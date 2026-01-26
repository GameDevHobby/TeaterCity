# Phase 6: Door Editing - Research

**Researched:** 2026-01-25
**Domain:** Room door management, wall tile manipulation, navigation mesh updates
**Confidence:** HIGH

## Summary

Phase 6 enables players to add and remove doors from existing rooms through the edit mode workflow. This phase builds heavily on existing infrastructure: DoorOperation already handles door validation during room creation, and the furniture editing patterns (FurnitureEditController, contextual menus, visual highlights) provide a proven template.

The primary new requirement is adjacent room checking - doors must open to empty space, not into another room. This requires querying RoomManager for rooms occupying the tile outside the door. The rest of the implementation reuses established patterns with minimal adaptation.

**Primary recommendation:** Create a DoorEditController following the FurnitureEditController pattern, add a helper method to RoomManager for tile occupancy checking, and extend DoorOperation with adjacent tile validation.

## Standard Stack

The door editing feature uses existing project infrastructure with no new libraries.

### Core

| Component | Location | Purpose | Why Standard |
|-----------|----------|---------|--------------|
| DoorOperation | `scripts/room_building/operations/DoorOperation.gd` | Door validation, visual creation | Already validates wall adjacency, determines direction |
| NavigationOperation | `scripts/room_building/operations/NavigationOperation.gd` | Updates navigation mesh | Already handles door positions in nav update |
| RoomManager | `scripts/RoomManager.gd` | Room tracking, selection | Singleton with tile-based room lookup needed |
| RoomInstance | `scripts/storage/RoomInstance.gd` | Door data model | DoorPlacement inner class already exists |

### Supporting

| Component | Location | Purpose | When to Use |
|-----------|----------|---------|-------------|
| RoomBuildDrawing | `scripts/room_building/ui/RoomBuildDrawing.gd` | Tile highlight rendering | Visual feedback for door positions |
| IsometricMath | `scripts/utils/IsometricMath.gd` | Coordinate conversions | Screen-to-tile for tap detection |
| UIStyleHelper | `scripts/utils/UIStyleHelper.gd` | Button/panel styling | Menu UI consistency |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| DoorEditController | Extend RoomEditMenu | Keeping door mode separate aligns with furniture pattern, cleaner state management |
| Inline adjacent check | Tilemap collision layer | Tilemap queries add complexity; RoomManager lookup is simpler given existing data |

## Architecture Patterns

### Recommended File Structure

```
scripts/
├── room_editing/
│   ├── DoorEditController.gd    # NEW: Door edit mode state machine
│   ├── DoorEditHighlight.gd     # NEW: Visual feedback for door editing
│   └── (existing files...)
├── room_building/operations/
│   └── DoorOperation.gd         # EXTEND: Add adjacent tile validation
└── RoomManager.gd               # EXTEND: Add is_tile_occupied_by_other_room()
```

### Pattern 1: Edit Controller State Machine

**What:** DoorEditController manages door edit mode state, similar to FurnitureEditController.

**When to use:** Entering door edit mode from RoomEditMenu.

**Example:**
```gdscript
# Based on existing FurnitureEditController pattern
class_name DoorEditController
extends Control

signal door_added(room: RoomInstance, door: RoomInstance.DoorPlacement)
signal door_removed(room: RoomInstance, door: RoomInstance.DoorPlacement)
signal mode_exited

var _active: bool = false
var _current_room: RoomInstance = null
var _hover_position: Vector2i = Vector2i(-1, -1)
var _door_operation: DoorOperation = null

func enter_edit_mode(room: RoomInstance) -> void:
    if room == null or not room.room_type_id:
        return
    # Check if room type has walls
    var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
    if room_type and not room_type.has_walls:
        return  # Cannot edit doors on wall-less rooms

    _active = true
    _current_room = room
    if _door_operation == null:
        _door_operation = DoorOperation.new()
    queue_redraw()

func exit_edit_mode() -> void:
    _active = false
    _current_room = null
    mode_exited.emit()
    queue_redraw()
```

### Pattern 2: Adjacent Room Validation

**What:** Check if the tile outside the door belongs to another room before allowing door placement.

**When to use:** Validating door positions during add operation.

**Example:**
```gdscript
# In DoorOperation.gd
func can_place_door_edit(position: Vector2i, room: RoomInstance) -> Dictionary:
    var result = { "can_place": true, "reason": "" }

    # First check standard wall adjacency
    if not is_valid_door_position(position, room):
        result.can_place = false
        result.reason = "Invalid wall position for door"
        return result

    # Check if door already exists
    for door in room.doors:
        if door.position == position:
            result.can_place = false
            result.reason = "Door already exists here"
            return result

    # Check adjacent tile (outside door) for other rooms
    var direction = determine_door_direction(position, room)
    var outside_tile = _get_outside_tile(position, direction)

    if RoomManager.is_tile_in_another_room(outside_tile, room):
        result.can_place = false
        result.reason = "Cannot place door into adjacent room"
        return result

    return result

func _get_outside_tile(door_pos: Vector2i, direction: int) -> Vector2i:
    # Direction: 0=North, 1=East, 2=South, 3=West
    match direction:
        0: return door_pos + Vector2i(0, -1)  # North: outside is y-1
        1: return door_pos + Vector2i(1, 0)   # East: outside is x+1
        2: return door_pos + Vector2i(0, 1)   # South: outside is y+1
        3: return door_pos + Vector2i(-1, 0)  # West: outside is x-1
    return door_pos
```

### Pattern 3: RoomManager Tile Lookup

**What:** Helper method to check if a tile is occupied by a room other than the current one.

**When to use:** Adjacent tile validation for door placement.

**Example:**
```gdscript
# In RoomManager.gd
func is_tile_in_another_room(tile: Vector2i, exclude_room: RoomInstance) -> bool:
    for room in _rooms:
        if room == exclude_room:
            continue
        if _is_tile_in_room(tile, room):
            return true
    return false

func _is_tile_in_room(tile: Vector2i, room: RoomInstance) -> bool:
    var bbox = room.bounding_box
    if tile.x < bbox.position.x or tile.x >= bbox.position.x + bbox.size.x:
        return false
    if tile.y < bbox.position.y or tile.y >= bbox.position.y + bbox.size.y:
        return false
    return true
```

### Pattern 4: Door Removal with Wall Restoration

**What:** Removing a door requires restoring the wall tile and updating terrain connections.

**When to use:** Delete door operation.

**Example:**
```gdscript
# In DoorOperation.gd
func remove_door_visuals(door: RoomInstance.DoorPlacement, room: RoomInstance, tilemap_layer: TileMapLayer) -> void:
    var tilemap_pos = _ui_to_tilemap_coords(door.position, tilemap_layer)

    # Erase the door tile
    tilemap_layer.erase_cell(tilemap_pos)

    # Collect all wall positions for this room (excluding other doors)
    var wall_tilemap_positions: Array[Vector2i] = []
    for wall_pos in room.walls:
        var is_other_door = false
        for d in room.doors:
            if d != door and d.position == wall_pos:
                is_other_door = true
                break
        if not is_other_door:
            wall_tilemap_positions.append(_ui_to_tilemap_coords(wall_pos, tilemap_layer))

    # Re-place with terrain connect to restore wall tile
    tilemap_layer.set_cells_terrain_connect(wall_tilemap_positions, TERRAIN_SET, TERRAIN_INDEX)
```

### Anti-Patterns to Avoid

- **Direct array manipulation without signal:** Always emit `placement_changed` after modifying `room.doors` to trigger auto-save.
- **Forgetting navigation update:** Door changes MUST call `NavigationOperation.update_room_navigation()` and `Targets.notify_navigation_changed()`.
- **Checking room type after entry:** Verify room has walls BEFORE entering door edit mode, not during operations.
- **Inconsistent direction calculation:** Use `determine_door_direction()` consistently - do not inline direction logic.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Door position validation | Custom neighbor counting | `DoorOperation.is_valid_door_position()` | Already handles 2-3 wall neighbor rule |
| Direction calculation | Inline bounding box math | `DoorOperation.determine_door_direction()` | Correct handling of all four edges |
| Tile highlighting | Custom isometric drawing | `RoomBuildDrawing.draw_tile_highlight()` | Handles camera transforms, consistent style |
| Navigation mesh update | Manual tile manipulation | `NavigationOperation.update_room_navigation()` | Handles doors as walkable tiles |
| Terrain auto-tiling | Manual tile placement | `TileMapLayer.set_cells_terrain_connect()` | Godot handles tile transitions |
| Menu styling | Custom StyleBoxFlat | `UIStyleHelper.apply_panel_style()` | Project-consistent visual style |

**Key insight:** Door editing is a special case of the existing door placement flow. The infrastructure exists; door editing adds edit-mode entry points and adjacent room validation.

## Common Pitfalls

### Pitfall 1: Forgetting Navigation Update

**What goes wrong:** Patrons cannot path through new doors or still walk through removed doors.
**Why it happens:** Door changes modify the navigation mesh, but developers forget to call navigation update.
**How to avoid:** Always call both operations after any door change:
```gdscript
_navigation_op.update_room_navigation(room, tilemap_layer)
Targets.notify_navigation_changed()
```
**Warning signs:** Patrons stop navigating or clip through walls after door edit.

### Pitfall 2: Wall Restoration Without Terrain Connect

**What goes wrong:** Removed door leaves visual gap in wall or incorrect wall tile.
**Why it happens:** Using `set_cell()` instead of `set_cells_terrain_connect()` for wall restoration.
**How to avoid:** Always use terrain-aware tile placement for walls:
```gdscript
tilemap_layer.set_cells_terrain_connect(wall_positions, TERRAIN_SET, TERRAIN_INDEX)
```
**Warning signs:** Wall corners or edges display incorrect sprites after door removal.

### Pitfall 3: Door-to-Door Adjacency Edge Case

**What goes wrong:** Door opens directly into a door of an adjacent room - confusing UX.
**Why it happens:** Only checking if tile is in another room, not if it's a door position.
**How to avoid:** The current requirement "doors can only open to empty space (not into adjacent rooms)" handles this - doors into any part of another room (including doors) are blocked.
**Warning signs:** Two rooms with back-to-back doors that both work but share the same outside tile.

### Pitfall 4: Minimum Door Count Validation

**What goes wrong:** Player removes the only door, making room inaccessible.
**Why it happens:** Not checking `room_type.door_count_min` before deletion.
**How to avoid:** Check minimum door requirement before allowing removal:
```gdscript
func can_remove_door(room: RoomInstance) -> Dictionary:
    var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
    if room_type and room.doors.size() <= room_type.door_count_min:
        return { "can_remove": false, "reason": "Minimum %d door(s) required" % room_type.door_count_min }
    return { "can_remove": true, "reason": "" }
```
**Warning signs:** Rooms with zero doors that patrons cannot enter.

### Pitfall 5: Full-Rect Control Blocking Input

**What goes wrong:** Taps on wall tiles not detected.
**Why it happens:** Control node with default `MOUSE_FILTER_PASS` or `STOP` blocks underlying Area2D.
**How to avoid:** Set `mouse_filter = MOUSE_FILTER_IGNORE` on full-rect Controls used for drawing only.
**Warning signs:** Highlight draws but taps do nothing.

## Code Examples

Verified patterns from existing codebase:

### Tap Detection Pattern (from FurnitureEditController)

```gdscript
# Source: scripts/room_editing/FurnitureEditController.gd
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0

func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, context: Variant) -> void:
    # Handle mouse clicks (desktop)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            var distance: float = event.position.distance_to(_touch_start_pos)
            var duration := Time.get_ticks_msec() - _touch_start_time
            if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                _handle_tap(context)
        return

    # Handle touch events (mobile)
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            var distance: float = event.position.distance_to(_touch_start_pos)
            var duration := Time.get_ticks_msec() - _touch_start_time
            if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                _handle_tap(context)
```

### Visual Highlight Pattern (from RoomBuildDrawing)

```gdscript
# Source: scripts/room_building/ui/RoomBuildDrawing.gd
static func draw_tile_highlight(control: CanvasItem, tile_pos: Vector2i, color: Color, viewport: Viewport) -> void:
    var top = IsometricMath.tile_to_screen(tile_pos, viewport)
    var right = IsometricMath.tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y), viewport)
    var bottom = IsometricMath.tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y + 1), viewport)
    var left = IsometricMath.tile_to_screen(Vector2i(tile_pos.x, tile_pos.y + 1), viewport)

    var points = PackedVector2Array([top, right, bottom, left])
    control.draw_colored_polygon(points, color)
```

### Door Visual Creation (from DoorOperation)

```gdscript
# Source: scripts/room_building/operations/DoorOperation.gd
func create_door_visuals(door: RoomInstance.DoorPlacement, tilemap_layer: TileMapLayer) -> void:
    var tilemap_pos = _ui_to_tilemap_coords(door.position, tilemap_layer)

    # Place the door tile (non-terrain, just a walkable tile)
    tilemap_layer.set_cell(tilemap_pos, SOURCE_ID, DOOR_TILE)

    # Update neighboring wall tiles to refresh their terrain connections
    _update_neighbor_terrain(tilemap_pos, tilemap_layer)
```

### RoomInstance Door Management (from RoomInstance)

```gdscript
# Source: scripts/storage/RoomInstance.gd
class DoorPlacement:
    var position: Vector2i
    var direction: int

    func _init(pos: Vector2i, dir: int):
        position = pos
        direction = dir

func add_door(position: Vector2i, direction: int) -> void:
    doors.append(DoorPlacement.new(position, direction))
    placement_changed.emit()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Hard-coded door positions | Dynamic door placement | Initial build system | Doors placed during room creation |
| No door editing | Edit mode entry (Phase 2) | 2026-01-22 | Menu enables edit workflows |
| Manual tile manipulation | Terrain auto-tiling | Initial build system | set_cells_terrain_connect handles transitions |

**Deprecated/outdated:**
- None for door operations - DoorOperation is current and well-tested.

## Open Questions

Things that couldn't be fully resolved:

1. **Maximum door count enforcement**
   - What we know: `RoomTypeResource.door_count_max` exists but is not currently enforced
   - What's unclear: Should door edit mode enforce maximum, or only warn?
   - Recommendation: Enforce maximum during add operation, consistent with furniture limits

2. **Door edit from main menu vs furniture edit menu**
   - What we know: RoomEditMenu has "Edit Room" button currently unused
   - What's unclear: Should door editing be separate mode or sub-option of "Edit Room"?
   - Recommendation: Use "Edit Room" button to enter door edit mode, keeping UI simple

3. **Visual indicator for blocked door positions**
   - What we know: Furniture uses red highlight for invalid positions
   - What's unclear: Should adjacent-room-blocked positions show different color than wall-invalid positions?
   - Recommendation: Use consistent red highlight for all invalid positions, show reason in error message

## Sources

### Primary (HIGH confidence)
- `scripts/room_building/operations/DoorOperation.gd` - All door validation and visual methods
- `scripts/room_building/operations/NavigationOperation.gd` - Navigation update pattern
- `scripts/room_editing/FurnitureEditController.gd` - Edit mode controller pattern
- `scripts/RoomManager.gd` - Room tracking and selection
- `scripts/storage/RoomInstance.gd` - DoorPlacement data model

### Secondary (MEDIUM confidence)
- `scripts/room_building/RoomBuildUI.gd` - Door placement during room creation (reference implementation)
- `scripts/room_building/ui/RoomBuildDrawing.gd` - Door placement hint drawing

### Tertiary (LOW confidence)
- None - all findings verified through codebase analysis

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All components exist and are in active use
- Architecture: HIGH - Follows established FurnitureEditController pattern
- Pitfalls: HIGH - Based on patterns from completed Phase 5

**Research date:** 2026-01-25
**Valid until:** 2026-02-25 (stable patterns, no external dependencies)
