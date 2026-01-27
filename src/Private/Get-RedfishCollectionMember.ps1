function Get-RedfishCollectionMember {
    <#
.SYNOPSIS
    Gets all members from a Redfish collection efficiently.

.DESCRIPTION
    Fetches all members from a Redfish collection (e.g., Systems, Chassis) using
    parallel batch requests for optimal performance.

.PARAMETER Session
    The Redfish session object.

.PARAMETER CollectionUri
    The URI of the collection to fetch (e.g., '/redfish/v1/Systems').

.PARAMETER MaxConcurrency
    Maximum number of concurrent requests when fetching members. Default is 10.

.EXAMPLE
    $systems = Get-RedfishCollectionMember -Session $session -CollectionUri '/redfish/v1/Systems'

.EXAMPLE
    $chassis = Get-RedfishCollectionMember -Session $session -CollectionUri '/redfish/v1/Chassis' -MaxConcurrency 20
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]
        $Session,

        [Parameter(Mandatory)]
        [string]
        $CollectionUri,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]
        $MaxConcurrency = 10
    )

    process {
        Write-Verbose "Fetching collection: $CollectionUri"

        # Get the collection
        $collection = Invoke-RedfishRequest -Session $Session -Uri $CollectionUri

        if (-not $collection.Members) {
            Write-Verbose 'Collection has no members'
            return [PSCustomObject[]]@()
        }

        Write-Verbose "Collection has $($collection.'Members@odata.count') members"

        # Create batch requests for all members
        $requests = $collection.Members | ForEach-Object {
            @{
                Uri    = $_.'@odata.id'
                Method = 'GET'
            }
        }

        # Fetch all members in parallel
        $members = Invoke-RedfishBatchRequest -Session $Session -Requests $requests -MaxConcurrency $MaxConcurrency

        Write-Verbose "Retrieved $($members.Count) members"

        return $members
    }
}
