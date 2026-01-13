@{
    # Use Severity when you want to limit the generated diagnostic records to a
    # temporary list or a specific set of rules
    Severity = @('Error', 'Warning')

    # Use IncludeRules when you want to run only a subset of the default rule set
    # IncludeRules = @()

    # Use ExcludeRules when you want to run most of the default set of rules except
    # for a few rules you wish to exclude
    ExcludeRules = @(
        # Allow using aliases for brevity in certain cases
        # 'PSAvoidUsingCmdletAliases',

        # Allow Write-Host for user interaction (this is an interactive script)
        'PSAvoidUsingWriteHost',

        # The original script uses unapproved verbs - we'll fix these separately
        'PSUseApprovedVerbs',

        # Allow positional parameters for common cmdlets
        'PSAvoidUsingPositionalParameters',

        # Allow empty catch blocks where intentional
        # 'PSAvoidUsingEmptyCatchBlock'
    )

    # Configure specific rules
    Rules = @{
        # Check compatibility with PowerShell 5.1 (target platform)
        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @('5.1')
        }

        PSUseCompatibleCommands = @{
            Enable = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'  # Windows Server 2019
            )
        }

        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace = @{
            Enable = $true
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore = $false
        }

        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
            CheckParameter = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAlignAssignmentStatement = @{
            Enable = $true
            CheckHashtable = $true
        }

        PSUseCorrectCasing = @{
            Enable = $true
        }
    }
}
