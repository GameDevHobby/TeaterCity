# Technology Stack: Room Editing & Persistence

**Project:** TheaterCity
**Milestone:** Room editing and persistence
**Researched:** 2026-01-21
**Overall confidence:** HIGH

## Executive Summary

Adding room editing and persistence to existing Godot 4.5 theater simulation requires three technical layers: (1) selection/manipulation UI for touch, (2) serialization of RoomInstance data model, and (3) file I/O to user://. This research focuses on what to ADD to your existing system, not re-architect it.

**Key recommendation:** Use FileAccess.store_var() for persistence (NOT JSON) because your RoomInstance already uses Vector2i, Rect2i, and other Godot types that store_var() handles natively. JSON requires manual conversion of every Vector2i/Rect2i, adding complexity without benefit.

## Core Persistence Stack

### File I/O: FileAccess (Godot Built-in)

| Technology | Version | Purpose | Why This |
|------------|---------|---------|----------|
| FileAccess | Godot 4.5 | Read/write save files | Built-in, no dependencies |
| FileAccess.store_var() | Godot 4.5 | Serialize game data | Native support for Vector2i, Rect2i, typed arrays |
| FileAccess.get_var() | Godot 4.5 | Deserialize game data | Counterpart to store_var() |
| user:// path | Godot 4.5 | Save location | Cross-platform, sandboxed for mobile |

**Rationale:**

FileAccess.store_var() is the standard Godot 4.5 approach for game saves because it:
- **Natively supports Godot types**: Vector2i, Rect2i, typed Arrays work without conversion
- **Binary format**: Smaller file size, faster than JSON
- **Type-safe**: Preserves type information (typed arrays stay typed)
- **Zero dependencies**: Built into engine

**Why NOT JSON:**
- JSON doesn't support Vector2i, Rect2i, or any Godot built-in types
- You'd need to write manual to_dict()/from_dict() for RoomInstance, DoorPlacement, FurniturePlacement
- JSON only supports floats (no integers), requiring careful type casting
- Typed arrays become untyped when round-tripping through JSON
- More code to write, test, and maintain

Sources:
- [Save and Load: Godot 4 Cheat Sheet | GDQuest Library](https://www.gdquest.com/library/cheatsheet_save_systems/)
- [Saving/loading data :: Godot 4 Recipes](https://kidscancode.org/godot_recipes/4.x/basics/file_io/index.html)
- [FileAccess — Godot Engine (stable) documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)

### Save File Structure

**Recommended pattern:** Single save file with versioned dictionary structure.

```gdscript
# Save structure
var save_data := {
    "version": 1,  # For migration if data model changes
    "rooms": [],   # Array of serialized RoomInstance data
    "player_state": {},  # Currency, progression, etc.
    "meta": {
        "saved_at": Time.get_datetime_dict_from_system(),
        "game_version": ProjectSettings.get_setting("application/config/version")
    }
}
```

**File path:** `user://theater_save.dat`

**Why .dat extension:** Signals binary format, discourages manual editing.

**Mobile behavior:**
- Android: `/data/data/org.godotengine.[APP_NAME]/files/theater_save.dat`
- iOS: App sandbox, inaccessible to user
- Files are app-private, survive app updates, deleted on uninstall

Sources:
- [Saving games — Godot Engine (stable) documentation](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
- [File paths in Godot projects — Godot Engine documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

## Serialization Strategy

### RoomInstance Serialization

Your RoomInstance is a RefCounted class with nested classes (DoorPlacement, FurniturePlacement). FileAccess.store_var() **CANNOT directly serialize RefCounted objects** - they're not Variants.

**Solution:** Custom to_dict()/from_dict() methods.

```gdscript
# Add to RoomInstance class
func to_dict() -> Dictionary:
    return {
        "id": id,
        "room_type_id": room_type_id,
        "bounding_box": bounding_box,  # Rect2i serializes directly
        "walls": walls,  # Array[Vector2i] serializes directly
        "doors": doors.map(func(d): return {"pos": d.position, "dir": d.direction}),
        "furniture": furniture.map(func(f): return {
            "id": f.furniture.id,  # Store ID, not Resource reference
            "pos": f.position,
            "rot": f.rotation
        })
    }

static func from_dict(data: Dictionary) -> RoomInstance:
    var room = RoomInstance.new(data["id"], data["room_type_id"])
    room.bounding_box = data["bounding_box"]
    room.walls = data["walls"]

    for door_data in data["doors"]:
        room.add_door(door_data["pos"], door_data["dir"])

    for furn_data in data["furniture"]:
        var furn_resource = FurnitureRegistry.get_instance().get_furniture(furn_data["id"])
        if furn_resource:
            room.add_furniture(furn_resource, furn_data["pos"], furn_data["rot"])

    return room
```

**Key decisions:**

1. **Store furniture ID, not Resource reference**: FurnitureResource is a Resource (scene-based), can't be serialized. Store ID string, resolve via FurnitureRegistry on load.

2. **Rect2i and Vector2i serialize directly**: These are Variant-compatible types that store_var() handles natively.

3. **Typed arrays work**: `Array[Vector2i]` preserves type through store_var().

4. **Use lambdas for nested class conversion**: Inner classes (DoorPlacement, FurniturePlacement) convert to plain dictionaries.

Sources:
- [How to load and save things with Godot: a complete tutorial about serialization](https://forum.godotengine.org/t/how-to-load-and-save-things-with-godot-a-complete-tutorial-about-serialization/44515)
- [GitHub - KoBeWi/Godot-Ref-Serializer](https://github.com/KoBeWi/Godot-Ref-Serializer)
- [A brief introduction to the RefCounted class in Godot 4](https://shaggydev.com/2025/11/03/godot-refcounted/)

### Save/Load Manager Pattern

**Recommended:** Singleton autoload for centralized save/load logic.

```gdscript
# SaveManager.gd (autoload as "SaveManager")
extends Node

const SAVE_PATH := "user://theater_save.dat"
const CURRENT_VERSION := 1

func save_game(rooms: Array[RoomInstance]) -> Error:
    var save_data := {
        "version": CURRENT_VERSION,
        "rooms": rooms.map(func(r): return r.to_dict())
    }

    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Failed to open save file: %s" % FileAccess.get_open_error())
        return FileAccess.get_open_error()

    file.store_var(save_data)
    file.close()
    return OK

func load_game() -> Array[RoomInstance]:
    if not FileAccess.file_exists(SAVE_PATH):
        return []

    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("Failed to open save file: %s" % FileAccess.get_open_error())
        return []

    var save_data: Dictionary = file.get_var()
    file.close()

    # Version migration logic here
    if save_data.get("version", 0) != CURRENT_VERSION:
        push_warning("Save file version mismatch, may need migration")

    var rooms: Array[RoomInstance] = []
    for room_data in save_data.get("rooms", []):
        rooms.append(RoomInstance.from_dict(room_data))

    return rooms
```

**Why singleton:**
- Single source of truth for save path
- Centralized version migration logic
- Easy to test (mock SaveManager for tests)
- Accessible from anywhere via `SaveManager.save_game()`

Sources:
- [Saving and Loading Games in Godot 4 (with resources) | GDQuest](https://www.gdquest.com/library/save_game_godot4/)
- [How we built a flexible game save system for Godot | Talo](https://trytalo.com/blog/saves-deep-dive-godot)

## Room Selection & Manipulation Stack

### Touch Input for Selection

| Technology | Version | Purpose | Why This |
|------------|---------|---------|----------|
| Area2D | Godot 4.5 | Room hit detection | Standard for 2D object picking |
| CollisionShape2D | Godot 4.5 | Define room bounds | Matches room bounding_box |
| InputEventScreenTouch | Godot 4.5 | Mobile touch events | Native touch API |
| InputEventScreenDrag | Godot 4.5 | Drag gestures | Native drag API |

**Pattern:** Each room gets an Area2D child for selection hit-testing.

```gdscript
# RoomSelectionArea.gd
extends Area2D

signal room_selected(room: RoomInstance)
signal room_drag_started(room: RoomInstance)
signal room_drag_ended(room: RoomInstance)

var room_data: RoomInstance

func _ready() -> void:
    input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            room_selected.emit(room_data)

    elif event is InputEventScreenDrag:
        # Handle drag for resize/move
        room_drag_started.emit(room_data)
```

**Mobile consideration:** Godot's "Emulate Mouse from Touch" setting (enabled by default) means InputEventMouseButton/InputEventMouseMotion work on mobile. However, for multi-touch or gestures, use Screen events directly.

**Critical setting:** `Project Settings > Input Devices > Pointing > Emulate Mouse From Touch = true` (default). Leave enabled unless you need multi-touch.

Sources:
- [Which is the best way to handle touch screen controls and clicking objects?](https://forum.godotengine.org/t/which-is-the-best-way-to-handle-touch-screen-controls-and-clicking-objects/42209)
- [InputEventScreenTouch — Godot Engine documentation](https://docs.godotengine.org/en/stable/classes/class_inputeventscreentouch.html)
- [InputEventScreenDrag — Godot Engine documentation](https://docs.godotengine.org/en/4.4/classes/class_inputeventscreendrag.html)

### Visual Selection Feedback

**Recommendation:** Use Line2D or ColorRect overlays, NOT gizmos.

| Approach | Use Case | Why |
|----------|----------|-----|
| Line2D | Room outline highlight | Thin border around selected room |
| ColorRect | Fill tint | Semi-transparent overlay on selected room |
| Control nodes | Resize handles | Touch-friendly corner/edge handles |

**Gizmo confusion:** Editor gizmos are for Godot editor plugins, not runtime game UI. For runtime selection, use regular nodes.

```gdscript
# Selection highlight
var highlight := Line2D.new()
highlight.default_color = Color.YELLOW
highlight.width = 3.0
# Add points matching room bounding box
```

**Mobile-friendly resize handles:**
- Minimum touch target: 44x44 pixels (iOS HIG guideline)
- Use Control nodes with custom_minimum_size for corner handles
- Visual feedback: Change color on touch_down

Sources:
- [Godot Drag and Drop Tutorial: Complete Interactive Guide [2025]](https://generalistprogrammer.com/tutorials/godot-drag-and-drop-tutorial)
- iOS Human Interface Guidelines (44pt minimum touch target)

## Undo/Redo System

### UndoRedo Class (Godot Built-in)

| Technology | Version | Purpose | Why This |
|------------|---------|---------|----------|
| UndoRedo | Godot 4.5 | Action history management | Built-in, designed for this |

**Pattern:** Wrap each edit action in create_action/commit_action pair.

```gdscript
# In room editor controller
var undo_redo := UndoRedo.new()

func move_furniture(room: RoomInstance, furn_idx: int, new_pos: Vector2i) -> void:
    var old_pos := room.furniture[furn_idx].position

    undo_redo.create_action("Move Furniture")
    undo_redo.add_do_method(self, "_set_furniture_position", room, furn_idx, new_pos)
    undo_redo.add_undo_method(self, "_set_furniture_position", room, furn_idx, old_pos)
    undo_redo.commit_action()

func _set_furniture_position(room: RoomInstance, furn_idx: int, pos: Vector2i) -> void:
    room.furniture[furn_idx].position = pos
    room.placement_changed.emit()
```

**Why UndoRedo:**
- Handles action stack automatically
- get_current_action_name() for UI display
- has_undo()/has_redo() for button state
- Memento pattern built-in

**Not for save/load:** UndoRedo is for session history, not persistence. Don't serialize undo stack.

Sources:
- [UndoRedo — Godot Engine (stable) documentation](https://docs.godotengine.org/en/stable/classes/class_undoredo.html)
- [Undo / Redo - Godot Asset Library](https://godotengine.org/asset-library/asset/1734)

## Testing Strategy

### GUT Framework (Already Installed)

| Technology | Version | Purpose | Why This |
|------------|---------|---------|----------|
| GUT | Current | Unit/integration testing | Already in project, familiar |

**Test coverage needed:**

1. **Serialization round-trip tests**
```gdscript
extends GutTest

func test_room_serialization_roundtrip() -> void:
    var room = RoomInstance.new("test", "lobby")
    room.bounding_box = Rect2i(0, 0, 10, 10)
    room.walls = [Vector2i(0, 0), Vector2i(1, 0)]

    var dict = room.to_dict()
    var loaded = RoomInstance.from_dict(dict)

    assert_eq(loaded.id, room.id)
    assert_eq(loaded.bounding_box, room.bounding_box)
    assert_eq(loaded.walls.size(), room.walls.size())
```

2. **Save/load manager tests**
```gdscript
func test_save_and_load_game() -> void:
    var rooms: Array[RoomInstance] = [RoomInstance.new("r1", "lobby")]

    var err = SaveManager.save_game(rooms)
    assert_eq(err, OK)

    var loaded = SaveManager.load_game()
    assert_eq(loaded.size(), 1)
    assert_eq(loaded[0].id, "r1")
```

3. **Selection hit-testing**
```gdscript
func test_room_selection_detects_touch() -> void:
    var area = RoomSelectionArea.new()
    # Test input_event signal with mock InputEventScreenTouch
```

**Test data location:** Use `user://test_save.dat` for tests, clean up in after_each().

Sources:
- [Your existing test files: test_room_instance.gd](file://C:/git/TheaterCity/test/unit/test_room_instance.gd)

## Anti-Patterns to Avoid

### 1. DON'T Use JSON for Game Saves

**Why not:**
- Manual conversion of Vector2i/Rect2i to dictionaries/arrays
- Loss of type information (typed arrays become untyped)
- Larger file size, slower parsing than binary
- Only use JSON for web APIs or external data exchange

**When JSON IS appropriate:**
- Exporting room designs to share with other players
- Level editor export for modding
- Debug export for inspection

Sources:
- [【Godot】Implementing Save/Load Systems - Complete Comparison](https://uhiyama-lab.com/en/notes/godot/save-load-system/)
- [Saving and Loading with .json - Programming - Godot Forum](https://forum.godotengine.org/t/saving-and-loading-with-json/109986)

### 2. DON'T Serialize FurnitureResource References

**Problem:** FurnitureResource is a Resource (.tres file), contains PackedScene references. Can't be serialized with store_var() or JSON.

**Solution:** Store furniture ID string, resolve via FurnitureRegistry on load.

```gdscript
# WRONG
"furniture": furniture.map(func(f): return f.furniture)  # Can't serialize Resource

# RIGHT
"furniture": furniture.map(func(f): return f.furniture.id)  # Store ID string
```

Sources:
- [Need a way to serialize simple objects · godotengine/godot-proposals](https://github.com/godotengine/godot-proposals/discussions/7435)

### 3. DON'T Use Editor Gizmos for Runtime Selection

**Problem:** EditorPlugin gizmos are for editor tools, not runtime gameplay.

**Solution:** Use regular nodes (Line2D, ColorRect, Control) for selection UI.

Sources:
- [Add a setting to disable Select Mode manipulator gizmo · Issue #7834](https://github.com/godotengine/godot-proposals/issues/7834)

### 4. DON'T Store Entire Scene Tree in Save File

**Problem:** Serializing Node trees with store_var() is fragile, breaks with scene changes.

**Solution:** Save data model (RoomInstance), reconstruct scene from data on load.

Your existing architecture already follows this - RoomInstance is data, scenes are generated from it.

### 5. DON'T Forget to Disable Camera Input During Editing

**Mobile-specific:** Touch events for room manipulation conflict with pan/zoom camera.

```gdscript
func enter_edit_mode() -> void:
    camera.enable_pinch_pan = false  # From your existing code
```

Sources:
- [Your CLAUDE.md: Input Handling with Camera](file://C:/git/TheaterCity/CLAUDE.md)

## Installation & Setup

### Core (No New Dependencies)

```bash
# Nothing to install - FileAccess, Area2D, UndoRedo are built into Godot 4.5
```

### New Autoload Singleton

```gdscript
# Project > Project Settings > Autoload
# Add: SaveManager.gd as "SaveManager"
```

### Project Settings

```gdscript
# Already enabled by default, verify:
Project Settings > Input Devices > Pointing > Emulate Mouse From Touch = true
```

## Migration Notes

### From Existing Room Build System

Your current system already separates data (RoomInstance) from presentation (tilemaps, sprites). This is ideal for save/load.

**Integration points:**

1. **RoomBuildController** - Add save/load methods
```gdscript
func save_all_rooms() -> void:
    SaveManager.save_game(_all_rooms)

func load_all_rooms() -> void:
    _all_rooms = SaveManager.load_game()
    # Regenerate tilemaps/visuals from loaded data
```

2. **RoomInstance** - Add to_dict()/from_dict() methods (see Serialization Strategy above)

3. **Main scene** - Add "Save" and "Load" buttons to UI

**No breaking changes required** - existing RoomInstance API stays the same.

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| FileAccess.store_var() | HIGH | Documented Godot 4.5 API, handles all your types natively |
| user:// persistence | HIGH | Standard cross-platform approach, verified mobile behavior |
| RefCounted serialization | HIGH | to_dict()/from_dict() pattern is standard, multiple sources confirm |
| Touch selection | MEDIUM | Standard Area2D approach, but mobile testing reveals edge cases |
| Undo/Redo | HIGH | Built-in UndoRedo class, well-documented pattern |

## Summary

**Add to existing system:**
1. SaveManager singleton (FileAccess.store_var/get_var)
2. RoomInstance.to_dict()/from_dict() methods
3. Area2D children for room selection
4. UndoRedo instance in editor controller
5. GUT tests for serialization round-trips

**Don't change:**
- Existing RoomInstance data model (it's already save-ready)
- Operations pattern (stateless, doesn't need persistence)
- Registries (load from .tres on startup, not from save file)

**Critical path:**
1. Serialization (to_dict/from_dict) - required for all other features
2. SaveManager - basic save/load functionality
3. Selection UI - enables editing after load
4. Undo/Redo - polish feature, add last

This stack leverages Godot 4.5 built-ins (FileAccess, Area2D, UndoRedo) rather than external dependencies, matching your zero-addon approach for core systems.
