function Get-WsusIISConfig {
    <#
    .SYNOPSIS
    Ruft die aktuelle WSUS IIS-Konfiguration ab.

    .DESCRIPTION
    Liest alle relevanten IIS-Einstellungen für den WSUS Application Pool:
    - Queue Length
    - Load Balancer Capabilities
    - CPU Reset Interval
    - Memory Recycling Settings
    - Idle Timeout
    - Ping/Health Check
    - Client Request Settings

    .OUTPUTS
    PSCustomObject mit allen IIS-Einstellungen

    .EXAMPLE
    Get-WsusIISConfig | Format-List

    .EXAMPLE
    $config = Get-WsusIISConfig
    if ($config.QueueLength -lt 25000) {
        Write-Warning "Queue Length zu niedrig"
    }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    # Pool-Konfiguration abrufen
    $poolInfo = Get-WsusIISPoolConfig
    $wsusPoolConfig = $poolInfo.PoolConfig

    # Queue Length
    $queueLength = Get-IISConfigAttributeValue -ConfigElement $wsusPoolConfig -AttributeName "queueLength"

    # Load Balancer Capabilities
    $failureConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "failure"
    $loadBalancerCapabilities = Get-IISConfigAttributeValue -ConfigElement $failureConfig -AttributeName "loadBalancerCapabilities"

    # CPU Reset Interval
    $cpuConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "cpu"
    $cpuResetInterval = (Get-IISConfigAttributeValue -ConfigElement $cpuConfig -AttributeName "resetInterval").TotalMinutes

    # Recycling Config
    $recyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" |
        Get-IISConfigElement -ChildElementName "periodicRestart"

    $recyclingMemory = Get-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "memory"
    $recyclingPrivateMemory = Get-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "privateMemory"
    $recyclingRegularTimeInterval = (Get-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "time").TotalMinutes

    # Process Model Config
    $processModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
    $idleTimeout = (Get-IISConfigAttributeValue -ConfigElement $processModelConfig -AttributeName "idleTimeout").TotalMinutes
    $pingEnabled = Get-IISConfigAttributeValue -ConfigElement $processModelConfig -AttributeName "pingingEnabled"

    # Client Web Service Config
    $iisPath = Get-WsusIISLocalizedPath
    $clientWebServiceConfig = Get-WebConfiguration -PSPath $iisPath -Filter "system.web/httpRuntime"

    $clientMaxRequestLength = $clientWebServiceConfig | Select-Object -ExpandProperty maxRequestLength
    $clientExecutionTimeout = ($clientWebServiceConfig | Select-Object -ExpandProperty executionTimeout).TotalSeconds

    # Ergebnis zusammenstellen
    return [PSCustomObject]@{
        # Site/Pool Info
        SiteName                     = $poolInfo.SiteName
        PoolName                     = $poolInfo.PoolName

        # Application Pool Settings
        QueueLength                  = $queueLength
        LoadBalancerCapabilities     = $loadBalancerCapabilities
        CpuResetInterval             = $cpuResetInterval

        # Recycling Settings
        RecyclingMemory              = $recyclingMemory
        RecyclingPrivateMemory       = $recyclingPrivateMemory
        RecyclingRegularTimeInterval = $recyclingRegularTimeInterval

        # Process Model Settings
        IdleTimeout                  = $idleTimeout
        PingEnabled                  = $pingEnabled

        # Client Web Service Settings
        ClientMaxRequestLength       = $clientMaxRequestLength
        ClientExecutionTimeout       = $clientExecutionTimeout
    }
}

function Test-WsusIISConfig {
    <#
    .SYNOPSIS
    Vergleicht die aktuelle WSUS IIS-Konfiguration mit empfohlenen Werten.

    .DESCRIPTION
    Prüft alle relevanten IIS-Einstellungen gegen Microsoft Best Practices
    und zeigt Abweichungen an.

    .PARAMETER AutoFix
    Automatisch alle abweichenden Einstellungen korrigieren.

    .EXAMPLE
    Test-WsusIISConfig

    .EXAMPLE
    Test-WsusIISConfig -AutoFix
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$AutoFix
    )

    Write-WsusHeader "WSUS IIS Konfiguration prüfen"

    # Aktuelle und empfohlene Einstellungen
    $current = Get-WsusIISConfig

    # Empfohlene Einstellungen laden
    $recommended = if ($script:IISRecommendedSettings) {
        $script:IISRecommendedSettings
    }
    else {
        @{
            QueueLength                  = 25000
            LoadBalancerCapabilities     = 'TcpLevel'
            CpuResetInterval             = 15
            RecyclingMemory              = 0
            RecyclingPrivateMemory       = 0
            RecyclingRegularTimeInterval = 0
            IdleTimeout                  = 0
            PingEnabled                  = $false
            ClientMaxRequestLength       = 204800
            ClientExecutionTimeout       = 7200
        }
    }

    Write-WsusStatus "Site: $($current.SiteName)" -Type Info
    Write-WsusStatus "Pool: $($current.PoolName)" -Type Info
    Write-WsusStatus "" -Type Info

    $issues = @()

    # Einstellungen vergleichen
    foreach ($key in $recommended.Keys) {
        if ($key -eq 'Descriptions') { continue }

        $currentValue = $current.$key
        $recommendedValue = $recommended[$key]

        $status = if ($currentValue -eq $recommendedValue) { 'OK' } else { 'ABWEICHUNG' }
        $type = if ($status -eq 'OK') { 'Success' } else { 'Warning' }

        Write-WsusStatus "$key" -Type Info
        Write-WsusStatus "  Aktuell:   $currentValue" -Type $type
        Write-WsusStatus "  Empfohlen: $recommendedValue" -Type Info

        if ($status -ne 'OK') {
            $issues += @{
                Setting     = $key
                Current     = $currentValue
                Recommended = $recommendedValue
            }
        }

        Write-WsusStatus "" -Type Info
    }

    # Zusammenfassung
    if ($issues.Count -eq 0) {
        Write-WsusStatus "Alle Einstellungen entsprechen den Empfehlungen" -Type Success
    }
    else {
        Write-WsusStatus "$($issues.Count) Einstellung(en) weichen ab" -Type Warning

        if ($AutoFix) {
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Korrigiere Einstellungen..." -Type Info

            foreach ($issue in $issues) {
                if ($PSCmdlet.ShouldProcess($issue.Setting, "Auf $($issue.Recommended) setzen")) {
                    Set-WsusIISConfig -Setting $issue.Setting -Value $issue.Recommended
                }
            }
        }
        else {
            Write-WsusStatus "Verwenden Sie -AutoFix oder Set-WsusIISConfig zum Korrigieren" -Type Info
        }
    }
}

function Set-WsusIISConfig {
    <#
    .SYNOPSIS
    Setzt eine WSUS IIS-Konfigurationseinstellung.

    .DESCRIPTION
    Ändert eine spezifische IIS-Einstellung für den WSUS Application Pool.

    .PARAMETER Setting
    Name der Einstellung.

    .PARAMETER Value
    Neuer Wert.

    .EXAMPLE
    Set-WsusIISConfig -Setting QueueLength -Value 25000
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'QueueLength', 'LoadBalancerCapabilities', 'CpuResetInterval',
            'RecyclingMemory', 'RecyclingPrivateMemory', 'RecyclingRegularTimeInterval',
            'IdleTimeout', 'PingEnabled', 'ClientMaxRequestLength', 'ClientExecutionTimeout'
        )]
        [string]$Setting,

        [Parameter(Mandatory)]
        $Value
    )

    if (-not $PSCmdlet.ShouldProcess($Setting, "Auf $Value setzen")) {
        return
    }

    # IIS Commit verzögern
    Start-IISCommitDelay

    try {
        $poolInfo = Get-WsusIISPoolConfig
        $wsusPoolConfig = $poolInfo.PoolConfig
        $iisPath = Get-WsusIISLocalizedPath

        switch ($Setting) {
            'QueueLength' {
                Set-IISConfigAttributeValue -ConfigElement $wsusPoolConfig -AttributeName "queueLength" -AttributeValue $Value
            }
            'LoadBalancerCapabilities' {
                $failureConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "failure"
                Set-IISConfigAttributeValue -ConfigElement $failureConfig -AttributeName "loadBalancerCapabilities" -AttributeValue $Value
            }
            'CpuResetInterval' {
                $cpuConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "cpu"
                Set-IISConfigAttributeValue -ConfigElement $cpuConfig -AttributeName "resetInterval" -AttributeValue ([timespan]::FromMinutes($Value))
            }
            'RecyclingMemory' {
                $recyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" |
                    Get-IISConfigElement -ChildElementName "periodicRestart"
                Set-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "memory" -AttributeValue $Value
            }
            'RecyclingPrivateMemory' {
                $recyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" |
                    Get-IISConfigElement -ChildElementName "periodicRestart"
                Set-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "privateMemory" -AttributeValue $Value
            }
            'RecyclingRegularTimeInterval' {
                $recyclingConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "recycling" |
                    Get-IISConfigElement -ChildElementName "periodicRestart"
                Set-IISConfigAttributeValue -ConfigElement $recyclingConfig -AttributeName "time" -AttributeValue ([timespan]::FromMinutes($Value))
            }
            'IdleTimeout' {
                $processModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
                Set-IISConfigAttributeValue -ConfigElement $processModelConfig -AttributeName "idleTimeout" -AttributeValue ([timespan]::FromMinutes($Value))
            }
            'PingEnabled' {
                $processModelConfig = Get-IISConfigElement -ConfigElement $wsusPoolConfig -ChildElementName "processModel"
                Set-IISConfigAttributeValue -ConfigElement $processModelConfig -AttributeName "pingingEnabled" -AttributeValue $Value
            }
            'ClientMaxRequestLength' {
                Unblock-WsusWebConfig
                Set-WebConfigurationProperty -PSPath $iisPath -Filter "system.web/httpRuntime" -Name "maxRequestLength" -Value $Value
            }
            'ClientExecutionTimeout' {
                Unblock-WsusWebConfig
                Set-WebConfigurationProperty -PSPath $iisPath -Filter "system.web/httpRuntime" -Name "executionTimeout" -Value ([timespan]::FromSeconds($Value))
            }
        }

        Write-WsusStatus "$Setting auf $Value gesetzt" -Type Success
    }
    finally {
        Stop-IISCommitDelay
    }
}
