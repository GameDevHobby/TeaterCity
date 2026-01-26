# Phase 6 Plan 03: Door Removal Operation Summary

**One-liner:** Door removal validation with room type minimum enforcement and wall tile restoration via terrain reconnection.

**Completed:** 2026-01-26

## What Was Built

### Task 1: Door Removal Validation (DoorOperation)
Added `can_remove_door(room: RoomInstance)` method to DoorOperation.gd:
- Returns Dictionary with `can_remove` (bool) and `reason` (String)
- Checks room type's `door_count_min` against current door count
- Enforces minimum 1 door even if `door_count_min` is 0 (rooms need patron access)

### Task 2: Wall Restoration Method (DoorOperation)
Added `remove_door_visuals(door, room, tilemap_layer)` method:
- Erases door tile from tilemap
- Collects all wall positions (excluding other doors)
- Uses `set_cells_terrain_connect()` to restore proper wall tile transitions
- Terrain system automatically calculates correct corner/edge tiles

### Task 3: Remove Door Operation (DoorEditController)
Added door add/remove methods to DoorEditController:

**`remove_door(position: Vector2i)`:**
- Finds door at position in room.doors array
- Validates with `_door_operation.can_remove_door()`
- Removes from data array
- Emits `door_removed` signal for Main.gd visual handling
- Triggers `placement_changed` for auto-save

**`add_door(position: Vector2i)`:**
- Validates with `_door_operation.can_place_door_edit()`
- Creates DoorPlacement with determined direction
- Adds to room data
- Emits `door_added` signal
- Triggers `placement_changed` for auto-save

**`handle_wall_tap(position, is_door)`:**
- Public method routing taps to add or remove
- Called by `_handle_wall_tap` after emitting `wall_tile_tapped` signal

## Commits

| Hash | Description |
|------|-------------|
| 2f25ec6 | feat(06-03): add door removal validation to DoorOperation |
| 65b8e16 | feat(06-03): add wall restoration method to DoorOperation |
| 65be635 | feat(06-03): add door removal operation to DoorEditController |

## Key Files

| File | Changes |
|------|---------|
| `scripts/room_building/operations/DoorOperation.gd` | Added `can_remove_door()` and `remove_door_visuals()` |
| `scripts/room_editing/DoorEditController.gd` | Added `_door_operation`, `remove_door()`, `add_door()`, `handle_wall_tap()` |

## Deviations from Plan

### Extended Scope
**1. [Rule 2 - Missing Critical] Added add_door() method**
- **Found during:** Task 3
- **Issue:** Plan only specified remove_door, but handle_wall_tap needs both add and remove
- **Fix:** Added add_door() method using existing can_place_door_edit() validation (from 06-02)
- **Files modified:** DoorEditController.gd
- **Commit:** 65be635

## Technical Notes

- **Terrain connect strategy:** Instead of updating only neighbors, remove_door_visuals rebuilds all wall terrain to ensure proper tile transitions after door removal
- **Signal flow:** Controller emits door_removed, Main.gd should call DoorOperation.remove_door_visuals() with tilemap reference
- **Auto-save trigger:** placement_changed signal on room fires after both add and remove operations

## Integration Points

For Main.gd to handle door visuals:
```gdscript
# Connect in _ready or when creating DoorEditController
door_edit_controller.door_added.connect(_on_door_added)
door_edit_controller.door_removed.connect(_on_door_removed)

func _on_door_added(room: RoomInstance, door: RoomInstance.DoorPlacement) -> void:
    _door_operation.create_door_visuals(door, wall_tile_layer)

func _on_door_removed(room: RoomInstance, door: RoomInstance.DoorPlacement) -> void:
    _door_operation.remove_door_visuals(door, room, wall_tile_layer)
```

## Next Phase Readiness

- Door removal is ready for integration with Main.gd
- Validation prevents removing last required door
- Wall terrain properly restored after door removal
- Auto-save triggered via placement_changed signal

## Duration

~3 minutes
