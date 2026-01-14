function New-WsusMaintenanceTask {
    <#
    .SYNOPSIS
    Erstellt Scheduled Tasks für automatische WSUS-Wartung.

    .DESCRIPTION
    Erstellt Windows Scheduled Tasks für regelmäßige WSUS-Optimierung:
    - Daily: Server-Cleanup (obsolete Updates, Computer, etc.)
    - Weekly: Datenbank-Optimierung (Defragmentierung, Index-Rebuild)

    Die Tasks laufen unter NT AUTHORITY\SYSTEM mit höchsten Rechten.

    .PARAMETER TaskType
    Art des Tasks: Daily oder Weekly

    .PARAMETER Time
    Ausführungszeit. Standard: 12:00 (Daily) oder 02:00 (Weekly)

    .PARAMETER DayOfWeek
    Wochentag für Weekly Tasks. Standard: Sunday

    .PARAMETER ScriptPath
    Pfad wo das Script abgelegt werden soll. Standard: C:\Scripts

    .EXAMPLE
    New-WsusMaintenanceTask -TaskType Daily
    # Erstellt täglichen Task um 12:00

    .EXAMPLE
    New-WsusMaintenanceTask -TaskType Weekly -Time "03:00" -DayOfWeek Saturday
    # Erstellt wöchentlichen Task samstags um 03:00

    .EXAMPLE
    New-WsusMaintenanceTask -TaskType Daily -ScriptPath "D:\Scripts"
    # Verwendet alternativen Script-Pfad
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Daily', 'Weekly')]
        [string]$TaskType,

        [Parameter()]
        [string]$Time,

        [Parameter()]
        [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
        [string]$DayOfWeek = 'Sunday',

        [Parameter()]
        [string]$ScriptPath = 'C:\Scripts'
    )

    $taskName = "Optimize WSUS Server ($TaskType)"

    # Defaults
    if (-not $Time) {
        $Time = switch ($TaskType) {
            'Daily'  { '12:00' }
            'Weekly' { '02:00' }
        }
    }

    Write-WsusStatus "Erstelle Scheduled Task: $taskName" -Type Info
    Write-WsusStatus "  Zeit: $Time" -Type Info
    if ($TaskType -eq 'Weekly') {
        Write-WsusStatus "  Tag: $DayOfWeek" -Type Info
    }

    # Existierenden Task entfernen
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        if ($PSCmdlet.ShouldProcess($taskName, "Existierenden Task entfernen")) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-WsusStatus "  Existierender Task entfernt" -Type Info
        }
    }

    # Script-Verzeichnis erstellen
    if (-not (Test-Path $ScriptPath)) {
        if ($PSCmdlet.ShouldProcess($ScriptPath, "Verzeichnis erstellen")) {
            New-Item -Path $ScriptPath -ItemType Directory -Force | Out-Null
            Write-WsusStatus "  Verzeichnis erstellt: $ScriptPath" -Type Info
        }
    }

    # Script kopieren
    $scriptName = 'Optimize-WsusServer.ps1'
    $targetScript = Join-Path $ScriptPath $scriptName

    # Aktuelles Script oder Modul-Script finden
    $sourceScript = $PSCommandPath
    if (-not $sourceScript -or -not (Test-Path $sourceScript)) {
        # Versuche aus Modul-Pfad
        $sourceScript = Join-Path $script:ModuleRoot 'dist\Optimize-WsusServer.ps1'
    }
    if (-not $sourceScript -or -not (Test-Path $sourceScript)) {
        # Fallback: Originalscript im Repo
        $sourceScript = Join-Path (Split-Path $script:ModuleRoot -Parent) 'Optimize-WsusServer.ps1'
    }

    if ($sourceScript -and (Test-Path $sourceScript)) {
        if ($PSCmdlet.ShouldProcess($targetScript, "Script kopieren")) {
            Copy-Item -Path $sourceScript -Destination $targetScript -Force
            Write-WsusStatus "  Script kopiert: $targetScript" -Type Info
        }
    }
    else {
        Write-WsusStatus "  WARNUNG: Source-Script nicht gefunden, Task erstellt ohne Kopie" -Type Warning
        $targetScript = $sourceScript  # Task zeigt auf ursprünglichen Pfad
    }

    # Task-Parameter basierend auf Typ
    $scriptAction = switch ($TaskType) {
        'Daily'  { '-OptimizeServer -Quiet' }
        'Weekly' { '-OptimizeDatabase -Quiet' }
    }

    # Trigger erstellen
    $trigger = switch ($TaskType) {
        'Daily' {
            New-ScheduledTaskTrigger -Daily -At $Time
        }
        'Weekly' {
            New-ScheduledTaskTrigger -Weekly -At $Time -DaysOfWeek $DayOfWeek
        }
    }

    # Action erstellen
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$targetScript`" $scriptAction"

    # Settings
    $settings = New-ScheduledTaskSettingsSet `
        -ExecutionTimeLimit (New-TimeSpan -Hours 4) `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 5) `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable

    # Principal (SYSTEM mit höchsten Rechten)
    $principal = New-ScheduledTaskPrincipal `
        -UserId "NT AUTHORITY\SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest

    # Task registrieren
    if ($PSCmdlet.ShouldProcess($taskName, "Task registrieren")) {
        $null = Register-ScheduledTask `
            -TaskName $taskName `
            -Action $action `
            -Trigger $trigger `
            -Settings $settings `
            -Principal $principal `
            -Description "Automatische WSUS-Wartung ($TaskType) - Erstellt von Optimize-WsusServer"

        Write-WsusStatus "" -Type Info
        Write-WsusStatus "Scheduled Task erstellt: $taskName" -Type Success
        Write-WsusStatus "  Nächste Ausführung: Siehe Task Scheduler" -Type Info
    }
}

function Remove-WsusMaintenanceTask {
    <#
    .SYNOPSIS
    Entfernt WSUS Scheduled Maintenance Tasks.

    .PARAMETER TaskType
    Art des zu entfernenden Tasks: Daily, Weekly, oder All.

    .EXAMPLE
    Remove-WsusMaintenanceTask -TaskType All
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Daily', 'Weekly', 'All')]
        [string]$TaskType
    )

    $taskNames = switch ($TaskType) {
        'Daily'  { @('Optimize WSUS Server (Daily)') }
        'Weekly' { @('Optimize WSUS Server (Weekly)') }
        'All'    { @('Optimize WSUS Server (Daily)', 'Optimize WSUS Server (Weekly)') }
    }

    foreach ($taskName in $taskNames) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

        if ($task) {
            if ($PSCmdlet.ShouldProcess($taskName, "Task entfernen")) {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
                Write-WsusStatus "Task entfernt: $taskName" -Type Success
            }
        }
        else {
            Write-WsusStatus "Task nicht gefunden: $taskName" -Type Info
        }
    }
}
