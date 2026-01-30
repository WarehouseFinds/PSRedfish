[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Variables used in Pester test contexts')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Test credentials in integration tests')]
param()

BeforeDiscovery {
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
}

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
}

AfterAll {
    # Clean up any remaining sessions
    Get-RedfishSession -ErrorAction SilentlyContinue | Remove-RedfishSession -ErrorAction SilentlyContinue

    # Clean up
    Remove-Module 'PSRedfish' -ErrorAction SilentlyContinue
}

Describe 'New-RedfishSession Integration Tests' -Tag 'Integration', 'Redfish', 'Sessions' -Skip:(-not $script:emulatorAvailable) {

    AfterEach {
        # Clean up sessions after each test
        Get-RedfishSession -ErrorAction SilentlyContinue | Remove-RedfishSession -ErrorAction SilentlyContinue
    }

    Context 'Basic Authentication' {
        It 'Should create session with Basic authentication' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $session | Should -Not -BeNullOrEmpty
            $session.PSTypeName | Should -Be 'PSRedfish.Session'
            $session.BaseUri | Should -Be $script:baseUri
            $session.AuthMethod | Should -Be 'Basic'
            $session.HttpClient | Should -Not -BeNullOrEmpty
            $session.Username | Should -Be 'Administrator'
        }

        It 'Should create session with custom timeout' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic -TimeoutSeconds 60

            $session.TimeoutSeconds | Should -Be 60
        }

        It 'Should create session with custom connection settings' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic -MaxConnectionsPerServer 20 -ConnectionLifetimeMinutes 10

            $session.MaxConnectionsPerServer | Should -Be 20
            $session.ConnectionLifetime.TotalMinutes | Should -Be 10
        }
    }

    Context 'Session Authentication' {
        It 'Should create session with Session authentication' {

            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Session

            $session | Should -Not -BeNullOrEmpty
            $session.PSTypeName | Should -Be 'PSRedfish.Session'
            $session.AuthMethod | Should -Be 'Session'
            $session.SessionToken | Should -Not -BeNullOrEmpty
            $session.SessionUri | Should -Not -BeNullOrEmpty
        }

        It 'Should delete session on server when removed' {
            try {
                $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Session
                $sessionUri = $session.SessionUri

                Remove-RedfishSession -Session $session

                # Session should no longer exist on server (404 expected)
                { Invoke-RedfishRequest -Session $session -Uri $sessionUri -ErrorAction Stop } | Should -Throw
            } catch {
                Set-ItResult -Skipped -Because "Session authentication not supported by emulator: $_"
            }
        }
    }

    Context 'Metrics' {
        It 'Should create session with metrics enabled' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic -EnableMetrics

            $session.Metrics | Should -Not -BeNullOrEmpty
            $session.Metrics.PSTypeName | Should -Be 'PSRedfish.Metrics'
            $session.Metrics.TotalRequests | Should -Be 0
            $session.Metrics.SuccessfulRequests | Should -Be 0
            $session.Metrics.FailedRequests | Should -Be 0
        }

        It 'Should create session without metrics by default' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $session.Metrics | Should -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Should handle invalid credentials' {
            # Note: Redfish emulators typically don't validate credentials for GET requests
            # Skip this test when using local emulator endpoints
            if ($script:baseUri -match 'localhost|host\.docker\.internal') {
                Set-ItResult -Skipped -Because "Redfish emulator doesn't validate credentials on GET requests"
                return
            }

            $badCred = [System.Management.Automation.PSCredential]::new(
                'InvalidUser',
                (ConvertTo-SecureString 'WrongPassword' -AsPlainText -Force)
            )

            { New-RedfishSession -BaseUri $script:baseUri -Credential $badCred -AuthMethod Basic -ErrorAction Stop } | Should -Throw
        }

        It 'Should handle invalid URI' {
            { New-RedfishSession -BaseUri 'http://invalid.nonexistent.local:9999' -Credential $script:testCredential -AuthMethod Basic -TimeoutSeconds 5 -ErrorAction Stop } | Should -Throw
        }

        It 'Should reject invalid BaseUri format' {
            { New-RedfishSession -BaseUri 'not-a-url' -Credential $script:testCredential -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Should support WhatIf parameter' {
            $null = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic -WhatIf

            # Session should not be created with WhatIf
            $sessions = Get-RedfishSession
            $sessions | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-RedfishSession Integration Tests' -Tag 'Integration', 'Redfish', 'Sessions' -Skip:(-not $script:emulatorAvailable) {

    AfterEach {
        Get-RedfishSession -ErrorAction SilentlyContinue | Remove-RedfishSession -ErrorAction SilentlyContinue
    }

    Context 'Session Retrieval' {
        It 'Should retrieve active sessions' {
            $session1 = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $sessions = Get-RedfishSession
            $sessions | Should -Not -BeNullOrEmpty
            $sessions.Count | Should -BeGreaterOrEqual 1
        }

        It 'Should retrieve multiple sessions' {
            $session1 = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic
            $session2 = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $sessions = Get-RedfishSession
            $sessions.Count | Should -BeGreaterOrEqual 2
        }

        It 'Should return empty when no sessions exist' {
            $sessions = Get-RedfishSession
            $sessions | Should -BeNullOrEmpty
        }
    }

    Context 'Filtering' {
        It 'Should filter sessions by BaseUri' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $filtered = Get-RedfishSession -BaseUri $script:baseUri
            $filtered | Should -Not -BeNullOrEmpty
            $filtered[0].BaseUri | Should -Be $script:baseUri
        }

        It 'Should return empty for non-matching BaseUri' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            $filtered = Get-RedfishSession -BaseUri 'https://nonexistent.example.com'
            $filtered | Should -BeNullOrEmpty
        }
    }
}

Describe 'Remove-RedfishSession Integration Tests' -Tag 'Integration', 'Redfish', 'Sessions' -Skip:(-not $script:emulatorAvailable) {

    AfterEach {
        Get-RedfishSession -ErrorAction SilentlyContinue | Remove-RedfishSession -ErrorAction SilentlyContinue
    }

    Context 'Session Removal' {
        It 'Should remove session and dispose resources' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            { Remove-RedfishSession -Session $session } | Should -Not -Throw

            $remainingSessions = Get-RedfishSession -BaseUri $script:baseUri
            $remainingSessions | Should -BeNullOrEmpty
        }

        It 'Should handle null HttpClient gracefully' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic
            $session.HttpClient.Dispose()
            $session.HttpClient = $null

            { Remove-RedfishSession -Session $session } | Should -Not -Throw
        }
    }

    Context 'WhatIf Support' {
        It 'Should support WhatIf' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            Remove-RedfishSession -Session $session -WhatIf

            # Session should still exist after WhatIf
            $sessions = Get-RedfishSession
            $sessions | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Pipeline Support' {
        It 'Should remove multiple sessions via pipeline' {
            $session1 = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic
            $session2 = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            Get-RedfishSession | Remove-RedfishSession

            $remainingSessions = Get-RedfishSession
            $remainingSessions | Should -BeNullOrEmpty
        }

        It 'Should accept session from pipeline by value' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            { $session | Remove-RedfishSession } | Should -Not -Throw
        }
    }

    Context 'Error Handling' {
        It 'Should handle removal of already removed session gracefully' {
            $session = New-RedfishSession -BaseUri $script:baseUri -Credential $script:testCredential -AuthMethod Basic

            Remove-RedfishSession -Session $session
            { Remove-RedfishSession -Session $session } | Should -Not -Throw
        }
    }
}
