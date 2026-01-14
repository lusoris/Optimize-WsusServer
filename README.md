# Optimize-WsusServer

![GitHub](https://img.shields.io/github/license/awarre/Optimize-WsusServer?style=flat-square) ![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/lusoris/Optimize-WsusServer?include_prereleases&style=flat-square)

> **Note:** This is a maintained fork of [awarre/Optimize-WsusServer](https://github.com/awarre/Optimize-WsusServer) with bug fixes, new features, and a modular code architecture based on Microsoft's 2024/2025 best practices.

## About The Project

Comprehensive Windows Server Update Services (WSUS) cleanup, optimization, maintenance, and configuration PowerShell module.

Free and open source: [MIT License](LICENSE)

### Key Features

* Deep cleaning and removal of unnecessary updates by product title and update title
* Removal of device drivers from WSUS repository (improves speed, reliability, reduces storage)
* IIS Configuration validation and optimization
* WSUS database optimization and re-indexing
* Server version detection (Windows Server 2012 R2 - 2025+)
* Virtual machine detection and hypervisor-specific optimization
* Health checks and comprehensive reporting
* Scheduled task creation for automated maintenance
* Remote WSUS server support
* UUP MIME types for Windows 11 22H2+ support

---

## Version 2.1.0 - Modular Architecture

This version introduces a **modular code structure** while maintaining backwards compatibility:

### Two Ways to Use

| Method | Best For | How |
|--------|----------|-----|
| **PowerShell Module** | Development, Testing, Interactive Use | `Import-Module .\Optimize-WsusServer.psd1` |
| **Monolithic Script** | Production, Scheduled Tasks, Distribution | `.\dist\Optimize-WsusServer.ps1` |

### New in v2.1.0

* **Modular Code Structure** - Public/Private function pattern following Microsoft best practices
* **Extended Server Support** - Windows Server 2012 R2 through 2025+ with automatic detection
* **Consolidated Helper Functions** - Eliminated code duplication (8+ registry accesses → 1 function)
* **Build System** - Generates single-file script from modular code
* **Comprehensive Documentation** - [docs/](docs/) folder with full reference

---

## Table of Contents

* [Getting Started](#getting-started)
* [Quick Examples](#quick-examples)
* [Documentation](#documentation)
* [Available Functions](#available-functions)
* [What's Fixed](#whats-fixed)
* [License](#license)
* [References](#references)

---

## Getting Started

### Prerequisites

* **Windows Server 2012 R2 / 2016 / 2019 / 2022 / 2025** with WSUS installed
* **Windows PowerShell 5.1** (PowerShell 7 is NOT supported - WSUS module not available)
* [SqlServer PowerShell module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module)

```powershell
Install-Module SqlServer -Scope CurrentUser
```

### Installation

#### Option 1: Monolithic Script (Recommended for Production)

```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lusoris/Optimize-WsusServer/develop/dist/Optimize-WsusServer.ps1" -OutFile "Optimize-WsusServer.ps1"

# Run Health Check
.\Optimize-WsusServer.ps1 -HealthCheck
```

#### Option 2: PowerShell Module (Recommended for Development)

```powershell
# Clone the repository
git clone https://github.com/lusoris/Optimize-WsusServer.git
cd Optimize-WsusServer

# Import module
Import-Module .\Optimize-WsusServer.psd1

# List available commands
Get-Command -Module Optimize-WsusServer
```

---

## Quick Examples

### Health Check

```powershell
# As Module
Get-WsusHealthStatus

# As Script
.\Optimize-WsusServer.ps1 -HealthCheck
```

### Standard Server Cleanup

```powershell
# As Module
Invoke-WsusOptimization

# As Script
.\Optimize-WsusServer.ps1 -OptimizeServer
```

### Decline Superseded Updates

```powershell
# As Module
Invoke-WsusDeepClean -DeclineSuperseded

# As Script
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates
```

### Database Optimization

```powershell
# As Module
Invoke-WsusDatabaseOptimization -Reindex

# As Script
.\Optimize-WsusServer.ps1 -OptimizeDatabase -ReindexDatabase
```

### Full Maintenance

```powershell
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates -OptimizeServer -OptimizeDatabase -ReindexDatabase
```

---

## Documentation

Full documentation is available in the [docs/](docs/) folder:

| Document | Description |
|----------|-------------|
| [Quickstart](docs/QUICKSTART.md) | First steps and common use cases |
| [Function Reference](docs/FUNCTION-REFERENCE.md) | All public functions with examples |
| [Parameter Reference](docs/PARAMETER-REFERENCE.md) | All script parameters in detail |
| [Module Structure](docs/MODULE-STRUCTURE.md) | Technical architecture |
| [Build Process](docs/BUILD-PROCESS.md) | How the monolithic script is generated |

### Reference Documentation

Local copies of Microsoft documentation for offline use and AI assistants:

| Document | Description |
|----------|-------------|
| [PowerShell Module Structure](docs/references/PowerShell-Module-Structure.md) | PS module best practices |
| [WSUS PowerShell Reference](docs/references/WSUS-PowerShell-Reference.md) | WSUS/IIS/SQL cmdlets |
| [Windows Server Versions](docs/references/Windows-Server-Versions.md) | Build numbers and feature matrix |

---

## Available Functions

### Optimization & Cleanup

| Function | Description |
|----------|-------------|
| `Invoke-WsusOptimization` | Standard WSUS Server Cleanup |
| `Invoke-WsusDeepClean` | Deep cleaning with update decline |
| `Invoke-WsusDatabaseOptimization` | Database maintenance and reindexing |

### Diagnostics & Health

| Function | Description |
|----------|-------------|
| `Get-WsusHealthStatus` | Comprehensive health check |
| `Get-WsusEnvironment` | Environment information |
| `Test-WsusPrerequisites` | Prerequisites check |

### Configuration

| Function | Description |
|----------|-------------|
| `Get-WsusIISConfig` | Read IIS configuration |
| `Test-WsusIISConfig` | Validate IIS settings |
| `Set-WsusIISConfig` | Apply recommended settings |
| `Test-WsusUupMimeTypes` | Check Windows 11 MIME types |
| `Add-WsusUupMimeTypes` | Add missing MIME types |

### Update Management

| Function | Description |
|----------|-------------|
| `Invoke-WsusAutoApprove` | Auto-approval rules |
| `Disable-WsusDriverSync` | Disable driver sync (saves storage) |
| `Enable-WsusDriverSync` | Enable driver sync |

### Storage & VM

| Function | Description |
|----------|-------------|
| `Set-WsusLowStorageMode` | Configure for limited storage |
| `Get-WsusStorageReport` | Storage usage report |
| `Invoke-WsusVMOptimization` | VM-specific optimizations |

### Scheduled Tasks

| Function | Description |
|----------|-------------|
| `New-WsusMaintenanceTask` | Create maintenance task |
| `Remove-WsusMaintenanceTask` | Remove maintenance task |

---

## What's Fixed

This fork addresses the following issues from the original repository:

| Issue | Description | Fix |
|-------|-------------|-----|
| [#20](https://github.com/awarre/Optimize-WsusServer/issues/20) | Get-WsusIISLocalizedNamespacePath returns empty path | Environment variable expansion added |
| [#24](https://github.com/awarre/Optimize-WsusServer/issues/24) | PowerShell 7 support | Added compatibility check with helpful error message |
| [#25](https://github.com/awarre/Optimize-WsusServer/issues/25) | SQL Server encryption error | Added `-Encrypt Optional` parameter |
| [#26](https://github.com/awarre/Optimize-WsusServer/issues/26) | SqlServer module >21.x incompatibility | Added `-Encrypt Optional` parameter |
| [#27](https://github.com/awarre/Optimize-WsusServer/issues/27) | SSL error on first run | Added automatic SSL detection |
| [#31](https://github.com/awarre/Optimize-WsusServer/issues/31) | SqlServer 22.3.0 missing invoke-sqlcmd | Works with latest SqlServer module |
| [#33](https://github.com/awarre/Optimize-WsusServer/issues/33) | HTTP requests fail when SSL required | Added automatic SSL detection and fallback |

### Additional Improvements in v2.1.0

* Eliminated 8+ duplicated registry access functions
* Consolidated 3 similar WSUS connection functions
* Added Windows Server 2025 support
* Future-proof version detection for newer Windows Server releases
* Modular code structure for easier maintenance

---

## Project Structure

```
Optimize-WsusServer/
├── Optimize-WsusServer.psd1    # Module manifest
├── Optimize-WsusServer.psm1    # Module loader
├── Public/                      # Exported functions (13 files)
├── Private/                     # Internal helpers (18 files)
│   ├── Core/                    # Registry, SQL, Connection
│   ├── Detection/               # Server version, VM detection
│   ├── Database/                # SQL queries
│   ├── IIS/                     # IIS configuration
│   ├── Output/                  # Logging, status output
│   ├── Storage/                 # Content size
│   └── Updates/                 # Update operations
├── Data/                        # Configuration data
├── Templates/                   # Build templates
├── Build/                       # Build system
├── dist/                        # Generated monolithic script
└── docs/                        # Documentation
```

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

## Contact

* Fork Maintainer: [lusoris](https://github.com/lusoris)
* Original Project: [awarre/Optimize-WsusServer](https://github.com/awarre/Optimize-WsusServer)

---

## References

### Microsoft Documentation

* [The complete guide to Microsoft WSUS and Configuration Manager SUP maintenance](https://support.microsoft.com/en-us/help/4490644/complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maint)
* [Windows Server Update Services best practices](https://docs.microsoft.com/en-us/troubleshoot/mem/configmgr/windows-server-update-services-best-practices)
* [Plan your WSUS deployment](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment)
* [Reindex the WSUS Database](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939795(v=ws.10))
* [WSUS Automatic Maintenance](https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-automatic-maintenance)

### PowerShell References

* [SqlServer PowerShell Module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module)
* [IIS Administration Module](https://blogs.iis.net/iisteam/introducing-iisadministration-in-the-powershell-gallery)
* [Invoke-Sqlcmd](https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd)
* [Invoke-WsusServerCleanup](https://docs.microsoft.com/en-us/powershell/module/wsus/Invoke-WsusServerCleanup)
