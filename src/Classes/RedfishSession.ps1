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

    # For backward compatibility with tests checking PSTypeName property
    [string] $PSTypeName = 'PSRedfish.Session'

    RedfishSession() {
        # Default constructor
    }
}
