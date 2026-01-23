---
phase: 02-room-menu-edit-mode
plan: 01
subsystem: ui
tags: [control, menu, signals, isometric-positioning]

# Dependency graph
requires:
  - Phase 1 (RoomManager singleton with room_selected/selection_cleared signals)
provides:
  - RoomEditMenu contextual menu Control
  - Room editing entry point via three button signals
  - Outside-click dismiss for touch and mouse
affects:
  - Phase 4 (Furniture Selection - edit_furniture_pressed)
  - Phase 5 (Furniture Editing - edit_furniture_pressed)
  - Phase 6 (Door Editing - edit_room_pressed)
  - Phase 7 (Room Deletion - edit_room_pressed)
  - Phase 8 (Room Resize - edit_room_pressed)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - PanelContainer with MarginContainer/VBoxContainer for auto-sizing menus
    - CanvasLayer layering (layer=1 for UI above layer=0 selection highlight)
    - Signal-based menu action delegation

key-files:
  created:
    - scripts/room_editing/RoomEditMenu.gd
  modified:
    - scripts/Main.gd

key-decisions:
  - "Use MOUSE_FILTER_IGNORE on full-rect Control, MOUSE_FILTER_STOP on panel"
  - "Position menu 30px right of room center, clamped to viewport with 8px margin"
  - "Handle both InputEventScreenTouch and InputEventMouseButton for outside-click"
  - "Room-type button shows contextual label mapped from room_type_id"

patterns-established:
  - "Contextual menu pattern: show on selection signal, hide on clear signal"
  - "Outside-click dismiss via _unhandled_input with panel bounds check"
  - "Room-type feature mapping via match statement on room_type_id"

# Metrics
duration: 2min
completed: 2026-01-23
---

# Phase 02 Plan 01: RoomEditMenu Contextual Menu Summary

**Contextual room edit menu with three buttons positioned near selected room using IsometricMath**

## Performance

- **Duration:** 2 min
- **Started:** 2026-01-23T06:46:49Z
- **Completed:** 2026-01-23T06:48:35Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Created RoomEditMenu.gd Control with three styled buttons (Edit Furniture, Edit Room, room-type-specific)
- Implemented menu positioning using IsometricMath.tile_to_screen near selected room center
- Added outside-click dismiss handling for both touch (InputEventScreenTouch) and mouse (InputEventMouseButton)
- Room-type button shows contextual labels (Theater Schedule, Ticket Prices, Menu Items, etc.)
- Integrated RoomEditMenu into Main.gd with EditMenuLayer CanvasLayer (layer=1)
- Connected menu signals to stub handlers for future phase implementation

## Task Commits

Each task was committed atomically:

1. **Task 1: Create RoomEditMenu Control** - `ab2493f` (feat)
2. **Task 2: Integrate RoomEditMenu with Main.gd** - `a7132b4` (feat)

## Files Created/Modified
- `scripts/room_editing/RoomEditMenu.gd` - Contextual menu Control (174 lines)
- `scripts/Main.gd` - Added EditMenuLayer, RoomEditMenu creation, stub signal handlers

## Decisions Made
- Used MOUSE_FILTER_IGNORE on Control (full-rect), MOUSE_FILTER_STOP on PanelContainer to allow room clicks while capturing button clicks
- Menu positioned 30px right of room center tile, clamped to viewport bounds with 8px margin
- Awaits process_frame for panel size calculation before positioning (async pattern)
- Room-type button defaults to "Room Options" when room_type_id not in registry

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Testing Notes

Manual verification required:
1. Build a room in the game
2. Click/tap the completed room to see yellow highlight and menu
3. Verify menu has three buttons with consistent styling
4. Click/tap outside menu to dismiss and clear selection
5. Select room again to verify menu reappears

Note: Room-type button will show "Room Options" until room types are configured in RoomTypeRegistry.

## Next Phase Readiness
- RoomEditMenu is fully functional and displays on room selection
- Edit menu signals ready for Phase 4+ (Furniture Selection/Editing)
- Stub handlers in Main.gd print to console for debugging
- Ready for 02-02-PLAN.md or next phase work

---
*Phase: 02-room-menu-edit-mode*
*Completed: 2026-01-23*
