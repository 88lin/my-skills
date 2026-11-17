# Shared package inventory and ownership state. No top-level network or writes.
# Load through manage-skills.ps1 -LoadOnly when another entry point needs it.

function Get-SafeSkillFilePath {
    param([object]$Entry, [string]$Relative)
    if ($Entry.localFolder -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Invalid single-level skill folder: $($Entry.localFolder)"
    }
    $Relative = $Relative.Replace('\', '/')
    $Parts = @($Relative -split '/')
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '[<>:"|?*\x00-\x1f]' -or
        @($Parts | Where-Object { $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)' }).Count -gt 0) {
        throw "Unsafe managed relative path: $Relative"
    }
    $Root = [IO.Path]::GetFullPath((Get-LocalSkillPath -Entry $Entry)).TrimEnd('\', '/')
    $Target = [IO.Path]::GetFullPath((Join-Path $Root ($Relative.Replace('/', '\'))))
    if (-not $Target.StartsWith($Root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Managed path escapes skill folder: $Relative"
    }
    $Cursor = $Root
    foreach ($Part in @('') + $Parts) {
        if ($Part -ne '') { $Cursor = Join-Path $Cursor $Part }
        if (Test-Path -LiteralPath $Cursor) {
            if ((Get-Item -LiteralPath $Cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Managed path crosses a link; refusing access: $Cursor"
            }
        }
    }
    return $Target
}

function Get-SkillPackageIdentity {
    param([object]$Entry)
    $Fields = [ordered]@{ type = $Entry.type; localFolder = $Entry.localFolder }
    foreach ($Name in @('repo', 'rawSkillUrl', 'remote', 'branch', 'repositoryFolder', 'syncSkillDirectory', 'syncSkillDirectories', 'syncSkillFile', 'syncSkillFiles')) {
        if ($Entry.PSObject.Properties.Name -contains $Name) { $Fields[$Name] = $Entry.$Name }
    }
    return (Get-TextHash -Text ($Fields | ConvertTo-Json -Depth 10 -Compress))
}

function Get-SkillManifestPath {
    param([object]$Entry)
    $null = Get-SafeSkillFilePath -Entry $Entry -Relative 'SKILL.md'
    $StateRoot = Join-Path (Split-Path -Parent $SkillsRoot) 'external\skill-package-state'
    return (Join-Path $StateRoot ($Entry.localFolder + '.json'))
}

function Read-SkillManagedManifest {
    param([object]$Entry)
    $Path = Get-SkillManifestPath -Entry $Entry
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $State = Read-JsonFileUtf8 -Path $Path
    if ($State.schemaVersion -ne 1 -or $State.sourceIdentity -ne (Get-SkillPackageIdentity -Entry $Entry)) {
        throw "Managed-file state has a different source or schema; review before replacing it: $Path"
    }
    $Seen = @{}
    foreach ($File in @($State.files)) {
        $null = Get-SafeSkillFilePath -Entry $Entry -Relative $File.path
        if ($File.sha256 -notmatch '^[0-9a-f]{64}$' -or $Seen.ContainsKey($File.path)) {
            throw "Invalid managed-file state: $Path"
        }
        $Seen[$File.path] = $true
    }
    return $State
}

function Get-GitSkillManagedPaths {
    param([object]$Entry)
    $Paths = @{}
    $RepositoryRoot = Get-GitRepositoryPath -Entry $Entry
    foreach ($Mapping in @(Get-SyncSkillDirectoryMappings -Entry $Entry)) {
        $SourceRoot = [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $Mapping.Source)).TrimEnd('\', '/')
        if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { throw "Missing sync source: $SourceRoot" }
        foreach ($File in @(Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File)) {
            $Relative = $File.FullName.Substring($SourceRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $Destination = if ($Mapping.Destination -eq '.') { $Relative } else { $Mapping.Destination.TrimEnd('\', '/').Replace('\', '/') + '/' + $Relative }
            $null = Get-SafeSkillFilePath -Entry $Entry -Relative $Destination
            $Paths[$Destination] = $true
        }
    }
    if ($null -ne (Get-SyncSkillSourcePath -Entry $Entry)) { $Paths['SKILL.md'] = $true }
    foreach ($Mapping in @(Get-SyncSkillExtraFileMappings -Entry $Entry)) {
        $Relative = $Mapping.Destination.Replace('\', '/')
        $null = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
        $Paths[$Relative] = $true
    }
    if ($Paths.Count -gt 0 -and $null -ne (Get-CodexSkillPolicy -Entry $Entry)) { $Paths['agents/openai.yaml'] = $true }
    return @($Paths.Keys | Sort-Object)
}

function Get-SkillManagedPaths {
    param([object]$Entry)
    if ($Entry.type -eq 'skills-cli') { return @((Get-SkillCliExpectedFiles -Entry $Entry -Snapshot (Get-SkillCliSourceSnapshot -Entry $Entry)).Keys | Sort-Object) }
    if ($Entry.type -eq 'git') { return @(Get-GitSkillManagedPaths -Entry $Entry) }
    return @()
}

function Get-SkillManagedRemovalPlan {
    param([object]$Entry, [string[]]$ExpectedPaths)
    $Expected = @{}
    foreach ($Path in $ExpectedPaths) { $Expected[$Path.Replace('\', '/')] = $true }
    $Removed = New-Object System.Collections.Generic.List[object]
    $Conflicts = New-Object System.Collections.Generic.List[string]
    $State = Read-SkillManagedManifest -Entry $Entry
    if ($null -ne $State) {
        foreach ($File in @($State.files)) {
            if ($Expected.ContainsKey($File.path)) { continue }
            $Path = Get-SafeSkillFilePath -Entry $Entry -Relative $File.path
            if (-not (Test-Path -LiteralPath $Path)) { continue }
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-FileHashValue -Path $Path) -ne $File.sha256) {
                $Conflicts.Add($File.path)
            }
            else {
                $Removed.Add([pscustomobject]@{ Relative = $File.path; Path = $Path; Sha256 = $File.sha256 })
            }
        }
    }
    return [pscustomobject]@{ Removed = @($Removed.ToArray()); Conflicts = @($Conflicts.ToArray()) }
}

function Assert-SkillRemovalPlan {
    param([object]$Plan)
    if (@($Plan.Conflicts).Count -gt 0) {
        throw ('Upstream removed files that have local changes; preserved: ' + ($Plan.Conflicts -join ', '))
    }
}

function Remove-StaleManagedSkillFiles {
    param([object]$Entry, [object]$Plan)
    Assert-SkillRemovalPlan -Plan $Plan
    # The caller must have completed New-SkillUpdateBackup before reaching here.
    # Recheck every target immediately before deleting; never recurse or follow links.
    foreach ($File in @($Plan.Removed)) {
        $Path = Get-SafeSkillFilePath -Entry $Entry -Relative $File.Relative
        if (-not (Test-Path -LiteralPath $Path)) { continue }
        if ((Get-FileHashValue -Path $Path) -ne $File.Sha256) { throw "Managed file changed during update; preserved: $Path" }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
}

function Save-SkillManagedManifest {
    param([object]$Entry)
    $Previous = Read-SkillManagedManifest -Entry $Entry
    $Paths = @(Get-SkillManagedPaths -Entry $Entry)
    if ($Paths.Count -eq 0) { return }
    $Files = @(
        foreach ($Relative in $Paths) {
            $Path = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
            if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Cannot record missing managed file: $Path" }
            [ordered]@{ path = $Relative; sha256 = (Get-FileHashValue -Path $Path) }
        }
    )
    if ($null -ne $Previous) {
        $Before = @($Previous.files | ForEach-Object { $_.path + ':' + $_.sha256 }) | Sort-Object
        $After = @($Files | ForEach-Object { $_.path + ':' + $_.sha256 }) | Sort-Object
        if (($Before -join "`n") -ceq ($After -join "`n")) { return }
    }
    $State = [ordered]@{
        schemaVersion = 1
        sourceIdentity = (Get-SkillPackageIdentity -Entry $Entry)
        skill = $Entry.name
        recordedAt = (Get-Date).ToString('o')
        files = $Files
    }
    $Path = Get-SkillManifestPath -Entry $Entry
    $Parent = Split-Path -Parent $Path
    $null = New-Item -ItemType Directory -Path $Parent -Force
    $TempPath = Join-Path $Parent ([guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($TempPath, ($State | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($TempPath, $Path, [NullString]::Value) }
        else { [IO.File]::Move($TempPath, $Path) }
    }
    finally {
        if (Test-Path -LiteralPath $TempPath) { Remove-Item -LiteralPath $TempPath -Force }
    }
}

function Get-PackageBytesHash {
    param([byte[]]$Bytes, [string]$RelativePath)
    # Git checkouts may use CRLF while GitHub archives use LF. Only normalize
    # known text formats that decode as UTF-8 without NUL. Unknown formats,
    # fonts and images stay byte-exact even if their bytes happen to be UTF-8.
    $Extension = [IO.Path]::GetExtension($RelativePath).ToLowerInvariant()
    $Name = [IO.Path]::GetFileName($RelativePath)
    $IsText = $Extension -in @('.md', '.mdx', '.mdc', '.txt', '.json', '.jsonl', '.yaml', '.yml', '.toml', '.ini', '.xml', '.svg', '.html', '.htm', '.css', '.scss', '.less', '.js', '.mjs', '.cjs', '.jsx', '.ts', '.tsx', '.py', '.ps1', '.psm1', '.psd1', '.sh', '.bat', '.cmd', '.csv', '.tsv', '.sql', '.rst', '.conf', '.cfg') -or
        $Name -match '^(LICENSE(?:\..*)?|NOTICE|README|Makefile|Dockerfile|\.gitignore|\.gitattributes|\.gitmodules|\.npmignore|\.npmrc|\.yarnrc|\.editorconfig|\.env|\.dockerignore|\.prettierignore|\.eslintignore|\.clawscan-allow)$'
    try {
        if ($IsText) {
            $Encoding = New-Object Text.UTF8Encoding($false, $true)
            $Text = $Encoding.GetString($Bytes)
            if ($Text.IndexOf([char]0) -lt 0) { $Bytes = [Text.Encoding]::UTF8.GetBytes((Get-NormalizedText -Text $Text)) }
        }
    }
    catch [Text.DecoderFallbackException] {}
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $Sha.Dispose() }
}

function Get-PackageFileHash {
    param([string]$Path)
    return (Get-PackageBytesHash -Bytes ([IO.File]::ReadAllBytes($Path)) -RelativePath $Path)
}

function Get-SkillCliSourceLocation {
    param([object]$Entry)
    if ($Entry.repo -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Unsupported GitHub repo: $($Entry.repo)" }
    $Uri = [uri]$Entry.rawSkillUrl
    if ($Uri.Scheme -ne 'https' -or $Uri.Host -ne 'raw.githubusercontent.com' -or $Uri.Query -ne '') {
        throw 'skills-cli package checks require a GitHub rawSkillUrl matching the registered repo.'
    }
    $Prefix = '/' + $Entry.repo + '/'
    $Path = [uri]::UnescapeDataString($Uri.AbsolutePath)
    if (-not $Path.StartsWith($Prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'rawSkillUrl does not match repo.' }
    $Rest = $Path.Substring($Prefix.Length)
    if ($Entry.PSObject.Properties.Name -contains 'branch' -and $Entry.branch) {
        $Ref = [string]$Entry.branch
        if (-not $Rest.StartsWith($Ref + '/', [StringComparison]::Ordinal)) { throw 'rawSkillUrl does not match branch.' }
        $SkillPath = $Rest.Substring($Ref.Length + 1)
    }
    else {
        $SplitAt = $Rest.IndexOf('/')
        if ($SplitAt -lt 1) { throw 'rawSkillUrl has no revision/skill path.' }
        $Ref = $Rest.Substring(0, $SplitAt)
        $SkillPath = $Rest.Substring($SplitAt + 1)
    }
    if ($Ref -notmatch '^[A-Za-z0-9._/-]+$' -or -not $SkillPath.EndsWith('SKILL.md', [StringComparison]::Ordinal)) {
        throw 'Invalid rawSkillUrl revision or skill entry.'
    }
    $Directory = if ($SkillPath -eq 'SKILL.md') { '' } else { $SkillPath.Substring(0, $SkillPath.Length - 'SKILL.md'.Length) }
    if (@(($Directory -split '/') | Where-Object { $_ -in @('.', '..', '.git') }).Count -gt 0) { throw 'Unsafe package directory.' }
    return [pscustomobject]@{ Repo = $Entry.repo; Ref = $Ref; Directory = $Directory }
}

function Initialize-SkillPackageSession {
    if (-not (Get-Variable -Name SkillPackageArchives -Scope Script -ErrorAction SilentlyContinue)) {
        $script:SkillPackageArchives = @{}
        $script:SkillPackageSnapshots = @{}
        $script:SkillPackageSessionRoot = $null
    }
}

function Get-SkillRepositoryArchive {
    param([object]$Location)
    Initialize-SkillPackageSession
    $Key = $Location.Repo + '@' + $Location.Ref
    if ($script:SkillPackageArchives.ContainsKey($Key)) { return $script:SkillPackageArchives[$Key] }
    $Commit = if ($Location.Ref -match '^[0-9a-f]{40}$') { $Location.Ref } else { Get-GitRemoteHead -Remote ('https://github.com/' + $Location.Repo + '.git') -Branch $Location.Ref }
    if ($Commit -notmatch '^[0-9a-f]{40}$') { throw "Invalid upstream revision for $Key" }
    if ($null -eq $script:SkillPackageSessionRoot) {
        $script:SkillPackageSessionRoot = Join-Path ([IO.Path]::GetTempPath()) ('skill-package-check-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:SkillPackageSessionRoot
    }
    $ZipPath = Join-Path $script:SkillPackageSessionRoot ([guid]::NewGuid().ToString('N') + '.zip')
    $null = Invoke-WebRequest -UseBasicParsing -Uri ('https://codeload.github.com/' + $Location.Repo + '/zip/' + $Commit) -OutFile $ZipPath -TimeoutSec 180
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $Stream = [IO.File]::OpenRead($ZipPath)
    try {
        $Archive = New-Object IO.Compression.ZipArchive($Stream, [IO.Compression.ZipArchiveMode]::Read)
        if ($Archive.Entries.Count -eq 0) { throw "Empty upstream archive: $Key" }
        $First = $Archive.Entries[0].FullName
        $Slash = $First.IndexOf('/')
        if ($Slash -le 0) { throw "Invalid upstream archive root: $Key" }
        $Result = [pscustomobject]@{ Archive = $Archive; Stream = $Stream; Root = $First.Substring(0, $Slash + 1); Commit = $Commit }
        $script:SkillPackageArchives[$Key] = $Result
        return $Result
    }
    catch { $Stream.Dispose(); throw }
}

function Get-SkillCliSourceSnapshot {
    param([object]$Entry)
    Initialize-SkillPackageSession
    $Key = Get-SkillPackageIdentity -Entry $Entry
    if ($script:SkillPackageSnapshots.ContainsKey($Key)) { return $script:SkillPackageSnapshots[$Key] }
    $Location = Get-SkillCliSourceLocation -Entry $Entry
    $Bundle = Get-SkillRepositoryArchive -Location $Location
    $Prefix = $Bundle.Root + $Location.Directory
    $Files = @{}
    $EntryText = $null
    $OpenAiYaml = $null
    foreach ($ZipEntry in $Bundle.Archive.Entries) {
        if (-not $ZipEntry.FullName.StartsWith($Prefix, [StringComparison]::Ordinal) -or $ZipEntry.FullName.EndsWith('/')) { continue }
        $Relative = $ZipEntry.FullName.Substring($Prefix.Length)
        if (@($Relative.Split('/') | Where-Object { $_ -eq '.git' }).Count -gt 0) { continue }
        $null = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
        if ($Files.ContainsKey($Relative) -or (($ZipEntry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000) {
            throw "Duplicate or linked upstream package path: $Relative"
        }
        $InputStream = $ZipEntry.Open()
        $Buffer = New-Object IO.MemoryStream
        try { $InputStream.CopyTo($Buffer); $Bytes = $Buffer.ToArray() }
        finally { $InputStream.Dispose(); $Buffer.Dispose() }
        $Files[$Relative] = Get-PackageBytesHash -Bytes $Bytes -RelativePath $Relative
        if ($Relative -ceq 'SKILL.md') { $EntryText = Get-NormalizedText -Text ([Text.Encoding]::UTF8.GetString($Bytes)) }
        if ($Relative -ceq 'agents/openai.yaml') { $OpenAiYaml = Get-NormalizedText -Text ([Text.Encoding]::UTF8.GetString($Bytes)) }
    }
    if ($null -eq $EntryText -or $Files.Count -eq 0) { throw "Upstream package has no root SKILL.md: $($Entry.name)" }
    $Result = [pscustomobject]@{ Files = $Files; EntryText = $EntryText; OpenAiYaml = $OpenAiYaml; Commit = $Bundle.Commit }
    $script:SkillPackageSnapshots[$Key] = $Result
    return $Result
}

function Get-SkillCliPackageStatus {
    param([object]$Entry, [object]$Snapshot)
    $Missing = New-Object System.Collections.Generic.List[string]
    $Different = New-Object System.Collections.Generic.List[string]
    $ExpectedFiles = Get-SkillCliExpectedFiles -Entry $Entry -Snapshot $Snapshot
    foreach ($Relative in $ExpectedFiles.Keys) {
        if ($Relative -ieq 'SKILL.md') { continue } # Entry includes routing overrides; caller compares it separately.
        $Path = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $Missing.Add($Relative) }
        elseif ((Get-PackageFileHash -Path $Path) -ne $ExpectedFiles[$Relative]) { $Different.Add($Relative) }
    }
    $Plan = Get-SkillManagedRemovalPlan -Entry $Entry -ExpectedPaths @($ExpectedFiles.Keys)
    Assert-SkillRemovalPlan -Plan $Plan
    return [pscustomobject]@{
        InSync = ($Missing.Count -eq 0 -and $Different.Count -eq 0 -and @($Plan.Removed).Count -eq 0)
        Missing = @($Missing.ToArray())
        Different = @($Different.ToArray())
        RemovalPlan = $Plan
    }
}

function Close-SkillPackageSession {
    Initialize-SkillPackageSession
    foreach ($Item in $script:SkillPackageArchives.Values) {
        try { $Item.Archive.Dispose() } finally { $Item.Stream.Dispose() }
    }
    $script:SkillPackageArchives = @{}
    $script:SkillPackageSnapshots = @{}
    if ($null -ne $script:SkillPackageSessionRoot -and (Test-Path -LiteralPath $script:SkillPackageSessionRoot)) {
        # Delete only downloaded leaf ZIPs, then the empty directory. Never recurse.
        foreach ($File in @(Get-ChildItem -LiteralPath $script:SkillPackageSessionRoot -File)) {
            if ($File.Extension -eq '.zip') { Remove-Item -LiteralPath $File.FullName -Force -ErrorAction SilentlyContinue }
        }
        try { [IO.Directory]::Delete($script:SkillPackageSessionRoot, $false) } catch {}
    }
    $script:SkillPackageSessionRoot = $null
}

function Restore-SkillUpdateBackup {
    param([object]$Entry, [string]$BackupDirectory)
    $FilesRoot = Join-Path $BackupDirectory 'files'
    $Metadata = Read-JsonFileUtf8 -Path (Join-Path $BackupDirectory 'metadata.json')
    $LocalRoot = [IO.Path]::GetFullPath((Get-LocalSkillPath -Entry $Entry))
    if ($Metadata.originalPath -ne $LocalRoot -or -not (Test-Path -LiteralPath $FilesRoot -PathType Container)) {
        throw '安装前备份路径不匹配，停止自动恢复。'
    }
    # First preserve the failed install. Then restore only exact, validated
    # leaf paths; no recursive delete, directory replacement or Git reset.
    if (Test-Path -LiteralPath $LocalRoot) { $null = New-SkillUpdateBackup -Entry $Entry }
    $OriginalFiles = @{}
    foreach ($File in @(Get-ChildItem -LiteralPath $FilesRoot -Recurse -File -Force)) {
        $Relative = $File.FullName.Substring($FilesRoot.Length).TrimStart('\', '/').Replace('\', '/')
        $null = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
        $OriginalFiles[$Relative] = $File.FullName
    }
    $Removals = @()
    if (Test-Path -LiteralPath $LocalRoot) {
        foreach ($File in @(Get-ChildItem -LiteralPath $LocalRoot -Recurse -File -Force)) {
            $Relative = $File.FullName.Substring($LocalRoot.Length).TrimStart('\', '/').Replace('\', '/')
            $Target = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
            if (-not $OriginalFiles.ContainsKey($Relative)) { $Removals += $Target }
        }
    }
    # Validate the complete removal plan before changing any leaf.
    foreach ($Target in $Removals) { Remove-Item -LiteralPath $Target -Force }
    foreach ($Relative in $OriginalFiles.Keys) {
        $Target = Get-SafeSkillFilePath -Entry $Entry -Relative $Relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Target) -Force
        Copy-Item -LiteralPath $OriginalFiles[$Relative] -Destination $Target -Force
        if ((Get-FileHashValue -Path $Target) -ne (Get-FileHashValue -Path $OriginalFiles[$Relative])) {
            throw "安装前文件恢复校验失败: $Relative"
        }
    }
}
