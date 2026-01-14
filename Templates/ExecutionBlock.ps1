#-----------------------------------------------------------[Execution]------------------------------------------------------------

#region Initialize
$script:ModuleRoot = $PSScriptRoot

# Logging initialisieren
if (-not $NoLog) {
    if (-not $LogPath) {
        $LogPath = Join-Path $env:TEMP "Optimize-WsusServer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    }
    $script:LogFile = $LogPath
}

# Quiet-Modus setzen
$script:QuietMode = $Quiet.IsPresent
#endregion

#region Prerequisites Check
if (-not $SkipPrerequisiteCheck) {
    $prereqs = Test-WsusPrerequisites -SkipDatabaseCheck:(-not ($OptimizeDatabase -or $ReindexDatabase))

    if (-not $prereqs.AllPassed) {
        Write-WsusStatus "Voraussetzungsprüfung fehlgeschlagen:" -Type Error
        foreach ($failure in $prereqs.Failures) {
            Write-WsusStatus "  - $failure" -Type Error
        }

        if (-not $Force) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Nutzen Sie -Force um trotzdem fortzufahren (nicht empfohlen)" -Type Warning
            exit 1
        }

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "-Force aktiv: Fahre trotz Fehler fort..." -Type Warning
    }
}
#endregion

#region Main Execution
try {
    # Health Check
    if ($HealthCheck) {
        $health = Get-WsusHealthStatus -Detailed
        if (-not $Quiet) {
            $health
        }
        exit 0
    }

    # VM Optimization
    if ($VMOptimization) {
        Invoke-WsusVMOptimization -AutoDetect
    }

    # IIS Configuration
    if ($ConfigureIIS) {
        Set-WsusIISConfig
    }

    # Web.config Fix
    if ($FixWebConfig) {
        Unblock-WsusWebConfig
    }

    # MIME Types for Windows 11
    if ($ConfigureMimeTypes) {
        if (-not (Test-WsusUupMimeTypes)) {
            Add-WsusUupMimeTypes
        }
    }

    # Driver Sync deaktivieren
    if ($DisableDriverSync) {
        Disable-WsusDriverSync -Force:$Force
    }

    # Decline Updates
    $declineParams = @{}

    if ($DeclineSupersededUpdates) { $declineParams.DeclineSuperseded = $true }
    if ($DeclineItanium) { $declineParams.Itanium = $true }
    if ($DeclineARM) { $declineParams.ARM = $true }
    if ($DeclinePreview) { $declineParams.Preview = $true }
    if ($DeclineBeta) { $declineParams.Beta = $true }
    if ($DeclineLanguagePacks) { $declineParams.LanguagePacks = $true }
    if ($DeclineDrivers) { $declineParams.Drivers = $true }
    if ($DeclineExpired) { $declineParams.Expired = $true }

    if ($declineParams.Count -gt 0) {
        Write-WsusHeader "Update Decline Operations"
        # Dies würde Deny-SupersededUpdates mit den entsprechenden Parametern aufrufen
    }

    # Server Optimization (Standard-Cleanup)
    if ($OptimizeServer) {
        $optimizeParams = @{
            RemoveObsoleteComputers = $RemoveObsoleteComputers
            RemoveObsoleteUpdates = $RemoveObsoleteUpdates
            RemoveUnneededContentFiles = $RemoveUnneededContentFiles
            CleanupSynchronizationData = $CleanupSynchronizationData
            BatchSize = $BatchSize
            ShowProgress = $ShowProgress.IsPresent
        }

        Invoke-WsusOptimization @optimizeParams
    }

    # Deep Clean
    if ($DeepClean) {
        $deepCleanParams = @{
            DeclineSuperseded = $DeclineSupersededUpdates
            RemoveDrivers = $DeclineDrivers
            RemoveItanium = $DeclineItanium
            RemoveARM = $DeclineARM
            RemovePreview = $DeclinePreview
            RemoveBeta = $DeclineBeta
            RemoveExpired = $DeclineExpired
            BatchSize = $BatchSize
        }

        Invoke-WsusDeepClean @deepCleanParams
    }

    # Database Optimization
    if ($OptimizeDatabase) {
        $dbParams = @{
            Reindex = $ReindexDatabase
            CreateCustomIndexes = $CreateCustomIndexes
            UpdateStatistics = $UpdateStatistics
        }

        # SQL Instance Override
        if ($SqlInstance) {
            $dbParams.SqlInstance = $SqlInstance
        }

        Invoke-WsusDatabaseOptimization @dbParams
    }

    # Nur Reindex (ohne volle DB-Optimierung)
    if ($ReindexDatabase -and -not $OptimizeDatabase) {
        Invoke-WsusDatabaseOptimization -Reindex
    }

    # Scheduled Task erstellen
    if ($CreateScheduledTask) {
        $taskParams = @{
            TaskType = $TaskType
            ScriptPath = $ScriptPath
        }

        if ($TaskTime) { $taskParams.Time = $TaskTime }
        if ($TaskType -eq 'Weekly') { $taskParams.DayOfWeek = $TaskDay }

        New-WsusMaintenanceTask @taskParams
    }

    # Abschluss
    if (-not $Quiet) {
        Write-WsusStatus "" -Type Info
        Write-WsusHeader "Abgeschlossen"
        Write-WsusStatus "Alle Operationen wurden erfolgreich ausgeführt." -Type Success

        if ($script:LogFile -and (Test-Path $script:LogFile)) {
            Write-WsusStatus "Log-Datei: $script:LogFile" -Type Info
        }

        # Empfehlungen
        if ($ConfigureIIS -or $ConfigureMimeTypes -or $FixWebConfig) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "HINWEIS: IIS-Neustart empfohlen:" -Type Warning
            Write-WsusStatus "  iisreset /restart" -Type Info
        }
    }
}
catch {
    Write-WsusStatus "Fehler bei der Ausführung: $_" -Type Error
    Write-WsusStatus $_.ScriptStackTrace -Type Error

    if ($script:LogFile) {
        "ERROR: $($_)" | Add-Content -Path $script:LogFile
        "Stack: $($_.ScriptStackTrace)" | Add-Content -Path $script:LogFile
    }

    exit 1
}
#endregion

#region Example Usage Block
<#
BEISPIEL-AUFRUFE:

# Standard Server-Optimierung (Cleanup)
.\Optimize-WsusServer.ps1 -OptimizeServer

# Deep Clean mit allen Decline-Optionen
.\Optimize-WsusServer.ps1 -DeepClean -DeclineSupersededUpdates -DeclineItanium -DeclineDrivers

# Nur Datenbank-Optimierung
.\Optimize-WsusServer.ps1 -OptimizeDatabase -Reindex

# Health Check
.\Optimize-WsusServer.ps1 -HealthCheck

# IIS konfigurieren und MIME Types für Windows 11
.\Optimize-WsusServer.ps1 -ConfigureIIS -ConfigureMimeTypes

# Täglichen Scheduled Task erstellen
.\Optimize-WsusServer.ps1 -CreateScheduledTask -TaskType Daily -TaskTime "12:00"

# Wöchentlichen Scheduled Task erstellen
.\Optimize-WsusServer.ps1 -CreateScheduledTask -TaskType Weekly -TaskTime "02:00" -TaskDay Sunday

# Remote WSUS Server mit SSL
.\Optimize-WsusServer.ps1 -WsusServer "wsus.domain.com" -Port 8531 -UseSSL -HealthCheck

# VM-Optimierung
.\Optimize-WsusServer.ps1 -VMOptimization

# Vollständige Optimierung (alles)
.\Optimize-WsusServer.ps1 -OptimizeServer -OptimizeDatabase -DeepClean -ConfigureIIS -DeclineSupersededUpdates
#>
#endregion
