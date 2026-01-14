function Get-WsusContentSize {
    <#
    .SYNOPSIS
    Berechnet die Größe des WSUS Content-Verzeichnisses.

    .DESCRIPTION
    Ermittelt Größeninformationen für das WSUS Content-Verzeichnis:
    - Gesamtgröße des Verzeichnisses
    - Freier Speicherplatz auf dem Laufwerk
    - Prozentuale Belegung
    - Low-Space Warnung

    Diese Funktion konsolidiert duplizierten Code aus:
    - Get-WsusHealthStatus
    - Invoke-LowStorageOptimization

    .PARAMETER ContentDir
    Pfad zum WSUS Content-Verzeichnis.
    Wenn nicht angegeben, wird der Pfad aus der Registry gelesen.

    .OUTPUTS
    PSCustomObject mit Größeninformationen, oder $null wenn Verzeichnis nicht existiert.

    .EXAMPLE
    $storage = Get-WsusContentSize
    Write-Host "WSUS Content: $($storage.SizeGB) GB"

    .EXAMPLE
    $storage = Get-WsusContentSize -ContentDir "D:\WSUS"
    if ($storage.IsLowSpace) {
        Write-Warning "Wenig Speicherplatz!"
    }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$ContentDir
    )

    # Content-Verzeichnis aus Registry lesen wenn nicht angegeben
    if (-not $ContentDir) {
        $wsusConfig = Get-WsusSetupConfig
        if (-not $wsusConfig) {
            Write-Verbose "WSUS nicht installiert - kann Content-Größe nicht ermitteln"
            return $null
        }
        $ContentDir = $wsusConfig.ContentDir
    }

    # Prüfen ob Verzeichnis existiert
    if (-not $ContentDir -or -not (Test-Path $ContentDir -ErrorAction SilentlyContinue)) {
        Write-Verbose "Content-Verzeichnis nicht gefunden: $ContentDir"
        return $null
    }

    Write-Verbose "Berechne Größe von: $ContentDir"

    # Größe berechnen (kann bei großen Verzeichnissen dauern)
    try {
        $items = Get-ChildItem -Path $ContentDir -Recurse -File -ErrorAction SilentlyContinue
        $totalSize = ($items | Measure-Object -Property Length -Sum).Sum

        if ($null -eq $totalSize) {
            $totalSize = 0
        }
    }
    catch {
        Write-Warning "Fehler beim Berechnen der Verzeichnisgröße: $_"
        $totalSize = 0
    }

    # Laufwerksinformationen
    try {
        $drive = (Get-Item $ContentDir).PSDrive.Name
        $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='${drive}:'"

        $freeSpace = $disk.FreeSpace
        $totalSpace = $disk.Size
    }
    catch {
        Write-Warning "Fehler beim Lesen der Laufwerksinformationen: $_"
        $freeSpace = 0
        $totalSpace = 0
        $drive = 'Unknown'
    }

    # Berechnungen
    $sizeGB = [math]::Round($totalSize / 1GB, 2)
    $freeGB = [math]::Round($freeSpace / 1GB, 2)
    $totalGB = [math]::Round($totalSpace / 1GB, 2)

    $usedPercent = if ($totalSpace -gt 0) {
        [math]::Round((($totalSpace - $freeSpace) / $totalSpace) * 100, 1)
    } else { 0 }

    # Low Space Threshold: 20 GB oder 10% frei (was kleiner ist)
    $lowSpaceThresholdGB = [math]::Min(20, $totalGB * 0.1)
    $isLowSpace = $freeGB -lt $lowSpaceThresholdGB

    return [PSCustomObject]@{
        # Pfad-Informationen
        Path              = $ContentDir
        DriveLetter       = $drive

        # Content-Größe
        SizeBytes         = $totalSize
        SizeGB            = $sizeGB
        SizeMB            = [math]::Round($totalSize / 1MB, 0)

        # Laufwerks-Informationen
        DriveFreeBytes    = $freeSpace
        DriveFreeGB       = $freeGB
        DriveTotalBytes   = $totalSpace
        DriveTotalGB      = $totalGB
        DriveUsedPercent  = $usedPercent

        # Status
        IsLowSpace        = $isLowSpace
        LowSpaceThreshold = $lowSpaceThresholdGB

        # Formatierte Ausgabe
        Summary           = "Content: $sizeGB GB | Frei: $freeGB GB / $totalGB GB ($usedPercent% belegt)"
    }
}
