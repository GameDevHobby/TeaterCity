# Architecture

**Analysis Date:** 2026-01-20

## Pattern Overview

**Overall:** Event-driven, data-centric architecture with layered separation between data models, operations, UI, and gameplay systems.

**Key Characteristics:**
- Autoload singletons manage global state (Targets, FurnitureRegistry, RoomTypeRegistry)
- RefCounted operation classes implement stateless, composable business logic
- Godot signals enable loose coupling between UI, controllers, and game logic
- Grid-based isometric coordinate system for all spatial operations
- State machine pattern in RoomBuildController for build workflow orchestration

## Layers

**Data Layer:**
- Purpose: Immutable resource definitions and data models
- Location: `scripts/data/`, `scripts/storage/`, `data/configs/`
- Contains: RoomTypeResource, FurnitureResource, RoomInstance (RefCounted data model)
- Depends on: Nothing (pure data)
- Used by: Operations, registries, controllers, UI

**Registry/Singleton Layer:**
- Purpose: Global access to resource definitions with lazy loading
- Location: `scripts/data/RoomTypeRegistry.gd`, `scripts/data/FurnitureRegistry.gd`, `scripts/Targets.gd`
- Contains: Static registry pattern with ResourceLoader for .tres files
- Depends on: Data layer (resources)
- Used by: Controllers, UI, operations

**Operation Layer:**
- Purpose: Stateless business logic for grid operations, validation, and visual generation
- Location: `scripts/room_building/operations/`
- Contains: WallOperation, DoorOperation, FurnitureOperation, CollisionOperation, ValidationOperation, NavigationOperation
- Depends on: Data layer (RoomInstance), utility helpers (IsometricMath, RotationHelper)
- Used by: RoomBuildController

**Controller Layer:**
- Purpose: Orchestrate workflow state and coordinate between UI, operations, and data
- Location: `scripts/room_building/RoomBuildController.gd`, `scripts/Main.gd`
- Contains: State machine (idle → draw_box → place_doors → place_furniture), operation composition
- Depends on: Data layer, registry layer, operation layer
- Used by: Main scene, UI

**UI Layer:**
- Purpose: Handle user input, render visual feedback, display dialogs
- Location: `scripts/room_building/RoomBuildUI.gd`, `scripts/room_building/ui/`
- Contains: RoomBuildDrawing (static drawing helpers), state machines for drawing/door/furniture placement
- Depends on: Data layer, registries, IsometricMath for screen/tile conversion
- Used by: CanvasLayer UI nodes

**Gameplay Layer:**
- Purpose: Autonomous patron behavior and navigation
- Location: `scripts/Patron.gd`, `scripts/Spawner.gd`
- Contains: NavigationAgent2D-based pathfinding with avoidance, animation state selection
- Depends on: Targets singleton, Godot's navigation system
- Used by: Main scene instance spawning

**Utility Layer:**
- Purpose: Shared mathematical conversions and helpers
- Location: `scripts/utils/`
- Contains: IsometricMath (screen↔tile↔world conversion), RotationHelper (footprint/access tile rotation), UIStyleHelper (theme creation)
- Depends on: Nothing
- Used by: All layers

## Data Flow

**Room Building Flow:**

1. Player presses build button → `Main._on_build_button_pressed()` → `RoomBuildController.start_build_mode()`
2. UI displays room type buttons (populated from RoomTypeRegistry)
3. Player selects room type → `RoomBuildUI.room_type_selected` signal → `RoomBuildController._on_room_type_selected()`
4. RoomBuildController creates RoomInstance, updates state_name to "draw_box"
5. Player draws box on tilemap → `RoomBuildUI` converts screen coords via IsometricMath, emits `box_draw_completed`
6. RoomBuildController validates size via RoomTypeResource constraints, calls `WallOperation.generate_walls()` to populate RoomInstance.walls
7. State transitions to "place_doors":
   - Player clicks wall tiles → `RoomBuildUI` validates via `DoorOperation.is_valid_door_position()`, emits `door_placed`
   - RoomBuildController calls `RoomInstance.add_door()`, stores DoorPlacement
8. State transitions to "place_furniture":
   - Player selects furniture from panel (FurnitureRegistry items)
   - RoomBuildUI displays preview sprite with rotation preview via `FurnitureOperation.create_preview_texture()`
   - Player clicks position → CollisionOperation validates placement and access tiles
   - RoomBuildController calls `RoomInstance.add_furniture()`
9. Player presses Complete:
   - ValidationOperation validates room type constraints (door count, furniture requirements)
   - WallOperation creates visual tilemap cells with terrain auto-connect
   - DoorOperation creates door visuals
   - FurnitureOperation instantiates furniture scenes as children of furniture_visuals node
   - NavigationOperation updates navigation polygon for updated room layout
   - Targets.notify_navigation_changed() signals all patrons to recalculate paths
   - state_name returns to "idle"

**Patron Navigation Flow:**

1. Spawner.gd spawns patron.tscn instances at marker positions
2. Patron._ready() connects to Targets.navigation_changed signal
3. Patron.choose_random_target() calls `Targets.get_random_entity()` to get Target node position
4. NavigationAgent2D calculates path to target with avoidance enabled
5. Patron._physics_process() reads NavigationAgent2D.get_next_path_position(), applies noise offset, updates animation
6. On velocity_computed signal (from NavigationAgent2D), Patron calls move_and_slide() with safe velocity
7. When navigation_finished signal fires, patron chooses new target (up to 10 times, then queue_free)
8. When room completed, Targets.notify_navigation_changed() emits → all patrons recalculate paths

**State Management:**

- Global state: RoomBuildController.state_name ("idle", "draw_box", "place_doors", "place_furniture")
- Session state: RoomBuildController.current_room (RoomInstance), current_room_type (RoomTypeResource)
- UI input state: RoomBuildUI._drawing, _is_dragging, _door_placement_active, _furniture_placement_active
- Grid state: RoomInstance model (walls, doors, furniture)

## Key Abstractions

**RoomInstance:**
- Purpose: Data model representing a player-built room with all spatial and furniture data
- Examples: `scripts/storage/RoomInstance.gd`
- Pattern: RefCounted with inner classes (DoorPlacement, FurniturePlacement) for composed data
- Methods: add_door(), add_furniture(), get_total_cost(), get_monthly_upkeep(), is_tile_occupied()

**Operation Classes:**
- Purpose: Composable stateless helpers that implement specific business logic
- Examples: `WallOperation`, `DoorOperation`, `CollisionOperation`, `ValidationOperation`
- Pattern: RefCounted extending with helper methods, no persistent state
- Usage: Instantiated in RoomBuildController._ready(), called via RoomBuildController on user events

**Registry Pattern:**
- Purpose: Lazy-load and cache resource definitions from .tres files
- Examples: RoomTypeRegistry, FurnitureRegistry
- Pattern: Static factory with singleton instance, ResourceLoader.load() from res://data/configs/
- Benefit: Single source of truth for game rules, editable in Godot editor

**Targets Singleton:**
- Purpose: Maintains array of navigation targets (doors, points of interest) and broadcasts navigation updates
- Location: `scripts/Targets.gd`
- Pattern: Autoload Node with signals for entity registration and navigation changes
- Usage: Accessed directly as `Targets` global reference

## Entry Points

**Main Scene:**
- Location: `Main.tscn` (root scene)
- Attached Script: `scripts/Main.gd`
- Triggers: Game startup
- Responsibilities:
  - Exports RoomBuildController, Camera, BuildButton references
  - Handles toggle_build input action
  - Disables camera panning when build mode active
  - Signals room completion to exit build mode

**RoomBuildController:**
- Location: `scripts/room_building/RoomBuildController.gd`
- Triggers: Build mode start → RoomBuildUI button clicks
- Responsibilities:
  - State machine orchestration (idle → draw_box → place_doors → place_furniture)
  - Operation composition and sequencing
  - Room data model lifecycle management
  - Visual generation (walls, doors, furniture, navigation)
  - Build completion emission

**RoomBuildUI:**
- Location: `scripts/room_building/RoomBuildUI.gd`
- Triggers: Build mode active, screen input events
- Responsibilities:
  - Room type button creation from registry
  - Screen-space drawing and placement visualization
  - Input validation before emitting signals
  - Color-coded feedback (valid/invalid placements)

**Patron Spawner:**
- Location: `scripts/Spawner.gd`
- Triggers: Timer elapsed (configured on spawner.tscn node)
- Responsibilities:
  - Instance patron.tscn at marker positions
  - Register patrons with Targets singleton

## Error Handling

**Strategy:** Validation-before-action with user feedback

**Patterns:**
- Size validation in RoomBuildController.finish_box_draw() compares to RoomTypeResource min/max
- Door position validation in DoorOperation.is_valid_door_position() checks wall adjacency
- Furniture placement validation in CollisionOperation.can_place_furniture() checks bounds and occupancy
- Final room validation in ValidationOperation.validate_complete() checks all constraints (door count, required furniture)
- Invalid placements show errors via RoomBuildUI.show_validation_errors() with colored feedback on canvas

## Cross-Cutting Concerns

**Logging:** Console output via push_warning/push_error for initialization and state transitions (e.g., "RoomBuildController: UI not found!")

**Validation:** Multi-stage approach:
- RoomInstance data model maintains consistency (bounds, occupancy)
- Operations validate before modifying
- RoomBuildController final validation before room completion

**Coordinate Systems:** All grid operations use Vector2i tile coordinates, with utilities:
- IsometricMath.screen_to_tile() for UI input
- IsometricMath.tile_to_screen() for rendering feedback
- IsometricMath.ui_to_tilemap_coords() for tilemap visual placement

**Signal Flow:** Controllers emit signals for high-level state changes; UI connects to these for state updates:
- RoomBuildController.state_changed → UI updates mode (drawing, doors, furniture)
- RoomBuildController.room_completed → Main exits build mode
- Targets.navigation_changed → All patrons recalculate paths

---

*Architecture analysis: 2026-01-20*
