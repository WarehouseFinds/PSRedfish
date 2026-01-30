BeforeAll {
    # Load class definitions in correct order
    . $PSScriptRoot/RedfishMetrics.ps1
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'RedfishSession' {
    Context 'Class Instantiation' {
        It 'Should create new instance' {
            $session = [RedfishSession]::new()

            $session | Should -Not -BeNullOrEmpty
        }

        It 'Should have PSTypeName property for backward compatibility' {
            $session = [RedfishSession]::new()
            $session.PSTypeName | Should -Be 'PSRedfish.Session'
        }

        It 'Should be of type RedfishSession' {
            $session = [RedfishSession]::new()
            $session.GetType().Name | Should -Be 'RedfishSession'
        }
    }

    Context 'Property Assignment' {
        It 'Should allow setting BaseUri' {
            $session = [RedfishSession]::new()
            $session.BaseUri = 'https://test.redfish.com'

            $session.BaseUri | Should -Be 'https://test.redfish.com'
        }

        It 'Should allow setting AuthMethod' {
            $session = [RedfishSession]::new()
            $session.AuthMethod = 'Basic'

            $session.AuthMethod | Should -Be 'Basic'
        }

        It 'Should allow setting Username' {
            $session = [RedfishSession]::new()
            $session.Username = 'testuser'

            $session.Username | Should -Be 'testuser'
        }

        It 'Should allow setting TimeoutSeconds' {
            $session = [RedfishSession]::new()
            $session.TimeoutSeconds = 60

            $session.TimeoutSeconds | Should -Be 60
        }

        It 'Should allow setting CreatedAt' {
            $session = [RedfishSession]::new()
            $now = [DateTime]::UtcNow
            $session.CreatedAt = $now

            $session.CreatedAt | Should -Be $now
        }

        It 'Should allow setting Metrics' {
            $session = [RedfishSession]::new()
            $metrics = [RedfishMetrics]::new()
            $session.Metrics = $metrics

            $session.Metrics | Should -Not -BeNullOrEmpty
            $session.Metrics.GetType().Name | Should -Be 'RedfishMetrics'
        }
    }

    Context 'Integration with RedfishMetrics' {
        It 'Should work with RedfishMetrics class' {
            $session = [RedfishSession]::new()
            $session.Metrics = [RedfishMetrics]::new()

            $session.Metrics.TotalRequests++
            $session.Metrics.SuccessfulRequests++

            $stats = $session.Metrics.GetStatistics()
            $stats.TotalRequests | Should -Be 1
            $stats.SuccessfulRequests | Should -Be 1
        }
    }
}
