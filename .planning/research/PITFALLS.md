# Domain Pitfalls: Room Editing & Persistence

**Domain:** Mobile theater simulation with room editing and JSON persistence
**Researched:** 2026-01-21
**Confidence:** MEDIUM (verified with Godot community sources, some platform-specific issues flagged)

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or major architectural issues.

### Pitfall 1: Navigation Map Not Updated After Room Edits
**What goes wrong:** Patrons walk through walls, get stuck, or path through deleted rooms because NavigationRegion2D wasn't rebaked after modifications.

**Why it happens:**
- Godot 4.5 changed navigation update behavior - baking must be explicit
- Moving/resizing rooms changes collision shapes but doesn't auto-trigger nav rebake
- Deleting furniture clears ground tiles but NavigationAgent2D paths use stale data

**Consequences:**
- Patrons exhibit broken pathfinding
- Player notices AI walking through newly-placed walls
- Game feels broken despite correct visual representation

**Prevention:**
```gdscript
# After ANY room modification:
func _update_after_room_edit(room: RoomInstance) -> void:
    _wall_op.update_wall_visuals(room, tilemap_layer)
    _furniture_op.update_furniture_visuals(room, furniture_visuals)
    _navigation_op.update_room_navigation(room, tilemap_layer)  # CRITICAL
    Targets.notify_navigation_changed()  # Tell patrons to recalculate
```

**Detection:**
- Patrons move through newly-created walls
- `nav_agent.is_target_reachable()` returns false after room edits
- Console warnings: "Navigation region synchronization error"

**Phase to address:** Phase 1 (Room Selection & Visual Feedback) must establish the update pattern immediately, before implementing actual edits.

**Sources:**
- [Godot 4.5 NavigationRegion2D pathfinding issues](https://github.com/godotengine/godot/issues/110686)
- [Using NavigationAgents documentation](https://docs.godotengine.org/en/latest/tutorials/navigation/navigation_using_navigationagents.html)

---

### Pitfall 2: Save File Corruption from Non-Atomic Writes
**What goes wrong:** Game crashes during save → partial file written → save data corrupted → player loses all progress.

**Why it happens:**
- Writing directly to `user://save.json` with `FileAccess.open(path, WRITE)` overwrites immediately
- If app crashes mid-write (battery dies, OS kills app), file is incomplete
- Mobile platforms have higher crash rates (memory pressure, background suspension)
- JSON string serialization can be large (multiple rooms with furniture arrays)

**Consequences:**
- Player opens game after crash → corrupted JSON → save won't load
- No recovery mechanism → permanent progress loss
- Negative reviews citing "lost my theater"

**Prevention:**
```gdscript
func save_game_safe(data: Dictionary) -> void:
    var temp_path = "user://save.json.tmp"
    var final_path = "user://save.json"

    # Write to temporary file first
    var file = FileAccess.open(temp_path, FileAccess.WRITE)
    if not file:
        push_error("Failed to open temp save file")
        return

    file.store_string(JSON.stringify(data, "\t"))
    file.close()

    # Verify temp file is valid JSON before committing
    var verify_file = FileAccess.open(temp_path, FileAccess.READ)
    if verify_file:
        var test_parse = JSON.parse_string(verify_file.get_as_text())
        verify_file.close()

        if test_parse:
            # Only now overwrite the real save file
            DirAccess.rename_absolute(temp_path, final_path)
        else:
            push_error("Temp save file invalid, aborting save")
```

**Detection:**
- `JSON.parse_string()` returns null on load
- FileAccess errors when opening save file
- Save file size is unexpectedly small (incomplete write)

**Phase to address:** Phase 4 (JSON Persistence) must implement atomic saves from the start. Do NOT defer to "polish phase."

**Sources:**
- [Godot save data corruption prevention](https://www.wayline.io/blog/godot-save-systems-configfiles)
- [Allow Godot to handle corrupted files](https://github.com/godotengine/godot-proposals/issues/10684)
- [Safe save fails too often](https://github.com/godotengine/godot/issues/40366)

---

### Pitfall 3: RefCounted Memory Leaks from Signal Connections
**What goes wrong:** `RoomInstance` objects (RefCounted) never freed because signals keep them alive → memory grows unbounded → mobile app crashes.

**Why it happens:**
- `RoomInstance` emits `placement_changed` signal
- UI or controller connects to signal: `room.placement_changed.connect(_on_room_changed)`
- Signal connection increments reference count
- Even when room is "deleted," signal connection keeps it in memory
- Mobile devices have limited RAM (~2-4GB) - leaks hit hard

**Consequences:**
- Memory usage grows with each room edit
- After 50-100 room operations, app crashes on mobile
- Desktop testing doesn't catch it (16GB+ RAM masks the issue)

**Prevention:**
```gdscript
# In RoomBuildController or UI:
var _active_room: RoomInstance = null

func start_editing_room(room: RoomInstance) -> void:
    # Disconnect old room first
    if _active_room and _active_room.placement_changed.is_connected(_on_placement_changed):
        _active_room.placement_changed.disconnect(_on_placement_changed)

    _active_room = room
    room.placement_changed.connect(_on_placement_changed)

func finish_editing_room() -> void:
    if _active_room and _active_room.placement_changed.is_connected(_on_placement_changed):
        _active_room.placement_changed.disconnect(_on_placement_changed)
    _active_room = null  # Drop reference
```

**Detection:**
- `print(Performance.get_monitor(Performance.MEMORY_STATIC))` keeps growing
- "ObjectDB instances leaked at exit" console warnings
- Mobile device out-of-memory crashes after extended play

**Phase to address:** Phase 2 (Room Editing Operations) when implementing selection. Add explicit cleanup from the start.

**Sources:**
- [Do signal connections prevent RefCounted garbage collection?](https://forum.godotengine.org/t/do-signal-connections-prevent-refcounted-garbage-collection/111346)
- [Conditions that cause memory leaks](https://forum.godotengine.org/t/conditions-that-cause-memory-leaks/95406)
- [Memory leak for objects storing self reference](https://github.com/godotengine/godot/issues/82882)

---

### Pitfall 4: Isometric Coordinate Confusion Between Edit and Runtime
**What goes wrong:** Room appears correct during placement but offset when loaded from save file, or furniture placed at wrong coordinates after room resize.

**Why it happens:**
- During build: UI uses screen coords → `_screen_to_tile()` → stores in `RoomInstance`
- During edit: Mouse coords are screen coords but room might have moved
- Canvas transform changes (camera pan/zoom) affect conversion
- `bounding_box.position` is absolute tile coords, but furniture positions might be stored relative or absolute
- Isometric math has subtle rounding errors (`floor` vs `round` vs `ceil`)

**Consequences:**
- Furniture appears 1-2 tiles offset from where player placed it
- Room walls render at wrong location after load
- Player can't click furniture to select it (collision detection uses wrong coords)

**Prevention:**
```gdscript
# ALWAYS use consistent coordinate system:
# - RoomInstance stores ABSOLUTE tile coordinates (Vector2i)
# - All operations convert screen → world → tile via IsometricMath helper
# - Never store world positions (Vector2), only tile positions (Vector2i)

# In RoomInstance:
class FurniturePlacement:
    var furniture: FurnitureResource
    var tile_position: Vector2i  # Absolute tile coords
    var rotation: int

# When saving:
func to_dict() -> Dictionary:
    return {
        "bounding_box": {
            "position": [bounding_box.position.x, bounding_box.position.y],
            "size": [bounding_box.size.x, bounding_box.size.y]
        },
        "furniture": furniture.map(func(f): return {
            "id": f.furniture.id,
            "tile_x": f.tile_position.x,  # Always tile coords
            "tile_y": f.tile_position.y,
            "rotation": f.rotation
        })
    }
```

**Detection:**
- Place furniture, save, reload → furniture is offset
- Room bounding box renders at wrong position after load
- Console logs show tile coords with decimal values (should be int)

**Phase to address:** Phase 4 (JSON Persistence) must verify coordinate round-tripping. Add unit tests for save→load→compare.

**Sources:**
- [Godot isometric grid editor coordinate system issues](https://github.com/godotengine/godot-proposals/issues/8944)
- [How to get AstarGrid working in isometric](https://forum.godotengine.org/t/how-to-get-astar-grid-working-in-isometric/41750)

---

### Pitfall 5: Touch Input Conflicts Between Pan and Selection
**What goes wrong:** Player tries to select a room to edit, but camera pans instead. Or tries to pan, but accidentally selects room.

**Why it happens:**
- Both camera pan and room selection respond to touch drag
- `InputEventScreenDrag` fires for both gestures
- No distinction between "short drag to pan" vs "tap to select"
- PPC addon (`addons/ppc/`) camera captures input before UI
- Godot 4.x has platform inconsistencies with touch index handling

**Consequences:**
- Editing on mobile feels broken
- Player can't reliably select rooms (keeps panning instead)
- Frustration → player abandons editing feature

**Prevention:**
```gdscript
# In Main controller - toggle input modes:
var _edit_mode_active: bool = false

func enable_edit_mode() -> void:
    _edit_mode_active = true
    camera.enable_pinch_pan = false  # Disable camera pan
    camera.enable_pinch_zoom = false
    room_selection_ui.enable()

func disable_edit_mode() -> void:
    _edit_mode_active = false
    camera.enable_pinch_pan = true
    camera.enable_pinch_zoom = true
    room_selection_ui.disable()

# In UI - detect tap vs drag:
var _touch_start_pos: Vector2
var _touch_start_time: int
const TAP_THRESHOLD := 20  # pixels
const TAP_TIME_MS := 300

func _on_screen_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        _touch_start_pos = event.position
        _touch_start_time = Time.get_ticks_msec()
    elif not event.pressed:
        var moved = event.position.distance_to(_touch_start_pos)
        var duration = Time.get_ticks_msec() - _touch_start_time

        if moved < TAP_THRESHOLD and duration < TAP_TIME_MS:
            _handle_tap(event.position)  # Selection
        # else: was a drag, ignore
```

**Detection:**
- Taps trigger camera pan instead of selection
- Can't select rooms on mobile (works on desktop with mouse)
- Touch events fire for both camera and UI

**Phase to address:** Phase 1 (Room Selection) must establish input mode toggle from the start. Test on mobile device, not just desktop.

**Sources:**
- [InputEventScreenTouch and InputEventScreenDrag problems](https://godotforums.org/d/27484-inputeventscreentouch-and-inputeventscreendrag-problem)
- [Issue with touch and drag simultaneously](https://forum.godotengine.org/t/issue-with-touch-and-drag-simultaneously/119328)
- [Touch index inconsistencies across platforms](https://github.com/godotengine/godot-proposals/issues/3772)

---

## Moderate Pitfalls

Mistakes that cause technical debt, performance issues, or user frustration.

### Pitfall 6: No Validation Before Save Allows Invalid States
**What goes wrong:** Player saves theater with invalid room (negative door count, furniture outside bounds) → load fails or causes runtime errors.

**Why it happens:**
- Room editing allows temporary invalid states (removed required furniture, deleted last door)
- Save triggered while in invalid state (auto-save, app suspension)
- No validation pass before serialization
- Deserialization assumes valid data structure

**Consequences:**
- Save file won't load (missing required fields)
- Runtime errors accessing furniture[invalid_index]
- Room type constraints violated (ValidationOperation passes during build but not on load)

**Prevention:**
```gdscript
func save_theater_state() -> void:
    var theater_data = {
        "rooms": []
    }

    # Validate each room before saving
    for room in _all_rooms:
        var validation = _validation_op.validate_complete(room)
        if not validation.is_valid:
            push_warning("Skipping invalid room %s: %s" % [room.id, validation.errors])
            continue  # Don't save invalid rooms

        theater_data.rooms.append(room.to_dict())

    _save_game_safe(theater_data)
```

**Detection:**
- Load fails with JSON parsing errors
- "Key not found" errors on deserialization
- Rooms missing furniture in loaded game

**Phase to address:** Phase 4 (JSON Persistence) - add validation before save.

---

### Pitfall 7: Furniture Visual Nodes Not Cleaned Up on Delete
**What goes wrong:** Delete furniture → sprite remains on screen → memory leak of Sprite2D nodes.

**Why it happens:**
- `FurnitureOperation.create_furniture_visual()` adds Sprite2D to scene tree
- Deleting from `RoomInstance.furniture` array doesn't remove scene node
- No tracking of which scene node corresponds to which FurniturePlacement

**Consequences:**
- Ghost furniture sprites remain visible
- Scene tree grows with orphaned nodes
- Memory usage increases

**Prevention:**
```gdscript
# In FurniturePlacement, track the visual node:
class FurniturePlacement:
    var furniture: FurnitureResource
    var tile_position: Vector2i
    var rotation: int
    var visual_node: Node2D  # Track scene node

# When deleting:
func remove_furniture(placement: FurniturePlacement) -> void:
    if placement.visual_node:
        placement.visual_node.queue_free()
    furniture.erase(placement)
    placement_changed.emit()
```

**Detection:**
- Furniture sprites remain after deletion
- Scene tree panel shows growing number of Sprite2D nodes
- Memory monitor shows node count increasing

**Phase to address:** Phase 2 (Room Editing Operations) when implementing furniture deletion.

---

### Pitfall 8: Undo/Redo Not Implemented for Editing
**What goes wrong:** Player accidentally deletes room or moves furniture → no undo → must manually rebuild.

**Why it happens:**
- Undo/Redo is complex (requires state snapshots)
- Tempting to defer as "polish"
- Mobile users expect undo (common iOS/Android pattern)

**Consequences:**
- Poor user experience on accidental edits
- Player frustration, especially on touch (easier to mis-tap)

**Prevention:**
```gdscript
# Use Godot's UndoRedo class:
var _undo_redo := UndoRedo.new()

func move_furniture(placement: FurniturePlacement, new_pos: Vector2i) -> void:
    var old_pos = placement.tile_position

    _undo_redo.create_action("Move Furniture")
    _undo_redo.add_do_method(self, "_set_furniture_position", placement, new_pos)
    _undo_redo.add_undo_method(self, "_set_furniture_position", placement, old_pos)
    _undo_redo.commit_action()

func _set_furniture_position(placement: FurniturePlacement, pos: Vector2i) -> void:
    placement.tile_position = pos
    _update_furniture_visual(placement)
```

**Detection:**
- No undo button in UI
- Player complaints about accidental deletions

**Phase to address:** Phase 3 (Furniture Management) should include basic undo. Don't defer to post-MVP.

**Sources:**
- [UndoRedo implementation question](https://godotforums.org/d/23515-undoredo-implementation-question)
- [Expose EditorUndoRedoManager to GDScript](https://github.com/godotengine/godot-proposals/issues/13377)

---

### Pitfall 9: Auto-Save Too Frequent or Too Rare
**What goes wrong:**
- Too frequent: Performance hitches every 10 seconds (JSON stringify is slow for large theaters)
- Too rare: Player loses 30 minutes of work when app crashes

**Why it happens:**
- No analysis of save operation duration
- Mobile has more frequent app suspension (phone call, home button)
- JSON serialization scales poorly (O(n) string concat)

**Consequences:**
- Frequent: Game stutters, feels laggy
- Rare: Data loss, negative reviews

**Prevention:**
```gdscript
# Event-based auto-save (better than timer):
func _on_room_completed(room: RoomInstance) -> void:
    _save_pending = true
    _save_timer.start(5.0)  # Debounce - wait 5s for more edits

func _on_furniture_placed() -> void:
    _save_pending = true
    _save_timer.start(5.0)

func _on_save_timer_timeout() -> void:
    if _save_pending:
        var start = Time.get_ticks_msec()
        save_theater_state()
        var duration = Time.get_ticks_msec() - start

        if duration > 100:
            push_warning("Save took %d ms, may cause stutter" % duration)

        _save_pending = false

# Also save on app suspension:
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        save_theater_state()  # iOS/Android backgrounding
```

**Detection:**
- Frame time spikes visible in profiler
- Player reports lag during play
- Data loss reports after crashes

**Phase to address:** Phase 5 (Auto-Save) - test save duration on mobile device with large theater (50+ rooms).

**Sources:**
- [When to save game on mobile](https://forum.unity.com/threads/when-to-save-game-on-mobile-and-what-events-to-use.1221564/)
- [Saved Games best practices](https://developers.google.com/games/services/common/concepts/savedgames)

---

### Pitfall 10: TileMap Performance Degradation with Many Rooms
**What goes wrong:** Theater with 50+ rooms runs at 60fps on PC, 15fps on mobile.

**Why it happens:**
- Each room's walls/ground added to same TileMapLayer
- TileMapLayer with 10,000+ tiles has high draw call overhead on mobile
- Furniture sprites (Sprite2D nodes) with transparency cause overdraw
- No culling - all rooms rendered even when off-screen

**Consequences:**
- Game unplayable on mid-range Android devices
- Poor reviews citing performance

**Prevention:**
```gdscript
# Use multiple TileMapLayers, one per room:
func create_room_visuals(room: RoomInstance) -> void:
    var room_tilemap = TileMapLayer.new()
    room_tilemap.tile_set = tilemap_layer.tile_set
    room_tilemap.name = "Room_%s" % room.id
    tilemap_layer.add_sibling(room_tilemap)

    _wall_op.create_wall_visuals(room, room_tilemap)
    room._tilemap_node = room_tilemap  # Track for deletion

# Enable visibility culling:
func _process(_delta: float) -> void:
    var viewport_rect = get_viewport_rect()
    for room in _all_rooms:
        if room._tilemap_node:
            var room_world_rect = _get_room_world_bounds(room)
            room._tilemap_node.visible = viewport_rect.intersects(room_world_rect)
```

**Detection:**
- FPS drops as room count increases
- Mobile profiler shows high draw calls
- TileMapLayer has >5000 cells

**Phase to address:** Phase 1 (Room Selection) should test with 20+ rooms on mobile. If slow, implement per-room TileMaps early.

**Sources:**
- [Increase performance on large tilemap](https://forum.godotengine.org/t/increase-performance-on-large-tilemap/71954)
- [How to manage performance of very large tilemaps](https://forum.godotengine.org/t/how-to-manage-performance-of-very-large-tilemaps/73436)
- [Godot 4 tilemap performance issues](https://github.com/godotengine/godot/issues/72458)

---

## Minor Pitfalls

Mistakes that cause polish issues but are easily fixable.

### Pitfall 11: No Visual Feedback for Selected Room
**What goes wrong:** Player taps room to edit → nothing visible changes → unclear if selection worked.

**Why it happens:**
- Selection logic works but no visual indication
- Common to implement backend first, defer visuals

**Prevention:**
- Add highlight shader or tint to selected room
- Show selection outline (draw_rect on CanvasItem)
- Display floating UI panel over selected room

**Phase to address:** Phase 1 (Room Selection) - visual feedback is core to selection UX, not polish.

---

### Pitfall 12: Furniture Rotation Not Validated Against Room Bounds
**What goes wrong:** Player rotates 2x1 furniture near wall → now extends outside room → visual glitch.

**Why it happens:**
- Rotation changes occupied tiles footprint
- Validation checks position but not rotated size

**Prevention:**
```gdscript
func can_rotate_furniture(placement: FurniturePlacement, new_rotation: int) -> bool:
    var new_footprint = RotationHelper.get_footprint_tiles(
        placement.tile_position,
        placement.furniture.size,
        new_rotation
    )

    for tile in new_footprint:
        if not current_room.bounding_box.has_point(tile):
            return false  # Would extend outside room

    return true
```

**Phase to address:** Phase 3 (Furniture Management) when implementing rotation.

---

### Pitfall 13: Deleted Room Still Registered as Navigation Target
**What goes wrong:** Delete room → patrons still path to it → stuck at empty location.

**Why it happens:**
- `Targets` singleton holds references to room positions
- No notification on room deletion

**Prevention:**
```gdscript
func delete_room(room: RoomInstance) -> void:
    # Remove from navigation targets
    Targets.unregister_room(room)

    # Clean up visuals
    if room._tilemap_node:
        room._tilemap_node.queue_free()

    # Remove from storage
    _all_rooms.erase(room)

    # Update navigation
    Targets.notify_navigation_changed()
```

**Phase to address:** Phase 2 (Room Editing Operations) when implementing deletion.

---

## Phase-Specific Research Flags

| Phase | Likely Needs Deeper Research | Reason |
|-------|------------------------------|--------|
| Phase 1 | LOW | Room selection is well-established pattern |
| Phase 2 | HIGH | Room resizing with isometric coordinates is complex, need to research coordinate transformation edge cases |
| Phase 3 | MEDIUM | Furniture drag-and-drop on mobile may need gesture library research |
| Phase 4 | HIGH | JSON schema evolution (versioning) for save compatibility needs investigation |
| Phase 5 | MEDIUM | Auto-save timing on iOS vs Android may differ (app lifecycle research) |

---

## Testing Checklist (Mobile-Specific)

Before shipping editing features, test on actual mobile device:

- [ ] Select room with single tap (not triggering pan)
- [ ] Edit room → save → kill app → relaunch → verify room preserved
- [ ] Create 50 rooms → check FPS (should be >30fps on mid-range device)
- [ ] Fill device storage to 90% → save → verify error handling
- [ ] Rotate device (portrait/landscape) during edit → verify no crashes
- [ ] Place call during auto-save → verify save completes or retries
- [ ] Enable airplane mode → edit room → save → verify works offline
- [ ] Play for 30 minutes with heavy editing → check memory usage (should stay <300MB)

---

## Summary

**Highest risk areas:**
1. Navigation map updates (breaks gameplay)
2. Save file corruption (data loss)
3. Touch input conflicts (unusable on mobile)

**Common theme:** Mobile constraints (limited RAM, touch input ambiguity, frequent suspension) amplify issues that might not appear on desktop. Test on mobile device early and often.

**Recommendation:** Address critical pitfalls 1-5 during implementation phases, not as post-MVP polish. These are architectural decisions that are expensive to retrofit.
