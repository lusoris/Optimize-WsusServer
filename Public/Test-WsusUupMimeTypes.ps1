function Test-WsusUupMimeTypes {
    <#
    .SYNOPSIS
    Prüft ob die für Windows 11 erforderlichen UUP MIME Types konfiguriert sind.

    .DESCRIPTION
    Windows 11 22H2+ verwendet UUP (Unified Update Platform) Updates die
    spezielle MIME Types in IIS erfordern:
    - .msu -> application/octet-stream
    - .wim -> application/x-ms-wim

    Ohne diese MIME Types können Windows 11 Clients keine Updates herunterladen.

    .OUTPUTS
    Boolean: $true wenn alle MIME Types konfiguriert sind

    .EXAMPLE
    if (-not (Test-WsusUupMimeTypes)) {
        Add-WsusUupMimeTypes
    }

    .LINK
    https://learn.microsoft.com/en-us/windows-server/administration/windows-server-update-services/plan/plan-your-wsus-deployment
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $requiredMimeTypes = @{
        '.msu' = 'application/octet-stream'
        '.wim' = 'application/x-ms-wim'
    }

    $allPresent = $true

    try {
        Import-Module WebAdministration -ErrorAction SilentlyContinue

        foreach ($ext in $requiredMimeTypes.Keys) {
            $existing = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                -Filter "system.webServer/staticContent/mimeMap[@fileExtension='$ext']" `
                -Name "mimeType" -ErrorAction SilentlyContinue

            if (-not $existing) {
                Write-Verbose "MIME Type fehlt: $ext"
                $allPresent = $false
            }
            else {
                Write-Verbose "MIME Type OK: $ext ($existing)"
            }
        }
    }
    catch {
        Write-Warning "MIME Type Prüfung fehlgeschlagen: $_"
        return $false
    }

    return $allPresent
}

function Add-WsusUupMimeTypes {
    <#
    .SYNOPSIS
    Fügt die für Windows 11 erforderlichen UUP MIME Types hinzu.

    .DESCRIPTION
    Konfiguriert die fehlenden MIME Types in IIS:
    - .msu -> application/octet-stream
    - .wim -> application/x-ms-wim

    .PARAMETER Force
    Überschreibt existierende MIME Type Einträge.

    .EXAMPLE
    Add-WsusUupMimeTypes

    .EXAMPLE
    Add-WsusUupMimeTypes -Force -Verbose
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )

    $requiredMimeTypes = @{
        '.msu' = 'application/octet-stream'
        '.wim' = 'application/x-ms-wim'
    }

    Import-Module WebAdministration -ErrorAction Stop

    foreach ($ext in $requiredMimeTypes.Keys) {
        $mimeType = $requiredMimeTypes[$ext]

        # Prüfen ob bereits vorhanden
        $existing = Get-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
            -Filter "system.webServer/staticContent/mimeMap[@fileExtension='$ext']" `
            -Name "mimeType" -ErrorAction SilentlyContinue

        if ($existing -and -not $Force) {
            Write-WsusStatus "MIME Type bereits vorhanden: $ext ($existing)" -Type Info
            continue
        }

        if ($PSCmdlet.ShouldProcess($ext, "MIME Type hinzufügen ($mimeType)")) {
            try {
                # Falls vorhanden, erst entfernen
                if ($existing) {
                    Remove-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                        -Filter "system.webServer/staticContent" `
                        -Name "." `
                        -AtElement @{fileExtension = $ext}
                }

                # Hinzufügen
                Add-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' `
                    -Filter "system.webServer/staticContent" `
                    -Name "." `
                    -Value @{fileExtension = $ext; mimeType = $mimeType}

                Write-WsusStatus "MIME Type hinzugefügt: $ext -> $mimeType" -Type Success
            }
            catch {
                Write-WsusStatus "Fehler beim Hinzufügen von $ext : $_" -Type Error
            }
        }
    }

    Write-WsusStatus "" -Type Info
    Write-WsusStatus "IIS Neustart empfohlen: iisreset /restart" -Type Info
}
