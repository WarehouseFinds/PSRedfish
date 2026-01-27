function Show-RedfishMetric {
    <#
.SYNOPSIS
    Displays session performance metrics in a formatted table.

.DESCRIPTION
    Shows detailed performance statistics for a Redfish session with metrics enabled.

.PARAMETER Session
    The Redfish session object with metrics enabled.

.EXAMPLE
    Show-RedfishMetric -Session $session

.EXAMPLE
    $session.Metrics.GetStatistics() | Format-Table
#>
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Write-Host is appropriate for this display function')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]
        $Session
    )

    process {
        if (-not $Session.Metrics) {
            Write-Warning 'Metrics are not enabled for this session. Create session with -EnableMetrics to collect metrics.'
            return
        }

        $stats = $Session.Metrics.GetStatistics()

        Write-Host -Object "`nRedfish Session Metrics - $($Session.BaseUri)" -ForegroundColor Cyan
        Write-Host -Object ('=' * 60) -ForegroundColor Cyan
        Write-Host -Object ''

        Write-Host -Object 'Session Info:' -ForegroundColor Yellow
        Write-Host -Object "  Uptime:              $($stats.SessionUptime)"
        Write-Host -Object "  Requests/Second:     $($stats.RequestsPerSecond)"
        Write-Host -Object ''

        Write-Host -Object 'Request Statistics:' -ForegroundColor Yellow
        Write-Host -Object "  Total Requests:      $($stats.TotalRequests)"
        Write-Host -Object "  Successful:          $($stats.SuccessfulRequests)"
        Write-Host -Object "  Failed:              $($stats.FailedRequests)"
        Write-Host -Object "  Success Rate:        $($stats.SuccessRate)%"
        Write-Host -Object ''

        Write-Host -Object 'Latency (ms):' -ForegroundColor Yellow
        Write-Host -Object "  Average:             $($stats.AverageLatencyMs)"
        Write-Host -Object "  Minimum:             $($stats.MinLatencyMs)"
        Write-Host -Object "  Maximum:             $($stats.MaxLatencyMs)"
        Write-Host -Object "  95th Percentile:     $($stats.P95LatencyMs)"
        Write-Host -Object "  99th Percentile:     $($stats.P99LatencyMs)"
        Write-Host -Object ''
    }
}
