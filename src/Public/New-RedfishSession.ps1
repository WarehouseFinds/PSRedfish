function New-RedfishSession {
    <#
    .SYNOPSIS
        Creates a new Redfish session to a DMTF Redfish® API endpoint.

    .DESCRIPTION
        Establishes an authenticated session to a Redfish API endpoint using either Basic authentication
        or Redfish session-based authentication. Session-based authentication is more secure and recommended.
        Returns a session object that can be used with other Redfish cmdlets.
        Uses .NET HttpClient for optimal performance.

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

    .EXAMPLE
        $cred = Get-Credential
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred
        Creates a new Redfish session using session-based authentication (default).

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred -AuthMethod Basic
        Creates a new Redfish session using HTTP Basic authentication.

    .EXAMPLE
        $session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -SkipCertificateCheck
        Creates a new Redfish session, skipping SSL certificate validation.

    .OUTPUTS
        PSCustomObject representing the Redfish session with HttpClient and session details.

    .NOTES
        The session object contains an HttpClient instance that should be disposed when no longer needed.
        Use Remove-RedfishSession to properly clean up the session.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
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
        $TimeoutSeconds = 30
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

            # Create HttpClientHandler with certificate validation settings
            $handler = [System.Net.Http.HttpClientHandler]::new()

            if ($SkipCertificateCheck) {
                Write-Warning 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
                $handler.ServerCertificateCustomValidationCallback = { $true }
            }

            # Enable automatic decompression
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate

            # Create HttpClient
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.Timeout = [System.TimeSpan]::FromSeconds($TimeoutSeconds)
            $httpClient.DefaultRequestHeaders.Clear()

            # Set default headers for Redfish
            $httpClient.DefaultRequestHeaders.Add('Accept', 'application/json')
            $httpClient.DefaultRequestHeaders.Add('OData-Version', '4.0')

            $username = $Credential.UserName
            $password = $Credential.GetNetworkCredential().Password
            $sessionToken = $null
            $sessionUri = $null

            if ($AuthMethod -eq 'Session') {
                # Create Redfish session for token-based authentication
                Write-Verbose 'Creating Redfish session with token authentication'

                # First, use Basic auth to create the session
                $encodedAuth = [System.Convert]::ToBase64String(
                    [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
                )
                $httpClient.DefaultRequestHeaders.Add('Authorization', "Basic $encodedAuth")

                $sessionBody = @{
                    UserName = $username
                    Password = $password
                } | ConvertTo-Json

                $sessionContent = [System.Net.Http.StringContent]::new(
                    $sessionBody,
                    [System.Text.Encoding]::UTF8,
                    'application/json'
                )

                $sessionResponse = $httpClient.PostAsync("$normalizedUri/redfish/v1/SessionService/Sessions", $sessionContent).GetAwaiter().GetResult()

                if (-not $sessionResponse.IsSuccessStatusCode) {
                    $errorContent = $sessionResponse.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    throw "Failed to create Redfish session. Status: $($sessionResponse.StatusCode) - $($sessionResponse.ReasonPhrase): $errorContent"
                }

                # Extract X-Auth-Token from response headers
                if ($sessionResponse.Headers.Contains('X-Auth-Token')) {
                    $sessionToken = $sessionResponse.Headers.GetValues('X-Auth-Token')[0]
                    Write-Verbose 'Session token obtained successfully'
                } else {
                    throw 'Server did not return X-Auth-Token header. Session authentication may not be supported.'
                }

                # Extract session Location URI
                if ($sessionResponse.Headers.Contains('Location')) {
                    $sessionUri = $sessionResponse.Headers.GetValues('Location')[0]
                    Write-Verbose "Session created at: $sessionUri"
                }

                # Remove Basic auth and add token authentication
                $httpClient.DefaultRequestHeaders.Remove('Authorization')
                $httpClient.DefaultRequestHeaders.Add('X-Auth-Token', $sessionToken)

                $sessionContent.Dispose()
                $sessionResponse.Dispose()
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

            # Create session object
            $sessionObject = [PSCustomObject]@{
                PSTypeName           = 'PSRedfish.Session'
                BaseUri              = $normalizedUri
                ServiceRoot          = $serviceRoot
                HttpClient           = $httpClient
                AuthMethod           = $AuthMethod
                SessionToken         = $sessionToken
                SessionUri           = $sessionUri
                CreatedAt            = [DateTime]::UtcNow
                TimeoutSeconds       = $TimeoutSeconds
                Username             = $username
                SkipCertificateCheck = $SkipCertificateCheck.IsPresent
            }

            # Store session in script scope for potential retrieval
            if (-not $script:RedfishSessions) {
                $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
            }
            $script:RedfishSessions.Add($sessionObject)

            Write-Verbose 'Redfish session created successfully'
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
