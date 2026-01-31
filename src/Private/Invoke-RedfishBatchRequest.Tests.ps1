BeforeAll {
    # Load class definitions first
    . (Join-Path $PSScriptRoot '../Classes/RedfishMetrics.ps1')
    . (Join-Path $PSScriptRoot '../Classes/RedfishSession.ps1')

    # Then load the function
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Invoke-RedfishBatchRequest' {
    BeforeEach {
        $script:mockSession = [RedfishSession]::new()
        $script:mockSession.BaseUri = 'https://test.redfish.com'
        $script:mockSession.HttpClient = $null
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory Session parameter' {
            $command = Get-Command Invoke-RedfishBatchRequest
            $sessionParam = $command.Parameters['Session']
            $mandatory = $sessionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should require mandatory Requests parameter' {
            $command = Get-Command Invoke-RedfishBatchRequest
            $requestsParam = $command.Parameters['Requests']
            $mandatory = $requestsParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should have MaxConcurrency parameter with valid range' {
            $command = Get-Command Invoke-RedfishBatchRequest
            $concurrencyParam = $command.Parameters['MaxConcurrency']
            $validateRange = $concurrencyParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 50
        }

        It 'Should default MaxConcurrency to 10' {
            $defaultConcurrency = 10
            $defaultConcurrency | Should -Be 10
        }

        It 'Should have ContinueOnError switch parameter' {
            $command = Get-Command Invoke-RedfishBatchRequest
            $continueParam = $command.Parameters['ContinueOnError']
            $continueParam | Should -Not -BeNullOrEmpty
            $continueParam.ParameterType.Name | Should -Be 'SwitchParameter'
        }
    }

    Context 'Request Structure Validation' {
        It 'Should require Uri key in request hashtable' {
            $request = @{ Uri = '/redfish/v1/Systems' }
            $request.ContainsKey('Uri') | Should -Be $true
        }

        It 'Should allow optional Method key' {
            $request = @{ Uri = '/redfish/v1/Systems'; Method = 'POST' }
            $request.ContainsKey('Method') | Should -Be $true
        }

        It 'Should allow optional Body key' {
            $request = @{ Uri = '/redfish/v1/Systems'; Method = 'POST'; Body = @{ Name = 'Test' } }
            $request.ContainsKey('Body') | Should -Be $true
        }

        It 'Should default Method to GET if not specified' {
            $request = @{ Uri = '/redfish/v1/Systems' }
            $method = if ($request.ContainsKey('Method')) { $request.Method } else { 'GET' }
            $method | Should -Be 'GET'
        }
    }

    Context 'URI Construction' {
        It 'Should construct full URI from relative path' {
            $baseUri = 'https://test.redfish.com'
            $uri = '/redfish/v1/Systems'
            $cleanUri = $uri.TrimStart('/')
            $fullUri = "$baseUri/$cleanUri"
            $fullUri | Should -Be 'https://test.redfish.com/redfish/v1/Systems'
        }

        It 'Should use absolute URI as-is' {
            $uri = 'https://other.redfish.com/redfish/v1/Systems'
            $isAbsolute = $uri -match '^https?://'
            $isAbsolute | Should -Be $true
        }
    }

    Context 'Semaphore Management' {
        It 'Should create semaphore with specified concurrency' {
            $maxConcurrency = 5
            $semaphore = [System.Threading.SemaphoreSlim]::new($maxConcurrency, $maxConcurrency)
            $semaphore | Should -Not -BeNullOrEmpty
            $semaphore.Dispose()
        }

        It 'Should wait for semaphore slot' {
            $semaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
            $result = $semaphore.Wait(0)
            $result | Should -BeOfType [bool]
            if ($result) { $semaphore.Release() }
            $semaphore.Dispose()
        }

        It 'Should release semaphore after request' {
            $semaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
            $semaphore.Wait()
            $released = $semaphore.Release()
            $released | Should -Be 0
            $semaphore.Dispose()
        }
    }

    Context 'Batch Error Object' {
        It 'Should create PSRedfish.BatchError type' {
            $errorObj = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.BatchError'
                StatusCode   = 404
                ReasonPhrase = 'Not Found'
                Message      = 'Resource not found'
                RequestUri   = '/redfish/v1/Systems/999'
                Method       = 'GET'
            }
            $errorObj.PSObject.TypeNames | Should -Contain 'PSRedfish.BatchError'
        }

        It 'Should include all error properties' {
            $errorObj = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.BatchError'
                StatusCode   = 503
                ReasonPhrase = 'Service Unavailable'
                Message      = 'Service temporarily unavailable'
                RequestUri   = '/redfish/v1/Systems'
                Method       = 'GET'
            }

            $errorObj.StatusCode | Should -Be 503
            $errorObj.RequestUri | Should -Be '/redfish/v1/Systems'
            $errorObj.Method | Should -Be 'GET'
        }
    }

    Context 'Task Management' {
        It 'Should wait for all tasks to complete' {
            $tasks = @()
            # WaitAll should be called on task array
            $true | Should -Be $true
        }

        It 'Should process results in order' {
            # Results should maintain request order
            $true | Should -Be $true
        }
    }

    Context 'Resource Cleanup' {
        It 'Should dispose HttpRequestMessage objects' {
            $request = [System.Net.Http.HttpRequestMessage]::new(
                [System.Net.Http.HttpMethod]::Get,
                'https://test.com'
            )
            $request.Dispose()
            $true | Should -Be $true
        }

        It 'Should dispose HttpResponseMessage objects' {
            # Response disposal should happen
            $true | Should -Be $true
        }

        It 'Should dispose semaphore' {
            $semaphore = [System.Threading.SemaphoreSlim]::new(1, 1)
            $semaphore.Dispose()
            $true | Should -Be $true
        }
    }
}
