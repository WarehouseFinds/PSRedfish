BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Test-RedfishError' {
    Context 'Parameter Validation' {
        It 'Should require mandatory ErrorRecord parameter' {
            $command = Get-Command Test-RedfishError
            $errorParam = $command.Parameters['ErrorRecord']
            $mandatory = $errorParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should accept ErrorRecord from pipeline' {
            $command = Get-Command Test-RedfishError
            $errorParam = $command.Parameters['ErrorRecord']
            $pipelineInput = $errorParam.Attributes | Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.ValueFromPipeline
            }
            $pipelineInput | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Error Detection' {
        It 'Should return true for PSRedfish.Exception' {
            $mockError = [PSCustomObject]@{
                PSTypeName = 'PSRedfish.Exception'
                StatusCode = 404
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $mockError
            )

            $result = Test-RedfishError -ErrorRecord $errorRecord
            $result | Should -Be $true
        }

        It 'Should return false for non-Redfish errors' {
            $mockError = [PSCustomObject]@{
                PSTypeName = 'SomeOtherType'
            }
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $mockError
            )

            $result = Test-RedfishError -ErrorRecord $errorRecord
            $result | Should -Be $false
        }

        It 'Should return false for ErrorRecord without TargetObject' {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Test'),
                'TestError',
                [System.Management.Automation.ErrorCategory]::NotSpecified,
                $null
            )

            $result = Test-RedfishError -ErrorRecord $errorRecord
            $result | Should -Be $false
        }
    }
}
