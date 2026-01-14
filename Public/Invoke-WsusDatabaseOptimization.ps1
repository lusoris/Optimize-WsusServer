function Invoke-WsusDatabaseOptimization {
    <#
    .SYNOPSIS
    Führt die WSUS-Datenbankoptimierung durch.

    .DESCRIPTION
    Führt Microsoft-empfohlene Datenbankwartung aus:
    1. Erstellt benutzerdefinierte Indizes (einmalig, beschleunigt zukünftige Cleanups)
    2. Führt Defragmentierung und Neuindizierung durch
    3. Aktualisiert Statistiken

    HINWEIS: Die erste Ausführung kann sehr lange dauern (30+ Minuten bei großen DBs).
    Nachfolgende Ausführungen sind deutlich schneller.

    .PARAMETER SkipIndexCreation
    Überspringt die Erstellung benutzerdefinierter Indizes.

    .PARAMETER Timeout
    SQL Query Timeout in Sekunden. Standard: 40000 (ca. 11 Stunden)

    .EXAMPLE
    Invoke-WsusDatabaseOptimization

    .EXAMPLE
    Invoke-WsusDatabaseOptimization -Timeout 7200
    # Mit 2 Stunden Timeout

    .LINK
    https://learn.microsoft.com/en-us/troubleshoot/mem/configmgr/update-management/wsus-maintenance-guide
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$SkipIndexCreation,

        [Parameter()]
        [int]$Timeout = 40000
    )

    Write-WsusHeader "WSUS Datenbank-Optimierung"

    # SQL-Queries
    $createIndexesQuery = @"
USE [SUSDB]
IF 0 = (SELECT COUNT(*) as index_count
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('[dbo].[tbLocalizedPropertyForRevision]')
    AND name='nclLocalizedPropertyID')
BEGIN
    CREATE NONCLUSTERED INDEX [nclLocalizedPropertyID] ON [dbo].[tbLocalizedPropertyForRevision]
    (
         [LocalizedPropertyID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
END
ELSE
BEGIN
    PRINT '[nclLocalizedPropertyID] already exists'
END ;
GO
IF 0 = (SELECT COUNT(*) as index_count
    FROM sys.indexes
    WHERE object_id = OBJECT_ID('[dbo].[tbRevisionSupersedesUpdate]')
    AND name='nclSupercededUpdateID')
BEGIN
    CREATE NONCLUSTERED INDEX [nclSupercededUpdateID] ON [dbo].[tbRevisionSupersedesUpdate]
    (
         [SupersededUpdateID] ASC
    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
END
ELSE
BEGIN
    PRINT '[nclSupercededUpdateID] already exists'
END ;
GO
"@

    $maintenanceQuery = @"
USE SUSDB;
GO
SET NOCOUNT ON;

DECLARE @work_to_do TABLE (
    objectid int, indexid int, pagedensity float, fragmentation float, numrows int
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

PRINT 'Estimating fragmentation: Begin. ' + convert(nvarchar, getdate(), 121)
INSERT @work_to_do
SELECT
    f.object_id, index_id, avg_page_space_used_in_percent, avg_fragmentation_in_percent, record_count
FROM
    sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f
WHERE
    (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1)
    or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0)
    or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0)

PRINT 'Number of indexes to rebuild: ' + cast(@@ROWCOUNT as nvarchar(20))
PRINT 'Estimating fragmentation: End. ' + convert(nvarchar, getdate(), 121)

SELECT @numpages = sum(ps.used_page_count)
FROM @work_to_do AS fi
    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id

DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do
OPEN curIndexes

WHILE (1=1)
BEGIN
    FETCH NEXT FROM curIndexes INTO @objectid, @indexid, @density, @fragmentation, @numrows;
    IF @@FETCH_STATUS < 0 BREAK;

    SELECT @objectname = QUOTENAME(o.name), @schemaname = QUOTENAME(s.name)
    FROM sys.objects AS o INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id
    WHERE o.object_id = @objectid;

    SELECT @indexname = QUOTENAME(name), @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END
    FROM sys.indexes WHERE object_id = @objectid AND index_id = @indexid;

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

CLOSE curIndexes;
DEALLOCATE curIndexes;

IF EXISTS (SELECT * FROM @work_to_do)
BEGIN
    PRINT 'Estimated number of pages in fragmented indexes: ' + cast(@numpages as nvarchar(20))
    SELECT @numpages = @numpages - sum(ps.used_page_count)
    FROM @work_to_do AS fi
        INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
        INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id
    PRINT 'Estimated number of pages freed: ' + cast(@numpages as nvarchar(20))
END
GO

PRINT 'Updating all statistics.' + convert(nvarchar, getdate(), 121)
EXEC sp_updatestats
PRINT 'Done updating statistics.' + convert(nvarchar, getdate(), 121)
GO
"@

    # SQL Instance ermitteln
    $serverInstance = Get-WsusSqlInstance
    $dbType = Get-WsusDatabaseType

    Write-WsusStatus "Datenbank: $dbType" -Type Info
    Write-WsusStatus "Instance: $serverInstance" -Type Info
    Write-WsusStatus "" -Type Info

    #region Index-Erstellung
    if (-not $SkipIndexCreation) {
        Write-WsusStatus "Phase 1: Benutzerdefinierte Indizes erstellen..." -Type Info
        Write-WsusStatus "  (Beschleunigt zukünftige Optimierungen)" -Type Info

        if ($PSCmdlet.ShouldProcess("SUSDB", "Benutzerdefinierte Indizes erstellen")) {
            try {
                Invoke-WsusSqlQuery -Query $createIndexesQuery -Timeout 120
                Write-WsusStatus "  Indizes erstellt/verifiziert" -Type Success
            }
            catch {
                Write-WsusStatus "  Index-Erstellung fehlgeschlagen: $_" -Type Warning
                Write-WsusStatus "  Fahre mit Wartung fort..." -Type Info
            }
        }
    }
    #endregion

    #region Datenbank-Wartung
    Write-WsusStatus "" -Type Info
    Write-WsusStatus "Phase 2: Datenbank-Wartung..." -Type Info
    Write-WsusStatus "  HINWEIS: Dies kann bei der ersten Ausführung sehr lange dauern!" -Type Warning
    Write-WsusStatus "  Timeout: $([math]::Round($Timeout / 60)) Minuten" -Type Info

    if ($PSCmdlet.ShouldProcess("SUSDB", "Defragmentierung und Statistik-Update")) {
        try {
            $startTime = Get-Date

            Invoke-WsusSqlQuery -Query $maintenanceQuery -Timeout $Timeout

            $duration = (Get-Date) - $startTime
            Write-WsusStatus "" -Type Info
            Write-WsusStatus "Datenbank-Wartung abgeschlossen" -Type Success
            Write-WsusStatus "  Dauer: $([math]::Round($duration.TotalMinutes, 1)) Minuten" -Type Info
        }
        catch {
            Write-WsusStatus "Datenbank-Wartung fehlgeschlagen: $_" -Type Error
            throw
        }
    }
    #endregion

    Write-WsusStatus "" -Type Info
    Write-WsusHeader "Optimierung abgeschlossen"
}
