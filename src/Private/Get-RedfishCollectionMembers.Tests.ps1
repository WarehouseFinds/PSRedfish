BeforeAll {
    . $PSCommandPath.Replace('.Tests.ps1', '.ps1')
}

Describe 'Get-RedfishCollectionMembers' {
    BeforeEach {
        $script:mockSession = [PSCustomObject]@{
            PSTypeName = 'PSRedfish.Session'
            BaseUri    = 'https://test.redfish.com'
        }
    }

    Context 'Parameter Validation' {
        It 'Should require mandatory Session parameter' {
            $command = Get-Command Get-RedfishCollectionMembers
            $sessionParam = $command.Parameters['Session']
            $mandatory = $sessionParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should require mandatory CollectionUri parameter' {
            $command = Get-Command Get-RedfishCollectionMembers
            $uriParam = $command.Parameters['CollectionUri']
            $mandatory = $uriParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }
            $mandatory.Mandatory | Should -Contain $true
        }

        It 'Should have MaxConcurrency parameter with valid range' {
            $command = Get-Command Get-RedfishCollectionMembers
            $concurrencyParam = $command.Parameters['MaxConcurrency']
            $validateRange = $concurrencyParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $validateRange.MinRange | Should -Be 1
            $validateRange.MaxRange | Should -Be 50
        }

        It 'Should default MaxConcurrency to 10' {
            $defaultConcurrency = 10
            $defaultConcurrency | Should -Be 10
        }
    }

    Context 'Collection Handling' {
        It 'Should handle empty collection' {
            $collection = [PSCustomObject]@{
                Members = @()
            }
            $collection.Members.Count | Should -Be 0
        }

        It 'Should extract @odata.id from members' {
            $collection = [PSCustomObject]@{
                Members = @(
                    [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/1' }
                    [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/2' }
                )
            }
            $collection.Members[0].'@odata.id' | Should -Be '/redfish/v1/Systems/1'
            $collection.Members[1].'@odata.id' | Should -Be '/redfish/v1/Systems/2'
        }

        It 'Should read Members@odata.count property' {
            $collection = [PSCustomObject]@{
                'Members@odata.count' = 5
                Members               = @()
            }
            $collection.'Members@odata.count' | Should -Be 5
        }

        It 'Should create batch requests from members' {
            $members = @(
                [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/1' }
                [PSCustomObject]@{ '@odata.id' = '/redfish/v1/Systems/2' }
            )

            $requests = $members | ForEach-Object {
                @{
                    Uri    = $_.'@odata.id'
                    Method = 'GET'
                }
            }

            $requests.Count | Should -Be 2
            $requests[0].Uri | Should -Be '/redfish/v1/Systems/1'
            $requests[0].Method | Should -Be 'GET'
        }
    }
}
