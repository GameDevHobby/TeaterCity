# Architecture: Room Editing and Persistence Integration

**Project:** TheaterCity
**Researched:** 2026-01-21
**Confidence:** HIGH

## Executive Summary

Room editing and persistence must integrate with TheaterCity's existing state-machine-driven build system. The architecture extends the current RoomBuildController state machine with new editing states, adds a RoomManager singleton to track room instances, and implements serialization for the RefCounted RoomInstance data model. The key insight: **treat editing as a parallel workflow to building**, not a modification of the build workflow.

## Current Architecture Analysis

### Existing Components (Do Not Modify Core Logic)

**RoomBuildController** (State Machine Orchestrator)
- States: `idle` → `select_room` → `draw_box` → `place_doors` → `place_furniture` → `idle`
- Owns `current_room: RoomInstance` during build
- Emits `room_completed(room: RoomInstance)` signal
- Uses operations pattern for validation and visual creation

**RoomInstance** (RefCounted Data Model)
- Properties: `id`, `room_type_id`, `bounding_box`, `walls`, `doors[]`, `furniture[]`
- Inner classes: `DoorPlacement`, `FurniturePlacement`
- Signals: `placement_changed`
- **Critical**: RefCounted, not a Node. Pure data.

**Operations Pattern** (Stateless RefCounted Helpers)
- `WallOperation`: Generates walls, creates visuals on TileMapLayer
- `DoorOperation`: Validates positions, creates visuals
- `FurnitureOperation`: Creates visual nodes from FurniturePlacement
- `CollisionOperation`: Validates furniture placement
- `NavigationOperation`: Updates navigation mesh
- **Critical**: Operations are stateless. They operate on data, emit no signals.

**Visual Layer**
- `tilemap_layer: TileMapLayer` - Wall/door visuals (terrain autotiling)
- `ground_tilemap_layer: TileMapLayer` - Navigation mesh (cleared under furniture)
- `furniture_visuals: Node2D` - Container for furniture scene instances
- **Critical**: Visuals created AFTER room completion, not during build

### Data Flow (Current)

```
User Input (RoomBuildUI)
    ↓ signals
RoomBuildController (state machine)
    ↓ creates/modifies
RoomInstance (pure data)
    ↓ on completion
Operations (stateless)
    ↓ creates
Visual Nodes (TileMapLayer, Node2D children)
```

**Key insight**: RoomInstance is the source of truth. Visuals are derived from it.

## Integration Architecture

### Component Responsibilities

| Component | Responsibility | Modification Type |
|-----------|---------------|-------------------|
| RoomBuildController | Build workflow only | **Minor extension** (add edit mode toggle) |
| **RoomManager** (NEW) | Track completed rooms, selection, persistence | **New singleton** |
| **RoomEditController** (NEW) | Edit workflow state machine | **New controller** |
| **SelectionManager** (NEW) | Visual selection feedback | **New helper** |
| **RoomSerializer** (NEW) | Serialize/deserialize RoomInstance | **New utility** |
| RoomInstance | Data model | **Add serialization methods** |
| Operations | Stateless helpers | **Add deletion operations** |

### RoomManager (New Singleton)

**Purpose**: Track all completed room instances and their visual nodes.

**Pattern**: Autoload singleton with registry pattern (similar to RoomTypeRegistry).

```gdscript
# scripts/storage/RoomManager.gd
extends Node

signal room_added(room: RoomInstance)
signal room_removed(room_id: String)
signal room_selected(room: RoomInstance)
signal room_deselected()

var _rooms: Dictionary = {}  # room_id -> RoomInstance
var _room_visuals: Dictionary = {}  # room_id -> Dictionary{walls: Array[Vector2i], furniture: Array[Node2D]}
var _selected_room_id: String = ""

func register_room(room: RoomInstance, visuals: Dictionary) -> void
func unregister_room(room_id: String) -> void
func get_room(room_id: String) -> RoomInstance
func get_all_rooms() -> Array[RoomInstance]
func get_room_at_position(tile_pos: Vector2i) -> RoomInstance
func select_room(room_id: String) -> void
func deselect_room() -> void
func get_selected_room() -> RoomInstance
```

**Integration point**: `RoomBuildController._on_complete_pressed()` calls `RoomManager.register_room()` after creating visuals.

**Why singleton**:
- Multiple controllers need access (build, edit, save/load)
- Lifetime matches game session
- Natural integration point for persistence

### RoomEditController (New State Machine)

**Purpose**: Parallel state machine for editing existing rooms.

**States**:
```
idle → select_room → edit_mode → idle
                          ↓
                    [add_furniture, remove_furniture, remove_room]
```

**Key difference from RoomBuildController**:
- Operates on existing RoomInstance from RoomManager
- No box drawing or wall placement
- Can add/remove furniture
- Can delete entire room

```gdscript
# scripts/room_building/RoomEditController.gd
class_name RoomEditController
extends Node

signal edit_started(room: RoomInstance)
signal edit_completed(room: RoomInstance)
signal room_deleted(room_id: String)

var current_room: RoomInstance  # Reference from RoomManager
var state_name: String = "idle"

func start_edit_mode(room: RoomInstance) -> void
func add_furniture_to_room(furniture: FurnitureResource, position: Vector2i, rotation: int) -> void
func remove_furniture_at(position: Vector2i) -> void
func delete_room() -> void
func end_edit_mode() -> void
```

**Integration pattern**: Shares operations with RoomBuildController, but manages different lifecycle.

### Selection System

**Visual feedback for room selection**.

**Pattern**: Helper class that highlights room boundaries and furniture.

```gdscript
# scripts/room_building/SelectionManager.gd
class_name SelectionManager
extends RefCounted

signal selection_changed(room: RoomInstance)

func highlight_room(room: RoomInstance, tilemap_layer: TileMapLayer) -> void
func unhighlight_room(tilemap_layer: TileMapLayer) -> void
func get_room_at_click(tile_pos: Vector2i) -> RoomInstance
```

**Implementation**:
- Draw colored overlay on walls using TileMapLayer modulate or separate overlay layer
- Add outline to furniture using shader or duplicate sprites with outline
- Highlight on hover, confirm on click

**Alternative approach**: Use Area2D on furniture for click detection (heavier, but more precise).

### Serialization Architecture

**Challenge**: RoomInstance is RefCounted with inner classes and FurnitureResource references.

**Solution**: Dictionary-based serialization with resource paths.

```gdscript
# scripts/storage/RoomSerializer.gd
class_name RoomSerializer
extends RefCounted

static func serialize_room(room: RoomInstance) -> Dictionary
static func deserialize_room(data: Dictionary) -> RoomInstance
static func save_to_file(rooms: Array[RoomInstance], path: String) -> Error
static func load_from_file(path: String) -> Array[RoomInstance]
```

**Serialization format** (Dictionary):
```gdscript
{
    "id": "room_1",
    "room_type_id": "lobby",
    "bounding_box": {"x": 0, "y": 0, "w": 6, "h": 6},
    "walls": [[0, 0], [1, 0], ...],
    "doors": [
        {"position": [2, 0], "direction": 0}
    ],
    "furniture": [
        {
            "furniture_id": "seating_bench",
            "position": [2, 2],
            "rotation": 0
        }
    ]
}
```

**Storage method**: `FileAccess.store_var()` with binary format.

**Rationale**:
- RefCounted can't use Resource serialization directly
- Dictionary serialization is Godot-native and type-safe
- Binary format is compact and secure
- Furniture references stored as IDs, resolved via FurnitureRegistry on load

**File location**: `user://saves/rooms.dat`

**When to save**:
- Auto-save on room completion (build)
- Auto-save on edit completion
- Manual save button
- Auto-save on room deletion
- **Not** real-time (would cause TileMap update thrashing)

## Component Integration Map

```
┌─────────────────────────────────────────────────────────────┐
│ Main.gd (Scene Root)                                        │
│  - Owns build_button, edit_button                          │
│  - Toggles between RoomBuildController and RoomEditController│
└─────────────────────────────────────────────────────────────┘
                    ↓                        ↓
        ┌───────────────────────┐   ┌──────────────────────┐
        │ RoomBuildController   │   │ RoomEditController   │
        │ (Existing + Minor)    │   │ (NEW)                │
        │                       │   │                      │
        │ States:               │   │ States:              │
        │  idle → select_room   │   │  idle → select_room  │
        │  → draw_box           │   │  → edit_mode         │
        │  → place_doors        │   │                      │
        │  → place_furniture    │   │ Operations:          │
        │                       │   │  - add_furniture     │
        │ On complete:          │   │  - remove_furniture  │
        │  → register to        │   │  - delete_room       │
        │     RoomManager       │   │                      │
        └───────────────────────┘   └──────────────────────┘
                    ↓                        ↓
                ┌────────────────────────────────┐
                │ RoomManager (NEW Singleton)    │
                │  - Registry of RoomInstance    │
                │  - Registry of visual nodes    │
                │  - Selection state             │
                │  - get_room_at_position()      │
                └────────────────────────────────┘
                    ↓                        ↓
        ┌───────────────────────┐   ┌──────────────────────┐
        │ RoomInstance          │   │ Visual Nodes         │
        │ (Data Model)          │   │  - TileMapLayer      │
        │                       │   │  - Node2D children   │
        │ + to_dict()           │   │                      │
        │ + from_dict()         │   │                      │
        └───────────────────────┘   └──────────────────────┘
                    ↓
        ┌───────────────────────┐
        │ RoomSerializer (NEW)  │
        │  - serialize_room()   │
        │  - deserialize_room() │
        │  - save_to_file()     │
        │  - load_from_file()   │
        └───────────────────────┘
                    ↓
        ┌───────────────────────┐
        │ user://saves/rooms.dat│
        │ (Binary file)         │
        └───────────────────────┘
```

## State Machine Integration

### Build Mode (Existing - Minor Changes)

```
idle
  ↓ (build button pressed)
select_room
  ↓ (room type selected)
draw_box
  ↓ (valid box drawn)
place_doors
  ↓ (doors done)
place_furniture
  ↓ (complete pressed + valid)
idle + RoomManager.register_room()  ← NEW: register room
```

**Change**: Add `RoomManager.register_room(current_room, visuals)` call in `_on_complete_pressed()` after visual creation.

### Edit Mode (New State Machine)

```
idle
  ↓ (edit button pressed)
select_room (click to select)
  ↓ (room selected)
edit_mode (show edit UI)
  ↓ (furniture actions)
  ├─ add_furniture (place new furniture)
  ├─ remove_furniture (click furniture to delete)
  └─ delete_room (delete entire room)
  ↓ (done button pressed)
idle + RoomManager update
```

**Key interactions**:
- Selection uses `RoomManager.get_room_at_position(tile_pos)`
- Edits modify RoomInstance in RoomManager
- Visual updates use same Operations as build mode
- Auto-save after edit completion

### Mode Switching

**Problem**: Can't build and edit simultaneously.

**Solution**: Mutually exclusive modes via Main.gd.

```gdscript
# scripts/Main.gd (modification)
var _mode: String = "idle"  # "idle", "build", "edit"

func _on_build_button_pressed() -> void:
    if _mode == "edit":
        _exit_edit_mode()
    _mode = "build"
    room_build_controller.start_build_mode()

func _on_edit_button_pressed() -> void:
    if _mode == "build":
        _exit_build_mode()
    _mode = "edit"
    # Show room selection cursor
```

## Deletion Architecture

### Furniture Deletion

**User flow**: Click furniture in edit mode → furniture disappears.

**Implementation**:
1. User clicks tile position
2. `RoomEditController` finds furniture at position via `RoomInstance.furniture`
3. Remove from `RoomInstance.furniture` array
4. Find visual node via `RoomManager._room_visuals[room_id].furniture`
5. Call `node.queue_free()`
6. Update navigation mesh via `NavigationOperation`

**Operation needed**: None (direct array manipulation).

### Room Deletion

**User flow**: Select room → click delete button → room disappears.

**Implementation**:
1. User confirms deletion
2. `RoomEditController.delete_room()` calls `RoomManager.unregister_room(room_id)`
3. RoomManager:
   - Removes RoomInstance from registry
   - Deletes visual nodes (`queue_free()` on all furniture, `erase_cell()` on tilemap)
   - Updates navigation mesh
   - Emits `room_removed` signal
4. Auto-save

**Operation needed**: `DeletionOperation` to centralize cleanup logic.

```gdscript
# scripts/room_building/operations/DeletionOperation.gd
class_name DeletionOperation
extends RefCounted

func delete_room_visuals(room: RoomInstance, tilemap_layer: TileMapLayer, furniture_parent: Node2D) -> void
func delete_furniture_visual(furniture_node: Node2D, tilemap_layer: TileMapLayer) -> void
```

## Persistence Integration Points

### Save Triggers

| Event | Auto-save | Manual Save |
|-------|-----------|-------------|
| Room completed | ✓ | ✓ |
| Edit completed | ✓ | ✓ |
| Room deleted | ✓ | ✓ |
| Game exit | ✓ | ✓ |
| User button | - | ✓ |

**Implementation**: `RoomManager` listens to own signals, calls `RoomSerializer.save_to_file()`.

```gdscript
# In RoomManager._ready()
room_added.connect(_auto_save)
room_removed.connect(_auto_save)
# Edit completion signal from RoomEditController
```

### Load Sequence

**When**: Game start (`Main._ready()` or dedicated load function).

**Sequence**:
1. `RoomSerializer.load_from_file()` → `Array[RoomInstance]`
2. For each RoomInstance:
   - Resolve `furniture_id` strings to `FurnitureResource` via `FurnitureRegistry`
   - Create visuals via operations (same as build completion)
   - Register with `RoomManager`
3. Update navigation mesh for entire level

**Error handling**:
- Missing furniture IDs: Log warning, skip furniture
- Invalid room types: Log warning, skip room
- File not found: Start with empty level

## Build Order and Dependencies

### Phase 1: Foundation (No Dependencies)

**Goal**: Enable room tracking and selection.

**Components**:
- RoomManager singleton (empty registry)
- Modify RoomBuildController to register completed rooms
- Basic room selection (click detection via bounding box check)

**Test**: Build room → room appears in RoomManager → click room → selection feedback.

### Phase 2: Serialization (Depends on Phase 1)

**Goal**: Save and load rooms.

**Components**:
- RoomSerializer (serialize/deserialize)
- RoomInstance.to_dict() / RoomInstance.from_dict()
- Save/load buttons in UI
- Auto-save on room completion

**Test**: Build room → save → restart game → load → room appears.

### Phase 3: Editing (Depends on Phase 1, 2)

**Goal**: Modify existing rooms.

**Components**:
- RoomEditController state machine
- Furniture addition (reuse FurnitureOperation)
- Furniture deletion (DeletionOperation)
- Edit UI panel

**Test**: Select room → add furniture → furniture appears → save → load → furniture persists.

### Phase 4: Deletion (Depends on Phase 1, 2, 3)

**Goal**: Delete rooms and furniture.

**Components**:
- DeletionOperation
- Room deletion flow in RoomEditController
- Confirmation dialog (prevent accidental deletion)

**Test**: Select room → delete → room disappears → save → load → room stays deleted.

### Dependency Graph

```
Phase 1 (RoomManager + Selection)
    ↓
Phase 2 (Serialization) + Phase 3 (Editing)
    ↓
Phase 4 (Deletion)
```

**Rationale**: Serialization and editing can be developed in parallel. Deletion requires both.

## Architecture Patterns Summary

### Patterns to Follow (Existing Codebase)

1. **State Machine Pattern**: Use explicit `state_name` string, emit `state_changed` signal
2. **Operations Pattern**: Stateless RefCounted helpers for complex logic
3. **Singleton Registry**: Autoload nodes for global state (RoomTypeRegistry, FurnitureRegistry, Targets)
4. **Signal-Based Communication**: Controllers emit signals, Main.gd or managers listen
5. **Data/Visual Separation**: RoomInstance (data) → Operations (transform) → Visual Nodes

### New Patterns for Editing/Persistence

1. **Manager Singleton**: RoomManager tracks instances and selection (like Targets singleton)
2. **Parallel State Machines**: Build and edit are separate controllers, not merged states
3. **Registry with Visuals**: Track both data (RoomInstance) and visuals (Node2D) in parallel dictionaries
4. **Dictionary Serialization**: Convert RefCounted to Dictionary for FileAccess.store_var()
5. **Lazy Visual Creation**: Visuals created from data on load, not stored directly

## Anti-Patterns to Avoid

### 1. Merging Edit into Build State Machine

**Problem**: Build workflow is linear (box → doors → furniture → done). Edit workflow is iterative (select → modify → modify → modify → done).

**Solution**: Separate RoomEditController with different state flow.

### 2. Storing Visual Nodes in Save File

**Problem**: Nodes can't be serialized with FileAccess.store_var(), Resource serialization is complex.

**Solution**: Store RoomInstance data only, recreate visuals on load.

### 3. Real-Time Auto-Save

**Problem**: TileMap updates and file I/O on every furniture placement causes lag.

**Solution**: Batch save on edit completion, not per-action.

### 4. Global Edit State

**Problem**: Tracking "which furniture is selected" in multiple places causes sync issues.

**Solution**: RoomManager owns selection state, emits signals for UI updates.

### 5. Modifying RoomInstance During Build

**Problem**: Current build flow modifies `current_room` directly, then creates visuals. If we add persistence mid-build, partial rooms get saved.

**Solution**: Only register rooms with RoomManager after completion validation passes.

## Testing Strategy

### Unit Tests (GUT Framework)

**RoomManager**:
- Register/unregister rooms
- Get room at position (boundary checking)
- Selection state management

**RoomSerializer**:
- Serialize → deserialize → equality check
- Handle missing furniture IDs gracefully
- Save to file → load from file → equality check

**RoomEditController**:
- State transitions (idle → select → edit → idle)
- Furniture addition (valid vs. invalid positions)
- Furniture deletion (by position)

### Integration Tests

**Build → Save → Load Flow**:
1. Build valid room with furniture
2. Save via RoomSerializer
3. Clear scene
4. Load from file
5. Assert room data matches original
6. Assert visuals exist and positioned correctly

**Edit → Save → Load Flow**:
1. Load room from file
2. Enter edit mode
3. Add furniture
4. Save
5. Reload
6. Assert furniture persists

## Performance Considerations

### Memory

**RoomInstance size**: ~100-500 bytes per room (depending on furniture count).

**Visual nodes**: ~1-10 KB per room (TileMap cells + furniture scenes).

**Estimate**: 100 rooms = ~50 KB data + ~1 MB visuals. Negligible for mobile.

### File I/O

**Save time**: FileAccess.store_var() with Dictionary is ~1-5ms per room. 100 rooms = ~500ms max.

**Optimization**: Save asynchronously using WorkerThreadPool in Godot 4 if needed (unlikely for mobile game scale).

### TileMap Updates

**Problem**: TileMap.set_cells_terrain_connect() triggers autotiling calculation, which is O(n) in cell count.

**Mitigation**:
- Batch all erase_cell() calls before set_cells_terrain_connect()
- WallOperation already does this correctly
- DeletionOperation must follow same pattern

## Godot 4 API Notes

### FileAccess Changes (Godot 4)

**Godot 3**: `File.new()` → `File.open()` → `store_var()`

**Godot 4**: `FileAccess.open()` → `store_var()` (static method)

```gdscript
# Godot 4 correct syntax
var file = FileAccess.open("user://saves/rooms.dat", FileAccess.WRITE)
if file:
    file.store_var(data)
    file.close()
```

### TileMapLayer vs TileMap (Godot 4.5)

**Current code uses**: `TileMapLayer` (Godot 4.2+)

**Correct**: TileMapLayer is the new API. Each layer is a separate node, not a layer property.

### Navigation Changes (Godot 4)

**NavigationMesh baking**: Automatic on TileMapLayer with navigation enabled.

**Manual update**: `NavigationServer2D.region_bake_navigation_polygon()` if needed.

**Current code**: NavigationOperation handles this correctly.

## Sources and Confidence Assessment

| Topic | Confidence | Primary Sources |
|-------|------------|-----------------|
| Existing architecture | HIGH | Code analysis (RoomBuildController, RoomInstance, Operations) |
| State machine patterns | HIGH | Existing code + [GDQuest FSM Tutorial](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) |
| Serialization approach | HIGH | [GDQuest Save Systems](https://www.gdquest.com/library/save_game_godot4/) + [Godot Docs](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html) |
| RefCounted serialization | MEDIUM | [RefSerializer GitHub](https://github.com/KoBeWi/Godot-Ref-Serializer) (third-party), Dictionary approach is standard |
| Selection patterns | MEDIUM | Community discussions, [Runtime Debug Tools](https://github.com/bbbscarter/GodotRuntimeDebugTools) |
| Manager singleton pattern | HIGH | Existing Targets singleton in codebase |

**Overall confidence**: HIGH for integration architecture, MEDIUM for specific UI patterns.

## Recommendations for Roadmap

### Phase Structure

1. **Phase 1: Room Tracking** - RoomManager singleton, registration from build controller
2. **Phase 2: Serialization** - RoomSerializer, save/load functionality
3. **Phase 3: Selection** - Click to select rooms, visual feedback
4. **Phase 4: Furniture Editing** - Add/remove furniture from existing rooms
5. **Phase 5: Room Deletion** - Delete entire rooms with confirmation

### Research Flags

**Phase 3 (Selection)**: May need deeper research into hover/click detection patterns. Consider Area2D vs. tile-based click detection tradeoffs.

**Phase 4 (Furniture Editing)**: Reuses existing operations, unlikely to need additional research.

**Phase 5 (Room Deletion)**: Standard pattern, but confirmation UI needs UX consideration.

### Files to Create (New)

- `scripts/storage/RoomManager.gd` (singleton)
- `scripts/storage/RoomSerializer.gd` (static utility)
- `scripts/room_building/RoomEditController.gd` (controller)
- `scripts/room_building/SelectionManager.gd` (helper)
- `scripts/room_building/operations/DeletionOperation.gd` (operation)

### Files to Modify (Existing)

- `scripts/Main.gd` (add edit mode toggle)
- `scripts/room_building/RoomBuildController.gd` (add RoomManager.register_room() call)
- `scripts/storage/RoomInstance.gd` (add to_dict/from_dict methods)

**Minimal surface area**: Only 2 existing files modified, preserves existing build flow.
