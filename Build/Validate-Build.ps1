<#
.SYNOPSIS
Validiert das generierte monolithische Script mit PSScriptAnalyzer.

.DESCRIPTION
Nach dem Build wird das generierte Script auf Code-Qualität geprüft.
Dies stellt sicher, dass das monolithische Script keine Syntaxfehler
oder Stilprobleme hat.

.PARAMETER ScriptPath
Pfad zum zu validierenden Script.
Standard: dist\Optimize-WsusServer.ps1

.PARAMETER SettingsPath
Pfad zu PSScriptAnalyzer-Einstellungen.
Standard: PSScriptAnalyzerSettings.psd1

.PARAMETER FailOnError
Beende mit Fehlercode wenn Fehler gefunden werden.

.PARAMETER FailOnWarning
Beende mit Fehlercode wenn Warnungen gefunden werden.

.EXAMPLE
.\Validate-Build.ps1
Validiert dist\Optimize-WsusServer.ps1

.EXAMPLE
.\Validate-Build.ps1 -FailOnWarning
Stoppt wenn Warnungen gefunden werden

.NOTES
Erfordert PSScriptAnalyzer-Modul:
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ScriptPath,

    [Parameter()]
    [string]$SettingsPath,

    [Parameter()]
    [switch]$FailOnError,

    [Parameter()]
    [switch]$FailOnWarning
)

$ErrorActionPreference = 'Stop'

# Pfade ermitteln
$BuildRoot = $PSScriptRoot
$ModuleRoot = Split-Path $BuildRoot -Parent

if (-not $ScriptPath) {
    $ScriptPath = Join-Path $ModuleRoot 'dist\Optimize-WsusServer.ps1'
}

if (-not $SettingsPath) {
    $SettingsPath = Join-Path $ModuleRoot 'PSScriptAnalyzerSettings.psd1'
}

Write-Host "PSScriptAnalyzer Validierung" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "Script: $ScriptPath" -ForegroundColor Gray
Write-Host "Settings: $SettingsPath" -ForegroundColor Gray
Write-Host ""

# Überprüfe ob Script existiert
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script nicht gefunden: $ScriptPath"
    exit 1
}

# Überprüfe PSScriptAnalyzer-Installation
if (-not (Get-Module -Name PSScriptAnalyzer -ListAvailable)) {
    Write-Warning "PSScriptAnalyzer nicht installiert. Installiere..."
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop
}

# Lade PSScriptAnalyzer
Import-Module PSScriptAnalyzer -Force

# Führe Analyse durch
Write-Host "Analysiere Script..." -ForegroundColor Yellow
$results = Invoke-ScriptAnalyzer -Path $ScriptPath -Settings $SettingsPath

if ($results.Count -eq 0) {
    Write-Host "✅ Keine Probleme gefunden!" -ForegroundColor Green
    exit 0
}

# Gruppiere Ergebnisse nach Severity
$errors = @($results | Where-Object { $_.Severity -eq 'Error' })
$warnings = @($results | Where-Object { $_.Severity -eq 'Warning' })
$information = @($results | Where-Object { $_.Severity -eq 'Information' })

# Zeige Ergebnisse
if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "❌ Fehler ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object {
        Write-Host "  Line $($_.Line): $($_.Message)" -ForegroundColor Red
        Write-Host "    Rule: $($_.RuleName)" -ForegroundColor DarkRed
    }
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Warnungen ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object {
        Write-Host "  Line $($_.Line): $($_.Message)" -ForegroundColor Yellow
        Write-Host "    Rule: $($_.RuleName)" -ForegroundColor DarkYellow
    }
}

if ($information.Count -gt 0) {
    Write-Host ""
    Write-Host "ℹ️  Information ($($information.Count)):" -ForegroundColor Cyan
    $information | ForEach-Object {
        Write-Host "  Line $($_.Line): $($_.Message)" -ForegroundColor Cyan
    }
}

# Bestimme Exit-Code
$exitCode = 0

if ($errors.Count -gt 0 -and $FailOnError) {
    Write-Host ""
    Write-Host "❌ Fehler gefunden. Build fehlgeschlagen." -ForegroundColor Red
    $exitCode = 1
}

if ($warnings.Count -gt 0 -and $FailOnWarning) {
    Write-Host ""
    Write-Host "⚠️  Warnungen gefunden. Build fehlgeschlagen." -ForegroundColor Red
    $exitCode = 1
}

# Zusammenfassung
Write-Host ""
Write-Host "Zusammenfassung:" -ForegroundColor Cyan
Write-Host "  Fehler:      $($errors.Count)"
Write-Host "  Warnungen:   $($warnings.Count)"
Write-Host "  Information: $($information.Count)"
Write-Host ""

exit $exitCode
