function Invoke-RedfishRequest {
    <#
    .SYNOPSIS
        Invokes a request against a Redfish API endpoint with retry logic and enhanced error handling.

    .DESCRIPTION
        Executes an HTTP request (GET, POST, PATCH, PUT, DELETE) against a Redfish API endpoint
        using an established session. Supports both relative and absolute URIs.
        Includes automatic retry logic for transient failures and structured error objects.
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

    .PARAMETER TimeoutSeconds
        Override the session's default timeout for this specific request.

    .PARAMETER MaxRetries
        Maximum number of retry attempts for transient failures. Default is 3.
        Set to 0 to disable retries.

    .PARAMETER RetryDelayMilliseconds
        Initial delay between retries in milliseconds. Default is 1000 (1 second).
        Delay increases exponentially with each retry.

    .PARAMETER NoRetry
        Disable retry logic for this request. Useful for operations that should fail fast.

    .EXAMPLE
        $systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
        Gets the list of computer systems.

    .EXAMPLE
        $body = @{ AssetTag = 'SERVER-001' }
        Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $body
        Updates the AssetTag property of a system with automatic retry on transient failures.

    .EXAMPLE
        $result = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -NoRetry
        Gets system information without retry logic.

    .OUTPUTS
        PSCustomObject containing the response data from the Redfish API.

    .NOTES
        For DELETE operations that return no content, returns $null.
        Automatically retries on HTTP 408, 429, 503, 504 status codes.
        Throws structured RedfishException objects for easier error handling.
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
        $ContentType = 'application/json',

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]
        $TimeoutSeconds,

        [Parameter()]
        [ValidateRange(0, 10)]
        [int]
        $MaxRetries = 3,

        [Parameter()]
        [ValidateRange(100, 60000)]
        [int]
        $RetryDelayMilliseconds = 1000,

        [Parameter()]
        [switch]
        $NoRetry
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        $attempt = 0
        $delay = $RetryDelayMilliseconds
        $maxAttempts = if ($NoRetry) { 1 } else { $MaxRetries + 1 }

        while ($attempt -lt $maxAttempts) {
            $attempt++
            $request = $null
            $response = $null
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

            try {
                # Construct full URI
                $fullUri = if ($Uri -match '^https?://') {
                    $Uri
                } else {
                    $cleanUri = $Uri.TrimStart('/')
                    "$($Session.BaseUri)/$cleanUri"
                }

                Write-Verbose "$Method request to: $fullUri (Attempt $attempt/$maxAttempts)"

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
                    # Handle per-request timeout
                    if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
                        $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
                        try {
                            $response = $Session.HttpClient.SendAsync($request, $cts.Token).GetAwaiter().GetResult()
                        } finally {
                            $cts.Dispose()
                        }
                    } else {
                        $response = $Session.HttpClient.SendAsync($request).GetAwaiter().GetResult()
                    }

                    $stopwatch.Stop()

                    # Update metrics if available
                    if ($Session.PSObject.Properties['Metrics']) {
                        $Session.Metrics.TotalRequests++
                        $Session.Metrics.RequestDurations.Add($stopwatch.Elapsed.TotalMilliseconds)
                    }

                    # Check for successful status code
                    if (-not $response.IsSuccessStatusCode) {
                        $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        $statusCode = [int]$response.StatusCode

                        # Parse Redfish error format
                        $errorObject = $null
                        $errorMessage = $errorContent
                        $extendedInfo = $null

                        try {
                            $errorObject = $errorContent | ConvertFrom-Json
                            if ($errorObject.error) {
                                if ($errorObject.error.'@Message.ExtendedInfo') {
                                    $messages = $errorObject.error.'@Message.ExtendedInfo' | ForEach-Object {
                                        if ($_.Message) { $_.Message }
                                    }
                                    $errorMessage = $messages -join '; '
                                    $extendedInfo = $errorObject.error.'@Message.ExtendedInfo'
                                } elseif ($errorObject.error.message) {
                                    $errorMessage = $errorObject.error.message
                                }
                            }
                        } catch {
                            Write-Verbose "Could not parse error response as JSON: $_"
                        }

                        # Determine if error is retryable
                        $retryableCodes = @(408, 429, 503, 504)  # Request Timeout, Too Many Requests, Service Unavailable, Gateway Timeout
                        $isRetryable = $statusCode -in $retryableCodes

                        # Check for Retry-After header (for 429 and 503)
                        $retryAfter = $null
                        if ($response.Headers.Contains('Retry-After')) {
                            $retryAfterValue = $response.Headers.GetValues('Retry-After')[0]
                            if ($retryAfterValue -match '^\d+$') {
                                $retryAfter = [int]$retryAfterValue
                            }
                        }

                        # Create structured error object
                        $redfishException = [PSCustomObject]@{
                            PSTypeName   = 'PSRedfish.Exception'
                            StatusCode   = $statusCode
                            ReasonPhrase = $response.ReasonPhrase
                            Message      = $errorMessage
                            ExtendedInfo = $extendedInfo
                            RequestUri   = $fullUri
                            Method       = $Method
                            Timestamp    = [DateTime]::UtcNow
                            IsRetryable  = $isRetryable
                            RetryAfter   = $retryAfter
                            Attempt      = $attempt
                            DurationMs   = $stopwatch.Elapsed.TotalMilliseconds
                        }

                        # Update failure metrics
                        if ($Session.PSObject.Properties['Metrics']) {
                            $Session.Metrics.FailedRequests++
                        }

                        # Decide whether to retry
                        if ($isRetryable -and $attempt -lt $maxAttempts -and -not $NoRetry) {
                            $actualDelay = if ($retryAfter) {
                                [Math]::Min($retryAfter * 1000, 60000)  # Max 60 seconds
                            } else {
                                [Math]::Min($delay, 30000)  # Max 30 seconds
                            }

                            Write-Warning "Request failed with HTTP $statusCode. Retrying in ${actualDelay}ms... (Attempt $attempt/$maxAttempts)"
                            Start-Sleep -Milliseconds $actualDelay
                            $delay = $delay * 2  # Exponential backoff
                            continue  # Retry
                        }

                        # Not retryable or max retries reached - throw error
                        $errorRecordMessage = "HTTP $statusCode - $($response.ReasonPhrase): $errorMessage"

                        $exception = [System.Net.Http.HttpRequestException]::new(
                            $errorRecordMessage,
                            $null,
                            $statusCode
                        )

                        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                            $exception,
                            "RedfishHttpError_$statusCode",
                            [System.Management.Automation.ErrorCategory]::InvalidOperation,
                            $redfishException
                        )

                        throw $errorRecord
                    }

                    # Success - update metrics
                    if ($Session.PSObject.Properties['Metrics']) {
                        $Session.Metrics.SuccessfulRequests++
                    }

                    # Read response content
                    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                    # Return null for empty responses (common with DELETE)
                    if ([string]::IsNullOrWhiteSpace($content)) {
                        Write-Verbose "Request completed successfully in $($stopwatch.Elapsed.TotalMilliseconds)ms (no content returned)"
                        return $null
                    }

                    # Parse JSON response
                    $result = $content | ConvertFrom-Json
                    Write-Verbose "Request completed successfully in $($stopwatch.Elapsed.TotalMilliseconds)ms"

                    return $result
                }
            } catch [System.Threading.Tasks.TaskCanceledException] {
                # Timeout exception
                $stopwatch.Stop()

                Write-Verbose "Request timed out after $($stopwatch.Elapsed.TotalSeconds)s"

                # Update metrics
                if ($Session.PSObject.Properties['Metrics']) {
                    $Session.Metrics.TotalRequests++
                    $Session.Metrics.FailedRequests++
                }

                # Create timeout error
                $timeoutException = [PSCustomObject]@{
                    PSTypeName   = 'PSRedfish.Exception'
                    StatusCode   = 408
                    ReasonPhrase = 'Request Timeout'
                    Message      = 'The request timed out'
                    RequestUri   = $fullUri
                    Method       = $Method
                    Timestamp    = [DateTime]::UtcNow
                    IsRetryable  = $true
                    Attempt      = $attempt
                    DurationMs   = $stopwatch.Elapsed.TotalMilliseconds
                }

                # Retry on timeout if not at max attempts
                if ($attempt -lt $maxAttempts -and -not $NoRetry) {
                    Write-Warning "Request timed out. Retrying in ${delay}ms... (Attempt $attempt/$maxAttempts)"
                    Start-Sleep -Milliseconds $delay
                    $delay = $delay * 2
                    continue
                }

                # Max retries reached
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $_,
                    'RedfishRequestTimeout',
                    [System.Management.Automation.ErrorCategory]::OperationTimeout,
                    $timeoutException
                )
                throw $errorRecord
            } catch {
                Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
                Write-Verbose "StackTrace: $($_.ScriptStackTrace)"

                # If this is already a structured error, just re-throw it
                if ($_.TargetObject.PSTypeName -eq 'PSRedfish.Exception') {
                    throw
                }

                # For other exceptions, wrap them
                throw $_
            } finally {
                if ($null -ne $request) {
                    $request.Dispose()
                }
                if ($null -ne $response) {
                    $response.Dispose()
                }
            }
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
