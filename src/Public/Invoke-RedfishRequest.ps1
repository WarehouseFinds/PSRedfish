function Invoke-RedfishRequest {
    <#
    .SYNOPSIS
        Invokes a request against a Redfish API endpoint.

    .DESCRIPTION
        Executes an HTTP request (GET, POST, PATCH, PUT, DELETE) against a Redfish API endpoint
        using an established session. Supports both relative and absolute URIs.
        Uses .NET HttpClient for optimal performance.

    .PARAMETER Session
        The Redfish session object created by New-RedfishSession.

    .PARAMETER Uri
        The URI to request. Can be relative (e.g., '/redfish/v1/Systems') or absolute.
        If relative, it will be appended to the session's BaseUri.

    .PARAMETER Method
        The HTTP method to use. Default is GET.

    .PARAMETER Body
        The request body as a hashtable or PSCustomObject. Will be converted to JSON.

    .PARAMETER ContentType
        The Content-Type header for the request. Default is 'application/json'.

    .EXAMPLE
        $systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
        Gets the list of computer systems.

    .EXAMPLE
        $body = @{ AssetTag = 'SERVER-001' }
        Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $body
        Updates the AssetTag property of a system.

    .EXAMPLE
        $result = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/SessionService/Sessions' -Method POST -Body @{ UserName = 'admin'; Password = 'secret' }
        Creates a new Redfish session (alternative authentication method).

    .OUTPUTS
        PSCustomObject containing the response data from the Redfish API.

    .NOTES
        For DELETE operations that return no content, returns $null.
        Automatically handles JSON serialization and deserialization.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNull()]
        [ValidateScript({
                if ($_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object created by New-RedfishSession'
                }
            })]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory, Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('@odata.id', 'Path')]
        [string]
        $Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [string]
        $Method = 'GET',

        [Parameter()]
        [ValidateNotNull()]
        [object]
        $Body,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/json'
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            # Construct full URI
            $fullUri = if ($Uri -match '^https?://') {
                $Uri
            } else {
                # Remove leading slash if present to avoid double slashes
                $cleanUri = $Uri.TrimStart('/')
                "$($Session.BaseUri)/$cleanUri"
            }

            Write-Verbose "$Method request to: $fullUri"

            # Create HTTP request message
            $httpMethod = [System.Net.Http.HttpMethod]::new($Method)
            $request = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $fullUri)

            # Add body if provided
            if ($PSBoundParameters.ContainsKey('Body')) {
                $jsonBody = if ($Body -is [string]) {
                    $Body
                } else {
                    $Body | ConvertTo-Json -Depth 10 -Compress
                }

                Write-Verbose "Request body: $jsonBody"
                $request.Content = [System.Net.Http.StringContent]::new(
                    $jsonBody,
                    [System.Text.Encoding]::UTF8,
                    $ContentType
                )
            }

            if ($PSCmdlet.ShouldProcess($fullUri, "$Method request")) {
                # Send request
                $response = $Session.HttpClient.SendAsync($request).GetAwaiter().GetResult()

                # Check for successful status code
                if (-not $response.IsSuccessStatusCode) {
                    $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                    $statusCode = [int]$response.StatusCode

                    try {
                        $errorObject = $errorContent | ConvertFrom-Json
                        $errorMessage = if ($errorObject.error.'@Message.ExtendedInfo') {
                            $errorObject.error.'@Message.ExtendedInfo'.Message -join '; '
                        } elseif ($errorObject.error.message) {
                            $errorObject.error.message
                        } else {
                            $errorContent
                        }
                    } catch {
                        $errorMessage = $errorContent
                    }

                    throw "HTTP $statusCode - $($response.ReasonPhrase): $errorMessage"
                }

                # Read response content
                $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                # Return null for empty responses (common with DELETE)
                if ([string]::IsNullOrWhiteSpace($content)) {
                    Write-Verbose 'Request completed successfully (no content returned)'
                    return $null
                }

                # Parse JSON response
                $result = $content | ConvertFrom-Json
                Write-Verbose 'Request completed successfully'

                return $result
            }
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"
            throw $_
        } finally {
            if ($null -ne $request) {
                $request.Dispose()
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
