param([Parameter(Mandatory = $true)][string]$ManagerPath, [Parameter(Mandatory = $true)][string]$WorkRoot)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Candidate = Split-Path -Parent $ManagerPath
$CaseRoot = Join-Path $WorkRoot ([guid]::NewGuid().ToString('N'))
$Fixture = Join-Path $CaseRoot 'skills'
$global:SkillInstallerFixtureRoot = $Fixture
$global:SkillInstallerUpstream = "---`nname: fixture`ndescription: UPSTREAM TRIGGER`n---`n# Fixture`n"
$global:SkillInstallerMode = 'success'
$global:SkillInstallerCalls = 0
$global:SkillInstallerNeedsBackup = $true
$global:SkillInstallerHttpCalls = 0
$global:SkillInstallerZip = Join-Path $CaseRoot 'upstream.zip'
$global:SkillInstallerFiles = @{
    'SKILL.md' = [Text.Encoding]::UTF8.GetBytes($global:SkillInstallerUpstream)
    'scripts/required.ps1' = [Text.Encoding]::UTF8.GetBytes("Write-Output 'required'`n")
    'agents/openai.yaml' = [Text.Encoding]::UTF8.GetBytes("interface:`n  display_name: Fixture`n")
}
$Utf8 = New-Object Text.UTF8Encoding($false)
$null = New-Item -ItemType Directory -Path (Join-Path $Fixture 'fixture') -Force
foreach ($Name in @('manage-skills.ps1', 'skill-package-state.ps1', 'skill-client-policy.ps1', 'skill-upstream-watch.ps1', 'install-and-register-skill.ps1')) {
    Copy-Item -LiteralPath (Join-Path $Candidate $Name) -Destination (Join-Path $Fixture $Name)
}
$RawUrl = 'https://raw.githubusercontent.com/fixture/repo/' + ('1' * 40) + '/SKILL.md'
$Config = [ordered]@{
    auditTag = 'preserve-root-metadata'
    skills = @(
        [ordered]@{ name = 'fixture'; localFolder = 'fixture'; type = 'skills-cli'; autoUpdate = $true; repo = 'fixture/repo'; skill = 'fixture'; rawSkillUrl = $RawUrl; notes = 'KEEP EXISTING METADATA' }
        [ordered]@{ name = 'protected'; localFolder = 'protected'; type = 'manual'; autoUpdate = $false; reason = 'KEEP MANUAL POLICY'; remote = 'https://example.invalid/source' }
        [ordered]@{ name = 'git-protected'; localFolder = 'git-protected'; type = 'git'; autoUpdate = $false; remote = 'https://example.invalid/git' }
    )
}
$ConfigPath = Join-Path $Fixture 'skills-sources.json'
[IO.File]::WriteAllText($ConfigPath, ($Config | ConvertTo-Json -Depth 12), $Utf8)
[IO.File]::WriteAllText((Join-Path $Fixture 'local-routing-overrides.json'), '{"overrides":[{"skill":"fixture","localFolder":"fixture","description":"LOCAL TRIGGER","codexPolicy":{"allow_implicit_invocation":false}}]}', $Utf8)
$SkillFile = Join-Path $Fixture 'fixture/SKILL.md'
[IO.File]::WriteAllText($SkillFile, $global:SkillInstallerUpstream.Replace('description: UPSTREAM TRIGGER', "description: >-`n  LOCAL TRIGGER"), $Utf8)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Zip = [IO.Compression.ZipFile]::Open($global:SkillInstallerZip, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($Relative in $global:SkillInstallerFiles.Keys) {
        $ZipEntry = $Zip.CreateEntry('fixture-revision/' + $Relative)
        $Stream = $ZipEntry.Open()
        try { $Bytes = $global:SkillInstallerFiles[$Relative]; $Stream.Write($Bytes, 0, $Bytes.Length) } finally { $Stream.Dispose() }
    }
} finally { $Zip.Dispose() }

function Assert-Equal { param($Actual, $Expected, [string]$Message) if ($Actual -cne $Expected) { throw "$Message`: expected [$Expected], got [$Actual]" } }
function Assert-Throws { param([scriptblock]$Action, [string]$Pattern) $Caught = $false; try { & $Action } catch { $Caught = $true; if ($_.Exception.Message -notmatch $Pattern) { throw } }; if (-not $Caught) { throw "Expected failure: $Pattern" } }
function Invoke-WebRequest {
    param([switch]$UseBasicParsing, [string]$Uri, [string]$OutFile, [int]$TimeoutSec)
    $global:SkillInstallerHttpCalls++
    if ($Uri -notlike 'https://codeload.github.com/fixture/repo/zip/*' -or -not $OutFile) { throw "Unexpected HTTP: $Uri" }
    Copy-Item -LiteralPath $global:SkillInstallerZip -Destination $OutFile
}
function npx {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Remaining)
    Assert-Equal ($Remaining -join ' ') '-y skills add fixture/repo@fixture -g -y' 'Noninteractive targeted install command'
    $global:SkillInstallerCalls++
    $Backups = Join-Path (Split-Path -Parent $global:SkillInstallerFixtureRoot) 'external/skill-update-backups/fixture'
    if ($global:SkillInstallerNeedsBackup -and @(Get-ChildItem -LiteralPath $Backups -Filter metadata.json -Recurse -File).Count -eq 0) { throw 'npx ran without a preinstall backup' }
    foreach ($Relative in $global:SkillInstallerFiles.Keys) {
        $Path = Join-Path (Join-Path $global:SkillInstallerFixtureRoot 'fixture') $Relative
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
        [IO.File]::WriteAllBytes($Path, $global:SkillInstallerFiles[$Relative])
    }
    if ($global:SkillInstallerMode -ne 'success') {
        Remove-Item -LiteralPath (Join-Path $global:SkillInstallerFixtureRoot 'fixture/scripts/required.ps1')
        [IO.File]::WriteAllText((Join-Path $global:SkillInstallerFixtureRoot 'fixture/partial.tmp'), 'failed candidate data')
    }
    $global:LASTEXITCODE = if ($global:SkillInstallerMode -eq 'partial-failure') { 1 } else { 0 }
}
function Run-Install { param([switch]$SkipInstall, [switch]$Preview) & (Join-Path $global:SkillInstallerFixtureRoot 'install-and-register-skill.ps1') -Skill fixture -Repo fixture/repo -RawSkillUrl $RawUrl -LocalFolder fixture -SkipInstall:$SkipInstall -Preview:$Preview }

$Before = [IO.File]::ReadAllText($SkillFile)
Run-Install
Assert-Equal ([IO.File]::ReadAllText($SkillFile)) $Before 'Reinstall must restore the configured local trigger'
$AfterConfig = [IO.File]::ReadAllText($ConfigPath) | ConvertFrom-Json
Assert-Equal $AfterConfig.auditTag 'preserve-root-metadata' 'Root configuration metadata preserved'
Assert-Equal @($AfterConfig.skills | Where-Object name -eq fixture)[0].notes 'KEEP EXISTING METADATA' 'Entry metadata preserved'
$StatePath = Join-Path $CaseRoot 'external/skill-package-state/fixture.json'
Assert-Equal (Test-Path -LiteralPath $StatePath) $true 'Validated install has ownership state'
$PolicyPath = Join-Path $CaseRoot 'external/skill-client-policy-state/fixture.json'
$YamlPath = Join-Path $Fixture 'fixture/agents/openai.yaml'
Assert-Equal (Test-Path -LiteralPath $PolicyPath) $true 'Verified reinstall records policy receipt'
Assert-Equal (([IO.File]::ReadAllText($YamlPath)).Contains('allow_implicit_invocation: false')) $true 'Verified reinstall restores explicit-only invocation'
Write-Output 'PASS: reinstall backs up first, replays routing and client policy, and preserves registration metadata'

$CallsBefore = $global:SkillInstallerCalls
Run-Install -SkipInstall
Assert-Equal $global:SkillInstallerCalls $CallsBefore 'SkipInstall does not invoke installer'
Assert-Equal ([IO.File]::ReadAllText($SkillFile)) $Before 'Already overridden entry accepted by SkipInstall'
Write-Output 'PASS: SkipInstall accepts a correctly overridden existing package'

foreach ($Mode in @('partial-failure', 'missing-resource')) {
    $global:SkillInstallerMode = $Mode
    $BeforeConfig = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath))
    $BeforeState = [Convert]::ToBase64String([IO.File]::ReadAllBytes($StatePath))
    $BeforePolicy = [Convert]::ToBase64String([IO.File]::ReadAllBytes($PolicyPath))
    $BeforeYaml = [Convert]::ToBase64String([IO.File]::ReadAllBytes($YamlPath))
    Assert-Throws { Run-Install } '失败'
    Assert-Equal ([IO.File]::ReadAllText($SkillFile)) $Before 'Failed install restores local routing'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $Fixture 'fixture/scripts/required.ps1')) $true 'Failed install restores resources'
    Assert-Equal (Test-Path -LiteralPath (Join-Path $Fixture 'fixture/partial.tmp')) $false 'Failed candidate leaves no new file in active runtime'
    Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath))) $BeforeConfig 'Failed install preserves config bytes'
    Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($StatePath))) $BeforeState 'Failed install preserves ownership bytes'
    Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($PolicyPath))) $BeforePolicy 'Failed install restores policy receipt'
    Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($YamlPath))) $BeforeYaml 'Failed install restores metadata bytes'
    Write-Output "PASS: $Mode cannot claim success and restores files, registry, ownership and policy state"
}
$global:SkillInstallerMode = 'success'
$CallsBefore = $global:SkillInstallerCalls
foreach ($Protected in @('protected', 'git-protected')) {
    Assert-Throws { & (Join-Path $Fixture 'install-and-register-skill.ps1') -Skill $Protected -Repo fixture/repo -RawSkillUrl $RawUrl } 'Git/人工'
}
Assert-Equal $global:SkillInstallerCalls $CallsBefore 'Protected entries blocked before npx'
Write-Output 'PASS: existing manual and Git policies cannot be replaced by a generic reinstall'

$HttpBefore = $global:SkillInstallerHttpCalls
$BeforeConfig = [Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath))
Run-Install -Preview | Out-Null
Assert-Equal $global:SkillInstallerCalls $CallsBefore 'Preview does not reinstall'
Assert-Equal $global:SkillInstallerHttpCalls $HttpBefore 'Explicit-source preview does not download the package'
Assert-Equal ([Convert]::ToBase64String([IO.File]::ReadAllBytes($ConfigPath))) $BeforeConfig 'Preview preserves config bytes'
Write-Output 'PASS: preview performs no install or registration writes'

$OverridePath = Join-Path $Fixture 'local-routing-overrides.json'
[IO.File]::WriteAllText($OverridePath, '{"overrides":[{"skill":"fixture","localFolder":"fixture","description":"LOCAL TRIGGER","bodyPatches":[{"find":"missing upstream anchor","replace":"local patch"}]}]}', $Utf8)
Assert-Throws { Run-Install } 'patch-stale'
Assert-Equal $global:SkillInstallerCalls $CallsBefore 'Stale body patch blocks before installation'
Assert-Equal ([IO.File]::ReadAllText($SkillFile)) $Before 'Stale body patch preserves local entry'
Write-Output 'PASS: stale body patches block reinstall before any runtime mutation'

$FreshRoot = Join-Path $CaseRoot 'fresh/skills'
$null = New-Item -ItemType Directory -Path $FreshRoot -Force
foreach ($Name in @('manage-skills.ps1', 'skill-package-state.ps1', 'skill-client-policy.ps1', 'skill-upstream-watch.ps1', 'install-and-register-skill.ps1')) {
    Copy-Item -LiteralPath (Join-Path $Candidate $Name) -Destination (Join-Path $FreshRoot $Name)
}
[IO.File]::WriteAllText((Join-Path $FreshRoot 'skills-sources.json'), '{"skills":[]}', $Utf8)
$global:SkillInstallerFixtureRoot = $FreshRoot
$global:SkillInstallerNeedsBackup = $false
Run-Install
$FreshConfig = [IO.File]::ReadAllText((Join-Path $FreshRoot 'skills-sources.json')) | ConvertFrom-Json
Assert-Equal @($FreshConfig.skills).Count 1 'Fresh install registers exactly one skill'
Assert-Equal $FreshConfig.skills[0].name 'fixture' 'Fresh installation retains the requested identity'
Assert-Equal ([IO.File]::ReadAllText((Join-Path $FreshRoot 'fixture/SKILL.md'))) $global:SkillInstallerUpstream 'Unrouted new install retains upstream entry'
Write-Output 'PASS: first installation still installs and registers a complete new package'
Write-Output '8 installer integration scenarios passed.'
