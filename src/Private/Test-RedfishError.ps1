function Test-RedfishError {
    <#
.SYNOPSIS
    Tests if an exception is a Redfish structured error.

.DESCRIPTION
    Helper function to identify and extract information from structured Redfish errors.

.PARAMETER ErrorRecord
    The error record to test.

.EXAMPLE
    try {
        Invoke-RedfishRequest -Session $session -Uri '/invalid'
    } catch {
        if (Test-RedfishError $_) {
            $redfishError = Get-RedfishErrorDetail $_
            Write-Host "HTTP $($redfishError.StatusCode): $($redfishError.Message)"
        }
    }
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [System.Management.Automation.ErrorRecord]
        $ErrorRecord
    )

    process {
        return $ErrorRecord.TargetObject.PSObject.TypeNames -contains 'PSRedfish.Exception'
    }
}
