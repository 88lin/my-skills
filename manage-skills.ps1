param(
    [ValidateSet('check', 'update', 'apply-overrides')]
    [string]$Mode = 'check',

    [string[]]$Only = @(),

    [switch]$IncludeManual
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
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

            $SourceHash = Get-FileHashValue -Path $SourceFile.FullName
            $DestinationHash = Get-FileHashValue -Path $Destination
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
        return $false
    }

    $SkillFile = Get-LocalSkillFile -Entry $Entry
    $LocalText = Get-FileText -Path $SkillFile
    if ($null -eq $LocalText) {
        throw "缺少本地文件: $SkillFile"
    }

    $UpdatedText = Apply-RoutingOverrideToText -Text $LocalText -Override $Override
    if ($UpdatedText -ne $LocalText) {
        Write-TextFile -Path $SkillFile -Text $UpdatedText
        return $true
    }

    return $false
}

function Invoke-ApplyOverrides {
    param([object[]]$TargetEntries)

    $ApplyResults = @()

    foreach ($Entry in $TargetEntries) {
        $Override = Get-RoutingOverride -Entry $Entry
        if ($null -eq $Override) {
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

function Invoke-Git {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    # git reports progress and summaries ("From https://...", "Switched to
    # branch ...") on stderr even when it succeeds. Under the script-wide
    # $ErrorActionPreference = 'Stop', the `2>&1` redirect turns those lines into
    # a terminating RemoteException, so `-Mode update` used to fail for every git
    # skill that actually had new commits to fetch — silently leaving the active
    # skill directory out of sync. Judge success by exit code instead.
    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $Output = & git -C $Path @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = (($Output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
}

function Get-GitRemoteHead {
    param(
        [string]$Remote,
        [string]$Branch
    )

    # Same stderr-under-Stop hazard as Invoke-Git: ls-remote can emit warnings
    # (redirect notices, credential helper chatter) while still succeeding.
    $PreviousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $Output = & git ls-remote $Remote "refs/heads/$Branch" 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousPreference
    }

    if ($ExitCode -ne 0) {
        throw (($Output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }

    $Line = @($Output | Where-Object { $_ -match '^[0-9a-f]{40}\s' } | Select-Object -First 1)
    if ($Line.Count -eq 0) {
        throw "No remote ref found for $Branch"
    }

    return (($Line[0].ToString().Trim()) -split "\s+")[0]
}

function Get-SkillStatus {
    param([object]$Entry)

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
                $MissingHere = @($script:CurrentApplyMissingPatches)
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
                $RemoteHead = Get-GitRemoteHead -Remote $Entry.remote -Branch $Branch
                $Dirty = Invoke-Git -Path $RepositoryPath -Arguments @('status', '--porcelain')
                $DirtySuffix = if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) { '; local changes present' } else { '' }
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

                    $SourceText = Get-FileText -Path $SyncSourcePath
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

                $Status = if ($Head.Output -eq $RemoteHead -and $SyncStatus -in @('not-configured', 'synced') -and $SyncDirectoryStatus -in @('not-configured', 'synced')) { 'up-to-date' } else { 'outdated' }
                $SyncSuffix = if ($SyncStatus -eq 'outdated') { '; local SKILL.md entry out of sync' } elseif ($SyncStatus -eq 'missing') { '; local SKILL.md entry missing' } elseif ($SyncDirectoryStatus -eq 'outdated') { '; local skill directory out of sync' } else { '' }

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

                $RemoteText = Get-WebText -Url $Entry.rawSkillUrl
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
                    $Status = if ($HashMatches) { 'up-to-date' } else { 'outdated' }
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

function Update-Skill {
    param([object]$Entry)

    $Current = Get-SkillStatus -Entry $Entry
    if ($Current.Status -in @('missing', 'error')) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = $Current.Status
            Detail    = $Current.Detail
        }
    }

    if ($Entry.type -eq 'manual' -and -not $IncludeManual) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = 'skipped'
            Detail    = $Entry.reason
        }
    }

    if (-not $Entry.autoUpdate -and -not $IncludeManual) {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'skipped'
            Status    = 'skipped'
            Detail    = '已禁用自动更新'
        }
    }

    if ($Current.Status -eq 'up-to-date') {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'unchanged'
            Status    = 'up-to-date'
            Detail    = $Current.Detail
        }
    }

    Write-Host "正在更新 $($Entry.name)..."

    try {
        switch ($Entry.type) {
            'git' {
                $RepositoryPath = Get-GitRepositoryPath -Entry $Entry
                $Dirty = Invoke-Git -Path $RepositoryPath -Arguments @('status', '--porcelain')
                if (-not [string]::IsNullOrWhiteSpace($Dirty.Output)) {
                    throw '检测到本地 Git 改动，已跳过更新'
                }

                $Branch = if ($Entry.branch) { $Entry.branch } else { 'main' }
                $Pull = Invoke-Git -Path $RepositoryPath -Arguments @('pull', '--ff-only', 'origin', $Branch)
                if ($Pull.ExitCode -ne 0) {
                    throw $Pull.Output
                }

                $null = Sync-LocalSkillDirectory -Entry $Entry
                $null = Sync-LocalSkillEntryPoint -Entry $Entry
            }
            'skills-cli' {
                & npx -y skills add "$($Entry.repo)@$($Entry.skill)" -g -y
                if ($LASTEXITCODE -ne 0) {
                    throw 'skills add 命令执行失败'
                }

                $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
            }
            default {
                throw "不支持的更新类型: $($Entry.type)"
            }
        }

        $After = Get-SkillStatus -Entry $Entry
        $Action = if ($After.Status -eq 'up-to-date') { 'updated' } else { 'failed' }

        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = $Action
            Status    = $After.Status
            Detail    = $After.Detail
        }
    }
    catch {
        return [pscustomobject]@{
            Name      = $Entry.name
            Type      = $Entry.type
            Action    = 'failed'
            Status    = 'error'
            Detail    = $_.Exception.Message
        }
    }
}

Write-Host "Skill 管理模式: $Mode"
Write-Host "配置文件: $ConfigPath"

if ($Only.Count -gt 0) {
    Write-Host ('仅处理: ' + ($Only -join ', '))
}

$Results = @()

if ($Mode -eq 'check') {
    foreach ($Entry in $Entries) {
        $Status = Get-SkillStatus -Entry $Entry
        $Results += [pscustomobject]@{
            Name      = $Status.Name
            Type      = $Status.Type
            Installed = $Status.Installed
            Action    = 'checked'
            Status    = $Status.Status
            Detail    = $Status.Detail
        }
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

$SortedResults = $Results | Sort-Object Name

""
Write-Host '结果:'
$SortedResults | Format-Table Name, Type, Installed, Action, Status, Detail -AutoSize

""
Write-Host '汇总:'
$SortedResults |
    Group-Object Status |
    Sort-Object Name |
    ForEach-Object { "- $($_.Name): $($_.Count)" } |
    ForEach-Object { Write-Host $_ }
