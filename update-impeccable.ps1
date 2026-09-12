param(
    [ValidateSet('preview', 'apply')]
    [string]$Mode = 'preview',

    [string]$SourcePath = '',

    [string]$RepoUrl = 'https://github.com/pbakaus/impeccable.git',

    [string]$Branch = 'main',

    [string]$CacheDir = (Join-Path (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\external') 'impeccable-upstream'),

    [switch]$LoadOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [Console]::OutputEncoding

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$SkillName = 'impeccable'
$SourceSubdir = '.agents/skills/impeccable'
$LocalSkillDir = Join-Path $ScriptRoot $SkillName
$LocalPatchConfigPath = Join-Path $ScriptRoot 'impeccable-local-patches.json'
$LocalRoutingOverridesPath = Join-Path $ScriptRoot 'local-routing-overrides.json'
$LockPath = Join-Path $ScriptRoot 'skills-upstream-lock.json'
$ManageSkillsPath = Join-Path $ScriptRoot 'manage-skills.ps1'
$RoutingOverrideStart = '<!-- LOCAL ROUTING OVERRIDE START -->'
$RoutingOverrideEnd = '<!-- LOCAL ROUTING OVERRIDE END -->'

function Get-FullPath {
    param([string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-PathInside {
    param(
        [string]$ChildPath,
        [string]$ParentPath,
        [string]$Purpose
    )

    $ParentFull = (Get-FullPath -Path $ParentPath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $ChildFull = Get-FullPath -Path $ChildPath

    if (-not $ChildFull.StartsWith($ParentFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Purpose path escapes expected parent: $ChildFull"
    }
}

function Read-TextFileUtf8 {
    param([string]$Path)

    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-TextFileUtf8NoBom {
    param(
        [string]$Path,
        [string]$Text
    )

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-NormalizedText {
    param([string]$Text)

    if ($null -eq $Text) {
        return $null
    }

    return $Text.TrimStart([char]0xFEFF).Replace("`r`n", "`n").Replace("`r", "`n")
}

function Read-JsonFileUtf8 {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return (Read-TextFileUtf8 -Path $Path | ConvertFrom-Json)
}

function Invoke-NativeCaptured {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $Output = & $FilePath @Arguments 2>&1
        $ExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = (($Output | ForEach-Object { $_.ToString() }) -join "`n").Trim()
    }
}

function Invoke-GitChecked {
    param(
        [string[]]$Arguments,
        [string]$WorkingDirectory = $ScriptRoot
    )

    $Result = Invoke-NativeCaptured -FilePath 'git' -Arguments $Arguments

    if ($Result.ExitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed in $WorkingDirectory`n$($Result.Output)"
    }

    return $Result.Output
}

function Get-GitCommit {
    param([string]$Path)

    try {
        $Result = Invoke-NativeCaptured -FilePath 'git' -Arguments @('-C', $Path, 'rev-parse', 'HEAD')
        if ($Result.ExitCode -eq 0 -and $Result.Output) {
            return (($Result.Output -split "`n" | Select-Object -First 1).ToString().Trim())
        }
    }
    catch {
        return $null
    }

    return $null
}

function Test-ImpeccableSourceDir {
    param([string]$Path)

    return (
        (Test-Path -LiteralPath (Join-Path $Path 'SKILL.md')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'reference')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'scripts')) -and
        (Test-Path -LiteralPath (Join-Path $Path 'agents'))
    )
}

function Find-ImpeccableSkillDir {
    param(
        [string]$Root,
        [string]$PreferredSubdir = ''
    )

    # Upstream occasionally moves the skill inside its repository. Probing for a
    # relocated copy lives here rather than in a caller so that every entry
    # point benefits: previously only auto-update-skills.ps1 carried this logic,
    # which left the desktop .bat — the manual path — failing outright on a
    # layout change that the unattended path handled fine.
    if (-not [string]::IsNullOrWhiteSpace($PreferredSubdir)) {
        $Primary = Join-Path $Root ($PreferredSubdir -replace '/', '\')
        if (Test-ImpeccableSourceDir -Path $Primary) {
            return [pscustomobject]@{ Path = (Get-FullPath -Path $Primary); Relocated = $false }
        }
    }

    if (Test-ImpeccableSourceDir -Path $Root) {
        return [pscustomobject]@{ Path = (Get-FullPath -Path $Root); Relocated = $false }
    }

    # Shortest path first, so a top-level relocation wins over a nested copy
    # such as a vendored example or test fixture.
    $Candidates = @(
        Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'impeccable' -and $_.FullName -notmatch '\\\.git\\' } |
            Sort-Object { $_.FullName.Length }
    )

    foreach ($Candidate in $Candidates) {
        if (Test-ImpeccableSourceDir -Path $Candidate.FullName) {
            return [pscustomobject]@{ Path = (Get-FullPath -Path $Candidate.FullName); Relocated = $true }
        }
    }

    return $null
}

function Resolve-ImpeccableSource {
    param(
        [string]$SourcePath = '',
        [string]$RepoUrl = 'https://github.com/pbakaus/impeccable.git',
        [string]$Branch = 'main',
        [string]$CacheDir = (Join-Path (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\external') 'impeccable-upstream')
    )

    if (-not [string]::IsNullOrWhiteSpace($SourcePath)) {
        if (-not (Test-Path -LiteralPath $SourcePath)) {
            throw "SourcePath does not exist: $SourcePath"
        }

        $Resolved = Get-FullPath -Path (Resolve-Path -LiteralPath $SourcePath).Path
        $Found = Find-ImpeccableSkillDir -Root $Resolved -PreferredSubdir $SourceSubdir
        if ($null -eq $Found) {
            throw "SourcePath must be either the impeccable skill directory or a repo root containing $SourceSubdir"
        }

        if ($Found.Relocated) {
            Write-Host "Upstream layout changed; using detected skill directory: $($Found.Path)"
        }

        return [pscustomobject]@{
            Root       = $Resolved
            SkillDir   = $Found.Path
            Commit     = Get-GitCommit -Path $Resolved
            SourceKind = 'source-path'
            SourcePath = $Resolved
            Relocated  = $Found.Relocated
        }
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'git is required when SourcePath is not provided.'
    }

    $CacheFull = Get-FullPath -Path $CacheDir
    if (-not (Test-Path -LiteralPath $CacheFull)) {
        $Parent = Split-Path -Parent $CacheFull
        if (-not (Test-Path -LiteralPath $Parent)) {
            New-Item -ItemType Directory -Path $Parent -Force | Out-Null
        }

        Invoke-GitChecked -Arguments @('clone', '--branch', $Branch, '--single-branch', $RepoUrl, $CacheFull) | Out-Null
    }
    else {
        if (-not (Test-Path -LiteralPath (Join-Path $CacheFull '.git'))) {
            throw "CacheDir exists but is not a git repository: $CacheFull"
        }

        $DirtyResult = Invoke-NativeCaptured -FilePath 'git' -Arguments @('-C', $CacheFull, 'status', '--porcelain')
        if ($DirtyResult.ExitCode -ne 0) {
            throw "Unable to inspect git cache: $($DirtyResult.Output)"
        }
        if (-not [string]::IsNullOrWhiteSpace($DirtyResult.Output)) {
            throw "Git cache has local changes; clean it before updating: $CacheFull"
        }

        Invoke-GitChecked -Arguments @('-C', $CacheFull, 'fetch', 'origin', $Branch) | Out-Null
        Invoke-GitChecked -Arguments @('-C', $CacheFull, 'checkout', $Branch) | Out-Null
        Invoke-GitChecked -Arguments @('-C', $CacheFull, 'pull', '--ff-only', 'origin', $Branch) | Out-Null
    }

    $Found = Find-ImpeccableSkillDir -Root $CacheFull -PreferredSubdir $SourceSubdir
    if ($null -eq $Found) {
        throw "Git source does not contain expected skill directory: $SourceSubdir"
    }

    if ($Found.Relocated) {
        Write-Host "Upstream layout changed; using detected skill directory: $($Found.Path)"
    }

    return [pscustomobject]@{
        Root       = $CacheFull
        SkillDir   = $Found.Path
        Commit     = Get-GitCommit -Path $CacheFull
        SourceKind = 'git-cache'
        SourcePath = $CacheFull
        Relocated  = $Found.Relocated
    }
}

function Get-ImpeccableCommands {
    param([string]$SkillFile)

    if (-not (Test-Path -LiteralPath $SkillFile)) {
        throw "Missing SKILL.md: $SkillFile"
    }

    $Text = Get-NormalizedText -Text (Read-TextFileUtf8 -Path $SkillFile)
    $Commands = [ordered]@{}

    foreach ($Line in ($Text -split "`n")) {
        if ($Line -match '^\|\s*`([^`]+)`\s*\|') {
            $CommandSpec = $Matches[1].Trim()
            $Command = ($CommandSpec -split '\s+')[0]
            if (-not [string]::IsNullOrWhiteSpace($Command)) {
                $Commands[$Command] = $true
            }
        }
    }

    return @($Commands.Keys)
}

function Test-ImpeccableBundle {
    param([string]$SkillDir)

    $RequiredPaths = @('SKILL.md', 'reference', 'scripts', 'agents')
    $MissingRequired = @(
        foreach ($RelativePath in $RequiredPaths) {
            $Path = Join-Path $SkillDir $RelativePath
            if (-not (Test-Path -LiteralPath $Path)) {
                $RelativePath
            }
        }
    )

    $SkillFile = Join-Path $SkillDir 'SKILL.md'
    $Commands = if (Test-Path -LiteralPath $SkillFile) {
        @(Get-ImpeccableCommands -SkillFile $SkillFile)
    }
    else {
        @()
    }

    $MissingReferences = @(
        foreach ($Command in $Commands) {
            $ReferencePath = Join-Path $SkillDir ("reference\$Command.md")
            if (-not (Test-Path -LiteralPath $ReferencePath)) {
                "reference/$Command.md"
            }
        }
    )

    $HasExpectedName = $false
    if (Test-Path -LiteralPath $SkillFile) {
        $SkillText = Get-NormalizedText -Text (Read-TextFileUtf8 -Path $SkillFile)
        $HasExpectedName = [regex]::IsMatch($SkillText, '(?m)^name:\s*impeccable\s*$')
    }

    return [pscustomobject]@{
        Valid                = ($MissingRequired.Count -eq 0 -and $MissingReferences.Count -eq 0 -and $Commands.Count -gt 0 -and $HasExpectedName)
        Commands             = @($Commands)
        MissingReferences    = @($MissingReferences)
        MissingRequiredPaths = @($MissingRequired)
        HasExpectedName      = $HasExpectedName
    }
}

function Apply-ImpeccableLocalPatches {
    param(
        [string]$SkillDir,
        [string]$PatchConfigPath = $LocalPatchConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($PatchConfigPath) -or -not (Test-Path -LiteralPath $PatchConfigPath)) {
        return [pscustomobject]@{
            Applied      = $false
            AppliedCount = 0
            Missing      = @()
            Skipped      = $true
        }
    }

    $Config = Read-JsonFileUtf8 -Path $PatchConfigPath
    $Patches = if ($Config -and $Config.PSObject.Properties.Name -contains 'patches') { @($Config.patches) } else { @() }
    $AppliedCount = 0
    $Missing = @()
    $SkillRootFull = (Get-FullPath -Path $SkillDir).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar

    foreach ($Patch in $Patches) {
        if ($null -eq $Patch -or -not ($Patch.PSObject.Properties.Name -contains 'path') -or -not ($Patch.PSObject.Properties.Name -contains 'find')) {
            continue
        }

        $RelativePath = $Patch.path
        $FindText = Get-NormalizedText -Text $Patch.find
        $ReplaceText = if ($Patch.PSObject.Properties.Name -contains 'replace' -and $null -ne $Patch.replace) {
            Get-NormalizedText -Text $Patch.replace
        }
        else {
            ''
        }
        $UseRegex = ($Patch.PSObject.Properties.Name -contains 'regex' -and $Patch.regex -eq $true)
        $Reason = if ($Patch.PSObject.Properties.Name -contains 'reason' -and $Patch.reason) { $Patch.reason } else { '(no reason field)' }

        if ([string]::IsNullOrWhiteSpace($RelativePath) -or [string]::IsNullOrWhiteSpace($FindText)) {
            continue
        }

        $TargetPath = Get-FullPath -Path (Join-Path $SkillDir $RelativePath)
        if (-not $TargetPath.StartsWith($SkillRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Patch path escapes skill directory: $RelativePath"
        }

        if (-not (Test-Path -LiteralPath $TargetPath)) {
            $Missing += [pscustomobject]@{
                Path        = $RelativePath
                Reason      = $Reason
                FindPreview = '[target file missing]'
            }
            continue
        }

        $Text = Get-NormalizedText -Text (Read-TextFileUtf8 -Path $TargetPath)
        $Matched = if ($UseRegex) { [regex]::IsMatch($Text, $FindText) } else { $Text.Contains($FindText) }
        if ($Matched) {
            $Updated = if ($UseRegex) {
                [regex]::Replace($Text, $FindText, $ReplaceText)
            }
            else {
                $Text.Replace($FindText, $ReplaceText)
            }
            Write-TextFileUtf8NoBom -Path $TargetPath -Text $Updated
            $AppliedCount += 1
        }
        else {
            $PreviewLen = [Math]::Min(80, $FindText.Length)
            $Missing += [pscustomobject]@{
                Path        = $RelativePath
                Reason      = $Reason
                FindPreview = $FindText.Substring(0, $PreviewLen).Replace("`n", ' \n ')
            }
        }
    }

    return [pscustomobject]@{
        Applied      = ($AppliedCount -gt 0)
        AppliedCount = $AppliedCount
        Missing      = @($Missing)
        Skipped      = $false
    }
}

function Set-ImpeccableFrontMatterDescription {
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

function Get-ImpeccableRoutingOverride {
    param([string]$OverridesPath = $LocalRoutingOverridesPath)

    if (-not (Test-Path -LiteralPath $OverridesPath)) {
        return $null
    }

    $Config = Read-JsonFileUtf8 -Path $OverridesPath
    foreach ($Override in @($Config.overrides)) {
        if ($null -eq $Override) {
            continue
        }

        $Keys = @()
        if ($Override.PSObject.Properties.Name -contains 'skill' -and $Override.skill) {
            $Keys += $Override.skill.ToString().ToLowerInvariant()
        }
        if ($Override.PSObject.Properties.Name -contains 'localFolder' -and $Override.localFolder) {
            $Keys += $Override.localFolder.ToString().ToLowerInvariant()
        }

        if ($Keys -contains $SkillName) {
            return $Override
        }
    }

    return $null
}

function Apply-ImpeccableRoutingOverride {
    param(
        [string]$SkillDir,
        [string]$OverridesPath = $LocalRoutingOverridesPath
    )

    $Override = Get-ImpeccableRoutingOverride -OverridesPath $OverridesPath
    if ($null -eq $Override) {
        return [pscustomobject]@{
            Applied      = $false
            HasOverride  = $false
            Missing      = @()
        }
    }

    $SkillFile = Join-Path $SkillDir 'SKILL.md'
    if (-not (Test-Path -LiteralPath $SkillFile)) {
        throw "Missing SKILL.md: $SkillFile"
    }

    $Original = Get-NormalizedText -Text (Read-TextFileUtf8 -Path $SkillFile)
    $Result = $Original
    $Missing = @()

    $FrontMatterMatch = [regex]::Match($Result, '(?ms)^---\s*(.*?)\s*---')
    if ($FrontMatterMatch.Success -and $Override.PSObject.Properties.Name -contains 'description' -and -not [string]::IsNullOrWhiteSpace($Override.description)) {
        $FrontMatterContent = $FrontMatterMatch.Groups[1].Value
        $FrontMatterContent = Set-ImpeccableFrontMatterDescription -FrontMatter $FrontMatterContent -Value $Override.description
        $Result = $Result.Substring(0, $FrontMatterMatch.Groups[1].Index) + $FrontMatterContent + $Result.Substring($FrontMatterMatch.Groups[1].Index + $FrontMatterMatch.Groups[1].Length)
    }

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
        elseif ($FrontMatterMatch.Success) {
            $FreshFrontMatterMatch = [regex]::Match($Result, '(?ms)^---\s*.*?\s*---')
            $InsertAt = $FreshFrontMatterMatch.Index + $FreshFrontMatterMatch.Length
            $Result = $Result.Substring(0, $InsertAt) + "`n`n" + $ManagedBlock + "`n`n" + $Result.Substring($InsertAt).TrimStart("`r", "`n")
        }
    }

    if ($Override.PSObject.Properties.Name -contains 'bodyPatches' -and $null -ne $Override.bodyPatches) {
        foreach ($Patch in @($Override.bodyPatches)) {
            if ($null -eq $Patch -or -not ($Patch.PSObject.Properties.Name -contains 'find') -or [string]::IsNullOrWhiteSpace($Patch.find)) {
                continue
            }

            $FindText = Get-NormalizedText -Text $Patch.find
            $ReplaceText = if ($Patch.PSObject.Properties.Name -contains 'replace' -and $null -ne $Patch.replace) {
                Get-NormalizedText -Text $Patch.replace
            }
            else {
                ''
            }
            $Reason = if ($Patch.PSObject.Properties.Name -contains 'reason' -and $Patch.reason) { $Patch.reason } else { '(no reason field)' }

            if ($Result.Contains($FindText)) {
                $Result = $Result.Replace($FindText, $ReplaceText)
            }
            else {
                $PreviewLen = [Math]::Min(80, $FindText.Length)
                $Missing += [pscustomobject]@{
                    Reason      = $Reason
                    FindPreview = $FindText.Substring(0, $PreviewLen).Replace("`n", ' \n ')
                }
            }
        }
    }

    $Result = [regex]::Replace($Result, '(\n){3,}', "`n`n")

    if ($Result -ne $Original) {
        Write-TextFileUtf8NoBom -Path $SkillFile -Text $Result
    }

    return [pscustomobject]@{
        Applied      = ($Result -ne $Original)
        HasOverride  = $true
        Missing      = @($Missing)
    }
}

function Format-ImpeccableTextFiles {
    param([string]$SkillDir)

    $Extensions = @('.md', '.mjs', '.json', '.ps1')
    $Changed = 0
    $Checked = 0

    $Files = @(
        Get-ChildItem -LiteralPath $SkillDir -Recurse -File -Force |
            Where-Object { $Extensions -contains $_.Extension.ToLowerInvariant() }
    )

    foreach ($File in $Files) {
        $Checked += 1
        $Original = Read-TextFileUtf8 -Path $File.FullName
        $Normalized = Get-NormalizedText -Text $Original
        $Updated = [regex]::Replace($Normalized, '[ \t]+(?=\n|$)', '')
        $Updated = [regex]::Replace($Updated, '\n+\z', '')
        if ($Updated.Length -gt 0) {
            $Updated += "`n"
        }

        if ($Updated -ne $Original) {
            Write-TextFileUtf8NoBom -Path $File.FullName -Text $Updated
            $Changed += 1
        }
    }

    return [pscustomobject]@{
        Checked = $Checked
        Changed = $Changed
    }
}

function Invoke-ImpeccableScriptSyntaxCheck {
    param([string]$SkillDir)

    $ScriptsDir = Join-Path $SkillDir 'scripts'
    $Failures = @()
    $Checked = 0

    if (-not (Test-Path -LiteralPath $ScriptsDir)) {
        return [pscustomobject]@{
            Valid    = $false
            Checked  = 0
            Failures = @([pscustomobject]@{ Path = 'scripts'; Detail = 'missing scripts directory' })
        }
    }

    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Valid    = $false
            Checked  = 0
            Failures = @([pscustomobject]@{ Path = 'node'; Detail = 'node executable not found' })
        }
    }

    $Files = @(
        Get-ChildItem -LiteralPath $ScriptsDir -Recurse -File |
            Where-Object { $_.Extension.ToLowerInvariant() -in @('.mjs', '.js') }
    )

    foreach ($File in $Files) {
        $Checked += 1
        $Result = Invoke-NativeCaptured -FilePath 'node' -Arguments @('--check', $File.FullName)
        if ($Result.ExitCode -ne 0) {
            $Failures += [pscustomobject]@{
                Path   = $File.FullName
                Detail = $Result.Output
            }
        }
    }

    return [pscustomobject]@{
        Valid    = ($Failures.Count -eq 0)
        Checked  = $Checked
        Failures = @($Failures)
    }
}

function Copy-DirectoryClean {
    param(
        [string]$SourceDir,
        [string]$DestinationDir,
        [string]$AllowedParent
    )

    if (-not (Test-Path -LiteralPath $SourceDir)) {
        throw "Source directory does not exist: $SourceDir"
    }

    Assert-PathInside -ChildPath $DestinationDir -ParentPath $AllowedParent -Purpose 'copy destination'

    if (Test-Path -LiteralPath $DestinationDir) {
        Remove-Item -LiteralPath $DestinationDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    Get-ChildItem -LiteralPath $SourceDir -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationDir -Recurse -Force
    }
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    $RootFull = (Get-FullPath -Path $Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $PathFull = Get-FullPath -Path $Path
    return $PathFull.Substring($RootFull.Length).Replace('\', '/')
}

function Get-FileSha256 {
    param([string]$Path)

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    $Stream = [System.IO.File]::OpenRead($Path)
    try {
        $HashBytes = $Sha.ComputeHash($Stream)
        return ([System.BitConverter]::ToString($HashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $Stream.Dispose()
        $Sha.Dispose()
    }
}

function Get-ImpeccableFileInventory {
    param([string]$Root)

    $Inventory = @{}
    $Files = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
            Where-Object { $_.FullName -notmatch '\\\.git\\' }
    )

    foreach ($File in $Files) {
        $RelativePath = Get-RelativePath -Root $Root -Path $File.FullName
        $Inventory[$RelativePath] = Get-FileSha256 -Path $File.FullName
    }

    return $Inventory
}

function Compare-ImpeccableDirectories {
    param(
        [string]$CurrentDir,
        [string]$CandidateDir
    )

    $Current = Get-ImpeccableFileInventory -Root $CurrentDir
    $Candidate = Get-ImpeccableFileInventory -Root $CandidateDir
    $AllPaths = @($Current.Keys + $Candidate.Keys | Sort-Object -Unique)
    $Added = @()
    $Modified = @()
    $Deleted = @()

    foreach ($Path in $AllPaths) {
        $InCurrent = $Current.ContainsKey($Path)
        $InCandidate = $Candidate.ContainsKey($Path)

        if (-not $InCurrent -and $InCandidate) {
            $Added += $Path
        }
        elseif ($InCurrent -and -not $InCandidate) {
            $Deleted += $Path
        }
        elseif ($Current[$Path] -ne $Candidate[$Path]) {
            $Modified += $Path
        }
    }

    return [pscustomobject]@{
        Added    = @($Added)
        Modified = @($Modified)
        Deleted  = @($Deleted)
    }
}

function Write-ListPreview {
    param(
        [string]$Label,
        [object[]]$Items,
        [int]$Limit = 30
    )

    Write-Host ("{0}: {1}" -f $Label, $Items.Count)
    foreach ($Item in ($Items | Select-Object -First $Limit)) {
        Write-Host ("  - {0}" -f $Item)
    }
    if ($Items.Count -gt $Limit) {
        Write-Host ("  ... {0} more" -f ($Items.Count - $Limit))
    }
}

function Update-ImpeccableLock {
    param(
        [object]$Source,
        [string]$RepoUrl,
        [string]$Branch,
        [string]$LockPath = $LockPath
    )

    $Skills = [ordered]@{}
    if (Test-Path -LiteralPath $LockPath) {
        $Existing = Read-JsonFileUtf8 -Path $LockPath
        if ($Existing -and $Existing.PSObject.Properties.Name -contains 'skills') {
            foreach ($Property in $Existing.skills.PSObject.Properties) {
                $Skills[$Property.Name] = $Property.Value
            }
        }
    }

    $Skills[$SkillName] = [ordered]@{
        repo          = $RepoUrl
        branch        = $Branch
        sourceSubdir  = $SourceSubdir
        sourceKind    = $Source.SourceKind
        sourcePath    = $Source.SourcePath
        commit        = $Source.Commit
        localPatches  = 'impeccable-local-patches.json'
        updatedAt     = (Get-Date).ToString('o')
    }

    $Lock = [ordered]@{
        skills = $Skills
    }

    Write-TextFileUtf8NoBom -Path $LockPath -Text (($Lock | ConvertTo-Json -Depth 10) + "`n")
}

function Invoke-ManageSkills {
    param([string[]]$Arguments)

    if (-not (Test-Path -LiteralPath $ManageSkillsPath)) {
        throw "Missing manage-skills.ps1: $ManageSkillsPath"
    }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $ManageSkillsPath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "manage-skills.ps1 failed: $($Arguments -join ' ')"
    }
}

function Invoke-ImpeccableUpdate {
    param(
        [ValidateSet('preview', 'apply')]
        [string]$Mode = 'preview',
        [string]$SourcePath = '',
        [string]$RepoUrl = 'https://github.com/pbakaus/impeccable.git',
        [string]$Branch = 'main',
        [string]$CacheDir = (Join-Path (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.agents\external') 'impeccable-upstream')
    )

    $Source = Resolve-ImpeccableSource -SourcePath $SourcePath -RepoUrl $RepoUrl -Branch $Branch -CacheDir $CacheDir
    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("impeccable-update-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

    try {
        $CandidateDir = Join-Path $TempRoot $SkillName
        Copy-DirectoryClean -SourceDir $Source.SkillDir -DestinationDir $CandidateDir -AllowedParent $TempRoot

        $PatchResult = Apply-ImpeccableLocalPatches -SkillDir $CandidateDir -PatchConfigPath $LocalPatchConfigPath
        $RoutingResult = Apply-ImpeccableRoutingOverride -SkillDir $CandidateDir -OverridesPath $LocalRoutingOverridesPath
        $FormatResult = Format-ImpeccableTextFiles -SkillDir $CandidateDir
        $Bundle = Test-ImpeccableBundle -SkillDir $CandidateDir
        $Syntax = Invoke-ImpeccableScriptSyntaxCheck -SkillDir $CandidateDir
        $Diff = Compare-ImpeccableDirectories -CurrentDir $LocalSkillDir -CandidateDir $CandidateDir

        Write-Host "Impeccable update mode: $Mode"
        Write-Host "Source kind: $($Source.SourceKind)"
        Write-Host "Source path: $($Source.SourcePath)"
        Write-Host "Source commit: $(if ($Source.Commit) { $Source.Commit } else { '(none)' })"
        Write-Host "Commands: $($Bundle.Commands.Count) [$($Bundle.Commands -join ', ')]"
        Write-Host "Local patches applied: $($PatchResult.AppliedCount)"
        Write-Host "Routing override applied: $($RoutingResult.Applied)"
        Write-Host "Formatted text files: $($FormatResult.Changed)/$($FormatResult.Checked)"
        Write-Host "Node syntax checks: $($Syntax.Checked)"
        Write-ListPreview -Label 'Added files' -Items $Diff.Added
        Write-ListPreview -Label 'Modified files' -Items $Diff.Modified
        Write-ListPreview -Label 'Deleted files' -Items $Diff.Deleted

        $Errors = @()
        if (-not $Bundle.Valid) {
            $Errors += 'bundle structure is invalid'
        }
        if (@($Bundle.MissingRequiredPaths).Count -gt 0) {
            $Errors += ('missing required paths: ' + (@($Bundle.MissingRequiredPaths) -join ', '))
        }
        if (@($Bundle.MissingReferences).Count -gt 0) {
            $Errors += ('missing command references: ' + (@($Bundle.MissingReferences) -join ', '))
        }
        if (@($PatchResult.Missing).Count -gt 0) {
            $Errors += ('local patch anchors missing: ' + (@($PatchResult.Missing | ForEach-Object { "$($_.Path): $($_.Reason)" }) -join '; '))
        }
        if (@($RoutingResult.Missing).Count -gt 0) {
            $Errors += ('routing bodyPatch anchors missing: ' + (@($RoutingResult.Missing | ForEach-Object { $_.Reason }) -join '; '))
        }
        if (-not $Syntax.Valid) {
            $Errors += ('script syntax failures: ' + (@($Syntax.Failures | ForEach-Object { $_.Path }) -join ', '))
        }

        if ($Errors.Count -gt 0) {
            throw ("Preview failed validation:`n- " + ($Errors -join "`n- "))
        }

        if ($Mode -eq 'apply') {
            $ChangeCount = @($Diff.Added).Count + @($Diff.Modified).Count + @($Diff.Deleted).Count
            if ($ChangeCount -gt 0) {
                $BackupRoot = Join-Path (Split-Path -Parent $ScriptRoot) 'external\impeccable-backups'
                $BackupDir = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')
                New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
                Copy-DirectoryClean -SourceDir $LocalSkillDir -DestinationDir $BackupDir -AllowedParent $BackupRoot
                Copy-DirectoryClean -SourceDir $CandidateDir -DestinationDir $LocalSkillDir -AllowedParent $ScriptRoot
                Write-Host "Backup written: $BackupDir"
            }
            else {
                Write-Host 'No local file changes to apply.'
            }

            Invoke-ManageSkills -Arguments @('-Mode', 'apply-overrides', '-Only', $SkillName)
            Invoke-ManageSkills -Arguments @('-Mode', 'check', '-Only', $SkillName)
            Update-ImpeccableLock -Source $Source -RepoUrl $RepoUrl -Branch $Branch -LockPath $LockPath
            Write-Host "Lock updated: $LockPath"
        }
        else {
            Write-Host 'Preview only; no local skill files were changed.'
        }
    }
    finally {
        if (Test-Path -LiteralPath $TempRoot) {
            Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

if ($LoadOnly) {
    return
}

# Failure guidance lives with the script that produces the failures. Without
# this, the desktop .bat could only surface a raw PowerShell exception dump —
# the one actionable line buried between "所在位置", CategoryInfo and
# FullyQualifiedErrorId — leaving the reader to fish the cause out of a stack.
$FailureGuidance = @(
    [pscustomobject]@{
        Match = 'local patch anchors missing'
        Hint  = @(
            '上游改写了本地补丁所锚定的正文，find 已匹配不到。'
            '处理：对照上游最新内容重写 impeccable-local-patches.json 里对应的 find；'
            '优先锚定不易变动的句子，避免锚在会随版本调整的措辞上。'
        )
    }
    [pscustomobject]@{
        Match = 'routing bodyPatch anchors missing'
        Hint  = @(
            'local-routing-overrides.json 中 impeccable 的 bodyPatch 锚点已失效。'
            '处理：按上游现网正文重写该 find，再运行 manage-skills.ps1 -Mode apply-overrides -Only impeccable。'
        )
    }
    [pscustomobject]@{
        Match = 'missing command references|missing required paths|bundle structure is invalid'
        Hint  = @(
            '上游 skill 包结构不完整，缺少必需目录或命令参考文件，已拒绝覆盖本地版本。'
            '处理：先到上游仓库确认这是有意重构还是上游自身出错，确认后再调整本脚本的结构校验预期。'
        )
    }
    [pscustomobject]@{
        Match = 'script syntax failures'
        Hint  = @(
            '上游 scripts 下的脚本未通过 node --check，已拒绝覆盖本地版本。'
            '处理：这通常是上游提交了坏代码，等上游修复后重试即可，不要绕过校验。'
        )
    }
    [pscustomobject]@{
        Match = 'does not contain expected skill directory|SourcePath must be either'
        Hint  = @(
            '在来源中找不到结构完整的 impeccable 目录（已自动递归探测过重定位的副本）。'
            '处理：确认上游是否整体重构，必要时用 -SourcePath 显式指定新的 skill 目录。'
        )
    }
    [pscustomobject]@{
        Match = 'Git cache has local changes'
        Hint  = @(
            '上游 Git 缓存有本地改动，为避免混入未知内容已停止。'
            "处理：该缓存是纯镜像，可直接重置：git -C `"$CacheDir`" reset --hard && git -C `"$CacheDir`" clean -fdx"
        )
    }
    [pscustomobject]@{
        Match = 'git is required'
        Hint  = @('找不到 git，无法拉取上游。处理：安装 git 或用 -SourcePath 指向已就绪的本地目录。')
    }
)

function Get-FailureHint {
    param([string]$Message)

    foreach ($Entry in $FailureGuidance) {
        if ($Message -match $Entry.Match) {
            return @($Entry.Hint)
        }
    }
    return @()
}

try {
    Invoke-ImpeccableUpdate -Mode $Mode -SourcePath $SourcePath -RepoUrl $RepoUrl -Branch $Branch -CacheDir $CacheDir
}
catch {
    $Message = [string]$_.Exception.Message

    Write-Host ''
    Write-Host '================================================================'
    Write-Host ("{0} 未完成，本地 impeccable 未被改动。" -f $Mode)
    Write-Host '================================================================'
    Write-Host ''
    Write-Host '原因:'
    foreach ($Line in ($Message -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($Line)) { Write-Host ("  " + $Line.TrimEnd()) }
    }

    # Wrapped in @() because returning an empty array from a function unrolls to
    # $null on the way out, and $null.Count throws under Set-StrictMode.
    $Hint = @(Get-FailureHint -Message $Message)
    if ($Hint.Count -gt 0) {
        Write-Host ''
        Write-Host '怎么处理:'
        foreach ($Line in $Hint) { Write-Host ("  " + $Line) }
    }

    Write-Host ''
    # Stack traces are diagnostics for whoever edits this script, not for the
    # person who double-clicked a shortcut, so they stay out of the default view.
    if ($env:IMPECCABLE_UPDATER_DEBUG -eq '1') {
        Write-Host '--- 调试信息 ---'
        Write-Host $_.ScriptStackTrace
        Write-Host ''
    }
    else {
        Write-Host '（需要堆栈时设 IMPECCABLE_UPDATER_DEBUG=1 再运行）'
        Write-Host ''
    }

    exit 1
}
