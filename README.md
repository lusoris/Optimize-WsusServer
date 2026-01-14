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

This version introduces a **modular code structure** while maintaining backwards compatibility with the original monolithic script:

### ⚡ Choose Your Usage Method

| **🧩 PowerShell Module** | **📦 Monolithic Script** |
|---|---|
| **Best for:** Development, testing, interactive use | **Best for:** Production, scheduled tasks, distribution |
| `Import-Module .\Optimize-WsusServer.psd1` | `.\dist\Optimize-WsusServer.ps1` |
| Full IDE/IntelliSense support | Single file, zero dependencies |
| Modular functions, easy to debug | Self-contained, easy to distribute |
| Edit and test individual functions | Run directly from scheduled task |
| [→ Module Usage](#module-usage) | [→ Script-usage](#script-usage) |

### New in v2.1.0

* **Modular Code Structure** - Public/Private function pattern following Microsoft best practices
* **Extended Server Support** - Windows Server 2012 R2 through 2025+ with automatic detection
* **Consolidated Helper Functions** - Eliminated code duplication (8+ registry accesses → 1 function)
* **Automated Build System** - Generates and validates single-file script from modular code
* **CI/CD Pipeline** - GitHub Actions for automated build validation
* **Comprehensive Documentation** - [docs/](docs/) folder with full reference

---

## Prerequisites

* **Windows Server 2012 R2 / 2016 / 2019 / 2022 / 2025+** with WSUS installed
* **Windows PowerShell 5.1** (PowerShell 7+ is NOT supported - WSUS module unavailable)
* **SqlServer Module** v21.0.0+ ([Install](https://www.powershellgallery.com/packages/SqlServer/))

```powershell
Install-Module SqlServer -Scope CurrentUser -Force
```

---

## Installation & Usage

### Module Usage

**For development, testing, and interactive use:**

```powershell
# 1. Clone the repository
git clone https://github.com/lusoris/Optimize-WsusServer.git
cd Optimize-WsusServer

# 2. Import the module
Import-Module .\Optimize-WsusServer.psd1 -Force

# 3. List available commands
Get-Command -Module Optimize-WsusServer

# 4. Get help
Get-Help Invoke-WsusOptimization -Full
```

**Module Examples:**
```powershell
# Check WSUS health
Get-WsusHealthStatus

# Check environment
Get-WsusEnvironment

# Validate IIS configuration
$config = Get-WsusIISConfig
$config | Format-Table

# Run standard optimization
Invoke-WsusOptimization -Verbose

# Run deep clean (with prompts)
Invoke-WsusDeepClean -Verbose

# Create scheduled tasks
New-WsusMaintenanceTask
```

---

### Script Usage

**For production, scheduled tasks, and distribution:**

#### 1. Build or Download

```powershell
# Option A: Build from source
git clone https://github.com/lusoris/Optimize-WsusServer.git
cd Optimize-WsusServer
.\Build\Build-MonolithicScript.ps1
# Output: dist\Optimize-WsusServer.ps1

# Option B: Download pre-built from releases
# https://github.com/lusoris/Optimize-WsusServer/releases/latest
```

#### 2. Deploy to Production

```powershell
# Copy single file to target servers
Copy-Item dist\Optimize-WsusServer.ps1 -Destination C:\Scripts\
```

#### 3. Run as Standalone Script

```powershell
# All commands work without module import

# Health check
C:\Scripts\Optimize-WsusServer.ps1 -HealthCheck

# Standard optimization (quiet)
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeServer -Quiet

# Deep clean with confirmation
C:\Scripts\Optimize-WsusServer.ps1 -DeepClean -Confirm

# Database optimization
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeDatabase

# With logging
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeServer -Quiet -LogPath C:\Logs
```

#### 4. Schedule Automated Maintenance

```powershell
# Create scheduled tasks automatically
C:\Scripts\Optimize-WsusServer.ps1 -InstallDailyTask
C:\Scripts\Optimize-WsusServer.ps1 -InstallWeeklyTask

# Or with email notifications
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeServer `
  -Quiet `
  -LogPath C:\Logs `
  -SmtpServer mail.company.com `
  -EmailFrom wsus@company.com `
  -EmailTo admins@company.com
```

---

## Available Functions

### Core Optimization

| Function | Description |
|----------|-------------|
| `Invoke-WsusOptimization` | Runs all Microsoft recommended WSUS cleanup operations |
| `Invoke-WsusDatabaseOptimization` | Optimizes WSUS SQL database with reindexing |
| `Invoke-WsusDeepClean` | Removes unnecessary updates and drivers by category |

### Configuration & Health

| Function | Description |
|----------|-------------|
| `Get-WsusHealthStatus` | Comprehensive WSUS server health report |
| `Get-WsusEnvironment` | Detect server version, hypervisor, installed modules |
| `Get-WsusIISConfig` | Read current IIS pool settings for WSUS |
| `Test-WsusPrerequisites` | Verify prerequisites (PowerShell, modules, WSUS) |
| `Test-WsusUupMimeTypes` | Check Windows 11 UUP MIME types (.msu, .wim) |

### Maintenance & Automation

| Function | Description |
|----------|-------------|
| `Disable-WsusDriverSync` | Disable driver and driver set synchronization |
| `Invoke-WsusAutoApprove` | Interactively approve updates by classification |
| `New-WsusMaintenanceTask` | Create scheduled tasks for nightly/weekly optimization |
| `Set-WsusLowStorageMode` | Configure WSUS for low-disk environments |
| `Invoke-WsusVMOptimization` | Display hypervisor-specific optimization tips |

**Full documentation:** See [docs/FUNCTION-REFERENCE.md](docs/FUNCTION-REFERENCE.md)

---

## Documentation

- **[QUICKSTART.md](docs/QUICKSTART.md)** - Get running in 5 minutes
- **[FUNCTION-REFERENCE.md](docs/FUNCTION-REFERENCE.md)** - Complete function documentation
- **[MODULE-STRUCTURE.md](docs/MODULE-STRUCTURE.md)** - Folder and file organization
- **[BUILD-PROCESS.md](docs/BUILD-PROCESS.md)** - How the build system works
- **[PARAMETER-REFERENCE.md](docs/PARAMETER-REFERENCE.md)** - All script parameters explained

---

## Common Use Cases

### Use Case 1: Quick Health Check
```powershell
# Module:
Get-WsusHealthStatus

# Script:
C:\Scripts\Optimize-WsusServer.ps1 -HealthCheck
```

### Use Case 2: Nightly Optimization
```powershell
# Module (interactive):
Invoke-WsusOptimization -Verbose

# Script (scheduled task):
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeServer -Quiet -LogPath C:\Logs
```

### Use Case 3: Weekly Database Maintenance
```powershell
# Module:
Invoke-WsusDatabaseOptimization -Verbose

# Script:
C:\Scripts\Optimize-WsusServer.ps1 -OptimizeDatabase -Quiet -LogPath C:\Logs
```

### Use Case 4: Storage Optimization
```powershell
# Module:
Set-WsusLowStorageMode -Verbose

# Script:
C:\Scripts\Optimize-WsusServer.ps1 -LowStorageMode
```

### Use Case 5: Disable Drivers (Save Storage)
```powershell
# Module:
Disable-WsusDriverSync

# Script:
C:\Scripts\Optimize-WsusServer.ps1 -DisableDrivers
```

---

## What's Fixed in v2.1.0

### Critical Fixes
- ✅ **FIX #1:** FunctionsToExport synchronized (25 → 13 functions)
- ✅ **FIX #2:** Build system validation added (syntax, functions, size checks)
- ✅ **FIX #3:** GitHub Actions CI/CD pipeline implemented

### Bug Fixes
- ✅ SQL Server module encryption compatibility (issue #25, #26)
- ✅ IIS path localization for non-English Windows (issue #20)
- ✅ PowerShell 7 detection and proper error messaging
- ✅ WSUS remote server connection stability
- ✅ SSL/TLS automatic detection on first run

### Architecture Improvements
- ✅ Modular code structure (Public/Private functions)
- ✅ Eliminated duplicate code (8+ registry calls → 1 helper)
- ✅ Consistent output functions with -Quiet support
- ✅ Automated build system with comprehensive validation
- ✅ GitHub Actions for every commit

### New Features
- ✅ Extended Windows Server version detection (2012 R2 - 2025+)
- ✅ Hypervisor detection and optimization tips
- ✅ Email reporting with log attachments
- ✅ Low-storage mode configuration
- ✅ Auto-approve updates by classification
- ✅ Windows 11 UUP MIME type support

---

## Development

### Building from Source
```powershell
cd Optimize-WsusServer

# Build the monolithic script
.\Build\Build-MonolithicScript.ps1

# Run code analysis
Invoke-ScriptAnalyzer -Path .\Public, .\Private -Settings .\PSScriptAnalyzerSettings.psd1 -Recurse

# Run tests (coming in v2.2)
# Invoke-Pester Tests/
```

### Code Structure
```
Optimize-WsusServer/
├── Public/                 # 13 exported functions
├── Private/                # 18 internal helpers
│   ├── Core/              # Registry, SQL, connection
│   ├── Database/          # SQL queries
│   ├── Detection/         # Server, VM detection
│   ├── IIS/               # IIS configuration
│   ├── Output/            # Logging, status
│   ├── Storage/           # Content sizing
│   └── Updates/           # Update operations
├── Data/                  # Configuration files
├── Build/                 # Build system
├── dist/                  # Generated script
└── docs/                  # Documentation
```

---

## Troubleshooting

### Error: "WSUS module not found"
```powershell
# Ensure you're using Windows PowerShell 5.1, not pwsh (PowerShell 7+)
$PSVersionTable.PSVersion  # Must be 5.1.x

# Run as Administrator
Start-Process powershell.exe -Verb RunAs
```

### Error: "SqlServer module not installed"
```powershell
Install-Module SqlServer -Scope CurrentUser -Force
Import-Module SqlServer
```

### Script Runs but Takes Very Long
- Database optimization can take hours on first run - this is normal
- Run on low-traffic hours (nights/weekends)
- Use `-Quiet` flag to reduce overhead

---

## License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

---

## Support & Links

* 📖 [Full Documentation](docs/)
* 🐛 [Report Issues](https://github.com/lusoris/Optimize-WsusServer/issues)
* 💬 [Discussions](https://github.com/lusoris/Optimize-WsusServer/discussions)
* 🔗 [Original Project](https://github.com/awarre/Optimize-WsusServer)

---

## References

### Microsoft Documentation
* [WSUS Best Practices](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment)
* [Complete WSUS Maintenance Guide](https://support.microsoft.com/en-us/help/4490644)
* [WSUS Database Optimization](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939795(v=ws.10))
* [WSUS Best Practices](https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices)

### PowerShell References
* [SqlServer PowerShell Module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module)
* [IIS Administration Module](https://docs.microsoft.com/en-us/powershell/module/iisadministration/)

* [IIS Administration Module](https://blogs.iis.net/iisteam/introducing-iisadministration-in-the-powershell-gallery)
* [Invoke-Sqlcmd](https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd)
* [Invoke-WsusServerCleanup](https://docs.microsoft.com/en-us/powershell/module/wsus/Invoke-WsusServerCleanup)
