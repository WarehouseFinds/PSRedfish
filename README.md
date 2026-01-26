# PSRedfish

PSRedfish is a production-ready PowerShell module for interacting with hardware management interfaces that implement the DMTF Redfish® standard. The module provides a clean, consistent, and PowerShell-native API for managing servers and chassis across vendors such as HPE iLO, Dell iDRAC, Lenovo XClarity, and other Redfish-compliant platforms.

[![Build Status](https://img.shields.io/github/actions/workflow/status/WarehouseFinds/PSRedfish/ci.yml?branch=main&logo=github&style=flat-square)](https://github.com/WarehouseFinds/PSRedfish/actions/workflows/ci.yml)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/PSRedfish.svg)](https://www.powershellgallery.com/packages/PSRedfish)
[![Downloads](https://img.shields.io/powershellgallery/dt/PSRedfish.svg)](https://www.powershellgallery.com/packages/PSRedfish)
[![License](https://img.shields.io/github/license/WarehouseFinds/PSRedfish)](LICENSE)

## 🚀 Getting Started

### Prerequisites

**Required:**

- **PowerShell 7.0+**

### Installation

Install the module from the PowerShell Gallery:

```powershell
Install-Module -Name PSRedfish -Scope CurrentUser
```

### Usage

Import the module and use its commands:

```powershell
Import-Module PSRedfish
Get-Command -Module PSRedfish
```

## 📘 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

- 📘 **[Module Help](docs/)** - Help files for cmdlets and functions
- 🚀 **[Examples](docs/examples/)** - Practical examples and usage scenarios

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
