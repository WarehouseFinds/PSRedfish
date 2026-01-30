function New-RedfishSession {
    <#
    .SYNOPSIS
        Creates a new Redfish session to a DMTF Redfish® API endpoint with enhanced performance.

    .DESCRIPTION
        Establishes an authenticated session to a Redfish API endpoint using either Basic authentication
        or Redfish session-based authentication. Session-based authentication is more secure and recommended.
        Returns a session object that can be used with other Redfish cmdlets.
        Uses optimized .NET HttpClient with connection pooling for high performance.

    .PARAMETER BaseUri
        The base URI of the Redfish API endpoint (e.g., https://redfish.example.com).

    .PARAMETER Credential
        PSCredential object containing the username and password for authentication.

    .PARAMETER AuthMethod
        Authentication method to use. Valid values are 'Session' (default) and 'Basic'.
        Session authentication creates a Redfish session and uses X-Auth-Token.
        Basic authentication uses HTTP Basic Auth for each request.

    .PARAMETER SkipCertificateCheck
        If specified, skips SSL certificate validation. Use with caution in production environments.

    .PARAMETER TimeoutSeconds
        The timeout in seconds for HTTP requests. Default is 30 seconds.

    .PARAMETER MaxConnectionsPerServer
        Maximum number of concurrent connections to the server. Default is 10.
        Increase for high-throughput scenarios.

    .PARAMETER ConnectionLifetimeMinutes
        How long to keep connections alive in the pool. Default is 5 minutes.
        Helps with load balancer scenarios.

    .PARAMETER EnableMetrics
        Enable collection of performance metrics for this session.
        Access metrics via $session.Metrics.GetStatistics()

    .EXAMPLE
        $cred = Get-Credential
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred
        Creates a new Redfish session using session-based authentication (default).

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred -EnableMetrics
        $session.Metrics.GetStatistics()
        Creates a session with performance metrics enabled.

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -SkipCertificateCheck -MaxConnectionsPerServer 20
        Creates a high-performance session with 20 concurrent connections allowed.

    .OUTPUTS
        RedfishSession object representing the Redfish session with HttpClient and session details.

    .NOTES
        The session object contains an HttpClient instance that should be disposed when no longer needed.
        Use Remove-RedfishSession to properly clean up the session.
        Connection pooling is automatically enabled for better performance.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([RedfishSession])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -match '^https?://') {
                    $true
                } else {
                    throw 'BaseUri must start with http:// or https://'
                }
            })]
        [string]
        $BaseUri,

        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [ValidateSet('Session', 'Basic')]
        [string]
        $AuthMethod = 'Session',

        [Parameter()]
        [switch]
        $SkipCertificateCheck,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]
        $TimeoutSeconds = 30,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]
        $MaxConnectionsPerServer = 10,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]
        $ConnectionLifetimeMinutes = 5,

        [Parameter()]
        [switch]
        $EnableMetrics
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            # Normalize the BaseUri (remove trailing slash)
            $normalizedUri = $BaseUri.TrimEnd('/')

            if (-not $PSCmdlet.ShouldProcess($normalizedUri, 'Create Redfish session')) {
                return
            }

            # Create optimized HttpClientHandler with SocketsHttpHandler for better performance
            # Note: SocketsHttpHandler is the recommended handler for .NET Core/.NET 5+
            $handler = if ($PSVersionTable.PSVersion.Major -ge 7) {
                # Use SocketsHttpHandler for PowerShell 7+ (better performance)
                $socketsHandler = [System.Net.Http.SocketsHttpHandler]::new()

                # Configure connection pooling
                $socketsHandler.PooledConnectionLifetime = [TimeSpan]::FromMinutes($ConnectionLifetimeMinutes)
                $socketsHandler.PooledConnectionIdleTimeout = [TimeSpan]::FromMinutes([Math]::Max($ConnectionLifetimeMinutes - 1, 1))
                $socketsHandler.MaxConnectionsPerServer = $MaxConnectionsPerServer

                # Enable keep-alive
                $socketsHandler.EnableMultipleHttp2Connections = $true

                # Configure SSL/TLS
                if ($SkipCertificateCheck) {
                    Write-Warning 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
                    $socketsHandler.SslOptions = [System.Net.Security.SslClientAuthenticationOptions]@{
                        RemoteCertificateValidationCallback = { $true }
                    }
                } else {
                    # Enable modern TLS versions
                    $socketsHandler.SslOptions = [System.Net.Security.SslClientAuthenticationOptions]@{
                        EnabledSslProtocols = [System.Security.Authentication.SslProtocols]::Tls12 -bor
                        [System.Security.Authentication.SslProtocols]::Tls13
                    }
                }

                # Enable automatic decompression
                $socketsHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::All

                $socketsHandler
            } else {
                # Fallback to HttpClientHandler for older PowerShell versions
                $httpHandler = [System.Net.Http.HttpClientHandler]::new()

                if ($SkipCertificateCheck) {
                    Write-Warning 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
                    $httpHandler.ServerCertificateCustomValidationCallback = { $true }
                }

                # Enable automatic decompression
                $httpHandler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor
                [System.Net.DecompressionMethods]::Deflate

                $httpHandler
            }

            # Create HttpClient with optimized settings
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.Timeout = [System.TimeSpan]::FromSeconds($TimeoutSeconds)
            $httpClient.DefaultRequestHeaders.Clear()

            # Set default headers for Redfish
            $httpClient.DefaultRequestHeaders.Add('Accept', 'application/json')
            $httpClient.DefaultRequestHeaders.Add('OData-Version', '4.0')
            $httpClient.DefaultRequestHeaders.Add('User-Agent', 'PSRedfish/2.0')

            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password
            $sessionToken = $null
            $sessionUri = $null

            if ($AuthMethod -eq 'Session') {
                # Create Redfish session for token-based authentication
                Write-Verbose 'Creating Redfish session with token authentication'

                # Prepare session creation request body with credentials
                $sessionBody = @{
                    UserName = $username
                    Password = $password
                } | ConvertTo-Json

                $sessionContent = [System.Net.Http.StringContent]::new(
                    $sessionBody,
                    [System.Text.Encoding]::UTF8,
                    'application/json'
                )

                # Retry session creation with exponential backoff
                $maxRetries = 3
                $retryDelay = 1000
                $sessionCreated = $false

                for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
                    try {
                        Write-Verbose "Attempting to create session (attempt $attempt/$maxRetries)"
                        $sessionResponse = $httpClient.PostAsync("$normalizedUri/redfish/v1/SessionService", $sessionContent).GetAwaiter().GetResult()

                        $statusCode = [int]$sessionResponse.StatusCode

                        # Validate HTTP 201 Created response
                        if ($statusCode -ne 201) {
                            $errorContent = $sessionResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                            # Retry on transient errors
                            if ($statusCode -in @(408, 429, 503, 504) -and $attempt -lt $maxRetries) {
                                Write-Warning "Session creation failed with HTTP $statusCode. Retrying in ${retryDelay}ms..."
                                $sessionResponse.Dispose()
                                Start-Sleep -Milliseconds $retryDelay
                                $retryDelay *= 2
                                continue
                            }

                            throw "Failed to create Redfish session. Expected HTTP 201 Created, received: $statusCode - $($sessionResponse.ReasonPhrase): $errorContent"
                        }

                        # Extract X-Auth-Token from response headers (required)
                        if ($sessionResponse.Headers.Contains('X-Auth-Token')) {
                            $sessionToken = $sessionResponse.Headers.GetValues('X-Auth-Token')[0]
                            Write-Verbose "Session token obtained: $($sessionToken.Substring(0, [Math]::Min(8, $sessionToken.Length)))..."
                        } else {
                            throw 'Server did not return X-Auth-Token header in HTTP 201 response. Session authentication is not supported by this endpoint.'
                        }

                        # Extract Location header (required for logout)
                        if ($sessionResponse.Headers.Location) {
                            # Location may be relative or absolute
                            $locationUri = $sessionResponse.Headers.Location
                            if ($locationUri.IsAbsoluteUri) {
                                $sessionUri = $locationUri.ToString()
                            } else {
                                # Convert relative URI to absolute
                                $sessionUri = "$normalizedUri$($locationUri.ToString())"
                            }
                            Write-Verbose "Session resource created at: $sessionUri"
                        } else {
                            Write-Warning 'Server did not return Location header. Session logout may not work correctly.'
                        }

                        $sessionResponse.Dispose()
                        $sessionCreated = $true
                        break
                    } catch {
                        if ($attempt -eq $maxRetries) {
                            throw
                        }
                    }
                }

                $sessionContent.Dispose()

                if (-not $sessionCreated) {
                    throw 'Failed to create Redfish session after multiple attempts'
                }

                # Add token authentication for subsequent requests
                $httpClient.DefaultRequestHeaders.Add('X-Auth-Token', $sessionToken)
            } else {
                # Use Basic Authentication for all requests
                Write-Verbose 'Using HTTP Basic authentication'
                $encodedAuth = [System.Convert]::ToBase64String(
                    [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
                )
                $httpClient.DefaultRequestHeaders.Add('Authorization', "Basic $encodedAuth")
            }

            # Test the connection by getting the service root
            Write-Verbose "Testing connection to $normalizedUri/redfish/v1"
            $testUri = "$normalizedUri/redfish/v1"
            $response = $httpClient.GetAsync($testUri).GetAwaiter().GetResult()

            if (-not $response.IsSuccessStatusCode) {
                throw "Failed to connect to Redfish endpoint. Status: $($response.StatusCode) - $($response.ReasonPhrase)"
            }

            $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $serviceRoot = $content | ConvertFrom-Json

            Write-Verbose "Successfully connected to Redfish service: $($serviceRoot.Name)"
            $response.Dispose()

            # Initialize metrics if enabled
            $metrics = if ($EnableMetrics) {
                [RedfishMetrics]::new()
            } else {
                $null
            }

            # Create session object
            $sessionObject = [RedfishSession]::new()
            $sessionObject.BaseUri = $normalizedUri
            $sessionObject.ServiceRoot = $serviceRoot
            $sessionObject.HttpClient = $httpClient
            $sessionObject.AuthMethod = $AuthMethod
            $sessionObject.SessionToken = $sessionToken
            $sessionObject.SessionUri = $sessionUri
            $sessionObject.CreatedAt = [DateTime]::UtcNow
            $sessionObject.TimeoutSeconds = $TimeoutSeconds
            $sessionObject.Username = $username
            $sessionObject.SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            $sessionObject.MaxConnectionsPerServer = $MaxConnectionsPerServer
            $sessionObject.ConnectionLifetime = [TimeSpan]::FromMinutes($ConnectionLifetimeMinutes)
            $sessionObject.Metrics = $metrics

            # Store session in script scope for potential retrieval
            if (-not $script:RedfishSessions) {
                $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            $script:RedfishSessions.Add($sessionObject)

            Write-Verbose 'Redfish session created successfully'
            if ($EnableMetrics) {
                Write-Verbose 'Performance metrics collection enabled. Access via $session.Metrics.GetStatistics()'
            }

            return $sessionObject
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"

            # Clean up if HttpClient was created
            if ($null -ne $httpClient) {
                $httpClient.Dispose()
            }
            if ($null -ne $handler) {
                $handler.Dispose()
            }

            throw $_
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
