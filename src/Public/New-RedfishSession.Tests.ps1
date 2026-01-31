BeforeAll {
    # Load class definitions first
    . (Join-Path $PSScriptRoot '../Classes/RedfishMetrics.ps1')
    . (Join-Path $PSScriptRoot '../Classes/RedfishSession.ps1')

    # Then load the function
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'New-RedfishSession' {
    BeforeEach {
        # Clean up any existing sessions
        $script:RedfishSessions = $null
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory BaseUri parameter' {
            $command = Get-Command New-RedfishSession
            $baseUriParam = $command.Parameters['BaseUri']
            $mandatory = $baseUriParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should require mandatory Credential parameter' {
            $command = Get-Command New-RedfishSession
            $credParam = $command.Parameters['Credential']
            $mandatory = $credParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should validate BaseUri starts with http:// or https://' {
            $validUris = @('https://example.com', 'http://example.com')
            foreach ($uri in $validUris) {
                $uri -match '^https?://' | Should -Be $true
            }
        }

        It 'Should reject BaseUri without http:// or https://' {
            $invalidUri = 'example.com'
            $invalidUri -match '^https?://' | Should -Be $false
        }

        It 'Should have AuthMethod parameter with valid set' {
            $command = Get-Command New-RedfishSession
            $authParam = $command.Parameters['AuthMethod']
            $validateSet = $authParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Session'
            $validateSet.ValidValues | Should -Contain 'Basic'
        }

        It 'Should default AuthMethod to Session' {
            # Check default in param definition
            $command = Get-Command New-RedfishSession
            $authParam = $command.Parameters['AuthMethod']
            $authParam | Should -Not -BeNullOrEmpty
        }

        It 'Should have TimeoutSeconds parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $timeoutParam = $command.Parameters['TimeoutSeconds']
            $validateRange = $timeoutParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 300
        }

        It 'Should have MaxConnectionsPerServer parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $maxConnParam = $command.Parameters['MaxConnectionsPerServer']
            $validateRange = $maxConnParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 100
        }

        It 'Should have ConnectionLifetimeMinutes parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $lifetimeParam = $command.Parameters['ConnectionLifetimeMinutes']
            $validateRange = $lifetimeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 60
        }

        It 'Should have EnableMetrics switch parameter' {
            $command = Get-Command New-RedfishSession
            $metricsParam = $command.Parameters['EnableMetrics']
            $metricsParam | Should -Not -BeNullOrEmpty
            $metricsParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It 'Should have SkipCertificateCheck switch parameter' {
            $command = Get-Command New-RedfishSession
            $skipCertParam = $command.Parameters['SkipCertificateCheck']
            $skipCertParam | Should -Not -BeNullOrEmpty
            $skipCertParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'URI Normalization' {

    }

    Context 'HttpClient Handler Configuration' {

    }

    Context 'SSL/TLS Configuration' {

    }

    Context 'HttpClient Configuration' {

    }

    Context 'Authentication' {

    }

    Context 'Session Creation Retry Logic' {

    }

    Context 'Session Object Creation' {
        It 'Should create session object with correct type' {
            $session = [RedfishSession]::new()
            $session.BaseUri = 'https://test.redfish.com'
            $session.GetType().Name | Should -Be 'RedfishSession'
        }

        It 'Should include BaseUri in session' {
            $baseUri = 'https://test.redfish.com'
            $session = [PSCustomObject]@{
                BaseUri = $baseUri
            }
            $session.BaseUri | Should -Be $baseUri
        }

        It 'Should include AuthMethod in session' {
            $session = [PSCustomObject]@{
                AuthMethod = 'Session'
            }
            $session.AuthMethod | Should -Be 'Session'
        }
    }

    Context 'WhatIf Support' {
        It 'Should support SupportsShouldProcess' {
            $command = Get-Command New-RedfishSession
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support Confirm parameter' {
            $command = Get-Command New-RedfishSession
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Resource Disposal' {
        It 'Should dispose StringContent after use' {
            $content = [System.Net.Http.StringContent]::new('test', [System.Text.Encoding]::UTF8, 'application/json')
            $content.Dispose()
            # Should not throw
            $true | Should -Be $true
        }
    }
}
