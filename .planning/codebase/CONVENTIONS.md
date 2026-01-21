# Coding Conventions

**Analysis Date:** 2026-01-20

## Naming Patterns

**Files:**
- PascalCase for class files: `Patron.gd`, `RoomInstance.gd`, `WallOperation.gd`
- snake_case for utility/helper files: `IsometricMath.gd`, `UIStyleHelper.gd`, `RotationHelper.gd`
- snake_case for state files: `box_drawing_state.gd`, `door_placement_state.gd`, `idle_build_state.gd`
- Example: `C:\git\TheaterCity\Scripts\Patron.gd` uses PascalCase for the main class file

**Functions:**
- snake_case for all functions: `generate_walls()`, `is_valid_door_position()`, `choose_random_target()`
- Private functions prefixed with underscore: `_on_velocity_computed()`, `_ui_to_tilemap_coords()`, `_add_existing_wall_neighbors()`
- Signal handlers follow pattern: `_on_signal_name()` (e.g., `_on_door_placed()`, `_on_velocity_computed()`)
- Example from `Patron.gd` line 90: `func _navigation_finished() -> void:`

**Variables:**
- snake_case for all member variables: `movement_speed`, `nav_agent`, `animated_sprite`
- Private members prefixed with underscore: `_started`, `_nav_count`, `_wall_op`, `_furniture_op`
- Exported properties use @export with no underscore prefix: `@export var movement_speed: float = 3000.0`
- Example from `RoomBuildController.gd` lines 12-21: Mixed public and private member variables

**Types:**
- PascalCase for class names: `Patron`, `RoomInstance`, `FurnitureResource`, `ValidationOperation`
- PascalCase for inner classes: `DoorPlacement`, `FurniturePlacement` (defined within `RoomInstance.gd`)
- Use typed arrays: `Array[Vector2i]`, `Array[String]`, `Array[FurnitureResource]`
- Use Optional types with null coalescing operator: `return item.cost if item else 0`
- Example from `RoomInstance.gd` lines 13-29: Inner classes use PascalCase

## Code Style

**Formatting:**
- Indentation: Tabs (1 tab = 1 level)
- Brace style: Opening brace on same line: `func _ready() -> void:`
- Line length: No enforced limit observed, but files stay under 200 lines
- Spacing: Two blank lines between major function sections (e.g., between signal handlers and utility functions)

**Linting:**
- No explicit linter detected (no .editorconfig or similar found)
- GDScript built-in validation appears to be used
- Use early returns to flatten control flow: See `Patron.gd` lines 54-61 where `return` exits early on finished state
- Prefer null checks with early returns over nested ifs: `if not nav_agent.is_target_reachable(): return`

## Import Organization

**Order:**
1. Class definition: `class_name ClassName extends Parent`
2. Signal definitions: `signal signal_name(param_type)`
3. Export variables: `@export var name: Type`
4. Member variables (public): `var name: Type = initial_value`
5. Private member variables: `var _name: Type`
6. Constants: `const CONSTANT_NAME := value`
7. Inner classes: `class InnerClass:`
8. Methods: `func method_name() -> ReturnType:`

**Path Aliases:**
- No path aliases detected in use (no symbolic imports)
- Paths appear absolute from res:// root: `load("res://data/furniture/seating_bench.tres")`
- Auto-loaded singletons used directly: `Targets`, `RoomTypeRegistry`, `FurnitureRegistry`

**Example structure from `RoomBuildController.gd` lines 1-24:**
```gdscript
class_name RoomBuildController
extends Node

signal room_completed(room: RoomInstance)
signal state_changed(new_state: String)

@export var tilemap_layer: TileMapLayer
@export var ground_tilemap_layer: TileMapLayer
@export var ui: RoomBuildUI
@export var furniture_visuals: Node2D

var current_room: RoomInstance
var current_room_type: RoomTypeResource
var state_name: String = "idle"

var _wall_op = WallOperation.new()
var _door_op = DoorOperation.new()
```

## Error Handling

**Patterns:**
- Use guard clauses with early returns: `if not result.can_place: return` (`RoomBuildController.gd` line 124)
- Validation results returned as custom result objects: `ValidationResult` in `ValidationOperation.gd` with `is_valid: bool` and `errors: Array[String]`
- No explicit exception throwing observed; use early returns for validation failures
- Warnings logged for missing dependencies: `push_warning("RoomBuildController: UI not found!")` (`RoomBuildController.gd` line 42)
- Null checks before operations: `if not furniture: return` (`RoomInstance.gd` line 32)

**Example validation pattern from `ValidationOperation.gd` lines 8-41:**
```gdscript
func validate_complete(room: RoomInstance) -> ValidationResult:
    var result = ValidationResult.new()

    var room_type = room_type_registry.get_room_type(room.room_type_id)
    if not room_type:
        result.is_valid = false
        result.errors.append("Invalid room type")
        return result

    # Additional validation checks...
    return result
```

## Logging

**Framework:** `print()` or `push_warning()` / `push_error()` (Godot built-in)

**Patterns:**
- Warnings for configuration issues: `push_warning("RoomBuildController: UI not found!")`
- Debug information via print statements (commented or removed after development)
- Comments for complex calculations: `# Terrain configuration for auto-tiling` (`WallOperation.gd` line 4)
- No centralized logger; logging is minimal and tactical

## Comments

**When to Comment:**
- Explain non-obvious algorithm choices: "# Generate hollow rectangle walls from bounding box"
- Document coordinate system conversions: "# Offset to align with tile center"
- Clarify terrain/tileset configuration: `const TERRAIN_SET := 0  # Terrain set index in wall-tileset.tres`
- Explain signal connections: `# Signal handler - THIS MAKES AVOIDANCE WORK` (`Patron.gd` line 104)

**JSDoc/TSDoc:**
- Use `##` comment blocks for public functions and classes (Godot documentation format)
- Document parameters and return types: `## Convert screen position to tile coordinates` (`IsometricMath.gd` line 13)
- Include brief descriptions of what methods do before implementation
- Example from `UIStyleHelper.gd` lines 15-29:
```gdscript
## Create a pixel-art StyleBoxFlat with specified parameters
static func create_pixel_style(
    bg_color: Color,
    border_color: Color,
    border_width: int = 2,
    corner_radius: int = 2,
    margin: int = 8
) -> StyleBoxFlat:
```

## Function Design

**Size:**
- Target 20-50 lines per function for maintainability
- Most functions are under 30 lines: `_physics_process()`, `add_door()`, `is_valid_door_position()`
- Larger functions break concerns into named sub-functions or refactored into operations

**Parameters:**
- Favor simple types: `Vector2i`, `int`, `String`
- Use typed collections: `Array[Vector2i]` instead of untyped `Array`
- Default parameter values for optional inputs: `rotation: int = 0` (`RoomInstance.gd` line 26)
- Keep parameter count under 4; use data objects for multiple related params

**Return Values:**
- Always specify return type: `-> void`, `-> bool`, `-> Array[Vector2i]`
- Use typed return values to enable IDE autocomplete
- Null is acceptable return for "not found": `return null` when item not found (`FurnitureRegistry.gd` line 18)
- Custom result objects for complex returns: `ValidationResult` with multiple fields

**Example from `DoorOperation.gd` lines 12-21:**
```gdscript
func is_valid_door_position(position: Vector2i, room: RoomInstance) -> bool:
    if position not in room.walls:
        return false

    var neighbors = 0
    for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
        if (position + dir) in room.walls:
            neighbors += 1

    return neighbors >= 2 and neighbors <= 3
```

## Module Design

**Exports:**
- Use `class_name` to define exported class: `class_name Patron extends CharacterBody2D`
- Make classes available globally via class_name (loaded automatically by engine)
- Inner classes defined within parent class file for data structures: `DoorPlacement`, `FurniturePlacement`

**Barrel Files:**
- No barrel file pattern detected
- Imports done directly from specific files via `load()` or class_name resolution

**Operations Pattern:**
- Stateless RefCounted classes for operations: `WallOperation`, `DoorOperation`, `ValidationOperation`, `CollisionOperation`
- Operations take input data and return results without modifying state
- Example from `WallOperation.gd` lines 9-25:
```gdscript
class_name WallOperation
extends RefCounted

func generate_walls(bounding_box: Rect2i) -> Array[Vector2i]:
    var walls: Array[Vector2i] = []
    # Algorithm...
    return walls
```

**Singleton Registry Pattern:**
- Static instance variable: `static var _instance: FurnitureRegistry`
- Lazy-loading from .tres resources: `ResourceLoader.load(_path)`
- Get instance via class method: `FurnitureRegistry.get_instance()`
- Example from `FurnitureRegistry.gd` lines 6-12:
```gdscript
static var _instance: FurnitureRegistry
static var _path = "res://data/configs/furniture_registry.tres"

static func get_instance() -> FurnitureRegistry:
    if _instance == null:
        _instance = ResourceLoader.load(_path)
    return _instance
```

**Signal-Based Communication:**
- Signals for state changes: `signal state_changed(new_state: String)`
- Signals for completed actions: `signal room_completed(room: RoomInstance)`
- Signal connection in _ready(): `ui.room_type_selected.connect(_on_room_type_selected)`
- Consistent naming: signals use past tense (room_completed) or state (placement_changed)

---

*Convention analysis: 2026-01-20*
