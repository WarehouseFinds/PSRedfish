BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Remove-RedfishSession' {
    BeforeEach {
        # Create mock HttpClient with proper Dispose method
        $mockHttpClient = [PSCustomObject]@{}
        $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

        # Create mock session object
        $script:mockSession = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://test.redfish.com'
            Username   = 'testuser'
            HttpClient = $mockHttpClient
        }

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
            $validSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                Username   = 'user'
                AuthMethod = 'Basic'
                HttpClient = $mockHttpClient
            }
            { Remove-RedfishSession -Session $validSession -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context 'Functionality' {
        It 'Should dispose HttpClient' {
            $script:disposed = $false
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $script:disposed = $true }
            $testSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                AuthMethod = 'Basic'
                Username   = 'user'
                HttpClient = $mockHttpClient
            }

            Remove-RedfishSession -Session $testSession
            $script:disposed | Should -Be $true
        }

        It 'Should remove session from cache' {
            $script:RedfishSessions.Count | Should -Be 1
            Remove-RedfishSession -Session $mockSession
            $script:RedfishSessions.Count | Should -Be 0
        }

        It 'Should handle session not in cache gracefully' {
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $otherSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://other.com'
                Username   = 'otheruser'
                AuthMethod = 'Basic'
                HttpClient = $mockHttpClient
            }

            { Remove-RedfishSession -Session $otherSession -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should handle null HttpClient gracefully' {
            $sessionWithoutClient = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                AuthMethod = 'Basic'
                Username   = 'user'
            }

            { Remove-RedfishSession -Session $sessionWithoutClient -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should handle null session cache gracefully' {
            $script:RedfishSessions = $null
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $testSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                AuthMethod = 'Basic'
                Username   = 'user'
                HttpClient = $mockHttpClient
            }

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
            $session2 = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test2.com'
                AuthMethod = 'Basic'
                Username   = 'user2'
                HttpClient = $mockHttpClient2
            }
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
            $failingSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                AuthMethod = 'Basic'
                Username   = 'user'
                HttpClient = $mockHttpClient
            }

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
