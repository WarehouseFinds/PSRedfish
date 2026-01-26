# PSRedfish Usage Guide

## Overview

PSRedfish is a universal PowerShell client for the DMTF Redfish® standard. It provides a simple, vendor-neutral interface for managing servers and infrastructure using the Redfish API.

## Key Features

- **Pure Redfish Implementation**: No vendor-specific code - works with any Redfish-compliant endpoint
- **High Performance**: Uses .NET HttpClient for optimal performance
- **Session Management**: Built-in session caching and lifecycle management
- **Pipeline Support**: All cmdlets support PowerShell pipeline operations
- **Comprehensive Error Handling**: Detailed error messages with Redfish extended information

## Core Functions

### New-RedfishSession

Creates an authenticated session to a Redfish API endpoint.

```powershell
# Create a session with session-based authentication (default, recommended)
$cred = Get-Credential
$session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred

# Create a session with HTTP Basic authentication
$session = New-RedfishSession -BaseUri 'https://redfish.example.com' -Credential $cred -AuthMethod Basic

# With custom timeout
$session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -TimeoutSeconds 60

# Skip certificate validation (not recommended for production)
$session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred -SkipCertificateCheck
```

**Authentication Methods:**

- **Session** (default): Creates a Redfish session and uses X-Auth-Token for subsequent requests. More secure and recommended.
- **Basic**: Uses HTTP Basic Authentication for all requests. Simpler but less secure.

### Invoke-RedfishRequest

Executes HTTP requests against Redfish endpoints.

```powershell
# GET request
$systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'

# POST request
$body = @{
    ResetType = 'ForceRestart'
}
Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset' -Method POST -Body $body

# PATCH request to update properties
$body = @{
    AssetTag = 'SERVER-001'
}
Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $body

# DELETE request
Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/SessionService/Sessions/1' -Method DELETE
```

### Get-RedfishSession

Retrieves active sessions from the session cache.

```powershell
# Get all active sessions
$sessions = Get-RedfishSession

# Filter by BaseUri
$sessions = Get-RedfishSession -BaseUri 'https://redfish.example.com'
```

### Remove-RedfishSession

Properly disposes of a session and cleans up resources.

```powershell
# Remove a specific session
Remove-RedfishSession -Session $session

# Remove all sessions via pipeline
Get-RedfishSession | Remove-RedfishSession
```

## Complete Workflow Example

```powershell
# Import the module
Import-Module PSRedfish

# Create session
$cred = Get-Credential
$session = New-RedfishSession -BaseUri 'https://192.168.1.100' -Credential $cred

# Get service root
$serviceRoot = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1'
Write-Host "Connected to: $($serviceRoot.Name) - $($serviceRoot.RedfishVersion)"

# List all computer systems
$systems = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems'
foreach ($systemLink in $systems.Members) {
    $system = Invoke-RedfishRequest -Session $session -Uri $systemLink.'@odata.id'
    Write-Host "System: $($system.Name) - $($system.PowerState)"
}

# Update asset tag
$updateBody = @{
    AssetTag = 'PROD-SERVER-001'
}
Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/1' -Method PATCH -Body $updateBody -WhatIf

# Clean up
Remove-RedfishSession -Session $session
```

## Pipeline Examples

```powershell
# Process multiple systems from pipeline
$systems.Members | ForEach-Object {
    Invoke-RedfishRequest -Session $session -Uri $_.'@odata.id'
} | Select-Object Name, PowerState, Model

# Clean up all sessions
Get-RedfishSession | Remove-RedfishSession
```

## Error Handling

```powershell
try {
    $system = Invoke-RedfishRequest -Session $session -Uri '/redfish/v1/Systems/Invalid'
}
catch {
    Write-Error "Failed to get system: $_"
    # Error includes HTTP status code and Redfish extended info
}
```

## Best Practices

1. **Always Clean Up Sessions**

   ```powershell
   try {
       $session = New-RedfishSession -BaseUri $uri -Credential $cred
       # ... do work ...
   }
   finally {
       Remove-RedfishSession -Session $session
   }
   ```

2. **Use -WhatIf for Destructive Operations**

   ```powershell
   Invoke-RedfishRequest -Session $session -Uri $uri -Method DELETE -WhatIf
   ```

3. **Enable Verbose Logging for Troubleshooting**

   ```powershell
   $session = New-RedfishSession -BaseUri $uri -Credential $cred -Verbose
   Invoke-RedfishRequest -Session $session -Uri $uri -Verbose
   ```

4. **Leverage Redfish OData Navigation**

   ```powershell
   # Follow @odata.id references
   $systemUri = $systems.Members[0].'@odata.id'
   $system = Invoke-RedfishRequest -Session $session -Uri $systemUri
   ```

## Security Considerations

- Never use `-SkipCertificateCheck` in production environments
- Store credentials securely (use `Get-Credential` or secure vaults)
- Always dispose of sessions when done to prevent resource leaks
- Use HTTPS endpoints whenever possible

## Troubleshooting

### Connection Timeouts

Increase timeout if connecting to slow endpoints:

```powershell
$session = New-RedfishSession -BaseUri $uri -Credential $cred -TimeoutSeconds 120
```

### Certificate Validation Errors

For development/testing only:

```powershell
$session = New-RedfishSession -BaseUri $uri -Credential $cred -SkipCertificateCheck
```

### Verbose Logging

Enable verbose output for detailed debugging:

```powershell
$VerbosePreference = 'Continue'
$session = New-RedfishSession -BaseUri $uri -Credential $cred -Verbose
```

## Resources

- [DMTF Redfish Specification](https://www.dmtf.org/standards/redfish)
- [Redfish Developer Hub](https://redfish.dmtf.org/)
- [PSRedfish GitHub Repository](https://github.com/yourusername/PSRedfish)
