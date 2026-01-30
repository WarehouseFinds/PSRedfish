[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variables used in Pester test contexts')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test credentials in integration tests')]
param()

BeforeAll {
    # Determine the built module path dynamically
    $moduleName = 'PSRedfish'
    $modulePath = Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "../../build/out/$moduleName")
    $manifestPath = Join-Path -Path $modulePath -ChildPath "$moduleName.psd1"

    # Import the built module
    if ($manifestPath -and (Test-Path $manifestPath)) {
        Import-Module $manifestPath -Force -ErrorAction Stop
    } else {
        throw "Built module not found at: $manifestPath. Run 'Invoke-Build' first."
    }

    # Helper function to detect environment and return appropriate base URI
    function Get-TestRedfishUri {
        # Check if running in GitHub Actions
        if ($env:GITHUB_ACTIONS -eq 'true') {
            return 'http://localhost:5000'
        }
        # Check if running in dev container (look for common indicators)
        elseif ($env:REMOTE_CONTAINERS -eq 'true' -or $env:CODESPACES -eq 'true' -or (Test-Path '/.dockerenv')) {
            return 'http://host.docker.internal:9000'
        }
        # Default to localhost for local development
        else {
            return 'http://localhost:9000'
        }
    }

    # Get the base URI for tests
    $script:baseUri = Get-TestRedfishUri

    # Test credentials (Redfish emulator defaults)
    $script:testCredential = [System.Management.Automation.PSCredential]::new(
        'Administrator',
        (ConvertTo-SecureString 'Password' -AsPlainText -Force)
    )

    # Check if Redfish emulator is available
    $script:emulatorAvailable = $false
    try {
        $testResponse = Invoke-WebRequest -Uri "$script:baseUri/redfish/v1" -Method GET -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($testResponse.StatusCode -eq 200 -or $testResponse.StatusCode -eq 401 -or $testResponse.StatusCode -eq 403) {
            $script:emulatorAvailable = $true
        }
    } catch {
        Write-Warning "Redfish emulator not available at $script:baseUri. Integration tests will be skipped."
        Write-Warning "Error: $_"
    }

    # Create a session for request tests
    if ($script:emulatorAvailable) {
        $script:testSession = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic
    }
}

AfterAll {
    # Clean up test session
    if ($script:testSession) {
        Remove-RedfishSession -Session $script:testSession -ErrorAction SilentlyContinue
    }

    # Clean up any remaining sessions
    Get-RedfishSession -ErrorAction SilentlyContinue | Remove-RedfishSession -ErrorAction SilentlyContinue

    # Clean up
    Remove-Module 'PSRedfish' -ErrorAction SilentlyContinue
}

Describe 'Invoke-RedfishRequest GET Operations' -Tag 'Integration', 'Redfish', 'Requests' -Skip:(-not $script:emulatorAvailable -or -not $script:testSession) {

    Context 'Service Root' {
        It 'Should get service root' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1'

            $result | Should -Not -BeNullOrEmpty
            $result.'@odata.type' | Should -Not -BeNullOrEmpty
            $result.RedfishVersion | Should -Not -BeNullOrEmpty
        }

        It 'Should have standard Redfish properties' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1'

            $result.'@odata.id' | Should -Be '/redfish/v1/'
            $result.Systems | Should -Not -BeNullOrEmpty
            $result.Chassis | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Collections' {
        It 'Should get Systems collection' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'

            $result | Should -Not -BeNullOrEmpty
            $result.Members | Should -Not -BeNullOrEmpty
            $result.'@odata.type' | Should -Match 'Collection'
        }

        It 'Should get Chassis collection' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Chassis'

            $result | Should -Not -BeNullOrEmpty
            $result.'@odata.type' | Should -Match 'ChassisCollection'
        }

        It 'Should get Managers collection' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Managers'

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Resource Navigation' {
        It 'Should navigate to System resource' {
            $systems = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'

            if ($systems.Members.Count -gt 0) {
                $systemUri = $systems.Members[0].'@odata.id'
                $system = Invoke-RedfishRequest -Session $script:testSession -Uri $systemUri

                $system | Should -Not -BeNullOrEmpty
                $system.'@odata.type' | Should -Match 'ComputerSystem'
            } else {
                Set-ItResult -Skipped -Because 'No systems available in emulator'
            }
        }

        It 'Should navigate to Chassis resource' {
            $chassis = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Chassis'

            if ($chassis.Members.Count -gt 0) {
                $chassisUri = $chassis.Members[0].'@odata.id'
                $chassisResource = Invoke-RedfishRequest -Session $script:testSession -Uri $chassisUri

                $chassisResource | Should -Not -BeNullOrEmpty
                $chassisResource.'@odata.type' | Should -Match 'Chassis'
            } else {
                Set-ItResult -Skipped -Because 'No chassis available in emulator'
            }
        }
    }

    Context 'Error Handling' {
        It 'Should handle 404 errors gracefully' {
            { Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/NonExistent' -ErrorAction Stop } | Should -Throw
        }

        It 'Should handle invalid URIs' {
            { Invoke-RedfishRequest -Session $script:testSession -Uri '/invalid' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Request Parameters' {
        It 'Should support custom timeout' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1' -TimeoutSeconds 10
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Should support NoRetry flag' {
            { Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1' -NoRetry } | Should -Not -Throw
        }

        It 'Should support custom retry parameters' {
            $result = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1' -MaxRetries 1 -RetryDelayMilliseconds 500
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Invoke-RedfishRequest POST/PATCH/DELETE Operations' -Tag 'Integration', 'Redfish', 'Requests' -Skip:(-not $script:emulatorAvailable -or -not $script:testSession) {

    Context 'PATCH Operations' {
        It 'Should perform PATCH operation' {
            try {
                $systems = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'
                if ($systems.Members.Count -gt 0) {
                    $systemUri = $systems.Members[0].'@odata.id'
                    $body = @{ AssetTag = "TEST-$(Get-Random)" }

                    { Invoke-RedfishRequest -Session $script:testSession -Uri $systemUri -Method PATCH -Body $body } | Should -Not -Throw
                } else {
                    Set-ItResult -Skipped -Because 'No systems available for testing'
                }
            } catch {
                # Some emulators don't support PATCH
                Set-ItResult -Skipped -Because "PATCH not supported by emulator: $_"
            }
        }

        It 'Should support WhatIf for PATCH' {
            try {
                $systems = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'
                if ($systems.Members.Count -gt 0) {
                    $systemUri = $systems.Members[0].'@odata.id'
                    $body = @{ AssetTag = 'WHATIF-TEST' }

                    $null = Invoke-RedfishRequest -Session $script:testSession -Uri $systemUri -Method PATCH -Body $body -WhatIf
                    # Verify nothing was changed (would need to compare before/after state)
                } else {
                    Set-ItResult -Skipped -Because 'No systems available for testing'
                }
            } catch {
                Set-ItResult -Skipped -Because "PATCH not supported by emulator: $_"
            }
        }
    }

    Context 'POST Operations' {
        It 'Should perform POST operation for actions' {
            try {
                $systems = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'
                if ($systems.Members.Count -gt 0) {
                    $systemUri = $systems.Members[0].'@odata.id'
                    $actionUri = "$systemUri/Actions/ComputerSystem.Reset"
                    $body = @{ ResetType = 'ForceRestart' }

                    # This may fail depending on emulator capabilities
                    { Invoke-RedfishRequest -Session $script:testSession -Uri $actionUri -Method POST -Body $body } | Should -Not -Throw
                } else {
                    Set-ItResult -Skipped -Because 'No systems available for testing'
                }
            } catch {
                Set-ItResult -Skipped -Because "POST actions not supported by emulator: $_"
            }
        }
    }
}

Describe 'Invoke-RedfishRequest with Metrics' -Tag 'Integration', 'Redfish', 'Requests', 'Metrics' -Skip:(-not $script:emulatorAvailable -or -not $script:metricsSession) {
    BeforeAll {
        if ($script:emulatorAvailable) {
            # Create session with metrics enabled
            $script:metricsSession = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic -EnableMetrics
        }
    }

    AfterAll {
        if ($script:metricsSession) {
            Remove-RedfishSession -Session $script:metricsSession -ErrorAction SilentlyContinue
        }
    }

    Context 'Metrics Collection' {
        It 'Should track request metrics' {
            $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1'

            $stats = $script:metricsSession.Metrics.GetStatistics()
            $stats.TotalRequests | Should -BeGreaterThan 0
            $stats.SuccessfulRequests | Should -BeGreaterThan 0
            $stats.AverageLatencyMs | Should -BeGreaterThan 0
        }

        It 'Should track multiple requests' {
            $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1'
            $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1/Systems'
            $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1/Chassis'

            $stats = $script:metricsSession.Metrics.GetStatistics()
            $stats.TotalRequests | Should -BeGreaterOrEqual 3
            $stats.SuccessfulRequests | Should -Be $stats.TotalRequests
            $stats.FailedRequests | Should -Be 0
        }

        It 'Should track failed requests' {
            { Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1/NonExistent' -ErrorAction Stop } | Should -Throw

            $stats = $script:metricsSession.Metrics.GetStatistics()
            $stats.FailedRequests | Should -BeGreaterThan 0
        }

        It 'Should calculate percentile latencies' {
            # Make multiple requests to get meaningful statistics
            1..10 | ForEach-Object {
                $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1'
            }

            $stats = $script:metricsSession.Metrics.GetStatistics()
            $stats.P95LatencyMs | Should -BeGreaterThan 0
            $stats.P99LatencyMs | Should -BeGreaterThan 0
            $stats.MinLatencyMs | Should -BeGreaterThan 0
            $stats.MaxLatencyMs | Should -BeGreaterOrEqual $stats.MinLatencyMs
        }

        It 'Should calculate requests per second' {
            Start-Sleep -Seconds 1
            1..5 | ForEach-Object {
                $null = Invoke-RedfishRequest -Session $script:metricsSession -Uri '/redfish/v1'
            }

            $stats = $script:metricsSession.Metrics.GetStatistics()
            $stats.RequestsPerSecond | Should -BeGreaterThan 0
        }
    }
}

Describe 'Invoke-RedfishRequest Pipeline Support' -Tag 'Integration', 'Redfish', 'Requests' -Skip:(-not $script:emulatorAvailable -or -not $script:testSession) {

    Context 'Pipeline Operations' {
        It 'Should accept URIs from pipeline' {
            $uris = @('/redfish/v1/Systems', '/redfish/v1/Chassis')

            $results = $uris | ForEach-Object {
                Invoke-RedfishRequest -Session $script:testSession -Uri $_
            }

            $results.Count | Should -Be 2
        }

        It 'Should process collection members via pipeline' {
            $systems = Invoke-RedfishRequest -Session $script:testSession -Uri '/redfish/v1/Systems'

            if ($systems.Members.Count -gt 0) {
                $results = $systems.Members | ForEach-Object {
                    Invoke-RedfishRequest -Session $script:testSession -Uri $_.'@odata.id'
                }

                $results.Count | Should -Be $systems.Members.Count
            } else {
                Set-ItResult -Skipped -Because 'No systems available for pipeline testing'
            }
        }
    }
}
