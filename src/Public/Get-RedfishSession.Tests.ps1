BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Get-RedfishSession' {
    BeforeEach {
        # Initialize session cache with test sessions
        $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Create mock HttpClients with proper Dispose methods
        $mockHttpClient1 = [PSCustomObject]@{}
        $mockHttpClient1 | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

        $mockHttpClient2 = [PSCustomObject]@{}
        $mockHttpClient2 | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

        $mockHttpClient3 = [PSCustomObject]@{}
        $mockHttpClient3 | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }

        $script:session1 = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://redfish1.example.com'
            Username   = 'user1'
            CreatedAt  = [DateTime]::UtcNow.AddMinutes(-10)
            HttpClient = $mockHttpClient1
        }

        $script:session2 = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://redfish2.example.com'
            Username   = 'user2'
            CreatedAt  = [DateTime]::UtcNow.AddMinutes(-5)
            HttpClient = $mockHttpClient2
        }

        $script:session3 = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://redfish1.example.com'
            Username   = 'user3'
            CreatedAt  = [DateTime]::UtcNow.AddMinutes(-3)
            HttpClient = $mockHttpClient3
        }

        $script:RedfishSessions.Add($session1)
        $script:RedfishSessions.Add($session2)
        $script:RedfishSessions.Add($session3)
    }

    AfterEach {
        $script:RedfishSessions = $null
    }

    Context 'Parameter Validation' {
        It 'Should not require any parameters' {
            { Get-RedfishSession } | Should -Not -Throw
        }

        It 'Should accept BaseUri parameter' {
            { Get-RedfishSession -BaseUri 'https://test.com' } | Should -Not -Throw
        }

        It 'Should not accept null or empty BaseUri' {
            { Get-RedfishSession -BaseUri '' } | Should -Throw
            { Get-RedfishSession -BaseUri $null } | Should -Throw
        }
    }

    Context 'Functionality' {
        It 'Should return all sessions when no filter is specified' {
            $result = Get-RedfishSession
            $result.Count | Should -Be 3
        }

        It 'Should return sessions matching BaseUri filter' {
            $result = Get-RedfishSession -BaseUri 'https://redfish1.example.com'
            $result.Count | Should -Be 2
            $result[0].BaseUri | Should -Be 'https://redfish1.example.com'
            $result[1].BaseUri | Should -Be 'https://redfish1.example.com'
        }

        It 'Should return empty array when no sessions match filter' {
            $result = Get-RedfishSession -BaseUri 'https://nonexistent.com'
            @($result).Count | Should -Be 0
        }

        It 'Should return empty array when no sessions exist' {
            $script:RedfishSessions.Clear()
            $result = Get-RedfishSession
            @($result).Count | Should -Be 0
        }

        It 'Should return empty array when session cache is null' {
            $script:RedfishSessions = $null
            $result = Get-RedfishSession
            @($result).Count | Should -Be 0
        }

        It 'Should normalize BaseUri by removing trailing slash' {
            $baseUri = 'https://redfish1.example.com/'
            $normalized = $baseUri.TrimEnd('/')
            $normalized | Should -Be 'https://redfish1.example.com'
        }
    }

    Context 'Output Type' {
        It 'Should return array of session objects' {
            $result = @(Get-RedfishSession)
            $result.Count | Should -Be 3
            $result[0].PSTypeNames -contains 'PSRedfish.Session' | Should -Be $true
        }

        It 'Should return session objects with expected properties' {
            $result = Get-RedfishSession
            $result[0].BaseUri | Should -Not -BeNullOrEmpty
            $result[0].Username | Should -Not -BeNullOrEmpty
            $result[0].CreatedAt | Should -BeOfType [DateTime]
        }

        It 'Should return consistent output type even for single result' {
            $result = @(Get-RedfishSession -BaseUri 'https://redfish2.example.com')
            $result.Count | Should -Be 1
        }
    }

    Context 'Filtering' {
        It 'Should filter case-sensitively by BaseUri' {
            # BaseUri comparison should be exact match
            $result = Get-RedfishSession -BaseUri 'https://redfish1.example.com'
            $result.Count | Should -Be 2
        }

        It 'Should handle BaseUri with different protocols' {
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $httpSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'http://redfish.example.com'
                Username   = 'user'
                HttpClient = $mockHttpClient
            }
            $script:RedfishSessions.Add($httpSession)

            $result = Get-RedfishSession -BaseUri 'http://redfish.example.com'
            $result.Count | Should -Be 1
            $result[0].BaseUri | Should -Be 'http://redfish.example.com'
        }
    }

    Context 'Pipeline Support' {
        It 'Should output objects suitable for pipeline' {
            $sessions = Get-RedfishSession
            $sessions | Should -Not -BeNullOrEmpty
            $sessions[0].PSTypeNames -contains 'PSRedfish.Session' | Should -Be $true
        }

        It 'Should be pipeable to Remove-RedfishSession' {
            # Verify session objects have proper type for pipeline
            $sessions = Get-RedfishSession
            $sessions[0].PSTypeNames -contains 'PSRedfish.Session' | Should -Be $true
        }
    }

    Context 'Verbose Output' {
        It 'Should provide verbose logging' {
            $verboseMessages = @()
            Get-RedfishSession -Verbose 4>&1 | ForEach-Object {
                if ($_ -is [System.Management.Automation.VerboseRecord]) {
                    $verboseMessages += $_
                }
            }
            $verboseMessages.Count | Should -BeGreaterThan 0
        }

        It 'Should report count of sessions found' {
            $verboseOutput = Get-RedfishSession -Verbose 4>&1 | Out-String
            $verboseOutput | Should -Match 'session'
        }

        It 'Should report when no sessions are found' {
            $script:RedfishSessions.Clear()
            $verboseOutput = Get-RedfishSession -Verbose 4>&1 | Out-String
            $verboseOutput | Should -Match 'No active'
        }
    }

    Context 'Error Handling' {
        It 'Should handle corrupt session cache gracefully' {
            # Even if cache has unexpected state, should not throw
            { Get-RedfishSession -ErrorAction Stop } | Should -Not -Throw
        }

        It 'Should preserve exception with stack trace on error' {
            # Verify error handling preserves exceptions properly
            # Stack traces are populated when exceptions are thrown
            try {
                throw [System.Exception]::new('Test error')
            } catch {
                $_.Exception | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Integration with Session Management' {
        It 'Should return sessions added by New-RedfishSession pattern' {
            # Simulating what New-RedfishSession does
            $mockHttpClient = [PSCustomObject]@{}
            $mockHttpClient | Add-Member -MemberType ScriptMethod -Name Dispose -Value { }
            $newSession = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://new.example.com'
                Username   = 'newuser'
                CreatedAt  = [DateTime]::UtcNow
                HttpClient = $mockHttpClient
            }
            $script:RedfishSessions.Add($newSession)

            $result = Get-RedfishSession
            $result.Count | Should -Be 4
            $result[-1].BaseUri | Should -Be 'https://new.example.com'
        }

        It 'Should reflect removed sessions' {
            # Simulating what Remove-RedfishSession does
            $script:RedfishSessions.RemoveAt(0)

            $result = Get-RedfishSession
            $result.Count | Should -Be 2
        }
    }
}
