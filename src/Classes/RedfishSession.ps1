class RedfishSession {
    [string] $BaseUri
    [PSCustomObject] $ServiceRoot
    [System.Net.Http.HttpClient] $HttpClient
    [string] $AuthMethod
    [string] $SessionToken
    [string] $SessionUri
    [DateTime] $CreatedAt
    [int] $TimeoutSeconds
    [string] $Username
    [bool] $SkipCertificateCheck
    [int] $MaxConnectionsPerServer
    [TimeSpan] $ConnectionLifetime
    [RedfishMetrics] $Metrics

    RedfishSession() {
        # Default constructor
    }
}
