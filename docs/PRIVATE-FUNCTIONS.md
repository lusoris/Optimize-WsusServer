# Private Functions Reference

> **Note:** These are internal helper functions. They are not part of the public API and may change between versions.

## Core Functions (Private\Core)

### Get-WsusSetupConfig

Reads WSUS configuration from the Windows registry.

**Location:** `Private\Core\Get-WsusSetupConfig.ps1`

**Purpose:** Centralized registry access eliminates duplication across module.

**Returns:** Hashtable with properties like `SqlServerName`, `ContentDir`, `TargetDir`, `IISTargetWebSiteIndex`, etc.

**Used By:**
- `Optimize-WsusDatabaseOptimization` (SQL instance detection)
- `Get-WsusHealthStatus` (environment info)
- `Get-WsusIISLocalizedPath` (IIS site detection)

---

### Get-WsusSqlInstance

Converts SQL Server instance names to named pipe connection strings.

**Location:** `Private\Core\Get-WsusSqlInstance.ps1`

**Purpose:** Handles different SQL Server installation types (Express, WID, SSEE, named instances).

**Parameters:**
- `SqlServerName` (string): SQL server name from registry (e.g., `##WID`, `SQLEXPRESS`, hostname)

**Returns:** Connection string (e.g., `np:\\.\pipe\MICROSOFT##WID\tsql\query`)

**Used By:**
- `Invoke-WsusDatabaseOptimization`
- `Get-WsusUpdateStatistics`

**Example:**
```powershell
# Convert WID to pipe
Get-WsusSqlInstance -SqlServerName "##WID"
# → 'np:\\.\pipe\MICROSOFT##WID\tsql\query'
```

---

### Get-WsusServerConnection

Creates WSUS server connection objects for remote/local servers.

**Location:** `Private\Core\Get-WsusServerConnection.ps1`

**Purpose:** Handles WSUS connection with SSL detection and fallback.

**Parameters:**
- `ServerName` (string): Hostname or "localhost"
- `UseSSL` (switch): Force SSL connection
- `PortNumber` (int): Custom port (defaults to 8530/8531)

**Returns:** IUpdateServer COM object

**Used By:**
- `Get-ActiveWsusServer` (wrapper)
- All update-related functions (optionally)

---

### Get-WsusEnvironment

Gathers comprehensive environment information.

**Location:** `Private\Core\Get-WsusEnvironment.ps1`

**Purpose:** Public function wrapper that calls detection functions.

**Returns:** Hashtable with:
- `OSVersion` (Windows Server version)
- `PowerShellVersion`
- `SqlServerName`
- `WsusPath`
- `ContentDirectory`
- `IsVirtualMachine`
- `Hypervisor`

---

## Detection Functions (Private\Detection)

### Get-WindowsServerVersion

Detects the Windows Server version.

**Location:** `Private\Detection\Get-WindowsServerVersion.ps1`

**Purpose:** Identify OS version for compatibility checks.

**Returns:** String (e.g., "Windows Server 2019", "Windows Server 2025+")

**Used By:**
- `Test-WsusPrerequisites`
- `Get-WsusEnvironment`

---

### Get-VirtualMachineInfo

Detects hypervisor type and VM status.

**Location:** `Private\Detection\Get-VirtualMachineInfo.ps1`

**Purpose:** Identify if running on: Hyper-V, VMware, Proxmox/KVM, VirtualBox, Xen.

**Returns:** Hashtable with:
- `IsVirtualMachine` (bool)
- `Hypervisor` (string)
- `Model` (string)
- `Manufacturer` (string)

**Used By:**
- `Invoke-WsusVMOptimization`
- `Get-WsusEnvironment`

---

### Test-WsusPrerequisites

Validates that prerequisites are met.

**Location:** `Private\Detection\Test-WsusPrerequisites.ps1`

**Purpose:** Check PowerShell version, WSUS module, SqlServer module before running.

**Returns:** PSCustomObject with test results.

**Checks:**
- PowerShell 5.1+ (not 7+)
- WSUS module available
- SqlServer module installed
- WSUS service running
- Administrator privileges

---

## Database Functions (Private\Database)

### Invoke-WsusSqlQuery

Executes a T-SQL query against WSUS database.

**Location:** `Private\Database\Invoke-WsusSqlQuery.ps1`

**Purpose:** Wrapper around `Invoke-Sqlcmd` with WSUS-specific defaults.

**Parameters:**
- `Query` (string): T-SQL query
- `ServerInstance` (string): Named pipe or server name
- `QueryTimeout` (int): Timeout in seconds (default: 300)

**Returns:** Query results as PS objects.

**Used By:**
- `Invoke-WsusDatabaseOptimization`
- `Get-WsusUpdateStatistics`

---

### Get-WsusUpdateStatistics

Queries WSUS database for update counts.

**Location:** `Private\Database\Get-WsusUpdateStatistics.ps1`

**Purpose:** Gather statistics about updates (total, live, superseded, declined).

**Returns:** Hashtable with:
- `TotalUpdates`
- `LiveUpdates`
- `Superseded`
- `Declined`
- `SupersededNotDeclined`

**Used By:**
- `Get-WsusHealthStatus`

---

## IIS Functions (Private\IIS)

### Get-WsusIISPoolConfig

Reads IIS application pool configuration for WSUS.

**Location:** `Private\IIS\Get-WsusIISPoolConfig.ps1`

**Purpose:** Retrieve current IIS settings for comparison with recommended values.

**Returns:** Hashtable with:
- `QueueLength`
- `LoadBalancerCapabilities`
- `CpuResetInterval`
- `RecyclingMemory`
- `RecyclingPrivateMemory`
- `IdleTimeout`
- `PingEnabled`
- etc.

**Used By:**
- `Get-WsusIISConfig` (public)

---

### Get-WsusIISLocalizedPath

Finds the WSUS IIS website by matching installation directory.

**Location:** `Private\IIS\Get-WsusIISLocalizedPath.ps1`

**Purpose:** Handles non-English Windows where site name is localized (not "WSUS Administration").

**Returns:** IIS config path string (e.g., `IIS:\Sites\WSUS Administration\ClientWebService`)

**Key Feature:** Expands environment variables in registry paths for proper matching.

**Used By:**
- `Get-WsusIISConfig` (public)
- `Update-WsusIISConfig` (public)

---

### Unblock-WsusWebConfig

Grants administrator access to web.config file.

**Location:** `Private\IIS\Unblock-WsusWebConfig.ps1`

**Purpose:** Removes read-only flag and sets ACL permissions for IIS config modification.

**Used By:**
- `Update-WsusIISConfig` when modifying ClientWebService settings

---

## Output Functions (Private\Output)

### Write-WsusStatus

Writes status messages respecting -Quiet and -Verbose flags.

**Location:** `Private\Output\Write-WsusStatus.ps1`

**Purpose:** Consistent output across all functions.

**Parameters:**
- `Message` (string): Message to display
- `Type` (string): "Info", "Success", "Warning", "Error", "Header"
- `NoNewline` (switch)

**Feature:** Automatically skips non-error messages when `-Quiet` flag is set.

**Used By:** All public functions

---

### Write-WsusLog

Writes to both console and log file.

**Location:** `Private\Output\Write-WsusLog.ps1`

**Purpose:** Dual output for console feedback and file logging.

**Parameters:**
- `Message` (string): Message text
- `Level` (string): "Info", "Warning", "Error", "Success"
- `LogFile` (string): Path to log file

**Used By:** Functions when `-LogPath` specified

---

### Initialize-WsusLogging

Sets up logging infrastructure.

**Location:** `Private\Output\Initialize-WsusLogging.ps1`

**Purpose:** Creates log directory, handles log rotation by date.

**Parameters:**
- `LogPath` (string): Directory for log files
- `LogRotateDays` (int): Days to keep logs (default 30)

**Returns:** Full path to generated log file.

**Used By:** Script execution block when `-LogPath` specified

---

## Storage Functions (Private\Storage)

### Get-WsusContentSize

Calculates WSUS content folder size.

**Location:** `Private\Storage\Get-WsusContentSize.ps1`

**Purpose:** Report storage usage of downloaded updates.

**Returns:** Size in bytes (convert with `[math]::Round($size/1GB, 2)`)

**Used By:**
- `Get-WsusHealthStatus`
- `Set-WsusLowStorageMode`

---

## Update Functions (Private\Updates)

### Remove-WsusUpdates

Searches and declines updates by title or product.

**Location:** `Private\Updates\Remove-WsusUpdates.ps1`

**Purpose:** Core function for deep cleaning - declines matching updates.

**Parameters:**
- `SearchStrings` (array): Titles or products to search
- `UpdateProperty` (string): "Title", "ProductTitles", or "UpdateClassificationTitle"
- `Force` (bool): Auto-decline without prompting on recursive call

**Returns:** Count of declined updates.

**Used By:**
- `Invoke-WsusDeepClean` (declines by title, product, classification)

**Important:** Recursively calls itself with `$Force=$true` when user confirms deletion.

---

### Deny-SupersededUpdates

Declines approved updates that are superseded by other approved updates.

**Location:** `Private\Updates\Deny-SupersededUpdates.ps1`

**Purpose:** Remove old approved updates when newer versions exist.

**Parameters:**
- `Verbose` (switch): Output count instead of returning

**Returns:** Count of declined updates

**Used By:**
- `Invoke-WsusOptimization` (called from cleanup sequence)

---

## Summary Table

| Function | Category | Purpose |
|----------|----------|---------|
| `Get-WsusSetupConfig` | Core | Registry access |
| `Get-WsusSqlInstance` | Core | SQL connection string |
| `Get-WsusServerConnection` | Core | WSUS connection |
| `Get-WsusEnvironment` | Core | Environment info |
| `Get-WindowsServerVersion` | Detection | OS detection |
| `Get-VirtualMachineInfo` | Detection | VM/hypervisor detection |
| `Test-WsusPrerequisites` | Detection | Prerequisite validation |
| `Invoke-WsusSqlQuery` | Database | SQL query wrapper |
| `Get-WsusUpdateStatistics` | Database | Update statistics |
| `Get-WsusIISPoolConfig` | IIS | IIS config read |
| `Get-WsusIISLocalizedPath` | IIS | IIS site path detection |
| `Unblock-WsusWebConfig` | IIS | File permission management |
| `Write-WsusStatus` | Output | Status output |
| `Write-WsusLog` | Output | Dual logging |
| `Initialize-WsusLogging` | Output | Logging setup |
| `Get-WsusContentSize` | Storage | Content size |
| `Remove-WsusUpdates` | Updates | Update removal |
| `Deny-SupersededUpdates` | Updates | Superseded update decline |

**All 18 private functions accounted for:** ✓

---

## Dependency Graph

```
Public Functions
├─ Invoke-WsusOptimization
│  └─ Invoke-WsusSqlQuery → Invoke-WsusDatabaseOptimization
│  └─ Deny-SupersededUpdates → Remove-WsusUpdates
├─ Get-WsusHealthStatus
│  └─ Get-WsusUpdateStatistics → Invoke-WsusSqlQuery
│  └─ Get-WsusContentSize
│  └─ Get-WsusSetupConfig
└─ Invoke-WsusDeepClean
   └─ Remove-WsusUpdates
   └─ Deny-SupersededUpdates

Core Helpers (used by most)
├─ Get-WsusSetupConfig
├─ Get-WsusSqlInstance
├─ Write-WsusStatus
└─ Write-WsusLog

Detection (environment)
├─ Get-WindowsServerVersion
├─ Get-VirtualMachineInfo
└─ Test-WsusPrerequisites
```

---

## When to Modify Private Functions

**Generally avoid modifying private functions unless:**

1. **Bug fixes** - Fixing a specific issue
2. **Performance** - Optimizing database queries or registry access
3. **Compatibility** - Supporting new Windows Server versions
4. **Testing** - Debug-specific issues locally

**Do NOT modify private functions to:**
- Change public function behavior (modify public function instead)
- Add features (add new public function)
- Change return types (breaks dependent functions)

---

## Future Improvements

Private functions that may change in v2.2+:

- [ ] `Invoke-WsusSqlQuery` - Add query caching
- [ ] `Get-WsusSetupConfig` - Add config validation
- [ ] `Get-WsusUpdateStatistics` - Add filtering options
- [ ] `Remove-WsusUpdates` - Add dry-run mode without prompting

---
