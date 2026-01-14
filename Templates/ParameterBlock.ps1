[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param(
    #region Server Connection
    [Parameter(ParameterSetName = 'Default')]
    [Parameter(ParameterSetName = 'Remote')]
    [Alias('Server')]
    [string]$WsusServer = $env:COMPUTERNAME,

    [Parameter(ParameterSetName = 'Remote')]
    [int]$Port,

    [Parameter(ParameterSetName = 'Remote')]
    [switch]$UseSSL,
    #endregion

    #region Primary Operation Mode
    [Parameter()]
    [switch]$OptimizeServer,

    [Parameter()]
    [switch]$OptimizeDatabase,

    [Parameter()]
    [switch]$DeepClean,

    [Parameter()]
    [switch]$HealthCheck,
    #endregion

    #region Cleanup Options
    [Parameter()]
    [Alias('DeclineSuperseded')]
    [switch]$DeclineSupersededUpdates,

    [Parameter()]
    [switch]$DeclineItanium,

    [Parameter()]
    [switch]$DeclineARM,

    [Parameter()]
    [switch]$DeclinePreview,

    [Parameter()]
    [switch]$DeclineBeta,

    [Parameter()]
    [switch]$DeclineLanguagePacks,

    [Parameter()]
    [switch]$DeclineDrivers,

    [Parameter()]
    [switch]$DeclineExpired,

    [Parameter()]
    [switch]$RemoveObsoleteComputers,

    [Parameter()]
    [switch]$RemoveObsoleteUpdates,

    [Parameter()]
    [switch]$RemoveUnneededContentFiles,

    [Parameter()]
    [switch]$CleanupSynchronizationData,
    #endregion

    #region Configuration Options
    [Parameter()]
    [switch]$ConfigureIIS,

    [Parameter()]
    [switch]$ConfigureMimeTypes,

    [Parameter()]
    [switch]$FixWebConfig,

    [Parameter()]
    [switch]$DisableDriverSync,
    #endregion

    #region Database Options
    [Parameter()]
    [switch]$ReindexDatabase,

    [Parameter()]
    [switch]$CreateCustomIndexes,

    [Parameter()]
    [switch]$UpdateStatistics,

    [Parameter()]
    [ValidateSet('WID', 'SQLExpress', 'SQL', 'Auto')]
    [string]$DatabaseType = 'Auto',

    [Parameter()]
    [string]$SqlInstance,
    #endregion

    #region Scheduled Tasks
    [Parameter()]
    [switch]$CreateScheduledTask,

    [Parameter()]
    [ValidateSet('Daily', 'Weekly')]
    [string]$TaskType = 'Daily',

    [Parameter()]
    [string]$TaskTime,

    [Parameter()]
    [ValidateSet('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')]
    [string]$TaskDay = 'Sunday',

    [Parameter()]
    [string]$ScriptPath = 'C:\Scripts',
    #endregion

    #region Output Options
    [Parameter()]
    [switch]$Quiet,

    [Parameter()]
    [switch]$Verbose,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [switch]$NoLog,
    #endregion

    #region Advanced Options
    [Parameter()]
    [ValidateRange(1, 1000)]
    [int]$BatchSize = 100,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$WhatIf,

    [Parameter()]
    [switch]$ShowProgress,

    [Parameter()]
    [switch]$SkipPrerequisiteCheck,

    [Parameter()]
    [switch]$VMOptimization
    #endregion
)
