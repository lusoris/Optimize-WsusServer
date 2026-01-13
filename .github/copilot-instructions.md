# AI Coding Agent Instructions - Optimize-WsusServer

## Project Overview

**Optimize-WsusServer** is a comprehensive PowerShell script for WSUS (Windows Server Update Services) maintenance, optimization, and configuration. It's a monolithic script (~2,300 lines) that performs server health checks, database optimization, IIS configuration, update management, and storage optimization tasks.

## Critical Architecture Decisions

### Single-Script Monolith Design

The entire project is one file: [Optimize-WsusServer.ps1](../Optimize-WsusServer.ps1). This is intentional:

-   Simplifies deployment (single file to copy)
-   Targets Windows PowerShell 5.1 only (not PowerShell 7)
-   Used as a scheduled task via direct copy to C:\Scripts\
-   **Do NOT split into modules** - maintain the single-file pattern

### Parameter-Driven Execution Model

The script uses a switch statement (line ~2250) to route parameter combinations:

```powershell
switch($true) {
    ($FirstRun) { ... }
    ($DeepClean) { ... }
    ($OptimizeServer) { ... }
}
```

-   Parameters like `-FirstRun`, `-DeepClean`, `-OptimizeServer` are mutually exclusive workflows
-   `-Quiet`, `-Verbose`, `-Confirm`, `-WhatIf` are universal modifiers applied to all flows
-   Remote server override: `-WsusServer`, `-WsusPort`, `-UseSSL` redirect `$script:WsusConnection`

## Dependencies & Environment

### Required Modules

-   **SqlServer** (not SqlPS): Used for database reindexing via `Invoke-Sqlcmd`. Must support `-Encrypt Optional` (Issue #26)
-   **IISAdministration** (fallback for Server 2012 R2): For IIS config retrieval/modification
-   **WebAdministration** (implicit): For web app discovery and config

### PowerShell Compatibility

-   **Target: PowerShell 5.1 only** (lines 108, 182)
-   **Never PowerShell 7+**: WSUS module unavailable. Script actively rejects PS7+ (line 182-187)
-   PSScriptAnalyzer settings (PSScriptAnalyzerSettings.psd1): Target Windows Server 2019, allow Write-Host

### WSUS Module Quirks

-   Requires reflection load: `[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")`
-   Get-WsusServerInstance works locally; remote connections use AdminProxy (line 1915+)
-   Uses UpdateScope with ApprovedStates filters (not enumerable directly)

## Key Patterns & Conventions

### Output & Logging Functions

**Custom wrapper functions replace Write-Host:**

-   `Write-Status`: Respects `-Quiet` and `-Verbose` flags (line 196)
    -   Types: `'Info'`, `'Success'`, `'Warning'`, `'Error'`, `'Header'`
    -   Skip errors in Quiet mode? NO - always show errors
-   `Write-ProgressStatus`: Progress bars (skipped in Quiet mode)
-   `Write-Log`: File logging when `-LogPath` specified (line 1709)
    -   Levels: `'Info'`, `'Success'`, `'Error'`, `'Verbose'`
    -   Auto-rotation by `-LogRotateDays` (default 30 days, line 1752)

**Pattern for new functions:**

```powershell
if ($script:Quiet) { return }  # Skip output in Quiet mode except errors
Write-Status -Message "..." -Type Success
```

### Confirmation Workflow

-   `Confirm-Prompt` wrapper (line 610) handles user confirmation
-   Used before destructive operations (declining updates, changing IIS settings)
-   **CRITICAL:** Pass question directly: `Confirm-Prompt "Are you sure?"` → returns $true/$false
-   In `-Confirm` mode, PowerShell's built-in mechanism handles the prompt (WhatIf support line 1025)

### IIS Configuration Pattern

1. Get registry values to find IIS site: `Get-ItemPropertyValue "HKLM:\Software\Microsoft\Update Services\Server\Setup"`
2. Find WSUS website dynamically: `Get-Website` → match by WSUS installation path (line 857-880)
    - **Must expand env vars** like `%SystemDrive%` (Issue #20 fix)
3. Query config hierarchy: IIS Site → Application Pool → specific config element
4. Use `Start-IISCommitDelay` / `Stop-IISCommitDelay` for batch updates
5. Set with `Set-IISConfigAttributeValue` or `Set-WebConfigurationProperty`

**Example IIS setting change:**

-   QueueLength → `wsusPoolConfig` → "queueLength" attribute
-   RecyclingRegularTimeInterval → nested: `wsusPoolConfig` → `recycling` → `periodicRestart` → "time" attribute
-   TimeSpan values require conversion: `[timespan]::FromMinutes($value)`

### SQL Query Patterns

Two embedded T-SQL scripts stored as here-strings (line ~360):

1. `$createCustomIndexesSQLQuery` (check before create): Indexes on tbLocalizedPropertyForRevision, tbRevisionSupersedesUpdate
2. `$wsusDBMaintenanceSQLQuery` (100+ lines): Fragmentation analysis and index rebuild

**Execution:**

```powershell
Invoke-Sqlcmd -Query $query -ServerInstance $serverInstance -QueryTimeout 40000 -Encrypt Optional
```

-   Query timeout critical: database operations can take hours on first run
-   `-Encrypt Optional` required for SqlServer module >21.x (Issue #25, #26)

### Unneeded Updates Configuration

Two arrays define cleanup targets (line ~330):

-   `$unneededUpdatesbyProductTitles`: OS versions no longer supported (XP, Vista, Server 2003, etc.)
-   `$unneededUpdatesbyTitle`: Browser versions, language packs, ARM/Itanium
-   Added by product title first, then by update title
-   Deep clean also includes all "Drivers" classification

### Email Reporting

Function: `Send-EmailReport` (line 1810)

-   Requires all three: `-SmtpServer`, `-EmailTo`, `-EmailFrom`
-   Called at end of execution if configured
-   Optionally attaches log file if `-LogPath` specified

### Remote Server Connection

Pattern: Override default local server with `-WsusServer`

```powershell
if ($WsusServer) {
    $script:WsusConnection = Get-WsusServerConnection -ServerName $WsusServer -PortNumber $WsusPort -UseSSL:$UseSSL
}
```

-   Stores in `$script:WsusConnection` for functions to reference (not implemented yet - use `Get-WsusServerInstance` which currently ignores this)
-   Auto-detects ports: 8530 (HTTP), 8531 (SSL)

## Major Functions & Responsibilities

| Function                            | Lines     | Purpose                                                        |
| ----------------------------------- | --------- | -------------------------------------------------------------- |
| `Get-WsusServerInstance`            | 548-607   | Connect to local/remote WSUS, load COM assembly                |
| `Optimize-WsusUpdates`              | 634-675   | Call `Invoke-WsusServerCleanup`                                |
| `Optimize-WsusDatabase`             | 677-714   | Run custom indexes + database maintenance SQL                  |
| `New-WsusMaintenanceTask`           | 716-780   | Create daily/weekly scheduled tasks in Task Scheduler          |
| `Get-WsusIISConfig`                 | 782-854   | Retrieve all IIS optimization settings                         |
| `Get-WsusIISLocalizedNamespacePath` | 857-905   | Find WSUS IIS site (handles env var expansion)                 |
| `Test-WsusIISConfig`                | 905-939   | Compare current vs recommended, prompt updates                 |
| `Update-WsusIISConfig`              | 942-1051  | Apply specific IIS setting change via switch                   |
| `Remove-Updates`                    | 1054-1110 | Search/decline updates by Title, ProductTitles, Classification |
| `Invoke-DeepClean`                  | 1111-1166 | Orchestrate removal of unneeded updates and drivers            |
| `Disable-WsusDriverSync`            | 1167-1180 | Disable "Drivers" and "Driver Sets" classifications            |
| `Test-WsusUupMimeTypes`             | 1183-1245 | Check/add .msu/.wim MIME types for Windows 11                  |
| `Get-WsusHealthStatus`              | 1247-1357 | Report SSL status, storage, update stats, UUP types            |
| `Get-VirtualMachineInfo`            | 1358-1459 | Detect hypervisor (Hyper-V, VMware, Proxmox, VirtualBox)       |
| `Invoke-VMOptimization`             | 1460-1571 | Display hypervisor-specific recommendations                    |
| `Invoke-LowStorageOptimization`     | 1572-1709 | Disable express files, enable download-on-demand               |
| `Invoke-AutoApproveUpdates`         | 1943-2107 | Interactive bulk approval by classification                    |
| `Decline-SupersededUpdates`         | 2196-2233 | Auto-decline superseded approved updates                       |

## Known Issues & Limitations

### Critical (Must Fix Before Production Use)

1. **`$iisPath` undefined in scope** (Lines 837, 1021-1028, 2123)

    - Used by: `Get-WsusIISConfig`, `Update-WsusIISConfig`, `Unblock-WebConfigAcl`
    - Only defined at line 2254 during execution phase
    - **Impact:** IIS config changes fail silently if functions called directly
    - **Fix:** Pass `$iisPath` as parameter or set before calling

2. **Remote WSUS connection not fully implemented** (Line 2251)

    - `$script:WsusConnection` set but ignored by most functions
    - Functions always call `Get-WsusServerInstance` (local only)
    - **Functions affected:** `Remove-Updates` (1055), `Decline-SupersededUpdates` (2214), `Invoke-AutoApproveUpdates` (1962)
    - **Impact:** `-WsusServer` parameter does nothing
    - **Fix:** Refactor to use `$script:WsusConnection` when available

3. **`Get-WsusServer` vs `Get-WsusServerInstance` inconsistency** (Lines 1632, 1670, 1962)
    - Some functions call built-in `Get-WsusServer` (no remote support)
    - Others call custom `Get-WsusServerInstance` (also no remote support)
    - **Impact:** Inconsistent behavior, remote parameter unreliable
    - **Fix:** Standardize on `Get-WsusServerInstance` everywhere

### Moderate (Should Fix)

1. **`Remove-Updates` uses `Write-Host` (Lines 1068-1083)**

    - Doesn't respect `-Quiet` flag
    - **Fix:** Replace with `Write-Status -Message ... -Type Success/Info`

2. **No error handling in `Optimize-WsusDatabase`** (Line 677)

    - SQL failures silently fail or throw to user
    - **Fix:** Add try/catch with `Write-Log` error handling

3. **Database variable instantiation duplication** (Lines 693, 1310, 1613)
    - SQL server instance detection repeated 3+ times
    - **Fix:** Extract to helper function `Get-WsusSqlServerInstance`

## Development Conventions

### Code Style

-   **Indentation:** 4 spaces (PSScriptAnalyzerSettings.psd1)
-   **Braces:** Same line as condition, newline after opening
-   **Comments:** Section headers with `#--[Section Name]--` (7 dashes)
-   **Logging:** Always use `Write-Status` or `Write-Log`, not bare `Write-Host`

### Adding New Functions

1. Place before `#---[Execution]---` section (line ~2240)
2. Use consistent header format with section breaks
3. Call via parameter switch in main execution logic
4. If destructive, add `Confirm-Prompt` before action
5. Use `Write-Status` for output, respect `-Quiet` flag
6. Add parameter to line 107+ param block
7. Add `.PARAMETER` doc in header (line ~10-90)

### Testing & Validation

-   PSScriptAnalyzer: `Invoke-ScriptAnalyzer -Path Optimize-WsusServer.ps1 -Settings PSScriptAnalyzerSettings.psd1`
-   Test on Windows Server 2019/2022 with WSUS installed
-   Validate against both HTTP (8530) and HTTPS (8531) WSUS deployments
-   Check database size before/after optimization on test server

### Common Pitfalls

1. **PowerShell 7:** Users might run with `pwsh` - script explicitly checks and rejects (line 182-187)
2. **SQL Query Timeout:** Database ops can exceed 40 seconds; never reduce QueryTimeout
3. **IIS Path Localization:** Website name varies by language; use dynamic discovery, not hardcoded "WSUS Administration"
4. **Write-Host in Quiet Mode:** Must check `$script:Quiet` - use `Write-Status` helper instead
5. **SQL Encryption:** Always include `-Encrypt Optional` for compatibility with modern SqlServer modules
6. **Update Decline Recursion:** `Remove-Updates` calls itself with force=true (line 1108) - don't modify lightly
7. **Variable Scope:** Functions like `Get-WsusIISConfig`, `Update-WsusIISConfig`, `Unblock-WebConfigAcl` depend on `$iisPath` from execution context (line 2254) - **ISSUE: these functions should not depend on global context**
8. **Remote Server Support:** The `-WsusServer` parameter sets `$script:WsusConnection` but most functions ignore it - **ISSUE: remote server support incomplete**
9. **Quiet Mode Inconsistency:** `Remove-Updates` outputs even in quiet mode - should use `Write-Status` wrapper
10. **Database Query Errors:** `Invoke-Sqlcmd` errors not caught in `Optimize-WsusDatabase` - add try/catch blocks

## Tech Debt & Refactoring Candidates

1. **Centralize WSUS Connection Logic** (Priority: High)

    - Create `$wsusConnection` as module-level state
    - All update-related functions should reference this single connection
    - Currently: `Get-WsusServerInstance` creates new connection each call
    - Would improve remote server support reliability

2. **Extract IIS Variable Dependencies** (Priority: Medium)

    - Move `$iisPath` initialization earlier in script
    - Pass as parameter to `Get-WsusIISConfig`, `Update-WsusIISConfig`, `Unblock-WebConfigAcl`
    - Allows these functions to be called independently

3. **Standardize Output Functions** (Priority: Medium)

    - `Remove-Updates` and some diagnostic functions still use `Write-Host`
    - Replace with `Write-Status` for consistent `-Quiet` behavior

4. **Separate SQL Server Instance Detection** (Priority: Low)
    - SQL server instance detection duplicated in 3+ locations
    - Extract to helper function: `Get-WsusSqlServerInstance`

## Running & Debugging

```powershell
# Test a function in isolation
. .\Optimize-WsusServer.ps1
Get-WsusHealthStatus

# Simulate without changes
.\Optimize-WsusServer.ps1 -CheckConfig -WhatIf

# Verbose output
.\Optimize-WsusServer.ps1 -OptimizeServer -Verbose

# Remote server with logging
.\Optimize-WsusServer.ps1 -WsusServer wsus.company.com -UseSSL -HealthCheck -LogPath C:\Logs
```

## External Resources

-   [WSUS Best Practices](https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/)
-   [SqlServer Module Docs](https://docs.microsoft.com/en-us/sql/powershell/download-sql-server-ps-module)
-   [IIS Administration Module](https://blogs.iis.net/iisteam/introducing-iisadministration-in-the-powershell-gallery)
