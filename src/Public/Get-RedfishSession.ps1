function Get-RedfishSession {
    <#
    .SYNOPSIS
        Retrieves active Redfish sessions from the session cache.

    .DESCRIPTION
        Returns all active Redfish sessions that have been created in the current PowerShell session.
        Sessions are cached when created by New-RedfishSession and can be retrieved for inspection
        or to pass to other Redfish cmdlets.

    .PARAMETER BaseUri
        Optional filter to return only sessions matching a specific BaseUri.

    .EXAMPLE
        Get-RedfishSession
        Returns all active Redfish sessions.

    .EXAMPLE
        Get-RedfishSession -BaseUri 'https://redfish.example.com'
        Returns only sessions connected to the specified endpoint.

    .EXAMPLE
        $sessions = Get-RedfishSession
        $sessions | Remove-RedfishSession
        Gets all sessions and removes them via the pipeline.

    .OUTPUTS
        PSCustomObject or array containing Redfish session objects.

    .NOTES
        Sessions remain in cache until explicitly removed with Remove-RedfishSession.
        Each session contains an HttpClient that should be disposed when no longer needed.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [object[]])]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $BaseUri
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            # Return empty array if no sessions exist
            if ($null -eq $script:RedfishSessions -or $script:RedfishSessions.Count -eq 0) {
                Write-Verbose 'No active Redfish sessions found'
                return @()
            }

            # Filter by BaseUri if specified
            if ($PSBoundParameters.ContainsKey('BaseUri')) {
                $normalizedUri = $BaseUri.TrimEnd('/')
                $filtered = $script:RedfishSessions | Where-Object { $_.BaseUri -eq $normalizedUri }

                if ($filtered) {
                    Write-Verbose "Found $(@($filtered).Count) session(s) matching BaseUri: $normalizedUri"
                    return @($filtered)
                } else {
                    Write-Verbose "No sessions found matching BaseUri: $normalizedUri"
                    return @()
                }
            }

            # Return all sessions
            Write-Verbose "Found $($script:RedfishSessions.Count) active Redfish session(s)"
            return $script:RedfishSessions.ToArray()
        } catch {
            Write-Verbose "$($MyInvocation.MyCommand) failed: $_"
            Write-Verbose "StackTrace: $($_.ScriptStackTrace)"
            throw $_
        }
    }

    end {
        Write-Verbose "Completed $($MyInvocation.MyCommand)"
    }
}
