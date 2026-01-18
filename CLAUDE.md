# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TheaterCity is a Godot 4.5 game project targeting mobile platforms. It's a theater/venue simulation where patrons navigate to targets using navigation agents with avoidance. The project uses GDScript as the primary language.

## Build & Run Commands

```bash
# Open project in Godot Editor (from command line)
godot --editor --path .

# Run the game
godot --path .

```

## Architecture

### Core Systems

**Navigation & Patrons** (`Patron/patron.gd`):
- `Patron` class extends CharacterBody2D with NavigationAgent2D for pathfinding
- Uses `Targets` autoload singleton to get random navigation destinations
- Implements avoidance via `velocity_computed` signal from NavigationAgent2D
- Directional 8-way animation system based on movement angle

**Targets System** (`targets.gd`):
- Autoload singleton registered as `Targets`
- Manages entity instances that patrons can navigate to
- Provides `get_random_entity()` for random target selection

**Room Building System** (`Scripts/room_building/`):
- `RoomBuildController`: Main orchestrator managing build workflow and state transitions
- `RoomBuildUI`: Handles user input (box drawing, door placement) and UI state feedback
- Operations pattern in `operations/` subdirectory:
  - `WallOperation`: Generates hollow rectangle walls from bounding box, creates tilemap visuals
  - `DoorOperation`: Validates door positions (must be on wall with 2-3 neighbors), determines direction
  - `ValidationOperation`: Validates complete rooms against type requirements (size, doors, furniture)
- State flow: `idle` → `draw_box` → `place_doors` → `idle` (via `state_name` property)

**Room Data & Storage** (`Scripts/storage/`):
- `RoomInstance`: RefCounted data model for rooms with:
  - Properties: `id`, `room_type_id`, `bounding_box`, `walls`, `doors`, `furniture`
  - Inner classes: `DoorPlacement` (position + direction), `FurniturePlacement` (id + position + rotation)
  - Methods: `get_total_cost()`, `get_monthly_upkeep()`, `add_door()`, `add_furniture()`

**Data Registries** (`Scripts/data/`):
- Singleton registry pattern with lazy-loading from `.tres` resources
- `RoomTypeRegistry` + `RoomTypeResource`: Room type definitions (min/max size, door requirements, allowed/required furniture)
- `FurnitureRegistry` + `FurnitureResource`: Furniture definitions (size, cost, monthly upkeep, sprite)

**Spawner** (`spawner.gd`):
- Simple timer-based spawner for patrons using Marker2D positions

### LimboAI Integration

The project includes LimboAI addon for behavior trees and state machines:
- Behavior trees defined in `demo/ai/trees/` as `.tres` resources
- Custom BT tasks in `demo/ai/tasks/` (extend BTAction/BTCondition)
- Agent base class in `demo/agents/scripts/agent_base.gd` provides movement, facing, health, and combat abilities
- BTPlayer nodes execute behavior trees; LimboHSM nodes manage state machines
- Blackboard system for sharing data between tasks (use `blackboard.get_var()`)

Custom BT task pattern:
```gdscript
@tool
extends BTAction  # or BTCondition, BTDecorator, BTComposite

@export var target_var: StringName = &"target"

func _generate_name() -> String:
    return "TaskName %s" % [LimboUtility.decorate_var(target_var)]

func _tick(_delta: float) -> Status:
    # Return SUCCESS, FAILURE, or RUNNING
    return SUCCESS
```

### Enabled Addons

- `addons/limboai/`: Behavior trees and state machines (LimboAI)
- `addons/ppc/`: Pan/zoom camera controls for 2D top-down view
- `addons/godot_visualstudio_debugger/`: VS debugging support

### Main Scene Structure

Main scene (`Main.tscn`) contains:
- RoomBuildSystem node with RoomBuildController
- Build mode toggle accessible via `main.gd` (`_on_build_button_pressed()`)

## UI Development Patterns

### Screen-Space UI vs World-Space

**Always use CanvasLayer for screen-space UI** - UI elements placed as children of Node2D will move with the camera. Wrap them in a CanvasLayer to keep them fixed on screen:

```
MainScene (Node2D)
├── GameContent
├── UILayer (CanvasLayer)        # Screen-space UI
│   └── GameUI (Control)
└── MainUILayer (CanvasLayer)    # Persistent UI (buttons, HUD)
    └── BuildButton (Button)
```

### Auto-Sizing Panels

Use **PanelContainer** (not Panel) when you want the panel to automatically size to its content:

```
CenterContainer (anchors: full_rect)
└── PanelContainer (auto-sizes to children)
    └── MarginContainer (padding: 20px all sides)
        └── VBoxContainer (separation: 8px)
            └── [Dynamic buttons added at runtime]
```

- `Panel` = fixed size, doesn't resize to content
- `PanelContainer` = automatically grows/shrinks to fit children

### Centering UI Elements

Wrap content in **CenterContainer** with full_rect anchors:
```gdscript
# In scene structure:
# CenterContainer (anchors_preset = 15 / PRESET_FULL_RECT)
#   └── YourPanel
```

### Anchor Presets

Common anchor presets for UI positioning:
- `PRESET_TOP_LEFT` (0) - Default
- `PRESET_BOTTOM_RIGHT` (3) - For persistent buttons
- `PRESET_CENTER` (8) - Centered element
- `PRESET_FULL_RECT` (15) - Fill parent

### Styling with StyleBoxFlat

Create pixel-art friendly styles programmatically:
```gdscript
var style = StyleBoxFlat.new()
style.bg_color = Color(0.25, 0.22, 0.3, 1.0)      # Dark purple-gray
style.border_color = Color(0.5, 0.45, 0.4, 1.0)   # Warm brown
style.set_border_width_all(2)
style.set_corner_radius_all(2)                     # Minimal rounding
style.set_content_margin_all(8)

button.add_theme_stylebox_override("normal", style)
button.add_theme_stylebox_override("hover", style_hover)
button.add_theme_stylebox_override("pressed", style_pressed)
button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
```

### Isometric Coordinate Conversion

For isometric tile games (64x32 tile size):
```gdscript
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
    var canvas_transform = get_viewport().get_canvas_transform()
    var world_pos = canvas_transform.affine_inverse() * screen_pos
    world_pos.y -= HALF_HEIGHT  # Offset for tile origin
    var tile_x = (world_pos.x / HALF_WIDTH + world_pos.y / HALF_HEIGHT) / 2.0
    var tile_y = (world_pos.y / HALF_HEIGHT - world_pos.x / HALF_WIDTH) / 2.0
    return Vector2i(floor(tile_x), floor(tile_y))

func _tile_to_world(tile_pos: Vector2i) -> Vector2:
    return Vector2(
        (tile_pos.x - tile_pos.y) * HALF_WIDTH,
        (tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
    )
```

### Input Handling with Camera

When UI needs mouse input while a pan/zoom camera exists:
```gdscript
# In main controller
func _on_build_button_pressed() -> void:
    build_mode_active = !build_mode_active
    if build_mode_active:
        camera.enable_pinch_pan = false  # Disable camera input
    else:
        camera.enable_pinch_pan = true   # Re-enable
```

### Visibility Toggle Pattern

For modal UI (show/hide based on state):
```gdscript
func _ready() -> void:
    hide()  # Start hidden

func show_all() -> void:
    show()
    if panel:
        panel.show()

func hide_all() -> void:
    hide()
```

## Key Conventions

- Navigation uses NavigationAgent2D with avoidance enabled
- Movement applies noise offsets to prevent patron clumping
- Animation names follow pattern: `{state}{direction}` (e.g., `walk0`, `idle3`)
- All room positions use `Vector2i` tile coordinates (grid-based)
- Registries use singleton pattern with lazy-loading from `res://data/resources/configs/` directory
- Operations are stateless RefCounted helpers that operate on RoomInstance data
- Door directions: 0=North, 1=East, 2=South, 3=West
