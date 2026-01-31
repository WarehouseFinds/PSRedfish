# PSRedfish - (UNSTABLE - EXPERIMENTAL)

Production-grade PowerShell module for vendor-agnostic server hardware automation via DMTF Redfish® API — high-performance data center management for HPE iLO, Dell iDRAC, Lenovo XClarity, and all Redfish-compliant platforms.

[![Build Status](https://img.shields.io/github/actions/workflow/status/WarehouseFinds/PSRedfish/ci.yml?branch=main&logo=github&style=flat-square)](https://github.com/WarehouseFinds/PSRedfish/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSRedfish.svg)](https://www.powershellgallery.com/packages/PSRedfish)
[![Downloads](https://img.shields.io/powershellgallery/dt/PSRedfish.svg)](https://www.powershellgallery.com/packages/PSRedfish)
[![License](https://img.shields.io/github/license/WarehouseFinds/PSRedfish)](LICENSE)

## About

**PSRedfish** is a production-grade PowerShell module for managing server hardware through the DMTF Redfish® RESTful API standard. Built on native .NET HttpClient for maximum performance, it provides vendor-agnostic automation for data center infrastructure management.

### Why Redfish?

Redfish® is the modern standard for out-of-band server management, replacing legacy protocols like IPMI. It provides:

- **RESTful API** over HTTPS with structured JSON responses
- **Secure by design** with session-based authentication and TLS
- **Vendor adoption** across HPE iLO 4+, Dell iDRAC 7+, Lenovo XClarity, Cisco UCS, Supermicro, and more
- **Standardized operations** for power management, firmware updates, BIOS configuration, sensor monitoring

### Use Cases

**Data Center Automation** — Automate server provisioning, configuration, and lifecycle management across heterogeneous hardware fleets

**Infrastructure as Code** — Integrate with CI/CD pipelines to treat bare-metal configuration as versioned, testable code

**Monitoring & Alerting** — Collect hardware telemetry (temperatures, power consumption, health status) for centralized observability platforms

**Disaster Recovery** — Scriptable power control, boot configuration, and remote console access for emergency operations

**Compliance & Auditing** — Query firmware versions, security settings, and hardware inventory for compliance reporting

### Why This Module?

Unlike vendor-specific tools or basic REST wrappers, PSRedfish delivers:

- **Universal compatibility** — One codebase for all Redfish-compliant hardware, no vendor lock-in
- **Performance at scale** — Connection pooling and concurrent batch requests handle large server fleets efficiently
- **Production reliability** — Automatic retry logic, structured error handling, and comprehensive testing
- **PowerShell idioms** — Full pipeline support, `-WhatIf`, `-Verbose`, and native object handling

## Installation

```powershell
Install-Module -Name PSRedfish -Scope CurrentUser
```

**Requirements:** PowerShell 7.0+

## Quick Start

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

## 📘 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- 🚀 **[Getting Started](docs/getting-started.md)** - Practical examples and usage scenarios
- 📘 **[Module Help](docs/)** - Help files for cmdlets and functions

## 🤝 Contributing

Contributions are welcome! Whether it’s bug fixes, improvements, or ideas for new features, your input helps make this template better for everyone. Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on:

- Pull request workflow
- Code style and conventions
- Testing and quality requirements

## ⭐ Support This Project

If this template saves you time or helps your projects succeed, consider supporting it:

- ⭐ Star the repository to show your support
- 🔁 Share it with other PowerShell developers
- 💬 Provide feedback via issues or discussions
- ❤️ Sponsor ongoing development via GitHub Sponsors

---

Built with ❤️ by [WarehouseFinds](https://github.com/WarehouseFinds)
