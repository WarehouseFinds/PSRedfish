BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    . $PSScriptRoot/Test-RedfishError.ps1
}

Describe 'Get-RedfishErrorDetails' {
    Context 'Parameter Validation' {
        It 'Should require mandatory ErrorRecord parameter' {
            $command = Get-Command Get-RedfishErrorDetails
            $errorParam = $command.Parameters['ErrorRecord']
            $mandatory = $errorParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should accept ErrorRecord from pipeline' {
            $command = Get-Command Get-RedfishErrorDetails
            $errorParam = $command.Parameters['ErrorRecord']
            $pipelineInput = $errorParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
            }
            $pipelineInput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Details Extraction' {
        It 'Should return error object for Redfish errors' {
            $mockError = [PSCustomObject]@{
                PSTypeName  = 'PSRedfish.Exception'
                StatusCode  = 404
                Message     = 'Not Found'
                IsRetryable = $false
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $mockError
            )

            $result = Get-RedfishErrorDetails -ErrorRecord $errorRecord
            $result | Should -Not -BeNullOrEmpty
            $result.StatusCode | Should -Be 404
        }

        It 'Should return null for non-Redfish errors' {
            $mockError = [PSCustomObject]@{
                PSTypeName = 'SomeOtherType'
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $mockError
            )

            $result = Get-RedfishErrorDetails -ErrorRecord $errorRecord
            $result | Should -Be $null
        }

        It 'Should preserve all error properties' {
            $mockError = [PSCustomObject]@{
                PSTypeName   = 'PSRedfish.Exception'
                StatusCode   = 503
                ReasonPhrase = 'Service Unavailable'
                Message      = 'Service temporarily unavailable'
                ExtendedInfo = @{ Details = 'Test' }
                RequestUri   = 'https://test.com/api'
                Method       = 'GET'
                Timestamp    = [DateTime]::UtcNow
                IsRetryable  = $true
                RetryAfter   = 30
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $mockError
            )

            $result = Get-RedfishErrorDetails -ErrorRecord $errorRecord
            $result.StatusCode | Should -Be 503
            $result.IsRetryable | Should -Be $true
            $result.RetryAfter | Should -Be 30
            $result.ExtendedInfo | Should -Not -BeNullOrEmpty
        }
    }
}
