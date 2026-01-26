# PSRedfish Authentication Examples

# Import the module
Import-Module PSRedfish

# =============================================================================
# Session-Based Authentication (Recommended)
# =============================================================================

# Session authentication creates a Redfish session and uses X-Auth-Token
# This is more secure as credentials are only sent once during session creation

$cred = Get-Credential -Message 'Enter Redfish credentials'
$sessionAuth = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -AuthMethod Session

# Inspect the session object
Write-Host "`nSession Authentication Properties:" -ForegroundColor Cyan
Write-Host "Auth Method: $($sessionAuth.AuthMethod)"
Write-Host "Session Token: $($sessionAuth.SessionToken.Substring(0, 20))..." # Show first 20 chars
Write-Host "Session URI: $($sessionAuth.SessionUri)"
Write-Host "Created: $($sessionAuth.CreatedAt)"

# Make requests - token is used automatically
$systems = Invoke-RedfishRequest -Session $sessionAuth -Uri '/redfish/v1/Systems'
Write-Host "`nFound $($systems.Members.Count) systems"

# Clean up - this will DELETE the session on the server
Remove-RedfishSession -Session $sessionAuth
Write-Host 'Session deleted from server' -ForegroundColor Green

# =============================================================================
# Basic Authentication (Simple but less secure)
# =============================================================================

# Basic auth sends credentials with every request
# Use this when session authentication is not supported

$basicAuth = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -AuthMethod Basic

Write-Host "`nBasic Authentication Properties:" -ForegroundColor Cyan
Write-Host "Auth Method: $($basicAuth.AuthMethod)"
Write-Host "Session Token: $($basicAuth.SessionToken)" # Should be null
Write-Host "Session URI: $($basicAuth.SessionUri)" # Should be null

# Make requests - credentials are sent with each request
$chassis = Invoke-RedfishRequest -Session $basicAuth -Uri '/redfish/v1/Chassis'
Write-Host "`nFound $($chassis.Members.Count) chassis"

# Clean up - this only disposes local resources
Remove-RedfishSession -Session $basicAuth
Write-Host 'Local session disposed' -ForegroundColor Green

# =============================================================================
# Multiple Sessions Example
# =============================================================================

# You can have multiple sessions to different servers or with different auth

$session1 = New-RedfishSession -BaseUri 'https://server1.example.com' -Credential $cred -AuthMethod Session
$session2 = New-RedfishSession -BaseUri 'https://server2.example.com' -Credential $cred -AuthMethod Basic

# List all active sessions
$allSessions = Get-RedfishSession
Write-Host "`nActive Sessions: $($allSessions.Count)"
foreach ($s in $allSessions) {
    Write-Host "  - $($s.BaseUri) ($($s.AuthMethod))"
}

# Clean up all sessions
Get-RedfishSession | Remove-RedfishSession
Write-Host 'All sessions cleaned up' -ForegroundColor Green

# =============================================================================
# Error Handling
# =============================================================================

try {
    # If session auth is not supported, it will fail gracefully
    $session = New-RedfishSession -BaseUri 'https://old-server.com' -Credential $cred -AuthMethod Session
} catch {
    Write-Warning "Session authentication failed: $_"
    Write-Host 'Falling back to Basic authentication...'
    $session = New-RedfishSession -BaseUri 'https://old-server.com' -Credential $cred -AuthMethod Basic
} finally {
    if ($session) {
        Remove-RedfishSession -Session $session
    }
}

# =============================================================================
# Best Practices
# =============================================================================

Write-Host "`nBest Practices:" -ForegroundColor Yellow
Write-Host '1. Use Session authentication when possible (default)'
Write-Host '2. Always call Remove-RedfishSession when done'
Write-Host '3. Use try/finally blocks to ensure cleanup'
Write-Host '4. Store credentials securely (use Get-Credential or secret vaults)'
Write-Host '5. Enable certificate validation in production (default behavior)'
