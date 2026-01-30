class RedfishMetrics {
    [int] $TotalRequests = 0
    [int] $SuccessfulRequests = 0
    [int] $FailedRequests = 0
    [System.Collections.Generic.List[double]] $RequestDurations = [System.Collections.Generic.List[double]]::new()
    [DateTime] $SessionStartTime = [DateTime]::UtcNow

    # For backward compatibility with tests checking PSTypeName property
    [string] $PSTypeName = 'PSRedfish.Metrics'

    [PSCustomObject] GetStatistics() {
        $duration = [DateTime]::UtcNow - $this.SessionStartTime

        return [PSCustomObject]@{
            TotalRequests      = $this.TotalRequests
            SuccessfulRequests = $this.SuccessfulRequests
            FailedRequests     = $this.FailedRequests
            SuccessRate        = if ($this.TotalRequests -gt 0) {
                [Math]::Round(($this.SuccessfulRequests / $this.TotalRequests) * 100, 2)
            } else { 0 }
            AverageLatencyMs   = if ($this.RequestDurations.Count -gt 0) {
                [Math]::Round(($this.RequestDurations | Measure-Object -Average).Average, 2)
            } else { 0 }
            MinLatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                [Math]::Round(($this.RequestDurations | Measure-Object -Minimum).Minimum, 2)
            } else { 0 }
            MaxLatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                [Math]::Round(($this.RequestDurations | Measure-Object -Maximum).Maximum, 2)
            } else { 0 }
            P95LatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                $sorted = $this.RequestDurations | Sort-Object
                $index = [Math]::Floor($sorted.Count * 0.95)
                [Math]::Round($sorted[$index], 2)
            } else { 0 }
            P99LatencyMs       = if ($this.RequestDurations.Count -gt 0) {
                $sorted = $this.RequestDurations | Sort-Object
                $index = [Math]::Floor($sorted.Count * 0.99)
                [Math]::Round($sorted[$index], 2)
            } else { 0 }
            SessionUptime      = $duration.ToString('hh\:mm\:ss')
            RequestsPerSecond  = if ($duration.TotalSeconds -gt 0) {
                [Math]::Round($this.TotalRequests / $duration.TotalSeconds, 2)
            } else { 0 }
        }
    }
}
