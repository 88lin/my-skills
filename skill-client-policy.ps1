# Persistent Codex policy overlay. Receipts live outside the active skill tree.
function Get-CodexSkillPolicy {
    param([object]$Entry)
    $Override = Get-RoutingOverride -Entry $Entry
    if ($null -eq $Override -or $Override.PSObject.Properties.Name -notcontains 'codexPolicy' -or $null -eq $Override.codexPolicy) { return $null }
    $Policy = $Override.codexPolicy
    if (@($Policy.PSObject.Properties.Name).Count -ne 1 -or $Policy.PSObject.Properties.Name -notcontains 'allow_implicit_invocation' -or $Policy.allow_implicit_invocation -isnot [bool]) {
        throw 'codexPolicy supports only a boolean allow_implicit_invocation.'
    }
    return $Policy
}

function Merge-CodexPolicyYaml {
    param([AllowEmptyString()][string]$Text, [object]$Policy)
    if ($null -eq $Policy) { return $Text }
    $Text = Get-NormalizedText -Text $Text
    if ($Text -match "`t" -or $Text -match '(?m)^(---|\.\.\.|%)') { throw 'Unsupported openai.yaml layout; review instead of overwriting it.' }
    $Value = if ($Policy.allow_implicit_invocation) { 'true' } else { 'false' }
    if ($Text -match '(?m)^["'']policy["'']\s*:') { throw 'Quoted policy mappings require review.' }
    $Headers = @([regex]::Matches($Text, '(?m)^policy\s*:[^\n]*'))
    if ($Headers.Count -gt 1) { throw 'Duplicate policy mappings in openai.yaml.' }
    if ($Headers.Count -eq 0) {
        return ($Text.TrimEnd("`n") + $(if ($Text.Length) { "`n`n" } else { '' }) + "policy:`n  allow_implicit_invocation: $Value`n")
    }
    if ($Headers[0].Value -notmatch '^policy:\s*(?:#.*)?$') { throw 'Only a block-style policy mapping can be merged safely.' }
    $Start = $Headers[0].Index
    $Tail = $Text.Substring($Start)
    $EndMatch = [regex]::Match($Tail.Substring($Headers[0].Length), '(?m)^[^\s#]')
    $Length = if ($EndMatch.Success) { $Headers[0].Length + $EndMatch.Index } else { $Tail.Length }
    $Block = $Tail.Substring(0, $Length)
    $Fields = @([regex]::Matches($Block, '(?m)^\s+allow_implicit_invocation\s*:[^\n]*'))
    if ($Fields.Count -gt 1) { throw 'Duplicate allow_implicit_invocation fields.' }
    if ($Fields.Count -eq 1) {
        $Field = $Fields[0]
        if ($Field.Value -notmatch '^  allow_implicit_invocation: *(true|false)( *#.*)?$') { throw 'Unsupported policy value or indentation; preserving openai.yaml.' }
        $Comment = $Matches[2]
        $Block = $Block.Remove($Field.Index, $Field.Length).Insert($Field.Index, "  allow_implicit_invocation: $Value$Comment")
    }
    else {
        if ($Block -match '(?m)^\s*(?:["'']allow_implicit_invocation["'']|<<)\s*:') { throw 'Quoted/merged policy keys require review.' }
        $Insert = $Block.IndexOf("`n")
        if ($Insert -lt 0) { $Block += "`n  allow_implicit_invocation: $Value`n" }
        else { $Block = $Block.Insert($Insert + 1, "  allow_implicit_invocation: $Value`n") }
    }
    return $Text.Remove($Start, $Length).Insert($Start, $Block)
}

function Get-CodexPolicyReceiptPath {
    param([object]$Entry)
    $null = Get-SafeSkillFilePath -Entry $Entry -Relative 'agents/openai.yaml'
    return (Join-Path (Join-Path (Split-Path -Parent $SkillsRoot) 'external\skill-client-policy-state') ($Entry.localFolder + '.json'))
}

function Read-CodexPolicyReceipt {
    param([object]$Entry)
    $Path = Get-CodexPolicyReceiptPath -Entry $Entry
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $Receipt = Read-JsonFileUtf8 -Path $Path
    if ($Receipt.schemaVersion -ne 1 -or $Receipt.sourceIdentity -ne (Get-SkillPackageIdentity -Entry $Entry) -or $Receipt.generatedSha256 -notmatch '^[0-9a-f]{64}$') { throw "Invalid Codex policy receipt: $Path" }
    return $Receipt
}

function Test-DirectGitSkill {
    param([object]$Entry)
    return ($Entry.type -eq 'git' -and [IO.Path]::GetFullPath((Get-GitRepositoryPath -Entry $Entry)).TrimEnd('\', '/') -ieq [IO.Path]::GetFullPath((Get-LocalSkillPath -Entry $Entry)).TrimEnd('\', '/'))
}

function Get-GitHeadPolicyBase {
    param([object]$Entry)
    $RepoPath = Get-GitRepositoryPath -Entry $Entry
    $Tree = Invoke-Git -Path $RepoPath -Arguments @('ls-tree', 'HEAD', '--', 'agents/openai.yaml')
    if ($Tree.ExitCode -ne 0) { throw $Tree.Output }
    if ([string]::IsNullOrWhiteSpace($Tree.Output)) { return [pscustomobject]@{ Exists = $false; Text = '' } }
    if ($Tree.Output -notmatch '^100(?:644|755) blob [0-9a-f]{40}\s+agents/openai.yaml$') { throw 'Client policy source is not an ordinary tracked file.' }
    $Blob = Invoke-Git -Path $RepoPath -Arguments @('show', 'HEAD:agents/openai.yaml')
    if ($Blob.ExitCode -ne 0) { throw $Blob.Output }
    return [pscustomobject]@{ Exists = $true; Text = (Get-NormalizedText -Text $Blob.StdOut) }
}

function Get-CodexPolicySourceBase {
    param([object]$Entry, [switch]$Offline)
    if (Test-DirectGitSkill -Entry $Entry) { return (Get-GitHeadPolicyBase -Entry $Entry) }
    if ($Entry.type -eq 'skills-cli' -and -not $Offline) {
        $Snapshot = Get-SkillCliSourceSnapshot -Entry $Entry
        return [pscustomobject]@{ Exists = $Snapshot.Files.ContainsKey('agents/openai.yaml'); Text = [string]$Snapshot.OpenAiYaml }
    }
    if ($Entry.type -eq 'git') {
        foreach ($Mapping in @(Get-SyncSkillDirectoryMappings -Entry $Entry)) {
            $Dest = $Mapping.Destination.Replace('\', '/').TrimEnd('/')
            $Relative = if ($Dest -eq '.') { 'agents/openai.yaml' } elseif ($Dest -eq 'agents') { 'openai.yaml' } else { $null }
            if ($null -ne $Relative) {
                $Source = Join-Path (Join-Path (Get-GitRepositoryPath -Entry $Entry) $Mapping.Source) $Relative
                if (Test-Path -LiteralPath $Source -PathType Leaf) { return [pscustomobject]@{ Exists = $true; Text = (Get-FileText -Path $Source) } }
            }
        }
        foreach ($Mapping in @(Get-SyncSkillExtraFileMappings -Entry $Entry)) {
            if ($Mapping.Destination.Replace('\', '/') -eq 'agents/openai.yaml') {
                $Source = Join-Path (Get-GitRepositoryPath -Entry $Entry) $Mapping.Source
                if (Test-Path -LiteralPath $Source -PathType Leaf) { return [pscustomobject]@{ Exists = $true; Text = (Get-FileText -Path $Source) } }
            }
        }
        return [pscustomobject]@{ Exists = $false; Text = '' }
    }
    $Path = Get-SafeSkillFilePath -Entry $Entry -Relative 'agents/openai.yaml'
    $Receipt = Read-CodexPolicyReceipt -Entry $Entry
    if ($null -ne $Receipt -and (Get-FileHashValue -Path $Path) -eq $Receipt.generatedSha256) {
        return [pscustomobject]@{ Exists = $Receipt.baseExists; Text = [string]$Receipt.baseText }
    }
    return [pscustomobject]@{ Exists = (Test-Path -LiteralPath $Path -PathType Leaf); Text = [string](Get-FileText -Path $Path) }
}

function Test-CodexSkillPolicy {
    param([object]$Entry)
    $Policy = Get-CodexSkillPolicy -Entry $Entry
    if ($null -eq $Policy) { return ($null -eq (Read-CodexPolicyReceipt -Entry $Entry)) }
    $Base = Get-CodexPolicySourceBase -Entry $Entry
    $Expected = Merge-CodexPolicyYaml -Text $Base.Text -Policy $Policy
    $Path = Get-SafeSkillFilePath -Entry $Entry -Relative 'agents/openai.yaml'
    return ((Test-Path -LiteralPath $Path -PathType Leaf) -and (Get-TextHash -Text (Get-FileText -Path $Path)) -eq (Get-TextHash -Text $Expected))
}

function Apply-CodexSkillPolicy {
    param([object]$Entry)
    $Policy = Get-CodexSkillPolicy -Entry $Entry
    $Receipt = Read-CodexPolicyReceipt -Entry $Entry
    if ($null -eq $Policy -and $null -eq $Receipt) { return $false }
    $Path = Get-SafeSkillFilePath -Entry $Entry -Relative 'agents/openai.yaml'
    $ReceiptPath = Get-CodexPolicyReceiptPath -Entry $Entry
    $Local = [string](Get-FileText -Path $Path)
    if ($null -eq $Policy) {
        if ((Get-FileHashValue -Path $Path) -ne $Receipt.generatedSha256) { throw 'Client policy changed locally; refusing automatic removal.' }
        if (Test-DirectGitSkill -Entry $Entry) {
            $Base = Get-GitHeadPolicyBase -Entry $Entry
            if ($Base.Exists) {
                $Restore = Invoke-Git -Path (Get-GitRepositoryPath -Entry $Entry) -Arguments @('restore', '--source=HEAD', '--worktree', '--', 'agents/openai.yaml')
                if ($Restore.ExitCode -ne 0) { throw $Restore.Output }
            }
            else { Remove-Item -LiteralPath $Path -Force }
        }
        elseif ($Receipt.baseExists) { Write-TextFile -Path $Path -Text ([string]$Receipt.baseText) }
        else { Remove-Item -LiteralPath $Path -Force }
        Remove-Item -LiteralPath $ReceiptPath -Force
        return $true
    }
    $Base = Get-CodexPolicySourceBase -Entry $Entry -Offline
    $Expected = Merge-CodexPolicyYaml -Text $Base.Text -Policy $Policy
    if (Test-DirectGitSkill -Entry $Entry) {
        $IsBase = (Get-TextHash -Text $Local) -eq (Get-TextHash -Text $Base.Text)
        $IsExpected = (Get-TextHash -Text $Local) -eq (Get-TextHash -Text $Expected)
        $IsRecorded = $null -ne $Receipt -and (Get-FileHashValue -Path $Path) -eq $Receipt.generatedSha256
        if (-not ($IsBase -or $IsExpected -or $IsRecorded)) { throw 'Unrecognized local openai.yaml changes; preserving them.' }
    }
    $Changed = (Get-TextHash -Text $Local) -ne (Get-TextHash -Text $Expected) -or -not (Test-Path -LiteralPath $Path)
    if ($Changed) {
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
        Write-TextFile -Path $Path -Text $Expected
    }
    $Hash = Get-FileHashValue -Path $Path
    if ($null -eq $Receipt -or $Receipt.generatedSha256 -ne $Hash -or $Receipt.baseText -cne $Base.Text -or $Receipt.baseExists -ne $Base.Exists) {
        $State = [ordered]@{ schemaVersion = 1; sourceIdentity = (Get-SkillPackageIdentity -Entry $Entry); skill = $Entry.name; recordedAt = (Get-Date).ToString('o'); baseExists = $Base.Exists; baseText = $Base.Text; generatedSha256 = $Hash; policy = $Policy }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $ReceiptPath) -Force
        Write-TextFile -Path $ReceiptPath -Text ($State | ConvertTo-Json -Depth 10)
    }
    return $Changed
}

function Get-SkillCliExpectedFiles {
    param([object]$Entry, [object]$Snapshot)
    $Files = @{}
    foreach ($Key in $Snapshot.Files.Keys) { $Files[$Key] = $Snapshot.Files[$Key] }
    $Policy = Get-CodexSkillPolicy -Entry $Entry
    if ($null -ne $Policy) {
        $Text = Merge-CodexPolicyYaml -Text ([string]$Snapshot.OpenAiYaml) -Policy $Policy
        $Files['agents/openai.yaml'] = Get-PackageBytesHash -Bytes ([Text.Encoding]::UTF8.GetBytes($Text)) -RelativePath 'agents/openai.yaml'
    }
    return $Files
}

function Get-GeneratedPolicyGitChanges {
    param([object]$Entry)
    $RepoPath = Get-GitRepositoryPath -Entry $Entry
    $Dirty = Invoke-Git -Path $RepoPath -Arguments @('status', '--porcelain', '--untracked-files=all')
    if ($Dirty.ExitCode -ne 0) { throw $Dirty.Output }
    if ([string]::IsNullOrWhiteSpace($Dirty.Output)) { return $false }
    if (-not (Test-DirectGitSkill -Entry $Entry) -or $null -eq (Get-CodexSkillPolicy -Entry $Entry)) { throw '检测到本地 Git 改动，已跳过更新' }
    $Staged = Invoke-Git -Path $RepoPath -Arguments @('diff', '--cached', '--name-only')
    if ($Staged.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($Staged.Output)) { throw 'Staged Git changes must be reviewed before updating.' }
    $Lines = @($Dirty.Output -split "`n" | Where-Object { $_.Trim() -ne '' })
    if ($Lines.Count -ne 1 -or $Lines[0].Trim() -notin @('M agents/openai.yaml', '?? agents/openai.yaml') -or -not (Test-CodexSkillPolicy -Entry $Entry)) {
        throw '检测到本地 Git 改动，只有与 HEAD + 本地策略完全一致的 openai.yaml 可自动重放'
    }
    return $true
}

function Suspend-GeneratedPolicyForPull {
    param([object]$Entry, [bool]$HasGeneratedChange)
    if (-not $HasGeneratedChange) { return }
    # Called only after a complete update backup. Do not touch the index or any other file.
    $Path = Get-SafeSkillFilePath -Entry $Entry -Relative 'agents/openai.yaml'
    if (-not (Get-GeneratedPolicyGitChanges -Entry $Entry)) { throw 'Git policy changed while preparing update.' }
    $Base = Get-GitHeadPolicyBase -Entry $Entry
    if ($Base.Exists) {
        $Restore = Invoke-Git -Path (Get-GitRepositoryPath -Entry $Entry) -Arguments @('restore', '--source=HEAD', '--worktree', '--', 'agents/openai.yaml')
        if ($Restore.ExitCode -ne 0) { throw $Restore.Output }
    }
    else { Remove-Item -LiteralPath $Path -Force }
}

function Sync-CodexRoutingInstructions {
    param([string]$Path, [switch]$CheckOnly)
    $Config = Read-JsonFileUtf8 -Path $OverridesPath
    if ($Config.PSObject.Properties.Name -notcontains 'codexGlobalRouting' -or [string]::IsNullOrWhiteSpace($Config.codexGlobalRouting)) { throw 'codexGlobalRouting is not configured.' }
    $Start = '<!-- LOCAL SKILL ROUTING START -->'; $End = '<!-- LOCAL SKILL ROUTING END -->'
    $Text = if (Test-Path -LiteralPath $Path) { [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) } else { '' }
    if (@([regex]::Matches($Text, [regex]::Escape($Start))).Count -gt 1 -or (@([regex]::Matches($Text, [regex]::Escape($Start))).Count -ne @([regex]::Matches($Text, [regex]::Escape($End))).Count)) { throw 'Ambiguous managed block in global AGENTS.md.' }
    $Block = $Start + "`n" + [string]$Config.codexGlobalRouting + "`n" + $End
    $Pattern = '(?ms)^<!-- LOCAL SKILL ROUTING START -->.*?^<!-- LOCAL SKILL ROUTING END -->'
    $Expected = if ([regex]::IsMatch($Text, $Pattern)) { [regex]::Replace($Text, $Pattern, [Text.RegularExpressions.MatchEvaluator]{ param($Match) $Block }) } else { $Text + $(if ($Text -and -not $Text.EndsWith("`n")) { "`n" } else { '' }) + $Block + "`n" }
    if ($CheckOnly) { return ($Text -ceq $Expected) }
    if ($Text -cne $Expected) { Write-TextFile -Path $Path -Text $Expected; return $true }
    return $false
}
