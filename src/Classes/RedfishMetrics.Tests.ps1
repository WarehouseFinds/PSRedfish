BeforeAll {
    # Load the class definition
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'RedfishMetrics' {
    Context 'Class Instantiation' {
        It 'Should create new instance with default values' {
            $metrics = [RedfishMetrics]::new()

            $metrics | Should -Not -BeNullOrEmpty
            $metrics.TotalRequests | Should -Be 0
            $metrics.SuccessfulRequests | Should -Be 0
            $metrics.FailedRequests | Should -Be 0
            $metrics.RequestDurations.GetType().Name | Should -Be 'List`1'
            $metrics.SessionStartTime | Should -BeOfType [DateTime]
        }

        It 'Should have PSTypeName property for backward compatibility' {
            $metrics = [RedfishMetrics]::new()
            $metrics.PSTypeName | Should -Be 'PSRedfish.Metrics'
        }

        It 'Should be of type RedfishMetrics' {
            $metrics = [RedfishMetrics]::new()
            $metrics.GetType().Name | Should -Be 'RedfishMetrics'
        }
    }

    Context 'GetStatistics Method' {
        It 'Should return statistics object' {
            $metrics = [RedfishMetrics]::new()
            $stats = $metrics.GetStatistics()

            $stats | Should -Not -BeNullOrEmpty
            $stats.TotalRequests | Should -Be 0
            $stats.SuccessfulRequests | Should -Be 0
            $stats.FailedRequests | Should -Be 0
            $stats.SuccessRate | Should -Be 0
        }

        It 'Should calculate success rate correctly' {
            $metrics = [RedfishMetrics]::new()
            $metrics.TotalRequests = 100
            $metrics.SuccessfulRequests = 95
            $metrics.FailedRequests = 5

            $stats = $metrics.GetStatistics()
            $stats.SuccessRate | Should -Be 95
        }

        It 'Should calculate average latency' {
            $metrics = [RedfishMetrics]::new()
            $metrics.RequestDurations.Add(100)
            $metrics.RequestDurations.Add(200)
            $metrics.RequestDurations.Add(300)

            $stats = $metrics.GetStatistics()
            $stats.AverageLatencyMs | Should -Be 200
        }

        It 'Should calculate min and max latency' {
            $metrics = [RedfishMetrics]::new()
            $metrics.RequestDurations.Add(100)
            $metrics.RequestDurations.Add(200)
            $metrics.RequestDurations.Add(300)

            $stats = $metrics.GetStatistics()
            $stats.MinLatencyMs | Should -Be 100
            $stats.MaxLatencyMs | Should -Be 300
        }

        It 'Should calculate P95 and P99 latency' {
            $metrics = [RedfishMetrics]::new()
            for ($i = 1; $i -le 100; $i++) {
                $metrics.RequestDurations.Add($i)
            }

            $stats = $metrics.GetStatistics()
            $stats.P95LatencyMs | Should -BeGreaterThan 90
            $stats.P99LatencyMs | Should -BeGreaterThan 95
        }

        It 'Should calculate requests per second' {
            $metrics = [RedfishMetrics]::new()
            $metrics.SessionStartTime = ([DateTime]::UtcNow).AddSeconds(-10)
            $metrics.TotalRequests = 100

            $stats = $metrics.GetStatistics()
            $stats.RequestsPerSecond | Should -BeGreaterThan 9
            $stats.RequestsPerSecond | Should -BeLessThan 11
        }

        It 'Should include session uptime' {
            $metrics = [RedfishMetrics]::new()
            Start-Sleep -Milliseconds 100

            $stats = $metrics.GetStatistics()
            $stats.SessionUptime | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Data Collection' {
        It 'Should allow adding request durations' {
            $metrics = [RedfishMetrics]::new()
            $metrics.RequestDurations.Add(150.5)
            $metrics.RequestDurations.Add(200.3)

            $metrics.RequestDurations.Count | Should -Be 2
        }

        It 'Should allow incrementing counters' {
            $metrics = [RedfishMetrics]::new()
            $metrics.TotalRequests++
            $metrics.SuccessfulRequests++

            $metrics.TotalRequests | Should -Be 1
            $metrics.SuccessfulRequests | Should -Be 1
        }
    }
}
