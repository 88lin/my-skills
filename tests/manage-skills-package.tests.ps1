param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. $ManagerPath -LoadOnly
$SkillsRoot = Join-Path (Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))) 'skills'
$null = New-Item -ItemType Directory -Path $SkillsRoot -Force
$RoutingOverrides = @{ fixture = [pscustomobject]@{ skill = 'fixture'; localFolder = 'fixture'; description = 'LOCAL TRIGGER' } }
$Entry = [pscustomobject]@{ name = 'fixture'; localFolder = 'fixture'; type = 'skills-cli'; autoUpdate = $true; repo = 'fixture/repo'; skill = 'fixture'; rawSkillUrl = ('https://raw.githubusercontent.com/fixture/repo/' + ('1' * 40) + '/skills/fixture/SKILL.md') }
$script:FixtureRoot = Join-Path $SkillsRoot 'fixture'
$script:SourceFiles = @{
    'SKILL.md' = [Text.Encoding]::UTF8.GetBytes("---`nname: fixture`ndescription: BROAD TRIGGER`n---`n# Fixture`n")
    'scripts/run.ps1' = [Text.Encoding]::UTF8.GetBytes("Write-Output 'v1'`n")
    'agents/openai.yaml' = [Text.Encoding]::UTF8.GetBytes("interface:`n  display_name: Fixture`n")
    'references/old.md' = [Text.Encoding]::UTF8.GetBytes("original upstream text`n")
    'assets/data.bin' = [byte[]]@(65, 13, 10, 66)
    '.clawscan-allow' = [Text.Encoding]::UTF8.GetBytes("# text control file`n")
}
$script:ZipPath = Join-Path (Split-Path -Parent $SkillsRoot) 'upstream.zip'
$script:NpxCalls = 0
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Assert-Throws { param([scriptblock]$Action, [string]$Pattern) $Caught = $false; try { & $Action } catch { $Caught = $true; if ($_.Exception.Message -notmatch $Pattern) { throw } }; if (-not $Caught) { throw "Expected failure: $Pattern" } }
function Write-FixtureFile {
    param([string]$Relative, [byte[]]$Bytes)
    $Path = Join-Path $script:FixtureRoot $Relative
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    [IO.File]::WriteAllBytes($Path, $Bytes)
}
function Build-Archive {
    Close-SkillPackageSession
    if (Test-Path -LiteralPath $script:ZipPath) { Remove-Item -LiteralPath $script:ZipPath }
    $Archive = [IO.Compression.ZipFile]::Open($script:ZipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($Relative in $script:SourceFiles.Keys) {
            $ZipEntry = $Archive.CreateEntry('fixture-revision/skills/fixture/' + $Relative)
            $Stream = $ZipEntry.Open()
            try { $Bytes = $script:SourceFiles[$Relative]; $Stream.Write($Bytes, 0, $Bytes.Length) } finally { $Stream.Dispose() }
        }
    }
    finally { $Archive.Dispose() }
}
function Invoke-WebRequest {
    param([switch]$UseBasicParsing, [string]$Uri, [string]$OutFile, [int]$TimeoutSec)
    if ($Uri -notlike 'https://codeload.github.com/fixture/repo/zip/*' -or -not $OutFile) { throw "Unexpected HTTP: $Uri" }
    Copy-Item -LiteralPath $script:ZipPath -Destination $OutFile
}
function Invoke-ExternalCommand {
    param([string]$FilePath, [string[]]$Arguments, [int]$TimeoutSec, [switch]$StreamOutput)
    Assert-Equal $FilePath 'cmd.exe' 'Only simulated npx transport is allowed'
    Assert-Equal ($Arguments -join ' ') '/c npx -y skills add fixture/repo@fixture -g -y' 'Installer command contract'
    $script:NpxCalls++
    foreach ($Relative in $script:SourceFiles.Keys) { Write-FixtureFile $Relative $script:SourceFiles[$Relative] }
    return [pscustomobject]@{ ExitCode = 0; TimedOut = $false; Output = 'fixture installed' }
}

try {
    Build-Archive
    foreach ($Relative in $script:SourceFiles.Keys) { Write-FixtureFile $Relative $script:SourceFiles[$Relative] }
    $null = Apply-RoutingOverrideToLocalSkill -Entry $Entry
    Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Complete package is current'
    $ManifestPath = Get-SkillManifestPath $Entry
    Assert-Equal (Test-Path -LiteralPath $ManifestPath) $false 'Check must not write ownership state'
    Write-Output 'PASS: full archive check is read-only and accounts for routing overrides'

    $TextPath = Join-Path $script:FixtureRoot 'scripts/run.ps1'
    [IO.File]::WriteAllText($TextPath, "Write-Output 'v1'`r`n", (New-Object Text.UTF8Encoding($true)))
    Write-FixtureFile '.clawscan-allow' ([Text.Encoding]::UTF8.GetBytes("# text control file`r`n"))
    Assert-Equal (Get-SkillStatus $Entry).Status 'up-to-date' 'Text line ending/BOM differences are normalized'
    Write-FixtureFile 'assets/data.bin' ([byte[]]@(65, 10, 66))
    Assert-Equal (Get-SkillStatus $Entry).Status 'outdated' 'Even UTF8-looking binary data is byte-exact'
    Write-FixtureFile 'assets/data.bin' $script:SourceFiles['assets/data.bin']
    Write-Output 'PASS: text normalization does not hide binary differences'

    Remove-Item -LiteralPath $TextPath
    $Status = Get-SkillStatus $Entry
    Assert-Equal $Status.Status 'outdated' 'Missing script must not pass'
    if ($Status.Detail -notmatch 'missing=1') { throw $Status.Detail }
    $Updated = Update-Skill $Entry
    Assert-Equal $Updated.Action 'updated' 'Resource-only defect must invoke an update'
    Assert-Equal (Test-Path -LiteralPath $TextPath) $true 'Missing script restored'
    Assert-Equal (Test-Path -LiteralPath $ManifestPath) $true 'Successful update records ownership'
    if ($Updated.Detail -notmatch 'backup:') { throw 'Missing pre-update backup evidence' }
    Write-Output 'PASS: absent non-entry resource triggers update, backup and post-update verification'

    Write-FixtureFile 'agents/openai.yaml' ([Text.Encoding]::UTF8.GetBytes('tampered policy'))
    Assert-Equal (Get-SkillStatus $Entry).Status 'outdated' 'Client invocation metadata is part of the package'
    Assert-Equal (Update-Skill $Entry).Action 'updated' 'Metadata drift repaired'
    $StateHash = Get-FileHashValue $ManifestPath
    $CallsBefore = $script:NpxCalls
    Assert-Equal (Update-Skill $Entry).Action 'unchanged' 'Second update is idempotent'
    Assert-Equal $script:NpxCalls $CallsBefore 'Idempotent update does not reinstall'
    Assert-Equal (Get-FileHashValue $ManifestPath) $StateHash 'Unchanged ownership state is byte-identical'
    Write-Output 'PASS: agents metadata is checked and updates are idempotent'

    $script:SourceFiles['scripts/run.ps1'] = [Text.Encoding]::UTF8.GetBytes("Write-Output 'v2'`n")
    Build-Archive
    Assert-Equal (Get-SkillStatus $Entry).Status 'outdated' 'Upstream resource-only change must be detected'
    $Updated = Update-Skill $Entry
    Assert-Equal $Updated.Action 'updated' ('Upstream resource change repaired: ' + $Updated.Detail)
    Write-Output 'PASS: upstream resource changes are detected when SKILL.md is unchanged'

    $OldBytes = $script:SourceFiles['references/old.md']
    $script:SourceFiles.Remove('references/old.md')
    Build-Archive
    Write-FixtureFile 'notes/local.txt' ([Text.Encoding]::UTF8.GetBytes('unknown local addition'))
    Write-FixtureFile 'references/old.md' ([Text.Encoding]::UTF8.GetBytes('local edit to upstream-deleted file'))
    $CallsBefore = $script:NpxCalls
    Assert-Equal (Get-SkillStatus $Entry).Status 'error' 'Modified obsolete file blocks cleanup'
    Assert-Equal (Update-Skill $Entry).Action 'skipped' 'Conflicted obsolete file blocks before install'
    Assert-Equal $script:NpxCalls $CallsBefore 'No install for deletion conflict'
    Write-FixtureFile 'references/old.md' $OldBytes
    Assert-Equal (Get-SkillStatus $Entry).Status 'outdated' 'Unmodified obsolete file is reported'
    Assert-Equal (Update-Skill $Entry).Action 'updated' 'Owned obsolete file is pruned after backup'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $script:FixtureRoot 'references/old.md')) $false 'Obsolete file removed'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $script:FixtureRoot 'notes/local.txt')) $true 'Unknown local file preserved'
    Write-Output 'PASS: ownership permits safe pruning and protects edited or unknown local files'

    foreach ($Unsafe in @('../escape', 'sub/../../escape', 'sub/.git/config', 'CON', 'file.', 'a*/b')) {
        Assert-Throws { Get-SafeSkillFilePath -Entry $Entry -Relative $Unsafe } 'Unsafe'
    }
    $Outside = Join-Path (Split-Path -Parent $SkillsRoot) 'outside'
    $null = New-Item -ItemType Directory -Path $Outside
    $null = New-Item -ItemType Junction -Path (Join-Path $script:FixtureRoot 'linked') -Target $Outside
    Assert-Throws { Get-SafeSkillFilePath -Entry $Entry -Relative 'linked/file.txt' } 'crosses a link'
    Write-Output 'PASS: traversal, Windows alias paths and junction access are rejected'

    $StateBytes = [IO.File]::ReadAllBytes($ManifestPath)
    $State = Read-JsonFileUtf8 $ManifestPath
    $State.sourceIdentity = 'different-source'
    [IO.File]::WriteAllText($ManifestPath, ($State | ConvertTo-Json -Depth 10))
    Assert-Equal (Get-SkillStatus $Entry).Status 'error' 'Source mismatch must fail closed'
    [IO.File]::WriteAllBytes($ManifestPath, $StateBytes)
    Write-Output 'PASS: ownership source mismatches fail without deleting files'
    Write-Output '8 package regression scenarios passed.'
}
finally { Close-SkillPackageSession }
