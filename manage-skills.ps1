param(
    [ValidateSet('check', 'update', 'apply-overrides')]
    [string]$Mode = 'check',

    [string[]]$Only = @(),

    [switch]$IncludeManual,

    # Wall-clock ceiling for a single git invocation. Large repositories such as
    # img2threejs and archify need real headroom, so this is deliberately not a
    # tight bound; it exists to break indefinite hangs, not to police slowness.
    [int]$GitTimeoutSec = 180,

    # npm cold installs are far slower than git transfers, hence the wider bound.
    [int]$NpxTimeoutSec = 600,

    # Ceiling for the working-tree rewrite phase of a pull. Status probes keep
    # the short $GitTimeoutSec above; only an actual pull uses this one. Large
    # repositories (archify: 305 files) routinely need several minutes, and the
    # fetch half of the same command finishes in seconds — killing at 180s lands
    # right in the checkout, which is why the update could never complete.
    [int]$GitPullTimeoutSec = 900,

    # Protected sources: checks read cached observations; updates refresh only when due.
    [ValidateSet('cached', 'due', 'force')]
    [string]$UpstreamWatchMode,
    [string]$UpstreamWatchCacheRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\external\skill-upstream-watch\observations'),
    [ValidateRange(1, 720)][int]$UpstreamWatchFreshHours = 72,
    [ValidateRange(1, 1440)][int]$UpstreamWatchRetryMinutes = 15,
    # Total refresh budget per protected skill, shared by Git and HTTP requests.
    [ValidateRange(1, 300)][int]$UpstreamWatchTimeoutSec = 30,

    # Structured sidecar is opt-in; ordinary cached check leaves persistent state untouched.
    [string]$ResultPath,
    [switch]$FailOnUnhealthy,
    [switch]$SyncClientRouting,
    [string]$ClientInstructionsPath = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex\AGENTS.md'),

    # Reuse the real routing/package functions without running the main loop.
    [switch]$LoadOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $UpstreamWatchMode) { $UpstreamWatchMode = if ($Mode -eq 'update') { 'due' } else { 'cached' } }
# Follow the host code page instead of forcing UTF-8. On Windows PowerShell
# 5.1 running in a cmd window on code page 936, setting UTF-8 here makes every
# CJK character render twice ("人人工工维维护护"), because the console decodes
# UTF-8 bytes as the active ANSI code page. Text files and JSON sidecars are
# still written explicitly as UTF-8 at their call sites, so this only affects
# console rendering.
[Console]::OutputEncoding = [System.Text.Encoding]::Default
$OutputEncoding = [Console]::OutputEncoding

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsRoot = $ScriptRoot
$ConfigPath = Join-Path $ScriptRoot 'skills-sources.json'
$OverridesPath = Join-Path $ScriptRoot 'local-routing-overrides.json'
$RoutingOverrideStart = '<!-- LOCAL ROUTING OVERRIDE START -->'
$RoutingOverrideEnd = '<!-- LOCAL ROUTING OVERRIDE END -->'

if (-not (Test-Path $ConfigPath)) {
    throw "缺少配置文件: $ConfigPath"
}

function Read-JsonFileUtf8 {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    $RawText = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    return ($RawText | ConvertFrom-Json)
}

$Config = Read-JsonFileUtf8 -Path $ConfigPath
$Entries = @($Config.skills)

$RoutingOverrides = @{}
# Script-scoped scratchpad. Apply-RoutingOverrideToText appends a record here
# for every bodyPatch whose `find` text is NOT present in the input. Callers
# (check / update / apply-overrides) reset this before invoking, then read it
# after to surface drift between upstream content and the patches.
$script:CurrentApplyMissingPatches = @()
if (Test-Path $OverridesPath) {
    try {
        $OverridesConfig = Read-JsonFileUtf8 -Path $OverridesPath
        foreach ($Override in @($OverridesConfig.overrides)) {
            if ($null -eq $Override) {
                continue
            }

            $Key = if ($Override.localFolder) { $Override.localFolder } elseif ($Override.skill) { $Override.skill } else { $null }
            if ($null -ne $Key -and $Key -ne '') {
                $RoutingOverrides[$Key.ToLowerInvariant()] = $Override
            }
        }
    }
    catch {
        throw "读取本地路由覆盖配置失败: $OverridesPath`n$($_.Exception.Message)"
    }
}

if ($Only.Count -gt 0) {
    $Wanted = @(
        $Only |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -ne '' } |
            ForEach-Object { $_.ToLowerInvariant() }
    )

    $Entries = @(
        $Entries | Where-Object {
            $Wanted -contains $_.name.ToLowerInvariant() -or
            $Wanted -contains $_.localFolder.ToLowerInvariant() -or
            ($_.PSObject.Properties.Name -contains 'skill' -and $Wanted -contains $_.skill.ToLowerInvariant())
        }
    )

    if ($Entries.Count -eq 0) {
        throw '没有匹配到 -Only 指定的 skill。'
    }
}

function Get-LocalSkillPath {
    param([object]$Entry)
    return (Join-Path $SkillsRoot $Entry.localFolder)
}

function Get-LocalSkillFile {
    param([object]$Entry)
    return (Join-Path (Get-LocalSkillPath -Entry $Entry) 'SKILL.md')
}

function Get-GitRepositoryPath {
    param([object]$Entry)

    if ($Entry.PSObject.Properties.Name -contains 'repositoryFolder' -and -not [string]::IsNullOrWhiteSpace($Entry.repositoryFolder)) {
        $Candidate = Join-Path $SkillsRoot $Entry.repositoryFolder
        return [System.IO.Path]::GetFullPath($Candidate)
    }

    return (Get-LocalSkillPath -Entry $Entry)
}

function Get-SyncSkillSourcePath {
    param([object]$Entry)

    if (-not ($Entry.PSObject.Properties.Name -contains 'syncSkillFile') -or [string]::IsNullOrWhiteSpace($Entry.syncSkillFile)) {
        return $null
    }

    return (Join-Path (Get-GitRepositoryPath -Entry $Entry) $Entry.syncSkillFile)
}

function Get-SyncSkillExtraFileMappings {
    param([object]$Entry)

    $Mappings = New-Object System.Collections.Generic.List[object]
    if (-not ($Entry.PSObject.Properties.Name -contains 'syncSkillFiles') -or $null -eq $Entry.syncSkillFiles) {
        return $Mappings.ToArray()
    }

    foreach ($Configured in @($Entry.syncSkillFiles)) {
        if ($null -eq $Configured) {
            continue
        }

        if ($Configured -is [string]) {
            $Source = $Configured
            $Destination = Split-Path -Leaf ($Configured.TrimEnd('\', '/'))
        }
        else {
            $Source = if ($Configured.PSObject.Properties.Name -contains 'source') { [string]$Configured.source } else { '' }
            $Destination = if ($Configured.PSObject.Properties.Name -contains 'destination') { [string]$Configured.destination } else { Split-Path -Leaf ($Source.TrimEnd('\', '/')) }
        }

        if (-not [string]::IsNullOrWhiteSpace($Source) -and -not [string]::IsNullOrWhiteSpace($Destination)) {
            $null = $Mappings.Add([pscustomobject]@{
                Source      = $Source
                Destination = $Destination
            })
        }
    }

    return $Mappings.ToArray()
}

function Get-SyncSkillExtraFileStatus {
    param([object]$Entry)

    $Mappings = @(Get-SyncSkillExtraFileMappings -Entry $Entry)
    if ($Mappings.Count -eq 0) {
        return 'not-configured'
    }

    $RepositoryRoot = Get-GitRepositoryPath -Entry $Entry
    $LocalRoot = Get-LocalSkillPath -Entry $Entry
    foreach ($Mapping in $Mappings) {
        $SourcePath = Join-Path $RepositoryRoot $Mapping.Source
        $DestinationPath = Join-Path $LocalRoot $Mapping.Destination
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf) -or -not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
            return 'outdated'
        }

        if ($Mapping.Destination.Replace('\', '/') -eq 'agents/openai.yaml' -and $null -ne (Get-CodexSkillPolicy -Entry $Entry)) {
            $Expected = Merge-CodexPolicyYaml -Text (Get-FileText -Path $SourcePath) -Policy (Get-CodexSkillPolicy -Entry $Entry)
            if ((Get-TextHash -Text $Expected) -ne (Get-TextHash -Text (Get-FileText -Path $DestinationPath))) { return 'outdated' }
        }
        elseif ((Get-FileHashValue -Path $SourcePath) -ne (Get-FileHashValue -Path $DestinationPath)) {
            return 'outdated'
        }
    }

    return 'synced'
}

function Sync-LocalSkillExtraFiles {
    param([object]$Entry)

    $Mappings = @(Get-SyncSkillExtraFileMappings -Entry $Entry)
    if ($Mappings.Count -eq 0) {
        return $false
    }

    $RepositoryRoot = Get-GitRepositoryPath -Entry $Entry
    $LocalRoot = Get-LocalSkillPath -Entry $Entry
    $Changed = $false
    foreach ($Mapping in $Mappings) {
        $SourcePath = Join-Path $RepositoryRoot $Mapping.Source
        $DestinationPath = Join-Path $LocalRoot $Mapping.Destination
        if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
            throw "缺少同步源文件: $SourcePath"
        }

        $DestinationParent = Split-Path -Parent $DestinationPath
        if (-not (Test-Path -LiteralPath $DestinationParent)) {
            $null = New-Item -ItemType Directory -Path $DestinationParent -Force
        }

        if ((Get-FileHashValue -Path $SourcePath) -ne (Get-FileHashValue -Path $DestinationPath)) {
            Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
            $Changed = $true
        }
    }

    return $Changed
}

function Get-CanonicalSkillFilePath {
    param([object]$Entry)

    if (-not ($Entry.PSObject.Properties.Name -contains 'skillFile') -or [string]::IsNullOrWhiteSpace($Entry.skillFile)) {
        return $null
    }

    return (Join-Path (Get-LocalSkillPath -Entry $Entry) $Entry.skillFile)
}

function Sync-LocalSkillEntryPoint {
    param([object]$Entry)

    $SourcePath = Get-SyncSkillSourcePath -Entry $Entry
    if ($null -eq $SourcePath) {
        return $false
    }

    $DestinationPath = Get-LocalSkillFile -Entry $Entry
    if (-not (Test-Path -LiteralPath $SourcePath)) {
        throw "缺少同步源文件: $SourcePath"
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    return $true
}

function Get-SyncSkillDirectoryMappings {
    param([object]$Entry)

    $Mappings = New-Object System.Collections.Generic.List[object]

    # syncSkillDirectory keeps the historical behavior: flatten the configured
    # source directory into the active skill root (used for nested skill dirs).
    if ($Entry.PSObject.Properties.Name -contains 'syncSkillDirectory' -and -not [string]::IsNullOrWhiteSpace($Entry.syncSkillDirectory)) {
        $null = $Mappings.Add([pscustomobject]@{
            Source      = $Entry.syncSkillDirectory
            Destination = '.'
        })
    }

    # syncSkillDirectories copies additional repository directories while
    # preserving their configured destination under the active skill root.
    if ($Entry.PSObject.Properties.Name -contains 'syncSkillDirectories' -and $null -ne $Entry.syncSkillDirectories) {
        foreach ($Configured in @($Entry.syncSkillDirectories)) {
            if ($null -eq $Configured) {
                continue
            }

            if ($Configured -is [string]) {
                $Source = $Configured
                $Destination = Split-Path -Leaf ($Configured.TrimEnd('\', '/'))
            }
            else {
                $Source = if ($Configured.PSObject.Properties.Name -contains 'source') { [string]$Configured.source } else { '' }
                $Destination = if ($Configured.PSObject.Properties.Name -contains 'destination') { [string]$Configured.destination } else { Split-Path -Leaf ($Source.TrimEnd('\', '/')) }
            }

            if ([string]::IsNullOrWhiteSpace($Source) -or [string]::IsNullOrWhiteSpace($Destination)) {
                continue
            }

            $null = $Mappings.Add([pscustomobject]@{
                Source      = $Source
                Destination = $Destination
            })
        }
    }

    return $Mappings.ToArray()
}

function Get-SyncSkillDirectoryStatus {
    param([object]$Entry)

    $Mappings = @(Get-SyncSkillDirectoryMappings -Entry $Entry)
    if ($Mappings.Count -eq 0) {
        return 'not-configured'
    }

    $RepositoryRoot = Get-GitRepositoryPath -Entry $Entry
    $LocalRoot = Get-LocalSkillPath -Entry $Entry
    foreach ($Mapping in $Mappings) {
        $SourceRoot = Join-Path $RepositoryRoot $Mapping.Source
        $DestinationRoot = Join-Path $LocalRoot $Mapping.Destination
        if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
            throw "缺少同步源目录: $SourceRoot"
        }

        foreach ($SourceFile in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File)) {
            $Relative = $SourceFile.FullName.Substring($SourceRoot.Length).TrimStart('\')
            $Destination = Join-Path $DestinationRoot $Relative
            if (-not (Test-Path -LiteralPath $Destination)) {
                return 'outdated'
            }

            $Override = if ($Relative -eq 'SKILL.md') { Get-RoutingOverride -Entry $Entry } else { $null }
            if ($null -ne $Override) {
                # The active entry point intentionally contains generated local
                # routing text, so compare it with the same override applied to
                # the upstream source instead of reporting permanent drift.
                $script:CurrentApplyMissingPatches = @()
                $ExpectedText = Apply-RoutingOverrideToText -Text (Get-FileText -Path $SourceFile.FullName) -Override $Override
                if (@($script:CurrentApplyMissingPatches).Count -gt 0) { throw 'patch-stale: sync source no longer matches a local body patch.' }
                $script:CurrentApplyMissingPatches = @()
                $SourceHash = Get-TextHash -Text $ExpectedText
                $DestinationHash = Get-TextHash -Text (Get-FileText -Path $Destination)
            }
            elseif ([IO.Path]::GetFullPath($Destination) -ieq [IO.Path]::GetFullPath((Join-Path $LocalRoot 'agents/openai.yaml')) -and $null -ne (Get-CodexSkillPolicy -Entry $Entry)) {
                $ExpectedYaml = Merge-CodexPolicyYaml -Text (Get-FileText -Path $SourceFile.FullName) -Policy (Get-CodexSkillPolicy -Entry $Entry)
                $SourceHash = Get-TextHash -Text $ExpectedYaml
                $DestinationHash = Get-TextHash -Text (Get-FileText -Path $Destination)
            }
            else {
                $SourceHash = Get-FileHashValue -Path $SourceFile.FullName
                $DestinationHash = Get-FileHashValue -Path $Destination
            }
            if ($SourceHash -ne $DestinationHash) {
                return 'outdated'
            }
        }
    }

    return 'synced'
}

function Sync-LocalSkillDirectory {
    param([object]$Entry)

    $Mappings = @(Get-SyncSkillDirectoryMappings -Entry $Entry)
    if ($Mappings.Count -eq 0) {
        return $false
    }

    $RepositoryRoot = Get-GitRepositoryPath -Entry $Entry
    $LocalRoot = Get-LocalSkillPath -Entry $Entry
    $Changed = $false
    foreach ($Mapping in $Mappings) {
        $SourceRoot = Join-Path $RepositoryRoot $Mapping.Source
        $DestinationRoot = Join-Path $LocalRoot $Mapping.Destination
        if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
            throw "缺少同步源目录: $SourceRoot"
        }

        foreach ($SourceFile in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File)) {
            $Relative = $SourceFile.FullName.Substring($SourceRoot.Length).TrimStart('\')
            $Destination = Join-Path $DestinationRoot $Relative
            $DestinationParent = Split-Path -Parent $Destination
            if (-not (Test-Path -LiteralPath $DestinationParent)) {
                $null = New-Item -ItemType Directory -Path $DestinationParent -Force
            }

            $SourceHash = Get-FileHashValue -Path $SourceFile.FullName
            $DestinationHash = Get-FileHashValue -Path $Destination
            if ($null -eq $DestinationHash -or $SourceHash -ne $DestinationHash) {
                Copy-Item -LiteralPath $SourceFile.FullName -Destination $Destination -Force
                $Changed = $true
            }
        }
    }

    return $Changed
}

function Get-NormalizedText {
    param([string]$Text)
    if ($null -eq $Text) {
        return $null
    }
    return $Text.TrimStart([char]0xFEFF).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Get-FileText {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return $null
    }
    return (Get-NormalizedText -Text ([System.IO.File]::ReadAllText($Path)))
}

function Get-FileHashValue {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    # Hash via .NET instead of Get-FileHash. When PSModulePath is inherited from
    # PowerShell 7, Windows PowerShell 5.1 can fail to resolve the Get-FileHash
    # cmdlet, which turned real 'outdated' sync drift into a bogus 'error' row.
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $Stream = [System.IO.File]::OpenRead($Path)
        try {
            $HashBytes = $Sha.ComputeHash($Stream)
        }
        finally {
            $Stream.Dispose()
        }
        return ([System.BitConverter]::ToString($HashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $Sha.Dispose()
    }
}

function Get-WebText {
    param([string]$Url)
    $Response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 60
    return (Get-NormalizedText -Text $Response.Content)
}

function Get-RoutingOverride {
    param([object]$Entry)

    $Keys = @()
    if ($Entry.PSObject.Properties.Name -contains 'localFolder' -and $Entry.localFolder) {
        $Keys += $Entry.localFolder.ToLowerInvariant()
    }
    if ($Entry.PSObject.Properties.Name -contains 'skill' -and $Entry.skill) {
        $Keys += $Entry.skill.ToLowerInvariant()
    }
    if ($Entry.PSObject.Properties.Name -contains 'name' -and $Entry.name) {
        $Keys += $Entry.name.ToLowerInvariant()
    }

    foreach ($Key in $Keys | Select-Object -Unique) {
        if ($RoutingOverrides.ContainsKey($Key)) {
            return $RoutingOverrides[$Key]
        }
    }

    return $null
}

function Get-FrontMatterMatch {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    return [regex]::Match($Text, '(?ms)^---\s*(.*?)\s*---')
}

function Set-FrontMatterDescription {
    param(
        [string]$FrontMatter,
        [string]$Value
    )

    $Lines = $FrontMatter -split "`n"
    $OutputLines = New-Object System.Collections.Generic.List[string]
    $SingleLineValue = ((Get-NormalizedText -Text $Value) -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }) -join ' '
    $DescriptionLines = @(
        'description: >-',
        ('  ' + $SingleLineValue)
    )
    $Inserted = $false
    $SkippingDescription = $false

    foreach ($Line in $Lines) {
        if ($SkippingDescription) {
            if ($Line -match '^\s' -and $Line -notmatch '^[A-Za-z0-9_-]+:\s*') {
                continue
            }

            $SkippingDescription = $false
        }

        if ($Line -match '^description:\s*') {
            foreach ($DescriptionLine in $DescriptionLines) {
                $OutputLines.Add($DescriptionLine)
            }
            $Inserted = $true
            $SkippingDescription = $true
            continue
        }

        $OutputLines.Add($Line)
    }

    if (-not $Inserted) {
        foreach ($DescriptionLine in $DescriptionLines) {
            $OutputLines.Add($DescriptionLine)
        }
    }

    return (($OutputLines -join "`n").TrimEnd())
}

function Apply-RoutingOverrideToText {
    param(
        [string]$Text,
        [object]$Override
    )

    if ($null -eq $Override -or [string]::IsNullOrWhiteSpace($Text)) {
        return $Text
    }

    if (@($Override.PSObject.Properties.Name | Where-Object { $_ -in @('description', 'usageRule', 'bodyPatches') }).Count -eq 0) { return $Text }

    $TrailingNewlines = [regex]::Match($Text, '(\r?\n*)$').Groups[1].Value
    $Result = $Text
    $FrontMatterMatch = Get-FrontMatterMatch -Text $Result
    if ($null -eq $FrontMatterMatch) {
        return $Result
    }

    $FrontMatterContent = $FrontMatterMatch.Groups[1].Value
    if ($Override.PSObject.Properties.Name -contains 'description' -and -not [string]::IsNullOrWhiteSpace($Override.description)) {
        $FrontMatterContent = Set-FrontMatterDescription -FrontMatter $FrontMatterContent -Value $Override.description
    }

    $Result = $Result.Substring(0, $FrontMatterMatch.Groups[1].Index) + $FrontMatterContent + $Result.Substring($FrontMatterMatch.Groups[1].Index + $FrontMatterMatch.Groups[1].Length)

    if ($Override.PSObject.Properties.Name -contains 'usageRule' -and -not [string]::IsNullOrWhiteSpace($Override.usageRule)) {
        $UsageRuleText = Get-NormalizedText -Text $Override.usageRule
        $ManagedBlock = $RoutingOverrideStart + "`n" + $UsageRuleText + "`n" + $RoutingOverrideEnd
        $ManagedPattern = '(?ms)^<!-- LOCAL ROUTING OVERRIDE START -->\s*.*?^<!-- LOCAL ROUTING OVERRIDE END -->\s*'
        $UsagePattern = '(?ms)^## Usage Rule\s*.*?(?=^## |^# [^#]|\Z)'

        if ([regex]::IsMatch($Result, $ManagedPattern)) {
            $Result = [regex]::Replace($Result, $ManagedPattern, ($ManagedBlock + "`n`n"))
        }
        elseif ([regex]::IsMatch($Result, $UsagePattern)) {
            $Result = [regex]::Replace($Result, $UsagePattern, ($ManagedBlock + "`n`n"))
        }
        else {
            $FrontMatterEnd = [regex]::Match($Result, '(?ms)^---\s*.*?\s*---')
            if ($FrontMatterEnd.Success) {
                $InsertAt = $FrontMatterEnd.Index + $FrontMatterEnd.Length
                $Result = $Result.Substring(0, $InsertAt) + "`n`n" + $ManagedBlock + "`n`n" + $Result.Substring($InsertAt).TrimStart("`r", "`n")
            }
        }
    }

    if ($Override.PSObject.Properties.Name -contains 'bodyPatches' -and $null -ne $Override.bodyPatches) {
        foreach ($Patch in @($Override.bodyPatches)) {
            if ($null -eq $Patch) {
                continue
            }
            if (-not ($Patch.PSObject.Properties.Name -contains 'find')) {
                continue
            }
            if ([string]::IsNullOrWhiteSpace($Patch.find)) {
                continue
            }

            $FindText = Get-NormalizedText -Text $Patch.find
            $ReplaceText = if ($Patch.PSObject.Properties.Name -contains 'replace' -and $null -ne $Patch.replace) {
                Get-NormalizedText -Text $Patch.replace
            }
            else {
                ''
            }

            if ($Result.Contains($FindText)) {
                $Result = $Result.Replace($FindText, $ReplaceText)
            }
            else {
                # bodyPatch.find is not present in the input text.
                # Record this miss so callers (check / update / apply-overrides)
                # can surface drift. Otherwise upstream changes could silently
                # re-introduce the content this patch was meant to remove.
                $PreviewLen = [Math]::Min(80, $FindText.Length)
                $Preview = $FindText.Substring(0, $PreviewLen).Replace("`n", ' \n ')
                $ReasonText = if ($Patch.PSObject.Properties.Name -contains 'reason' -and $Patch.reason) { $Patch.reason } else { '(no reason field)' }
                $script:CurrentApplyMissingPatches += [pscustomobject]@{
                    Reason      = $ReasonText
                    FindPreview = $Preview
                    AlreadyApplied = (-not [string]::IsNullOrEmpty($ReplaceText) -and $Result.Contains($ReplaceText))
                }
            }
        }
    }

    $Result = [regex]::Replace($Result, '(\n){3,}', "`n`n")

    return ($Result.TrimEnd("`r", "`n") + $TrailingNewlines)
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Text
    )

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-TextHash {
    param([string]$Text)

    $Normalized = if ($null -eq $Text) { '' } else { $Text.TrimEnd("`r", "`n") }
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Normalized)
    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $HashBytes = $Sha.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($HashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $Sha.Dispose()
    }
}

function Apply-RoutingOverrideToLocalSkill {
    param([object]$Entry)

    $Override = Get-RoutingOverride -Entry $Entry
    if ($null -eq $Override) {
        return (Apply-CodexSkillPolicy -Entry $Entry)
    }

    $SkillFile = Get-LocalSkillFile -Entry $Entry
    $LocalText = Get-FileText -Path $SkillFile
    if ($null -eq $LocalText) {
        throw "缺少本地文件: $SkillFile"
    }

    $UpdatedText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
    # Validate/apply metadata first so an unsupported YAML does not partially rewrite SKILL.md.
    $Changed = Apply-CodexSkillPolicy -Entry $Entry
    if ($UpdatedText -ne $LocalText) {
        Write-TextFile -Path $SkillFile -Text $UpdatedText
        $Changed = $true
    }
    return $Changed
}

function Invoke-ApplyOverrides {
    param([object[]]$TargetEntries)

    $ApplyResults = @()

    foreach ($Entry in $TargetEntries) {
        $Override = Get-RoutingOverride -Entry $Entry
        if ($null -eq $Override -and $null -eq (Read-CodexPolicyReceipt -Entry $Entry)) {
            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = 'skipped'
                Status    = 'skipped'
                Detail    = '没有本地 override'
            }
            continue
        }

        try {
            $script:CurrentApplyMissingPatches = @()
            $Changed = Apply-RoutingOverrideToLocalSkill -Entry $Entry
            $MissingAfter = @($script:CurrentApplyMissingPatches)
            $script:CurrentApplyMissingPatches = @()

            # In apply-overrides mode, missing patches on LocalText are EXPECTED
            # for the idempotent rerun case: after the first apply, patch.find
            # no longer matches because the local content has already been
            # replaced. So we don't promote missing to an error here; we just
            # append a note. Use `check` mode to detect drift against upstream.
            $Detail = '已应用本地 override'
            if ($MissingAfter.Count -gt 0) {
                $Detail += "; $($MissingAfter.Count) bodyPatch.find 在本地正文未匹配（幂等 rerun 时正常；如果是首次 apply 应改用 update -Only $($Entry.name) 重新从上游拉取）"
            }

            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = if ($Changed) { 'applied' } else { 'unchanged' }
                Status    = 'up-to-date'
                Detail    = $Detail
            }
        }
        catch {
            $ApplyResults += [pscustomobject]@{
                Name      = $Entry.name
                Type      = $Entry.type
                Installed = (Test-Path (Get-LocalSkillPath -Entry $Entry))
                Action    = 'failed'
                Status    = 'error'
                Detail    = $_.Exception.Message
            }
        }
    }

    return $ApplyResults
}

function Get-FrontMatterVersion {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }

    $FrontMatterMatch = [regex]::Match($Text, '(?ms)^---\s*(.*?)\s*---')
    if (-not $FrontMatterMatch.Success) {
        return $null
    }

    $VersionMatch = [regex]::Match($FrontMatterMatch.Groups[1].Value, '(?m)^\s*version:\s*"?([^"\r\n]+)"?')
    if ($VersionMatch.Success) {
        return $VersionMatch.Groups[1].Value.Trim()
    }

    return $null
}

function Stop-ProcessTree {
    param([int]$ProcessId)

    # git and npx both spawn helpers (git-remote-https, node, npm). Process.Kill()
    # on .NET Framework only kills the parent, which would leave the very hung
    # child that caused the stall still holding the network handle. taskkill /T
    # walks the tree; fall back to the direct kill if it is unavailable.
    try {
        $null = & taskkill /T /F /PID $ProcessId 2>&1
    }
    catch {
        try { (Get-Process -Id $ProcessId -ErrorAction Stop).Kill() } catch {}
    }
}

function Clear-StaleGitLock {
    param([string]$RepositoryPath)

    # taskkill /T /F terminates git hard, so it never removes its own
    # .git\index.lock. That stale lock then makes every later git command in the
    # repository fail with "Unable to create ...index.lock: File exists", which
    # looks like a network problem and never heals on its own — a single timeout
    # would silently freeze that skill forever.
    #
    # Only clear it when no git process is alive. A live git will recreate the
    # lock immediately, and deleting it underneath a running process risks a
    # corrupt index.
    $LockPath = Join-Path $RepositoryPath '.git\index.lock'
    if (-not (Test-Path -LiteralPath $LockPath)) { return $false }
    if (@(Get-Process git -ErrorAction SilentlyContinue).Count -gt 0) { return $false }

    try {
        Remove-Item -LiteralPath $LockPath -Force -ErrorAction Stop
        Write-Host "已清理残留的 Git 锁: $LockPath"
        return $true
    }
    catch {
        return $false
    }
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [int]$TimeoutSec,

        # When set, the child inherits this console so long-running output (npx
        # install progress) stays visible instead of disappearing into a file.
        [switch]$StreamOutput,

        [hashtable]$Environment = @{}
    )

    # Start-Process is used rather than [Diagnostics.ProcessStartInfo] because
    # Windows PowerShell 5.1 runs on .NET Framework, where ProcessStartInfo has
    # no ArgumentList property — building the command line by hand would mean
    # re-implementing Windows argument quoting. Captured output goes through
    # uniquely named temp files rather than pipes, which sidesteps the classic
    # deadlock where a full stdout buffer blocks the child while the parent is
    # still waiting on stderr.
    $Token = [System.Guid]::NewGuid().ToString('N')
    $StdOutPath = Join-Path $env:TEMP "manage-skills-$Token.out"
    $StdErrPath = Join-Path $env:TEMP "manage-skills-$Token.err"

    $RestoreEnvironment = @{}
    foreach ($Key in $Environment.Keys) {
        $RestoreEnvironment[$Key] = [Environment]::GetEnvironmentVariable($Key, 'Process')
        [Environment]::SetEnvironmentVariable($Key, $Environment[$Key], 'Process')
    }

    try {
        $StartArguments = @{
            FilePath     = $FilePath
            ArgumentList = $Arguments
            NoNewWindow  = $true
            PassThru     = $true
        }
        if (-not $StreamOutput) {
            $StartArguments['RedirectStandardOutput'] = $StdOutPath
            $StartArguments['RedirectStandardError'] = $StdErrPath
        }

        $Process = Start-Process @StartArguments

        # Reading .Handle forces .NET to cache the process handle. Without this,
        # Start-Process -PassThru hands back an object whose ExitCode is empty
        # after the process ends, so every call would look like a failure.
        # Verified: without the touch ExitCode is ''; with it, 0 and 128 both
        # come through correctly.
        $null = $Process.Handle

        $TimedOut = -not $Process.WaitForExit($TimeoutSec * 1000)
        if ($TimedOut) {
            Stop-ProcessTree -ProcessId $Process.Id
            $null = $Process.WaitForExit(5000)
        }

        $ExitCode = if ($TimedOut) { $null } else { $Process.ExitCode }

        $Segments = @()
        if (-not $StreamOutput) {
            foreach ($Path in @($StdOutPath, $StdErrPath)) {
                if (Test-Path -LiteralPath $Path) {
                    $Text = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
                    if (-not [string]::IsNullOrWhiteSpace($Text)) {
                        $Segments += (Get-NormalizedText -Text $Text).Trim()
                    }
                }
            }
        }

        $CapturedStdOut = if (Test-Path -LiteralPath $StdOutPath) { Get-NormalizedText -Text ([IO.File]::ReadAllText($StdOutPath, [Text.Encoding]::UTF8)) } else { '' }
        $CapturedStdErr = if (Test-Path -LiteralPath $StdErrPath) { Get-NormalizedText -Text ([IO.File]::ReadAllText($StdErrPath, [Text.Encoding]::UTF8)) } else { '' }
        $Output = ($Segments -join "`n").Trim()
        if ($TimedOut) {
            $TimeoutNote = "$FilePath 超过 $TimeoutSec 秒未返回，已终止进程树"
            $Output = if ([string]::IsNullOrWhiteSpace($Output)) { $TimeoutNote } else { "$TimeoutNote`n$Output" }
        }

        return [pscustomobject]@{
            ExitCode = $ExitCode
            Output   = $Output
            StdOut   = $CapturedStdOut
            StdErr   = $CapturedStdErr
            TimedOut = $TimedOut
        }
    }
    finally {
        foreach ($Key in $RestoreEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($Key, $RestoreEnvironment[$Key], 'Process')
        }
        foreach ($Path in @($StdOutPath, $StdErrPath)) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-GitGuardArguments {
    # Prefer letting git abort itself: a stalled transfer then fails with git's
    # own message and a real exit code, which is far more diagnosable than the
    # wall-clock kill in Invoke-ExternalCommand. That kill stays as the backstop
    # for hangs these settings cannot see, such as a wedged DNS or TCP connect.
    return @(
        '-c', 'http.lowSpeedLimit=1000',
        '-c', "http.lowSpeedTime=$GitTimeoutSec"
    )
}

function Get-GitGuardEnvironment {
    # Without these, a missing or expired credential makes git wait forever on a
    # terminal prompt or a GUI askpass dialog that nobody is watching.
    return @{
        GIT_TERMINAL_PROMPT = '0'
        GIT_ASKPASS         = ''
        SSH_ASKPASS         = ''
    }
}

function Invoke-Git {
    param(
        [string]$Path,
        [string[]]$Arguments,

        # Per-call ceiling. 0 means "use $GitTimeoutSec".
        #
        # The two kinds of git call have opposite profiles: a status probe only
        # needs to detect a hang, while a pull that rewrites hundreds of files
        # legitimately takes minutes. archify needs ~6 minutes for 305 files and
        # was being killed at 180s even though the fetch had already succeeded —
        # the timeout landed mid-checkout, so the update never completed.
        [int]$TimeoutSec = 0
    )

    $EffectiveTimeout = if ($TimeoutSec -gt 0) { $TimeoutSec } else { $GitTimeoutSec }

    # git reports progress and summaries ("From https://...", "Switched to
    # branch ...") on stderr even when it succeeds, so success is judged by exit
    # code only. Under the script-wide $ErrorActionPreference = 'Stop', the older
    # `& git ... 2>&1` form turned those lines into a terminating RemoteException,
    # which made -Mode update fail for every git skill that actually had new
    # commits to fetch — silently leaving the active skill directory out of sync.
    #
    # Self-heal a lock left behind by an earlier force-killed run *before*
    # touching git. Without this, a stale lock makes every probe fail and the
    # repository can never recover on its own. One Test-Path when no lock exists.
    $ReadOnly = $Arguments[0] -in @('status', 'rev-parse', 'show', 'ls-tree', 'cat-file', 'diff')
    if (-not $ReadOnly) { $null = Clear-StaleGitLock -RepositoryPath $Path }
    $GitEnvironment = Get-GitGuardEnvironment
    if ($ReadOnly) { $GitEnvironment['GIT_OPTIONAL_LOCKS'] = '0' }

    $Result = Invoke-ExternalCommand `
        -FilePath 'git' `
        -Arguments (@(Get-GitGuardArguments) + @('-C', $Path) + $Arguments) `
        -TimeoutSec $EffectiveTimeout `
        -Environment $GitEnvironment

    # A timed-out git was force-killed and therefore left index.lock behind.
    # Clear it now so the next run (or the next command in this run) is not
    # permanently blocked by "File exists".
    if ($Result.TimedOut -and -not $ReadOnly) {
        $null = Clear-StaleGitLock -RepositoryPath $Path
    }

    return [pscustomobject]@{
        ExitCode = $Result.ExitCode
        Output   = $Result.Output
        StdOut   = $Result.StdOut
        StdErr   = $Result.StdErr
        TimedOut = $Result.TimedOut
    }
}

function Get-GitRemoteHead {
    param(
        [string]$Remote,
        [string]$Branch,
        [int]$TimeoutSec = $GitTimeoutSec
    )

    $Result = Invoke-ExternalCommand `
        -FilePath 'git' `
        -Arguments (@(Get-GitGuardArguments) + @('ls-remote', $Remote, "refs/heads/$Branch")) `
        -TimeoutSec $TimeoutSec `
        -Environment (Get-GitGuardEnvironment)

    if ($Result.TimedOut -or $Result.ExitCode -ne 0) {
        throw $Result.Output
    }

    # Match the SHA line explicitly. The previous implementation took the first
    # output line verbatim, so any leading warning (redirect notice, credential
    # helper chatter) would be parsed as a commit id.
    $Line = @($Result.Output -split "`n" | Where-Object { $_ -match '^[0-9a-f]{40}\s' } | Select-Object -First 1)
    if ($Line.Count -eq 0) {
        throw "No remote ref found for $Branch"
    }

    return (($Line[0].ToString().Trim()) -split "\s+")[0]
}

function Get-SkillLocalStatus {
    param([object]$Entry, [switch]$LocalOnly)

    $FolderPath = Get-LocalSkillPath -Entry $Entry
    $SkillFile = Get-LocalSkillFile -Entry $Entry
    $Installed = Test-Path $FolderPath

    if (-not $Installed) {
        return [pscustomobject]@{
            Name      = $Entry.name
            LocalPath = $FolderPath
            Type      = $Entry.type
            Installed = $false
            Status    = 'missing'
            Detail    = 'not installed locally'
        }
    }

    switch ($Entry.type) {
        'manual' {
            try {
                $LocalText = Get-FileText -Path $SkillFile
                if ($null -eq $LocalText) {
                    throw "缺少本地文件: $SkillFile"
                }

                $Override = Get-RoutingOverride -Entry $Entry
                if ($null -eq $Override) {
                    return [pscustomobject]@{
                        Name      = $Entry.name
                        LocalPath = $FolderPath
                        Type      = $Entry.type
                        Installed = $true
                        Status    = 'skipped'
                        Detail    = $Entry.reason
                    }
                }

                $script:CurrentApplyMissingPatches = @()
                $ExpectedLocalText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
                $MissingHere = @($script:CurrentApplyMissingPatches | Where-Object { -not $_.AlreadyApplied })
                $script:CurrentApplyMissingPatches = @()

                $HashMatches = (Get-TextHash -Text $LocalText) -eq (Get-TextHash -Text $ExpectedLocalText)
                if ($MissingHere.Count -gt 0) {
                    $FirstPreview = $MissingHere[0].FindPreview
                    $Status = 'patch-stale'
                    $Detail = "$($Entry.reason); $($MissingHere.Count) bodyPatch.find 在本地正文未匹配 (e.g. ""$FirstPreview"")；可能本地正文已替换、或 patch.find 需要按上游最新内容重写"
                }
                elseif ($HashMatches) {
                    $Status = 'up-to-date'
                    $Detail = "$($Entry.reason); local override 已同步"
                }
                else {
                    $Status = 'outdated'
                    $Detail = "$($Entry.reason); local override 未同步，请运行 manage-skills.ps1 -Mode apply-overrides -Only $($Entry.name)"
                }

                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = $Status
                    Detail    = $Detail
                }
            }
            catch {
                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = 'error'
                    Detail    = $_.Exception.Message
                }
            }
        }
        'git' {
            try {
                $RepositoryPath = Get-GitRepositoryPath -Entry $Entry
                if (-not (Test-Path -LiteralPath $RepositoryPath -PathType Container)) {
                    throw "缺少 Git 源仓库目录: $RepositoryPath"
                }

                $Head = Invoke-Git -Path $RepositoryPath -Arguments @('rev-parse', 'HEAD')
                if ($Head.ExitCode -ne 0) {
                    throw $Head.Output
                }

                $Branch = if ($Entry.branch) { $Entry.branch } else { 'main' }
                $RemoteHead = if ($LocalOnly) { $Head.Output } else { Get-GitRemoteHead -Remote $Entry.remote -Branch $Branch }
                $Dirty = Invoke-Git -Path $RepositoryPath -Arguments @('status', '--porcelain', '--untracked-files=all')
                $DirtySuffix = if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) { '; local changes present' } else { '' }

                # Git HEAD equality does not prove the generated local routing
                # is current. Check the managed description/Usage Rule as well.
                # Already-applied body patches need not match their old anchors.
                $RoutingOverrideOutdated = $false
                $Override = Get-RoutingOverride -Entry $Entry
                if ($null -ne $Override) {
                    $LocalText = Get-FileText -Path $SkillFile
                    if ($null -eq $LocalText) {
                        throw "缺少本地文件: $SkillFile"
                    }
                    $script:CurrentApplyMissingPatches = @()
                    try {
                        $ExpectedLocalText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
                        $RoutingOverrideOutdated = (Get-TextHash -Text $LocalText) -ne (Get-TextHash -Text $ExpectedLocalText)
                    }
                    finally {
                        $script:CurrentApplyMissingPatches = @()
                    }
                }
                $CanonicalSkillFile = Get-CanonicalSkillFilePath -Entry $Entry
                if ($null -ne $CanonicalSkillFile -and -not (Test-Path -LiteralPath $CanonicalSkillFile)) {
                    throw "缺少 canonical skill 入口文件: $CanonicalSkillFile"
                }
                $SyncSourcePath = Get-SyncSkillSourcePath -Entry $Entry
                $SyncStatus = 'not-configured'
                if ($null -ne $SyncSourcePath) {
                    if (-not (Test-Path -LiteralPath $SyncSourcePath)) {
                        throw "缺少同步源文件: $SyncSourcePath"
                    }

                    $script:CurrentApplyMissingPatches = @()
                    $SourceText = Apply-RoutingOverrideToText -Text (Get-FileText -Path $SyncSourcePath) -Override $Override
                    if (@($script:CurrentApplyMissingPatches).Count -gt 0) { throw 'patch-stale: sync source no longer matches a local body patch.' }
                    $script:CurrentApplyMissingPatches = @()
                    $DestinationText = Get-FileText -Path $SkillFile
                    if ($null -eq $DestinationText) {
                        $SyncStatus = 'missing'
                    }
                    elseif ((Get-TextHash -Text $SourceText) -eq (Get-TextHash -Text $DestinationText)) {
                        $SyncStatus = 'synced'
                    }
                    else {
                        $SyncStatus = 'outdated'
                    }
                }

                $SyncDirectoryStatus = Get-SyncSkillDirectoryStatus -Entry $Entry
                $SyncExtraFileStatus = Get-SyncSkillExtraFileStatus -Entry $Entry
                $ManagedPaths = @(Get-GitSkillManagedPaths -Entry $Entry)
                $ObsoleteCount = 0
                if ($ManagedPaths.Count -gt 0) {
                    $RemovalPlan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths $ManagedPaths
                    Assert-SkillRemovalPlan -Plan $RemovalPlan
                    $ObsoleteCount = @($RemovalPlan.Removed).Count
                }

                $Status = if ($Head.Output -eq $RemoteHead -and $SyncStatus -in @('not-configured', 'synced') -and $SyncDirectoryStatus -in @('not-configured', 'synced') -and $SyncExtraFileStatus -in @('not-configured', 'synced') -and -not $RoutingOverrideOutdated -and $ObsoleteCount -eq 0) { 'up-to-date' } else { 'outdated' }
                $SyncSuffix = if ($SyncStatus -eq 'outdated') { '; local SKILL.md entry out of sync' } elseif ($SyncStatus -eq 'missing') { '; local SKILL.md entry missing' } elseif ($SyncDirectoryStatus -eq 'outdated') { '; local skill directory out of sync' } elseif ($SyncExtraFileStatus -eq 'outdated') { '; local extra skill file out of sync' } else { '' }
                if ($ObsoleteCount -gt 0) { $SyncSuffix += "; obsolete managed files: $ObsoleteCount" }
                if ($RoutingOverrideOutdated) {
                    $SyncSuffix += "; local override 未同步，请运行 manage-skills.ps1 -Mode apply-overrides -Only $($Entry.name)"
                }

                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = $Status
                    Detail    = ("local {0}; remote {1}{2}{3}" -f $Head.Output.Substring(0, 7), $RemoteHead.Substring(0, 7), $DirtySuffix, $SyncSuffix)
                }
            }
            catch {
                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = 'error'
                    Detail    = $_.Exception.Message
                }
            }
        }
        'skills-cli' {
            try {
                $LocalText = Get-FileText -Path $SkillFile
                if ($null -eq $LocalText) {
                    throw "缺少本地文件: $SkillFile"
                }

                $Package = Get-SkillCliSourceSnapshot -Entry $Entry
                $RemoteText = $Package.EntryText
                $Override = Get-RoutingOverride -Entry $Entry

                $script:CurrentApplyMissingPatches = @()
                $ExpectedLocalText = Apply-RoutingOverrideToText -Text $RemoteText -Override $Override
                # missing-on-remote: patch.find no longer matches upstream content.
                # This is the dangerous case — without patches applying, upstream
                # drift can silently re-introduce the content the patch removes.
                $MissingFromRemote = @($script:CurrentApplyMissingPatches)

                $script:CurrentApplyMissingPatches = @()
                $ExpectedOverrideLocalText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
                $script:CurrentApplyMissingPatches = @()

                $LocalVersion = Get-FrontMatterVersion -Text $LocalText
                $RemoteVersion = Get-FrontMatterVersion -Text $RemoteText
                $HashMatches = (Get-TextHash -Text $LocalText) -eq (Get-TextHash -Text $ExpectedLocalText)
                $OverrideInSync = if ($null -eq $Override) {
                    $true
                }
                else {
                    (Get-TextHash -Text $LocalText) -eq (Get-TextHash -Text $ExpectedOverrideLocalText)
                }

                $LocalVersionText = if ($null -ne $LocalVersion -and $LocalVersion -ne '') { $LocalVersion } else { 'n/a' }
                $RemoteVersionText = if ($null -ne $RemoteVersion -and $RemoteVersion -ne '') { $RemoteVersion } else { 'n/a' }

                $VersionDetail = if ($LocalVersion -or $RemoteVersion) {
                    "local $LocalVersionText; remote $RemoteVersionText"
                }
                else {
                    '未声明版本号'
                }

                if (-not $OverrideInSync) {
                    $VersionDetail += '; local override 未同步'
                }

                if ($MissingFromRemote.Count -gt 0) {
                    $FirstPreview = $MissingFromRemote[0].FindPreview
                    $VersionDetail += "; $($MissingFromRemote.Count) bodyPatch.find 在上游正文未匹配 (e.g. ""$FirstPreview"")；上游可能已改变，patch.find 需要重写"
                    $Status = 'patch-stale'
                }
                else {
                    $PackageStatus = Get-SkillCliPackageStatus -Entry $Entry -Snapshot $Package
                    $Status = if ($HashMatches -and $PackageStatus.InSync) { 'up-to-date' } else { 'outdated' }
                    $VersionDetail += "; package $($Package.Commit.Substring(0, 7)), $($Package.Files.Count) files"
                    if (-not $PackageStatus.InSync) {
                        $VersionDetail += "; missing=$($PackageStatus.Missing.Count), changed=$($PackageStatus.Different.Count), obsolete=$(@($PackageStatus.RemovalPlan.Removed).Count)"
                        $Examples = @($PackageStatus.Missing) + @($PackageStatus.Different) + @($PackageStatus.RemovalPlan.Removed | ForEach-Object { $_.Relative })
                        $VersionDetail += '; ' + (($Examples | Select-Object -First 3) -join ', ')
                    }
                }

                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = $Status
                    Detail    = $VersionDetail
                }
            }
            catch {
                return [pscustomobject]@{
                    Name      = $Entry.name
                    LocalPath = $FolderPath
                    Type      = $Entry.type
                    Installed = $true
                    Status    = 'error'
                    Detail    = $_.Exception.Message
                }
            }
        }
        default {
            return [pscustomobject]@{
                Name      = $Entry.name
                LocalPath = $FolderPath
                Type      = $Entry.type
                Installed = $true
                Status    = 'unknown'
                Detail    = "不支持的类型: $($Entry.type)"
            }
        }
    }
}

function New-SkillUpdateBackup {
    param([object]$Entry)

    # No mutation is allowed unless a complete readable snapshot exists.
    # Keep Git metadata in its repository; record HEAD alongside copied files.
    $FolderPath = Get-LocalSkillPath -Entry $Entry
    $RootFull = [IO.Path]::GetFullPath($SkillsRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $FolderFull = [IO.Path]::GetFullPath($FolderPath)
    if (-not $FolderFull.StartsWith($RootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "备份目标不在活动 skills 目录内: $FolderFull"
    }
    if ($Entry.localFolder -match '[/\\]' -or $Entry.localFolder -in @('.', '..')) {
        throw '备份仅支持已登记的单层 skill 目录名'
    }
    $BackupRoot = Join-Path (Split-Path -Parent $SkillsRoot) 'external\skill-update-backups'
    $BackupDir = Join-Path (Join-Path $BackupRoot $Entry.localFolder) ((Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

    function Copy-SnapshotTree {
        param([string]$Source, [string]$Destination)
        $Item = Get-Item -LiteralPath $Source -Force
        if ($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "备份遇到链接，停止更新以免越界复制: $Source"
        }
        if ($Item.PSIsContainer) {
            New-Item -ItemType Directory -Path $Destination -Force | Out-Null
            foreach ($Child in Get-ChildItem -LiteralPath $Source -Force) {
                if ($Child.Name -eq '.git') { continue }
                Copy-SnapshotTree -Source $Child.FullName -Destination (Join-Path $Destination $Child.Name)
            }
        }
        else {
            Copy-Item -LiteralPath $Source -Destination $Destination -Force
            if ((Get-FileHashValue -Path $Source) -ne
                (Get-FileHashValue -Path $Destination)) {
                throw "备份校验失败: $Source"
            }
        }
    }

    $Head = $null
    if ($Entry.type -eq 'git') {
        $GitHead = Invoke-Git -Path (Get-GitRepositoryPath -Entry $Entry) -Arguments @('rev-parse', 'HEAD')
        if ($GitHead.ExitCode -ne 0) { throw $GitHead.Output }
        $Head = $GitHead.Output.Trim()
    }
    Copy-SnapshotTree -Source $FolderFull -Destination (Join-Path $BackupDir 'files')
    [ordered]@{
        createdAt = (Get-Date).ToString('o')
        originalPath = $FolderFull
        entry = $Entry
        routingOverride = (Get-RoutingOverride -Entry $Entry)
        gitHead = $Head
        excludes = @('.git')
        note = 'Pre-update files only. Restore after reviewing later changes; Git history and client links are not automatically reset.'
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $BackupDir 'metadata.json') -Encoding UTF8
    Write-Host "更新前备份: $BackupDir"
    return $BackupDir
}

function Update-Skill {
    param([object]$Entry)

    $Current = Get-SkillStatus -Entry $Entry
    if ($Current.Status -in @('missing', 'error', 'patch-stale')) {
        $Current | Add-Member -NotePropertyName Action -NotePropertyValue 'skipped' -Force
        return $Current
    }

    if ($Entry.type -eq 'manual' -or -not $Entry.autoUpdate) {
        # IncludeManual cannot bypass an explicit protected-source policy.
        $Current | Add-Member -NotePropertyName Action -NotePropertyValue 'skipped' -Force
        $Current.Detail = '自动覆盖保持关闭；' + $Current.Detail
        return $Current
    }

    if ($Current.Status -eq 'up-to-date') {
        try { Save-SkillManagedManifest -Entry $Entry }
        catch {
            return [pscustomobject]@{ Name = $Entry.name; Type = $Entry.type; Action = 'failed'; Status = 'error'; Detail = $_.Exception.Message }
        }
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'unchanged'
            Status    = 'up-to-date'
            Detail    = $Current.Detail
        }
    }

    Write-Host "正在更新 $($Entry.name)..."
    $UpdateBackup = ''
    $CliMutationStarted = $false
    $CliOriginalState = @{}

    try {
        switch ($Entry.type) {
            'git' {
                $RepositoryPath = Get-GitRepositoryPath -Entry $Entry
                $GeneratedPolicyChange = Get-GeneratedPolicyGitChanges -Entry $Entry
                $UpdateBackup = New-SkillUpdateBackup -Entry $Entry
                Suspend-GeneratedPolicyForPull -Entry $Entry -HasGeneratedChange $GeneratedPolicyChange
                try {
                $Branch = if ($Entry.branch) { $Entry.branch } else { 'main' }
                $Pull = Invoke-Git -Path $RepositoryPath -Arguments @('pull', '--ff-only', 'origin', $Branch) -TimeoutSec $GitPullTimeoutSec
                if ($Pull.ExitCode -ne 0) {
                    throw $Pull.Output
                }

                $ManagedPaths = @(Get-GitSkillManagedPaths -Entry $Entry)
                $RemovalPlan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths $ManagedPaths
                Assert-SkillRemovalPlan -Plan $RemovalPlan
                $null = Sync-LocalSkillDirectory -Entry $Entry
                $null = Sync-LocalSkillEntryPoint -Entry $Entry
                $null = Sync-LocalSkillExtraFiles -Entry $Entry
                Remove-StaleManagedSkillFiles -Entry $Entry -Plan $RemovalPlan
                $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
                }
                finally {
                    # Restore the policy even if pull fails; merge against the surviving HEAD.
                    if ($GeneratedPolicyChange) { $null = Apply-CodexSkillPolicy -Entry $Entry }
                }
            }
            'skills-cli' {
                # Routed through cmd.exe because npx is a .cmd/.ps1 shim on
                # Windows: Start-Process -NoNewWindow implies UseShellExecute
                # false, and CreateProcess cannot launch a bare `npx`
                # (verified: "%1 is not a valid Win32 application"). Output is
                # streamed rather than captured so a slow npm install still
                # shows progress.
                if (Test-Path -LiteralPath (Join-Path (Get-LocalSkillPath -Entry $Entry) '.git')) { throw 'skills-cli 目标含 Git 元数据，请使用 Git 管理流程。' }
                $UpdateBackup = New-SkillUpdateBackup -Entry $Entry
                foreach ($StatePath in @((Get-SkillManifestPath -Entry $Entry), (Get-CodexPolicyReceiptPath -Entry $Entry))) {
                    $CliOriginalState[$StatePath] = if (Test-Path -LiteralPath $StatePath) { [IO.File]::ReadAllBytes($StatePath) } else { $null }
                }
                $CliMutationStarted = $true
                $Install = Invoke-ExternalCommand `
                    -FilePath 'cmd.exe' `
                    -Arguments @('/c', 'npx', '-y', 'skills', 'add', "$($Entry.repo)@$($Entry.skill)", '-g', '-y') `
                    -TimeoutSec $NpxTimeoutSec `
                    -StreamOutput

                if ($Install.TimedOut) {
                    throw "skills add 超过 $NpxTimeoutSec 秒未返回，已终止进程树"
                }
                if ($Install.ExitCode -ne 0) {
                    throw 'skills add 命令执行失败'
                }

                $RemovalPlan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths @((Get-SkillCliExpectedFiles -Entry $Entry -Snapshot (Get-SkillCliSourceSnapshot -Entry $Entry)).Keys)
                Remove-StaleManagedSkillFiles -Entry $Entry -Plan $RemovalPlan
                $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
            }
            default {
                throw "不支持的更新类型: $($Entry.type)"
            }
        }

        $After = Get-SkillStatus -Entry $Entry
        if ($Entry.type -eq 'skills-cli' -and $After.Status -ne 'up-to-date') {
            throw ("安装后校验失败 [$($After.Status)]: " + $After.Detail)
        }
        $Action = if ($After.Status -eq 'up-to-date') { 'updated' } else { 'failed' }
        if ($After.Status -eq 'up-to-date') { Save-SkillManagedManifest -Entry $Entry }

        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = $Action
            Status    = $After.Status
            Detail    = ($After.Detail + $(if ($UpdateBackup) { "; backup: $UpdateBackup" } else { '' }))
        }
    }
    catch {
        $Failure = $_.Exception.Message
        if ($CliMutationStarted -and $UpdateBackup) {
            try {
                Restore-SkillUpdateBackup -Entry $Entry -BackupDirectory $UpdateBackup
                foreach ($StatePath in $CliOriginalState.Keys) {
                    if ($null -ne $CliOriginalState[$StatePath]) {
                        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $StatePath) -Force
                        [IO.File]::WriteAllBytes($StatePath, [byte[]]$CliOriginalState[$StatePath])
                    }
                    elseif (Test-Path -LiteralPath $StatePath) { Remove-Item -LiteralPath $StatePath -Force }
                }
                $Failure += '; 已恢复更新前文件和客户端策略'
            }
            catch { $Failure += '; 自动恢复未完成: ' + $_.Exception.Message }
        }
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'failed'
            Status    = 'error'
            Detail    = ($Failure + $(if ($UpdateBackup) { "; pre-update backup: $UpdateBackup" } else { '' }))
        }
    }
}

. (Join-Path $ScriptRoot 'skill-package-state.ps1')
. (Join-Path $ScriptRoot 'skill-client-policy.ps1')
. (Join-Path $ScriptRoot 'skill-upstream-watch.ps1')
if ($LoadOnly) { return }

try {
Write-Host "Skill 管理模式: $Mode"
Write-Host "配置文件: $ConfigPath"
Write-Host "人工维护项上游观察: $UpstreamWatchMode (缓存有效 ${UpstreamWatchFreshHours}h，失败退避 ${UpstreamWatchRetryMinutes}min)"

if ($Only.Count -gt 0) {
    Write-Host ('仅处理: ' + ($Only -join ', '))
}

$Results = @()

if ($Mode -eq 'check') {
    foreach ($Entry in $Entries) {
        $Status = Get-SkillStatus -Entry $Entry
        $Status | Add-Member -NotePropertyName Action -NotePropertyValue 'checked' -Force
        $Results += $Status
    }
}
elseif ($Mode -eq 'apply-overrides') {
    $Results = @(Invoke-ApplyOverrides -TargetEntries $Entries)
}
else {
    foreach ($Entry in $Entries) {
        $Results += (Update-Skill -Entry $Entry)
    }
}

if ($SyncClientRouting) {
    if ($Mode -ne 'apply-overrides') { throw '-SyncClientRouting requires -Mode apply-overrides.' }
    $ClientChanged = Sync-CodexRoutingInstructions -Path $ClientInstructionsPath
    Write-Host ('Codex 全局路由: ' + $(if ($ClientChanged) { 'applied' } else { 'unchanged' }))
}
$SortedResults = @($Results | Sort-Object Name)
if ($ResultPath) {
    $Sidecar = [ordered]@{ schemaVersion = 1; mode = $Mode; upstreamWatchMode = $UpstreamWatchMode; checkedAt = (Get-Date).ToString('o'); results = $SortedResults }
    Write-TextFile -Path $ResultPath -Text ($Sidecar | ConvertTo-Json -Depth 15)
}

""
Write-Host '结果:'
$SortedResults | Format-Table Name, Type, Installed, Action, Status, Detail -AutoSize

""
foreach ($Result in $SortedResults) {
    if ($Result.Status -eq 'error') {
        Write-Host ('SKILL_ERROR_DETAIL: ' + ($Result.Detail | ConvertTo-Json -Compress))
    }
}
Write-Host '汇总:'
$SortedResults |
    Group-Object Status |
    Sort-Object Name |
    ForEach-Object { "- $($_.Name): $($_.Count)" } |
    ForEach-Object { Write-Host $_ }

$WatchRows = @($SortedResults | Where-Object { $_.PSObject.Properties.Name -contains 'Upstream' -and $_.Upstream })
if ($WatchRows.Count -gt 0) {
    Write-Host '人工维护项上游观察（独立于安装/同步结果）:'
    foreach ($Row in $WatchRows) {
        $Watch = $Row.Upstream
        Write-Host ("  {0}: {1}; source={2}; freshness={3}; checkedAt={4}" -f $Row.Name, $Watch.status, $Watch.source, $Watch.freshness, $Watch.checkedAt)
        if ($Watch.warning) { Write-Host ('  UPSTREAM_OBSERVATION_WARNING: ' + $Row.Name + ': ' + $Watch.warning) }
    }
}
}
finally { Close-SkillPackageSession }
if ($FailOnUnhealthy -and @($Results | Where-Object { $_.Status -notin @('up-to-date', 'skipped', 'unchanged', 'applied', 'updated') }).Count -gt 0) { exit 1 }
