#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates agent instruction files from standards/*.md.

.DESCRIPTION
    standards/*.md is the single source of truth. Generated output is not
    committed, so run this to produce files for a target directory.

    Output is AGENTS.md plus .agents/skills/<name>/SKILL.md, one skill per
    standard. .agents/skills/ is the vendor-neutral Agent Skills location, read
    natively by Codex, Cursor, Copilot/VS Code, OpenCode and others. A tool with
    no skill loader reads AGENTS.md and opens the path from its trigger table, so
    there is exactly one copy of every standard.

    Adapters cover the two tools that need something else, and are off by
    default. Claude Code reads only .claude/skills/; Copilot additionally
    supports glob-attached instructions. Both emit pointers to the
    .agents/skills/ copy, never a second copy of the text.

.PARAMETER OutputRoot
    Directory to write into. Required.

.PARAMETER Adapters
    Optional tool-specific adapters: claude, copilot, hooks, all, none. Defaults
    to none. Accepts an array or a comma-separated string.

.PARAMETER SkillsPath
    Where AGENTS.md and the adapters say the skills live. Defaults to
    .agents/skills. A user-level install passes ~/.agents/skills, because there
    is no project root.

.PARAMETER Lite
    Emit a single AGENTS.md for small-context local models: the core rules plus
    the checklist of each universal standard, inline. No skills tree, and
    adapters are refused. No stack-scoped standard is included unless -Stacks
    names its stack (-Lite -Stacks dotnet,unreal).

.EXAMPLE
    ./build.ps1 -OutputRoot ../my-project
    Emit AGENTS.md and .agents/skills/ only.

.EXAMPLE
    ./build.ps1 -OutputRoot ../my-project -Adapters claude
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$OutputRoot,

    [string[]]$Adapters = @('none'),

    [string[]]$Stacks = @('all'),

    [string]$SkillsPath = '.agents/skills',

    [switch]$Lite
)

$SkillsPath = $SkillsPath.TrimEnd('/', '\')

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot
$StandardsDir = Join-Path $RepoRoot 'standards'

if (-not (Test-Path $StandardsDir)) { throw "Source directory not found: $StandardsDir" }

if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }
$OutputRoot = (Resolve-Path $OutputRoot).Path

# Everything else reads .agents/skills/ natively, or falls back to the AGENTS.md
# table. Claude Code does not read .agents/skills/ at all, Copilot has a
# glob-attach mechanism that skills do not cover, and hooks turns the
# no-hardcodes gate into a real git pre-commit hook.
$KnownAdapters = @('claude', 'copilot', 'hooks')

# Accept both -Adapters claude,copilot (array) and -Adapters "claude,copilot" (one
# string, which is how "pwsh -File" passes a comma list). Splitting handles both.
$requested = @($Adapters -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

foreach ($a in $requested) {
    if ($a -notin (@('all', 'none') + $KnownAdapters)) {
        throw "Unknown adapter: $a`nValid: none, all, $($KnownAdapters -join ', ')"
    }
}

if ($requested -contains 'all') { $selected = $KnownAdapters }
elseif ($requested -contains 'none') { $selected = @() }
else { $selected = @($requested | Select-Object -Unique) }

# Lite is one always-on file: there is no skills tree for an adapter to point at.
if ($Lite -and $selected.Count -gt 0) {
    [Console]::Error.WriteLine('-Lite emits a single AGENTS.md; adapters do not apply.')
    exit 2
}

# --- Source parsing -------------------------------------------------------

function Read-Standard {
    <#
      Parses a standards/*.md file into a hashtable.
      Frontmatter is intentionally hand-parsed: values are single-line
      "key: value" pairs only, so no YAML module dependency is needed.
    #>
    param([Parameter(Mandatory)][string]$Path)

    $lines = [System.IO.File]::ReadAllLines($Path)
    if ($lines.Count -lt 3 -or $lines[0].Trim() -ne '---') {
        throw "$Path : missing opening frontmatter delimiter '---' on line 1."
    }

    $close = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '---') { $close = $i; break }
    }
    if ($close -lt 0) { throw "$Path : missing closing frontmatter delimiter '---'." }

    $meta = @{}
    for ($i = 1; $i -lt $close; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $sep = $line.IndexOf(':')
        if ($sep -lt 1) { throw "$Path : line $($i + 1) is not a 'key: value' pair." }
        $meta[$line.Substring(0, $sep).Trim()] = $line.Substring($sep + 1).Trim()
    }

    foreach ($required in 'name', 'description') {
        if (-not $meta.ContainsKey($required) -or -not $meta[$required]) {
            throw "$Path : frontmatter is missing required key '$required'."
        }
    }

    $expected = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    if ($meta['name'] -ne $expected) {
        throw "$Path : frontmatter name '$($meta['name'])' must match the filename '$expected'."
    }

    return @{
        Name        = $meta['name']
        Description = $meta['description']
        Globs       = if ($meta.ContainsKey('globs')) { $meta['globs'] } else { '' }
        Stack       = if ($meta.ContainsKey('stack') -and $meta['stack']) { $meta['stack'] } else { 'any' }
        Body        = ($lines[($close + 1)..($lines.Count - 1)] -join "`n").Trim()
    }
}

# A standard applies when it is universal, or when its stack list intersects the
# requested stacks. 'all' requests everything.
function Test-StackMatch {
    param([Parameter(Mandatory)][hashtable]$Standard, [Parameter(Mandatory)][string[]]$Requested)

    if ($Standard.Stack -eq 'any') { return $true }
    if ($Requested -contains 'all') { return $true }

    $declared = @($Standard.Stack -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })
    foreach ($d in $declared) { if ($Requested -contains $d) { return $true } }
    return $false
}

# Short hash identifying the framework revision. Covers every source standard,
# including _core, so one version identifies the whole set regardless of which
# stacks a given install selected. Ordinal sort and CR stripping keep it equal to
# the value build.sh computes.
function Get-StandardsVersion {
    $names = [string[]]@(Get-ChildItem $StandardsDir -Filter '*.md' | ForEach-Object { $_.Name })
    [Array]::Sort($names, [System.StringComparer]::Ordinal)

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $stream = New-Object System.IO.MemoryStream
    foreach ($name in $names) {
        $header = $utf8.GetBytes("$name`n")
        $stream.Write($header, 0, $header.Length)
        $text = [System.IO.File]::ReadAllText((Join-Path $StandardsDir $name)).Replace("`r", '')
        $body = $utf8.GetBytes($text)
        $stream.Write($body, 0, $body.Length)
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($stream.ToArray())
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 8)
    }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$standardsVersion = Get-StandardsVersion

$core = Read-Standard (Join-Path $StandardsDir '_core.md')

# Lite is the core rules and the universal standards unless stacks are named.
if ($Lite -and -not $PSBoundParameters.ContainsKey('Stacks')) { $Stacks = @('any') }

$requestedStacks = @($Stacks -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })

# Recorded in every generated file so --check can compare against the stack set
# that was actually installed, rather than re-detecting and disagreeing.
$stacksStamp = $requestedStacks -join ','

$allStandards = @(Get-ChildItem -Path $StandardsDir -Filter '*.md' |
    Where-Object { -not $_.Name.StartsWith('_') } |
    Sort-Object Name |
    ForEach-Object { Read-Standard $_.FullName })

if ($allStandards.Count -eq 0) { throw "No standards found in $StandardsDir." }

$standards = @($allStandards | Where-Object { Test-StackMatch $_ $requestedStacks })
$excluded = @($allStandards | Where-Object { -not (Test-StackMatch $_ $requestedStacks) })

Write-Host "Source: $($standards.Count) standards + core" -ForegroundColor Cyan
Write-Host "Output: $OutputRoot"
if ($excluded.Count -gt 0) {
    Write-Host "Excluded by stack: $(($excluded | ForEach-Object { "$($_.Name) ($($_.Stack))" }) -join ', ')" -ForegroundColor DarkGray
}

# --- Helpers --------------------------------------------------------------

function Write-Generated {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Content
    )
    $full = Join-Path $OutputRoot $RelativePath
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # LF endings and no BOM, so output is identical on every platform.
    $normalised = $Content.Replace("`r`n", "`n").TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($full, $normalised, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  + $RelativePath"
}

# One-line trigger, derived from the description's USE FOR clauses so the table
# and the frontmatter can never disagree.
function Get-Trigger {
    param([Parameter(Mandatory)][hashtable]$Standard)

    # Drop the DO NOT USE FOR clause before matching. "DO NOT USE FOR" contains
    # the literal "USE FOR", so matching it first would capture exclusions as
    # triggers and invert the rule.
    $text = ($Standard.Description -split 'DO NOT USE FOR')[0].Trim()

    # @() so a single match is still a collection under Set-StrictMode.
    $useFor = @([regex]::Matches($text, 'USE FOR\s+(.+?)(?=\s*USE FOR|\s*$)') |
        ForEach-Object { $_.Groups[1].Value.Trim().TrimEnd('.') })

    if ($useFor.Count -eq 0) { return (($text -split '(?<=\.)\s')[0]).TrimEnd('.') }
    return (($useFor -join '; ') -replace '\s+', ' ')
}

# The checklist as rules: each "- [ ] item" line becomes "- item". The lite
# build inlines these as a standard's whole content. Mirrors get_checklist.
function Get-Checklist {
    param([Parameter(Mandatory)][hashtable]$Standard)
    $rules = [System.Collections.Generic.List[string]]::new()
    $inChecklist = $false
    foreach ($line in ($Standard.Body -split "`n")) {
        if ($line -match '^## Checklist') { $inChecklist = $true; continue }
        if ($inChecklist -and $line -match '^## ') { break }
        if ($inChecklist -and $line.StartsWith('- [ ] ')) { $rules.Add('- ' + $line.Substring(6)) }
    }
    return $rules
}

# The mode is stamped so -Check and -Upgrade regenerate what was installed
# rather than comparing a lite install against a full build.
$modeStamp = if ($Lite) { ' | mode: lite' } else { '' }

$generatedNotice = @"
<!-- GENERATED FILE. Do not edit.
     Source: standards/*.md in the agent-framework repository.
     Standards version: $standardsVersion | stacks: $stacksStamp$modeStamp -->
"@

# --- .agents/skills/ ------------------------------------------------------
# The canonical copy, and the only one. Agent Skills is an open format, so a
# single tree serves every tool with a skill loader; AGENTS.md points the rest at
# the same paths.
#
# Frontmatter carries only the two fields the spec requires. Stack and Globs are
# build-time inputs to this script, not part of the format, so they are not
# passed through. A standard excluded by stack is never emitted, or the target
# gains rules for a language it does not use.

if (-not $Lite) {
    foreach ($s in $standards) {
        Write-Generated ".agents/skills/$($s.Name)/SKILL.md" @"
---
name: $($s.Name)
description: $($s.Description)
---

$generatedNotice

$($s.Body)
"@
    }
}

# --- AGENTS.md (lite) -------------------------------------------------------
# One always-on file for models with small context windows and weak on-demand
# loading: the core rules plus each standard's checklist, inline. No trigger
# table, because a small model cannot be relied on to go and load a file.

if ($Lite) {
    $liteSections = foreach ($s in $standards) {
        $rules = (Get-Checklist $s) -join "`n"
        "### $($s.Name)`n`nWhen: $(Get-Trigger $s).`n`n$rules"
    }

    Write-Generated 'AGENTS.md' @"
# Agent instructions

$generatedNotice

This is the lite build. Every rule is in this one file; there is nothing else
to load. Follow the non-negotiables always. Each standard below binds whenever
its "When" line matches the work you are doing.

$($core.Body)

## Standards

$($liteSections -join "`n`n")

## Precedence

Highest authority first:

1. An explicit instruction from the user in the current conversation.
2. This repository's own documented conventions and tooling configuration.
3. The patterns used in the surrounding code.
4. The conventions of the language being written.
5. The standards listed above.

The single exception is security. Rule 1 of the non-negotiables outranks a
repository or language convention that is insecure. Raise it rather than
following it.
"@
}
else {

# --- AGENTS.md ------------------------------------------------------------
# The vendor-neutral entry point. Read natively by Codex, Cursor, Copilot,
# Claude Code, Gemini CLI, Aider, Windsurf, Zed, Jules and others. Always
# emitted, and on its own it is a complete installation.

$table = foreach ($s in $standards) {
    "| ``$($s.Name)`` | $(Get-Trigger $s) | ``$SkillsPath/$($s.Name)/SKILL.md`` |"
}

Write-Generated 'AGENTS.md' @"
# Agent instructions

$generatedNotice

This file holds only the rules that apply to every turn. Detailed standards are
separate files, listed below. Load one **before** starting the work it governs,
not after.

**How to load a standard**, in order of preference for your runtime:

1. If you have a skill or rule loader that already lists it, use that.
2. Otherwise, read the file at the path in the third column. Read it in full
   before acting on the work it governs.

$($core.Body)

## Standards

Load by trigger. When two or more triggers match, load all of them.

| Standard | Load when | Path |
|---|---|---|
$($table -join "`n")

## Precedence

Highest authority first:

1. An explicit instruction from the user in the current conversation.
2. This repository's own documented conventions and tooling configuration.
3. The patterns used in the surrounding code.
4. The conventions of the language being written: its official style guide, its
   reference documentation, and its standard library's own practice.
5. The standards listed above.

When a language convention overrides a standard, state why in your report of the
work: name the standard's rule, name the convention and its source, and say why
the two conflict. A convention with no citable source, or a preference, is not a
justification; follow the standard.

The single exception is security. Rule 1 of the non-negotiables outranks a
repository or language convention that is insecure. Raise it rather than
following it.
"@

}

# --- Optional adapters ----------------------------------------------------
# Each adds a tool-specific directory. Off unless explicitly requested. Neither
# repeats a standard's text: they carry the discovery metadata their tool needs
# and point at the .agents/skills/ copy.

# Claude Code reads .claude/skills/ only, so without this adapter it falls back
# to the AGENTS.md table like any tool with no loader. The stub gives it a real
# skill entry: name and description are what drive activation, and the body is
# one instruction to read the canonical file.
if ($selected -contains 'claude') {
    foreach ($s in $standards) {
        Write-Generated ".claude/skills/$($s.Name)/SKILL.md" @"
---
name: $($s.Name)
description: $($s.Description)
---

$generatedNotice

Read ``$SkillsPath/$($s.Name)/SKILL.md`` in full before starting this work, then
follow it. That file is the standard; this one only points at it.
"@
    }
}

# Copilot has no agent-requested mode. Instructions are either repository-wide
# or glob-attached via applyTo. Only standards with globs become auto-attached
# files; the rest are referenced by path from the repository-wide file.
if ($selected -contains 'copilot') {
    $copilotTable = foreach ($s in $standards) {
        "| ``$SkillsPath/$($s.Name)/SKILL.md`` | $(Get-Trigger $s) |"
    }

    Write-Generated '.github/copilot-instructions.md' @"
# Copilot instructions

$generatedNotice

$($core.Body)

## Standards

Read the matching file before starting the work it governs. When two or more
triggers match, read all of them.

| Path | Read when |
|---|---|
$($copilotTable -join "`n")
"@

    foreach ($s in $standards) {
        if (-not $s.Globs) { continue }
        Write-Generated ".github/instructions/$($s.Name).instructions.md" @"
---
applyTo: '$($s.Globs)'
---
$generatedNotice

Read ``$SkillsPath/$($s.Name)/SKILL.md`` in full before editing these files, then
follow it. That file is the standard; this one only points at it.
"@
    }
}

# The hooks adapter is tooling, not a pointer: it turns the no-hardcodes
# standard's pre-commit gate into a real git hook, so a human commit meets the
# same gate an agent applies. Enabled per clone with:
#   git config core.hooksPath .githooks
if ($selected -contains 'hooks') {
    $hookBody = @'
#
# Pre-commit gate from the no-hardcodes standard: scans the staged diff's
# added lines for secrets and environment-specific values, and blocks the
# commit on a hit. Enable it per clone with:
#
#   git config core.hooksPath .githooks
#
# Only the user may waive a finding, and only after hearing the risk. Agents
# must never bypass this hook.

findings=$(git diff --cached --diff-filter=ACM --unified=0 --no-color | awk '
    /^\+\+\+ / { file = substr($0, 7); next }
    /^@@ /     { split($0, h, "+"); split(h[2], p, /[, ]/); line = p[1] - 1; next }
    /^\+/ {
        line = line + 1
        if (file ~ /^\.githooks\//) next
        text = substr($0, 2)
        lower = tolower(text)
        # Obvious placeholders and local-dev values never block.
        if (lower ~ /<[a-z_-]+>|changeme|xxxx|example\.com|localhost|127\.0\.0\.1/) next
        hit = ""
        if (lower ~ /-----begin [a-z ]*private key-----/)
            hit = "private key"
        else if (lower ~ /(password|passwd|pwd)[[:space:]]*[=:][[:space:]]*[^[:space:]]/)
            hit = "password"
        else if (lower ~ /(api[_-]?key|secret|token|accountkey)[[:space:]]*[=:][[:space:]]*["]?[a-z0-9+\/_.=-]{12,}/)
            hit = "credential"
        else if (text ~ /AKIA[0-9A-Z]{16}/)
            hit = "AWS access key"
        else if (lower ~ /[a-z+.-]+:\/\/[^\/[:space:]:]+:[^\/[:space:]@]+@/)
            hit = "credential in URL"
        # Report the location and category only. Never echo the value itself.
        if (hit != "") printf "  %s:%d  %s\n", file, line, hit
        next
    }
')

if [ -n "$findings" ]; then
    echo "no-hardcodes: commit blocked. Staged lines that look like secrets or"
    echo "environment-specific values:"
    echo ""
    printf '%s\n' "$findings"
    echo ""
    echo "Move each value to configuration or a secret store, then stage the"
    echo "change again. See the no-hardcodes standard for the remedy rules."
    exit 1
fi
exit 0
'@

    Write-Generated '.githooks/pre-commit' @"
#!/bin/sh
# GENERATED FILE. Do not edit.
# Source: standards/no-hardcodes.md in the agent-framework repository.
# Standards version: $standardsVersion | stacks: $stacksStamp
$hookBody
"@

    if ($IsLinux -or $IsMacOS) {
        & chmod +x (Join-Path $OutputRoot '.githooks/pre-commit')
    }
}

Write-Host ''
if ($selected.Count -eq 0) {
    Write-Host "Done. AGENTS.md + $SkillsPath/ only, no tool-specific directories." -ForegroundColor Green
}
else {
    Write-Host "Done. Adapters: $($selected -join ', ')" -ForegroundColor Green
}
