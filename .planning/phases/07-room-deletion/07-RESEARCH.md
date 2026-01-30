# Phase 7: Room Deletion - Research

**Researched:** 2026-01-30
**Domain:** Room lifecycle management, resource cleanup, navigation system integration
**Confidence:** HIGH

## Summary

Room deletion requires coordinated cleanup across multiple systems: tilemap visuals (walls, doors), furniture nodes, navigation mesh, target registration, and RoomManager state. The critical challenge is **shared wall preservation** - when rooms are adjacent, their walls occupy the same tilemap cells, so deletion must NOT erase tiles that belong to neighboring rooms.

The established patterns in this codebase provide a strong foundation: Operations pattern (stateless RefCounted helpers), auto-save via RoomInstance.placement_changed signal, and separation of data layer (RoomInstance) from visual layer (tilemap + Node2D).

**Primary recommendation:** Create DeletionOperation following existing operations pattern. Use ConfirmationDialog for destructive action confirmation. Clear navigation BEFORE clearing tilemap visuals to avoid patrons navigating to deleted areas during cleanup.

## Standard Stack

The project already has all necessary libraries and patterns in place. Room deletion builds on existing infrastructure.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Godot Engine | 4.5 | Core engine with built-in ConfirmationDialog | Project-wide standard |
| GDScript | 4.5 | Scripting language | Project-wide standard |
| TileMapLayer | 4.5 | Tilemap visuals for walls/doors | Existing room system |
| NavigationAgent2D | 4.5 | Pathfinding integration | Existing patron navigation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ConfirmationDialog | 4.5 (built-in) | User confirmation for destructive actions | All delete operations |
| Area2D | 4.5 (built-in) | Selection collision detection | Already used by RoomManager |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ConfirmationDialog | AcceptDialog + add_cancel_button() | ConfirmationDialog provides OK+Cancel by default, less code |
| DeletionOperation | Inline deletion in controller | Operation pattern is established, keeps logic testable/reusable |

**Installation:**
No new packages required - all functionality is built-in to Godot 4.5.

## Architecture Patterns

### Recommended Project Structure
```
scripts/
├── room_building/
│   └── operations/
│       └── DeletionOperation.gd  # NEW: Stateless deletion logic
├── room_editing/
│   └── RoomEditMenu.gd           # MODIFY: Add "Delete Room" button
└── Main.gd                        # MODIFY: Wire deletion signals
```

### Pattern 1: DeletionOperation (Stateless Helper)
**What:** RefCounted class with public methods for room deletion logic
**When to use:** All room cleanup operations
**Example:**
```gdscript
# Source: Existing operations pattern (WallOperation, FurnitureOperation, DoorOperation)
class_name DeletionOperation
extends RefCounted

## Delete all visuals for a room (walls, doors, furniture)
## CRITICAL: Must preserve shared walls (tiles in other rooms)
func delete_room_visuals(room: RoomInstance, wall_tilemap: TileMapLayer,
                         ground_tilemap: TileMapLayer, room_manager: Node) -> void:
    # 1. Delete furniture visuals and ground tiles
    _delete_furniture_visuals(room, ground_tilemap)

    # 2. Delete door visuals (revert doors to walls first)
    _delete_door_visuals(room, wall_tilemap)

    # 3. Delete wall visuals (ONLY if not shared with other rooms)
    _delete_wall_visuals(room, wall_tilemap, room_manager)

## Check which wall tiles are shared with other rooms
func _get_shared_wall_tiles(room: RoomInstance, room_manager: Node) -> Array[Vector2i]:
    var shared: Array[Vector2i] = []
    for wall_pos in room.walls:
        # Check if this tile is inside any OTHER room's bounding box
        for other_room in room_manager.get_all_rooms():
            if other_room == room:
                continue
            if _is_tile_in_room(wall_pos, other_room):
                shared.append(wall_pos)
                break
    return shared
```

### Pattern 2: Confirmation Dialog
**What:** Built-in Godot dialog for destructive action confirmation
**When to use:** Any irreversible operation (delete room, bulk delete)
**Example:**
```gdscript
# Source: Godot 4.5 ConfirmationDialog API
# https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html

func _create_delete_confirmation_dialog() -> ConfirmationDialog:
    var dialog = ConfirmationDialog.new()
    dialog.dialog_text = "Delete this room? This cannot be undone."
    dialog.title = "Confirm Deletion"

    # Connect to confirmed signal (no cancel signal - dialog just closes)
    dialog.confirmed.connect(_on_delete_confirmed)

    add_child(dialog)
    return dialog

func _on_delete_room_requested(room: RoomInstance) -> void:
    _room_to_delete = room
    _delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
    # User confirmed deletion
    delete_room(_room_to_delete)
```

### Pattern 3: Cleanup Sequence Order
**What:** Specific order for cleanup operations to avoid visual glitches and navigation bugs
**When to use:** ALL room deletion flows
**Example:**
```gdscript
# CORRECT ORDER (prevents patrons navigating to deleted rooms):
func delete_room(room: RoomInstance) -> void:
    # 1. Clear navigation FIRST (make area non-walkable immediately)
    _navigation_op.clear_room_navigation(room, ground_tilemap)

    # 2. Unregister from Targets (patrons stop targeting this room)
    Targets.notify_navigation_changed()

    # 3. Delete furniture visuals (queue_free nodes)
    for furn in room.furniture:
        furn.cleanup_visual()

    # 4. Delete door visuals (revert to walls)
    for door in room.doors:
        _door_op.remove_door_visuals(door, room, wall_tilemap)

    # 5. Delete wall visuals (ONLY non-shared tiles)
    var shared_walls = _deletion_op.get_shared_wall_tiles(room, _room_manager)
    for wall_pos in room.walls:
        if wall_pos not in shared_walls:
            var tilemap_pos = IsometricMath.ui_to_tilemap_coords(wall_pos, wall_tilemap)
            wall_tilemap.erase_cell(tilemap_pos)

    # 6. Remove selection Area2D (from RoomManager)
    _room_manager.unregister_room(room)

    # 7. Trigger auto-save
    # (handled automatically by RoomManager when room removed)
```

### Anti-Patterns to Avoid
- **Clear tilemap before navigation:** Causes visual pop (patrons walk through empty space before navigation updates)
- **Forget to check shared walls:** Adjacent rooms lose their walls, creating holes
- **Delete confirmation without room context:** User doesn't know which room is being deleted
- **Skip Targets.notify_navigation_changed():** Patrons continue pathfinding to deleted room

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tilemap coordinate conversion | Custom UI→tilemap math | IsometricMath.ui_to_tilemap_coords() | Already handles isometric projection |
| Furniture visual cleanup | Manual node.queue_free() | RoomInstance.FurniturePlacement.cleanup_visual() | Handles null checks, already exists |
| Room boundary checks | Custom AABB collision | RoomManager.is_tile_in_another_room() | Existing method for adjacency checks |
| Navigation mesh updates | Direct NavigationPolygon editing | NavigationOperation.clear_room_navigation() | Already exists, handles coordinate conversion |
| Door-to-wall conversion | Custom tilemap operations | DoorOperation.remove_door_visuals() | Handles terrain reconnect, existing code |

**Key insight:** Room deletion is the inverse of room creation - reuse existing operations in reverse order. Don't create new tilemap/navigation logic.

## Common Pitfalls

### Pitfall 1: Shared Wall Destruction
**What goes wrong:** Deleting a room erases tilemap cells that are also walls for an adjacent room, creating holes.
**Why it happens:** Multiple rooms can place walls at the same tilemap coordinates (e.g., two rooms side-by-side share the boundary wall). Simple `erase_cell()` on all wall positions destroys both rooms' walls.
**How to avoid:** Query RoomManager for all other rooms, check if wall tile is inside another room's bounding box. Only erase walls NOT in any other room.
**Warning signs:** Adjacent rooms show missing walls after deletion, patrons walk through phantom openings.

### Pitfall 2: Navigation Update Order
**What goes wrong:** Patrons briefly navigate to deleted room during cleanup, walk through empty space, or get stuck.
**Why it happens:** Navigation mesh update happens AFTER tilemap visual deletion, creating window where tiles are walkable but room doesn't exist.
**How to avoid:** Clear navigation FIRST (make area non-walkable), THEN unregister from Targets, THEN delete visuals. This ensures patrons never see or path to the deleted area.
**Warning signs:** Patrons walk into deleted rooms, frozen patrons at deletion site, navigation warnings in console.

### Pitfall 3: Stale Area2D References
**What goes wrong:** Deleted room's Area2D remains in scene tree, can be selected, causes null reference errors.
**Why it happens:** RoomManager creates Area2D for room selection in `_selection_areas` dictionary. Deleting room data doesn't automatically clean up the Area2D.
**How to avoid:** Add `unregister_room()` method to RoomManager that removes from `_rooms` array, erases from `_selection_areas` dictionary, and calls `queue_free()` on the Area2D.
**Warning signs:** Can select "ghost" rooms, crashes when accessing deleted room data, selection highlights appear in wrong positions.

### Pitfall 4: Furniture Node Leaks
**What goes wrong:** Furniture visual nodes remain in scene tree after room deletion, invisible but consuming memory.
**Why it happens:** Furniture nodes are added to `furniture_visuals` parent, but deletion only removes data from RoomInstance. Nodes aren't automatically freed.
**How to avoid:** Call `cleanup_visual()` on each FurniturePlacement BEFORE removing from room.furniture array. This method handles `queue_free()` and null checks.
**Warning signs:** Memory usage grows with repeated delete operations, scene tree shows orphaned nodes.

### Pitfall 5: Confirmation Dialog Not Centered
**What goes wrong:** Confirmation dialog appears off-screen or in corner, hard to see/interact with on mobile.
**Why it happens:** Default Window positioning doesn't center on viewport. Must explicitly call `popup_centered()`.
**How to avoid:** Always use `popup_centered()` method after setting dialog_text. This works correctly across desktop and mobile.
**Warning signs:** Dialog hidden on small screens, user doesn't see confirmation prompt.

## Code Examples

Verified patterns from official sources and existing codebase:

### ConfirmationDialog Creation
```gdscript
# Source: https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html
# Source: https://gdscript.com/solutions/popups/

var _delete_dialog: ConfirmationDialog = null
var _room_to_delete: RoomInstance = null

func _ready() -> void:
    # Create dialog once, reuse for all delete operations
    _delete_dialog = ConfirmationDialog.new()
    _delete_dialog.title = "Confirm Deletion"
    _delete_dialog.confirmed.connect(_on_delete_confirmed)
    add_child(_delete_dialog)

func _on_delete_room_button_pressed() -> void:
    if _current_room == null:
        return

    _room_to_delete = _current_room
    _delete_dialog.dialog_text = "Delete this room? All furniture will be removed.\n\nThis cannot be undone."
    _delete_dialog.popup_centered()

func _on_delete_confirmed() -> void:
    # User pressed OK
    if _room_to_delete:
        delete_room_requested.emit(_room_to_delete)
        _room_to_delete = null
```

### Shared Wall Detection
```gdscript
# Source: Existing RoomManager.is_tile_in_another_room() pattern
# Source: CollisionOperation._is_tile_valid() boundary checking

func get_non_shared_walls(room: RoomInstance, room_manager: Node) -> Array[Vector2i]:
    var non_shared: Array[Vector2i] = []

    for wall_pos in room.walls:
        var is_shared = false

        # Check if this wall tile is inside any OTHER room's bounding box
        for other_room in room_manager.get_all_rooms():
            if other_room == room:
                continue

            # Use same boundary check as CollisionOperation
            var bbox = other_room.bounding_box
            var in_bounds = wall_pos.x >= bbox.position.x and wall_pos.x < bbox.position.x + bbox.size.x
            in_bounds = in_bounds and wall_pos.y >= bbox.position.y and wall_pos.y < bbox.position.y + bbox.size.y

            if in_bounds:
                is_shared = true
                break

        if not is_shared:
            non_shared.append(wall_pos)

    return non_shared
```

### Room Unregistration
```gdscript
# Source: Existing RoomManager registration pattern (inverse)
# Add to RoomManager.gd:

signal room_removed(room: RoomInstance)

func unregister_room(room: RoomInstance) -> void:
    if room == null:
        return

    # Remove from rooms array
    var index = _rooms.find(room)
    if index >= 0:
        _rooms.remove_at(index)

    # Clean up selection Area2D
    if _selection_areas.has(room.id):
        var area = _selection_areas[room.id]
        if area and is_instance_valid(area):
            area.queue_free()
        _selection_areas.erase(room.id)

    # Clear selection if this room was selected
    if _selected_room == room:
        _selected_room = null
        selection_cleared.emit()

    # Emit signal for listeners
    room_removed.emit(room)

    # Trigger auto-save
    _schedule_save()
```

### Navigation Clearing
```gdscript
# Source: Existing NavigationOperation.clear_room_navigation()
# This method already exists, just needs to be called FIRST

var _navigation_op = NavigationOperation.new()

func delete_room_navigation(room: RoomInstance, tilemap: TileMapLayer) -> void:
    # Clear navigation BEFORE visual cleanup
    _navigation_op.clear_room_navigation(room, tilemap)

    # Notify patrons to recalculate paths immediately
    Targets.notify_navigation_changed()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual Area2D cleanup | queue_free() + dictionary erase | Godot 4.0+ | Prevents memory leaks |
| Single global navigation update | Per-patron notify_navigation_changed signal | Phase 1-6 | Patrons recalculate paths dynamically |
| Inline deletion logic | DeletionOperation pattern | Phase 7 (new) | Testable, reusable cleanup |
| No deletion confirmation | ConfirmationDialog | Phase 7 (new) | Prevents accidental deletion |

**Deprecated/outdated:**
- **Direct tilemap manipulation without shared wall checks:** Required for multi-room support (Phase 7)
- **Navigation update after visual deletion:** Must happen before to prevent pathfinding to deleted areas

## Open Questions

1. **Should shared wall detection use bounding box or actual wall array?**
   - What we know: Bounding box check is simpler, faster (O(n) vs O(n*m) where m=walls)
   - What's unclear: Edge case where rooms are adjacent but don't share wall tiles (gap between rooms)
   - Recommendation: Use bounding box check - matches door placement validation pattern, simpler code

2. **Should deletion emit room_removed signal before or after auto-save?**
   - What we know: RoomManager._schedule_save() is debounced (5 second delay)
   - What's unclear: Should listeners assume room is saved when they receive room_removed signal?
   - Recommendation: Emit AFTER calling _schedule_save() but BEFORE actual save. Signal means "room removed from manager" not "room deleted from disk".

3. **Should delete button be in RoomEditMenu or separate confirmation flow?**
   - What we know: Current menu has 3 buttons (Edit Furniture, Edit Room, Room Type Action)
   - What's unclear: Does "Delete Room" fit in this menu or need separate entry point?
   - Recommendation: Add as 4th button in RoomEditMenu (keeps all room actions together), use ConfirmationDialog for safety

4. **Should we support undo for room deletion?**
   - What we know: No undo system exists currently, auto-save makes undo complex
   - What's unclear: User expectations for destructive operations
   - Recommendation: No undo for Phase 7 - ConfirmationDialog provides safety net. Undo can be future enhancement if needed.

## Sources

### Primary (HIGH confidence)
- Godot 4.5 ConfirmationDialog API - [Official Documentation](https://docs.godotengine.org/en/stable/classes/class_confirmationdialog.html)
- Godot 4.5 AcceptDialog API - [Official Documentation](https://docs.godotengine.org/en/stable/classes/class_acceptdialog.html)
- Existing codebase operations pattern - RoomBuildController.gd, WallOperation.gd, DoorOperation.gd, FurnitureOperation.gd
- Existing navigation pattern - NavigationOperation.gd, Targets.gd
- Existing room management pattern - RoomManager.gd, RoomInstance.gd

### Secondary (MEDIUM confidence)
- Godot popup centering - [GDScript Solutions: Popups](https://gdscript.com/solutions/popups/)
- Shared wall handling research - Phase 6 door editing research (adjacent room validation)

### Tertiary (LOW confidence)
- None - all findings verified against existing codebase or official documentation

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries are built-in Godot 4.5, already used in project
- Architecture: HIGH - Patterns directly match existing operations, confirmed via code inspection
- Pitfalls: HIGH - Identified from similar operations (furniture deletion, door removal) and known multi-room edge cases

**Research date:** 2026-01-30
**Valid until:** 2026-02-28 (30 days - stable domain, unlikely to change)
