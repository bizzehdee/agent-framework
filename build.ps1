#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates agent instruction files from standards/*.md.

.DESCRIPTION
    standards/*.md is the single source of truth. Generated output is not
    committed, so run this to produce files for a target directory.

    By default only AGENTS.md and standards/ are emitted. That is all any
    supported tool needs, because AGENTS.md is read natively by Codex, Cursor,
    Copilot, Claude Code, Gemini CLI, Aider, Windsurf, Zed and others.

    Tool-specific directories (.claude/, .cursor/, .github/) are emitted only
    when named in -Adapters. They buy on-demand loading at the cost of extra
    directories in the repository.

.PARAMETER OutputRoot
    Directory to write into. Required.

.PARAMETER Adapters
    Optional tool-specific adapters: claude, copilot, cursor, all, none.
    Defaults to none. Accepts an array or a comma-separated string.

.PARAMETER NoStandards
    Skip emitting standards/. Only safe when every selected adapter inlines the
    full text, because AGENTS.md refers to standards/ by path.

.EXAMPLE
    ./build.ps1 -OutputRoot ../my-project
    Emit AGENTS.md and standards/ only.

.EXAMPLE
    ./build.ps1 -OutputRoot ../my-project -Adapters claude,cursor
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$OutputRoot,

    [string[]]$Adapters = @('none'),

    [string[]]$Stacks = @('all'),

    [switch]$NoStandards
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot
$StandardsDir = Join-Path $RepoRoot 'standards'

if (-not (Test-Path $StandardsDir)) { throw "Source directory not found: $StandardsDir" }

if (-not (Test-Path $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }
$OutputRoot = (Resolve-Path $OutputRoot).Path

# Only these three have a file-based, on-demand loading mechanism worth an
# adapter. Every other tool reads AGENTS.md, which is always emitted.
$KnownAdapters = @('claude', 'copilot', 'cursor')

# Accept both -Adapters claude,cursor (array) and -Adapters "claude,cursor" (one
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

$generatedNotice = @"
<!-- GENERATED FILE. Do not edit.
     Source: standards/*.md in the agent-framework repository.
     Standards version: $standardsVersion | stacks: $stacksStamp -->
"@

# --- standards/ -----------------------------------------------------------
# AGENTS.md refers to these by path, so they are always emitted. Skipped when
# generating in place, because the source already lives there.

if (-not $NoStandards -and $OutputRoot -ne $RepoRoot) {
    # _core.md plus the stack-matching standards only. A standard excluded by
    # stack must not reach the target, or the repository gains a file for a
    # language it does not use.
    Write-Generated 'standards/_core.md' ([System.IO.File]::ReadAllText((Join-Path $StandardsDir '_core.md')))
    foreach ($s in $standards) {
        Write-Generated "standards/$($s.Name).md" ([System.IO.File]::ReadAllText((Join-Path $StandardsDir "$($s.Name).md")))
    }
}

# --- AGENTS.md ------------------------------------------------------------
# The vendor-neutral entry point. Read natively by Codex, Cursor, Copilot,
# Claude Code, Gemini CLI, Aider, Windsurf, Zed, Jules and others. Always
# emitted, and on its own it is a complete installation.

$table = foreach ($s in $standards) {
    "| ``$($s.Name)`` | $(Get-Trigger $s) | ``standards/$($s.Name).md`` |"
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
4. The standards listed above.

The single exception is security. Rule 1 of the non-negotiables outranks a
repository convention that is insecure. Raise it rather than following it.
"@

# --- Optional adapters ----------------------------------------------------
# Each adds a tool-specific directory. Off unless explicitly requested, because
# AGENTS.md alone is sufficient and keeps the repository clean.

# Claude Code: the only target with model-decided progressive disclosure.
if ($selected -contains 'claude') {
    foreach ($s in $standards) {
        Write-Generated ".claude/skills/$($s.Name)/SKILL.md" @"
---
name: $($s.Name)
description: $($s.Description)
---

$($s.Body)
"@
    }
}

# Copilot has no agent-requested mode. Instructions are either repository-wide
# or glob-attached via applyTo. Only standards with globs become auto-attached
# files; the rest are referenced by path from the repository-wide file.
if ($selected -contains 'copilot') {
    $copilotTable = foreach ($s in $standards) {
        "| ``standards/$($s.Name).md`` | $(Get-Trigger $s) |"
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

$($s.Body)
"@
    }
}

# Cursor supports agent-requested rules: no globs plus alwaysApply false means
# the model decides from the description.
if ($selected -contains 'cursor') {
    foreach ($s in $standards) {
        $globsLine = if ($s.Globs) { "globs: $($s.Globs)" } else { 'globs:' }
        Write-Generated ".cursor/rules/$($s.Name).mdc" @"
---
description: $($s.Description)
$globsLine
alwaysApply: false
---

$($s.Body)
"@
    }
}

Write-Host ''
if ($selected.Count -eq 0) {
    Write-Host 'Done. AGENTS.md + standards/ only, no tool-specific directories.' -ForegroundColor Green
}
else {
    Write-Host "Done. Adapters: $($selected -join ', ')" -ForegroundColor Green
}
