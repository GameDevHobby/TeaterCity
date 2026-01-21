# Technology Stack

**Analysis Date:** 2026-01-20

## Languages

**Primary:**
- GDScript 4.5 - Core game logic, UI systems, and simulation

**Secondary:**
- Python - Configuration utility in addon (`data/configs/populate_registries.gd` imports logic)

## Runtime

**Environment:**
- Godot Engine 4.5 - Game engine and runtime
- Target platforms: Android (arm64-v8a), Desktop (Windows/Linux/macOS via Godot runtime)

**Engine Configuration:**
- Rendering method: Mobile (optimized for mobile platforms)
- Viewport size: 1080x1920 (mobile portrait)
- Stretch mode: canvas_items with aspect expand
- Handheld orientation: Portrait (orientation=1)

## Frameworks

**Core Game Framework:**
- Godot 4.5 Engine - Scene-based architecture with node hierarchy
- GDScript type system - Static typing with class annotations

**AI & Behavior:**
- LimboAI - Behavior trees and hierarchical state machines
  - Custom BT tasks in `demo/ai/tasks/`
  - Blackboard system for inter-task communication
  - Base agent class in `demo/agents/scripts/agent_base.gd`

**Navigation & Physics:**
- NavigationAgent2D - Pathfinding with avoidance
- CharacterBody2D - Physics-based character movement
- NavigationRegion2D - Runtime navigation mesh generation

**UI Framework:**
- CanvasLayer - Screen-space UI management
- Control nodes (Panel, PanelContainer, Button, etc.)
- StyleBoxFlat - Programmatic UI styling

**Camera System:**
- PinchPanCamera (custom addon `addons/ppc/`) - Pan/zoom camera for 2D top-down games

**Testing Framework:**
- GUT 9.5.1 - Unit testing tool for Godot
  - Located in `addons/gut/`
  - CLI runner support

## Key Dependencies (Addons)

**Behavior & AI:**
- LimboAI - Behavior tree and state machine framework
  - Located: `addons/limboai/`
  - Provides: BTAction, BTCondition, BTComposite, LimboHSM for hierarchical state machines
  - Custom tasks extend these base classes

**Camera & Input:**
- Pinch Pan Camera (PPC) v0.4 - 2D strategy game camera
  - Located: `addons/ppc/`
  - Features: Pan, zoom, touch-based camera control via `PinchPanCamera` node
  - Implements `enable_pinch_pan` property for enable/disable

**Testing:**
- GUT v9.5.1 - Unit testing framework
  - Located: `addons/gut/`
  - Provides: Test runners, mocking/doubling, assertion library
  - CLI available via `gut_cli.gd`

**Development Tools:**
- Visual Studio Debugger - VS debugging support for .NET projects
  - Located: `addons/godot_visualstudio_debugger/`
  - Enables breakpoint debugging in Visual Studio

**AI/MCP Plugin:**
- GDAI MCP v0.2.8 - Claude AI integration for development
  - Located: `addons/gdai-mcp-plugin-godot/`
  - GDExtension binaries for Windows, macOS, Linux
  - Autoload: `GDAIMCPRuntime` (registered in project.godot)

## Configuration

**Environment:**
- Mobile-optimized rendering pipeline
- Input mapping: `mouse`, `drag_camera`, `toggle_build` (mapped to 'B' key and joypad)
- Touch emulation from mouse enabled for desktop testing

**Build:**
- Android export preset configured:
  - Package: `com.GameDevHobby.TheaterCity`
  - Target: arm64-v8a architecture only
  - Version code: 5
  - App category: Game (id=2)
  - Immersive mode enabled

**Godot Project Settings:**
- Main scene: `res://Main.tscn`
- Autoload singletons:
  - `Targets` - Entity registry for navigation destinations
  - `GDAIMCPRuntime` - AI integration runtime
- Features: Godot 4.5, Mobile

## Platform Requirements

**Development:**
- Godot 4.5+ editor
- GDScript IDE/editor (built into Godot)
- Optional: Visual Studio for debugging (if using VS debugger addon)
- LimboAI addon for behavior tree editing

**Production:**
- Android 7.0+ (arm64-v8a)
- Desktop: Windows, macOS, Linux via Godot runtime export
- Mobile device with 1080x1920 screen support

## Data Persistence

**Resource Format:**
- `.tres` - Binary Godot resource files for:
  - Room type definitions (`data/room_types/`)
  - Furniture configurations (`data/furniture/`)
  - TileSet data (`resources/tiles/`)
  - Scene data (`.tscn` files)

**In-Memory Storage:**
- Registries (singleton pattern):
  - `RoomTypeRegistry` - Room type definitions
  - `FurnitureRegistry` - Furniture specifications
  - `Targets` autoload - Navigation targets

---

*Stack analysis: 2026-01-20*
