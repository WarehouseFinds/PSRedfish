function Get-RedfishErrorDetails {
    <#
.SYNOPSIS
    Extracts structured error details from a Redfish error.

.DESCRIPTION
    Retrieves the structured error object from a caught Redfish exception.

.PARAMETER ErrorRecord
    The error record containing the Redfish error.

.EXAMPLE
    try {
        Invoke-RedfishRequest -Session $session -Uri '/invalid'
    } catch {
        $details = Get-RedfishErrorDetails $_
        if ($details.StatusCode -eq 404) {
            Write-Host "Resource not found"
        }
    }
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    process {
        if (Test-RedfishError $ErrorRecord) {
            return $ErrorRecord.TargetObject
        }
        return $null
    }
}
