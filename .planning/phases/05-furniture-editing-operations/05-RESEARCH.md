# Phase 5: Furniture Editing Operations - Research

**Researched:** 2026-01-23
**Domain:** Godot 4.5 furniture drag-and-drop, mobile touch input, grid snapping, visual feedback
**Confidence:** HIGH

## Summary

Phase 5 requires implementing move, add, and delete operations for furniture within existing rooms. The codebase already has strong foundations: FurnitureEditController for selection state, CollisionOperation for placement validation, FurnitureOperation for visual creation, and RoomSerializer for atomic persistence. The key challenges are implementing drag gesture detection (distinguishing tap from drag on mobile), grid-snapped dragging with visual preview, and proper cleanup of visual nodes on delete.

Godot 4.5 provides InputEventMouseMotion (desktop) and InputEventScreenDrag (mobile) for drag operations, but the codebase pattern uses InputEventMouseButton/InputEventScreenTouch exclusively, tracking drag distance to distinguish tap from drag. This pattern works well for tap detection and should be extended with motion events for continuous drag feedback.

**Primary recommendation:** Extend the existing tap detection pattern (TAP_DISTANCE_THRESHOLD = 20px) with motion events for drag operations. Track drag state in FurnitureEditController, update furniture position on each motion event with grid snap, and use CollisionOperation for real-time validation feedback. Store visual node references in FurniturePlacement for cleanup on delete.

## Standard Stack

The codebase already uses the correct Godot 4.5 patterns. No external libraries needed.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.5 | Game engine | Project requirement |
| GDScript | 4.5 | Scripting language | Project convention (CLAUDE.md) |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| InputEventMouseMotion | Desktop drag tracking | Continuous position updates during mouse drag |
| InputEventScreenDrag | Mobile drag tracking | Continuous position updates during touch drag |
| Timer (one_shot) | Debounced auto-save | Delay save after each furniture operation (5s) |
| queue_free() | Node cleanup | Delete furniture visual nodes on furniture removal |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Motion events for drag | Position delta between tap start/end | Motion events provide continuous feedback, delta only works for final position |
| Manual node tracking | WeakRef for visual nodes | WeakRef adds complexity but prevents dangling references; not needed if lifecycle is controlled |
| Custom drag preview | Control._get_drag_data() | Control drag/drop is for UI elements, not world-space objects |

**Installation:**
No additional packages required - all features are built into Godot 4.5.

## Architecture Patterns

### Recommended Controller Extension

Extend FurnitureEditController to manage drag state:

```
FurnitureEditController (Control)
├── Selection state (_selected_furniture)
├── Drag state (_dragging, _drag_start_pos, _drag_offset)
├── Furniture areas (Area2D for tap detection)
└── Drag preview (via signal to Main for visual update)
```

### Pattern 1: Tap-to-Drag State Machine

**What:** Three-state system: idle → dragging → idle. Tap detection distinguishes selection from drag start.

**When to use:** All furniture interaction modes (move, add, delete require selection first).

**Example:**
```gdscript
# Source: Existing RoomManager.gd tap detection pattern (lines 12-14, 187-208)
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

# State tracking
var _dragging := false
var _touch_start_pos := Vector2.ZERO
var _touch_start_time := 0
var _drag_offset := Vector2i.ZERO  # Offset from furniture position to tap point

func _on_furniture_input(event: InputEvent):
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
            _drag_offset = _screen_to_tile(event.position) - _selected_furniture.position
        else:
            if _dragging:
                _end_drag()
            else:
                var distance = event.position.distance_to(_touch_start_pos)
                var duration = Time.get_ticks_msec() - _touch_start_time
                if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                    _select_furniture()

    elif event is InputEventMouseMotion:
        if _touch_start_pos != Vector2.ZERO:
            var distance = event.position.distance_to(_touch_start_pos)
            if distance >= TAP_DISTANCE_THRESHOLD and not _dragging:
                _start_drag()
        if _dragging:
            _update_drag_position(event.position)
```

### Pattern 2: Grid-Snapped Drag with Collision Preview

**What:** Convert screen position to tile position on each motion event, validate with CollisionOperation, emit signal for visual update.

**When to use:** Move operation, add operation (placement).

**Example:**
```gdscript
# Source: CollisionOperation.get_placement_preview (lines 37-56)
func _update_drag_position(screen_pos: Vector2):
    var tile_pos = _screen_to_tile(screen_pos) - _drag_offset

    # Validate placement
    var preview = _collision_operation.get_placement_preview(
        _selected_furniture.furniture,
        tile_pos,
        _selected_furniture.rotation,
        _current_room
    )

    # Update ghost position (emit signal to Main for visual update)
    var is_valid = preview.blocked_tiles.is_empty() and preview.blocked_access_tiles.is_empty()
    furniture_drag_preview.emit(tile_pos, is_valid)

    # Store for end_drag
    _preview_position = tile_pos
    _preview_valid = is_valid
```

### Pattern 3: Visual Node Reference Tracking

**What:** Store visual node reference in FurniturePlacement for cleanup on delete.

**When to use:** All furniture creation (add, restore from save).

**Example:**
```gdscript
# Source: Extended from RoomInstance.FurniturePlacement (lines 33-42)
class FurniturePlacement:
    var furniture: FurnitureResource
    var position: Vector2i
    var rotation: int
    var visual_node: Node2D = null  # NEW: reference for cleanup

    func cleanup_visual():
        if visual_node and is_instance_valid(visual_node):
            visual_node.queue_free()
        visual_node = null

# In FurnitureOperation.create_furniture_visual
func create_furniture_visual(...) -> Node2D:
    # ... existing creation code ...
    var node = _setup_furniture_instance(...)
    placement.visual_node = node  # Store reference
    return node
```

### Pattern 4: Debounced Auto-Save

**What:** Timer with one_shot=true, restarted on each furniture change, saves when timer fires.

**When to use:** After move, add, or delete operations complete.

**Example:**
```gdscript
# Source: RoomManager auto-save pattern (lines 17, 41-46, 216-222)
const SAVE_DEBOUNCE_SECONDS := 5.0
var _save_debounce_timer: Timer = null

func _setup_save_timer():
    _save_debounce_timer = Timer.new()
    _save_debounce_timer.one_shot = true
    _save_debounce_timer.wait_time = SAVE_DEBOUNCE_SECONDS
    _save_debounce_timer.timeout.connect(_on_save_timer_timeout)
    add_child(_save_debounce_timer)

func _schedule_save():
    if _save_debounce_timer.is_stopped():
        _save_debounce_timer.start()
    # Timer already running restarts automatically in Godot 4
```

### Anti-Patterns to Avoid

- **Don't use Control drag/drop system (_get_drag_data):** Control drag/drop is designed for UI widgets in screen space, not world-space objects with isometric coordinates and camera transforms. The existing tap detection + motion event pattern is correct for this use case.

- **Don't update furniture position every frame during drag:** Only update on InputEvent (motion events), not in _process(). Event-driven updates are more efficient and prevent unnecessary redraws.

- **Don't delete furniture without validation:** Always check RoomTypeResource.required_furniture before allowing delete. Block with error message if deletion would violate minimum requirements.

- **Don't forget to emit placement_changed signal:** RoomInstance.placement_changed triggers auto-save via RoomManager. Forgetting this signal means changes won't persist.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Placement validation | Custom bounds/collision checks | CollisionOperation.can_place_furniture() | Handles footprint tiles, access tiles, rotation, and multi-tile furniture correctly |
| Visual preview | Custom tile overlay system | CollisionOperation.get_placement_preview() | Returns valid/blocked tiles separated, already handles access tiles |
| Isometric coordinate conversion | Custom math formulas | IsometricMath.screen_to_tile() | Accounts for viewport canvas_transform (camera zoom/pan) |
| Grid snapping | Round/floor operations | IsometricMath.screen_to_tile() returns Vector2i | Automatic grid snap via integer return type |
| Visual node cleanup | Manual remove_child calls | Node.queue_free() | Handles deferred cleanup safely, removes all children automatically |
| Required furniture validation | Count furniture manually | ValidationOperation.validate_complete() | Already checks required_furniture array with proper counts |
| Debounced save | call_deferred + flag variables | Timer with one_shot=true | Built-in timer restart handling, cleaner state management |

**Key insight:** The existing operations pattern (CollisionOperation, FurnitureOperation, ValidationOperation) provides all necessary validation and visual creation logic. Don't bypass these - they handle edge cases like multi-tile furniture rotation, access tile validation, and isometric coordinate transforms that are easy to get wrong.

## Common Pitfalls

### Pitfall 1: Tap vs Drag Ambiguity on Mobile

**What goes wrong:** User taps furniture to select, but small hand movement during tap registers as drag, causing unintended furniture movement.

**Why it happens:** Touch screens register motion even during intended taps. Without distance/time thresholds, any motion event starts a drag.

**How to avoid:** Use TAP_DISTANCE_THRESHOLD (20px) and TAP_TIME_THRESHOLD (300ms) to distinguish tap from drag. Only transition to drag state if motion distance exceeds threshold.

**Warning signs:** Furniture "jumps" to new position on simple tap, users report difficulty selecting furniture.

### Pitfall 2: Forgetting to Update Navigation Mesh After Furniture Changes

**What goes wrong:** Furniture is moved/added/deleted, but patrons still path through the old location or get stuck trying to reach the new location.

**Why it happens:** TileMapLayer navigation mesh is baked at specific tile positions. Moving furniture erases tiles from old position and new position, but navigation mesh doesn't automatically update.

**How to avoid:** Call TileMapLayer baking methods after furniture changes. In Godot 4.5, TileMapLayer has automatic navigation mesh generation when tiles are modified, but verify behavior with set_cell/erase_cell operations.

**Warning signs:** Patrons walk through furniture, patrons fail to path to furniture, navigation agents timeout.

### Pitfall 3: Dangling Visual Node References After queue_free()

**What goes wrong:** FurniturePlacement.visual_node points to freed node, causing "Invalid instance" errors when accessed.

**Why it happens:** queue_free() defers deletion until end of frame. Code executing in same frame sees valid node reference that becomes invalid later.

**How to avoid:** Always use is_instance_valid() before accessing visual_node reference. Set visual_node = null after calling queue_free(). Don't access visual_node in same frame as queue_free() call.

**Warning signs:** Crashes with "Attempt to call function 'X' in base 'previously freed instance'" errors, intermittent null reference errors.

### Pitfall 4: Drag Offset Not Accounting for Multi-Tile Furniture

**What goes wrong:** Dragging multi-tile furniture causes it to "jump" so the top-left corner snaps to cursor, not the tile user clicked on.

**Why it happens:** Multi-tile furniture position is the top-left tile, but user may click on any occupied tile. Without storing drag offset, furniture position always equals cursor position.

**How to avoid:** On drag start, calculate offset = cursor_tile - furniture.position. During drag, furniture.position = cursor_tile - offset. This maintains the relative position of the click point.

**Warning signs:** Furniture "jumps" when drag starts, user can't drag furniture by grabbing center or right edge.

### Pitfall 5: Deleting Required Furniture Without Validation

**What goes wrong:** Room becomes invalid (fails validation), player can't complete room or save breaks on next load.

**Why it happens:** RoomTypeResource.required_furniture specifies minimum counts. Deleting below minimum violates room constraints.

**How to avoid:** Before allowing delete, check if furniture.count > required_count for that furniture type. Show error message "Cannot delete - X is required for this room type (minimum Y)".

**Warning signs:** ValidationOperation.validate_complete() returns errors after delete, rooms disappear on reload.

### Pitfall 6: InputEventScreenDrag Not Receiving Events

**What goes wrong:** Mouse drag works on desktop, but touch drag doesn't work on mobile.

**Why it happens:** Godot generates InputEventScreenDrag only for actual touch devices. Emulated touch input (desktop testing) may generate InputEventMouseMotion instead. Also, Area2D.input_pickable must be true for input_event signal to fire.

**How to avoid:** Handle both InputEventMouseMotion and InputEventScreenDrag in the same handler. Test on actual mobile device or use Godot's remote debug feature to validate touch events.

**Warning signs:** Works on desktop, fails on mobile; no drag events received during touch.

## Code Examples

Verified patterns from existing codebase:

### Tap Detection Pattern (Cross-Platform)
```gdscript
# Source: RoomManager.gd (lines 185-208)
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, room: RoomInstance):
    # Handle mouse clicks (desktop)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            var distance: float = event.position.distance_to(_touch_start_pos)
            var duration := Time.get_ticks_msec() - _touch_start_time
            if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                select_room(room)
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
                select_room(room)
```

### Collision Validation with Preview
```gdscript
# Source: CollisionOperation.gd (lines 37-56)
func get_placement_preview(furniture: FurnitureResource, position: Vector2i,
                          rotation: int, room: RoomInstance) -> PreviewResult:
    var result = PreviewResult.new()
    result.tiles = _get_footprint_tiles(furniture, position, rotation)

    for tile in result.tiles:
        if _is_tile_valid(tile, room):
            result.valid_tiles.append(tile)
        else:
            result.blocked_tiles.append(tile)

    # Get access tiles
    result.access_tiles = _get_access_tiles(furniture, position, rotation)
    for tile in result.access_tiles:
        if _is_access_tile_valid(tile, room, result.tiles):
            result.valid_access_tiles.append(tile)
        else:
            result.blocked_access_tiles.append(tile)

    return result
```

### Visual Tile Highlight (Isometric)
```gdscript
# Source: FurnitureSelectionHighlight.gd (lines 51-69)
func _draw():
    if _controller == null:
        return

    var furniture := _controller.get_selected_furniture()
    if furniture == null:
        return

    var viewport := get_viewport()

    # Draw access tiles first (lighter color, shows where patrons stand)
    var access_tiles := furniture.get_access_tiles()
    for tile in access_tiles:
        RoomBuildDrawing.draw_tile_highlight(self, tile, ACCESS_TILE_COLOR, viewport)

    # Draw occupied tiles on top (main selection highlight)
    var occupied_tiles := furniture.get_occupied_tiles()
    for tile in occupied_tiles:
        RoomBuildDrawing.draw_tile_highlight(self, tile, SELECTION_COLOR, viewport)
```

### Safe Node Cleanup
```gdscript
# Source: Best practice pattern from Godot forums
# https://forum.godotengine.org/t/discussion-of-best-practices-regarding-queue-free/5159
func delete_furniture(placement: RoomInstance.FurniturePlacement):
    # Cleanup visual node first
    if placement.visual_node and is_instance_valid(placement.visual_node):
        placement.visual_node.queue_free()
    placement.visual_node = null

    # Remove from room's furniture array
    var index = _current_room.furniture.find(placement)
    if index >= 0:
        _current_room.furniture.remove_at(index)

    # Trigger auto-save
    _current_room.placement_changed.emit()
```

### Required Furniture Validation
```gdscript
# Source: ValidationOperation.gd (lines 31-39)
# Furniture check using typed FurnitureRequirement
for req in room_type.get_required_furniture():
    if not req.furniture:
        continue
    var actual_count = room.get_furniture_count_by_resource(req.furniture)
    if actual_count < req.count:
        var display_name = req.furniture.name if req.furniture.name else req.furniture.id
        result.is_valid = false
        result.errors.append("Need %d more %s(s)" % [req.count - actual_count, display_name])
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| TileMap node | TileMapLayer node | Godot 4.0+ | TileMap deprecated in favor of multiple TileMapLayer nodes for better layer management |
| Manual navigation mesh baking | Automatic on tile changes | Godot 4.0+ | TileMapLayer automatically updates navigation mesh when set_cell/erase_cell called (verify in 4.5) |
| InputEventScreenDrag.relative_pos | InputEventScreenDrag.relative | Godot 3.x → 4.x | Property renamed, now represents frame-to-frame delta, not start position delta |
| Control drag/drop for world objects | Area2D + motion events | Best practice | Control drag/drop is for UI widgets, Area2D with motion tracking is for world-space objects |

**Deprecated/outdated:**
- Using TileMap instead of TileMapLayer: TileMap node is deprecated in Godot 4+, use TileMapLayer
- Setting visual_node = null without is_instance_valid(): Always validate before access to avoid "previously freed instance" errors
- Assuming NavigationRegion2D.bake_navigation_polygon() for tilemaps: TileMapLayer has built-in navigation, don't add separate NavigationRegion2D

## Open Questions

1. **TileMapLayer auto-bake behavior in Godot 4.5**
   - What we know: TileMapLayer should automatically update navigation mesh when tiles change via set_cell/erase_cell
   - What's unclear: Does FurnitureOperation._clear_furniture_tiles() trigger auto-bake, or do we need manual bake call?
   - Recommendation: Test with furniture add/move/delete and verify patrons re-path correctly. If not, call manual bake or investigate TileMapLayer navigation settings

2. **Visual node lifecycle for moved furniture**
   - What we know: Move operation changes FurniturePlacement.position but doesn't recreate visual node
   - What's unclear: Should we update existing visual_node.position, or queue_free() and recreate at new position?
   - Recommendation: Update existing node position for performance (avoid instantiate overhead). Only recreate if rotation changes (sprite frame update required)

3. **Multi-touch handling for simultaneous furniture operations**
   - What we know: InputEventScreenDrag has index property for multi-touch
   - What's unclear: Should Phase 5 support dragging multiple furniture simultaneously, or limit to single-touch?
   - Recommendation: Limit to single-touch for Phase 5 (simpler state management). Track first touch index, ignore other touches until first completes

## Sources

### Primary (HIGH confidence)
- Existing codebase files (verified via Read tool):
  - `FurnitureEditController.gd` - Selection state management, tap detection
  - `RoomInstance.gd` - FurniturePlacement data model
  - `CollisionOperation.gd` - Placement validation and preview
  - `FurnitureOperation.gd` - Visual node creation
  - `RoomManager.gd` - Auto-save debounce timer pattern, tap detection
  - `RoomBuildUI.gd` - Ghost preview and drag visualization patterns
  - `IsometricMath.gd` - Screen-to-tile coordinate conversion
  - `RotationHelper.gd` - Multi-tile footprint calculation with rotation

### Secondary (MEDIUM confidence)
- [Godot 4.5 Drag and Drop Tutorial](https://generalistprogrammer.com/godot/godot-drag-and-drop-tutorial/) - Comprehensive guide on drag and drop in Godot 4.x
- [Godot Engine Forum: Drag and drop on touch screen](https://forum.godotengine.org/t/drag-and-drop-on-touch-screen/129827) - Recent discussion on mobile touch drag (Dec 2025)
- [Godot Timer Node Best Practices](https://forum.godotengine.org/t/timer-node-best-practices/84112) - Timer patterns for debouncing
- [Godot Forum: Discussion of best practices regarding queue_free()](https://forum.godotengine.org/t/discussion-of-best-practices-regarding-queue-free/5159) - Safe node cleanup patterns
- [Godot Forum: Updating navigation mesh mid-game](https://forum.godotengine.org/t/updating-navigation-mesh-mid-game/109807) - Runtime navigation updates

### Tertiary (LOW confidence - WebSearch only)
- [InputEventScreenDrag Documentation](https://docs.godotengine.org/en/stable/classes/class_inputeventscreendrag.html) - Official docs (WebFetch failed to extract content)
- [TileMapLayer Documentation](https://docs.godotengine.org/en/4.5/classes/class_tilemaplayer.html) - Official docs (WebFetch failed to extract content, navigation methods not confirmed)
- [GitHub Issue: NavigationRegion2D doesn't update](https://github.com/godotengine/godot/issues/85545) - Known issue with navigation mesh updates (may be resolved in 4.5)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Verified existing codebase patterns, no new libraries needed
- Architecture: HIGH - Existing operations pattern provides all necessary components
- Pitfalls: HIGH - Identified from codebase analysis and cross-platform input handling requirements
- Navigation mesh updates: MEDIUM - TileMapLayer auto-bake behavior needs runtime verification

**Research date:** 2026-01-23
**Valid until:** 2026-02-23 (30 days - Godot stable, patterns established)
