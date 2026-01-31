function Remove-RedfishSession {
    <#
    .SYNOPSIS
        Removes a Redfish session and disposes of associated resources.

    .DESCRIPTION
        Properly disposes of a Redfish session by cleaning up the HttpClient and removing
        the session from the session cache. This ensures proper resource cleanup and
        prevents memory leaks.

    .PARAMETER Session
        The Redfish session object to remove.

    .EXAMPLE
        Remove-RedfishSession -Session $session
        Removes the specified Redfish session and cleans up resources.

    .EXAMPLE
        $session | Remove-RedfishSession
        Removes the Redfish session from the pipeline.

    .OUTPUTS
        None

    .NOTES
        Always call this function when done with a Redfish session to ensure proper cleanup.
        Disposing the HttpClient will close any open connections.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNull()]
        [ValidateScript({
                # Support both class-based sessions and legacy PSCustomObject sessions
                if ($_ -is [RedfishSession] -or $_.PSTypeNames -contains 'PSRedfish.Session') {
                    $true
                } else {
                    throw 'Session parameter must be a valid Redfish session object created by New-RedfishSession'
                }
            })]
        [object]
        $Session
    )

    begin {
        Write-Verbose "Starting $($MyInvocation.MyCommand)"
    }

    process {
        try {
            $target = "$($Session.BaseUri) (User: $($Session.Username))"

            if ($PSCmdlet.ShouldProcess($target, 'Remove Redfish session')) {
                Write-Verbose "Removing Redfish session for $target"

                # Delete Redfish session if using session authentication
                if ($Session.AuthMethod -eq 'Session' -and $null -ne $Session.SessionUri) {
                    try {
                        Write-Verbose "Deleting Redfish session at: $($Session.SessionUri)"
                        $deleteRequest = [System.Net.Http.HttpRequestMessage]::new(
                            [System.Net.Http.HttpMethod]::Delete,
                            $Session.SessionUri
                        )
                        $deleteResponse = $Session.HttpClient.SendAsync($deleteRequest).GetAwaiter().GetResult()

                        if ($deleteResponse.IsSuccessStatusCode) {
                            Write-Verbose 'Redfish session deleted successfully'
                        } else {
                            Write-Warning "Failed to delete Redfish session: $($deleteResponse.StatusCode) - $($deleteResponse.ReasonPhrase)"
                        }

                        $deleteRequest.Dispose()
                        $deleteResponse.Dispose()
                    } catch {
                        Write-Warning "Failed to delete Redfish session: $_"
                    }
                }

                # Dispose HttpClient if present
                if ($Session.PSObject.Properties['HttpClient'] -and $null -ne $Session.HttpClient) {
                    try {
                        $Session.HttpClient.Dispose()
                        Write-Verbose 'HttpClient disposed successfully'
                    } catch {
                        Write-Warning "Failed to dispose HttpClient: $_"
                    }
                }

                # Remove from session cache
                if ($null -ne $script:RedfishSessions) {
                    $removed = $script:RedfishSessions.Remove($Session)
                    if ($removed) {
                        Write-Verbose 'Session removed from cache'
                    } else {
                        Write-Verbose 'Session was not found in cache'
                    }
                }

                Write-Verbose 'Redfish session removed successfully'
            }
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
