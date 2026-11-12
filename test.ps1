#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Test suite for the PowerShell implementation: build.ps1 and install.ps1.

.DESCRIPTION
    Each platform tests its own native implementation. This suite covers the
    PowerShell scripts with native commands and runs on Windows; test.sh covers
    build.sh and install.sh and runs on Linux and macOS. Neither runs the other's
    shell.

    The two implementations must still agree byte for byte. That is checked
    across machines, not on one: -Manifest writes the name of every test and a
    SHA-256 of every generated file, test.sh writes the same, and CI diffs the
    two. Keep the test names and the manifest trees identical in both suites.

    git is optional; the hook tests report as skipped without it, never as
    passed.

.PARAMETER Manifest
    Also write the parity manifest to this file.

.PARAMETER Detailed
    Also print each failing command's output.
#>
[CmdletBinding()]
param(
    [string]$Manifest,
    [switch]$Detailed
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot
$Build = Join-Path $RepoRoot 'build.ps1'
$Install = Join-Path $RepoRoot 'install.ps1'
$StandardsDir = Join-Path $RepoRoot 'standards'
$Work = Join-Path ([System.IO.Path]::GetTempPath()) "agent-framework-test-$PID"

if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory -Path $Work -Force | Out-Null

# Resolved now, against the caller's directory: a bare file name has no parent
# to create, and the hook tests change location before the manifest is written.
if ($Manifest) {
    $Manifest = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Manifest)
}

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0
$script:FailedNames = [System.Collections.Generic.List[string]]::new()
# Every test name is recorded, whatever its outcome, so the manifest can show
# that both suites ran the same tests.
$script:TestNames = [System.Collections.Generic.List[string]]::new()

# --- Harness --------------------------------------------------------------

function Ok([string]$Name) {
    $script:Pass++; $script:TestNames.Add($Name)
    Write-Host "  ok    $Name"
}

function Bad([string]$Name, [string]$Detail = '') {
    $script:Fail++; $script:TestNames.Add($Name); $script:FailedNames.Add($Name)
    Write-Host "  FAIL  $Name" -ForegroundColor Red
    if ($Detail) { Write-Host "        $Detail" }
}

function Skip([string]$Name, [string]$Why) {
    $script:Skip++; $script:TestNames.Add($Name)
    Write-Host "  skip  $Name ($Why)" -ForegroundColor DarkGray
}

function Section([string]$Title) { Write-Host ''; Write-Host $Title }

function Assert-Eq([string]$Name, $Actual, $Expected) {
    if ("$Actual" -ceq "$Expected") { Ok $Name }
    else { Bad $Name "expected [$Expected], got [$Actual]" }
}

# Runs a script in this process, which costs no interpreter start-up. Returns
# its exit code: what it passed to exit, 1 if it threw, otherwise 0.
function Invoke-Script([string]$Script, [hashtable]$Params) {
    $global:LASTEXITCODE = 0
    try {
        if ($Detailed) { & $Script @Params }
        else { & $Script @Params *> $null }
        return [int]$global:LASTEXITCODE
    }
    catch {
        if ($Detailed) { Write-Host "        | $($_.Exception.Message)" }
        return 1
    }
}

# As Invoke-Script, but returns what the script wrote, for tests that read it.
function Invoke-ScriptOutput([string]$Script, [hashtable]$Params) {
    $global:LASTEXITCODE = 0
    try { return (& $Script @Params *>&1 | Out-String) }
    catch { return '' }
}

# Runs a script in a child process. Used where a script rejects its arguments:
# a missing mandatory parameter prompts in-process, and the rejection messages
# go straight to the console's error stream.
function Invoke-Child([string]$Script, [string[]]$Arguments) {
    & pwsh -NoProfile -NonInteractive -File $Script @Arguments *> $null
    return [int]$LASTEXITCODE
}

function Assert-Code([string]$Name, [int]$Want, [int]$Got) {
    if ($Got -eq $Want) { Ok $Name } else { Bad $Name "expected exit $Want, got $Got" }
}

# The sh implementation exits 2 on a rejected argument; PowerShell reports a
# binding error or a throw as 1. What both must do is refuse.
function Assert-Refused([string]$Name, [int]$Got) {
    if ($Got -ne 0) { Ok $Name } else { Bad $Name 'expected a non-zero exit, got 0' }
}

function Invoke-Build([hashtable]$Params) { [void](Invoke-Script $Build $Params) }
function Invoke-Install([hashtable]$Params) { [void](Invoke-Script $Install $Params) }

function Get-Files([string]$Dir) {
    if (-not (Test-Path $Dir)) { return @() }
    return @(Get-ChildItem $Dir -Recurse -File -Force)
}

function Get-FileCount([string]$Dir) { return @(Get-Files $Dir).Count }

function Get-OrdinalSorted([string[]]$Items) {
    $copy = [string[]]@($Items)
    [Array]::Sort($copy, [System.StringComparer]::Ordinal)
    return $copy
}

function Get-RootEntries([string]$Dir) {
    $names = [string[]]@(Get-ChildItem $Dir -Force | ForEach-Object { $_.Name })
    return (Get-OrdinalSorted $names) -join ' '
}

function Get-Lines([string]$Path) { return [System.IO.File]::ReadAllLines($Path) }

# LF endings and no BOM, so a fixture is the same bytes test.sh writes.
function Set-Text([string]$Path, [string]$Text) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($false)))
}

function New-Dir([string]$Path) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

function Get-FrontmatterValue([string]$Path, [string]$Key) {
    foreach ($line in (Get-Lines $Path)) {
        if ($line.StartsWith("${Key}: ")) { return $line.Substring($Key.Length + 2) }
    }
    return ''
}

function Get-Links([string]$Path) {
    $found = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($Path), '\[\[([a-z0-9-]*)\]\]')) {
        [void]$found.Add($m.Groups[1].Value)
    }
    return @($found)
}

$Sources = @(Get-ChildItem $StandardsDir -Filter '*.md' | Sort-Object Name)
$Standards = @($Sources | Where-Object { -not $_.Name.StartsWith('_') })

try {

Write-Host 'Agent framework test suite (PowerShell)'
Write-Host "Repo: $RepoRoot"

# --- 1. Scripts parse -----------------------------------------------------

Section '1. Scripts parse'

foreach ($pair in @(@('the build script parses', $Build), @('the install script parses', $Install))) {
    $tokens = $null; $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($pair[1], [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) { Ok $pair[0] } else { Bad $pair[0] $errors[0].Message }
}

# --- 2. Source validation -------------------------------------------------

Section '2. Source validation'

# The trigger table is derived from USE FOR clauses. Without one, a standard
# silently falls back to its first sentence.
$missing = @($Standards | Where-Object { (Get-FrontmatterValue $_.FullName 'description') -notmatch 'USE FOR' } |
    ForEach-Object { $_.BaseName })
Assert-Eq 'every standard declares at least one USE FOR' ($missing -join ' ') ''

# name must equal the filename, or the generated skill name is wrong.
$mismatch = @($Sources | Where-Object { (Get-FrontmatterValue $_.FullName 'name') -cne $_.BaseName } |
    ForEach-Object { $_.BaseName })
Assert-Eq 'every name matches its filename' ($mismatch -join ' ') ''

# stack must be present and non-empty; an empty value would silently mean "any".
$noStack = @($Sources | Where-Object { -not (Get-FrontmatterValue $_.FullName 'stack') } |
    ForEach-Object { $_.BaseName })
Assert-Eq 'every standard declares a stack' ($noStack -join ' ') ''

# [[links]] are how standards cross-reference each other. A rename that leaves a
# dangling reference is exactly the drift this suite exists to catch.
$badRefs = foreach ($s in $Sources) {
    foreach ($r in (Get-Links $s.FullName)) {
        if (-not (Test-Path (Join-Path $StandardsDir "$r.md"))) { "$($s.BaseName)->$r" }
    }
}
Assert-Eq 'every [[link]] names an existing standard' (@($badRefs) -join ' ') ''

# A universal standard linking a stack-scoped one would dangle in any install
# whose stack set excludes the target.
$crossRefs = foreach ($s in $Sources) {
    if ((Get-FrontmatterValue $s.FullName 'stack') -ne 'any') { continue }
    foreach ($r in (Get-Links $s.FullName)) {
        $target = Join-Path $StandardsDir "$r.md"
        if (-not (Test-Path $target)) { continue }
        if ((Get-FrontmatterValue $target 'stack') -ne 'any') { "$($s.BaseName)->$r" }
    }
}
Assert-Eq 'no universal standard links a stack-scoped one' (@($crossRefs) -join ' ') ''

# The lite build inlines each standard as its checklist, so a standard without
# one would silently vanish from a lite install.
$noChecklist = foreach ($s in $Standards) {
    $inChecklist = $false; $items = 0
    foreach ($line in (Get-Lines $s.FullName)) {
        if ($line -match '^## Checklist') { $inChecklist = $true; continue }
        if ($inChecklist -and $line -match '^## ') { break }
        if ($inChecklist -and $line.StartsWith('- [ ] ')) { $items++ }
    }
    if ($items -eq 0) { $s.BaseName }
}
Assert-Eq 'every standard has a checklist (lite depends on it)' (@($noChecklist) -join ' ') ''

# --- 3. Frontmatter validation is enforced --------------------------------

Section '3. Frontmatter validation is enforced'

$BadSrc = Join-Path $Work 'badsrc'
New-Dir (Join-Path $BadSrc 'standards')
Copy-Item $Build $BadSrc
Copy-Item (Join-Path $StandardsDir '_core.md') (Join-Path $BadSrc 'standards')
$BadBuild = Join-Path $BadSrc 'build.ps1'
$BadStandard = Join-Path $BadSrc 'standards/code-quality.md'
$goodLines = Get-Lines (Join-Path $StandardsDir 'code-quality.md')

# name that disagrees with the filename
Set-Text $BadStandard ((($goodLines -replace '^name: code-quality$', 'name: wrong-name') -join "`n") + "`n")
Assert-Code 'build rejects a name/filename mismatch' 1 `
    (Invoke-Script $BadBuild @{ OutputRoot = (Join-Path $Work 'badout') })

# missing description
Set-Text $BadStandard ((@($goodLines | Where-Object { $_ -notmatch '^description:' }) -join "`n") + "`n")
Assert-Code 'build rejects a missing description' 1 `
    (Invoke-Script $BadBuild @{ OutputRoot = (Join-Path $Work 'badout2') })

# missing opening delimiter
Set-Text $BadStandard "name: code-quality`n"
Assert-Code 'build rejects absent frontmatter' 1 `
    (Invoke-Script $BadBuild @{ OutputRoot = (Join-Path $Work 'badout3') })

# --- 4. Argument validation ----------------------------------------------

Section '4. Argument validation'

Assert-Refused 'build rejects an unknown adapter' `
    (Invoke-Script $Build @{ OutputRoot = (Join-Path $Work 'x'); Adapters = 'bogus' })
Assert-Refused 'build requires --out' (Invoke-Child $Build @())
Assert-Refused 'install rejects an unknown option' `
    (Invoke-Child $Install @('-Target', (Join-Path $Work 'x'), '-Bogus'))
Assert-Refused 'install rejects target and --user together' `
    (Invoke-Child $Install @('-Target', (Join-Path $Work 'x'), '-User'))
Assert-Refused 'install refuses the framework repo as target' `
    (Invoke-Child $Install @('-Target', $RepoRoot))

# --- 5. Default output shape ---------------------------------------------

Section '5. Default output shape'

# Counts are derived from standards/, never hardcoded. A hardcoded count goes stale
# the moment a standard is added, which is how this suite last broke.
function Get-StackNames([string]$Stack) {
    return @($Sources | Where-Object { (Get-FrontmatterValue $_.FullName 'stack') -eq $Stack } |
        ForEach-Object { $_.BaseName })
}
$SrcStandards = $Standards.Count
$DotnetNames = @(Get-StackNames 'dotnet')
$PythonNames = @(Get-StackNames 'python')
$GodotNames = @(Get-StackNames 'godot')
$UnrealNames = @(Get-StackNames 'unreal')
$CppNames = @(Get-StackNames 'c-cpp')
# Standards scoped to any named stack, i.e. excluded from a stacks=any build.
$SrcStacked = @($Sources | Where-Object { (Get-FrontmatterValue $_.FullName 'stack') -ne 'any' }).Count

function Get-SkillNames([string]$Root) {
    $dir = Join-Path $Root '.agents/skills'
    if (-not (Test-Path $dir)) { return @() }
    return @(Get-ChildItem $dir -Directory | ForEach-Object { $_.Name })
}

# How many skills in an install belong to the named set: grep -c over ls.
function Get-SkillCount([string]$Root, [string[]]$Names) {
    return @(Get-SkillNames $Root | Where-Object { $Names -contains $_ }).Count
}

$Def = Join-Path $Work 'def'
Invoke-Build @{ OutputRoot = $Def }
Assert-Eq 'default build root is AGENTS.md + .agents' (Get-RootEntries $Def) '.agents AGENTS.md'
# One SKILL.md per standard, plus AGENTS.md. _core is inlined, never a skill.
Assert-Eq 'default build emits AGENTS.md plus one skill per standard' (Get-FileCount $Def) ($SrcStandards + 1)
Assert-Eq 'every skill directory holds a SKILL.md' (@(Get-SkillNames $Def).Count) $SrcStandards

# The skills tree is the only copy. An install that also carried standards/ would
# be back to two copies of every standard, which is the thing this layout removes.
foreach ($unwanted in 'standards', '.claude', '.cursor', '.github', 'CLAUDE.md', 'GEMINI.md', 'CONVENTIONS.md') {
    if (Test-Path (Join-Path $Def $unwanted)) { Bad "default build omits $unwanted" }
    else { Ok "default build omits $unwanted" }
}

# Every skill must satisfy the Agent Skills spec: name matches its directory, and
# the description fits the 1024-character cap.
$specBad = 0
foreach ($name in (Get-SkillNames $Def)) {
    $file = Join-Path $Def ".agents/skills/$name/SKILL.md"
    if ((Get-FrontmatterValue $file 'name') -cne $name) { $specBad++ }
    $desc = Get-FrontmatterValue $file 'description'
    if (-not $desc -or $desc.Length -gt 1024) { $specBad++ }
}
Assert-Eq 'every skill has a spec-valid name and description' $specBad 0

# Frontmatter carries only spec fields. stack and globs drive this build; passing
# them through would put non-standard keys in front of every tool that reads them.
$leaks = 0
foreach ($name in (Get-SkillNames $Def)) {
    $delimiters = 0
    foreach ($line in (Get-Lines (Join-Path $Def ".agents/skills/$name/SKILL.md"))) {
        if ($line -eq '---') { $delimiters++; continue }
        if ($delimiters -eq 1 -and $line -match '^(stack|globs):') { $leaks++ }
    }
}
Assert-Eq 'skill frontmatter leaks no build-time keys' $leaks 0

# _core is inlined into AGENTS.md, and must never become a skill or a rule.
$Adapters = Join-Path $Work 'adapters'
Invoke-Build @{ OutputRoot = $Adapters; Adapters = 'all' }
if (Test-Path (Join-Path $Adapters '.agents/skills/_core')) { Bad '_core is not emitted as a skill' }
else { Ok '_core is not emitted as a skill' }

# The whole point of the adapters: discovery metadata their tool needs, pointing
# at the canonical file. A body long enough to be the standard itself is a
# regression back to duplicated text.
$pointerFiles = @(Get-ChildItem (Join-Path $Adapters '.claude/skills') -Recurse -File -Filter 'SKILL.md') +
    @(Get-ChildItem (Join-Path $Adapters '.github/instructions') -File -Filter '*.instructions.md')
$tooLong = @($pointerFiles | Where-Object { @(Get-Lines $_.FullName).Count -gt 15 })
if ($tooLong.Count -gt 0) { Bad 'adapter files are pointers, not copies' $tooLong[0].FullName }
else { Ok 'adapter files are pointers, not copies' }

function Get-MatchingFileCount([string]$Dir, [string]$Pattern) {
    return @(Get-ChildItem $Dir -Recurse -File -Filter 'SKILL.md' |
        Where-Object { [System.IO.File]::ReadAllText($_.FullName) -match $Pattern }).Count
}

function Get-MatchingLineCount([string]$Path, [string]$Pattern) {
    return @(Get-Lines $Path | Where-Object { $_ -cmatch $Pattern }).Count
}

Assert-Eq 'every claude stub points at the .agents/skills copy' `
    (Get-MatchingFileCount (Join-Path $Adapters '.claude/skills') '`\.agents/skills/[a-z-]*/SKILL\.md`') $SrcStandards

# --skills-path has to reach every generated reference, or a user install points
# at a project-relative path that does not exist there.
$UserPath = Join-Path $Work 'userpath'
Invoke-Build @{ OutputRoot = $UserPath; Adapters = 'claude'; SkillsPath = '~/.agents/skills' }
Assert-Eq '--skills-path rewrites the AGENTS.md table' `
    (Get-MatchingLineCount (Join-Path $UserPath 'AGENTS.md') '`~/\.agents/skills/[a-z-]*/SKILL\.md`') $SrcStandards
Assert-Eq '--skills-path rewrites the claude stubs' `
    (Get-MatchingFileCount (Join-Path $UserPath '.claude/skills') '`~/\.agents/skills/[a-z-]*/SKILL\.md`') $SrcStandards

# --- 6. Trigger table correctness ---------------------------------------

Section '6. Trigger table correctness'

# Regression: "DO NOT USE FOR" contains "USE FOR". Matching it first turned each
# standard's exclusions into reasons to load it.
$phrases = 'see technical-writing', 'see architecture-principles', 'see elimination-debugging',
    'see observability-standards', 'see performance-discipline', 'greenfield work'
$leak = 0
foreach ($line in (Get-Lines (Join-Path $Def 'AGENTS.md'))) {
    $fields = $line -split '\|'
    if ($fields.Count -lt 3) { continue }
    foreach ($phrase in $phrases) { if ($fields[2].Contains($phrase)) { $leak = 1 } }
}
Assert-Eq 'no exclusion text leaks into the Load when column' $leak 0

# _core is inlined into AGENTS.md rather than listed, so it has no row.
Assert-Eq 'trigger table has one row per standard' `
    (Get-MatchingLineCount (Join-Path $Def 'AGENTS.md') '^\| `') $SrcStandards

Assert-Eq 'AGENTS.md carries a standards version' `
    (Get-MatchingLineCount (Join-Path $Def 'AGENTS.md') 'Standards version: [0-9a-f]{8}') 1

# --- 7. Output hygiene ---------------------------------------------------

Section '7. Output hygiene'

$trailing = 0; $withCr = 0; $noEol = 0
foreach ($file in (Get-Files $Adapters)) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    if ($text -match ' \n') { $trailing++ }
    if ($text.Contains("`r")) { $withCr++ }
    if ($bytes.Length -eq 0 -or $bytes[$bytes.Length - 1] -ne 10) { $noEol++ }
}
Assert-Eq 'no generated file has trailing whitespace' $trailing 0
Assert-Eq 'no generated file contains CR' $withCr 0
Assert-Eq 'every generated file ends with a newline' $noEol 0

# --- 8. Stack filtering -------------------------------------------------

Section '8. Stack filtering'

$SAny = Join-Path $Work 's-any'
Invoke-Build @{ OutputRoot = $SAny; Stacks = 'any' }
Assert-Eq 'stacks=any excludes the dotnet standards' (Get-SkillCount $SAny $DotnetNames) 0

$SDotnet = Join-Path $Work 's-dotnet'
Invoke-Build @{ OutputRoot = $SDotnet; Stacks = 'dotnet' }
Assert-Eq 'stacks=dotnet includes the dotnet standards' (Get-SkillCount $SDotnet $DotnetNames) $DotnetNames.Count

# Every standard except the stack-scoped ones.
Assert-Eq 'stacks=any yields a shorter trigger table' `
    (Get-MatchingLineCount (Join-Path $SAny 'AGENTS.md') '^\| `') ($SrcStandards - $SrcStacked)

# Detection: a marker file under src/ must be found.
$ProjDotnet = Join-Path $Work 'proj-dotnet'
$ProjPython = Join-Path $Work 'proj-python'
Set-Text (Join-Path $ProjDotnet 'src/App/App.csproj') ''
Set-Text (Join-Path $ProjPython 'pyproject.toml') ''

Invoke-Install @{ Target = $ProjDotnet; Yes = $true }
Assert-Eq 'a .NET project receives the dotnet standards' (Get-SkillCount $ProjDotnet $DotnetNames) $DotnetNames.Count

Invoke-Install @{ Target = $ProjPython; Yes = $true }
Assert-Eq 'a Python project receives no dotnet standards' (Get-SkillCount $ProjPython $DotnetNames) 0
Assert-Eq 'a Python project receives the python standards' (Get-SkillCount $ProjPython $PythonNames) $PythonNames.Count

# A GDScript-only Godot project is godot alone; a C# one is godot and dotnet.
$ProjGodot = Join-Path $Work 'proj-godot'
$ProjGodotCs = Join-Path $Work 'proj-godot-cs'
Set-Text (Join-Path $ProjGodot 'game/project.godot') ''
Set-Text (Join-Path $ProjGodotCs 'game/project.godot') ''
Set-Text (Join-Path $ProjGodotCs 'game/Game.csproj') ''

Invoke-Install @{ Target = $ProjGodot; Yes = $true }
Assert-Eq 'a Godot project receives the godot standards' (Get-SkillCount $ProjGodot $GodotNames) $GodotNames.Count
Assert-Eq 'a GDScript Godot project receives no dotnet standards' (Get-SkillCount $ProjGodot $DotnetNames) 0

Invoke-Install @{ Target = $ProjGodotCs; Yes = $true }
Assert-Eq 'a C# Godot project receives the godot and dotnet standards' `
    (Get-SkillCount $ProjGodotCs ($GodotNames + $DotnetNames)) ($GodotNames.Count + $DotnetNames.Count)
Assert-Eq 'a .NET project receives no python standards' (Get-SkillCount $ProjDotnet $PythonNames) 0

# Unreal generates a .sln and .vcxproj files; neither makes the project .NET or
# general C++.
$ProjUnreal = Join-Path $Work 'proj-unreal'
Set-Text (Join-Path $ProjUnreal 'Game.uproject') ''
Set-Text (Join-Path $ProjUnreal 'Game.sln') ''
Set-Text (Join-Path $ProjUnreal 'Game.vcxproj') ''
Set-Text (Join-Path $ProjUnreal 'Intermediate/ProjectFiles/Game.csproj') ''

Invoke-Install @{ Target = $ProjUnreal; Yes = $true }
Assert-Eq 'an Unreal project receives the unreal standards' (Get-SkillCount $ProjUnreal $UnrealNames) $UnrealNames.Count
Assert-Eq 'an Unreal project ignores its generated project files' `
    (Get-SkillCount $ProjUnreal ($DotnetNames + $CppNames)) 0

# --- 9. Install behaviour ------------------------------------------------

Section '9. Install behaviour'

$Inst = Join-Path $Work 'inst'
New-Dir $Inst
Invoke-Install @{ Target = $Inst; Yes = $true }
Assert-Eq 'install root is AGENTS.md + .agents' (Get-RootEntries $Inst) '.agents AGENTS.md'

$before = Get-FileCount $Inst
if ((Invoke-ScriptOutput $Install @{ Target = $Inst; Yes = $true }) -match '(?m)^0 file\(s\) written') {
    Ok 're-install writes nothing'
}
else { Bad 're-install writes nothing' }
Assert-Eq 're-install changes no file count' (Get-FileCount $Inst) $before

if ((Invoke-ScriptOutput $Install @{ Target = $Inst; Yes = $true; Force = $true }) -match "(?m)^$before file\(s\) written") {
    Ok '--force rewrites every file'
}
else { Bad '--force rewrites every file' }

$InstClaude = Join-Path $Work 'inst-claude'
Invoke-Install @{ Target = $InstClaude; Yes = $true; Adapters = 'claude' }
Assert-Eq '--adapters claude adds .claude' (Test-Path (Join-Path $InstClaude '.claude/skills')) $true
Assert-Eq '--adapters claude keeps the .agents/skills copy' (Test-Path (Join-Path $InstClaude '.agents/skills')) $true
Assert-Eq '--adapters claude adds no other tool directory' `
    ((Test-Path (Join-Path $InstClaude '.cursor')) -or (Test-Path (Join-Path $InstClaude '.github'))) $false

# Cursor reads .agents/skills natively, so there is nothing left for an adapter
# to do and the name is no longer accepted.
Assert-Refused 'cursor is no longer an adapter' `
    (Invoke-Child $Install @('-Target', (Join-Path $Work 'inst-cursor'), '-Yes', '-Adapters', 'cursor'))

$InstCopilot = Join-Path $Work 'inst-copilot'
Invoke-Install @{ Target = $InstCopilot; Yes = $true; Adapters = 'copilot' }
Assert-Eq '--adapters copilot adds copilot-instructions.md' `
    (Test-Path (Join-Path $InstCopilot '.github/copilot-instructions.md')) $true

# The hooks adapter is tooling, not a pointer: a working no-hardcodes gate. Here
# git runs the hook itself, through a real commit, as it would for a user.
if (Get-Command git -ErrorAction SilentlyContinue) {
    $InstHooks = Join-Path $Work 'inst-hooks'
    Invoke-Install @{ Target = $InstHooks; Yes = $true; Adapters = 'hooks' }
    Assert-Eq '--adapters hooks writes the pre-commit gate' `
        (Test-Path (Join-Path $InstHooks '.githooks/pre-commit')) $true

    Push-Location $InstHooks
    try {
        & git init -q . *> $null
        & git config user.email test@example.com
        & git config user.name test
        & git config core.hooksPath .githooks

        Set-Text (Join-Path $InstHooks 'app.conf') "password = `"hunter2hunter2`"`n"
        & git add app.conf *> $null
        & git commit -q -m 'secret' *> $null
        if ($LASTEXITCODE -ne 0) { Ok 'the hook blocks a staged secret' }
        else { Bad 'the hook blocks a staged secret' 'the commit succeeded' }

        Set-Text (Join-Path $InstHooks 'app.conf') "password = `"<db-password>`"`n"
        & git add app.conf *> $null
        & git commit -q -m 'placeholder' *> $null
        Assert-Code 'the hook allows an obvious placeholder' 0 $LASTEXITCODE
    }
    finally { Pop-Location }
}
else {
    Skip 'hooks adapter gate' 'no git'
}

# --dry-run must not touch the destination.
$Dry = Join-Path $Work 'dry'
New-Dir $Dry
Invoke-Install @{ Target = $Dry; Yes = $true; DryRun = $true }
Assert-Eq '--dry-run writes nothing' (Get-FileCount $Dry) 0

# --- 10. Check mode -----------------------------------------------------

Section '10. Check mode'

Assert-Code '--check on an empty directory exits 2' 2 (Invoke-Child $Install @('-Target', $Dry, '-Check'))

Assert-Code '--check on a fresh install exits 0' 0 (Invoke-Script $Install @{ Target = $Inst; Check = $true })

$tamperTarget = Join-Path $Inst '.agents/skills/code-quality/SKILL.md'
[System.IO.File]::AppendAllText($tamperTarget, "`ntampered`n")
Assert-Code '--check detects a modified file' 1 (Invoke-Script $Install @{ Target = $Inst; Check = $true })

Remove-Item $tamperTarget -Force
Assert-Code '--check detects a missing file' 1 (Invoke-Script $Install @{ Target = $Inst; Check = $true })

Invoke-Install @{ Target = $Inst; Yes = $true; Force = $true }
Assert-Code '--check passes again after repair' 0 (Invoke-Script $Install @{ Target = $Inst; Check = $true })

# --- 11. Lite -------------------------------------------------------------

Section '11. Lite'

$Lite = Join-Path $Work 'lite'
Invoke-Build @{ OutputRoot = $Lite; Lite = $true }
Assert-Eq 'lite build root is AGENTS.md only' (Get-RootEntries $Lite) 'AGENTS.md'
Assert-Eq 'lite AGENTS.md is stamped with its mode' `
    (Get-MatchingLineCount (Join-Path $Lite 'AGENTS.md') 'mode: lite') 1
# Bare lite is the core rules and the universal standards: no stack is included
# unless it is named.
Assert-Eq 'lite AGENTS.md holds one section per universal standard' `
    (Get-MatchingLineCount (Join-Path $Lite 'AGENTS.md') '^### ') ($SrcStandards - $SrcStacked)
Assert-Refused 'lite refuses adapters' `
    (Invoke-Child $Build @('-OutputRoot', (Join-Path $Work 'lite-x'), '-Lite', '-Adapters', 'claude'))

$LiteStack = Join-Path $Work 'lite-stack'
Invoke-Build @{ OutputRoot = $LiteStack; Lite = $true; Stacks = 'dotnet,unreal' }
$dotnetPattern = '^### (' + (($DotnetNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
$givenPattern = '^### (' + ((($DotnetNames + $UnrealNames) | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
Assert-Eq 'lite includes the stacks it is given' `
    (Get-MatchingLineCount (Join-Path $LiteStack 'AGENTS.md') $givenPattern) ($DotnetNames.Count + $UnrealNames.Count)
Assert-Eq 'lite includes no stack it is not given' `
    (Get-MatchingLineCount (Join-Path $LiteStack 'AGENTS.md') '^### ') `
    ($SrcStandards - $SrcStacked + $DotnetNames.Count + $UnrealNames.Count)

$LiteInst = Join-Path $Work 'lite-inst'
Invoke-Install @{ Target = $LiteInst; Yes = $true; Lite = $true }
Assert-Eq 'lite install root is AGENTS.md only' (Get-RootEntries $LiteInst) 'AGENTS.md'

# A detected stack is not added to a lite install; it has to be named.
$LiteProj = Join-Path $Work 'lite-proj'
$LiteProjStack = Join-Path $Work 'lite-proj-stack'
Set-Text (Join-Path $LiteProj 'App.csproj') ''
Set-Text (Join-Path $LiteProjStack 'App.csproj') ''
Invoke-Install @{ Target = $LiteProj; Yes = $true; Lite = $true }
Assert-Eq 'a lite install ignores the detected stacks' `
    (Get-MatchingLineCount (Join-Path $LiteProj 'AGENTS.md') $dotnetPattern) 0
Invoke-Install @{ Target = $LiteProjStack; Yes = $true; Lite = $true; Stacks = 'dotnet' }
Assert-Eq 'a lite install includes the stacks it is given' `
    (Get-MatchingLineCount (Join-Path $LiteProjStack 'AGENTS.md') $dotnetPattern) $DotnetNames.Count
Assert-Code '--check regenerates a lite install as lite' 0 `
    (Invoke-Script $Install @{ Target = $LiteInst; Check = $true })

$LiteConv = Join-Path $Work 'lite-conv'
Invoke-Install @{ Target = $LiteConv; Yes = $true }
Invoke-Install @{ Target = $LiteConv; Upgrade = $true; Lite = $true; Yes = $true }
Assert-Eq '--upgrade --lite converts a full install' (Get-RootEntries $LiteConv) 'AGENTS.md'

# --- 12. Upgrade --------------------------------------------------------

Section '12. Upgrade'

# The legacy layout is fabricated rather than generated: the code that produced it
# is gone from this tree, and what the pruner acts on is the shape on disk. The
# stamp gives -Upgrade a version and a stack set to read, as a real one would.
function New-Legacy([string]$Dir) {
    New-Dir (Join-Path $Dir 'standards')
    Copy-Item (Join-Path $StandardsDir '*.md') (Join-Path $Dir 'standards')
    foreach ($s in $Standards) {
        $n = $s.BaseName
        Set-Text (Join-Path $Dir ".cursor/rules/$n.mdc") "---`ndescription: x`nglobs:`nalwaysApply: false`n---`n`nold body`n"
        Set-Text (Join-Path $Dir ".claude/skills/$n/SKILL.md") "---`nname: $n`ndescription: x`n---`n`nold body`n"
    }
    Set-Text (Join-Path $Dir 'AGENTS.md') "# Agent instructions`n`n<!-- Standards version: 00000000 | stacks: all -->`n"
    # A skill of the user's own, in a directory the installer manages. It must
    # survive: the pruner may only touch names that came from standards/.
    Set-Text (Join-Path $Dir '.claude/skills/my-own-skill/SKILL.md') "---`nname: my-own-skill`n---`nkeep me`n"
}

Assert-Code '--upgrade on an empty directory exits 2' 2 (Invoke-Child $Install @('-Target', $Dry, '-Upgrade'))
Assert-Refused '--upgrade with --check is refused' (Invoke-Child $Install @('-Target', $Inst, '-Upgrade', '-Check'))

# -DryRun first, on the same fixture, so the destructive run has something to do.
$UpDry = Join-Path $Work 'up-dry'
New-Legacy $UpDry
$legacyFiles = Get-FileCount $UpDry
Invoke-Install @{ Target = $UpDry; Upgrade = $true; DryRun = $true; Yes = $true }
Assert-Eq '--upgrade --dry-run writes and removes nothing' (Get-FileCount $UpDry) $legacyFiles

$Up = Join-Path $Work 'up'
New-Legacy $Up
Invoke-Install @{ Target = $Up; Upgrade = $true; Yes = $true }

Assert-Eq 'upgrade adds the skills tree' (@(Get-SkillNames $Up).Count) $SrcStandards
Assert-Eq 'upgrade removes the standards directory' (Test-Path (Join-Path $Up 'standards')) $false
Assert-Eq 'upgrade removes the retired cursor directory' (Test-Path (Join-Path $Up '.cursor')) $false

# The claude adapter was inferred from the install, so its stubs are rewritten
# rather than dropped - an upgrade must not silently reduce coverage.
$claudeSkills = @(Get-ChildItem (Join-Path $Up '.claude/skills') -Directory |
    Where-Object { $_.Name -ne 'my-own-skill' })
Assert-Eq 'upgrade keeps the inferred claude adapter' $claudeSkills.Count $SrcStandards
Assert-Eq 'upgrade replaces the old claude bodies with pointers' `
    (Get-MatchingLineCount (Join-Path $Up '.claude/skills/code-quality/SKILL.md') 'old body') 0
$ownSkill = Join-Path $Up '.claude/skills/my-own-skill/SKILL.md'
$kept = if (Test-Path $ownSkill) { Get-MatchingLineCount $ownSkill 'keep me' } else { 0 }
Assert-Eq 'upgrade leaves a skill of your own alone' $kept 1

Assert-Code '--check passes on an upgraded install' 0 (Invoke-Script $Install @{ Target = $Up; Check = $true })

# Second time through there is nothing left to move, and nothing may be lost.
$upgraded = Get-FileCount $Up
Invoke-Install @{ Target = $Up; Upgrade = $true; Yes = $true }
Assert-Eq 'a second upgrade is a no-op' (Get-FileCount $Up) $upgraded

# --- Parity manifest ------------------------------------------------------
# The name of every test, and a SHA-256 of every file in the trees below. The
# trees are ones the tests above already built and no later test modifies.
# test.sh writes the same lines from the sh implementation; a difference between
# the two manifests is a parity failure.

if ($Manifest) {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($name in (Get-OrdinalSorted $script:TestNames.ToArray())) { $lines.Add("test  $name") }

    $trees = 'def', 'adapters', 'userpath', 's-any', 's-dotnet', 'proj-dotnet', 'proj-python',
        'proj-godot', 'proj-godot-cs', 'proj-unreal', 'inst-claude', 'inst-copilot',
        'lite', 'lite-stack', 'lite-inst', 'lite-proj', 'lite-proj-stack', 'lite-conv', 'up'
    foreach ($tree in $trees) {
        $root = Join-Path $Work $tree
        $hashes = @{}
        foreach ($file in (Get-Files $root)) {
            $rel = [System.IO.Path]::GetRelativePath($Work, $file.FullName) -replace '\\', '/'
            $hashes[$rel] = (Get-FileHash $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        foreach ($rel in (Get-OrdinalSorted ([string[]]@($hashes.Keys)))) { $lines.Add("$($hashes[$rel])  $rel") }
    }

    Set-Text $Manifest (($lines -join "`n") + "`n")
    Write-Host ''
    Write-Host "Manifest: $Manifest"
}

}
finally {
    Remove-Item $Work -Recurse -Force -ErrorAction SilentlyContinue
}

# --- Summary ------------------------------------------------------------

Write-Host ''
Write-Host '----------------------------------------'
Write-Host "$($script:Pass) passed, $($script:Fail) failed, $($script:Skip) skipped"
if ($script:Fail -gt 0) {
    Write-Host 'Failed:'
    foreach ($name in $script:FailedNames) { Write-Host "  - $name" }
    exit 1
}
exit 0
