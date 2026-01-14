@{
    <#
    .SYNOPSIS
    Empfohlene IIS-Einstellungen für WSUS-Server.

    .DESCRIPTION
    Diese Einstellungen basieren auf Microsoft Best Practices und Community-Erfahrungen.
    Sie verhindern häufige WSUS/IIS/SQL Abstürze und den "RESET SERVER NODE" Fehler.

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/windows-server-update-services-best-practices

    .LINK
    https://www.reddit.com/r/sysadmin/comments/996xul/getting_2016_updates_to_work_on_wsus/
    #>

    # Application Pool Queue
    # Standard: 1000, Microsoft empfiehlt 2000+
    # Erhöhter Wert verhindert Request-Timeouts bei vielen gleichzeitigen Clients
    QueueLength = 25000

    # Load Balancer Capabilities
    # TcpLevel = Nur TCP Health Checks, keine HTTP
    # Verhindert unnötige Overhead bei WSUS
    LoadBalancerCapabilities = 'TcpLevel'

    # CPU Reset Interval (Minuten)
    # Intervall für CPU-Nutzungs-Reset
    CpuResetInterval = 15

    # Memory Recycling (Bytes)
    # 0 = Deaktiviert (unbegrenzt)
    # Verhindert unerwartete Pool-Neustarts während Updates
    RecyclingMemory = 0

    # Private Memory Recycling (Bytes)
    # Standard: 1843200 (1.8 GB)
    # 0 = Deaktiviert - wichtig für große WSUS-Installationen
    RecyclingPrivateMemory = 0

    # Periodic Recycling (Minuten)
    # Standard: 1740 (29 Stunden)
    # 0 = Deaktiviert - verhindert Recycling während Client-Downloads
    RecyclingRegularTimeInterval = 0

    # Idle Timeout (Minuten)
    # Standard: 20
    # 0 = Deaktiviert - WSUS sollte immer bereit sein
    IdleTimeout = 0

    # Ping/Health Check
    # Deaktiviert - nicht nötig für WSUS
    PingEnabled = $false

    # Client Web Service - Max Request Length (KB)
    # Standard: 4096 (4 MB)
    # Erhöht für große Update-Metadaten
    ClientMaxRequestLength = 204800

    # Client Execution Timeout (Sekunden)
    # Standard: 110
    # Erhöht für langsame Netzwerke und große Downloads
    ClientExecutionTimeout = 7200

    # Beschreibungen für UI/Reporting
    Descriptions = @{
        QueueLength                  = 'Max. Warteschlangenlänge für Requests'
        LoadBalancerCapabilities     = 'Load Balancer Health Check Typ'
        CpuResetInterval             = 'CPU-Nutzung Reset-Intervall (Min)'
        RecyclingMemory              = 'Virtual Memory Limit (0=unbegrenzt)'
        RecyclingPrivateMemory       = 'Private Memory Limit (0=unbegrenzt)'
        RecyclingRegularTimeInterval = 'Periodisches Recycling (0=deaktiviert)'
        IdleTimeout                  = 'Idle Timeout (0=deaktiviert)'
        PingEnabled                  = 'Health Check Ping aktiviert'
        ClientMaxRequestLength       = 'Max. Request-Größe (KB)'
        ClientExecutionTimeout       = 'Request Timeout (Sekunden)'
    }
}
