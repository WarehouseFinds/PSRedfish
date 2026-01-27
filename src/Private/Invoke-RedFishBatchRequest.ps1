function Invoke-RedfishBatchRequest {
    <#
.SYNOPSIS
    Invokes multiple Redfish requests in parallel for high performance.

.DESCRIPTION
    Executes multiple HTTP requests concurrently against a Redfish endpoint.
    Useful for fetching multiple resources simultaneously (e.g., all systems, all chassis).
    Automatically handles errors and returns results in the same order as input.

.PARAMETER Session
    The Redfish session object.

.PARAMETER Requests
    Array of hashtables containing Uri, Method, and optionally Body.
    Example: @{Uri='/redfish/v1/Systems/1'; Method='GET'}

.PARAMETER MaxConcurrency
    Maximum number of concurrent requests. Default is 10.

.PARAMETER ContinueOnError
    If specified, continues processing remaining requests even if some fail.
    Failed requests will return error objects instead of throwing.

.EXAMPLE
    $requests = @(
        @{Uri='/redfish/v1/Systems/1'; Method='GET'}
        @{Uri='/redfish/v1/Systems/2'; Method='GET'}
        @{Uri='/redfish/v1/Chassis/1'; Method='GET'}
    )
    $results = Invoke-RedfishBatchRequest -Session $session -Requests $requests

.EXAMPLE
    # Fetch all members from a collection
    $systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
    $requests = $systems.Members | ForEach-Object {
        @{Uri = $_.'@odata.id'; Method = 'GET'}
    }
    $allSystems = Invoke-RedfishBatchRequest -Session $session -Requests $requests

.OUTPUTS
    Array of response objects or error objects (if ContinueOnError is specified)
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [ValidateScript({
                if ($_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object'
                }
            })]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]
        $Requests,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]
        $MaxConcurrency = 10,

        [Parameter()]
        [switch]
        $ContinueOnError
    )

    begin {
        Write-Verbose "Starting batch request with $($Requests.Count) requests (max concurrency: $MaxConcurrency)"
    }

    process {
        try {
            $results = [System.Collections.ArrayList]::new()
            $tasks = [System.Collections.ArrayList]::new()
            $semaphore = [System.Threading.SemaphoreSlim]::new($MaxConcurrency, $MaxConcurrency)

            foreach ($req in $Requests) {
                # Validate request structure
                if (-not $req.ContainsKey('Uri')) {
                    throw 'Each request must contain a Uri key'
                }

                $uri = $req.Uri
                $method = if ($req.ContainsKey('Method')) { $req.Method } else { 'GET' }
                $body = if ($req.ContainsKey('Body')) { $req.Body } else { $null }

                # Construct full URI
                $fullUri = if ($uri -match '^https?://') {
                    $uri
                } else {
                    $cleanUri = $uri.TrimStart('/')
                    "$($Session.BaseUri)/$cleanUri"
                }

                Write-Verbose "Queuing request: $method $fullUri"

                # Wait for semaphore slot
                $null = $semaphore.Wait()

                # Create request
                $httpMethod = [System.Net.Http.HttpMethod]::new($method)
                $request = [System.Net.Http.HttpRequestMessage]::new($httpMethod, $fullUri)

                if ($null -ne $body) {
                    $jsonBody = if ($body -is [string]) {
                        $body
                    } else {
                        $body | ConvertTo-Json -Depth 10 -Compress
                    }

                    $request.Content = [System.Net.Http.StringContent]::new(
                        $jsonBody,
                        [System.Text.Encoding]::UTF8,
                        'application/json'
                    )
                }

                # Send async request
                $task = $Session.HttpClient.SendAsync($request)

                # Add continuation to release semaphore
                $continuationTask = $task.ContinueWith([Action[System.Threading.Tasks.Task[System.Net.Http.HttpResponseMessage]]] {
                        param($t)
                        $semaphore.Release() | Out-Null
                    })

                $null = $tasks.Add(@{
                        Task        = $task
                        Request     = $req
                        HttpRequest = $request
                    })
            }

            Write-Verbose 'All requests queued. Waiting for completion...'

            # Wait for all tasks
            $allTasks = $tasks | ForEach-Object { $_.Task }
            [System.Threading.Tasks.Task]::WaitAll($allTasks)

            Write-Verbose 'All requests completed. Processing results...'

            # Process results in order
            foreach ($taskInfo in $tasks) {
                try {
                    $response = $taskInfo.Task.Result

                    if ($response.IsSuccessStatusCode) {
                        $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

                        if ([string]::IsNullOrWhiteSpace($content)) {
                            $null = $results.Add($null)
                        } else {
                            $result = $content | ConvertFrom-Json
                            $null = $results.Add($result)
                        }
                    } else {
                        # Handle error response
                        $errorContent = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        $statusCode = [int]$response.StatusCode

                        $errorObject = [PSCustomObject]@{
                            PSTypeName   = 'PSRedfish.BatchError'
                            StatusCode   = $statusCode
                            ReasonPhrase = $response.ReasonPhrase
                            Message      = $errorContent
                            RequestUri   = $taskInfo.Request.Uri
                            Method       = if ($taskInfo.Request.ContainsKey('Method')) { $taskInfo.Request.Method } else { 'GET' }
                        }

                        if ($ContinueOnError) {
                            Write-Warning "Request failed: $($taskInfo.Request.Method) $($taskInfo.Request.Uri) - HTTP $statusCode"
                            $null = $results.Add($errorObject)
                        } else {
                            throw "Batch request failed at $($taskInfo.Request.Uri): HTTP $statusCode - $($response.ReasonPhrase)"
                        }
                    }

                    $response.Dispose()
                } catch {
                    if ($ContinueOnError) {
                        $errorObject = [PSCustomObject]@{
                            PSTypeName = 'PSRedfish.BatchError'
                            Message    = $_.Exception.Message
                            RequestUri = $taskInfo.Request.Uri
                            Method     = if ($taskInfo.Request.ContainsKey('Method')) { $taskInfo.Request.Method } else { 'GET' }
                        }
                        Write-Warning "Request failed: $($taskInfo.Request.Method) $($taskInfo.Request.Uri) - $($_.Exception.Message)"
                        $null = $results.Add($errorObject)
                    } else {
                        throw
                    }
                } finally {
                    $taskInfo.HttpRequest.Dispose()
                }
            }

            $semaphore.Dispose()

            Write-Verbose "Batch request completed successfully. Processed $($results.Count) results."

            return $results.ToArray()
        } catch {
            Write-Error "Batch request failed: $_"
            throw
        }
    }
}

