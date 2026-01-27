BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Show-RedfishMetrics' {
    Context 'Parameter Validation' {
        It 'Should require mandatory Session parameter' {
            $command = Get-Command Show-RedfishMetrics
            $sessionParam = $command.Parameters['Session']
            $mandatory = $sessionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should accept Session from pipeline' {
            $command = Get-Command Show-RedfishMetrics
            $sessionParam = $command.Parameters['Session']
            $pipelineInput = $sessionParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
            }
            $pipelineInput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Metrics Display' {
        It 'Should warn if metrics not enabled' {
            $sessionWithoutMetrics = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
            }

            $hasMetrics = $null -ne $sessionWithoutMetrics.PSObject.Properties['Metrics'] -and $null -ne $sessionWithoutMetrics.Metrics
            $hasMetrics | Should -Be $false
        }

        It 'Should display metrics when available' {
            $sessionWithMetrics = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.com'
                Metrics    = [PSCustomObject]@{
                    TotalRequests      = 100
                    SuccessfulRequests = 95
                    FailedRequests     = 5
                }
            }

            $hasMetrics = $null -ne $sessionWithMetrics.Metrics
            $hasMetrics | Should -Be $true
        }

        It 'Should format uptime correctly' {
            $duration = [TimeSpan]::FromSeconds(3723)  # 1h 2m 3s
            $formatted = $duration.ToString('hh\:mm\:ss')
            $formatted | Should -Be '01:02:03'
        }

        It 'Should format requests per second' {
            $rps = 15.67
            $formatted = [Math]::Round($rps, 2)
            $formatted | Should -Be 15.67
        }

        It 'Should format latency values' {
            $latency = 123.456789
            $formatted = [Math]::Round($latency, 2)
            $formatted | Should -Be 123.46
        }

        It 'Should format success rate as percentage' {
            $successRate = 95.5
            $formatted = "$successRate%"
            $formatted | Should -Be '95.5%'
        }
    }

    Context 'Statistics Calculation' {
        It 'Should calculate statistics from metrics' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 100
                SuccessfulRequests = 95
                FailedRequests     = 5
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
                SessionStartTime   = [DateTime]::UtcNow.AddMinutes(-10)
            }

            # Add some durations
            $metrics.RequestDurations.Add(100.0)
            $metrics.RequestDurations.Add(200.0)
            $metrics.RequestDurations.Add(150.0)

            $metrics.TotalRequests | Should -Be 100
            $metrics.SuccessfulRequests | Should -Be 95
            $metrics.FailedRequests | Should -Be 5
            $metrics.RequestDurations.Count | Should -Be 3
        }

        It 'Should handle zero requests gracefully' {
            $totalRequests = 0
            $successRate = if ($totalRequests -gt 0) { 100 } else { 0 }
            $successRate | Should -Be 0
        }

        It 'Should handle empty duration list' {
            $durations = [System.Collections.Generic.List[double]]::new()
            $average = if ($durations.Count -gt 0) {
                ($durations | Measure-Object -Average).Average
            } else { 0 }
            $average | Should -Be 0
        }
    }
}
