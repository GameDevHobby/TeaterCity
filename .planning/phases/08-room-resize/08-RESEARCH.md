# Phase 8: Room Resize (Complex) - Research

**Researched:** 2026-02-01
**Domain:** Room geometry modification, furniture validation, shared wall handling, drag-to-resize UX
**Confidence:** MEDIUM

## Summary

Room resize is the most complex room editing operation in this milestone. After analyzing the existing codebase and the requirements, **the "delete + rebuild" approach is strongly recommended over in-place modification**. The existing architecture already has all the building blocks: RoomBuildUI's box drawing, DeletionOperation's shared wall handling, CollisionOperation's furniture validation, and WallOperation's wall generation.

Key insights from codebase analysis:
1. RoomBuildUI already handles drag-to-define bounding box (the exact UX needed for resize preview)
2. DeletionOperation already solves the hardest problem: shared wall detection and preservation
3. All wall/door data is derived from bounding_box, not stored independently
4. Furniture positions are absolute Vector2i tile coordinates (not relative to room origin)

**Primary recommendation:** Implement resize as a delete-then-rebuild workflow where:
1. User enters resize mode
2. User drags to define new bounding box (using existing box drawing input)
3. System validates: new size fits room type constraints AND all furniture fits inside
4. If valid: delete old walls/doors, generate new walls, transition to door placement
5. Furniture keeps absolute positions (those outside new bounds block resize)

This approach reuses 80%+ of existing code and avoids complex incremental wall manipulation.

## Standard Stack

This phase uses only existing project infrastructure. No new libraries required.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.5 | Built-in Control drawing, input handling | Project-wide standard |
| GDScript | 4.5 | Scripting language | Project-wide standard |
| TileMapLayer | 4.5 | Wall/floor tilemap manipulation | Existing room system |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| IsometricMath | Project util | Coordinate conversion | All tile-screen conversions |
| RoomBuildDrawing | Project util | Tile highlight rendering | Preview rendering |
| UIStyleHelper | Project util | Button/panel styling | Done button styling |
| CollisionOperation | Project util | Furniture bounds checking | Validate furniture fits |
| WallOperation | Project util | Wall generation | Generate new walls |
| DeletionOperation | Project util | Shared wall cleanup | Preserve adjacent walls |
| ValidationOperation | Project util | Room type constraints | Check min/max size |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Delete+rebuild | In-place wall modification | In-place requires tracking which walls to add/remove, complex shared wall logic; delete+rebuild reuses tested code |
| Box drawing UI | Corner/edge drag handles | Handles require 8 touch targets, complex isometric positioning; box drawing already implemented and tested |
| New ResizeController | Extend RoomBuildUI | ResizeController cleaner separation, avoids polluting build code with edit logic |

**Installation:**
No new packages required - all functionality is built-in or exists in the project.

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── room_editing/
│   ├── RoomResizeController.gd   # NEW: Resize workflow state machine
│   └── RoomResizeHighlight.gd    # NEW: Preview rendering
├── room_building/
│   └── operations/
│       └── ResizeOperation.gd    # NEW: Resize validation and execution
└── Main.gd                        # MODIFY: Wire resize controller
```

### Pattern 1: ResizeController (Delete+Rebuild Workflow)
**What:** A Control that manages the resize state machine: idle -> drawing -> validating -> door_placement
**When to use:** For the resize feature
**Example:**
```gdscript
# Source: Follows FurnitureEditController pattern from existing codebase
class_name RoomResizeController
extends Control

signal resize_started(room: RoomInstance)
signal resize_cancelled
signal resize_completed(room: RoomInstance)
signal preview_updated(new_box: Rect2i, is_valid: bool, error: String)

enum State { IDLE, DRAWING, VALIDATING, DOOR_PLACEMENT }

var _state: State = State.IDLE
var _current_room: RoomInstance = null
var _original_box: Rect2i
var _preview_box: Rect2i
var _is_preview_valid: bool = false

# Drag state (matches RoomBuildUI pattern)
var _draw_start: Vector2i = Vector2i.ZERO
var _current_mouse_pos: Vector2i = Vector2i.ZERO
var _is_dragging: bool = false

func enter_resize_mode(room: RoomInstance) -> void:
    _current_room = room
    _original_box = room.bounding_box
    _state = State.DRAWING
    resize_started.emit(room)
    queue_redraw()

func exit_resize_mode() -> void:
    _state = State.IDLE
    _current_room = null
    _is_dragging = false
    resize_cancelled.emit()
    queue_redraw()
```

### Pattern 2: Furniture Bounds Validation
**What:** Check if all existing furniture fits within new bounding box BEFORE committing resize
**When to use:** During preview validation and before executing resize
**Example:**
```gdscript
# Source: Extends CollisionOperation pattern from existing codebase
class_name ResizeOperation
extends RefCounted

class ValidationResult:
    var is_valid: bool = true
    var error: String = ""
    var blocked_furniture: Array[RoomInstance.FurniturePlacement] = []

## Validate that a new bounding box is valid for the room
func validate_resize(room: RoomInstance, new_box: Rect2i) -> ValidationResult:
    var result = ValidationResult.new()

    # 1. Check room type size constraints
    var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
    if room_type:
        var min_s = room_type.min_size
        var max_s = room_type.max_size
        # Check both orientations (matches RoomBuildUI pattern)
        var normal_valid = new_box.size.x >= min_s.x and new_box.size.y >= min_s.y
        normal_valid = normal_valid and new_box.size.x <= max_s.x and new_box.size.y <= max_s.y
        var swapped_valid = new_box.size.x >= min_s.y and new_box.size.y >= min_s.x
        swapped_valid = swapped_valid and new_box.size.x <= max_s.y and new_box.size.y <= max_s.x
        if not normal_valid and not swapped_valid:
            result.is_valid = false
            result.error = "Invalid size: %dx%d to %dx%d required" % [min_s.x, min_s.y, max_s.x, max_s.y]
            return result

    # 2. Check all furniture fits within new bounds
    var new_walls = WallOperation.new().generate_walls(new_box)
    for furn in room.furniture:
        for tile in furn.get_occupied_tiles():
            # Must be inside new box AND not on a wall
            var in_box = _is_tile_in_box(tile, new_box)
            var on_wall = tile in new_walls
            if not in_box or on_wall:
                result.is_valid = false
                result.blocked_furniture.append(furn)
        # Also check access tiles
        for tile in furn.get_access_tiles():
            var in_box = _is_tile_in_box(tile, new_box)
            var on_wall = tile in new_walls
            if not in_box or on_wall:
                result.is_valid = false
                if furn not in result.blocked_furniture:
                    result.blocked_furniture.append(furn)

    if result.blocked_furniture.size() > 0:
        result.error = "%d furniture item(s) would be outside new bounds" % result.blocked_furniture.size()

    return result

func _is_tile_in_box(tile: Vector2i, box: Rect2i) -> bool:
    return tile.x >= box.position.x and tile.x < box.position.x + box.size.x \
       and tile.y >= box.position.y and tile.y < box.position.y + box.size.y
```

### Pattern 3: Resize Preview Rendering
**What:** Draw the preview bounding box during resize drag, showing valid (green) or invalid (red)
**When to use:** During resize drawing state
**Example:**
```gdscript
# Source: Follows RoomBuildUI._draw_box_selection() pattern
class_name RoomResizeHighlight
extends Control

const VALID_FILL := Color(0.2, 0.8, 0.4, 0.2)      # Light green
const VALID_BORDER := Color(0.2, 0.8, 0.4, 1.0)    # Green
const INVALID_FILL := Color(0.9, 0.2, 0.2, 0.2)    # Light red
const INVALID_BORDER := Color(0.9, 0.2, 0.2, 1.0)  # Red
const FURNITURE_BLOCKED := Color(1.0, 0.5, 0.0, 0.6)  # Orange for blocked furniture

var _controller: RoomResizeController = null

func _draw() -> void:
    if _controller == null or not _controller.is_active():
        return

    var preview_box = _controller.get_preview_box()
    var is_valid = _controller.is_preview_valid()
    var blocked_furniture = _controller.get_blocked_furniture()

    # Draw preview box (same technique as RoomBuildUI)
    _draw_box_preview(preview_box, is_valid)

    # Highlight blocked furniture in orange
    for furn in blocked_furniture:
        for tile in furn.get_occupied_tiles():
            RoomBuildDrawing.draw_tile_highlight(self, tile, FURNITURE_BLOCKED, get_viewport())
```

### Pattern 4: Resize Execution (Delete + Rebuild)
**What:** Execute the resize by deleting old walls and generating new ones
**When to use:** After user confirms resize (releases drag with valid preview)
**Example:**
```gdscript
# Source: Combines DeletionOperation and WallOperation patterns
func execute_resize(room: RoomInstance, new_box: Rect2i,
                    wall_tilemap: TileMapLayer, room_manager: Node,
                    exterior_walls: Array[Vector2i]) -> void:
    # 1. Delete old walls (preserving shared and exterior)
    var deletion_op = DeletionOperation.new()
    deletion_op.delete_wall_visuals(room, wall_tilemap, room_manager, exterior_walls)

    # 2. Delete old doors (they will be reset)
    deletion_op.delete_door_visuals(room, wall_tilemap)
    room.doors.clear()

    # 3. Update room data with new bounding box
    room.bounding_box = new_box

    # 4. Generate new walls
    var wall_op = WallOperation.new()
    room.walls = wall_op.generate_walls(new_box)

    # 5. Create new wall visuals
    wall_op.create_wall_visuals(room, wall_tilemap)

    # 6. Furniture stays in place (already validated to fit)
    # No furniture changes needed

    # 7. Trigger placement_changed for auto-save
    room.placement_changed.emit()

    # 8. Navigation will be updated when doors are placed
```

### Pattern 5: Door Placement After Resize
**What:** Transition to door placement mode after resize, requiring user to re-place doors
**When to use:** After resize execution completes
**Example:**
```gdscript
# In ResizeController after execute_resize():
func _on_resize_executed() -> void:
    _state = State.DOOR_PLACEMENT
    # Emit signal so Main.gd can enter door placement (reuse existing DoorEditController)
    door_placement_needed.emit(_current_room)
    # Note: Don't call resize_completed until doors are placed
```

### Anti-Patterns to Avoid
- **In-place wall modification:** Tracking which individual walls to add/remove is complex and error-prone; delete+rebuild is simpler
- **Relative furniture positions:** Furniture uses absolute tile coordinates; never try to "move" furniture with the room
- **Skip furniture validation:** Always validate ALL furniture (footprint + access tiles) fits before committing
- **Forget shared wall preservation:** Reuse DeletionOperation's shared wall logic; don't hand-roll
- **Single resize handle:** Isometric corners are hard to tap; box drawing (drag corner to corner) is more reliable
- **Complex handle hit detection:** 8 separate drag handles in isometric space is error-prone; unified box draw is simpler

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Drag-to-draw box | Custom gesture recognition | RoomBuildUI input pattern | Already handles tap vs drag detection, isometric conversion |
| Wall generation | Custom perimeter logic | WallOperation.generate_walls() | Already handles hollow rectangle generation |
| Shared wall detection | Custom adjacency check | DeletionOperation.get_deletable_walls() | Already solves this complex problem |
| Furniture bounds check | Custom collision logic | CollisionOperation patterns + new validation | Extend existing pattern, don't duplicate |
| Preview rendering | Custom drawing | RoomBuildDrawing.draw_tile_highlight() | Already handles isometric tile rendering |
| Coordinate conversion | Custom isometric math | IsometricMath static methods | Battle-tested, handles camera zoom |
| Size constraint validation | Inline checking | ValidationOperation patterns | Consistent with existing validation |
| Door placement after resize | Custom door UI | Existing DoorEditController | Fully implemented, just enter edit mode |

**Key insight:** Room resize is 80% reuse of existing code. The only new logic is:
1. ResizeController state machine
2. Furniture-fits-in-bounds validation
3. Preview highlight for the new bounds

## Common Pitfalls

### Pitfall 1: Furniture Outside New Bounds
**What goes wrong:** Resize commits and furniture ends up on walls or outside room entirely.
**Why it happens:** Only checking furniture origin position, not full footprint and access tiles.
**How to avoid:** Validate ALL tiles for ALL furniture pieces before allowing resize. Show blocked furniture visually.
**Warning signs:** Furniture overlapping walls, inaccessible furniture, patrons stuck.

### Pitfall 2: Shared Walls Deleted
**What goes wrong:** Adjacent room loses its wall when resize removes it from the resized room.
**Why it happens:** Not reusing DeletionOperation's shared wall detection.
**How to avoid:** Use DeletionOperation.get_deletable_walls() which checks against all other rooms.
**Warning signs:** Holes in adjacent room walls, terrain artifacts.

### Pitfall 3: Exterior Walls Affected
**What goes wrong:** Resize allows new bounds to overlap with exterior (scene) walls, or deletes them.
**Why it happens:** Not passing exterior_walls array to deletion/validation.
**How to avoid:** Pass Main._exterior_walls to ResizeOperation, exclude from deletable walls.
**Warning signs:** Scene walls disappear, doors placed on exterior.

### Pitfall 4: Drag Detection Conflicts
**What goes wrong:** Resize drag conflicts with camera pan or room selection.
**Why it happens:** Not disabling other input handlers during resize mode.
**How to avoid:** Disable camera pan (camera.enable_pinch_pan = false), disable room selection (_room_manager.disable_selection()).
**Warning signs:** Accidental camera movement, room deselection during resize.

### Pitfall 5: Door Placement Never Completes
**What goes wrong:** User exits resize before placing doors, room has no doors.
**Why it happens:** Allowing cancel during door placement phase.
**How to avoid:** Require at least minimum doors before allowing exit (match room type requirements).
**Warning signs:** Rooms with zero doors, patrons can't enter.

### Pitfall 6: Preview Box Coordinates Wrong
**What goes wrong:** Preview shows in wrong location relative to actual tiles.
**Why it happens:** Mixing screen space and world space coordinates.
**How to avoid:** Use IsometricMath.tile_to_screen() for drawing, IsometricMath.screen_to_tile() for input.
**Warning signs:** Preview doesn't align with grid, clicks register on wrong tiles.

## Code Examples

Verified patterns from existing codebase:

### Input Handling (from RoomBuildUI)
```gdscript
# Source: RoomBuildUI.gd lines 122-140
func _input(event: InputEvent) -> void:
    if _drawing:
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _box_start = _screen_to_tile(event.global_position)
                _current_mouse_pos = _box_start
                _is_dragging = true
                queue_redraw()
            elif _is_dragging:
                _box_end = _screen_to_tile(event.global_position)
                _is_dragging = false
                _drawing = false
                queue_redraw()
                box_draw_completed.emit(_box_start, _box_end)
        elif event is InputEventMouseMotion and _is_dragging:
            _current_mouse_pos = _screen_to_tile(event.global_position)
            queue_redraw()
```

### Box Preview Drawing (from RoomBuildUI)
```gdscript
# Source: RoomBuildUI.gd lines 184-244
func _draw_box_selection() -> void:
    var min_tile = Vector2i(
        mini(_box_start.x, _current_mouse_pos.x),
        mini(_box_start.y, _current_mouse_pos.y)
    )
    var max_tile = Vector2i(
        maxi(_box_start.x, _current_mouse_pos.x),
        maxi(_box_start.y, _current_mouse_pos.y)
    )

    # Generate wall positions
    var wall_positions: Array[Vector2i] = []
    for x in range(min_tile.x, max_tile.x + 1):
        wall_positions.append(Vector2i(x, min_tile.y))
        wall_positions.append(Vector2i(x, max_tile.y))
    for y in range(min_tile.y + 1, max_tile.y):
        wall_positions.append(Vector2i(min_tile.x, y))
        wall_positions.append(Vector2i(max_tile.x, y))

    # Draw interior tiles
    for x in range(min_tile.x + 1, max_tile.x):
        for y in range(min_tile.y + 1, max_tile.y):
            _draw_tile_highlight(Vector2i(x, y), interior_color)

    # Draw wall tiles
    for wall_pos in wall_positions:
        _draw_tile_highlight(wall_pos, wall_color)
```

### Shared Wall Detection (from DeletionOperation)
```gdscript
# Source: DeletionOperation.gd lines 16-38
func get_deletable_walls(room: RoomInstance, room_manager: Node, exterior_walls: Array[Vector2i]) -> Array[Vector2i]:
    var deletable: Array[Vector2i] = []

    for wall_pos in room.walls:
        # Check 1: Is this an exterior wall?
        if wall_pos in exterior_walls:
            continue

        # Check 2: Is this wall shared with another room?
        var is_shared := false
        for other_room in room_manager.get_all_rooms():
            if other_room == room:
                continue
            if wall_pos in other_room.walls:
                is_shared = true
                break

        if is_shared:
            continue

        deletable.append(wall_pos)

    return deletable
```

### Room Size Validation (from RoomBuildController)
```gdscript
# Source: RoomBuildController.gd lines 119-131
if current_room_type:
    var min_s = current_room_type.min_size
    var max_s = current_room_type.max_size
    # Check both orientations
    var normal_valid = box.size.x >= min_s.x and box.size.y >= min_s.y \
                   and box.size.x <= max_s.x and box.size.y <= max_s.y
    var swapped_valid = box.size.x >= min_s.y and box.size.y >= min_s.x \
                    and box.size.x <= max_s.y and box.size.y <= max_s.x
    if not normal_valid and not swapped_valid:
        var error_msg = "Invalid size! Required: %dx%d to %dx%d" % [min_s.x, min_s.y, max_s.x, max_s.y]
        ui.show_validation_errors([error_msg])
        return
```

### Furniture Tile Iteration (from CollisionOperation)
```gdscript
# Source: CollisionOperation.gd lines 18-35
func can_place_furniture(furniture: FurnitureResource, position: Vector2i,
                        rotation: int, room: RoomInstance) -> CollisionResult:
    var result = CollisionResult.new()
    var tiles = _get_footprint_tiles(furniture, position, rotation)

    for tile in tiles:
        if not _is_tile_valid(tile, room):
            result.can_place = false
            result.blocked_tiles.append(tile)

    var access_tiles = _get_access_tiles(furniture, position, rotation)
    for tile in access_tiles:
        if not _is_access_tile_valid(tile, room, tiles):
            result.can_place = false
            result.blocked_access_tiles.append(tile)

    return result
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Individual wall manipulation | Delete + rebuild | Phase 8 (new) | Simpler, reuses tested code |
| 8 corner/edge drag handles | Box drawing (corner to corner) | Phase 8 (new) | Better touch UX, matches build mode |
| Auto-adjust door positions | Reset doors on resize | Prior decision | Eliminates complex door movement logic |
| Keep furniture positions | Validate furniture fits | Phase 8 (new) | Furniture absolute positions unchanged |

**Deprecated/outdated:**
- In-place wall modification considered too complex for benefit
- Corner drag handles rejected due to isometric positioning difficulty

## Open Questions

1. **Should preview show furniture that would be blocked?**
   - What we know: Validation identifies blocked furniture
   - What's unclear: UX for showing which furniture blocks resize
   - Recommendation: Draw blocked furniture tiles in orange during preview; add error message listing furniture names

2. **What happens if user tries to resize smaller than furniture extent?**
   - What we know: Validation will fail, preview shows invalid
   - What's unclear: Should we auto-calculate minimum valid size?
   - Recommendation: For simplicity, just show invalid preview; don't calculate minimum. User can visually adjust.

3. **Should resize be accessible from main edit menu or separate entry point?**
   - What we know: Current menu has Edit Furniture, Edit Room (doors), Room Type Action, Delete
   - What's unclear: Does "Edit Room" mean doors only or doors + resize?
   - Recommendation: Add "Resize Room" as separate menu button (keeps concerns separated)

4. **How to handle resize when room is adjacent to another room?**
   - What we know: DeletionOperation preserves shared walls during cleanup
   - What's unclear: Can resize extend INTO adjacent room's space?
   - Recommendation: NO - validate new bounds don't overlap with other rooms. This prevents wall conflicts.

5. **Should resize support non-rectangular shapes in future?**
   - What we know: Current architecture assumes Rect2i bounding boxes
   - What's unclear: Future L-shaped or complex room support
   - Recommendation: Out of scope for Phase 8. Design for Rect2i only. Non-rectangular would require architecture changes.

6. **How to handle the Area2D selection polygon after resize?**
   - What we know: RoomManager creates Area2D from bounding box
   - What's unclear: Does Area2D need recreation or can polygon be updated?
   - Recommendation: Recreate Area2D by calling unregister_room + register_room, or add update_selection_area() method

## Sources

### Primary (HIGH confidence)
- Existing codebase: RoomBuildUI.gd - box drawing input and preview rendering patterns
- Existing codebase: DeletionOperation.gd - shared wall detection and deletion sequence
- Existing codebase: WallOperation.gd - wall generation from bounding box
- Existing codebase: CollisionOperation.gd - tile validation patterns
- Existing codebase: FurnitureEditController.gd - edit mode state machine patterns
- Existing codebase: DoorEditController.gd - door edit mode patterns

### Secondary (MEDIUM confidence)
- Existing codebase: RoomBuildController.gd - room completion workflow, size validation
- Existing codebase: ValidationOperation.gd - room type constraint checking
- Existing codebase: Main.gd - controller wiring patterns

### Tertiary (LOW confidence)
- Phase requirements from ROADMAP.md - resize requirements interpretation
- Prior decisions from STATE.md - "doors reset on resize" decision

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already exist in project
- Architecture (delete+rebuild): HIGH - Directly follows and reuses existing operations
- Architecture (state machine): MEDIUM - New controller, but follows established patterns
- Furniture validation: MEDIUM - New validation, but extends existing CollisionOperation
- Preview rendering: HIGH - Directly reuses RoomBuildUI patterns
- Pitfalls: MEDIUM - Identified from codebase analysis, some are hypothetical

**Research date:** 2026-02-01
**Valid until:** 2026-03-03 (30 days - stable architecture, building on established patterns)
