# Phase 1: Room Manager Foundation - Research

**Researched:** 2026-01-21
**Domain:** Room selection infrastructure, touch input, visual feedback
**Confidence:** HIGH

## Summary

This phase establishes the RoomManager autoload singleton to track completed rooms and enable selection via tap input. The research focuses on phase-specific implementation details that build upon the existing codebase patterns.

Key findings:
- RoomManager follows the existing Targets singleton pattern (simple, signal-based)
- Area2D with CollisionPolygon2D enables precise isometric diamond hit detection for each room
- Tap vs drag detection requires manual threshold tracking (20px distance, 300ms time)
- Visual highlight uses existing `RoomBuildDrawing.draw_tile_highlight()` pattern with modulate tint
- Camera input toggling already implemented in Main.gd, reuse same pattern for edit mode

**Primary recommendation:** Create RoomManager as minimal autoload, spawn Area2D collision areas when rooms complete, use existing isometric math and drawing utilities.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Autoload singleton | Godot 4.5 | RoomManager global access | Follows existing Targets pattern |
| Area2D | Godot 4.5 | Room hit detection | Standard 2D object picking |
| CollisionPolygon2D | Godot 4.5 | Isometric diamond shape | Precise tile-aligned click bounds |
| InputEventScreenTouch | Godot 4.5 | Touch/tap detection | Native mobile input |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| IsometricMath | Project util | Coordinate conversion | Converting tile bounds to collision polygon |
| RoomBuildDrawing | Project util | Tile highlighting | Visual selection feedback |
| PinchPanCamera | ppc addon | Camera control toggle | Disable pan during selection mode |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CollisionPolygon2D | CollisionShape2D + RectangleShape | Simpler but doesn't match isometric tile shape |
| Area2D input_event | Manual raycast | More control but reinvents wheel |
| Tint highlight | Line2D outline | Line2D harder to align with isometric tiles |

**Installation:**
```bash
# Nothing to install - all built-in Godot 4.5 features
# Uses existing project utilities (IsometricMath, RoomBuildDrawing)
```

## Architecture Patterns

### Recommended Project Structure

```
scripts/
├── RoomManager.gd          # NEW: Autoload singleton
├── Targets.gd              # Existing (reference pattern)
├── Main.gd                 # Modified: Connect to RoomManager signals
└── room_building/
    ├── RoomBuildController.gd  # Modified: Register rooms on completion
    └── RoomSelectionArea.gd    # NEW: Area2D for room hit detection
```

### Pattern 1: RoomManager Singleton (follows Targets pattern)

**What:** Global autoload that tracks completed rooms and manages selection state
**When to use:** Always - single source of truth for room data

```gdscript
# RoomManager.gd - follows existing Targets.gd pattern
extends Node

signal room_added(room: RoomInstance)
signal room_selected(room: RoomInstance)
signal selection_cleared

var _rooms: Array[RoomInstance] = []
var _selected_room: RoomInstance = null
var _selection_areas: Dictionary = {}  # room_id -> Area2D

func register_room(room: RoomInstance) -> void:
    if room not in _rooms:
        _rooms.append(room)
        _create_selection_area(room)
        room_added.emit(room)

func get_all_rooms() -> Array[RoomInstance]:
    return _rooms

func select_room(room: RoomInstance) -> void:
    if room != _selected_room:
        _selected_room = room
        room_selected.emit(room)

func clear_selection() -> void:
    if _selected_room:
        _selected_room = null
        selection_cleared.emit()

func get_selected_room() -> RoomInstance:
    return _selected_room
```

### Pattern 2: Area2D Selection with Isometric Collision

**What:** Each completed room gets an Area2D child with CollisionPolygon2D matching its isometric bounds
**When to use:** When room is registered with RoomManager

```gdscript
# Create isometric diamond collision polygon for room bounds
func _create_selection_area(room: RoomInstance) -> Area2D:
    var area = Area2D.new()
    area.name = "SelectionArea_" + room.id
    area.input_pickable = true

    var collision = CollisionPolygon2D.new()
    collision.polygon = _create_room_polygon(room)
    area.add_child(collision)

    # Store reference for input handling
    area.set_meta("room_data", room)
    area.input_event.connect(_on_area_input_event.bind(room))

    add_child(area)
    _selection_areas[room.id] = area
    return area

func _create_room_polygon(room: RoomInstance) -> PackedVector2Array:
    var bbox = room.bounding_box
    # Convert tile corners to world positions (isometric diamond)
    var top_left = bbox.position
    var bottom_right = bbox.position + bbox.size

    # Isometric diamond: top, right, bottom, left
    var points = PackedVector2Array()
    points.append(IsometricMath.tile_to_world(top_left))                                    # Top
    points.append(IsometricMath.tile_to_world(Vector2i(bottom_right.x, top_left.y)))       # Right
    points.append(IsometricMath.tile_to_world(bottom_right))                               # Bottom
    points.append(IsometricMath.tile_to_world(Vector2i(top_left.x, bottom_right.y)))       # Left

    return points
```

### Pattern 3: Tap vs Drag Detection

**What:** Distinguish tap (select) from drag (camera pan) using distance and time thresholds
**When to use:** In RoomManager or dedicated input handler

```gdscript
# Tap detection thresholds
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

var _touch_start_pos: Vector2
var _touch_start_time: int

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int, room: RoomInstance) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            # Check if this was a tap (not a drag)
            var distance = event.position.distance_to(_touch_start_pos)
            var duration = Time.get_ticks_msec() - _touch_start_time

            if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                select_room(room)
```

### Pattern 4: Integration with RoomBuildController

**What:** Register completed rooms with RoomManager when build completes
**When to use:** In RoomBuildController._on_complete_pressed() after validation

```gdscript
# In RoomBuildController.gd - add after room_completed.emit(current_room)
func _on_complete_pressed() -> void:
    # ... existing validation and visual creation code ...

    room_completed.emit(current_room)

    # Register with RoomManager for selection/editing
    RoomManager.register_room(current_room)

    # ... existing cleanup code ...
```

### Anti-Patterns to Avoid

- **Global input handling:** Don't use `_unhandled_input` for room selection - Area2D handles it locally
- **Rebuilding collision on every frame:** Create collision polygon once when room registers
- **Storing visual nodes in RoomInstance:** Keep data (RoomInstance) separate from visuals (Area2D, highlights)
- **Direct camera manipulation:** Use `camera.enable_pinch_pan` toggle, not custom input blocking

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Isometric coordinate math | Custom conversion functions | `IsometricMath.tile_to_world()` | Already tested, matches tilemap |
| Tile highlighting | Custom polygon drawing | `RoomBuildDrawing.draw_tile_highlight()` | Handles camera zoom correctly |
| Click-in-polygon detection | Manual point-in-polygon test | Area2D + CollisionPolygon2D | Godot handles edge cases |
| Camera pan disable | Block input events manually | `camera.enable_pinch_pan = false` | Already used in Main.gd |

**Key insight:** The project already has isometric utilities and UI patterns from RoomBuildUI - reuse them rather than creating parallel systems.

## Common Pitfalls

### Pitfall 1: Area2D input_event Not Firing

**What goes wrong:** Area2D receives no input events despite collision shape being set
**Why it happens:** `input_pickable` is false (default) or collision layers misconfigured
**How to avoid:** Explicitly set `input_pickable = true` when creating Area2D
**Warning signs:** Clicks work elsewhere but not on rooms

```gdscript
var area = Area2D.new()
area.input_pickable = true  # CRITICAL - default is false
```

### Pitfall 2: Touch Events Fire During Camera Drag

**What goes wrong:** Room selects while user is panning camera
**Why it happens:** InputEventScreenTouch fires on touch_down before drag is detected
**How to avoid:** Track touch start position/time, only select on touch_up if thresholds met
**Warning signs:** Accidental selections during pan gesture

### Pitfall 3: Collision Polygon in Wrong Coordinate Space

**What goes wrong:** Click detection offset from visual room position
**Why it happens:** Polygon points in tile coords instead of world coords, or missing camera transform
**How to avoid:** Use `IsometricMath.tile_to_world()` for all polygon points
**Warning signs:** Clicks register offset from where room appears

### Pitfall 4: Mobile Touch with Mouse Emulation Conflicts

**What goes wrong:** Double events or missed events on mobile
**Why it happens:** `Emulate Mouse From Touch` setting creates both mouse and touch events
**How to avoid:** Use InputEventScreenTouch for consistency; project already has `emulate_touch_from_mouse=true`
**Warning signs:** Events fire twice or input_event signal doesn't trigger

**Project setting verified:** `pointing/emulate_touch_from_mouse=true` in project.godot

### Pitfall 5: Selection Highlight Doesn't Update with Camera Zoom

**What goes wrong:** Highlight tiles are wrong size after zooming
**Why it happens:** Drawing in screen coords without accounting for canvas transform
**How to avoid:** Use `RoomBuildDrawing.draw_tile_highlight()` which handles zoom via `tile_to_screen()`
**Warning signs:** Highlight misaligned at different zoom levels

## Code Examples

### Creating RoomManager Autoload

```gdscript
# scripts/RoomManager.gd
extends Node

signal room_added(room: RoomInstance)
signal room_selected(room: RoomInstance)
signal selection_cleared

var _rooms: Array[RoomInstance] = []
var _selected_room: RoomInstance = null
var _selection_areas: Dictionary = {}  # room.id -> Area2D

# Tap detection
const TAP_DISTANCE_THRESHOLD := 20.0
const TAP_TIME_THRESHOLD := 300
var _touch_start_pos: Vector2
var _touch_start_time: int

func register_room(room: RoomInstance) -> void:
    if room not in _rooms:
        _rooms.append(room)
        _create_selection_area(room)
        room_added.emit(room)

func get_room_by_id(id: String) -> RoomInstance:
    for room in _rooms:
        if room.id == id:
            return room
    return null

func select_room(room: RoomInstance) -> void:
    if room != _selected_room:
        _selected_room = room
        room_selected.emit(room)

func clear_selection() -> void:
    if _selected_room:
        _selected_room = null
        selection_cleared.emit()

func get_selected_room() -> RoomInstance:
    return _selected_room

func _create_selection_area(room: RoomInstance) -> void:
    var area = Area2D.new()
    area.name = "SelectionArea_" + room.id
    area.input_pickable = true

    var collision = CollisionPolygon2D.new()
    collision.polygon = _room_to_polygon(room)
    area.add_child(collision)

    area.input_event.connect(_on_area_input.bind(room))

    add_child(area)
    _selection_areas[room.id] = area

func _room_to_polygon(room: RoomInstance) -> PackedVector2Array:
    var bbox = room.bounding_box
    var tl = bbox.position
    var br = bbox.position + bbox.size

    # Isometric diamond corners (world coordinates)
    return PackedVector2Array([
        IsometricMath.tile_to_world(tl),                        # Top
        IsometricMath.tile_to_world(Vector2i(br.x, tl.y)),     # Right
        IsometricMath.tile_to_world(br),                        # Bottom
        IsometricMath.tile_to_world(Vector2i(tl.x, br.y))      # Left
    ])

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, room: RoomInstance) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            var dist = event.position.distance_to(_touch_start_pos)
            var time = Time.get_ticks_msec() - _touch_start_time
            if dist < TAP_DISTANCE_THRESHOLD and time < TAP_TIME_THRESHOLD:
                select_room(room)
```

### Registering Autoload in project.godot

```ini
[autoload]
Targets="*res://scripts/Targets.gd"
RoomManager="*res://scripts/RoomManager.gd"
```

### Selection Highlight Visual (using existing pattern)

```gdscript
# In a Control node that handles selection visuals
extends Control

func _ready() -> void:
    RoomManager.room_selected.connect(_on_room_selected)
    RoomManager.selection_cleared.connect(_on_selection_cleared)

func _on_room_selected(_room: RoomInstance) -> void:
    queue_redraw()

func _on_selection_cleared() -> void:
    queue_redraw()

func _draw() -> void:
    var room = RoomManager.get_selected_room()
    if not room:
        return

    # Highlight all tiles in room
    var bbox = room.bounding_box
    var highlight_color = Color(1.0, 0.9, 0.2, 0.3)  # Yellow tint

    for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
        for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
            RoomBuildDrawing.draw_tile_highlight(self, Vector2i(x, y), highlight_color, get_viewport())
```

### Deselect When Tapping Outside Rooms

```gdscript
# In Main.gd or dedicated input handler
func _unhandled_input(event: InputEvent) -> void:
    # Existing toggle_build handling...

    # Deselect room when tapping empty space
    if event is InputEventScreenTouch and not event.pressed:
        # If we get here, no Area2D consumed the event
        RoomManager.clear_selection()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual point-in-polygon | Area2D + CollisionPolygon2D | Godot 3.x | Built-in handles edge cases |
| Global input manager | Local Area2D input_event | Godot 4.0 | Cleaner event propagation |
| Custom gesture detection | InputEventScreenTouch/Drag | Godot 4.0 | Native touch support |

**Deprecated/outdated:**
- Godot 3.x `is_action_pressed()` for touch - use InputEventScreenTouch directly
- Custom input singletons - Area2D signals preferred for localized input

## Open Questions

1. **Multi-room highlight during edit mode?**
   - What we know: Single selection works
   - What's unclear: Should we highlight adjacent rooms differently?
   - Recommendation: Start with single selection, add multi-room awareness if needed

2. **Selection persistence across scene changes?**
   - What we know: RoomManager is autoload, survives scene changes
   - What's unclear: Should selection clear when entering/exiting build mode?
   - Recommendation: Clear selection when exiting build mode (matches existing pattern)

## Sources

### Primary (HIGH confidence)
- Existing codebase: `Targets.gd` - singleton pattern reference
- Existing codebase: `RoomBuildUI.gd` - input handling and isometric drawing patterns
- Existing codebase: `IsometricMath.gd` - coordinate conversion utilities
- Existing codebase: `project.godot` - touch emulation settings
- [Godot CollisionPolygon2D Documentation](https://docs.godotengine.org/en/stable/classes/class_collisionpolygon2d.html)

### Secondary (MEDIUM confidence)
- [Godot Touch Input Best Practices Forum](https://forum.godotengine.org/t/which-is-the-best-way-to-handle-touch-screen-controls-and-clicking-objects/42209)
- [Godot Touch Input Manager](https://github.com/Federico-Ciuffardi/GodotTouchInputManager) - tap threshold patterns
- [Area2D Mobile Bug Report](https://github.com/godotengine/godot/issues/109615) - emulate_touch_from_mouse behavior

### Tertiary (LOW confidence)
- General mobile game tap vs drag threshold conventions (20px/300ms is industry standard)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - uses existing project patterns
- Architecture: HIGH - follows Targets.gd singleton pattern exactly
- Tap detection: MEDIUM - thresholds are industry standard but may need tuning
- Collision polygon: HIGH - uses existing IsometricMath utilities

**Research date:** 2026-01-21
**Valid until:** 60 days (stable Godot 4.5 patterns, project-specific)
