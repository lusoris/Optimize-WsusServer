@{
    <#
    .SYNOPSIS
    Listen von Updates die typischerweise nicht mehr benötigt werden.

    .DESCRIPTION
    Diese Listen werden von Invoke-WsusDeepClean verwendet um veraltete
    Updates zu identifizieren und zu entfernen.

    Kategorien:
    - ByProductTitle: Ganze Produktkategorien (z.B. "Windows XP")
    - ByTitle: Spezifische Update-Titel (z.B. "Internet Explorer 6")
    - ByClassification: Update-Klassifikationen (z.B. "Drivers")

    WICHTIG: Diese Listen sollten an die eigene Umgebung angepasst werden!
    Nicht jede Organisation möchte alle diese Updates entfernen.
    #>

    # Updates nach Produkt-Titel
    # Diese Produkte sind End-of-Life und werden typischerweise nicht mehr benötigt
    ByProductTitle = @(
        # Legacy Windows Clients
        'Windows 2000'
        'Windows XP'
        'Windows XP x64 Edition'
        'Windows XP Embedded'
        'Windows Vista'
        'Windows 7'
        'Windows 8'
        'Windows 8 Embedded'
        'Windows 8.1'

        # Legacy Windows Server
        'Windows Server 2003'
        'Windows Server 2003 R2'
        'Windows Server 2008'
        'Windows Server 2008 R2'

        # Legacy Office
        'Office 2002/XP'
        'Office 2003'
        'Office 2007'
        'Office 2010'

        # Legacy SQL Server
        'SQL Server 2000'
        'SQL Server 2005'
        'SQL Server 2008'

        # Andere Legacy-Produkte
        'Virtual PC'
        'Forefront Identity Manager 2010'
        'Microsoft Lync Server 2010'
        'Microsoft Lync Server 2013'
        'Windows Ultimate Extras'
    )

    # Updates nach Update-Titel (Regex-Patterns möglich)
    ByTitle = @(
        # Legacy Internet Explorer
        'Internet Explorer 6'
        'Internet Explorer 7'
        'Internet Explorer 8'
        'Internet Explorer 9'

        # Language Packs (oft nicht benötigt)
        'Language Interface Pack'

        # Consumer Windows Editionen (in Unternehmen selten)
        'Windows 10 (consumer editions)'
        'Windows 10 Education'
        'Windows 10 Enterprise N'
        'Windows 11 (consumer editions)'

        # Spezielle Architekturen
        'Itanium'
        'ARM64'

        # Preview/Beta Updates (optional - für Produktionsumgebungen)
        # 'Preview'
        # 'Beta'
    )

    # Update-Klassifikationen zum Entfernen
    # VORSICHT: Treiber sind oft nützlich, daher separat konfigurierbar
    ByClassification = @(
        # Treiber können separat mit -DisableDrivers deaktiviert werden
        # 'Drivers'
        # 'Driver Sets'
    )

    # Optionale erweiterte Filter
    # Diese werden nur angewendet wenn explizit aktiviert
    Optional = @{
        # Updates älter als X Tage
        OlderThanDays = 365

        # Updates die nie installiert wurden
        NeverInstalled = $false

        # Superseded Updates (wird bereits von WSUS Cleanup behandelt)
        Superseded = $false
    }

    # Ausnahmen - diese Updates werden NICHT entfernt, auch wenn sie in anderen Listen sind
    Exceptions = @(
        # Beispiel: Bestimmte Legacy-Systeme die noch unterstützt werden müssen
        # 'Windows Server 2008 R2'
    )

    # Metadata
    LastUpdated = '2026-01-14'
    Version = '2.0'
    Notes = @'
Diese Listen sind Vorschläge basierend auf typischen Enterprise-Umgebungen.
Passen Sie die Listen an Ihre spezifischen Anforderungen an.

WARNUNG: Entfernen Sie keine Updates für Systeme die noch in Ihrer Umgebung existieren!
'@
}
