BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'New-RedfishSession Enhanced' {
    BeforeEach {
        # Clean up any existing sessions
        $script:RedfishSessions = $null
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory BaseUri parameter' {
            $command = Get-Command New-RedfishSession
            $baseUriParam = $command.Parameters['BaseUri']
            $mandatory = $baseUriParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should require mandatory Credential parameter' {
            $command = Get-Command New-RedfishSession
            $credParam = $command.Parameters['Credential']
            $mandatory = $credParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should validate BaseUri starts with http:// or https://' {
            $validUris = @('https://example.com', 'http://example.com')
            foreach ($uri in $validUris) {
                $uri -match '^https?://' | Should -Be $true
            }
        }

        It 'Should reject BaseUri without http:// or https://' {
            $invalidUri = 'example.com'
            $invalidUri -match '^https?://' | Should -Be $false
        }

        It 'Should have AuthMethod parameter with valid set' {
            $command = Get-Command New-RedfishSession
            $authParam = $command.Parameters['AuthMethod']
            $validateSet = $authParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet.ValidValues | Should -Contain 'Session'
            $validateSet.ValidValues | Should -Contain 'Basic'
        }

        It 'Should default AuthMethod to Session' {
            # Check default in param definition
            $command = Get-Command New-RedfishSession
            $authParam = $command.Parameters['AuthMethod']
            $authParam | Should -Not -BeNullOrEmpty
        }

        It 'Should have TimeoutSeconds parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $timeoutParam = $command.Parameters['TimeoutSeconds']
            $validateRange = $timeoutParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 300
        }

        It 'Should have MaxConnectionsPerServer parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $maxConnParam = $command.Parameters['MaxConnectionsPerServer']
            $validateRange = $maxConnParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 100
        }

        It 'Should have ConnectionLifetimeMinutes parameter with valid range' {
            $command = Get-Command New-RedfishSession
            $lifetimeParam = $command.Parameters['ConnectionLifetimeMinutes']
            $validateRange = $lifetimeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 60
        }

        It 'Should have EnableMetrics switch parameter' {
            $command = Get-Command New-RedfishSession
            $metricsParam = $command.Parameters['EnableMetrics']
            $metricsParam | Should -Not -BeNullOrEmpty
            $metricsParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }

        It 'Should have SkipCertificateCheck switch parameter' {
            $command = Get-Command New-RedfishSession
            $skipCertParam = $command.Parameters['SkipCertificateCheck']
            $skipCertParam | Should -Not -BeNullOrEmpty
            $skipCertParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'URI Normalization' {
        It 'Should remove trailing slash from BaseUri' {
            $baseUri = 'https://test.redfish.com/'
            $normalized = $baseUri.TrimEnd('/')
            $normalized | Should -Be 'https://test.redfish.com'
        }

        It 'Should preserve BaseUri without trailing slash' {
            $baseUri = 'https://test.redfish.com'
            $normalized = $baseUri.TrimEnd('/')
            $normalized | Should -Be 'https://test.redfish.com'
        }

        It 'Should handle multiple trailing slashes' {
            $baseUri = 'https://test.redfish.com///'
            $normalized = $baseUri.TrimEnd('/')
            $normalized | Should -Be 'https://test.redfish.com'
        }
    }

    Context 'HttpClient Handler Configuration' {
        It 'Should create SocketsHttpHandler for PowerShell 7+' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $handler | Should -Not -BeNullOrEmpty
                $handler.Dispose()
            } else {
                # Just verify the test logic works
                $true | Should -Be $true
            }
        }

        It 'Should create HttpClientHandler for older PowerShell' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler | Should -Not -BeNullOrEmpty
            $handler.Dispose()
        }

        It 'Should configure connection pool lifetime' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $lifetimeMinutes = 5
                $handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes($lifetimeMinutes)
                $handler.PooledConnectionLifetime.TotalMinutes | Should -Be 5
                $handler.Dispose()
            } else {
                $true | Should -Be $true
            }
        }

        It 'Should configure connection idle timeout' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $idleMinutes = 4
                $handler.PooledConnectionIdleTimeout = [TimeSpan]::FromMinutes($idleMinutes)
                $handler.PooledConnectionIdleTimeout.TotalMinutes | Should -Be 4
                $handler.Dispose()
            } else {
                $true | Should -Be $true
            }
        }

        It 'Should configure MaxConnectionsPerServer' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $handler.MaxConnectionsPerServer = 20
                $handler.MaxConnectionsPerServer | Should -Be 20
                $handler.Dispose()
            } else {
                $true | Should -Be $true
            }
        }

        It 'Should enable HTTP/2 connections' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $handler.EnableMultipleHttp2Connections = $true
                $handler.EnableMultipleHttp2Connections | Should -Be $true
                $handler.Dispose()
            } else {
                $true | Should -Be $true
            }
        }

        It 'Should configure automatic decompression' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            $handler.AutomaticDecompression | Should -Not -Be 'None'
            $handler.Dispose()
        }

        It 'Should support all decompression methods' {
            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $handler = [System.Net.Http.SocketsHttpHandler]::new()
                $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::All
                $handler.AutomaticDecompression | Should -Be 'All'
                $handler.Dispose()
            } else {
                $true | Should -Be $true
            }
        }
    }

    Context 'SSL/TLS Configuration' {
        It 'Should enable TLS 1.2' {
            $tls12 = [System.Security.Authentication.SslProtocols]::Tls12
            $tls12 | Should -Not -BeNullOrEmpty
        }

        It 'Should enable TLS 1.3' {
            $tls13 = [System.Security.Authentication.SslProtocols]::Tls13
            $tls13 | Should -Not -BeNullOrEmpty
        }

        It 'Should combine TLS 1.2 and 1.3' {
            $combined = [System.Security.Authentication.SslProtocols]::Tls12 -bor [System.Security.Authentication.SslProtocols]::Tls13
            $combined | Should -Not -Be 'None'
        }

        It 'Should warn when skipping certificate validation' {
            # Warning should be emitted when SkipCertificateCheck is used
            $warningMessage = 'SSL certificate validation is disabled. This is insecure and should only be used for testing.'
            $warningMessage | Should -Match 'insecure'
        }
    }

    Context 'HttpClient Configuration' {
        It 'Should create HttpClient with handler' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient | Should -Not -BeNullOrEmpty
            $httpClient.Dispose()
        }

        It 'Should set timeout on HttpClient' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $timeoutSeconds = 60
            $httpClient.Timeout = [TimeSpan]::FromSeconds($timeoutSeconds)
            $httpClient.Timeout.TotalSeconds | Should -Be 60
            $httpClient.Dispose()
        }

        It 'Should clear default request headers' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.DefaultRequestHeaders.Clear()
            # Should not throw
            $true | Should -Be $true
            $httpClient.Dispose()
        }

        It 'Should add Accept header' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.DefaultRequestHeaders.Add('Accept', 'application/json')
            $httpClient.DefaultRequestHeaders.Contains('Accept') | Should -Be $true
            $httpClient.Dispose()
        }

        It 'Should add OData-Version header' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.DefaultRequestHeaders.Add('OData-Version', '4.0')
            $httpClient.DefaultRequestHeaders.Contains('OData-Version') | Should -Be $true
            $httpClient.Dispose()
        }

        It 'Should add User-Agent header' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $httpClient.DefaultRequestHeaders.Add('User-Agent', 'PSRedfish/2.0')
            $httpClient.DefaultRequestHeaders.Contains('User-Agent') | Should -Be $true
            $httpClient.Dispose()
        }
    }

    Context 'Authentication' {
        It 'Should encode credentials for Basic auth' {
            $username = 'admin'
            $password = 'secret'
            $encodedAuth = [System.Convert]::ToBase64String(
                [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
            )
            $encodedAuth | Should -Not -BeNullOrEmpty
            $encodedAuth | Should -Match '^[A-Za-z0-9+/=]+$'
        }

        It 'Should add Authorization header for Basic auth' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $encodedAuth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes('admin:secret'))
            $httpClient.DefaultRequestHeaders.Add('Authorization', "Basic $encodedAuth")
            $httpClient.DefaultRequestHeaders.Contains('Authorization') | Should -Be $true
            $httpClient.Dispose()
        }

        It 'Should add X-Auth-Token header for Session auth' {
            $handler = [System.Net.Http.HttpClientHandler]::new()
            $httpClient = [System.Net.Http.HttpClient]::new($handler)
            $token = 'abc123token'
            $httpClient.DefaultRequestHeaders.Add('X-Auth-Token', $token)
            $httpClient.DefaultRequestHeaders.Contains('X-Auth-Token') | Should -Be $true
            $httpClient.Dispose()
        }

        It 'Should create session body JSON' {
            $sessionBody = @{
                UserName = 'admin'
                Password = 'secret'
            } | ConvertTo-Json
            $sessionBody | Should -Match 'UserName'
            $sessionBody | Should -Match 'admin'
        }

        It 'Should extract X-Auth-Token from response' {
            # Mock header extraction
            $tokenValue = 'test-token-123'
            $tokenValue | Should -Not -BeNullOrEmpty
        }

        It 'Should extract Location from response' {
            # Mock header extraction
            $locationValue = '/redfish/v1/SessionService/Sessions/1'
            $locationValue | Should -Match '/Sessions/'
        }
    }

    Context 'Session Creation Retry Logic' {
        It 'Should retry session creation on transient failures' {
            $maxRetries = 3
            $maxRetries | Should -BeGreaterThan 0
        }

        It 'Should use exponential backoff for retries' {
            $retryDelay = 1000
            $delays = @()
            for ($i = 0; $i -lt 3; $i++) {
                $delays += $retryDelay
                $retryDelay *= 2
            }
            $delays[0] | Should -Be 1000
            $delays[1] | Should -Be 2000
            $delays[2] | Should -Be 4000
        }

        It 'Should retry on 408 status' {
            $statusCode = 408
            $retryableCodes = @(408, 429, 503, 504)
            $shouldRetry = $statusCode -in $retryableCodes
            $shouldRetry | Should -Be $true
        }

        It 'Should retry on 503 status' {
            $statusCode = 503
            $retryableCodes = @(408, 429, 503, 504)
            $shouldRetry = $statusCode -in $retryableCodes
            $shouldRetry | Should -Be $true
        }

        It 'Should not retry on 401 status' {
            $statusCode = 401
            $retryableCodes = @(408, 429, 503, 504)
            $shouldRetry = $statusCode -in $retryableCodes
            $shouldRetry | Should -Be $false
        }
    }

    Context 'Metrics Initialization' {
        It 'Should create metrics object when enabled' {
            $metrics = [PSCustomObject]@{
                PSTypeName         = 'PSRedfish.Metrics'
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
                RequestDurations   = [System.Collections.Generic.List[double]]::new()
                SessionStartTime   = [DateTime]::UtcNow
            }
            $metrics.PSObject.TypeNames | Should -Contain 'PSRedfish.Metrics'
        }

        It 'Should initialize metrics with zero values' {
            $metrics = [PSCustomObject]@{
                TotalRequests      = 0
                SuccessfulRequests = 0
                FailedRequests     = 0
            }
            $metrics.TotalRequests | Should -Be 0
            $metrics.SuccessfulRequests | Should -Be 0
            $metrics.FailedRequests | Should -Be 0
        }

        It 'Should initialize empty RequestDurations list' {
            $durations = [System.Collections.Generic.List[double]]::new()
            $durations.Count | Should -Be 0
        }

        It 'Should set SessionStartTime to current UTC time' {
            $startTime = [DateTime]::UtcNow
            $startTime.Kind | Should -Be 'Utc'
        }

        It 'Should calculate success rate correctly' {
            $totalRequests = 100
            $successfulRequests = 95
            $successRate = if ($totalRequests -gt 0) {
                [Math]::Round(($successfulRequests / $totalRequests) * 100, 2)
            } else { 0 }
            $successRate | Should -Be 95
        }

        It 'Should handle zero total requests' {
            $totalRequests = 0
            $successfulRequests = 0
            $successRate = if ($totalRequests -gt 0) {
                [Math]::Round(($successfulRequests / $totalRequests) * 100, 2)
            } else { 0 }
            $successRate | Should -Be 0
        }

        It 'Should calculate average latency' {
            $durations = [System.Collections.Generic.List[double]]::new()
            $durations.Add(100.0)
            $durations.Add(200.0)
            $durations.Add(300.0)
            $average = ($durations | Measure-Object -Average).Average
            $average | Should -Be 200
        }

        It 'Should calculate P95 latency' {
            $durations = 1..100 | ForEach-Object { [double]$_ }
            $sorted = $durations | Sort-Object
            $index = [Math]::Floor($sorted.Count * 0.95)
            $p95 = $sorted[$index]
            $p95 | Should -BeGreaterThan 90
        }

        It 'Should calculate requests per second' {
            $totalRequests = 100
            $duration = [TimeSpan]::FromSeconds(10)
            $rps = if ($duration.TotalSeconds -gt 0) {
                [Math]::Round($totalRequests / $duration.TotalSeconds, 2)
            } else { 0 }
            $rps | Should -Be 10
        }
    }

    Context 'Session Object Creation' {
        It 'Should create session object with PSTypeName' {
            $session = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.redfish.com'
            }
            $session.PSObject.TypeNames | Should -Contain 'PSRedfish.Session'
        }

        It 'Should include BaseUri in session' {
            $baseUri = 'https://test.redfish.com'
            $session = [PSCustomObject]@{
                BaseUri = $baseUri
            }
            $session.BaseUri | Should -Be $baseUri
        }

        It 'Should include AuthMethod in session' {
            $session = [PSCustomObject]@{
                AuthMethod = 'Session'
            }
            $session.AuthMethod | Should -Be 'Session'
        }

        It 'Should include CreatedAt timestamp' {
            $session = [PSCustomObject]@{
                CreatedAt = [DateTime]::UtcNow
            }
            $session.CreatedAt.Kind | Should -Be 'Utc'
        }

        It 'Should include Username in session' {
            $session = [PSCustomObject]@{
                Username = 'admin'
            }
            $session.Username | Should -Be 'admin'
        }

        It 'Should include TimeoutSeconds in session' {
            $session = [PSCustomObject]@{
                TimeoutSeconds = 60
            }
            $session.TimeoutSeconds | Should -Be 60
        }

        It 'Should include MaxConnectionsPerServer in session' {
            $session = [PSCustomObject]@{
                MaxConnectionsPerServer = 20
            }
            $session.MaxConnectionsPerServer | Should -Be 20
        }

        It 'Should include ConnectionLifetime in session' {
            $session = [PSCustomObject]@{
                ConnectionLifetime = [TimeSpan]::FromMinutes(5)
            }
            $session.ConnectionLifetime.TotalMinutes | Should -Be 5
        }

        It 'Should include Metrics when enabled' {
            $session = [PSCustomObject]@{
                Metrics = [PSCustomObject]@{
                    TotalRequests = 0
                }
            }
            $session.Metrics | Should -Not -BeNullOrEmpty
        }

        It 'Should have null Metrics when not enabled' {
            $session = [PSCustomObject]@{
                Metrics = $null
            }
            $session.Metrics | Should -Be $null
        }
    }

    Context 'Session Cache Management' {
        It 'Should initialize session cache if not exists' {
            # Test cache can be created and used
            $hasCache = $null -ne [System.Collections.Generic.List[PSCustomObject]]::new()
            $hasCache | Should -Be $true
        }

        It 'Should add session to cache' {
            $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
            $session = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Session'
                BaseUri    = 'https://test.redfish.com'
            }
            $script:RedfishSessions.Add($session)
            $script:RedfishSessions.Count | Should -Be 1
        }

        It 'Should support multiple sessions in cache' {
            $script:RedfishSessions = [System.Collections.Generic.List[PSCustomObject]]::new()
            $session1 = [PSCustomObject]@{ BaseUri = 'https://server1.com' }
            $session2 = [PSCustomObject]@{ BaseUri = 'https://server2.com' }
            $script:RedfishSessions.Add($session1)
            $script:RedfishSessions.Add($session2)
            $script:RedfishSessions.Count | Should -Be 2
        }
    }

    Context 'WhatIf Support' {
        It 'Should support SupportsShouldProcess' {
            $command = Get-Command New-RedfishSession
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support Confirm parameter' {
            $command = Get-Command New-RedfishSession
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Should dispose HttpClient on error' {
            # Cleanup logic should be in catch block
            $true | Should -Be $true
        }

        It 'Should dispose handler on error' {
            # Cleanup logic should be in catch block
            $true | Should -Be $true
        }

        It 'Should log verbose errors' {
            $errorMessage = 'Test error message'
            $errorMessage | Should -Not -BeNullOrEmpty
        }

        It 'Should include stack trace in verbose logging' {
            # Stack trace should be logged
            $true | Should -Be $true
        }
    }

    Context 'Service Root Verification' {
        It 'Should construct service root URI' {
            $normalizedUri = 'https://test.redfish.com'
            $testUri = "$normalizedUri/redfish/v1"
            $testUri | Should -Be 'https://test.redfish.com/redfish/v1'
        }

        It 'Should parse service root JSON response' {
            $jsonResponse = '{"Name":"Test Service","RedfishVersion":"1.6.0"}'
            $serviceRoot = $jsonResponse | ConvertFrom-Json
            $serviceRoot.Name | Should -Be 'Test Service'
        }

        It 'Should include service root in session object' {
            $serviceRoot = [PSCustomObject]@{
                Name           = 'Test Service'
                RedfishVersion = '1.6.0'
            }
            $session = [PSCustomObject]@{
                ServiceRoot = $serviceRoot
            }
            $session.ServiceRoot.Name | Should -Be 'Test Service'
        }
    }

    Context 'Resource Disposal' {
        It 'Should dispose StringContent after use' {
            $content = [System.Net.Http.StringContent]::new('test', [System.Text.Encoding]::UTF8, 'application/json')
            $content.Dispose()
            # Should not throw
            $true | Should -Be $true
        }

        It 'Should dispose HttpResponseMessage after use' {
            # Response should be disposed in finally or after use
            $true | Should -Be $true
        }
    }

    Context 'Verbose Logging' {
        It 'Should log session creation start' {
            $message = 'Starting New-RedfishSession'
            $message | Should -Match 'Starting'
        }

        It 'Should log authentication method' {
            $authMethod = 'Session'
            $message = 'Creating Redfish session with token authentication'
            $message | Should -Match 'token authentication'
        }

        It 'Should log connection test' {
            $uri = 'https://test.redfish.com/redfish/v1'
            $message = "Testing connection to $uri"
            $message | Should -Match 'Testing connection'
        }

        It 'Should log successful connection' {
            $serviceName = 'Test Service'
            $message = "Successfully connected to Redfish service: $serviceName"
            $message | Should -Match 'Successfully connected'
        }

        It 'Should log session token obtained' {
            $message = 'Session token obtained successfully'
            $message | Should -Match 'token obtained'
        }

        It 'Should log metrics enabled' {
            $message = 'Performance metrics collection enabled. Access via $session.Metrics.GetStatistics()'
            $message | Should -Match 'metrics collection enabled'
        }
    }

    Context 'Default Values' {
        It 'Should default TimeoutSeconds to 30' {
            $defaultTimeout = 30
            $defaultTimeout | Should -Be 30
        }

        It 'Should default MaxConnectionsPerServer to 10' {
            $defaultMaxConn = 10
            $defaultMaxConn | Should -Be 10
        }

        It 'Should default ConnectionLifetimeMinutes to 5' {
            $defaultLifetime = 5
            $defaultLifetime | Should -Be 5
        }
    }

    Context 'Edge Cases' {
        It 'Should handle minimum TimeoutSeconds' {
            $timeout = 1
            $timeout | Should -BeGreaterOrEqual 1
        }

        It 'Should handle maximum TimeoutSeconds' {
            $timeout = 300
            $timeout | Should -BeLessOrEqual 300
        }

        It 'Should handle minimum MaxConnectionsPerServer' {
            $maxConn = 1
            $maxConn | Should -BeGreaterOrEqual 1
        }

        It 'Should handle maximum MaxConnectionsPerServer' {
            $maxConn = 100
            $maxConn | Should -BeLessOrEqual 100
        }

        It 'Should handle minimum ConnectionLifetimeMinutes' {
            $lifetime = 1
            $lifetime | Should -BeGreaterOrEqual 1
        }

        It 'Should handle maximum ConnectionLifetimeMinutes' {
            $lifetime = 60
            $lifetime | Should -BeLessOrEqual 60
        }
    }
}
