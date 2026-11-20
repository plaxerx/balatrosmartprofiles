# Deploy this mod into Balatro's Mods folder.
#
# Adapted from EndlessEngines/tools/deploy.ps1.
#
# MIRROR, not copy: robocopy /MIR deletes files in the destination that no longer exist in
# the source. That is the point - a plain copy leaves deleted files sitting in the Mods
# folder where Steamodded still loads them, which is a far more confusing failure than a
# missing file.
#
# Balatro must be restarted to pick up changes.

[CmdletBinding()]
param(
    # Repo root. Left empty and resolved in the body from this script's own location - see
    # the note there. Do NOT put $PSScriptRoot in this default.
    [string]$Source = '',

    # Install folder. Steamodded identifies a mod by the "id" in its .json manifest, not by
    # the folder name, so an existing install can be updated in place under whatever name it
    # already has.
    [string]$Dest = (Join-Path $env:APPDATA 'Balatro\Mods\SmartProfiles'),

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# Resolve the source HERE, not in the param default. When this script is launched as
# `powershell.exe -File ...` from a non-PowerShell parent (which is how a PostToolUse hook
# runs it, via Git Bash), $PSScriptRoot is still empty while param defaults are being bound -
# Split-Path then throws on an empty string and the hook fails every time, while running it
# from a PowerShell prompt works fine and hides the bug.
if (-not $Source) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $Source = Split-Path -Parent $here
}

if (-not (Test-Path $Source)) { throw "source not found: $Source" }
if (-not (Test-Path (Join-Path $Source 'SmartProfiles.json'))) {
    throw "no SmartProfiles.json in $Source"
}

# Dev-only files. None of these are read by the game.
$excludeDirs  = @('.git', '.claude', 'tools', 'docs')
$excludeFiles = @('*.ps1', '.gitattributes', '.gitignore', '*.md')

# NOT $args - that is a PowerShell automatic variable holding the script's own unbound
# arguments, and splatting a reassigned copy of it is asking for trouble.
$rcArgs = @(
    $Source, $Dest, '/MIR',
    '/XD') + $excludeDirs + @(
    '/XF') + $excludeFiles + @(
    '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:2', '/W:1'
)

$output = & robocopy @rcArgs 2>&1
$code = $LASTEXITCODE

# Robocopy's exit code is a BIT FIELD, not a status. 0-7 all mean success (1 = files copied,
# 2 = extras removed, 4 = mismatches). Only bit 3 and above (>= 8) is a real failure.
if ($code -ge 8) {
    Write-Error "robocopy failed (exit $code) syncing $Source -> $Dest`n$output"
    exit 1
}

# /MIR does NOT purge excluded paths. An /XD or /XF entry is skipped entirely - not copied,
# and not treated as an "extra" to delete - so dev cruft left in the destination by an older
# install would survive every future sync. Sweep it explicitly so the destination self-heals.
foreach ($d in $excludeDirs) {
    $p = Join-Path $Dest $d
    if (Test-Path $p) { Remove-Item $p -Recurse -Force; if (-not $Quiet) { Write-Host "  purged stale $d/" } }
}
foreach ($f in $excludeFiles) {
    Get-ChildItem -Path $Dest -Filter $f -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force
        if (-not $Quiet) { Write-Host "  purged stale $($_.Name)" }
    }
}

if (-not $Quiet) {
    $n = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "deployed SmartProfiles -> $Dest ($n files)"
}
exit 0
