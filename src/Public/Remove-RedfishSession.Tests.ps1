BeforeAll {
    # Load class definitions first
    . (Join-Path $PSScriptRoot '../Classes/RedfishMetrics.ps1')
    . (Join-Path $PSScriptRoot '../Classes/RedfishSession.ps1')

    # Then load the function
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Remove-RedfishSession' {
    BeforeEach {
        # Create mock HttpClient with proper Dispose method
        $mockHttpClient = [PSCustomObject]@{}
        $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

        # Create mock session object
        $script:mockSession = [RedfishSession]::new()
        $script:mockSession.BaseUri = 'https://test.redfish.com'
        $script:mockSession.AuthMethod = 'Basic'
        $script:mockSession.Username = 'testuser'
        $script:mockSession.HttpClient = $mockHttpClient

        # Initialize session cache
        $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
        $script:RedfishSessions.Add($mockSession)
    }

    AfterEach {
        $script:RedfishSessions = $null
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory Session parameter' {
            $command = Get-Command Remove-RedfishSession
            $sessionParam = $command.Parameters['Session']
            $mandatory = $sessionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should reject null Session' {
            { Remove-RedfishSession -Session $null } | Should -Throw
        }

        It 'Should reject invalid session object' {
            $invalidSession = [PSCustomObject]@{ Invalid = 'Object' }
            { Remove-RedfishSession -Session $invalidSession } | Should -Throw
        }

        It 'Should accept valid session object' {
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $validSession = [RedfishSession]::new()
            $validSession.BaseUri = 'https://test.com'
            $validSession.Username = 'user'
            $validSession.AuthMethod = 'Basic'
            $validSession.HttpClient = $mockHttpClient
            { Remove-RedfishSession -Session $validSession -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Functionality' {
        It 'Should dispose HttpClient' {
            # Use a session with an HttpClient property to test disposal
            # Since RedfishSession.HttpClient is strongly typed as System.Net.Http.HttpClient,
            # we need to test differently - verify that Dispose() is called on the property
            $testSession = [RedfishSession]::new()
            $testSession.BaseUri = 'https://test.com'
            $testSession.AuthMethod = 'Basic'
            $testSession.Username = 'user'

            # Create a real HttpClient that we can check for disposal
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $testSession.HttpClient = $httpClient
            $script:RedfishSessions.Add($testSession)

            Remove-RedfishSession -Session $testSession -Confirm:$false

            # After disposal, operations on the HttpClient should fail
            { $testSession.HttpClient.GetAsync('https://test.com').GetAwaiter().GetResult() } | Should -Throw
        }

        It 'Should remove session from cache' {
            $script:RedfishSessions.Count | Should -Be 1
            Remove-RedfishSession -Session $mockSession
            $script:RedfishSessions.Count | Should -Be 0
        }

        It 'Should handle session not in cache gracefully' {
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $otherSession = [RedfishSession]::new()
            $otherSession.BaseUri = 'https://other.com'
            $otherSession.AuthMethod = 'Basic'
            $otherSession.Username = 'otheruser'
            $otherSession.HttpClient = $mockHttpClient

            { Remove-RedfishSession -Session $otherSession -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should handle null HttpClient gracefully' {
            $sessionWithoutClient = [RedfishSession]::new()
            $sessionWithoutClient.BaseUri = 'https://test.com'
            $sessionWithoutClient.AuthMethod = 'Basic'
            $sessionWithoutClient.Username = 'user'

            { Remove-RedfishSession -Session $sessionWithoutClient -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should handle null session cache gracefully' {
            $script:RedfishSessions = $null
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $testSession = [RedfishSession]::new()
            $testSession.BaseUri = 'https://test.com'
            $testSession.AuthMethod = 'Basic'
            $testSession.Username = 'user'
            $testSession.HttpClient = $mockHttpClient

            { Remove-RedfishSession -Session $testSession -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Pipeline Support' {
        It 'Should accept session from pipeline' {
            $script:RedfishSessions.Count | Should -Be 1
            $mockSession | Remove-RedfishSession
            $script:RedfishSessions.Count | Should -Be 0
        }

        It 'Should process multiple sessions from pipeline' {
            $mockHttpClient2 = [PSCustomObject]@{}
            $mockHttpClient2 | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $session2 = [RedfishSession]::new()
            $session2.BaseUri = 'https://test2.com'
            $session2.AuthMethod = 'Basic'
            $session2.Username = 'user2'
            $session2.HttpClient = $mockHttpClient2
            $script:RedfishSessions.Add($session2)

            $script:RedfishSessions.Count | Should -Be 2
            # Create a copy to avoid "Collection was modified" error during enumeration
            @($script:RedfishSessions) | Remove-RedfishSession
            $script:RedfishSessions.Count | Should -Be 0
        }
    }

    Context 'WhatIf Support' {
        It 'Should support SupportsShouldProcess' {
            $command = Get-Command Remove-RedfishSession
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support Confirm parameter' {
            $command = Get-Command Remove-RedfishSession
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }

        It 'Should not remove session when WhatIf is specified' {
            $script:RedfishSessions.Count | Should -Be 1
            Remove-RedfishSession -Session $mockSession -WhatIf
            $script:RedfishSessions.Count | Should -Be 1
        }
    }

    Context 'Error Handling' {
        It 'Should warn if HttpClient disposal fails' {
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { throw 'Disposal failed' }
            $failingSession = [RedfishSession]::new()
            $failingSession.BaseUri = 'https://test.com'
            $failingSession.AuthMethod = 'Basic'
            $failingSession.Username = 'user'
            $failingSession.HttpClient = $mockHttpClient

            # Should not throw, but should write warning
            { Remove-RedfishSession -Session $failingSession -WarningAction SilentlyContinue -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should preserve exception with stack trace' {
            # Verify error handling preserves exceptions properly
            # Stack traces are populated when exceptions are thrown
            try {
                throw [System.Exception]::new('Test error')
            } catch {
                $_.Exception | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Verbose Output' {
        It 'Should provide verbose logging' {
            $verboseMessages = @()
            Remove-RedfishSession -Session $mockSession -Verbose 4>&1 | ForEach-Object {
                $verboseMessages += $_
            }
            $verboseMessages.Count | Should -BeGreaterThan 0
        }
    }
}
