#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs the agent instruction framework into a project or into user-level config.

.DESCRIPTION
    A project install adds two entries and nothing else:

        AGENTS.md     the always-on rules and the standards trigger table
        standards/    one file per standard, read only when its trigger matches

    Every supported tool reads AGENTS.md, so that is a complete installation.
    Tool-specific directories (.claude/, .cursor/, .github/) are never written
    unless you ask for them with -Adapters.

    When the input stream is redirected, the defaults are used without prompting.

.PARAMETER Target
    Project directory to install into. Mutually exclusive with -User.

.PARAMETER User
    Install to user-level configuration so the standards apply to every project
    without adding files to any repository. Covers Claude Code (~/.claude) and
    Codex (~/.codex).

.PARAMETER Adapters
    Add tool-specific directories: claude, copilot, cursor, all, none.
    Defaults to none. Passing this skips the prompt. Accepts an array or a
    comma-separated string.

.PARAMETER Yes
    Accept the defaults without prompting.

.PARAMETER Force
    Overwrite existing files. Without this, existing files are left alone and reported.

.PARAMETER DryRun
    Report what would be written without changing the destination.

.EXAMPLE
    ./install.ps1 -Target C:\code\my-project
    AGENTS.md and standards/ only.

.EXAMPLE
    ./install.ps1 -Target ../my-project -Adapters claude
    Also writes .claude/skills/.

.EXAMPLE
    ./install.ps1 -User -Yes
    Global setup, no repository files anywhere.
#>
[CmdletBinding(DefaultParameterSetName = 'Project')]
param(
    [Parameter(ParameterSetName = 'Project', Mandatory, Position = 0)]
    [string]$Target,

    [Parameter(ParameterSetName = 'UserScope', Mandatory)]
    [switch]$User,

    [string[]]$Adapters,

    [Alias('y')]
    [switch]$Yes,

    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RepoRoot = $PSScriptRoot
$BuildScript = Join-Path $RepoRoot 'build.ps1'
if (-not (Test-Path $BuildScript)) { throw 'Missing build.ps1 next to install.ps1.' }

# Accept both -Adapters claude,cursor (array) and -Adapters "claude,cursor" (one
# string, which is how "pwsh -File" passes a comma list). build.ps1 validates
# the names, so this only normalises the shape.
$adaptersExplicit = $PSBoundParameters.ContainsKey('Adapters')
if ($adaptersExplicit) {
    $Adapters = @($Adapters -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
else {
    $Adapters = @('none')
}

$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

# --- Resolve destination --------------------------------------------------

if ($User) {
    if (-not $homeDir) { throw 'Cannot determine the home directory.' }
    $destination = $homeDir
    $label = "user scope ($homeDir)"
    # Only these two have a documented user-level file location.
    $candidates = @('claude', 'codex')
}
else {
    if (-not (Test-Path $Target)) {
        if ($DryRun) { Write-Host "Would create target directory: $Target" -ForegroundColor DarkGray }
        else { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
    }
    $destination = if (Test-Path $Target) { (Resolve-Path $Target).Path } else { $Target }
    if ($destination -eq $RepoRoot) {
        throw 'Target is the framework repository itself. Choose another directory.'
    }
    $label = $destination
    $candidates = @('claude', 'copilot', 'cursor', 'codex', 'gemini', 'aider', 'windsurf', 'zed')
}

# --- Detection ------------------------------------------------------------
# Each tool is probed for a CLI on PATH, a user config directory, an installed
# application, and a marker inside the destination project. The first hit wins
# and is reported as the evidence, so the report is auditable.

$ToolLabels = @{
    claude   = 'Claude Code'
    codex    = 'OpenAI Codex'
    copilot  = 'GitHub Copilot'
    cursor   = 'Cursor'
    gemini   = 'Gemini CLI'
    aider    = 'Aider'
    windsurf = 'Windsurf'
    zed      = 'Zed'
}

$AdapterNotes = [ordered]@{
    claude  = '.claude/skills/    model-decided skill loading'
    cursor  = '.cursor/rules/     agent-requested rule loading'
    copilot = '.github/           glob-attached instructions'
}

function Test-Cmd {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Returns the evidence string when found, or $null when not.
function Find-Tool {
    param([Parameter(Mandatory)][string]$Name)

    $localApp = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $homeDir 'AppData/Local' }

    switch ($Name) {
        'claude' {
            if (Test-Cmd 'claude') { return 'claude on PATH' }
            if (Test-Path (Join-Path $homeDir '.claude')) { return '~/.claude' }
            if (Test-Path (Join-Path $destination '.claude')) { return '.claude in project' }
        }
        'codex' {
            if (Test-Cmd 'codex') { return 'codex on PATH' }
            if (Test-Path (Join-Path $homeDir '.codex')) { return '~/.codex' }
        }
        'copilot' {
            if (Test-Cmd 'copilot') { return 'copilot on PATH' }
            foreach ($d in '.vscode/extensions', '.vscode-insiders/extensions', '.vscode-server/extensions') {
                $dir = Join-Path $homeDir $d
                if (-not (Test-Path $dir)) { continue }
                if (Get-ChildItem $dir -Filter 'github.copilot-*' -Directory -ErrorAction SilentlyContinue) {
                    return 'VS Code Copilot extension'
                }
            }
            if (Test-Path (Join-Path $destination '.github/copilot-instructions.md')) {
                return 'copilot-instructions.md in project'
            }
        }
        'cursor' {
            if (Test-Cmd 'cursor') { return 'cursor on PATH' }
            if (Test-Path (Join-Path $homeDir '.cursor')) { return '~/.cursor' }
            if (Test-Path '/Applications/Cursor.app') { return '/Applications/Cursor.app' }
            if (Test-Path (Join-Path $localApp 'Programs/cursor')) { return 'Cursor in LOCALAPPDATA' }
            if (Test-Path (Join-Path $destination '.cursor')) { return '.cursor in project' }
        }
        'gemini' {
            if (Test-Cmd 'gemini') { return 'gemini on PATH' }
            if (Test-Path (Join-Path $homeDir '.gemini')) { return '~/.gemini' }
        }
        'aider' {
            if (Test-Cmd 'aider') { return 'aider on PATH' }
            if (Test-Path (Join-Path $homeDir '.aider.conf.yml')) { return '~/.aider.conf.yml' }
        }
        'windsurf' {
            if (Test-Cmd 'windsurf') { return 'windsurf on PATH' }
            if (Test-Path (Join-Path $homeDir '.codeium/windsurf')) { return '~/.codeium/windsurf' }
            if (Test-Path '/Applications/Windsurf.app') { return '/Applications/Windsurf.app' }
            if (Test-Path (Join-Path $localApp 'Programs/Windsurf')) { return 'Windsurf in LOCALAPPDATA' }
        }
        'zed' {
            if (Test-Cmd 'zed') { return 'zed on PATH' }
            if (Test-Path (Join-Path $homeDir '.config/zed')) { return '~/.config/zed' }
            if (Test-Path '/Applications/Zed.app') { return '/Applications/Zed.app' }
            if (Test-Path (Join-Path $localApp 'Zed')) { return 'Zed in LOCALAPPDATA' }
        }
    }
    return $null
}

$detected = [System.Collections.Generic.List[string]]::new()

Write-Host 'Detected agentic tools:' -ForegroundColor Cyan
Write-Host ''
foreach ($name in $candidates) {
    $evidence = Find-Tool $name
    $row = '  [{0}] {1,-9} {2,-16} {3}' -f
        $(if ($evidence) { 'x' } else { ' ' }),
        $name,
        $ToolLabels[$name],
        $(if ($evidence) { $evidence } else { 'not detected' })

    if ($evidence) { $detected.Add($name); Write-Host $row -ForegroundColor Green }
    else { Write-Host $row -ForegroundColor DarkGray }
}
Write-Host ''

if ($User) {
    # User scope has no repository to keep clean, so Claude Code skills are
    # included: they give on-demand loading with zero project footprint.
    if ($detected.Count -eq 0) {
        [Console]::Error.WriteLine('Neither Claude Code nor Codex detected. Nothing to set up at user level.')
        [Console]::Error.WriteLine('Install into a project instead: ./install.ps1 -Target <dir>')
        exit 2
    }
    $selectedTools = @($detected)
    $adapterList = if ($selectedTools -contains 'claude') { 'claude' } else { 'none' }
}
else {
    Write-Host 'Every tool above reads AGENTS.md, so no tool-specific files are required.'
    Write-Host ''

    if (-not $adaptersExplicit) {
        Write-Host 'Optional adapters add directories to the repository, in exchange for'
        Write-Host 'on-demand loading rather than one always-present table:'
        Write-Host ''
        $offered = @($AdapterNotes.Keys)
        for ($i = 0; $i -lt $offered.Count; $i++) {
            $a = $offered[$i]
            $mark = if ($detected -contains $a) { ' (detected)' } else { '' }
            Write-Host ('  {0}) {1,-9} {2}{3}' -f ($i + 1), $a, $AdapterNotes[$a], $mark)
        }
        Write-Host ''

        $interactive = -not $Yes -and -not [Console]::IsInputRedirected
        if ($interactive) {
            $reply = (Read-Host 'Add any? Numbers separated by spaces, or Enter for none (recommended)').Trim()

            if ($reply -eq '') { $Adapters = @('none') }
            elseif ($reply -in 'a', 'A', 'all') { $Adapters = @('all') }
            else {
                # Bad input is a user mistake, not a defect, so report one clean
                # line and exit 2 rather than throwing a source-code dump.
                $picked = [System.Collections.Generic.List[string]]::new()
                foreach ($num in ($reply -split '[\s,]+' | Where-Object { $_ })) {
                    if ($num -notmatch '^\d+$') {
                        [Console]::Error.WriteLine("Not a number: $num"); exit 2
                    }
                    $index = [int]$num
                    if ($index -lt 1 -or $index -gt $offered.Count) {
                        [Console]::Error.WriteLine("No such option: $num"); exit 2
                    }
                    $picked.Add($offered[$index - 1])
                }
                if ($picked.Count -eq 0) { [Console]::Error.WriteLine('Nothing selected.'); exit 2 }
                $Adapters = @($picked)
            }
        }
        else {
            $Adapters = @('none')
            if (-not $Yes) {
                Write-Host 'Input is redirected: using the defaults without prompting.' -ForegroundColor DarkGray
            }
        }
        Write-Host ''
    }
    $adapterList = $Adapters -join ','
}

Write-Host "Installing to: $label" -ForegroundColor Cyan
if ($User) {
    Write-Host "Tools: $($selectedTools -join ', ')"
}
elseif ($adapterList -in '', 'none') {
    Write-Host 'Contents: AGENTS.md + standards/ only'
}
else {
    Write-Host "Contents: AGENTS.md + standards/ + adapters ($adapterList)"
}
if ($DryRun) { Write-Host 'Dry run: no files will be written.' -ForegroundColor Yellow }
Write-Host ''

# --- Generate to a staging directory --------------------------------------

$staging = Join-Path ([System.IO.Path]::GetTempPath()) "agent-framework-install-$PID"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

try {
    # 6>$null suppresses build.ps1's Write-Host progress. A build failure still
    # surfaces, because both scripts set $ErrorActionPreference to Stop.
    $effectiveAdapters = if ($adapterList) { $adapterList } else { 'none' }
    & $BuildScript -OutputRoot $staging -Adapters $effectiveAdapters 6>$null

    # Map staged relative paths onto destination relative paths.
    # Project installs are a straight copy. User installs relocate into the
    # per-tool config directories, because there is no project root to sit in.
    $mappings = [System.Collections.Generic.List[object]]::new()

    if ($User) {
        if ($selectedTools -contains 'claude') {
            $mappings.Add(@{ From = '.claude/skills'; To = '.claude/skills' })
            # Claude Code reads ~/.claude/CLAUDE.md as global always-on context.
            $mappings.Add(@{ From = 'AGENTS.md'; To = '.claude/CLAUDE.md' })
            $mappings.Add(@{ From = 'standards'; To = '.claude/standards' })
        }
        if ($selectedTools -contains 'codex') {
            $mappings.Add(@{ From = 'AGENTS.md'; To = '.codex/AGENTS.md' })
            $mappings.Add(@{ From = 'standards'; To = '.codex/standards' })
        }
    }
    else {
        Get-ChildItem $staging -Force | ForEach-Object {
            $mappings.Add(@{ From = $_.Name; To = $_.Name })
        }
    }

    # --- Copy ---------------------------------------------------------------

    $script:written = 0
    $script:skipped = 0

    function Copy-One {
        param([string]$SourceFile, [string]$DestFile)

        if ((Test-Path $DestFile) -and -not $Force) {
            Write-Host "  skip (exists) $DestFile" -ForegroundColor DarkYellow
            $script:skipped++
            return
        }
        if ($DryRun) {
            Write-Host "  would write   $DestFile" -ForegroundColor DarkGray
            $script:written++
            return
        }
        $dir = Split-Path $DestFile -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Copy-Item -LiteralPath $SourceFile -Destination $DestFile -Force
        Write-Host "  + $DestFile" -ForegroundColor Green
        $script:written++
    }

    foreach ($map in $mappings) {
        $source = Join-Path $staging $map.From
        if (-not (Test-Path $source)) { continue }

        if (Test-Path $source -PathType Container) {
            $sourceFull = (Resolve-Path $source).Path
            Get-ChildItem $source -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($sourceFull.Length).TrimStart('\', '/')
                Copy-One $_.FullName (Join-Path $destination (Join-Path $map.To $rel))
            }
        }
        else {
            Copy-One $source (Join-Path $destination $map.To)
        }
    }
}
finally {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}

Write-Host ''
Write-Host "$script:written file(s) $(if ($DryRun) { 'would be written' } else { 'written' }), $script:skipped skipped." -ForegroundColor Green
if ($script:skipped -gt 0 -and -not $Force) {
    Write-Host 'Re-run with -Force to overwrite existing files.' -ForegroundColor Yellow
}
