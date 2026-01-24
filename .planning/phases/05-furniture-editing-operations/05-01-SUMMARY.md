---
phase: 05-furniture-editing-operations
plan: 01
subsystem: ui
tags: [gdscript, godot, furniture-editing, drag-drop, collision-detection, isometric]

# Dependency graph
requires:
  - phase: 04-furniture-selection
    provides: FurnitureEditController with tap detection and selection state
provides:
  - Drag-to-move furniture functionality with tap-vs-drag discrimination
  - Real-time collision validation during drag operations
  - Visual node tracking for live position updates
  - Auto-save integration via placement_changed signal
affects: [05-furniture-editing-operations, furniture-operations]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Drag state machine with motion threshold detection
    - Temporary removal pattern for self-collision avoidance
    - Visual node reference for live updates without scene tree traversal

key-files:
  created: []
  modified:
    - Scripts/room_editing/FurnitureEditController.gd
    - Scripts/storage/RoomInstance.gd
    - Scripts/room_building/operations/FurnitureOperation.gd

key-decisions:
  - "Temporary removal during validation to avoid self-collision"
  - "20px drag threshold reuses established tap detection constant"
  - "visual_node reference stored in FurniturePlacement for efficient updates"

patterns-established:
  - "Drag state machine: press → motion threshold → drag start → update → end"
  - "Temporary array removal pattern: remove → validate → restore to original index"
  - "Dual input handling: InputEventMouseMotion (desktop) + InputEventScreenDrag (mobile)"

# Metrics
duration: 3min
completed: 2026-01-23
---

# Phase 05 Plan 01: Furniture Drag-to-Move Summary

**Drag-to-move furniture with grid snapping, collision validation, and live visual updates using visual_node references**

## Performance

- **Duration:** 3 minutes
- **Started:** 2026-01-23T21:20:18Z
- **Completed:** 2026-01-23T21:23:39Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments
- Implemented drag-to-move functionality with tap-vs-drag discrimination using 20px threshold
- Integrated CollisionOperation for real-time validation during drag preview
- Added visual_node tracking to FurniturePlacement for efficient position updates
- Connected to auto-save system via placement_changed signal emission

## Task Commits

Each task was committed atomically:

1. **Task 1: Add drag state tracking to FurnitureEditController** - `35c126a` (feat)
2. **Task 2: Implement drag detection and motion handling** - `f7cd72d` (feat)
3. **Task 3: Add visual_node tracking to FurniturePlacement** - `b74d677` (feat)

## Files Created/Modified
- `Scripts/room_editing/FurnitureEditController.gd` - Added drag state machine with _dragging, _drag_offset, _preview_position; motion event handlers; drag lifecycle methods (_start_drag, _update_drag_position, _end_drag)
- `Scripts/storage/RoomInstance.gd` - Added visual_node property and cleanup_visual() method to FurniturePlacement
- `Scripts/room_building/operations/FurnitureOperation.gd` - Store visual_node reference when creating furniture visuals

## Decisions Made

**1. Temporary removal during validation**
- **Rationale:** CollisionOperation.can_place_furniture checks room.is_tile_occupied(), which would detect the furniture being dragged as a collision with itself. Temporarily removing it from the array during validation avoids false positives.
- **Implementation:** Remove at index, validate, restore at same index to maintain order.

**2. Reuse 20px TAP_DISTANCE_THRESHOLD for drag detection**
- **Rationale:** Established in Phase 1 as below camera pan threshold. Consistent across all input detection.
- **Implementation:** Drag starts when motion exceeds 20px from touch_start_pos.

**3. Store visual_node reference in FurniturePlacement**
- **Rationale:** Enables direct position updates without scene tree traversal. Critical for smooth drag preview.
- **Implementation:** FurnitureOperation stores reference on creation; _end_drag() updates position directly.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Furniture drag-to-move foundation complete. Ready for:
- Task 2 (05-02): Furniture rotation
- Task 3 (05-03): Furniture deletion
- Phase 6: Door editing operations

Key signals established:
- `furniture_drag_preview(position, is_valid)` - For visual feedback (highlight system can subscribe)
- `furniture_drag_ended` - For cleanup
- `placement_changed` - Triggers auto-save

Known limitation: Visual node position updates happen in _end_drag(). If FurnitureSelectionHighlight needs live preview during drag, it should subscribe to furniture_drag_preview signal.

---
*Phase: 05-furniture-editing-operations*
*Completed: 2026-01-23*
