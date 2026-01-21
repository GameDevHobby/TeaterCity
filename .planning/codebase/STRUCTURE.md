# Codebase Structure

**Analysis Date:** 2026-01-20

## Directory Layout

```
project-root/
├── scripts/                           # Core game logic and systems
│   ├── Main.gd                       # Main scene controller
│   ├── Patron.gd                     # Patron NPC with navigation
│   ├── Spawner.gd                    # Patron spawner
│   ├── Target.gd                     # Navigation target (static scene)
│   ├── Targets.gd                    # Targets singleton autoload
│   ├── data/                         # Resource definitions and registries
│   │   ├── RoomTypeRegistry.gd       # Registry for room type definitions
│   │   ├── RoomTypeResource.gd       # Room type data model
│   │   ├── FurnitureRegistry.gd      # Registry for furniture definitions
│   │   ├── FurnitureResource.gd      # Furniture data model
│   │   └── FurnitureRequirement.gd   # Requirement constraint model
│   ├── room_building/                # Room building system
│   │   ├── RoomBuildController.gd    # Main workflow orchestrator
│   │   ├── RoomBuildUI.gd            # UI input and rendering (575 lines)
│   │   ├── operations/               # Stateless spatial operations
│   │   │   ├── WallOperation.gd      # Generate and place walls
│   │   │   ├── DoorOperation.gd      # Validate and place doors
│   │   │   ├── FurnitureOperation.gd # Create furniture visuals and previews
│   │   │   ├── CollisionOperation.gd # Collision and tile occupancy (121 lines)
│   │   │   ├── ValidationOperation.gd # Final room constraint validation
│   │   │   └── NavigationOperation.gd # Update navigation polygons
│   │   └── ui/                       # Drawing and state management
│   │       ├── RoomBuildDrawing.gd   # Static drawing helpers
│   │       └── states/               # Build mode state machines
│   │           ├── box_drawing_state.gd
│   │           ├── door_placement_state.gd
│   │           ├── furniture_placement_state.gd
│   │           └── idle_build_state.gd
│   ├── storage/                      # Data models
│   │   └── RoomInstance.gd           # Room state and furniture/door tracking
│   └── utils/                        # Shared utilities
│       ├── IsometricMath.gd          # Screen↔tile↔world coordinate conversion
│       ├── RotationHelper.gd         # Footprint and rotation transformations
│       └── UIStyleHelper.gd          # Theme and button styling helpers
├── objects/                          # Scene instances and prefabs
│   ├── patron/                       # Patron NPC
│   │   ├── patron.tscn               # Patron scene with animations
│   │   └── Patron.png                # Sprite sheet (18x18 multi-frame)
│   ├── furniture/                    # Furniture scene prefabs
│   │   ├── furniture_base.gd         # Base class for furniture instances
│   │   ├── furniture_base.tscn       # Base furniture scene
│   │   ├── counter.tscn              # Counter furniture
│   │   ├── seat.tscn                 # Seat furniture
│   │   ├── seating_bench.tscn        # Bench seating
│   │   ├── stall.tscn                # Stall furniture
│   │   ├── toilet.tscn               # Toilet fixture
│   │   ├── sink.tscn                 # Sink fixture
│   │   ├── screen.tscn               # Display screen
│   │   ├── register.tscn             # Cash register
│   │   ├── speaker.tscn              # Audio speaker
│   │   ├── dispenser.tscn            # Item dispenser
│   │   ├── display_case.tscn         # Display case
│   │   └── mirror.tscn               # Mirror
│   ├── spawner.tscn                  # Patron spawner (timer + marker2d)
│   └── target.tscn                   # Navigation target point
├── data/                             # Game configuration resources
│   ├── configs/                      # Registry resource definitions
│   │   ├── room_type_registry.tres   # Room type definitions
│   │   ├── furniture_registry.tres   # Furniture definitions
│   │   └── populate_registries.gd    # Editor script to populate from .tres
│   ├── room_types/                   # Individual room type .tres files
│   └── furniture/                    # Individual furniture .tres files
├── resources/                        # Art assets (textures, tilesets)
│   ├── tiles/
│   │   ├── RetroDiner_Tiles_128x128/    # Floor tile assets
│   │   ├── RetroDiner_Walls_128x128/    # Wall tile assets
│   │   └── wall_tileset.tres            # Compiled tileset with terrain setup
│   ├── IIP - Outlined/                  # Secondary asset pack
│   │   ├── floors/
│   │   ├── furniture/
│   │   ├── walls/
│   │   └── Props/
│   ├── Pixel-Isometric-Modern-Interior-Free_v.1.01/  # Additional assets
│   └── objects/                      # Sprite and model assets
├── demo/                             # LimboAI addon demo content
│   ├── agents/                       # Agent scripts and scenes
│   ├── ai/                           # Behavior tree definitions
│   │   ├── tasks/                    # Custom BT tasks
│   │   └── trees/                    # BT resource files
│   ├── assets/                       # Demo fonts and graphics
│   └── scenes/                       # Demo scenes
├── test/                             # Test suite using Gut framework
│   ├── unit/                         # Unit tests
│   │   ├── test_room_instance.gd
│   │   ├── test_wall_operation.gd
│   │   ├── test_door_operation.gd
│   │   ├── test_collision_operation.gd
│   │   ├── test_validation_operation.gd
│   │   ├── test_patron.gd
│   │   └── test_targets.gd
│   └── integration/                  # Integration tests
│       ├── test_room_build_flow.gd
│       └── test_patron_spawner_flow.gd
├── addons/                           # Third-party Godot plugins
│   ├── limboai/                      # LimboAI for behavior trees
│   ├── ppc/                          # Pan/pinch camera controller
│   ├── gut/                          # Unit testing framework
│   └── godot_visualstudio_debugger/  # VS Code debugging support
├── Main.tscn                         # Root scene for the game
├── project.godot                     # Godot project configuration
├── CLAUDE.md                         # This file - Claude AI guidance
└── .planning/                        # GSD planning documentation
    └── codebase/
        ├── ARCHITECTURE.md           # (this analysis)
        └── STRUCTURE.md              # (this analysis)
```

## Directory Purposes

**scripts/:**
- Purpose: All game logic, controllers, and systems
- Contains: GDScript source code organized by system
- Key files: Main.gd, RoomBuildController.gd, Patron.gd

**scripts/data/:**
- Purpose: Resource definition classes and registries
- Contains: RoomTypeResource, FurnitureResource, and their registries
- Key files: RoomTypeRegistry.gd (lazy loads room_type_registry.tres), FurnitureRegistry.gd

**scripts/room_building/:**
- Purpose: Room building system orchestration and UI
- Contains: Main controller, UI handler, stateless operations, state machines
- Key files: RoomBuildController.gd (166 lines), RoomBuildUI.gd (575 lines)

**scripts/room_building/operations/:**
- Purpose: Composable stateless operations for grid manipulation
- Contains: 6 operation classes for walls, doors, furniture, collision detection, validation, navigation
- Pattern: RefCounted classes with static helper methods; no instance state

**scripts/storage/:**
- Purpose: Data models for persisted game state
- Contains: RoomInstance.gd with inner classes for DoorPlacement and FurniturePlacement
- Key responsibility: Grid occupancy tracking, cost calculations

**scripts/utils/:**
- Purpose: Shared utilities across layers
- Contains: Coordinate conversion (IsometricMath), rotation math (RotationHelper), UI styling (UIStyleHelper)

**objects/:**
- Purpose: Scene prefabs and visual assets
- Contains: Patron NPC with animations, furniture pieces, spawner, navigation targets
- Structure: Each prefab in its own .tscn file, optionally with attached scripts

**data/configs/:**
- Purpose: Compiled registry resources and editor scripts
- Contains: room_type_registry.tres, furniture_registry.tres (ResourceLoader paths)
- Files: `res://data/configs/room_type_registry.tres`, `res://data/configs/furniture_registry.tres`

**resources/:**
- Purpose: Art assets (textures, tilesets)
- Contains: Multiple art packs (RetroDiner, IIP - Outlined, Pixel-Isometric)
- Key files: wall_tileset.tres (compiled tileset with terrain auto-connect setup)

**test/**
- Purpose: Automated test suite
- Contains: Unit tests (data models, operations) and integration tests (workflows)
- Framework: Gut framework (runs via Godot editor or CLI)

## Key File Locations

**Entry Points:**
- `Main.tscn`: Root scene for game
- `scripts/Main.gd`: Main controller, handles build mode toggle, camera control
- `scripts/room_building/RoomBuildController.gd`: Workflow orchestrator

**Configuration:**
- `project.godot`: Godot project settings
- `data/configs/room_type_registry.tres`: Room type definitions (ResourceLoader path)
- `data/configs/furniture_registry.tres`: Furniture definitions (ResourceLoader path)

**Core Logic:**
- `scripts/storage/RoomInstance.gd`: Room data model (walls, doors, furniture)
- `scripts/Patron.gd`: Patron NPC with NavigationAgent2D
- `scripts/Targets.gd`: Singleton for target registration and navigation updates

**Room Building System:**
- `scripts/room_building/RoomBuildController.gd`: State machine and operation orchestrator
- `scripts/room_building/RoomBuildUI.gd`: Input handling and UI rendering
- `scripts/room_building/operations/WallOperation.gd`: Wall generation and visuals
- `scripts/room_building/operations/CollisionOperation.gd`: Placement validation
- `scripts/room_building/operations/ValidationOperation.gd`: Final room constraints

**Testing:**
- `test/unit/test_room_instance.gd`: Tests RoomInstance data model
- `test/unit/test_collision_operation.gd`: Tests placement logic
- `test/integration/test_room_build_flow.gd`: Tests full build workflow

## Naming Conventions

**Files:**
- Scripts: `PascalCase.gd` (class_name matches filename, e.g., `Patron.gd` defines `class_name Patron`)
- Scenes: `snake_case.tscn` (e.g., `patron.tscn`, `furniture_base.tscn`)
- Resources: `snake_case.tres` (e.g., `room_type_registry.tres`)
- Tests: `test_*.gd` (e.g., `test_wall_operation.gd` extends GutTest)

**Directories:**
- Operation subdirectory: lowercase `operations/` (contains operation classes)
- UI subdirectory: lowercase `ui/` (contains UI-specific code)
- State machines: lowercase `states/` (contains state scripts)

**Classes:**
- Public classes: PascalCase (e.g., `RoomBuildController`, `WallOperation`)
- Inner classes: PascalCase (e.g., `RoomInstance.DoorPlacement`, `CollisionOperation.CollisionResult`)
- Static utilities: PascalCase (e.g., `IsometricMath.screen_to_tile()`)

**Methods and Variables:**
- Public methods: snake_case (e.g., `add_door()`, `get_total_cost()`)
- Private methods: _snake_case prefix (e.g., `_on_room_type_selected()`, `_validate_size()`)
- Exported properties: snake_case (e.g., `@export var tilemap_layer`)

## Where to Add New Code

**New Feature (e.g., room upgrades, cosmetics):**
- Primary code: Create operation class in `scripts/room_building/operations/UpgradeOperation.gd`
- Data model: Add fields to `scripts/storage/RoomInstance.gd` or create new RefCounted class
- UI: Add buttons/panels to `scripts/room_building/RoomBuildUI.gd` or separate UI state in `scripts/room_building/ui/states/`
- Tests: `test/unit/test_upgrade_operation.gd`
- Signal: Emit from RoomBuildController or operation as needed

**New Component/Module (e.g., room customization UI):**
- Implementation: `scripts/room_building/ui/RoomCustomizer.gd`
- Controller integration: Connect via RoomBuildController or Main
- Scene: `objects/ui_customizer.tscn` if complex
- Tests: `test/unit/test_room_customizer.gd`

**New Furniture Type:**
- Scene: `objects/furniture/new_item.tscn` (extending `furniture_base.tscn`)
- Resource: `data/furniture/new_item.tres` (FurnitureResource with size, cost, access_offsets)
- Add to: `data/configs/furniture_registry.tres` (add to FurnitureRegistry.room_types array)
- Optionally: Add placement constraints to CollisionOperation if special rules needed

**New Room Type:**
- Resource: `data/room_types/new_room.tres` (RoomTypeResource with min_size, max_size, door requirements)
- Add to: `data/configs/room_type_registry.tres` (add to RoomTypeRegistry.room_types array)
- Constraints: Edit allowed_furniture and required_furniture arrays in resource

**Utilities:**
- Shared helpers: `scripts/utils/NewHelper.gd` (static methods only)
- Coordinate math: Add to `scripts/utils/IsometricMath.gd` (consolidate all coordinate conversions here)
- UI styling: Add to `scripts/utils/UIStyleHelper.gd` (reusable style creation)

**Tests:**
- Unit tests: `test/unit/test_*.gd` (extends GutTest, tests single class/function)
- Integration tests: `test/integration/test_*_flow.gd` (tests multiple systems interacting)
- Naming: `func test_descriptive_behavior() -> void:`
- Fixtures: Create test data in `before_each()` block, cleanup in `after_each()`

## Special Directories

**addons/:**
- Purpose: Third-party Godot plugins (not custom code)
- Generated: No
- Committed: Yes (included in repo)
- Notable: limboai/ (behavior trees), ppc/ (camera), gut/ (testing)

**demo/:**
- Purpose: LimboAI addon example content
- Generated: No
- Committed: Yes
- Note: Can be removed if LimboAI addon not used for patrons

**.godot/:**
- Purpose: Godot editor cache and imported assets
- Generated: Yes
- Committed: No (gitignored)
- Cache location: Reimport resources, shader cache, metadata

**.planning/:**
- Purpose: GSD orchestrator planning documents
- Generated: Yes (by `/gsd:map-codebase`)
- Committed: Yes
- Documents: ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, CONCERNS.md, INTEGRATIONS.md, STACK.md

---

*Structure analysis: 2026-01-20*
