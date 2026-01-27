function Show-RedfishMetrics {
    <#
.SYNOPSIS
    Displays session performance metrics in a formatted table.

.DESCRIPTION
    Shows detailed performance statistics for a Redfish session with metrics enabled.

.PARAMETER Session
    The Redfish session object with metrics enabled.

.EXAMPLE
    Show-RedfishMetrics -Session $session

.EXAMPLE
    $session.Metrics.GetStatistics() | Format-Table
#>
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

        Write-Host "`nRedfish Session Metrics - $($Session.BaseUri)" -ForegroundColor Cyan
        Write-Host '=' * 60 -ForegroundColor Cyan
        Write-Host ''

        Write-Host 'Session Info:' -ForegroundColor Yellow
        Write-Host "  Uptime:              $($stats.SessionUptime)"
        Write-Host "  Requests/Second:     $($stats.RequestsPerSecond)"
        Write-Host ''

        Write-Host 'Request Statistics:' -ForegroundColor Yellow
        Write-Host "  Total Requests:      $($stats.TotalRequests)"
        Write-Host "  Successful:          $($stats.SuccessfulRequests)"
        Write-Host "  Failed:              $($stats.FailedRequests)"
        Write-Host "  Success Rate:        $($stats.SuccessRate)%"
        Write-Host ''

        Write-Host 'Latency (ms):' -ForegroundColor Yellow
        Write-Host "  Average:             $($stats.AverageLatencyMs)"
        Write-Host "  Minimum:             $($stats.MinLatencyMs)"
        Write-Host "  Maximum:             $($stats.MaxLatencyMs)"
        Write-Host "  95th Percentile:     $($stats.P95LatencyMs)"
        Write-Host "  99th Percentile:     $($stats.P99LatencyMs)"
        Write-Host ''
    }
}
