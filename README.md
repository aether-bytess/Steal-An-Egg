# Steal-An-Egg Framework & Automation Suite

An advanced multi-executor framework for **Steal An Egg** featuring visual diagnostics, intelligent pathing, auto-farming routines, and companion tooling.

[![Download ZIP](https://img.shields.io/badge/Download-Steal--An--Egg%20(Latest%20ZIP)-2ea44f?style=for-the-badge&logo=github)](https://github.com/aether-bytess/Steal-An-Egg/archive/refs/heads/main.zip)

---

## ⚡ Features

- **Dynamic Visuals (ESP):** Bounding box rendering, distance indicators, trap radar, and treadmill vectors.
- **Autonomous Farm Loop:** Priority-based egg targeting, inventory capacity checks, base pen returns, and automated deposits.
- **Obstacle Avoidance:** Navigation mesh solver to avoid hostile zones, user-placed traps, and treadmills.
- **Pet Automation:** Auto-hatch logic, best-in-slot equipment manager, and pet fusing routines.
- **Custom UI System:** Multi-tab interactive GUI with persistent state toggles, draggable viewport, and keybind toggle (`G`).

---

## 🚀 Execution Methods

| Method | Setup | Highlights |
|---|---|---|
| **[Option 2: Local Launcher](#option-2-local-workspace-loader-recommended)** *(Recommended)* | 1-Click ZIP + `launch_hub.bat` | Auto-sync to all executors, zero network throttling |
| **[Option 1: Cloud Loader](#option-1-direct-web-loader-cloud)** | Paste single URL | Quick cloud execution |

---

### Option 2: Local Workspace Loader (Recommended)

[![Download ZIP](https://img.shields.io/badge/⬇️_Download_Ready_Archive-Click_Here-blue?style=for-the-badge)](https://github.com/aether-bytess/Steal-An-Egg/archive/refs/heads/main.zip)

#### Пошаговая инструкция (3 шага):
1. **Скачайте архив:** Нажмите [Скачать Steal-An-Egg.zip](https://github.com/aether-bytess/Steal-An-Egg/archive/refs/heads/main.zip) и распакуйте папку в любое место на компьютере.
2. **Запустите лаунчер:** Дважды кликните по файлу `launch_hub.bat`.
   - Лаунчер сам найдет установленные инжекторы (**Real**, **Solara**, **Wave**, **Celery**, **Potassium** и др.).
   - Автоматически скопирует нужные файлы в папку `workspace` вашего экзекутора.
   - **Автоматически скопирует команду запуска в буфер обмена**.
3. **Запустите в игре:** Зайдите в Steal An Egg в Roblox, откройте свой экзекутор, нажмите **Ctrl + V** (вставить) и нажмите **Execute**:
```lua
loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()
```
Нажмите **G** в игре, чтобы открыть/закрыть меню.

---

### Option 1: Direct Web Loader (Cloud)
Если у вас нет возможности распаковать архив, вставьте этот скрипт напрямую в экзекутор:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aether-bytess/Steal-An-Egg/refs/heads/main/StealAnEgg.lua"))()
```
*(Примечание: если локальные файлы не найдены, скрипт покажет окно с предложением использовать Способ 2 для полной стабильности).*

---

## 🛠️ Supported Executors

Протестировано и подтверждено на популярных экзекуторах:
- **Real / RealExecutor**
- **Potassium / Ro-Exec**
- **Solara**
- **Wave**
- **Celery**
- **Xeno / Swift**
- **Delta / Codex**

---

## 📁 Repository Structure

```text
├── StealAnEgg.lua         # Universal cloud & local UI hub
├── hub_loader.lua         # Unified modular loader
├── run.lua                # Standalone single-chunk runtime
├── launch_hub.bat         # Host bootstrapper launcher (Double-click)
├── launch_hub.ps1         # Multi-executor workspace synchronizer
├── EggESP/                # Core automation, navigation & ESP modules
│   ├── automation/        # Auto-farm, movement, pet logic
│   ├── core/              # Config, diagnostics, filters
│   ├── esp/               # Renderer, bounding boxes, data collectors
│   ├── navigation/        # A* pathfinding and vector solver
│   └── ui/                # Interface components and themes
└── README.md
```

---

## 📄 License & Notes
Developed for personal research and private automation testing.
