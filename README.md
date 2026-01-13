# Optimize-WsusServer.PS1

![GitHub](https://img.shields.io/github/license/awarre/Optimize-WsusServer?style=flat-square) ![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/lusoris/Optimize-WsusServer?include_prereleases&style=flat-square)

> **Note:** This is a maintained fork of [awarre/Optimize-WsusServer](https://github.com/awarre/Optimize-WsusServer) with bug fixes and new features based on Microsoft's 2024/2025 best practices.

## About The Project

Comprehensive Windows Server Update Services (WSUS) cleanup, optimization, maintenance, and configuration PowerShell script.

Free and open source: [MIT License](https://github.com/lusoris/Optimize-WsusServer/blob/main/LICENSE)

### Features

* Deep cleaning search and removal of unnecessary updates by product title and update title.
* Removal of device drivers from WSUS repository (greatly improves speed, reliability, and reduces storage space needed).
* IIS Configuration validation and optimization.
* Disable device driver synchronization and caching.
* WSUS integrated update and computer cleanup.
* Microsoft best practice WSUS database optimization and re-indexing.
* Creation of daily and weekly optimization scheduled tasks.

### New in v2.0.0

* **Health Check** (`-HealthCheck`) - Comprehensive server health report including:
  * SSL configuration status
  * Storage and content folder size
  * Update statistics with superseded count warning (>1500)
  * UUP MIME types check for Windows 11
* **UUP MIME Types** (`-FixUupMimeTypes`) - Check and add missing .msu/.wim MIME types for Windows 11 22H2+
* **VM Optimization** (`-OptimizeForVM`) - Detects hypervisor (Hyper-V, VMware, Proxmox/KVM, VirtualBox) and provides specific recommendations
* **Low Storage Mode** (`-LowStorageMode`) - Configures WSUS for limited storage (download-on-demand from Microsoft)
* **Extended IIS Settings** - Now validates IdleTimeout, PingEnabled, and RecyclingRegularTimeInterval
* **SSL Support** - Automatic SSL detection for WSUS connections
* **SqlServer Module Compatibility** - Works with SqlServer module >21.x

## Table of Contents

* [Getting Started](#getting-started)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation)
* [Usage](#usage)
* [What's Fixed](#whats-fixed)
* [License](#license)
* [Contact](#contact)
* [References](#references)

## Getting Started

### Prerequisites

* **Windows Server 2016/2019/2022** with WSUS installed
* **Windows PowerShell 5.1** (PowerShell 7 is NOT supported - Microsoft has not ported the WSUS module)
* [SqlServer PowerShell module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15)
* [IIS Administration PowerShell module](https://blogs.iis.net/iisteam/introducing-iisadministration-in-the-powershell-gallery) (needed for Server 2012 R2)

### Installation

1. Download [Optimize-WsusServer.ps1](https://github.com/lusoris/Optimize-WsusServer/blob/master/Optimize-WsusServer.ps1)
2. From PowerShell run:

```powershell
.\Optimize-WsusServer.ps1 -FirstRun
```

## Usage

### First Run (Recommended)

```powershell
.\Optimize-WsusServer.ps1 -FirstRun
```

Presents a series of prompts for user to initiate all recommended first run optimization tasks.

### Health Check (New)

```powershell
.\Optimize-WsusServer.ps1 -HealthCheck
```

Runs a comprehensive health check on the WSUS server including SSL status, update statistics, storage usage, and UUP MIME types.

### Fix UUP MIME Types (New)

```powershell
.\Optimize-WsusServer.ps1 -FixUupMimeTypes
```

Checks and adds missing UUP MIME types (.msu, .wim) required for Windows 11 22H2+ updates.

### Configuration Check

```powershell
.\Optimize-WsusServer.ps1 -CheckConfig
```

Validates current WSUS IIS configuration against recommended settings. Now includes IdleTimeout, PingEnabled, and RecyclingRegularTimeInterval.

### Server Optimization

```powershell
.\Optimize-WsusServer.ps1 -OptimizeServer
```

Runs all of Microsoft's built-in WSUS cleanup processes.

### Database Optimization

```powershell
.\Optimize-WsusServer.ps1 -OptimizeDatabase
```

Runs Microsoft's recommended SQL reindexing script.

### Deep Clean

```powershell
.\Optimize-WsusServer.ps1 -DeepClean
```

Searches through most likely categories for unneeded updates and drivers to free up massive amounts of storage and improve database responsiveness.

### Disable Drivers

```powershell
.\Optimize-WsusServer.ps1 -DisableDrivers
```

Disable device driver synchronization and caching.

### Scheduled Tasks

```powershell
.\Optimize-WsusServer.ps1 -InstallDailyTask
.\Optimize-WsusServer.ps1 -InstallWeeklyTask
```

Creates scheduled tasks to run OptimizeServer nightly and OptimizeDatabase weekly.

### Decline Superseded Updates

```powershell
.\Optimize-WsusServer.ps1 -DeclineSupersededUpdates
```

Declines all updates that have been approved and are superseded by other updates.

### VM Optimization (New)

```powershell
.\Optimize-WsusServer.ps1 -OptimizeForVM
```

Detects if running on a virtual machine and provides hypervisor-specific recommendations for:

* **Hyper-V** - VHDX settings, NUMA spanning, dynamic memory
* **VMware** - PVSCSI adapter, VMXNET3, VMware Tools
* **Proxmox/QEMU/KVM** - VirtIO drivers, CPU type, QEMU Guest Agent
* **VirtualBox** - Migration recommendations

### Low Storage Mode (New)

```powershell
.\Optimize-WsusServer.ps1 -LowStorageMode
```

Configures WSUS for environments with limited storage by:

* Disabling express installation files
* Enabling download-on-demand (clients download from Microsoft Update)
* Providing storage usage analysis and recommendations

## What's Fixed

This fork addresses the following issues from the original repository:

| Issue | Description | Fix |
| ----- | ----------- | --- |
| [#20](https://github.com/awarre/Optimize-WsusServer/issues/20) | Get-WsusIISLocalizedNamespacePath returns empty path | Environment variable expansion added |
| [#24](https://github.com/awarre/Optimize-WsusServer/issues/24) | PowerShell 7 support | Added compatibility check with helpful error message |
| [#25](https://github.com/awarre/Optimize-WsusServer/issues/25) | SQL Server encryption error | Added `-Encrypt Optional` parameter |
| [#26](https://github.com/awarre/Optimize-WsusServer/issues/26) | SqlServer module >21.x incompatibility | Added `-Encrypt Optional` parameter |
| [#27](https://github.com/awarre/Optimize-WsusServer/issues/27) | SSL error on first run | Added automatic SSL detection |
| [#31](https://github.com/awarre/Optimize-WsusServer/issues/31) | SqlServer 22.3.0 missing invoke-sqlcmd | Works with latest SqlServer module |
| [#33](https://github.com/awarre/Optimize-WsusServer/issues/33) | HTTP requests fail when SSL required | Added automatic SSL detection and fallback |

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Contact

* Fork Maintainer: [lusoris](https://github.com/lusoris)
* Original Project: [awarre/Optimize-WsusServer](https://github.com/awarre/Optimize-WsusServer)

## References

### Microsoft Documentation

* [The complete guide to Microsoft WSUS and Configuration Manager SUP maintenance](https://support.microsoft.com/en-us/help/4490644/complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maint)
* [Windows Server Update Services best practices](https://docs.microsoft.com/en-us/troubleshoot/mem/configmgr/windows-server-update-services-best-practices)
* [Plan your WSUS deployment](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment)
* [Reindex the WSUS Database](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939795(v=ws.10))
* [WSUS Automatic Maintenance](https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-automatic-maintenance)

### PowerShell References

* [SqlServer PowerShell Module](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module?view=sql-server-ver15)
* [IIS Administration Module](https://blogs.iis.net/iisteam/introducing-iisadministration-in-the-powershell-gallery)
* [Invoke-Sqlcmd](https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd?view=sqlserver-ps)
* [Invoke-WsusServerCleanup](https://docs.microsoft.com/en-us/powershell/module/wsus/Invoke-WsusServerCleanup?view=win10-ps)

### Other Resources

* [10 Tips for the SQL Server PowerShell Scripter](https://devblogs.microsoft.com/scripting/10-tips-for-the-sql-server-powershell-scripter/)
* [Getting 2016 updates to work on WSUS](https://www.reddit.com/r/sysadmin/comments/996xul/getting_2016_updates_to_work_on_wsus/)
