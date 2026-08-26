#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs the agent instruction framework into a project or into user-level config.

.DESCRIPTION
    A project install adds two entries and nothing else:

        AGENTS.md        the always-on rules and the standards trigger table
        .agents/skills/  one skill per standard, loaded when its trigger matches

    .agents/skills/ is the vendor-neutral Agent Skills location: Codex, Cursor,
    Copilot/VS Code and OpenCode load it natively, and every other tool reads
    AGENTS.md and opens the path from its table. One copy serves all of them.

    Claude Code is the exception - it reads only .claude/skills/ - so -Adapters
    claude writes pointer stubs there. Nothing duplicates a standard's text.

    When the input stream is redirected, the defaults are used without prompting.

.PARAMETER Target
    Project directory to install into. Mutually exclusive with -User.

.PARAMETER User
    Install to user-level configuration so the standards apply to every project
    without adding files to any repository. Writes ~/.agents/skills, which serves
    Codex, Cursor and Copilot/VS Code, plus Claude Code (~/.claude) and Codex
    (~/.codex) always-on files.

.PARAMETER Adapters
    Add tool-specific directories: claude, copilot, all, none. Defaults to none.
    Passing this skips the prompt. Accepts an array or a comma-separated string.

.PARAMETER Check
    Report whether an existing install matches the current standards. Writes
    nothing. Exit code 1 if it is out of date.

.PARAMETER Upgrade
    Bring an existing install to the current layout: infer what was installed,
    regenerate it, and remove what earlier versions left behind. Implies -Force.

.PARAMETER Yes
    Accept the defaults without prompting.

.PARAMETER Force
    Overwrite existing files. Without this, existing files are left alone and reported.

.PARAMETER DryRun
    Report what would be written without changing the destination.

.EXAMPLE
    ./install.ps1 -Target C:\code\my-project
    AGENTS.md and .agents/skills/ only.

.EXAMPLE
    ./install.ps1 -Target ../my-project -Adapters claude
    Also writes .claude/skills/ pointer stubs.

.EXAMPLE
    ./install.ps1 -Target ../my-project -Upgrade
    Migrate an older install to the current layout.

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

    [string[]]$Stacks,

    [switch]$Check,
    [switch]$Upgrade,

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

if ($Check -and $Upgrade) {
    Write-Error '-Check reports and -Upgrade rewrites. Choose one.'
    exit 2
}
# An upgrade replaces the files it manages by definition, so asking again for
# -Force would only be a way to get it half done.
if ($Upgrade) { $Force = [switch]$true }

# Both modes read an existing install rather than prompting for a new one.
$inspect = $Check -or $Upgrade

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
        if ($DryRun -or $Check) { Write-Host "Target directory does not exist: $Target" -ForegroundColor DarkGray }
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
    claude  = '.claude/skills/    Claude Code does not read .agents/skills/'
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

# --- Stack detection ------------------------------------------------------
# Stack-specific standards install only into projects that match, so a Python
# repository never receives .NET rules. Marker files are searched a few levels
# deep, because projects commonly sit under src/.

function Get-ProjectStacks {
    $markers = [ordered]@{
        dotnet = '*.sln', '*.slnx', '*.csproj', '*.fsproj', '*.vbproj', 'global.json'
        python = 'pyproject.toml', 'setup.py', 'requirements.txt', 'Pipfile'
        rust   = 'Cargo.toml'
        'c-cpp' = 'CMakeLists.txt', '*.vcxproj', 'meson.build'
        node   = 'package.json'
        go     = 'go.mod'
    }

    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($stack in $markers.Keys) {
        foreach ($pattern in $markers[$stack]) {
            $hit = Get-ChildItem -Path $destination -Filter $pattern -Depth 2 -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git)[\\/]' } |
                Select-Object -First 1
            if ($hit) { $found.Add($stack); break }
        }
    }
    return $found
}

$stacksExplicit = $PSBoundParameters.ContainsKey('Stacks')
if ($stacksExplicit) {
    $stackList = (@($Stacks -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) -join ','
}
elseif ($User) {
    # User config serves every project, so every stack is included. The
    # descriptions are stack-scoped, so a .NET standard will not trigger in a
    # Python project.
    $stackList = 'all'
}
else {
    $projectStacks = @(Get-ProjectStacks)
    if ($projectStacks.Count -gt 0) {
        # -Check and -Upgrade override this from the install's own stamp, so
        # printing it here would announce a set that is about to be discarded.
        if (-not $inspect) {
            Write-Host "Detected stacks: $($projectStacks -join ', ')" -ForegroundColor Cyan
            Write-Host ''
        }
        $stackList = $projectStacks -join ','
    }
    else {
        if (-not $inspect) {
            Write-Host 'No stack markers found. Installing universal standards only.'
            Write-Host ''
        }
        $stackList = 'any'
    }
}

# --- Check and upgrade modes ----------------------------------------------
# Both read an existing install instead of prompting for a new one: the adapter
# set and the stack set come from what is actually on disk. Both reuse the normal
# staging build and path mappings, so no mode can disagree with another about
# where a file belongs. -Check then compares instead of copying; -Upgrade copies
# with -Force and prunes what is left over afterwards.

if ($inspect) {
    $anyInstalled = @(
        (Join-Path $destination 'AGENTS.md'),
        (Join-Path $destination '.claude/CLAUDE.md'),
        (Join-Path $destination '.codex/AGENTS.md')
    ) | Where-Object { Test-Path $_ }

    if (-not $anyInstalled) {
        [Console]::Error.WriteLine("Nothing installed at $label.")
        $how = if ($User) { '-User' } else { "-Target $Target" }
        [Console]::Error.WriteLine("Install first: ./install.ps1 $how")
        exit 2
    }

    # Infer the adapter set from what is actually present, so the comparison
    # covers exactly what was installed rather than today's defaults.
    if (-not $adaptersExplicit) {
        $inferred = [System.Collections.Generic.List[string]]::new()
        if (Test-Path (Join-Path $destination '.claude/skills')) { $inferred.Add('claude') }
        if (Test-Path (Join-Path $destination '.github/copilot-instructions.md')) { $inferred.Add('copilot') }
        # .cursor/rules is a retired adapter, not a current one: Cursor reads
        # .agents/skills natively now. Inferring 'cursor' here would fail the
        # build, so it is only noted, and the directory is pruned on upgrade.
        $Adapters = if ($inferred.Count -gt 0) { @($inferred) } else { @('none') }
    }

    $installedVersion = 'unstamped'
    foreach ($f in $anyInstalled) {
        $m = Select-String -Path $f -Pattern 'Standards version: ([0-9a-f]+)' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($m) { $installedVersion = $m.Matches[0].Groups[1].Value; break }
    }

    # Use the stack set recorded at install time. Re-detecting would compare
    # against a different set whenever the project has no marker files but was
    # installed with an explicit -Stacks.
    if (-not $stacksExplicit) {
        foreach ($f in $anyInstalled) {
            $m = Select-String -Path $f -Pattern 'stacks: ([a-z0-9,-]+)' -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($m) { $stackList = $m.Matches[0].Groups[1].Value; break }
        }
    }

    # The current version is read from the staging build below, so each mode
    # generates exactly once.
    if ($Upgrade) {
        Write-Host "Upgrading: $label" -ForegroundColor Cyan
        Write-Host "Adapters kept: $($Adapters -join ',')"
        Write-Host "Stacks kept:   $stackList"
    }
    else {
        Write-Host "Checking: $label" -ForegroundColor Cyan
        Write-Host "Adapters checked: $($Adapters -join ',')"
    }
    Write-Host ''

    if ($User) {
        $selectedTools = @(
            $(if (Test-Path (Join-Path $destination '.claude')) { 'claude' }),
            $(if (Test-Path (Join-Path $destination '.codex')) { 'codex' })
        ) | Where-Object { $_ }
    }
}
else {

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
    Write-Host 'Codex, Cursor, Copilot and OpenCode load .agents/skills/ natively, and every'
    Write-Host 'other tool reads AGENTS.md, so no tool-specific files are required.'
    Write-Host ''

    if (-not $adaptersExplicit) {
        Write-Host 'Optional adapters add a directory that points at .agents/skills/, for the'
        Write-Host "two tools that need one. They never copy a standard's text:"
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

}

if ($inspect) { $adapterList = $Adapters -join ',' }
else {
    Write-Host "Installing to: $label" -ForegroundColor Cyan
    if ($User) {
        Write-Host "Tools: $($selectedTools -join ', ')"
    }
    elseif ($adapterList -in '', 'none') {
        Write-Host 'Contents: AGENTS.md + .agents/skills/ only'
    }
    else {
        Write-Host "Contents: AGENTS.md + .agents/skills/ + adapters ($adapterList)"
    }
    if ($DryRun) { Write-Host 'Dry run: no files will be written.' -ForegroundColor Yellow }
    Write-Host ''
}
if ($Upgrade -and $DryRun) {
    Write-Host 'Dry run: nothing will be written or removed.' -ForegroundColor Yellow
    Write-Host ''
}

# --- Generate to a staging directory --------------------------------------

$currentVersion = ''
$staging = Join-Path ([System.IO.Path]::GetTempPath()) "agent-framework-install-$PID"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

try {
    # 6>$null suppresses build.ps1's Write-Host progress. A build failure still
    # surfaces, because both scripts set $ErrorActionPreference to Stop.
    $effectiveAdapters = if ($adapterList) { $adapterList } else { 'none' }
    # A user install has no project root, so the skills land in ~/.agents/skills
    # and every generated reference has to say so.
    $skillsPath = if ($User) { '~/.agents/skills' } else { '.agents/skills' }
    & $BuildScript -OutputRoot $staging -Adapters $effectiveAdapters -Stacks $stackList `
        -SkillsPath $skillsPath 6>$null

    # Map staged relative paths onto destination relative paths.
    # Project installs are a straight copy. User installs relocate into the
    # per-tool config directories, because there is no project root to sit in.
    $mappings = [System.Collections.Generic.List[object]]::new()

    if ($User) {
        # One skills tree for everyone. ~/.agents/skills is the documented
        # user-level location for Codex, Cursor and Copilot/VS Code alike, so this
        # is written whichever of them is present.
        $mappings.Add(@{ From = '.agents/skills'; To = '.agents/skills' })
        if ($selectedTools -contains 'claude') {
            # Claude Code reads neither ~/.agents/skills nor AGENTS.md at user
            # level, so it gets the stubs plus CLAUDE.md as always-on context.
            $mappings.Add(@{ From = '.claude/skills'; To = '.claude/skills' })
            $mappings.Add(@{ From = 'AGENTS.md'; To = '.claude/CLAUDE.md' })
        }
        if ($selectedTools -contains 'codex') {
            $mappings.Add(@{ From = 'AGENTS.md'; To = '.codex/AGENTS.md' })
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
    $script:missing = 0
    $script:differs = 0
    $script:same = 0
    # Every destination path the current build accounts for. The upgrade pruner
    # needs it to tell a file that still belongs from one an earlier version left
    # behind. Ordinal comparison, because these are paths, not prose.
    $script:expected = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    function Copy-One {
        param([string]$SourceFile, [string]$DestFile, [string]$DestRelative)

        # Recorded before any early return, so the set is complete in every mode.
        # Destination-relative, because that is the one spelling of a path both
        # this function and the leftover walk can derive without normalising
        # anything: an absolute comparison breaks the moment one side expands an
        # 8.3 path component and the other does not.
        $script:expected.Add(($DestRelative -replace '\\', '/')) | Out-Null
        if ($Check) {
            if (-not (Test-Path $DestFile)) {
                Write-Host "  missing  $DestFile" -ForegroundColor Red; $script:missing++
            }
            elseif ((Get-FileHash $SourceFile).Hash -ne (Get-FileHash $DestFile).Hash) {
                Write-Host "  differs  $DestFile" -ForegroundColor Yellow; $script:differs++
            }
            else { $script:same++ }
            return
        }
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
                Copy-One $_.FullName (Join-Path $destination (Join-Path $map.To $rel)) "$($map.To)/$rel"
            }
        }
        else {
            Copy-One $source (Join-Path $destination $map.To) $map.To
        }
    }
}
finally {
    if ($Check -and (Test-Path (Join-Path $staging 'AGENTS.md'))) {
        $m = Select-String -Path (Join-Path $staging 'AGENTS.md') -Pattern 'Standards version: ([0-9a-f]+)' |
            Select-Object -First 1
        if ($m) { $currentVersion = $m.Matches[0].Groups[1].Value }
    }
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}

if ($Check) {
    Write-Host ''
    Write-Host "Installed version: $installedVersion"
    Write-Host "Current version:   $(if ($currentVersion) { $currentVersion } else { 'unknown' })"
    Write-Host "$script:same up to date, $script:differs differ, $script:missing missing."
    if ($script:differs -gt 0 -or $script:missing -gt 0) {
        $how = if ($User) { '-User' } else { "-Target $Target" }
        Write-Host "Out of date. Re-install: ./install.ps1 $how -Force" -ForegroundColor Yellow
        exit 1
    }
    Write-Host 'Up to date.' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host "$script:written file(s) $(if ($DryRun) { 'would be written' } else { 'written' }), $script:skipped skipped." -ForegroundColor Green
if ($script:skipped -gt 0 -and -not $Force) {
    Write-Host 'Re-run with -Force to overwrite existing files.' -ForegroundColor Yellow
}

# --- Leftovers ------------------------------------------------------------
# Only these directories are ever written by this installer, so only these are
# considered. Within them, only a file whose name corresponds to a source
# standard is treated as ours: a skill or rule you wrote yourself sits in the
# same directory and must survive an upgrade untouched.

$managedDirs = @(
    'standards', '.agents/skills', '.claude/skills', '.claude/standards',
    '.codex/standards', '.cursor/rules', '.github/instructions'
)

# Every source standard, including _core and those excluded by stack, so a file
# left behind by a stack change is still recognised as ours rather than yours.
$sourceNames = @(Get-ChildItem (Join-Path $RepoRoot 'standards') -Filter '*.md' |
    ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) })

$stale = [System.Collections.Generic.List[string]]::new()
$foreign = [System.Collections.Generic.List[string]]::new()

foreach ($md in $managedDirs) {
    $dir = Join-Path $destination $md
    if (-not (Test-Path $dir -PathType Container)) { continue }
    foreach ($file in Get-ChildItem $dir -Recurse -File) {
        # GetRelativePath rather than trimming a resolved prefix: on Windows
        # Resolve-Path expands an 8.3 component that Get-ChildItem leaves short,
        # and the two lengths then disagree.
        $rel = [System.IO.Path]::GetRelativePath($dir, $file.FullName) -replace '\\', '/'
        if ($script:expected.Contains("$md/$rel")) { continue }

        # The standard's name is the directory for a skill, the basename otherwise.
        $name = switch -Regex ($rel) {
            '/.*/'                     { ''; break }
            '^(.+)/SKILL\.md$'         { $Matches[1]; break }
            '/'                        { ''; break }
            '^(.+)\.instructions\.md$' { $Matches[1]; break }
            '^(.+)\.[^.]+$'            { $Matches[1]; break }
            default                    { '' }
        }
        if ($name -and $sourceNames -contains $name) { $stale.Add("$md/$rel") }
        else { $foreign.Add("$md/$rel") }
    }
}

if ($foreign.Count -gt 0) {
    Write-Host ''
    Write-Host 'In a directory this installer manages, but not generated by it:' -ForegroundColor DarkGray
    foreach ($o in $foreign) { Write-Host "  $destination/$o" }
    Write-Host 'Left untouched.'
}

if ($stale.Count -eq 0) {
    if ($Upgrade) {
        Write-Host ''
        Write-Host 'Nothing left over. The install is on the current layout.' -ForegroundColor Green
    }
}
elseif (-not $Upgrade) {
    Write-Host ''
    Write-Host 'Left over from an earlier layout, no longer referenced by anything:' -ForegroundColor Yellow
    foreach ($o in $stale) { Write-Host "  $destination/$o" }
    $how = if ($User) { '-User' } else { "-Target $Target" }
    Write-Host "Remove them with: ./install.ps1 $how -Upgrade"
}
else {
    Write-Host ''
    Write-Host 'Left over from an earlier layout, to remove:' -ForegroundColor Yellow
    foreach ($o in $stale) { Write-Host "  - $destination/$o" }

    $remove = $true
    if ($DryRun) {
        $remove = $false
        Write-Host "$($stale.Count) file(s) would be removed."
    }
    elseif (-not $Yes -and -not [Console]::IsInputRedirected) {
        $confirm = Read-Host "Remove these $($stale.Count) file(s)? [y/N]"
        if ($confirm -notin 'y', 'Y', 'yes', 'YES') {
            $remove = $false
            Write-Host 'Left in place.'
        }
    }

    if ($remove) {
        foreach ($o in $stale) {
            Remove-Item -LiteralPath (Join-Path $destination $o) -Force -ErrorAction SilentlyContinue
        }
        # Remove-Item on a directory only succeeds here when it is empty, so a
        # directory still holding something of yours survives without needing a
        # second check for it. Deepest first, then the parents the managed
        # directories sat in.
        foreach ($md in $managedDirs) {
            $dir = Join-Path $destination $md
            if (-not (Test-Path $dir -PathType Container)) { continue }
            $subdirs = @(Get-ChildItem $dir -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending)
            foreach ($d in $subdirs + @(Get-Item $dir)) {
                if (-not (Get-ChildItem $d.FullName -Force)) {
                    Remove-Item -LiteralPath $d.FullName -Force -ErrorAction SilentlyContinue
                }
            }
        }
        foreach ($md in '.cursor', '.claude', '.codex', '.github', '.agents') {
            $dir = Join-Path $destination $md
            if ((Test-Path $dir -PathType Container) -and -not (Get-ChildItem $dir -Force)) {
                Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "$($stale.Count) file(s) removed."
    }
}
