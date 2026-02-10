---
phase: 08-room-resize
plan: 04
subsystem: room-editing
tags: [ui, menu, integration, wiring]
dependencies:
  requires: ["08-02", "08-03"]
  provides: ["resize-menu-button", "resize-mode-entry", "resize-workflow-orchestration"]
  affects: ["08-05"]
tech-stack:
  added: []
  patterns: ["signal-driven-workflow", "unregister-register-pattern"]
key-files:
  created: []
  modified:
    - scripts/room_editing/RoomEditMenu.gd
    - scripts/Main.gd
decisions:
  - id: area2d-update-pattern
    choice: "Use unregister/register to update Area2D after resize"
    rationale: "Cleanest solution - reuses existing RoomManager code rather than adding update method"
metrics:
  duration: "2m 27s"
  completed: "2026-02-02"
---

# Phase 08 Plan 04: Main.gd Integration Summary

**One-liner:** Resize Room button in menu triggers resize mode with Area2D refresh and door re-placement workflow

## What Was Built

### 1. RoomEditMenu Resize Button
- Added `resize_room_pressed(room: RoomInstance)` signal
- Created "Resize Room" button between Edit Room and room type action
- Button handler emits signal with current room

### 2. Main.gd Resize Controller Wiring
- Created `ResizeEditLayer` CanvasLayer at layer 0
- Instantiated `RoomResizeController` and `RoomResizeHighlight`
- Connected highlight to controller via `set_controller()`
- Connected three controller signals: `resize_completed`, `door_placement_needed`, `mode_exited`

### 3. Resize Mode Entry Handler
`_on_resize_room_requested(room)`:
- Hides room edit menu
- Clears room selection
- Disables room selection input
- Disables camera panning
- Sets exterior walls and wall tilemap on controller
- Enters resize mode

### 4. Resize Completion Handler
`_on_resize_completed(room)`:
- Updates RoomManager Area2D via unregister/register pattern
- Notifies navigation system of change

### 5. Door Placement Transition
`_on_resize_door_placement_needed(room)`:
- Sets exterior walls on door controller
- Enters door edit mode (doors were cleared during resize)
- Shows Done button positioned near room

### 6. Cancel/Exit Handler
`_on_resize_mode_exited()`:
- Re-enables camera panning
- Re-enables room selection

## Key Links Verified

| From | To | Via | Pattern |
|------|-----|------|---------|
| RoomEditMenu | Main.gd | resize_room_pressed signal | `_room_edit_menu.resize_room_pressed.connect` |
| Main.gd | RoomResizeController | enter_resize_mode call | `_resize_controller.enter_resize_mode` |
| Main.gd | DoorEditController | door placement after resize | `_door_edit_controller.enter_edit_mode` |

## Decisions Made

1. **Area2D Update Pattern**: Used unregister/register to recreate selection polygon after bounding box changes. This reuses existing RoomManager code rather than adding a new update method.

2. **Resize workflow**: After resize completes, `resize_completed` fires (Area2D update), then `door_placement_needed` fires (transitions to door edit mode). Cancel triggers `mode_exited` directly.

## Deviations from Plan

None - plan executed exactly as written.

## Files Modified

| File | Changes |
|------|---------|
| scripts/room_editing/RoomEditMenu.gd | +11 lines (signal, button, handler) |
| scripts/Main.gd | +85 lines (variables, setup, 4 handlers) |

## Commits

| Hash | Message |
|------|---------|
| eb8c499 | feat(08-04): add Resize Room button to RoomEditMenu |
| 354eb86 | feat(08-04): wire RoomResizeController in Main.gd |

## Next Phase Readiness

Ready for 08-05 (Human Verification):
- Resize Room button appears in menu
- Clicking button enters resize mode
- Box drawing shows valid/invalid preview
- Successful resize updates Area2D and enters door placement
- Cancel exits cleanly and re-enables camera/selection
