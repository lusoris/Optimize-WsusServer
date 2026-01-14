# Function Reference

Complete reference of all 13 Public Functions in Optimize-WsusServer module.

---

## Overview by Category

### Optimization & Cleanup (3)

| Function | Description |
|----------|-------------|
| [Invoke-WsusOptimization](#invoke-wsusoptimization) | Standard WSUS Server cleanup |
| [Invoke-WsusDeepClean](#invoke-wsusdeepclean) | Deep cleaning of unneeded updates and drivers |
| [Invoke-WsusDatabaseOptimization](#invoke-wsusdatabaseoptimization) | Database maintenance and reindexing |

### Diagnostics & Health (4)

| Function | Description |
|----------|-------------|
| [Get-WsusHealthStatus](#get-wsushealthstatus) | Comprehensive WSUS health check |
| [Get-WsusEnvironment](#get-wsusenvironment) | Environment and configuration information |
| [Test-WsusPrerequisites](#test-wsusprerequisites) | Check WSUS prerequisites |
| [Test-WsusUupMimeTypes](#test-wsusuupmimetypes) | Validate Windows 11 UUP MIME types |

### Configuration (1)

| Function | Description |
|----------|-------------|
| [Get-WsusIISConfig](#get-wsusiisconfig) | Retrieve current IIS configuration |

### Update Management (2)

| Function | Description |
|----------|-------------|
| [Invoke-WsusAutoApprove](#invoke-wsusautoapprove) | Interactive update approval by classification |
| [Disable-WsusDriverSync](#disable-wsusdriiversync) | Disable device driver synchronization |

### Storage Management (1)

| Function | Description |
|----------|-------------|
| [Set-WsusLowStorageMode](#set-wsuslowstoragemode) | Configure for low storage environments |

### VM Optimization (1)

| Function | Description |
|----------|-------------|
| [Invoke-WsusVMOptimization](#invoke-wsusvmoptimization) | VM-specific optimization recommendations |

### Scheduled Tasks (1)

| Function | Description |
|----------|-------------|
| [New-WsusMaintenanceTask](#new-wsusmaintenancetask) | Create maintenance scheduled task |

---

## Quick Start by Use Case

### First-Time WSUS Setup
```powershell
# 1. Check prerequisites
Test-WsusPrerequisites -Verbose

# 2. Check health
Get-WsusHealthStatus

# 3. Optimize database
Invoke-WsusDatabaseOptimization

# 4. Full server optimization
Invoke-WsusOptimization

# 5. Setup maintenance tasks
New-WsusMaintenanceTask
```

### Regular Maintenance
```powershell
# Daily (from scheduled task)
Invoke-WsusOptimization

# Weekly database optimization (from scheduled task)
Invoke-WsusDatabaseOptimization

# Monthly deep clean
Invoke-WsusDeepClean
```

### Troubleshooting
```powershell
# Check environment
Get-WsusEnvironment

# Check health
Get-WsusHealthStatus

# Check IIS settings
Get-WsusIISConfig
```

### Low Storage Scenario
```powershell
# Configure for low storage
Set-WsusLowStorageMode

# Deep clean
Invoke-WsusDeepClean

# Disable drivers
Disable-WsusDriverSync
```

---

## Detailed Function Reference

### Invoke-WsusOptimization

Executes all WSUS built-in cleanup processes.

**Cleanup Operations:**
- Deleting obsolete computers (not checked in 30+ days)
- Deleting obsolete updates
- Deleting unneeded content files
- Compressing update revisions
- Declining expired updates
- Declining superseded updates

**Syntax:**
```powershell
Invoke-WsusOptimization [[-WsusServer <string>]] [-Verbose] [-WhatIf] [-Confirm]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server hostname (default: localhost)
- `-Verbose` - Show detailed output
- `-WhatIf` - Preview changes without executing
- `-Confirm` - Require confirmation before running

**Examples:**
```powershell
# Run standard cleanup
Invoke-WsusOptimization

# Verbose mode
Invoke-WsusOptimization -Verbose

# Remote server
Invoke-WsusOptimization -WsusServer wsus.company.com

# Preview only
Invoke-WsusOptimization -WhatIf
```

**Time Estimate:** 30-90 minutes on first run, 10-20 minutes on subsequent runs

**Notes:**
- Requires administrator privileges
- Progress shown unless `-Verbose` is used
- Can take longer on large deployments

---

### Invoke-WsusDeepClean

Deep cleaning of WSUS by removing unneeded updates and drivers.

**Removes:**
- Legacy Windows versions (XP, Vista, Server 2003/2008)
- Legacy Office versions (2003, 2007, 2010)
- Unsupported SQL Server versions
- Drivers and driver sets
- Superseded updates
- ARM and Itanium architecture updates

**Syntax:**
```powershell
Invoke-WsusDeepClean [[-WsusServer <string>]] [-Force] [-Verbose] [-WhatIf] [-Confirm]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server hostname
- `-Force` - Skip confirmation prompts
- `-Verbose` - Show detailed output
- `-WhatIf` - Preview removals without executing
- `-Confirm` - Require confirmation for each action

**Examples:**
```powershell
# Interactive (prompts before removal)
Invoke-WsusDeepClean

# Automatic (no prompts)
Invoke-WsusDeepClean -Force

# Preview removals
Invoke-WsusDeepClean -WhatIf
```

**Caution:**
- Removed updates cannot be recovered
- Always backup WSUS database first
- Can take several hours on large deployments
- Recommend running during maintenance window

---

### Invoke-WsusDatabaseOptimization

Optimizes WSUS database with Microsoft-recommended procedures.

**Operations:**
- Creating custom performance indexes (if missing)
- Rebuilding fragmented indexes
- Defragmenting database
- Updating table statistics

**Syntax:**
```powershell
Invoke-WsusDatabaseOptimization [-Verbose] [-WhatIf] [-Confirm]
```

**Parameters:**
- `-Verbose` - Show detailed progress
- `-WhatIf` - Preview changes
- `-Confirm` - Require confirmation

**Examples:**
```powershell
# Standard optimization
Invoke-WsusDatabaseOptimization

# Verbose output
Invoke-WsusDatabaseOptimization -Verbose

# Preview
Invoke-WsusDatabaseOptimization -WhatIf
```

**Requirements:**
- SqlServer PowerShell module (v21.0.0+)
- Local database access
- Administrator privileges

**Time Estimate:**
- Small deployments (<50GB): 30-60 minutes
- Large deployments (>100GB): 2-4+ hours
- First run significantly slower

---

### Get-WsusHealthStatus

Comprehensive health check of WSUS server.

**Checks:**
- SSL configuration status
- Storage usage (content and database)
- Update statistics (total, live, superseded, declined)
- Superseded update warnings
- UUP MIME type validation

**Syntax:**
```powershell
Get-WsusHealthStatus [[-WsusServer <string>]] [-Verbose]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server
- `-Verbose` - Show detailed metrics

**Output:** Formatted health report with color-coded status

**Examples:**
```powershell
# Local server
Get-WsusHealthStatus

# Remote server
Get-WsusHealthStatus -WsusServer wsus.company.com

# Detailed view
Get-WsusHealthStatus -Verbose
```

**Status Indicators:**
- ✅ Green = Healthy (acceptable values)
- ⚠️ Yellow = Warning (approaching limits)
- ❌ Red = Critical (immediate action needed)

---

### Get-WsusEnvironment

Returns environment and WSUS configuration information.

**Information Provided:**
- Windows Server version and build
- WSUS installation type (SQL, WID, SSEE)
- IIS configuration
- Database location and type
- Content directory location
- Update statistics summary
- Virtual machine detection

**Syntax:**
```powershell
Get-WsusEnvironment [[-WsusServer <string>]]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server

**Output:** PSCustomObject with environment properties

**Examples:**
```powershell
# Local environment
$env = Get-WsusEnvironment
$env | Select-Object *

# Remote environment
Get-WsusEnvironment -WsusServer wsus.company.com

# Check specific property
(Get-WsusEnvironment).WindowsVersion
```

---

### Test-WsusPrerequisites

Validates WSUS prerequisites before operations.

**Checks:**
- PowerShell version (5.1 required)
- Required modules (SqlServer)
- Registry settings
- IIS components
- WSUS service running
- Database accessibility

**Syntax:**
```powershell
Test-WsusPrerequisites [[-WsusServer <string>]] [-Verbose]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server
- `-Verbose` - Show detailed checks

**Output:** $true if all prerequisites met, $false otherwise

**Examples:**
```powershell
# Check local prerequisites
if (Test-WsusPrerequisites) {
    Write-Host "Ready to run optimization"
}

# Check remote server with details
Test-WsusPrerequisites -WsusServer wsus.company.com -Verbose

# Store result
$ready = Test-WsusPrerequisites
```

---

### Test-WsusUupMimeTypes

Validates Windows 11 UUP MIME types are configured.

**Validates:**
- `.msu` = `application/octet-stream`
- `.wim` = `application/x-ms-wim`

Required for Windows 11 22H2+ update support

**Syntax:**
```powershell
Test-WsusUupMimeTypes
```

**Output:** $true if all MIME types configured, $false otherwise

**Examples:**
```powershell
# Check MIME types
if (Test-WsusUupMimeTypes) {
    Write-Host "Windows 11 updates supported"
}

# Store result
$win11Support = Test-WsusUupMimeTypes
```

**Note:** Requires Windows Server 2019+

---

### Get-WsusIISConfig

Retrieves current WSUS IIS configuration.

**Returns:**
- Application pool settings
- Queue length
- Memory limits (recycling)
- Idle timeout settings
- Execution timeout
- Request size limits
- CPU reset interval

**Syntax:**
```powershell
Get-WsusIISConfig [[-WsusServer <string>]]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server

**Output:** HashTable with IIS settings

**Key Properties:**
- QueueLength - Application pool queue depth
- RecyclingMemory - Virtual memory limit
- RecyclingPrivateMemory - Private memory limit
- IdleTimeout - Idle timeout duration
- ClientMaxRequestLength - Max request size
- ClientExecutionTimeout - Script timeout

**Examples:**
```powershell
# Get current config
$config = Get-WsusIISConfig
$config | Format-Table

# Check specific setting
$config.QueueLength

# Display all settings
$config | Out-String
```

---

### Invoke-WsusAutoApprove

Interactively approves unapproved updates by classification.

**Supported Classifications:**
- Critical Updates
- Security Updates
- Definition Updates
- Update Rollups
- And others...

**Syntax:**
```powershell
Invoke-WsusAutoApprove [[-WsusServer <string>]] [[-Classifications <string[]>]]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server
- `-Classifications` - Specific classifications to approve

**Examples:**
```powershell
# Interactive approval wizard
Invoke-WsusAutoApprove

# Approve specific classifications
Invoke-WsusAutoApprove -Classifications 'Critical Updates', 'Security Updates'

# Remote server
Invoke-WsusAutoApprove -WsusServer wsus.company.com
```

**Process:**
1. Select computer group (All Computers, etc.)
2. Select classifications to approve
3. Review and confirm updates
4. Approve without prompts

---

### Disable-WsusDriverSync

Disables device driver synchronization in WSUS.

**Disables:**
- "Drivers" classification
- "Driver Sets" classification

Driver synchronization is a major cause of:
- Storage consumption
- Database bloat
- Performance degradation

**Syntax:**
```powershell
Disable-WsusDriverSync [[-WsusServer <string>]] [-Confirm]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server
- `-Confirm` - Require confirmation

**Examples:**
```powershell
# Disable drivers
Disable-WsusDriverSync

# Without confirmation
Disable-WsusDriverSync -Confirm:$false

# Remote server
Disable-WsusDriverSync -WsusServer wsus.company.com
```

**Recommendation:**
- Drivers are primary cause of WSUS slowness
- Strongly recommend disabling unless actively needed
- Clients can get drivers from Windows Update if needed

---

### Set-WsusLowStorageMode

Configures WSUS for low storage environments.

**Configuration Changes:**
- Disables express installation files
- Enables download-on-demand (clients download from Microsoft)
- Reduces local content caching

**Syntax:**
```powershell
Set-WsusLowStorageMode [[-WsusServer <string>]] [-Force] [-Confirm]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server
- `-Force` - Skip confirmation
- `-Confirm` - Require confirmation

**Examples:**
```powershell
# Configure for low storage
Set-WsusLowStorageMode

# Without confirmation
Set-WsusLowStorageMode -Force

# Remote server
Set-WsusLowStorageMode -WsusServer wsus.company.com
```

**Impact:**
- Reduces storage by 50-70%
- Increases client download time
- Better for branch office scenarios
- More bandwidth to Microsoft Update

---

### Invoke-WsusVMOptimization

Provides VM-specific optimization recommendations.

**Detects:**
- Microsoft Hyper-V
- VMware (ESXi, Workstation, Fusion)
- Proxmox/QEMU/KVM
- VirtualBox
- Xen

**Provides:**
- Resource recommendations
- Hypervisor-specific optimization tips
- Performance tuning guidance

**Syntax:**
```powershell
Invoke-WsusVMOptimization [[-WsusServer <string>]]
```

**Parameters:**
- `-WsusServer` - Remote WSUS server

**Examples:**
```powershell
# Check VM optimization
Invoke-WsusVMOptimization

# Remote VM
Invoke-WsusVMOptimization -WsusServer wsus.company.com
```

**Output:**
- Hypervisor type detected
- Current vCPU and memory
- Resource recommendations
- Hypervisor-specific tips

---

### New-WsusMaintenanceTask

Creates Windows Scheduled Task for automated maintenance.

**Creates:**
- Daily optimization task
- Weekly database optimization task

**Syntax:**
```powershell
New-WsusMaintenanceTask [-Interval <string>] [[-Time <DateTime>]]
    [[-DaysOfWeek <string[]>]] [-Confirm]
```

**Parameters:**
- `-Interval` - "Daily" or "Weekly" (required)
- `-Time` - Execution time (default: 12:00 AM)
- `-DaysOfWeek` - Days for weekly (default: Sunday)
- `-Confirm` - Require confirmation

**Examples:**
```powershell
# Daily optimization at 2 AM
New-WsusMaintenanceTask -Interval Daily

# Weekly optimization on Sunday at 3 AM
New-WsusMaintenanceTask -Interval Weekly

# Without confirmation
New-WsusMaintenanceTask -Interval Daily -Confirm:$false
```

**Task Details:**
- Runs as SYSTEM account
- Elevated privileges
- Copies script to C:\Scripts\
- Creates in Task Scheduler
- Logs to Windows Event Log

---

## Aliases

Quick shortcuts for commonly used functions:

| Alias | Function |
|-------|----------|
| `owsus` | Invoke-WsusOptimization |
| `wsushealth` | Get-WsusHealthStatus |
| `wsuscheck` | Test-WsusPrerequisites |

**Example:**
```powershell
# Instead of:
Invoke-WsusOptimization

# You can use:
owsus
```

---

## Common Patterns

### Error Handling
All functions support standard PowerShell error handling:

```powershell
try {
    Invoke-WsusOptimization
} catch {
    Write-Error $_.Exception.Message
}
```

### Remote Execution
All functions accept `-WsusServer` parameter:

```powershell
# Remote server
Get-WsusHealthStatus -WsusServer wsus.company.com

# Pass through pipeline
'wsus1', 'wsus2' | ForEach-Object {
    Get-WsusEnvironment -WsusServer $_
}
```

### Logging
Functions log to Windows Event Log and optionally to files:

```powershell
# Run with verbose logging
Invoke-WsusOptimization -Verbose
```

### Dry Run
Most functions support `-WhatIf` to preview changes:

```powershell
# Preview without executing
Invoke-WsusDeepClean -WhatIf
```

---

## Help System

Get detailed help for any function:

```powershell
# Get function help
Get-Help Invoke-WsusOptimization

# Get full help with examples
Get-Help Invoke-WsusOptimization -Full

# Get online help
Get-Help Invoke-WsusOptimization -Online

# Search help
Get-Help *Wsus* | Select-Object Name, Synopsis
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.1.0 | 2026-01-14 | Modular architecture, 13 public functions |
| 2.0.0 | 2025-01-01 | Major refactoring, module conversion |
| 1.0.0 | 2020-01-01 | Original monolithic script |

---

**Last Updated:** January 14, 2026
**Version:** 2.1.0
**Functions:** 13 Public Functions
**Status:** Production Ready
