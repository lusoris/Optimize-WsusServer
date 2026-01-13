#Requires -modules SqlServer
#Requires -Version 5.1

<#
.SYNOPSIS
    Comprehensive Windows Server Update Services (WSUS) configuration and optimization script.
.DESCRIPTION
    Comprehensive Windows Server Update Services (WSUS) configuration and optimization script.
    Features:
        -Deep cleaning search and removal of unnecessary updates and drivers by product title and update title.
        -IIS Configuration validation and optimization.
        -Disable device driver synchronization and caching.
        -WSUS integrated update and computer cleanup
        -Microsoft best practice WSUS database optimization and re-indexing
        -Creation of daily and weekly optimization scheduled tasks.

.PARAMETER FirstRun
    Presents a series of prompts for user to initiate all recommended first run optimization tasks. Additional parameters will be ignored, as they will be redundant.

.PARAMETER DeclineSupersededUpdates
Declines all updates that have been approved and are superseded by other updates. The update will only be declined if a superseding update has been approved.

.PARAMETER DeepClean
    Searches through most likely categories for unneeded updates and drivers to free up massive amounts of storage and improve database responsiveness. Prompts user to approve removal before deletion.

.PARAMETER DisableDrivers
    Disable device driver synchronization and caching.

.PARAMETER CheckConfig
    Validates current WSUS IIS configuration against recommended settings. Helps prevent frequent WSUS/IIS/SQL service crashes and the "RESET SERVER NODE" error.

.PARAMETER OptimizeServer
    Runs all of Microsoft's built-in WSUS cleanup processes.

.PARAMETER OptimizeDatabase
    Runs Microsoft's recommended SQL reindexing script.

.PARAMETER InstallDailyTask
    Creates a scheduled task to run the OptimizeServer function nightly.

.PARAMETER InstallWeeklyTask
    Creates a scheduled task to run the OptimizeDatabase function weekly.

.PARAMETER HealthCheck
    Runs a comprehensive health check on the WSUS server including SSL status, update statistics, storage usage, and UUP MIME types.

.PARAMETER FixUupMimeTypes
    Checks and adds missing UUP MIME types (.msu, .wim) required for Windows 11 22H2+ updates.

.PARAMETER OptimizeForVM
    Detects if running on a virtual machine (Hyper-V, VMware, Proxmox/KVM, VirtualBox) and provides hypervisor-specific optimization recommendations.

.PARAMETER LowStorageMode
    Configures WSUS for low storage environments by disabling express installation files and enabling download-on-demand (clients download from Microsoft Update).

.PARAMETER AutoApproveUpdates
    Interactively approves unapproved updates for specified computer groups based on classification (Critical, Security, Definition Updates, etc.).

.PARAMETER WsusServer
    Remote WSUS server hostname. If not specified, connects to local WSUS server.

.PARAMETER WsusPort
    WSUS server port number. Defaults to 8530 (HTTP) or 8531 (SSL).

.PARAMETER UseSSL
    Use SSL for WSUS server connection.

.PARAMETER LogPath
    Directory path for log files. Enables logging with automatic rotation.

.PARAMETER LogRotateDays
    Number of days to keep log files. Default: 30. Older files are automatically deleted.

.PARAMETER SmtpServer
    SMTP server hostname for email notifications.

.PARAMETER EmailTo
    Recipient email address for reports.

.PARAMETER EmailFrom
    Sender email address for reports.

.PARAMETER Quiet
    Suppresses all output except errors. Useful for scheduled tasks.

.PARAMETER Verbose
    Shows detailed progress information.

.PARAMETER WhatIf
    Shows what changes would be made without actually making them.

.PARAMETER Confirm
    Prompts for confirmation before making changes.

.NOTES
  Version:        2.0.0
  Author:         Austin Warren (original), lusoris (fork maintainer)
  Creation Date:  2020/07/31
  Last Modified:  2026/01/13

.EXAMPLE
  Optimize-WsusServer.ps1 -FirstRun
  Optimize-WsusServer.ps1 -DeepClean
  Optimize-WsusServer.ps1 -OptimizeServer -Quiet
  Optimize-WsusServer.ps1 -CheckConfig -WhatIf
  Optimize-WsusServer.ps1 -OptimizeServer -Verbose
#>


[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param (
    [Parameter()]
    [switch]
    $Quiet,
    [Parameter()]
    [switch]
    $FirstRun,
    [Parameter()]
    [switch]
    $DisableDrivers,
    [Parameter()]
    [switch]
    $DeepClean,
    [Parameter()]
    [switch]
    $CheckConfig,
    [Parameter()]
    [switch]
    $InstallDailyTask,
    [Parameter()]
    [switch]
    $InstallWeeklyTask,
    [Parameter()]
    [switch]
    $OptimizeServer,
    [Parameter()]
    [switch]
    $OptimizeDatabase,
    [Parameter()]
    [switch]
    $DeclineSupersededUpdates,
    [Parameter()]
    [switch]
    $HealthCheck,
    [Parameter()]
    [switch]
    $FixUupMimeTypes,
    [Parameter()]
    [switch]
    $LowStorageMode,
    [Parameter()]
    [switch]
    $OptimizeForVM,
    [Parameter()]
    [switch]
    $AutoApproveUpdates,
    [Parameter()]
    [string]
    $WsusServer,
    [Parameter()]
    [int]
    $WsusPort,
    [Parameter()]
    [switch]
    $UseSSL,
    [Parameter()]
    [string]
    $LogPath,
    [Parameter()]
    [int]
    $LogRotateDays = 30,
    [Parameter()]
    [string]
    $SmtpServer,
    [Parameter()]
    [string]
    $EmailTo,
    [Parameter()]
    [string]
    $EmailFrom
)

#----------------------------------------------------------[Compatibility Check]----------------------------------------------------------

# Check for PowerShell 7+ and warn user (Issue #24)
# WSUS module is not available in PowerShell 7
if ($PSVersionTable.PSVersion.Major -ge 7) {
    Write-Warning "PowerShell 7+ detected. The WSUS module is not available in PowerShell 7."
    Write-Warning "Please run this script using Windows PowerShell 5.1:"
    Write-Warning "  powershell.exe -File `"$PSCommandPath`""
    exit 1
}

#----------------------------------------------------------[Output Helper Functions]----------------------------------------------------------

function Write-Status {
    <#
    .SYNOPSIS
    Writes status messages respecting -Quiet and -Verbose flags.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Header', 'Verbose')]
        [string]$Type = 'Info',

        [Parameter()]
        [switch]$NoNewline
    )

    # Skip output in Quiet mode (except errors)
    if ($script:Quiet -and $Type -ne 'Error') {
        return
    }

    # Verbose messages only show with -Verbose
    if ($Type -eq 'Verbose') {
        Write-Verbose $Message
        return
    }

    $params = @{}
    if ($NoNewline) { $params['NoNewline'] = $true }

    switch ($Type) {
        'Info' { Write-Host $Message -ForegroundColor White @params }
        'Success' { Write-Host $Message -ForegroundColor Green @params }
        'Warning' { Write-Host $Message -ForegroundColor Yellow @params }
        'Error' { Write-Host $Message -ForegroundColor Red @params }
        'Header' { Write-Host $Message -BackgroundColor Blue -ForegroundColor White @params }
    }
}

function Write-ProgressStatus {
    <#
    .SYNOPSIS
    Displays a progress bar for long-running operations.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter(Mandatory = $true)]
        [string]$Status,

        [Parameter()]
        [int]$PercentComplete = -1,

        [Parameter()]
        [int]$Id = 0,

        [Parameter()]
        [switch]$Completed
    )

    # Skip in Quiet mode
    if ($script:Quiet) { return }

    if ($Completed) {
        Write-Progress -Activity $Activity -Id $Id -Completed
    } elseif ($PercentComplete -ge 0) {
        Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -Id $Id
    } else {
        Write-Progress -Activity $Activity -Status $Status -Id $Id
    }
}

# Store Quiet parameter at script scope for helper functions
$script:Quiet = $Quiet

# Initialize IIS path early for use by IIS configuration functions
# This allows functions like Get-WsusIISConfig, Update-WsusIISConfig, and Unblock-WebConfigAcl
# to be called at any point without depending on late initialization (Issue #1)
$script:IISPath = Get-WsusIISLocalizedNamespacePath

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Recommended IIS settings
# Sources:
# - https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices
# - https://www.reddit.com/r/sysadmin/comments/996xul/getting_2016_updates_to_work_on_wsus/
$recommendedIISSettings = @{
    QueueLength                  = 25000   # Default: 1000, MS recommends 2000+
    LoadBalancerCapabilities     = 'TcpLevel'
    CpuResetInterval             = 15
    RecyclingMemory              = 0       # Disable virtual memory limit
    RecyclingPrivateMemory       = 0       # Disable private memory limit (default: 1843200)
    RecyclingRegularTimeInterval = 0   # Disable periodic recycling (default: 1740 = 29h)
    IdleTimeout                  = 0       # Disable idle timeout (default: 20 min)
    PingEnabled                  = $false  # Disable ping
    ClientMaxRequestLength       = 204800
    ClientExecutionTimeout       = 7200
}

<#
DeepClean

To find potentially unneeded updates:
    1. WSUS management console
    2. Updates > All Updates
    3. Approval: Approved, Status: No Status
    4. Look for unused products
    5. Add titles to respective arrays below

Get-WsusProduct - Lists all Microsoft WSUS product categories.
#>

# Common unneeded updates by ProductTitles
$unneededUpdatesbyProductTitles = @(
    "Forefront Identity Manager 2010",
    "Microsoft Lync Server 2010",
    "Microsoft Lync Server 2013",
    "Office 2003",
    "Office 2007",
    "Office 2010",
    "Office 2002/XP",
    "SQL Server 2000",
    "SQL Server 2005",
    "SQL Server 2008",
    "Virtual PC",
    "Windows 2000",
    "Windows 7",
    "Windows 8 Embedded",
    "Windows 8.1",
    "Windows 8",
    "Windows Server 2003 R2",
    "Windows Server 2003",
    "Windows Server 2008 R2",
    "Windows Server 2008",
    "Windows Ultimate Extras",
    "Windows Vista",
    "Windows XP Embedded",
    "Windows XP x64 Edition",
    "Windows XP"
)

# Common unneeded updates by Title
$unneededUpdatesbyTitle = @(
    "Internet Explorer 6",
    "Internet Explorer 7",
    "Internet Explorer 8",
    "Internet Explorer 9",
    "Language Interface Pack",
    "Windows 10 (consumer editions)",
    "Windows 10 Education",
    "Windows 10 Enterprise N",
    "Itanium",
    "ARM64"
)

<#
REFERENCES
    The complete guide to Microsoft WSUS and Configuration Manager SUP maintenance
    https://support.microsoft.com/en-us/help/4490644/complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maint

    Invoke-WsusServerCleanup
    https://docs.microsoft.com/en-us/powershell/module/wsus/Invoke-WsusServerCleanup?view=win10-ps

    Reindex the WSUS Database
    https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/dd939795(v=ws.10)

    Invoke-Sqlcmd
    https://docs.microsoft.com/en-us/powershell/module/sqlserver/invoke-sqlcmd?view=sqlserver-ps

    How to Check if an Index Exists on a Table in SQL Server
    https://littlekendra.com/2016/01/28/how-to-check-if-an-index-exists-on-a-table-in-sql-server/
#>

<#
    "[U]sed to create custom indexes in the SUSDB database. This is a one-time process, which is optional but recommended, as doing so will greatly improve performance during subsequent cleanup operations."
    Modified to check if indexes already exist before creating them.
#>
$createCustomIndexesSQLQuery = @"
USE [SUSDB]
IF 0 = (SELECT COUNT(*) as index_count
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('[dbo].[tbLocalizedPropertyForRevision]')
    AND name='nclLocalizedPropertyID')
BEGIN
-- Create custom index in tbLocalizedPropertyForRevision
	CREATE NONCLUSTERED INDEX [nclLocalizedPropertyID] ON [dbo].[tbLocalizedPropertyForRevision]
	(
		 [LocalizedPropertyID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
END
ELSE
BEGIN
	PRINT '[nclLocalizedPropertyID] ON [dbo].[tbLocalizedPropertyForRevision] already exists'
END ;
GO
IF 0 = (SELECT COUNT(*) as index_count
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('[dbo].[tbRevisionSupersedesUpdate]')
    AND name='nclSupercededUpdateID')
BEGIN
-- Create custom index in tbRevisionSupersedesUpdate
	CREATE NONCLUSTERED INDEX [nclSupercededUpdateID] ON [dbo].[tbRevisionSupersedesUpdate]
	(
		 [SupersededUpdateID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
END
ELSE
BEGIN
	PRINT '[nclSupercededUpdateID] ON [dbo].[tbRevisionSupersedesUpdate] already exists'
END ;
GO
"@

<#
    Microsoft recommended database maintenance script

    "The performance of large Windows Server Update Services (WSUS) deployments will degrade over time if the WSUS database
    is not maintained properly. The WSUSDBMaintenance script is a T-SQL script that can be run by SQL Server administrators
    to re-index and defragment WSUS databases. It should not be used on WSUS 2.0 databases.This script contributed by the
    Microsoft WSUS team."

    Reference: https://support.microsoft.com/en-us/help/4490644/complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maint
#>
$wsusDBMaintenanceSQLQuery = @"
/******************************************************************************
This sample T-SQL script performs basic maintenance tasks on SUSDB
1. Identifies indexes that are fragmented and defragments them. For certain
   tables, a fill-factor is set in order to improve insert performance.
   Based on MSDN sample at http://msdn2.microsoft.com/en-us/library/ms188917.aspx
   and tailored for SUSDB requirements
2. Updates potentially out-of-date table statistics.
******************************************************************************/

USE SUSDB;
GO
SET NOCOUNT ON;

-- Rebuild or reorganize indexes based on their fragmentation levels
DECLARE @work_to_do TABLE (
    objectid int
    , indexid int
    , pagedensity float
    , fragmentation float
    , numrows int
)

DECLARE @objectid int;
DECLARE @indexid int;
DECLARE @schemaname nvarchar(130);
DECLARE @objectname nvarchar(130);
DECLARE @indexname nvarchar(130);
DECLARE @numrows int
DECLARE @density float;
DECLARE @fragmentation float;
DECLARE @command nvarchar(4000);
DECLARE @fillfactorset bit
DECLARE @numpages int

-- Select indexes that need to be defragmented based on the following
-- * Page density is low
-- * External fragmentation is high in relation to index size
PRINT 'Estimating fragmentation: Begin. ' + convert(nvarchar, getdate(), 121)
INSERT @work_to_do
SELECT
    f.object_id
    , index_id
    , avg_page_space_used_in_percent
    , avg_fragmentation_in_percent
    , record_count
FROM
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f
WHERE
    (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1)
    or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0)
    or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0)

PRINT 'Number of indexes to rebuild: ' + cast(@@ROWCOUNT as nvarchar(20))

PRINT 'Estimating fragmentation: End. ' + convert(nvarchar, getdate(), 121)

SELECT @numpages = sum(ps.used_page_count)
FROM
    @work_to_do AS fi
    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id

-- Declare the cursor for the list of indexes to be processed.
DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do

-- Open the cursor.
OPEN curIndexes

-- Loop through the indexes
WHILE (1=1)
BEGIN
    FETCH NEXT FROM curIndexes
    INTO @objectid, @indexid, @density, @fragmentation, @numrows;
    IF @@FETCH_STATUS < 0 BREAK;

    SELECT
        @objectname = QUOTENAME(o.name)
        , @schemaname = QUOTENAME(s.name)
    FROM
        sys.objects AS o
        INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id
    WHERE
        o.object_id = @objectid;

    SELECT
        @indexname = QUOTENAME(name)
        , @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END
    FROM
        sys.indexes
    WHERE
        object_id = @objectid AND index_id = @indexid;

    IF ((@density BETWEEN 75.0 AND 85.0) AND @fillfactorset = 1) OR (@fragmentation < 30.0)
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE';
    ELSE IF @numrows >= 5000 AND @fillfactorset = 0
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD WITH (FILLFACTOR = 90)';
    ELSE
        SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD';
    PRINT convert(nvarchar, getdate(), 121) + N' Executing: ' + @command;
    EXEC (@command);
    PRINT convert(nvarchar, getdate(), 121) + N' Done.';
END

-- Close and deallocate the cursor.
CLOSE curIndexes;
DEALLOCATE curIndexes;

IF EXISTS (SELECT * FROM @work_to_do)
BEGIN
    PRINT 'Estimated number of pages in fragmented indexes: ' + cast(@numpages as nvarchar(20))
    SELECT @numpages = @numpages - sum(ps.used_page_count)
    FROM
        @work_to_do AS fi
        INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
        INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id

    PRINT 'Estimated number of pages freed: ' + cast(@numpages as nvarchar(20))
END
GO

--Update all statistics
PRINT 'Updating all statistics.' + convert(nvarchar, getdate(), 121)
EXEC sp_updatestats
PRINT 'Done updating statistics.' + convert(nvarchar, getdate(), 121)
GO
"@

#-----------------------------------------------------------[Functions]------------------------------------------------------------

function Get-WsusServerInstance {
    <#
    .SYNOPSIS
    Gets a connection to the WSUS server with SSL support.

    .DESCRIPTION
    Creates a connection to the local WSUS server, automatically detecting whether SSL is required.
    Fixes issues #27 and #33 where SSL connections fail.

    .LINK
    https://github.com/awarre/Optimize-WsusServer/issues/33
    https://github.com/awarre/Optimize-WsusServer/issues/27
    #>

    [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

    # Try to detect WSUS SSL configuration from registry
    $wsusSetup = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Update Services\Server\Setup" -ErrorAction SilentlyContinue
    $useSSL = $false
    $portNumber = 8530

    if ($wsusSetup) {
        # Check if SSL is configured
        if ($wsusSetup.PSObject.Properties.Name -contains "UsingSSL") {
            $useSSL = [bool]$wsusSetup.UsingSSL
        }

        # Get configured port
        if ($wsusSetup.PSObject.Properties.Name -contains "PortNumber") {
            $portNumber = $wsusSetup.PortNumber
        }
    }

    # If SSL is enabled, use SSL port (typically 8531)
    if ($useSSL -and $portNumber -eq 8530) {
        $portNumber = 8531
    }

    try {
        # Try connecting with detected settings
        $wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("localhost", $useSSL, $portNumber)
        return $wsusServer
    } catch {
        # Fallback: try without SSL first, then with SSL
        try {
            $wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("localhost", $false, 8530)
            return $wsusServer
        } catch {
            try {
                $wsusServer = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer("localhost", $true, 8531)
                return $wsusServer
            } catch {
                Write-Error "Failed to connect to WSUS server. Please verify WSUS is running and accessible."
                throw
            }
        }
    }
}

function Confirm-Prompt ($prompt) {
    <#
    .SYNOPSIS
    Y/N confirmation prompt.

    .DESCRIPTION
    Displays Y/N confirmation prompt and returns true or false.

    .PARAMETER prompt
    String displayed as prompt

    .EXAMPLE
    Confirm-Prompt "Is this a question?"
    #>
    Write-Host "$prompt Y/N: " -BackgroundColor Blue -ForegroundColor White -NoNewline
    $confirm = Read-Host

    if ($confirm.ToLower() -eq 'y') {
        return $true
    } else {
        return $false
    }
}

function Get-WsusSqlServerInstance {
    <#
    .SYNOPSIS
    Converts WSUS SQL server name to appropriate connection instance string.

    .DESCRIPTION
    Determines the correct SQL Server instance connection string based on WSUS
    database type (SQL Express, WID, SSEE, or named instance).

    .PARAMETER SqlServerName
    The SQL server name from WSUS registry configuration

    .EXAMPLE
    $instance = Get-WsusSqlServerInstance "##WID"
    # Returns: 'np:\\.\pipe\MICROSOFT##WID\tsql\query'

    .OUTPUTS
    String: The connection instance string for use with Invoke-Sqlcmd

    .NOTES
    This function eliminates duplicate SQL instance detection code across
    multiple functions (Issue #3 - Tech Debt).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlServerName
    )

    switch -Regex ($SqlServerName) {
        'SQLEXPRESS' { return 'np:\\.\pipe\MSSQL$SQLEXPRESS\sql\query' }
        '##WID' { return 'np:\\.\pipe\MICROSOFT##WID\tsql\query' }
        '##SSEE' { return 'np:\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query' }
        default { return $SqlServerName }
    }
}

function Get-ActiveWsusServer {
    <#
    .SYNOPSIS
    Gets the active WSUS server connection (local or remote).

    .DESCRIPTION
    Returns the remote WSUS server connection if specified via -WsusServer parameter,
    otherwise returns the local WSUS server instance. This ensures all WSUS operations
    use the same connection and respects the remote server override.

    .OUTPUTS
    Microsoft.UpdateServices.Administration.IUpdateServer

    .NOTES
    This wrapper function fixes Issue #2 (remote WSUS support) by providing a single
    connection point that all functions should use instead of calling Get-WsusServerInstance
    directly.
    #>

    if ($script:WsusConnection) {
        return $script:WsusConnection
    } else {
        return Get-WsusServerInstance
    }
}

function Optimize-WsusUpdates {
    <#
    .SYNOPSIS
    Runs all built-in WSUS cleanup processes.

    .DESCRIPTION
    Runs all built-in WSUS cleanup processes.

    .LINK
    https://docs.microsoft.com/en-us/powershell/scripting/developer/help/examples-of-comment-based-help?view=powershell-7
    #>

    $steps = @(
        @{ Name = "Deleting obsolete computers"; Action = { Invoke-WsusServerCleanup -CleanupObsoleteComputers } },
        @{ Name = "Deleting obsolete updates"; Action = { Invoke-WsusServerCleanup -CleanupObsoleteUpdates } },
        @{ Name = "Deleting unneeded content files"; Action = { Invoke-WsusServerCleanup -CleanupUnneededContentFiles } },
        @{ Name = "Compressing update revisions"; Action = { Invoke-WsusServerCleanup -CompressUpdates } },
        @{ Name = "Declining expired updates"; Action = { Invoke-WsusServerCleanup -DeclineExpiredUpdates } },
        @{ Name = "Declining superseded updates"; Action = { Invoke-WsusServerCleanup -DeclineSupersededUpdates } },
        @{ Name = "Declining additional superseded updates"; Action = { Decline-SupersededUpdates $true } }
    )

    $totalSteps = $steps.Count
    $currentStep = 0

    foreach ($step in $steps) {
        $currentStep++
        $percent = [math]::Round(($currentStep / $totalSteps) * 100)

        Write-ProgressStatus -Activity "WSUS Server Optimization" -Status $step.Name -PercentComplete $percent
        Write-Verbose $step.Name

        if (-not $script:Quiet) {
            Write-Host $step.Name -ForegroundColor Cyan
        }

        & $step.Action
    }

    Write-ProgressStatus -Activity "WSUS Server Optimization" -Status "Complete" -Completed
    Write-Verbose "WSUS Server Optimization completed"
}

function Optimize-WsusDatabase {
    <#
    .SYNOPSIS
    Runs WSUS database optimization.

    .DESCRIPTION
    Runs Microsoft's recommended WSUS database optimization including custom
    index creation and fragmentation repair.

    .LINK
    https://support.microsoft.com/en-us/help/4490644/complete-guide-to-microsoft-wsus-and-configuration-manager-sup-maint

    .LINK
    https://devblogs.microsoft.com/scripting/10-tips-for-the-sql-server-powershell-scripter/
    #>

    # Check registry for WSUS database install type (SQL or WID)
    $wsusSqlServerName = (Get-ItemProperty "HKLM:\Software\Microsoft\Update Services\Server\Setup" -Name "SqlServername").SqlServername

    # Get the named pipe to use based on WSUS db type (Fixed: use helper function to eliminate duplication)
    $serverInstance = Get-WsusSqlServerInstance -SqlServerName $wsusSqlServerName

    # Setting query timeout value because both of these scripts are prone to timeout
    # https://devblogs.microsoft.com/scripting/10-tips-for-the-sql-server-powershell-scripter/

    Write-Host "Creating custom indexes in WSUS database if they don't already exist. This will speed up future database optimizations."

    # Create custom indexes in the database if they don't already exist
    # -Encrypt Optional fixes compatibility with SqlServer module >21.x (Issue #25, #26, #31)
    try {
        Invoke-Sqlcmd -Query $createCustomIndexesSQLQuery -ServerInstance $serverInstance -QueryTimeout 120 -Encrypt Optional
        Write-Log "Custom indexes created/verified successfully" -Level Success
    } catch {
        Write-Log "Failed to create custom indexes: $_" -Level Error
        Write-Status -Message "Custom index creation failed. Check database connectivity." -Type Warning
        if ($PSCmdlet.ShouldProcess("Continue")) {
            # Continue with maintenance even if indexes fail
        } else {
            return
        }
    }

    Write-Host "Running WSUS SQL database maintenance script. This can take an extremely long time on the first run."

    # Run the WSUS SQL database maintenance script
    try {
        Invoke-Sqlcmd -Query $wsusDBMaintenanceSQLQuery -ServerInstance $serverInstance -QueryTimeout 40000 -Encrypt Optional
        Write-Log "Database maintenance completed successfully" -Level Success
    } catch {
        Write-Log "Database maintenance failed: $_" -Level Error
        Write-Status -Message "Database maintenance failed. Please review logs and retry." -Type Error
        throw
    }
}

function New-WsusMaintenanceTask($interval) {
    <#
    .SYNOPSIS
    Creates a new WSUS optimization scheduled tasks.

    .DESCRIPTION
    Creates or overwrites daily or weekly scheduled tasks for WSUS update and database optimization.

    .PARAMETER interval
    Specifies "Daily" or "Weekly" tasks

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/scheduledtasks/?view=win10-ps
    #>

    $taskName = "Optimize WSUS Server ($interval)"
    $scriptPath = 'C:\Scripts'

    # Delete scheduled task with the same name if it already exists
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Unregistered Schedule Task: $taskName"
    }

    # Change scheduled action based on Daily or Weekly
    switch ($interval) {
        'Daily' {
            $trigger = New-ScheduledTaskTrigger -Daily -At "12pm"
            $scriptAction = "-OptimizeServer"
            break
        }
        'Weekly' {
            $trigger = New-ScheduledTaskTrigger -Weekly -At "2am" -DaysOfWeek Sunday
            $scriptAction = "-OptimizeDatabase"
            break
        }
        default {}
    }

    $scriptName = Split-Path $MyInvocation.PSCommandPath -Leaf

    #Create "C:\Scripts" to store PS script
    $null = New-Item -Path "$scriptPath" -ItemType Directory -Force
    Write-Host "Created Directory: $scriptPath"

    # Copy current script to script
    Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force
    Write-Host "Copied Script: $scriptName"

    # Create and register the scheduled task
    $task = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-Command `"&'$($scriptPath)`\$($scriptName)'$scriptAction`""

    $settings = New-ScheduledTaskSettingsSet
    $principal = New-ScheduledTaskPrincipal `
        -UserId "NT AUTHORITY\SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Sending to $null to suppress output
    $null = Register-ScheduledTask $taskName -Action $task -Trigger $trigger -Settings $settings -Principal $principal

    Write-Host "Registered Scheduled Task: $taskName"
}

function Get-WsusIISConfig {
    <#
    .SYNOPSIS
    Returns a hash of all WSUS optimization related IIS settings.

    .DESCRIPTION
    Determines WSUS IIS Site and Pool, and then forms hash of all relevant optimization settings.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/webadminstration/get-webapplication?view=winserver2012-ps

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/iisadministration/get-iissite?view=win10-ps
    #>

    # Get WSUS IIS Index from registry
    $iisSiteIndex = Get-ItemPropertyValue "HKLM:\Software\Microsoft\Update Services\Server\Setup" -Name "IISTargetWebSiteIndex"

    # IIS Site
    $iisSiteName = Get-IISSite | Where-Object -Property "Id" -EQ $iisSiteIndex | Select-Object -ExpandProperty "Name"

    # Site Application Pool
    $iisAppPool = Get-WebApplication -site $iisSiteName -Name "ClientWebService" | Select-Object -ExpandProperty "applicationPool"

    # Application Pool Config
    $iisApplicationPoolConfig = Get-IISConfigCollection -ConfigElement (Get-IISConfigSection -SectionPath "system.applicationHost/applicationPools")

    # WSUS Pool Config Root
    $wsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $iisApplicationPoolConfig -ConfigAttribute @{"name" = "$iisAppPool" }

    # Queue Length
    $queueLength = Get-IISConfigAttributeValue -ConfigElement $wsusPoolConfig -AttributeName "queueLength"

    #Load Balancer Capabilities
    $wsusPoolFailureConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "failure"
    $loadBalancerCapabilities = Get-IISConfigAttributeValue -ConfigElement $wsusPoolFailureConfig -AttributeName "loadBalancerCapabilities"

    # CPU Reset Interval
    $wsusPoolCpuConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "cpu"
    $cpuResetInterval = (Get-IISConfigAttributeValue -ConfigElement $wsusPoolCpuConfig -AttributeName "resetInterval").TotalMinutes

    # Recycling Config Root
    $wsusPoolRecyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" | Get-IISConfigElement -ChildElementName "periodicRestart"

    $recyclingMemory = Get-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "memory"
    $recyclingPrivateMemory = Get-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "privateMemory"

    # Regular Time Interval (periodic recycling)
    $recyclingRegularTimeInterval = (Get-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "time").TotalMinutes

    # Process Model Config (Idle Timeout, Ping)
    $wsusPoolProcessModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
    $idleTimeout = (Get-IISConfigAttributeValue -ConfigElement $wsusPoolProcessModelConfig -AttributeName "idleTimeout").TotalMinutes
    $pingEnabled = Get-IISConfigAttributeValue -ConfigElement $wsusPoolProcessModelConfig -AttributeName "pingingEnabled"

    $clientWebServiceConfig = Get-WebConfiguration -PSPath $script:IISPath -Filter "system.web/httpRuntime"

    $clientMaxRequestLength = $clientWebServiceConfig | Select-Object -ExpandProperty maxRequestLength
    $clientExecutionTimeout = ($clientWebServiceConfig | Select-Object -ExpandProperty executionTimeout).TotalSeconds

    # Return hash of IIS settings
    @{
        QueueLength                  = $queueLength
        LoadBalancerCapabilities     = $loadBalancerCapabilities
        CpuResetInterval             = $cpuResetInterval
        RecyclingMemory              = $recyclingMemory
        RecyclingPrivateMemory       = $recyclingPrivateMemory
        RecyclingRegularTimeInterval = $recyclingRegularTimeInterval
        IdleTimeout                  = $idleTimeout
        PingEnabled                  = $pingEnabled
        ClientMaxRequestLength       = $clientMaxRequestLength
        ClientExecutionTimeout       = $clientExecutionTimeout
    }
}

function Get-WsusIISLocalizedNamespacePath {
    <#
    .SYNOPSIS
    Gets the localized IIS namespace path for WSUS ClientWebService.

    .DESCRIPTION
    Determines the correct IIS path for the WSUS ClientWebService by matching
    the WSUS installation directory with IIS website physical paths.
    Handles environment variable expansion for proper path matching.

    .LINK
    https://docs.microsoft.com/fr-fr/security-updates/windowsupdateservices/18127277

    .LINK
    https://github.com/awarre/Optimize-WsusServer/issues/20
    #>

    # Get WSUS installation path from registry
    $iisSitePhysicalPath = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup\' -Name "TargetDir"

    # Expand environment variables in the registry path (e.g., %SystemDrive% -> C:)
    $iisSitePhysicalPath = [System.Environment]::ExpandEnvironmentVariables($iisSitePhysicalPath)

    # Find the IIS website that matches the WSUS installation path
    # Also expand environment variables in website physical paths for proper comparison
    $iisLocalizedString = Get-Website | Where-Object {
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($_.PhysicalPath)
        $expandedPath.StartsWith($iisSitePhysicalPath) -or $iisSitePhysicalPath.StartsWith($expandedPath)
    } | Select-Object -ExpandProperty Name

    # Fallback: If no match found, try to find by WSUS-specific characteristics
    if ([string]::IsNullOrEmpty($iisLocalizedString)) {
        # Try to find website containing ClientWebService application
        $iisLocalizedString = Get-Website | Where-Object {
            $siteName = $_.Name
            $null -ne (Get-WebApplication -Site $siteName -Name "ClientWebService" -ErrorAction SilentlyContinue)
        } | Select-Object -First 1 -ExpandProperty Name
    }

    if ([string]::IsNullOrEmpty($iisLocalizedString)) {
        Write-Warning "Could not determine WSUS IIS website. Using default 'WSUS Administration'."
        $iisLocalizedString = "WSUS Administration"
    }

    $iisLocalizedNamespacePath = "IIS:\Sites\$iisLocalizedString\ClientWebService"
    return $iisLocalizedNamespacePath
}

function Test-WsusIISConfig ($settings, $recommended) {
    <#
    .SYNOPSIS
    Compares current WSUS IIS settings to recommended values.

    .DESCRIPTION
    Compares current WSUS IIS settings to recommended values. Prompts user to commit changes.

    .PARAMETER settings
    Hash of current WSUS IIS settings.

    .PARAMETER recommended
    Hash of recommended WSUS IIS settings.
    #>

    # Delay IIS configuration commits until we're done updating all necessary settings
    Start-IISCommitDelay

    foreach ($key in $recommended.Keys) {
        # If the current configuration setting doesn't match the recommended value, prompt the user to update
        # This could be better designed to match minimum requirements instead of specific values, but it isn't.
        if ($recommended[$key] -ne $settings[$key]) {
            Write-Host "$key`n`tCurrent:`t$($settings[$key])`n`tRecommended:`t$($recommended[$key])" -BackgroundColor Black -ForegroundColor Red

            if (Confirm-Prompt "Update $key to recommended value?") {
                Update-WsusIISConfig $key $recommended[$key]
            }
        } else {
            Write-Host "$key`n`tCurrent:`t$($settings[$key])`n`tRecommended:`t$($recommended[$key])" -BackgroundColor Black -ForegroundColor Green
        }
    }

    # Allow IIS config commits again
    Stop-IISCommitDelay
}

function Update-WsusIISConfig {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$settingKey,

        [Parameter(Mandatory = $true)]
        $recommendedValue
    )
    <#
    .SYNOPSIS
    Modifies IIS configuration for specified setting.

    .DESCRIPTION
    Modifies specified IIS setting for WSUS IIS Site/App Pool optimization.

    .PARAMETER settingKey
    String used to reference specific IIS configuration setting.

    .PARAMETER recommendedValue
    Recommended value for WSUS IIS configuration setting.
    #>

    # WhatIf support
    if ($PSCmdlet.ShouldProcess("IIS Setting: $settingKey", "Set to $recommendedValue")) {
        Write-Verbose "Updating IIS setting '$settingKey' to '$recommendedValue'"
    } else {
        return
    }

    # WSUS IIS Index
    $iisSiteIndex = Get-ItemPropertyValue "HKLM:\Software\Microsoft\Update Services\Server\Setup" -Name "IISTargetWebSiteIndex"

    # IIS Site
    $iisSiteName = Get-IISSite | Where-Object -Property "Id" -EQ $iisSiteIndex | Select-Object -ExpandProperty "Name"

    # Site Application Pool
    $iisAppPool = Get-WebApplication -site $iisSiteName -Name "ClientWebService" | Select-Object -ExpandProperty "applicationPool"

    # Application Pool Config
    $iisApplicationPoolConfig = Get-IISConfigCollection -ConfigElement (Get-IISConfigSection -SectionPath "system.applicationHost/applicationPools")

    # WSUS Pool Config Root
    $wsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $iisApplicationPoolConfig -ConfigAttribute @{"name" = "$iisAppPool" }

    # Recycling Config Root
    $wsusPoolRecyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" | Get-IISConfigElement -ChildElementName "periodicRestart"

    switch ($settingKey) {
        'QueueLength' {
            # Queue Length
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolConfig -AttributeName "queueLength" -AttributeValue $recommendedValue
            break
        }
        'LoadBalancerCapabilities' {
            # Failure Config Root
            $wsusPoolFailureConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "failure"

            # Load Balancer Capabilities
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolFailureConfig -AttributeName "loadBalancerCapabilities" -AttributeValue $recommendedValue
            break
        }
        'CpuResetInterval' {
            # CPU Reset Interval
            $wsusPoolCpuConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "cpu"
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolCpuConfig -AttributeName "resetInterval" -AttributeValue ([timespan]::FromMinutes($recommendedValue))
            break
        }
        'RecyclingMemory' {
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "memory" -AttributeValue $recommendedValue
            break
        }
        'RecyclingPrivateMemory' {
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "privateMemory" -AttributeValue $recommendedValue
            break
        }
        'ClientMaxRequestLength' {
            # Check if the IIS WSUS Client Web Service web.config is read only and make it RW if so
            Unblock-WebConfigAcl
            Set-WebConfigurationProperty -PSPath $script:IISPath -Filter "system.web/httpRuntime" -Name "maxRequestLength" -Value $recommendedValue
            break
        }
        'ClientExecutionTimeout' {
            # Check if the IIS WSUS Client Web Service web.config is read only and make it RW if so
            Unblock-WebConfigAcl
            Set-WebConfigurationProperty -PSPath $script:IISPath -Filter "system.web/httpRuntime" -Name "executionTimeout" -Value ([timespan]::FromSeconds($recommendedValue))
            break
        }
        'RecyclingRegularTimeInterval' {
            # Regular Time Interval (periodic recycling)
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolRecyclingConfig -AttributeName "time" -AttributeValue ([timespan]::FromMinutes($recommendedValue))
            break
        }
        'IdleTimeout' {
            # Idle Timeout
            $wsusPoolProcessModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolProcessModelConfig -AttributeName "idleTimeout" -AttributeValue ([timespan]::FromMinutes($recommendedValue))
            break
        }
        'PingEnabled' {
            # Ping Enabled
            $wsusPoolProcessModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
            Set-IISConfigAttributeValue -ConfigElement $wsusPoolProcessModelConfig -AttributeName "pingingEnabled" -AttributeValue $recommendedValue
            break
        }
        default {}
    }

    Write-Host "Updated IIS Setting: $settingKey, $recommendedValue" -BackgroundColor Green -ForegroundColor Black
}

function Remove-Updates ($searchStrings, $updateProp, $force = $false) {
    $wsusServer = Get-ActiveWsusServer
    $scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updates = $wsusServer.GetUpdates($scope)
    $declinedCount = 0
    $searchCount = 0
    $userMsg = 'Found'
    $statusType = 'Warning'

    if ($force) {
        $userMsg = 'Declined'
        $statusType = 'Success'
    }

    Write-Status -Message "Update Property: $updateProp" -Type Info

    foreach ($searchString in $searchStrings) {
        $confirm = $false
        Write-Status -Message " - Update Search: $searchString" -Type Info
        $searchCount = 0
        foreach ($update in $updates) {
            if ($update.$($updateProp) -match "$searchString") {
                if ($update.IsApproved) {

                    if ($force) {
                        $update.Decline()
                    }
                    $searchCount = $searchCount + 1
                    Write-Status -Message "   [*]$($userMsg): $($update.Title), $($update.ProductTitles) ($searchString)" -Type $statusType
                }
            }
        }

        if ($searchCount -gt 0) {
            Write-Status -Message "$searchCount `"$searchString`" Updates $userMsg!" -Type Info
        } else {
            Write-Status -Message "      $searchCount `"$searchString`" Updates $userMsg" -Type Info
        }

        #Prompt user to confirm declining updates. Do no prompt if force flag is enable to prevent loop
        if ((-not $force) -and ($searchCount -ne 0)) {
            $confirm = Confirm-Prompt "Are you sure you want to decline all ($searchCount) listed ($searchString) updates?"

            if ($confirm) {
                Remove-Updates @($searchString) $updateProp $true | Out-Null
            }
        }

        if (($confirm) -or $force) {
            $declinedCount = ($declinedCount + $searchCount)
        }
    }

    return $declinedCount
}

function Invoke-DeepClean ($titles, $productTitles) {
    <#
    .SYNOPSIS
    Checks for unneeded WSUS updates to be deleted.

    .DESCRIPTION
    Checks for unneeded WSUS updates by product category to be deleted.

    .PARAMETER titles
    Array of titles of WSUS titles to search and prompt for removal

    .PARAMETER productTitles
    Array of WSUS product titles to search and prompt for removal

    .EXAMPLE
    DeepClean $titles $products

    .NOTES
    WSUS GetUpdates Method
    https://docs.microsoft.com/en-us/previous-versions/windows/desktop/aa350127(v=vs.85)

    WSUS IUpdate Properties
    https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ms752741(v=vs.85)

    WSUS Product List
    Get-WsusProduct
    https://docs.microsoft.com/en-us/powershell/module/wsus/get-wsusproduct?view=win10-ps

    WSUS Classification List
    Get-WsusClassification
    https://docs.microsoft.com/en-us/powershell/module/wsus/get-wsusclassification?view=win10-ps
    #>

    $declinedTotal = 0

    Write-Host "Make certain to carefully read the listed updates before choosing to remove them!" -BackgroundColor White -ForegroundColor Green

    #Remove updates by Title
    Write-Host "Searching for unneeded updates by Title. This process can take a long time. Please wait." -BackgroundColor White -ForegroundColor Blue
    $declinedTotal += Remove-Updates $titles 'Title'

    #Remove updates by ProductTitles
    Write-Host "Searching for unneeded updates by ProductTitle. This process can take a long time. Please wait." -BackgroundColor White -ForegroundColor Blue
    $declinedTotal += Remove-Updates $productTitles 'ProductTitles'

    #Remove drivers
    Write-Host "Searching for drivers to be removed from WSUS. This process can take a long time. Please wait." -BackgroundColor White -ForegroundColor Blue
    $declinedTotal += Remove-Updates @('Drivers') 'UpdateClassificationTitle'

    Write-Host "Searching for unneeded updates superseded by newer updates. This process can take a long time. Please wait." -BackgroundColor White -ForegroundColor Blue
    $declinedTotal += Decline-SupersededUpdates

    Write-Host "================DEEPCLEAN COMPLETE==================" -BackgroundColor White -ForegroundColor Blue
    Write-Host "$declinedTotal Total Updates Declined" -BackgroundColor White -ForegroundColor Blue
}

function Disable-WsusDriverSync {
    <#
    .SYNOPSIS
    Disable WSUS device driver synchronization and caching.

    .DESCRIPTION
    Disable WSUS device driver synchronization and caching. Automatic driver synchronization is one of the primary causes of WSUS slowness, crashing, and wasted storage space.

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/updateservices/set-wsusclassification?view=win10-ps
    #>

    Get-WsusClassification | Where-Object -FilterScript { $_.Classification.Title -eq "Drivers" } | Set-WsusClassification -Disable
    Get-WsusClassification | Where-Object -FilterScript { $_.Classification.Title -eq "Driver Sets" } | Set-WsusClassification -Disable
}

function Test-WsusUupMimeTypes {
    <#
    .SYNOPSIS
    Checks and optionally adds UUP MIME types required for Windows 11 updates.

    .DESCRIPTION
    Windows 11 22H2+ requires .msu and .wim MIME types to be configured in IIS.
    This function checks if they exist and can add them if missing.

    .PARAMETER Fix
    If specified, adds missing MIME types automatically.

    .LINK
    https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment
    #>
    param(
        [switch]$Fix
    )

    Import-Module WebAdministration -ErrorAction SilentlyContinue

    $requiredMimeTypes = @{
        '.msu' = 'application/octet-stream'
        '.wim' = 'application/x-ms-wim'
    }

    $missingTypes = @()

    foreach ($ext in $requiredMimeTypes.Keys) {
        $existing = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
            -Filter "system.webServer/staticContent/mimeMap[@fileExtension='$ext']" `
            -Name "mimeType" -ErrorAction SilentlyContinue

        if (-not $existing) {
            $missingTypes += $ext
            Write-Host "MIME type missing: $ext" -ForegroundColor Yellow
        } else {
            Write-Host "MIME type OK: $ext ($existing)" -ForegroundColor Green
        }
    }

    if ($missingTypes.Count -gt 0 -and $Fix) {
        foreach ($ext in $missingTypes) {
            try {
                Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                    -Filter "system.webServer/staticContent" `
                    -Name "." `
                    -Value @{fileExtension = $ext; mimeType = $requiredMimeTypes[$ext] }
                Write-Host "Added MIME type: $ext" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to add MIME type $ext : $_"
            }
        }
    } elseif ($missingTypes.Count -gt 0) {
        Write-Host ""
        Write-Host "Missing MIME types detected. Run with -Fix to add them, or add manually in IIS." -ForegroundColor Yellow
        Write-Host "These are required for Windows 11 22H2+ UUP updates." -ForegroundColor Yellow
    }

    return $missingTypes.Count -eq 0
}

function Get-WsusHealthStatus {
    <#
    .SYNOPSIS
    Performs health checks on the WSUS server and database.

    .DESCRIPTION
    Runs various health checks including:
    - Superseded update count (warning if >1500)
    - Database size
    - Content folder size
    - SSL configuration status
    - Update statistics

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-maintenance-guide
    #>

    Write-Host "================ WSUS HEALTH CHECK ================" -BackgroundColor Blue -ForegroundColor White
    Write-Host ""

    # Get WSUS configuration from registry
    $wsusSetup = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Update Services\Server\Setup" -ErrorAction SilentlyContinue

    # SSL Status Check
    Write-Host "[SSL Configuration]" -ForegroundColor Cyan
    if ($wsusSetup -and $wsusSetup.PSObject.Properties.Name -contains "UsingSSL") {
        if ($wsusSetup.UsingSSL) {
            Write-Host "  SSL: Enabled" -ForegroundColor Green
        } else {
            Write-Host "  SSL: Not configured (recommended for security)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  SSL: Not configured" -ForegroundColor Yellow
    }

    # Port Info
    if ($wsusSetup -and $wsusSetup.PSObject.Properties.Name -contains "PortNumber") {
        Write-Host "  Port: $($wsusSetup.PortNumber)" -ForegroundColor White
    }
    Write-Host ""

    # Content Folder Size
    Write-Host "[Storage]" -ForegroundColor Cyan
    if ($wsusSetup -and $wsusSetup.PSObject.Properties.Name -contains "ContentDir") {
        $contentDir = $wsusSetup.ContentDir
        if (Test-Path $contentDir) {
            $contentSize = (Get-ChildItem -Path $contentDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $contentSizeGB = [math]::Round($contentSize / 1GB, 2)
            Write-Host "  Content Folder: $contentDir" -ForegroundColor White
            Write-Host "  Content Size: $contentSizeGB GB" -ForegroundColor White
        }
    }

    # Database Info
    $wsusSqlServerName = $wsusSetup.SqlServername
    Write-Host "  Database: $wsusSqlServerName" -ForegroundColor White
    Write-Host ""

    # Update Statistics from Database
    Write-Host "[Update Statistics]" -ForegroundColor Cyan

    # Determine server instance for SQL queries
    switch -Regex ($wsusSqlServerName) {
        'SQLEXPRESS' { $serverInstance = 'np:\\.\pipe\MSSQL$SQLEXPRESS\sql\query'; break }
        '##WID' { $serverInstance = 'np:\\.\pipe\MICROSOFT##WID\tsql\query'; break }
        '##SSEE' { $serverInstance = 'np:\\.\pipe\MSSQL$MICROSOFT##SSEE\sql\query'; break }
        default { $serverInstance = $wsusSqlServerName }
    }

    try {
        $statsQuery = @"
SELECT
    (SELECT COUNT(*) FROM vwMinimalUpdate) AS TotalUpdates,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE declined=0) AS LiveUpdates,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE IsSuperseded=1) AS Superseded,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE IsSuperseded=1 AND declined=0) AS SupersededNotDeclined,
    (SELECT COUNT(*) FROM vwMinimalUpdate WHERE declined=1) AS Declined
"@
        $stats = Invoke-Sqlcmd -Query $statsQuery -ServerInstance $serverInstance -QueryTimeout 60 -Encrypt Optional

        Write-Host "  Total Updates: $($stats.TotalUpdates)" -ForegroundColor White
        Write-Host "  Live Updates: $($stats.LiveUpdates)" -ForegroundColor White
        Write-Host "  Superseded: $($stats.Superseded)" -ForegroundColor White
        Write-Host "  Declined: $($stats.Declined)" -ForegroundColor White

        # Check superseded but not declined (warning threshold: 1500)
        $supersededNotDeclined = $stats.SupersededNotDeclined
        if ($supersededNotDeclined -gt 1500) {
            Write-Host "  Superseded (not declined): $supersededNotDeclined" -ForegroundColor Red
            Write-Host "  WARNING: More than 1500 superseded updates not declined!" -ForegroundColor Red
            Write-Host "  This can cause client scanning issues. Run -OptimizeServer to clean up." -ForegroundColor Red
        } elseif ($supersededNotDeclined -gt 500) {
            Write-Host "  Superseded (not declined): $supersededNotDeclined" -ForegroundColor Yellow
        } else {
            Write-Host "  Superseded (not declined): $supersededNotDeclined" -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not query database statistics: $_"
    }

    Write-Host ""

    # UUP MIME Types Check
    Write-Host "[UUP MIME Types (Windows 11)]" -ForegroundColor Cyan
    Test-WsusUupMimeTypes | Out-Null

    Write-Host ""
    Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
}

function Get-VirtualMachineInfo {
    <#
    .SYNOPSIS
    Detects if the server is running in a virtual machine and identifies the hypervisor.

    .DESCRIPTION
    Detects common hypervisors including:
    - Microsoft Hyper-V
    - VMware (ESXi, Workstation, Fusion)
    - Proxmox/QEMU/KVM
    - VirtualBox
    - Xen

    Returns a hashtable with VM status and hypervisor name.

    .OUTPUTS
    Hashtable with IsVirtualMachine (bool) and Hypervisor (string)
    #>

    $result = @{
        IsVirtualMachine = $false
        Hypervisor       = "Physical"
        Model            = ""
        Manufacturer     = ""
    }

    try {
        # Get system information via WMI
        $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
        $bios = Get-WmiObject -Class Win32_BIOS

        $result.Model = $computerSystem.Model
        $result.Manufacturer = $computerSystem.Manufacturer

        # Check common VM indicators
        $model = $computerSystem.Model.ToLower()
        $manufacturer = $computerSystem.Manufacturer.ToLower()
        $biosVersion = $bios.Version.ToLower()
        $biosSerial = $bios.SerialNumber.ToLower()

        # Microsoft Hyper-V
        if ($model -match "virtual machine" -or $manufacturer -match "microsoft corporation") {
            if ($model -match "virtual") {
                $result.IsVirtualMachine = $true
                $result.Hypervisor = "Hyper-V"
                return $result
            }
        }

        # VMware
        if ($manufacturer -match "vmware" -or $model -match "vmware") {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "VMware"
            return $result
        }

        # Proxmox / QEMU / KVM
        if ($manufacturer -match "qemu" -or $model -match "qemu" -or
            $biosVersion -match "qemu" -or $manufacturer -match "proxmox" -or
            $model -match "standard pc" -or $model -match "kvm") {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "Proxmox/QEMU/KVM"
            return $result
        }

        # VirtualBox
        if ($model -match "virtualbox" -or $manufacturer -match "innotek" -or $biosVersion -match "virtualbox") {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "VirtualBox"
            return $result
        }

        # Xen
        if ($manufacturer -match "xen" -or $biosVersion -match "xen") {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "Xen"
            return $result
        }

        # Additional check: Look for hypervisor via processor
        $processor = Get-WmiObject -Class Win32_Processor | Select-Object -First 1
        if ($processor.Name -match "virtual|qemu") {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "Unknown (VM detected via CPU)"
            return $result
        }

        # Check for Hyper-V via feature flag (Windows built-in detection)
        $hypervisorPresent = (Get-WmiObject -Class Win32_ComputerSystem).HypervisorPresent
        if ($hypervisorPresent) {
            $result.IsVirtualMachine = $true
            $result.Hypervisor = "Unknown (Hypervisor present)"
            return $result
        }
    } catch {
        Write-Warning "Could not detect VM status: $_"
    }

    return $result
}

function Invoke-VMOptimization {
    <#
    .SYNOPSIS
    Applies VM-specific optimizations for WSUS servers.

    .DESCRIPTION
    When WSUS runs on a virtual machine, specific optimizations can improve performance:
    - Recommends higher IIS application pool memory limits
    - Suggests VM resource allocation
    - Disables unnecessary IIS features for VMs
    - Provides hypervisor-specific recommendations

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices
    #>

    Write-Host "================ VM OPTIMIZATION ================" -BackgroundColor Blue -ForegroundColor White
    Write-Host ""

    # Detect VM
    $vmInfo = Get-VirtualMachineInfo

    Write-Host "[System Detection]" -ForegroundColor Cyan
    Write-Host "  Manufacturer: $($vmInfo.Manufacturer)" -ForegroundColor White
    Write-Host "  Model: $($vmInfo.Model)" -ForegroundColor White

    if (-not $vmInfo.IsVirtualMachine) {
        Write-Host "  Status: Physical Server" -ForegroundColor Green
        Write-Host ""
        Write-Host "This server appears to be running on physical hardware." -ForegroundColor White
        Write-Host "VM-specific optimizations are not applicable." -ForegroundColor White
        Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
        return
    }

    Write-Host "  Status: Virtual Machine" -ForegroundColor Yellow
    Write-Host "  Hypervisor: $($vmInfo.Hypervisor)" -ForegroundColor Yellow
    Write-Host ""

    # Get current system resources
    $totalRAM = [math]::Round((Get-WmiObject -Class Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $cpuCount = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors

    Write-Host "[Current VM Resources]" -ForegroundColor Cyan
    Write-Host "  vCPUs: $cpuCount" -ForegroundColor White
    Write-Host "  RAM: $totalRAM GB" -ForegroundColor White
    Write-Host ""

    # Resource recommendations based on best practices
    Write-Host "[Recommendations for WSUS on VM]" -ForegroundColor Cyan
    Write-Host ""

    # CPU recommendations
    if ($cpuCount -lt 4) {
        Write-Host "  vCPU: Consider increasing to 4-6 vCPUs" -ForegroundColor Yellow
        Write-Host "        WSUS is CPU-intensive during sync and client scans." -ForegroundColor Gray
    } else {
        Write-Host "  vCPU: $cpuCount vCPUs is adequate" -ForegroundColor Green
    }

    # RAM recommendations
    if ($totalRAM -lt 8) {
        Write-Host "  RAM: Consider increasing to 8+ GB" -ForegroundColor Yellow
        Write-Host "       Minimum 4GB for small environments, 8GB+ recommended." -ForegroundColor Gray
    } else {
        Write-Host "  RAM: $totalRAM GB is adequate" -ForegroundColor Green
    }

    Write-Host ""

    # Hypervisor-specific recommendations
    Write-Host "[Hypervisor-Specific Tips]" -ForegroundColor Cyan
    switch -Regex ($vmInfo.Hypervisor) {
        "Hyper-V" {
            Write-Host "  - Use fixed-size VHDX for better I/O performance" -ForegroundColor White
            Write-Host "  - Enable NUMA spanning if using multiple vCPUs" -ForegroundColor White
            Write-Host "  - Consider using dynamic memory with 8GB minimum" -ForegroundColor White
        }
        "VMware" {
            Write-Host "  - Use PVSCSI adapter for disk I/O" -ForegroundColor White
            Write-Host "  - Use VMXNET3 for network adapter" -ForegroundColor White
            Write-Host "  - Ensure VMware Tools are up to date" -ForegroundColor White
            Write-Host "  - Consider memory reservation for consistent performance" -ForegroundColor White
        }
        "Proxmox|QEMU|KVM" {
            Write-Host "  - Use VirtIO drivers for disk and network" -ForegroundColor White
            Write-Host "  - Enable 'host' CPU type for best performance" -ForegroundColor White
            Write-Host "  - Consider using local SSD storage for WSUS database" -ForegroundColor White
            Write-Host "  - Install QEMU Guest Agent for better integration" -ForegroundColor White
        }
        "VirtualBox" {
            Write-Host "  - VirtualBox is not recommended for production WSUS" -ForegroundColor Yellow
            Write-Host "  - Consider migrating to Hyper-V, VMware, or Proxmox" -ForegroundColor Yellow
            Write-Host "  - If using VirtualBox, enable VT-x/AMD-V and nested paging" -ForegroundColor White
        }
        default {
            Write-Host "  - Ensure guest tools/agents are installed" -ForegroundColor White
            Write-Host "  - Use paravirtualized drivers where available" -ForegroundColor White
        }
    }

    Write-Host ""

    # IIS Settings for VMs
    Write-Host "[IIS Settings for VM Environment]" -ForegroundColor Cyan
    Write-Host "  Running -CheckConfig to validate IIS settings..." -ForegroundColor White
    Write-Host "  VM environments should use unlimited memory (RecyclingPrivateMemory = 0)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
}

function Invoke-LowStorageOptimization {
    <#
    .SYNOPSIS
    Configures WSUS for low storage environments.

    .DESCRIPTION
    Applies aggressive storage-saving measures:
    - Configures WSUS to not store update files locally (clients download from Microsoft)
    - Disables express installation files
    - Enables upgrade deferral for feature updates
    - Provides storage usage report

    WARNING: This will change how updates are delivered. Clients will download
    directly from Microsoft Update instead of your WSUS server.

    .LINK
    https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment
    #>

    Write-Host "================ LOW STORAGE MODE ================" -BackgroundColor Blue -ForegroundColor White
    Write-Host ""

    # Get current storage usage
    $wsusSetup = Get-ItemProperty -Path "HKLM:\Software\Microsoft\Update Services\Server\Setup" -ErrorAction SilentlyContinue

    if (-not $wsusSetup) {
        Write-Warning "Could not read WSUS configuration from registry."
        return
    }

    Write-Host "[Current Storage Usage]" -ForegroundColor Cyan

    $contentDir = $wsusSetup.ContentDir
    if ($contentDir -and (Test-Path $contentDir)) {
        $contentSize = (Get-ChildItem -Path $contentDir -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        $contentSizeGB = [math]::Round($contentSize / 1GB, 2)
        Write-Host "  Content Directory: $contentDir" -ForegroundColor White
        Write-Host "  Current Size: $contentSizeGB GB" -ForegroundColor White

        # Get disk free space
        $drive = (Get-Item $contentDir).PSDrive.Name
        $diskInfo = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='${drive}:'"
        $freeSpaceGB = [math]::Round($diskInfo.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($diskInfo.Size / 1GB, 2)
        $usedPercent = [math]::Round((($totalSpaceGB - $freeSpaceGB) / $totalSpaceGB) * 100, 1)

        Write-Host "  Disk Free Space: $freeSpaceGB GB / $totalSpaceGB GB ($usedPercent% used)" -ForegroundColor White

        if ($freeSpaceGB -lt 20) {
            Write-Host "  WARNING: Low disk space!" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "[Storage Saving Options]" -ForegroundColor Cyan
    Write-Host ""

    # Check current express files setting
    $expressEnabled = $false
    try {
        $wsusConfig = (Get-ActiveWsusServer).GetConfiguration()
        $expressEnabled = $wsusConfig.DownloadExpressPackages
        $localContentCaching = -not $wsusConfig.DownloadUpdateBinariesAsNeeded

        Write-Host "  Express Installation Files: $(if ($expressEnabled) { 'Enabled (uses more space)' } else { 'Disabled' })" -ForegroundColor White
        Write-Host "  Local Content Caching: $(if ($localContentCaching) { 'Enabled (stores files locally)' } else { 'Disabled (clients download from MS)' })" -ForegroundColor White
    } catch {
        Write-Warning "Could not query current WSUS settings: $_"
    }

    Write-Host ""
    Write-Host "[Recommended Actions for Low Storage]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Disable Express Installation Files" -ForegroundColor White
    Write-Host "   Saves significant space but increases client download time." -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Enable 'Download updates only when approved'" -ForegroundColor White
    Write-Host "   Prevents downloading unused updates." -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Configure clients to download from Microsoft" -ForegroundColor White
    Write-Host "   Set 'DownloadUpdateBinariesAsNeeded' = True" -ForegroundColor Gray
    Write-Host "   WSUS approves updates, clients download from Microsoft Update." -ForegroundColor Gray
    Write-Host ""
    Write-Host "4. Run cleanup to remove obsolete content" -ForegroundColor White
    Write-Host "   Use -OptimizeServer to clean up unneeded files." -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Disable driver synchronization" -ForegroundColor White
    Write-Host "   Use -DisableDrivers to prevent driver updates." -ForegroundColor Gray
    Write-Host ""

    $applyChanges = Confirm-Prompt "Apply storage-saving configuration changes? (Disables express files, enables download-on-demand)"

    if ($applyChanges) {
        Write-Host ""
        Write-Host "Applying storage-saving configuration..." -ForegroundColor Cyan
        try {
            $wsusServer = Get-ActiveWsusServer
            $wsusConfig = $wsusServer.GetConfiguration()

            # Disable express installation files
            if ($wsusConfig.DownloadExpressPackages) {
                $wsusConfig.DownloadExpressPackages = $false
                Write-Host "  Disabled Express Installation Files" -ForegroundColor Green
            }

            # Enable download binaries as needed (clients download from MS)
            if (-not $wsusConfig.DownloadUpdateBinariesAsNeeded) {
                $wsusConfig.DownloadUpdateBinariesAsNeeded = $true
                Write-Host "  Enabled Download-on-Demand (clients download from Microsoft)" -ForegroundColor Green
            }

            $wsusConfig.Save()
            Write-Host ""
            Write-Host "Configuration saved successfully!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "  1. Run -OptimizeServer to clean up existing cached content" -ForegroundColor White
            Write-Host "  2. Run -DisableDrivers if you don't need driver updates" -ForegroundColor White
            Write-Host "  3. Review approved products and remove unused categories" -ForegroundColor White
        } catch {
            Write-Error "Failed to apply configuration: $_"
        }
    } else {
        Write-Host ""
        Write-Host "No changes made." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
}

#----------------------------------------------------------[Logging Functions]----------------------------------------------------------

function Write-Log {
    <#
    .SYNOPSIS
    Writes a message to both console and log file.

    .PARAMETER Message
    The message to write.

    .PARAMETER Level
    The log level: Info, Warning, Error, Success.

    .PARAMETER LogFile
    Path to the log file. If not specified, uses $script:LogFilePath.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warning', 'Error', 'Success')]
        [string]$Level = 'Info',

        [Parameter()]
        [string]$LogFile = $script:LogFilePath
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Console output with colors
    switch ($Level) {
        'Info' { Write-Host $Message -ForegroundColor White }
        'Warning' { Write-Host $Message -ForegroundColor Yellow }
        'Error' { Write-Host $Message -ForegroundColor Red }
        'Success' { Write-Host $Message -ForegroundColor Green }
    }

    # File output
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
}

function Initialize-Logging {
    <#
    .SYNOPSIS
    Initializes logging for the script.

    .PARAMETER LogPath
    Directory path for log files. Defaults to script directory.

    .PARAMETER LogRotateDays
    Number of days to keep log files. Older files are deleted.
    #>
    param(
        [Parameter()]
        [string]$LogPath,

        [Parameter()]
        [int]$LogRotateDays = 30
    )

    # Set default log path to script directory
    if (-not $LogPath) {
        $LogPath = Split-Path -Parent $PSCommandPath
    }

    # Create log directory if it doesn't exist
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }

    # Create log file with timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFilePath = Join-Path $LogPath "Optimize-WsusServer_$timestamp.log"

    # Log rotation - remove old log files
    if ($LogRotateDays -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$LogRotateDays)
        Get-ChildItem -Path $LogPath -Filter "Optimize-WsusServer_*.log" -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoffDate } |
            ForEach-Object {
                Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed old log file: $($_.Name)"
            }
    }

    # Write header to log file
    $header = @"
================================================================================
Optimize-WsusServer Log
Started: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Computer: $env:COMPUTERNAME
User: $env:USERNAME
================================================================================
"@
    Set-Content -Path $script:LogFilePath -Value $header

    return $script:LogFilePath
}

function Send-EmailReport {
    <#
    .SYNOPSIS
    Sends an email report with the log file attached.

    .PARAMETER SmtpServer
    SMTP server hostname.

    .PARAMETER To
    Recipient email address(es).

    .PARAMETER From
    Sender email address.

    .PARAMETER Subject
    Email subject line.

    .PARAMETER Body
    Email body text.

    .PARAMETER AttachLog
    Whether to attach the log file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SmtpServer,

        [Parameter(Mandatory = $true)]
        [string]$To,

        [Parameter(Mandatory = $true)]
        [string]$From,

        [Parameter()]
        [string]$Subject = "WSUS Optimization Report - $env:COMPUTERNAME",

        [Parameter()]
        [string]$Body,

        [Parameter()]
        [switch]$AttachLog
    )

    if (-not $Body) {
        $Body = @"
WSUS Optimization Report

Server: $env:COMPUTERNAME
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

The WSUS optimization script has completed. Please see the attached log file for details.

This is an automated message from Optimize-WsusServer.ps1
"@
    }

    $mailParams = @{
        SmtpServer = $SmtpServer
        To         = $To
        From       = $From
        Subject    = $Subject
        Body       = $Body
    }

    if ($AttachLog -and $script:LogFilePath -and (Test-Path $script:LogFilePath)) {
        $mailParams['Attachments'] = $script:LogFilePath
    }

    try {
        Send-MailMessage @mailParams
        Write-Log "Email report sent to $To" -Level Success
    } catch {
        Write-Log "Failed to send email report: $_" -Level Error
    }
}

#----------------------------------------------------------[Remote WSUS Support]----------------------------------------------------------

function Get-WsusServerConnection {
    <#
    .SYNOPSIS
    Gets a WSUS server connection, supporting both local and remote servers.

    .PARAMETER ServerName
    The WSUS server name. If not specified, connects to local server.

    .PARAMETER PortNumber
    The WSUS port number. Defaults to 8530 (HTTP) or 8531 (SSL).

    .PARAMETER UseSSL
    Whether to use SSL for the connection.
    #>
    param(
        [Parameter()]
        [string]$ServerName,

        [Parameter()]
        [int]$PortNumber,

        [Parameter()]
        [switch]$UseSSL
    )

    [reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

    # If no server specified, use local detection
    if (-not $ServerName) {
        return Get-WsusServerInstance
    }

    # Remote server connection
    try {
        # Default ports
        if (-not $PortNumber) {
            $PortNumber = if ($UseSSL) { 8531 } else { 8530 }
        }

        Write-Log "Connecting to WSUS server: $ServerName`:$PortNumber (SSL: $UseSSL)" -Level Info

        $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($ServerName, $UseSSL, $PortNumber)
        Write-Log "Connected to remote WSUS server successfully" -Level Success

        return $wsus
    } catch {
        Write-Log "Failed to connect to WSUS server $ServerName`: $_" -Level Error
        throw
    }
}

#----------------------------------------------------------[Auto-Approve Functions]----------------------------------------------------------

function Invoke-AutoApproveUpdates {
    <#
    .SYNOPSIS
    Automatically approves updates based on configurable rules.

    .DESCRIPTION
    Approves updates for specified computer groups based on:
    - Update classification (Critical, Security, Definition, etc.)
    - Product categories
    - Age of update (days since release)

    .LINK
    https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/manage/updates-operations
    #>

    Write-Host "================ AUTO-APPROVE UPDATES ================" -BackgroundColor Blue -ForegroundColor White
    Write-Host ""

    try {
        $wsusServer = Get-ActiveWsusServer

        # Get all computer groups
        $computerGroups = $wsusServer.GetComputerTargetGroups()
        Write-Host "[Computer Groups]" -ForegroundColor Cyan
        $groupList = @()
        $i = 1
        foreach ($group in $computerGroups) {
            Write-Host "  $i. $($group.Name)" -ForegroundColor White
            $groupList += $group
            $i++
        }
        Write-Host ""

        # Ask which group to approve for
        Write-Host "Enter group number to approve updates for (or 'all' for All Computers): " -ForegroundColor Yellow -NoNewline
        $groupChoice = Read-Host

        $targetGroup = $null
        if ($groupChoice -eq 'all') {
            $targetGroup = $computerGroups | Where-Object { $_.Name -eq 'All Computers' }
        } elseif ($groupChoice -match '^\d+$' -and [int]$groupChoice -le $groupList.Count) {
            $targetGroup = $groupList[[int]$groupChoice - 1]
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "Target group: $($targetGroup.Name)" -ForegroundColor Cyan
        Write-Host ""

        # Get update classifications
        Write-Host "[Update Classifications to Auto-Approve]" -ForegroundColor Cyan
        $defaultClassifications = @(
            'Critical Updates',
            'Security Updates',
            'Definition Updates',
            'Update Rollups'
        )

        Write-Host "Default classifications:" -ForegroundColor White
        $defaultClassifications | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        Write-Host ""

        $useDefaults = Confirm-Prompt "Use default classifications?"

        $selectedClassifications = @()
        if ($useDefaults) {
            $selectedClassifications = $defaultClassifications
        } else {
            $allClassifications = $wsusServer.GetUpdateClassifications()
            Write-Host ""
            Write-Host "Available classifications:" -ForegroundColor White
            $i = 1
            foreach ($class in $allClassifications) {
                Write-Host "  $i. $($class.Title)" -ForegroundColor White
                $i++
            }
            Write-Host ""
            Write-Host "Enter classification numbers separated by comma (e.g., 1,2,3): " -ForegroundColor Yellow -NoNewline
            $classChoice = Read-Host
            $classNums = $classChoice -split ',' | ForEach-Object { [int]$_.Trim() }
            foreach ($num in $classNums) {
                if ($num -le $allClassifications.Count) {
                    $selectedClassifications += $allClassifications[$num - 1].Title
                }
            }
        }

        Write-Host ""
        Write-Host "Searching for updates to approve..." -ForegroundColor Cyan

        # Get unapproved updates matching our criteria
        $updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
        $updateScope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::NotApproved

        $updates = $wsusServer.GetUpdates($updateScope)
        $matchingUpdates = @()

        foreach ($update in $updates) {
            # Skip declined updates
            if ($update.IsDeclined) { continue }

            # Check classification
            $updateClass = $update.UpdateClassificationTitle
            if ($selectedClassifications -contains $updateClass) {
                $matchingUpdates += $update
            }
        }

        Write-Host ""
        Write-Host "Found $($matchingUpdates.Count) updates matching criteria." -ForegroundColor White

        if ($matchingUpdates.Count -eq 0) {
            Write-Host "No updates to approve." -ForegroundColor Green
            Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
            return
        }

        # Show summary by classification
        Write-Host ""
        Write-Host "[Updates by Classification]" -ForegroundColor Cyan
        $matchingUpdates | Group-Object UpdateClassificationTitle | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor White
        }

        Write-Host ""
        $approve = Confirm-Prompt "Approve these $($matchingUpdates.Count) updates for '$($targetGroup.Name)'?"

        if ($approve) {
            Write-Host ""
            Write-Host "Approving updates..." -ForegroundColor Cyan
            $approved = 0
            $failed = 0

            foreach ($update in $matchingUpdates) {
                try {
                    $update.Approve([Microsoft.UpdateServices.Administration.UpdateApprovalAction]::Install, $targetGroup) | Out-Null
                    $approved++
                    Write-Host "  Approved: $($update.Title)" -ForegroundColor Green
                } catch {
                    $failed++
                    Write-Host "  Failed: $($update.Title) - $_" -ForegroundColor Red
                }
            }

            Write-Host ""
            Write-Host "Approval complete: $approved approved, $failed failed" -ForegroundColor Cyan
            Write-Log "Auto-approved $approved updates for group '$($targetGroup.Name)'" -Level Success
        } else {
            Write-Host "No updates approved." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Error during auto-approve: $_" -ForegroundColor Red
        Write-Log "Auto-approve failed: $_" -Level Error
    }

    Write-Host ""
    Write-Host "=================================================" -BackgroundColor Blue -ForegroundColor White
}

function Unblock-WebConfigAcl {
    <#
    .SYNOPSIS
    Grants local admins access to web.config

    .DESCRIPTION
    Grants BUILTIN\Administrators ownership and read write access to ClientWebService web.config. Also removes Read Only flag.

    .LINK
    https://devblogs.microsoft.com/scripting/use-powershell-to-translate-a-users-sid-to-an-active-directory-account-name/
    https://docs.microsoft.com/en-us/dotnet/api/system.security.principal.securityidentifier.-ctor?view=windowsdesktop-5.0#System_Security_Principal_SecurityIdentifier__ctor_System_String_
    #>

    $wsusWebConfigPath = Get-WebConfigFile -PSPath $script:IISPath | Select-Object -ExpandProperty 'FullName'

    # Get localized BUILTIN\Administrators group
    $builtinAdminGroup = ([System.Security.Principal.SecurityIdentifier]'S-1-5-32-544').Translate([System.Security.Principal.NTAccount]).Value

    Set-FileAclOwner $wsusWebConfigPath $builtinAdminGroup
    Set-FileAclPermissions $wsusWebConfigPath $builtinAdminGroup 'FullControl' 'None' 'None' 'Allow'
    Set-ItemProperty -Path $wsusWebConfigPath -Name IsReadOnly -Value $false
}

function Set-FileAclOwner ($file, $owner) {
    <#
    .SYNOPSIS
    Sets NTFS file owner

    .DESCRIPTION
    Sets NTFS file owner

    .PARAMETER file
    File path as string

    .PARAMETER owner
    Account as string to set as owner

    .LINK
    https://stackoverflow.com/questions/22988384/powershell-change-owner-of-files-and-folders
    #>

    $acl = Get-Acl($file)
    $account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $owner
    $acl.SetOwner($account)
    Set-Acl -Path $file -AclObject $acl
}

function Set-FileAclPermissions ($file, $accString, $rights, $inheritanceFlags, $propagationFlags, $type) {
    <#
    .SYNOPSIS
    Set NTFS file permissions

    .DESCRIPTION
    Set NTFS permissions for specified file

    .PARAMETER file
    File path as string

    .PARAMETER accString
    Account to set permissions for as string

    .PARAMETER rights
    Access Rights - https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemrights?view=dotnet-plat-ext-3.1

    .PARAMETER inheritanceFlags
    Inheritence flags - https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.inheritanceflags?view=dotnet-plat-ext-3.1

    .PARAMETER propagationFlags
    Propagation flags - https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.propagationflags?view=dotnet-plat-ext-3.1

    .PARAMETER type
    Access control type - https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.accesscontroltype?view=dotnet-plat-ext-3.1

    .LINK
    https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-acl?view=powershell-7

    .LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.filesystemaccessrule.-ctor?view=dotnet-plat-ext-3.1#System_Security_AccessControl_FileSystemAccessRule__ctor_System_String_System_Security_AccessControl_FileSystemRights_System_Security_AccessControl_InheritanceFlags_System_Security_AccessControl_PropagationFlags_System_Security_AccessControl_AccessControlType_
    #>

    $acl = Get-Acl($file)
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $accString, $rights, $inheritanceFlags, $propagationFlags, $type
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $file -AclObject $acl
}

function Decline-SupersededUpdates ($verbose) {
    <#
    .SYNOPSIS
    Declines approved updates that have been approved and are superseded by other updates.

    .DESCRIPTION
    Declines all updates that have been approved and are superseded by other updates. The update will only be declined if a superseding update has been approved.

    .LINK
    ApprovedStates - https://docs.microsoft.com/en-us/previous-versions/windows/desktop/aa354257(v=vs.85)

    .LINK
    IUpdate - https://docs.microsoft.com/en-us/previous-versions/windows/desktop/bb313429(v=vs.85)

    .LINK
    UpdateCollection - https://docs.microsoft.com/en-us/previous-versions/windows/desktop/ms752803(v=vs.85)
    #>
    $declineCount = 0
    $wsusServer = Get-ActiveWsusServer
    $scope = New-Object Microsoft.UpdateServices.Administration.UpdateScope

    $scope.ApprovedStates = "LatestRevisionApproved"
    $updates = $wsusServer.GetUpdates($scope)

    foreach ($update in $updates) {
        $updatesThatSupersede = $update.GetRelatedUpdates("UpdatesThatSupersedeThisUpdate")
        if ($updatesThatSupersede.Count -gt 0) {
            foreach ($super in $updatesThatSupersede) {
                if ($super.IsApproved) {
                    $update.Decline()
                    $declineCount++
                    break
                }
            }
        }
    }

    if ($verbose) {
        Write-Host "Osbolete Updates Declined: $declineCount"
    } else {
        return $declineCount
    }
}
#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Initialize logging if LogPath is specified
if ($LogPath) {
    $logFile = Initialize-Logging -LogPath $LogPath -LogRotateDays $LogRotateDays
    Write-Log "Optimize-WsusServer started" -Level Info
    Write-Log "Parameters: $($PSBoundParameters.Keys -join ', ')" -Level Info
}

# Override WSUS connection if remote server is specified
if ($WsusServer) {
    $script:WsusConnection = Get-WsusServerConnection -ServerName $WsusServer -PortNumber $WsusPort -UseSSL:$UseSSL
}

# Check commandline parameters.
switch ($true) {
    ($FirstRun) {
        Write-Host "All of the following processes are highly recommended!" -ForegroundColor Blue -BackgroundColor White

        switch ($true) {
            (Confirm-Prompt "Run WSUS IIS configuration optimization?") {
                $wsusIISConfig = Get-WsusIISConfig
                Test-WsusIISConfig $wsusIISConfig $recommendedIISSettings
            }
            (Confirm-Prompt "Run WSUS database optimization?") {
                Optimize-WsusDatabase
            }
            (Confirm-Prompt "Run WSUS server optimization?") {
                Optimize-WsusUpdates
            }
            (Confirm-Prompt "Create daily WSUS server optimization scheduled task?") {
                New-WsusMaintenanceTask('Daily')
            }
            (Confirm-Prompt "Create weekly WSUS database optimization scheduled task?") {
                New-WsusMaintenanceTask('Weekly')
            }
            (Confirm-Prompt "Disable device driver synchronization?") {
                Disable-WsusDriverSync
            }
        }
        break
    }
    ($DisableDrivers) {
        Disable-WsusDriverSync
    }
    ($DeclineSupersededUpdates) {
        Decline-SupersededUpdates
    }
    ($DeepClean) {
        Invoke-DeepClean $unneededUpdatesbyTitle $unneededUpdatesbyProductTitles
    }
    ($InstallDailyTask) {
        New-WsusMaintenanceTask('Daily')
    }
    ($InstallWeeklyTask) {
        New-WsusMaintenanceTask('Weekly')
    }
    ($CheckConfig) {
        $wsusIISConfig = Get-WsusIISConfig
        Test-WsusIISConfig $wsusIISConfig $recommendedIISSettings
    }
    ($OptimizeServer) {
        Optimize-WsusUpdates
    }
    ($OptimizeDatabase) {
        Optimize-WsusDatabase
    }
    ($HealthCheck) {
        Get-WsusHealthStatus
    }
    ($FixUupMimeTypes) {
        Test-WsusUupMimeTypes -Fix
    }
    ($OptimizeForVM) {
        Invoke-VMOptimization
    }
    ($LowStorageMode) {
        Invoke-LowStorageOptimization
    }
    ($AutoApproveUpdates) {
        Invoke-AutoApproveUpdates
    }
}

# Send email report if SMTP settings are configured
if ($SmtpServer -and $EmailTo -and $EmailFrom) {
    Send-EmailReport -SmtpServer $SmtpServer -To $EmailTo -From $EmailFrom -AttachLog
}

# Log completion
if ($LogPath) {
    Write-Log "Optimize-WsusServer completed" -Level Success
}
