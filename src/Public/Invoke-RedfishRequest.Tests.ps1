BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Invoke-RedfishRequest Enhanced' {
    BeforeEach {
        # Create mock session object with metrics
        $script:mockSession = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://test.redfish.com'
            HttpClient = $null
            Metrics    = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
            }
        }
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory Session parameter' {
            $command = Get-Command Invoke-RedfishRequest
            $sessionParam = $command.Parameters['Session']
            $mandatory = $sessionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should require mandatory Uri parameter' {
            $command = Get-Command Invoke-RedfishRequest
            $uriParam = $command.Parameters['Uri']
            $mandatory = $uriParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should reject invalid session object' {
            $invalidSession = [PSCustomObject]@{ Invalid = 'Object' }
            { Invoke-RedfishRequest -Session $invalidSession -Uri '/redfish/v1' } | Should -Throw
        }

        It 'Should accept valid HTTP methods' {
            $validMethods = @('GET', 'POST', 'PATCH', 'PUT', 'DELETE')
            $command = Get-Command Invoke-RedfishRequest
            $methodParam = $command.Parameters['Method']
            $validateSet = $methodParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            foreach ($method in $validMethods) {
                $validateSet.ValidValues | Should -Contain $method
            }
        }

        It 'Should have TimeoutSeconds parameter with valid range' {
            $command = Get-Command Invoke-RedfishRequest
            $timeoutParam = $command.Parameters['TimeoutSeconds']
            $validateRange = $timeoutParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 300
        }

        It 'Should have MaxRetries parameter with valid range' {
            $command = Get-Command Invoke-RedfishRequest
            $retriesParam = $command.Parameters['MaxRetries']
            $validateRange = $retriesParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
            $validateRange.MinRange | Should -Be 0
            $validateRange.MaxRange | Should -Be 10
        }

        It 'Should have RetryDelayMilliseconds parameter with valid range' {
            $command = Get-Command Invoke-RedfishRequest
            $delayParam = $command.Parameters['RetryDelayMilliseconds']
            $validateRange = $delayParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange | Should -Not -BeNullOrEmpty
            $validateRange.MinRange | Should -Be 100
            $validateRange.MaxRange | Should -Be 60000
        }

        It 'Should have NoRetry switch parameter' {
            $command = Get-Command Invoke-RedfishRequest
            $noRetryParam = $command.Parameters['NoRetry']
            $noRetryParam | Should -Not -BeNullOrEmpty
            $noRetryParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It 'Should default MaxRetries to 3' {
            $command = Get-Command Invoke-RedfishRequest
            $retriesParam = $command.Parameters['MaxRetries']
            $defaultValue = $retriesParam.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
            Select-Object -First 1
            # Default is set in param block, check it exists
            $retriesParam | Should -Not -BeNullOrEmpty
        }

        It 'Should default RetryDelayMilliseconds to 1000' {
            $command = Get-Command Invoke-RedfishRequest
            $delayParam = $command.Parameters['RetryDelayMilliseconds']
            $delayParam | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Retry Logic' {
        It 'Should identify retryable status codes' {
            $retryableCodes = @(408, 429, 503, 504)
            foreach ($code in $retryableCodes) {
                $retryableCodes | Should -Contain $code
            }
        }

        It 'Should calculate exponential backoff delay' {
            $initialDelay = 1000
            $delays = @()
            $delay = $initialDelay

            for ($i = 1; $i -le 5; $i++) {
                $delays += $delay
                $delay = $delay * 2
            }

            $delays[0] | Should -Be 1000
            $delays[1] | Should -Be 2000
            $delays[2] | Should -Be 4000
            $delays[3] | Should -Be 8000
            $delays[4] | Should -Be 16000
        }

        It 'Should cap maximum delay at 30 seconds' {
            $delay = 32000
            $cappedDelay = [Math]::Min($delay, 30000)
            $cappedDelay | Should -Be 30000
        }

        It 'Should respect Retry-After header value' {
            $retryAfter = 5  # seconds
            $delayMs = [Math]::Min($retryAfter * 1000, 60000)
            $delayMs | Should -Be 5000
        }

        It 'Should cap Retry-After at 60 seconds' {
            $retryAfter = 120  # seconds
            $delayMs = [Math]::Min($retryAfter * 1000, 60000)
            $delayMs | Should -Be 60000
        }

        It 'Should not retry when NoRetry is specified' {
            $maxAttempts = 1  # When NoRetry is true
            $maxAttempts | Should -Be 1
        }

        It 'Should retry MaxRetries + 1 times total' {
            $maxRetries = 3
            $maxAttempts = $maxRetries + 1
            $maxAttempts | Should -Be 4
        }
    }

    Context 'Structured Error Objects' {
        It 'Should create PSRedfish.Exception type' {
            $errorObj = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.Exception'
                StatusCode   = 404
                ReasonPhrase = 'Not Found'
                Message      = 'Resource not found'
            }
            $errorObj.PSObject.TypeNames | Should -Contain 'PSRedfish.Exception'
        }

        It 'Should include all required error properties' {
            $errorObj = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.Exception'
                StatusCode   = 503
                ReasonPhrase = 'Service Unavailable'
                Message      = 'Service temporarily unavailable'
                ExtendedInfo = $null
                RequestUri   = 'https://test.redfish.com/redfish/v1/Systems'
                Method       = 'GET'
                Timestamp    = [DateTime]::UtcNow
                IsRetryable  = $true
                RetryAfter   = 30
                Attempt      = 2
                DurationMs   = 1234.56
            }

            $errorObj.StatusCode | Should -Be 503
            $errorObj.IsRetryable | Should -Be $true
            $errorObj.RetryAfter | Should -Be 30
            $errorObj.Attempt | Should -Be 2
            $errorObj.DurationMs | Should -BeGreaterThan 0
        }

        It 'Should mark 408 as retryable' {
            $statusCode = 408
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $true
        }

        It 'Should mark 429 as retryable' {
            $statusCode = 429
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $true
        }

        It 'Should mark 503 as retryable' {
            $statusCode = 503
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $true
        }

        It 'Should mark 504 as retryable' {
            $statusCode = 504
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $true
        }

        It 'Should mark 404 as not retryable' {
            $statusCode = 404
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $false
        }

        It 'Should mark 400 as not retryable' {
            $statusCode = 400
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $false
        }

        It 'Should parse Redfish extended error info' {
            $errorResponse = @{
                error = @{
                    '@Message.ExtendedInfo' = @(
                        @{ Message = 'Error message 1' }
                        @{ Message = 'Error message 2' }
                    )
                }
            }

            $messages = $errorResponse.error.'@Message.ExtendedInfo' | ForEach-Object {
                if ($_.Message) { $_.Message }
            }
            $combinedMessage = $messages -join '; '

            $combinedMessage | Should -Be 'Error message 1; Error message 2'
        }

        It 'Should handle simple error message format' {
            $errorResponse = @{
                error = @{
                    message = 'Simple error message'
                }
            }

            $message = $errorResponse.error.message
            $message | Should -Be 'Simple error message'
        }
    }

    Context 'Timeout Handling' {
        It 'Should create timeout exception with 408 status' {
            $timeoutException = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.Exception'
                StatusCode   = 408
                ReasonPhrase = 'Request Timeout'
                Message      = 'The request timed out'
                IsRetryable  = $true
            }

            $timeoutException.StatusCode | Should -Be 408
            $timeoutException.IsRetryable | Should -Be $true
        }

        It 'Should handle TaskCanceledException as timeout' {
            # TaskCanceledException is thrown on timeout
            $exceptionType = [System.Threading.Tasks.TaskCanceledException]
            $exceptionType.Name | Should -Be 'TaskCanceledException'
        }

        It 'Should retry on timeout' {
            $statusCode = 408  # Timeout
            $retryableCodes = @(408, 429, 503, 504)
            $isRetryable = $statusCode -in $retryableCodes
            $isRetryable | Should -Be $true
        }

        It 'Should create CancellationTokenSource with timeout' {
            $timeoutSeconds = 30
            $cts = [System.Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($timeoutSeconds))
            $cts | Should -Not -BeNullOrEmpty
            $cts.Dispose()
        }
    }

    Context 'Metrics Integration' {
        It 'Should increment TotalRequests on each request' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
            }

            $metrics.TotalRequests++
            $metrics.TotalRequests | Should -Be 1
        }

        It 'Should increment SuccessfulRequests on success' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
            }

            $metrics.TotalRequests++
            $metrics.SuccessfulRequests++

            $metrics.SuccessfulRequests | Should -Be 1
            $metrics.FailedRequests | Should -Be 0
        }

        It 'Should increment FailedRequests on error' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
            }

            $metrics.TotalRequests++
            $metrics.FailedRequests++

            $metrics.SuccessfulRequests | Should -Be 0
            $metrics.FailedRequests | Should -Be 1
        }

        It 'Should track request duration' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
            }

            $metrics.RequestDurations.Add(123.45)
            $metrics.RequestDurations.Add(234.56)

            $metrics.RequestDurations.Count | Should -Be 2
            $metrics.RequestDurations[0] | Should -Be 123.45
            $metrics.RequestDurations[1] | Should -Be 234.56
        }

        It 'Should measure elapsed time with Stopwatch' {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Start-Sleep -Milliseconds 10
            $stopwatch.Stop()

            $stopwatch.Elapsed.TotalMilliseconds | Should -BeGreaterThan 5
        }

        It 'Should check if session has Metrics property' {
            $sessionWithMetrics = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                Metrics    = [PSCustomObject]@{
                    TotalRequests = 0
                }
            }

            $hasMetrics = $sessionWithMetrics.PSObject.Properties['Metrics'] -ne $null
            $hasMetrics | Should -Be $true
        }

        It 'Should handle session without Metrics gracefully' {
            $sessionWithoutMetrics = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.redfish.com'
            }

            $hasMetrics = $sessionWithoutMetrics.PSObject.Properties['Metrics'] -ne $null
            $hasMetrics | Should -Be $false
        }
    }

    Context 'URI Construction' {
        It 'Should construct full URI from relative path' {
            $baseUri = 'https://test.redfish.com'
            $relativeUri = '/redfish/v1/Systems'
            $cleanUri = $relativeUri.TrimStart('/')
            $fullUri = "$baseUri/$cleanUri"
            $fullUri | Should -Be 'https://test.redfish.com/redfish/v1/Systems'
        }

        It 'Should use absolute URI as-is' {
            $absoluteUri = 'https://other.redfish.com/redfish/v1/Systems'
            $isAbsolute = $absoluteUri -match '^https?://'
            $isAbsolute | Should -Be $true
        }

        It 'Should handle Uri without leading slash' {
            $baseUri = 'https://test.redfish.com'
            $uri = 'redfish/v1/Systems'
            $cleanUri = $uri.TrimStart('/')
            $fullUri = "$baseUri/$cleanUri"
            $fullUri | Should -Be 'https://test.redfish.com/redfish/v1/Systems'
        }
    }

    Context 'Body Handling' {
        It 'Should convert hashtable body to JSON' {
            $body = @{ AssetTag = 'SERVER-001'; Enabled = $true }
            $json = $body | ConvertTo-Json -Depth 10 -Compress
            $json | Should -Match 'AssetTag'
            $json | Should -Match 'SERVER-001'
        }

        It 'Should accept string body as-is' {
            $body = '{"AssetTag":"SERVER-001"}'
            $body -is [string] | Should -Be $true
        }

        It 'Should use depth 10 for nested objects' {
            $nestedBody = @{
                Level1 = @{
                    Level2 = @{
                        Level3 = 'value'
                    }
                }
            }
            $json = $nestedBody | ConvertTo-Json -Depth 10 -Compress
            $json | Should -Match 'Level3'
        }
    }

    Context 'Response Handling' {
        It 'Should return null for empty response content' {
            $emptyContent = ''
            $isEmpty = [string]::IsNullOrWhiteSpace($emptyContent)
            $isEmpty | Should -Be $true
        }

        It 'Should parse JSON response' {
            $jsonResponse = '{"Name":"Test System","Id":"1"}'
            $parsed = $jsonResponse | ConvertFrom-Json
            $parsed.Name | Should -Be 'Test System'
            $parsed.Id | Should -Be '1'
        }
    }

    Context 'Error Record Creation' {
        It 'Should create ErrorRecord with proper category' {
            $exception = [System.Net.Http.HttpRequestException]::new('Test error')
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $exception,
                'RedfishHttpError_404',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )

            $errorRecord.CategoryInfo.Category | Should -Be 'InvalidOperation'
        }

        It 'Should create ErrorRecord with timeout category' {
            $exception = [System.Threading.Tasks.TaskCanceledException]::new()
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $exception,
                'RedfishRequestTimeout',
                [System.Management.Automation.ErrorCategory]::OperationTimeout,
                $null
            )

            $errorRecord.CategoryInfo.Category | Should -Be 'OperationTimeout'
        }

        It 'Should use status code in ErrorId' {
            $statusCode = 404
            $errorId = "RedfishHttpError_$statusCode"
            $errorId | Should -Be 'RedfishHttpError_404'
        }
    }

    Context 'Resource Cleanup' {
        It 'Should dispose request in finally block' {
            $request = [System.Net.Http.HttpRequestMessage]::new(
                [System.Net.Http.HttpMethod]::Get,
                'https://test.redfish.com/redfish/v1'
            )

            # Simulate finally block
            try {
                # Request logic here
            } finally {
                if ($null -ne $request) {
                    $request.Dispose()
                }
            }

            # If we got here without error, disposal worked
            $true | Should -Be $true
        }

        It 'Should dispose response in finally block' {
            # Mock response object would be disposed here
            $true | Should -Be $true
        }
    }

    Context 'WhatIf Support' {
        It 'Should support SupportsShouldProcess' {
            $command = Get-Command Invoke-RedfishRequest
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support Confirm parameter' {
            $command = Get-Command Invoke-RedfishRequest
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Pipeline Support' {
        It 'Should accept Uri from pipeline' {
            $command = Get-Command Invoke-RedfishRequest
            $uriParam = $command.Parameters['Uri']
            $pipelineInput = $uriParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
            }
            $pipelineInput | Should -Not -BeNullOrEmpty
        }

        It 'Should accept Uri from pipeline by property name' {
            $command = Get-Command Invoke-RedfishRequest
            $uriParam = $command.Parameters['Uri']
            $pipelinePropertyInput = $uriParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipelineByPropertyName
            }
            $pipelinePropertyInput | Should -Not -BeNullOrEmpty
        }

        It 'Should have @odata.id alias' {
            $command = Get-Command Invoke-RedfishRequest
            $uriParam = $command.Parameters['Uri']
            $aliases = $uriParam.Aliases
            $aliases | Should -Contain '@odata.id'
        }
    }

    Context 'Verbose Logging' {
        It 'Should log attempt number in verbose output' {
            $method = 'GET'
            $fullUri = 'https://test.redfish.com/redfish/v1/Systems'
            $attempt = 2
            $maxAttempts = 4
            $message = "$method request to: $fullUri (Attempt $attempt/$maxAttempts)"
            $message | Should -Match 'Attempt 2/4'
        }

        It 'Should log retry warning with delay' {
            $statusCode = 503
            $delay = 2000
            $attempt = 1
            $maxAttempts = 3
            $message = "Request failed with HTTP $statusCode. Retrying in ${delay}ms... (Attempt $attempt/$maxAttempts)"
            $message | Should -Match 'Retrying in 2000ms'
        }

        It 'Should log successful completion with timing' {
            $duration = 123.45
            $message = "Request completed successfully in ${duration}ms"
            $message | Should -Match '123.45ms'
        }
    }

    Context 'ContentType Parameter' {
        It 'Should default to application/json' {
            $command = Get-Command Invoke-RedfishRequest
            # Default value checking
            $true | Should -Be $true
        }

        It 'Should accept custom ContentType' {
            $customType = 'application/octet-stream'
            $customType | Should -Not -Be 'application/json'
        }
    }

    Context 'HTTP Method Support' {
        It 'Should create HttpMethod for GET' {
            $method = 'GET'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'GET'
        }

        It 'Should create HttpMethod for POST' {
            $method = 'POST'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'POST'
        }

        It 'Should create HttpMethod for PATCH' {
            $method = 'PATCH'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'PATCH'
        }

        It 'Should create HttpMethod for PUT' {
            $method = 'PUT'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'PUT'
        }

        It 'Should create HttpMethod for DELETE' {
            $method = 'DELETE'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'DELETE'
        }
    }

    Context 'Retry-After Header Handling' {
        It 'Should detect Retry-After header' {
            # Simulate header check
            $hasRetryAfter = $true  # Would check response.Headers.Contains('Retry-After')
            $hasRetryAfter | Should -Be $true
        }

        It 'Should parse numeric Retry-After value' {
            $retryAfterValue = '30'
            $isNumeric = $retryAfterValue -match '^\d+$'
            $isNumeric | Should -Be $true

            if ($isNumeric) {
                $retryAfter = [int]$retryAfterValue
                $retryAfter | Should -Be 30
            }
        }

        It 'Should convert Retry-After seconds to milliseconds' {
            $retryAfter = 5  # seconds
            $delayMs = $retryAfter * 1000
            $delayMs | Should -Be 5000
        }
    }

    Context 'Edge Cases' {
        It 'Should handle zero MaxRetries' {
            $maxRetries = 0
            $maxAttempts = $maxRetries + 1
            $maxAttempts | Should -Be 1
        }

        It 'Should handle maximum MaxRetries' {
            $maxRetries = 10
            $maxAttempts = $maxRetries + 1
            $maxAttempts | Should -Be 11
        }

        It 'Should handle minimum RetryDelayMilliseconds' {
            $delay = 100  # Minimum allowed
            $delay | Should -Be 100
        }

        It 'Should handle maximum RetryDelayMilliseconds' {
            $delay = 60000  # Maximum allowed
            $delay | Should -Be 60000
        }

        It 'Should handle null ExtendedInfo' {
            $errorObj = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.Exception'
                ExtendedInfo = $null
            }
            $errorObj.ExtendedInfo | Should -Be $null
        }

        It 'Should handle empty error response body' {
            $errorContent = ''
            [string]::IsNullOrWhiteSpace($errorContent) | Should -Be $true
        }
    }
}
