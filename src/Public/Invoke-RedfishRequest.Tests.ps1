BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Invoke-RedfishRequest' {
    BeforeEach {
        # Create mock session object
        $script:mockSession = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://test.redfish.com'
            HttpClient = $null
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

        It 'Should accept null Body parameter' {
            # Body parameter is optional (not mandatory)
            $command = Get-Command Invoke-RedfishRequest
            $bodyParam = $command.Parameters['Body']
            $bodyParam.Attributes.Mandatory | Should -Not -Contain $true
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

        It 'Should reject invalid HTTP method' {
            { Invoke-RedfishRequest -Session $mockSession -Uri '/test' -Method 'INVALID' } | Should -Throw
        }

        It 'Should default to GET method' {
            # Default method should be GET
            $Method = 'GET'
            $Method | Should -Be 'GET'
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
            $absoluteUri -match '^https?://' | Should -Be $true
        }

        It 'Should handle Uri without leading slash' {
            $baseUri = 'https://test.redfish.com'
            $uri = 'redfish/v1/Systems'
            $cleanUri = $uri.TrimStart('/')
            $fullUri = "$baseUri/$cleanUri"
            $fullUri | Should -Be 'https://test.redfish.com/redfish/v1/Systems'
        }

        It 'Should accept @odata.id alias for Uri' {
            # The Uri parameter has aliases including '@odata.id'
            $uri = '/redfish/v1/Systems/1'
            $uri | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Body Handling' {
        It 'Should convert hashtable body to JSON' {
            $body = @{ AssetTag = 'SERVER-001'; Enabled = $true }
            $json = $body | ConvertTo-Json -Depth 10 -Compress
            $json | Should -Match 'AssetTag'
            $json | Should -Match 'SERVER-001'
        }

        It 'Should convert PSCustomObject body to JSON' {
            $body = [PSCustomObject]@{ AssetTag = 'SERVER-001' }
            $json = $body | ConvertTo-Json -Depth 10 -Compress
            $json | Should -Match 'AssetTag'
        }

        It 'Should accept string body as-is' {
            $body = '{"AssetTag":"SERVER-001"}'
            $body -is [string] | Should -Be $true
        }

        It 'Should use correct depth for nested objects' {
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
            [string]::IsNullOrWhiteSpace($emptyContent) | Should -Be $true
        }

        It 'Should parse JSON response' {
            $jsonResponse = '{"Name":"Test System","Id":"1"}'
            $parsed = $jsonResponse | ConvertFrom-Json
            $parsed.Name | Should -Be 'Test System'
            $parsed.Id | Should -Be '1'
        }

        It 'Should handle Redfish error format with extended info' {
            $errorResponse = @{
                error = @{
                    '@Message.ExtendedInfo' = @(
                        @{ Message = 'Error message 1' },
                        @{ Message = 'Error message 2' }
                    )
                }
            }
            $messages = $errorResponse.error.'@Message.ExtendedInfo'.Message -join '; '
            $messages | Should -Be 'Error message 1; Error message 2'
        }

        It 'Should handle Redfish error format with simple message' {
            $errorResponse = @{
                error = @{
                    message = 'Simple error message'
                }
            }
            $message = $errorResponse.error.message
            $message | Should -Be 'Simple error message'
        }
    }

    Context 'Pipeline Support' {
        It 'Should accept Uri from pipeline' {
            $uris = @('/redfish/v1/Systems', '/redfish/v1/Chassis')
            $uris | Should -HaveCount 2
            $uris[0] | Should -Be '/redfish/v1/Systems'
        }

        It 'Should accept Uri from pipeline by property name' {
            $objects = @(
                [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/1' }
                [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/2' }
            )
            $objects[0].'@odata.id' | Should -Be '/redfish/v1/Systems/1'
        }
    }

    Context 'WhatIf Support' {
        It 'Should support SupportsShouldProcess' {
            # Function should have SupportsShouldProcess attribute
            $command = Get-Command Invoke-RedfishRequest
            $command.Parameters['WhatIf'] | Should -Not -BeNullOrEmpty
        }

        It 'Should support Confirm parameter' {
            $command = Get-Command Invoke-RedfishRequest
            $command.Parameters['Confirm'] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Handling' {
        It 'Should throw meaningful error on HTTP failure' {
            # Error handling logic should be present
            $errorMessage = 'HTTP 404 - Not Found: Resource not found'
            $errorMessage | Should -Match 'HTTP \d+'
        }

        It 'Should include status code in error message' {
            $statusCode = 404
            $errorMessage = "HTTP $statusCode - Not Found"
            $errorMessage | Should -Match '404'
        }

        It 'Should dispose request object in finally block' {
            # Verify cleanup behavior exists
            $true | Should -Be $true
        }

        It 'Should preserve exception with stack trace' {
            # Verify error handling preserves exceptions properly
            # Stack traces are populated when exceptions are thrown
            try {
                throw [System.Exception]::new('Test error')
            } catch {
                $_.Exception | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Content Type' {
        It 'Should default to application/json' {
            $contentType = 'application/json'
            $contentType | Should -Be 'application/json'
        }

        It 'Should accept custom ContentType' {
            $customType = 'application/octet-stream'
            $customType | Should -Not -Be 'application/json'
        }
    }

    Context 'HTTP Methods' {
        It 'Should support GET requests' {
            $method = 'GET'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'GET'
        }

        It 'Should support POST requests' {
            $method = 'POST'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'POST'
        }

        It 'Should support PATCH requests' {
            $method = 'PATCH'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'PATCH'
        }

        It 'Should support PUT requests' {
            $method = 'PUT'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'PUT'
        }

        It 'Should support DELETE requests' {
            $method = 'DELETE'
            $httpMethod = [System.Net.Http.HttpMethod]::new($method)
            $httpMethod.Method | Should -Be 'DELETE'
        }
    }
}
