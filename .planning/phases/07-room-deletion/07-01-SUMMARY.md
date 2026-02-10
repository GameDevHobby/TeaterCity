# Phase 7 Plan 01: Room Deletion Infrastructure Summary

**One-liner:** RoomManager unregistration with Area2D cleanup and DeletionOperation for shared wall detection and visual cleanup.

**Completed:** 2026-01-30

## What Was Built

### Task 1: RoomManager.unregister_room() Method
Extended RoomManager.gd with complete room unregistration:

**New Signal:**
- `room_removed(room: RoomInstance)` - emitted when a room is removed from tracking

**New Method:**
- `unregister_room(room: RoomInstance)` - removes room from tracking with full cleanup:
  - Removes from `_rooms` array using find() and remove_at()
  - Cleans up selection Area2D: checks is_instance_valid(), calls queue_free(), erases from dictionary
  - Clears selection if deleted room was selected (_selected_room = null, emits selection_cleared)
  - Disconnects placement_changed signal to prevent memory leaks
  - Emits room_removed signal for listeners
  - Triggers auto-save via _schedule_save()

Follows the reverse pattern of register_room() for symmetry.

### Task 2: DeletionOperation Class
Created `scripts/room_building/operations/DeletionOperation.gd` following the established stateless operations pattern:

**Core Methods:**

1. **get_non_shared_walls(room, room_manager) -> Array[Vector2i]**
   - Identifies wall tiles that are NOT inside other rooms' bounding boxes
   - Uses same boundary check as RoomManager._is_tile_in_room()
   - Only non-shared walls should be deleted (shared walls belong to adjacent rooms)

2. **delete_wall_visuals(room, wall_tilemap, room_manager)**
   - Erases non-shared wall tiles from tilemap
   - Calls _update_neighbor_terrain() to reconnect adjacent room walls
   - Updates terrain tiles so neighboring rooms' walls render correctly

3. **delete_furniture_visuals(room)**
   - Calls FurniturePlacement.cleanup_visual() for each furniture item
   - Leverages existing null checks and queue_free() logic

4. **delete_door_visuals(room, wall_tilemap)**
   - Erases door tiles from tilemap
   - Prevents visual artifacts if wall deletion is animated in future

5. **restore_furniture_ground_tiles(room, ground_tilemap)**
   - Restores walkable tiles where furniture occupied space
   - Uses NavigationOperation constants (SOURCE_ID=1, WALKABLE_TILE=(0,1))
   - Restores both footprint and access tiles for proper navigation

**Private Helper:**
- `_update_neighbor_terrain(deleted_positions, tilemap_layer)` - re-applies terrain to neighboring wall tiles so they reconnect properly after deletion

**Design Notes:**
- Stateless RefCounted pattern (no state, no orchestration)
- Main.gd will call these methods in correct sequence
- Reuses TERRAIN_SET and TERRAIN_INDEX constants from WallOperation

## Commits

| Commit | Description |
|--------|-------------|
| 8394a59 | feat(07-01): add unregister_room() to RoomManager |
| 3afff85 | feat(07-01): create DeletionOperation class |

## Files Changed

| File | Change |
|------|--------|
| scripts/RoomManager.gd | Added room_removed signal and unregister_room() method |
| scripts/room_building/operations/DeletionOperation.gd | Created new file with deletion helper methods |

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| Shared wall detection via bounding box | Matches RoomManager._is_tile_in_room() logic |
| Separate methods for each visual cleanup | Allows Main.gd to control sequence |
| Terrain reconnection in delete_wall_visuals | Prevents orphaned wall rendering artifacts |
| Restore ground tiles for furniture | Maintains navigability after deletion |

## Next Phase Readiness

Ready to proceed with:
- 07-02: Main.gd integration to orchestrate deletion sequence
- 07-03: RoomEditMenu "Delete Room" button and confirmation
- Future plans in phase 07

**Blockers:** None
**Concerns:** None - infrastructure follows established patterns

## Duration

~2 minutes
