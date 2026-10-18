# Steal-An-Egg Framework & Automation Suite

An advanced multi-executor framework for **Steal An Egg** featuring visual diagnostics, intelligent pathing, auto-farming routines, and companion tooling.

---

## ⚡ Features

- **Dynamic Visuals (ESP):** Bounding box rendering, distance indicators, trap radar, and treadmill vectors.
- **Autonomous Farm Loop:** Priority-based egg targeting, inventory capacity checks, base pen returns, and automated deposits.
- **Obstacle Avoidance:** Navigation mesh solver to avoid hostile zones, user-placed traps, and treadmills.
- **Pet Automation:** Auto-hatch logic, best-in-slot equipment manager, and pet fusing routines.
- **Custom UI System:** Multi-tab interactive GUI with persistent state toggles, draggable viewport, and keybind toggle (`G`).

---

## 🚀 Execution Methods

### Option 1: Direct Web Loader (Cloud)
Paste into your executor's execution tab:
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/aether-bytess/Steal-An-Egg/refs/heads/main/StealAnEgg.lua"))()
```

### Option 2: Local Workspace Loader (Host Companion)
1. Run `launch_hub.bat` on your PC.
2. In your executor, paste and execute:
```lua
loadstring(readfile("Steal-An-Egg/StealAnEgg.lua"))()
```

Press **G** in-game to toggle the interface.

---

## 🛠️ Supported Executors

Tested and verified across standard UNC and custom environments:
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
├── launch_hub.bat         # Host bootstrapper launcher
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
