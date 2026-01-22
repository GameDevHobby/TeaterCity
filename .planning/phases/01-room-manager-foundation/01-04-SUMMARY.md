# Phase 01 Plan 04: RoomBuildUI Mouse Filter Fix Summary

**One-liner:** Set MOUSE_FILTER_IGNORE on RoomBuildUI to allow mouse clicks to reach Area2D input_event signals

---

## What Was Done

### Task 1: Add mouse_filter = MOUSE_FILTER_IGNORE to RoomBuildUI._ready()
- **Commit:** 4162e3b
- **Files modified:** scripts/room_building/RoomBuildUI.gd

Added `mouse_filter = Control.MOUSE_FILTER_IGNORE` as the first statement in the `_ready()` function.

---

## Root Cause Analysis

**Problem:** Room selection still did not work after 01-03 fix added mouse click handling.

**Cause:** RoomBuildUI is a Control node with `anchors_preset = 15` (FULL_RECT), covering the entire screen. The default `mouse_filter = MOUSE_FILTER_STOP` was consuming all mouse events before they could reach the Area2D nodes created by RoomManager for room selection.

**Why 01-03 fix alone was insufficient:**
1. 01-03 added InputEventMouseButton handling to RoomManager._on_area_input
2. But Area2D.input_event signal never fired because RoomBuildUI intercepted the clicks first
3. Godot's input propagation: Control nodes with MOUSE_FILTER_STOP consume events before Area2D sees them

**Fix:** Set `mouse_filter = MOUSE_FILTER_IGNORE` on RoomBuildUI. This allows mouse events to pass through to the Area2D nodes underneath.

**Why _input() still works:** RoomBuildUI uses `_input()` for its own input handling (box drawing, door placement, furniture placement). The `_input()` callback is independent of mouse_filter - it receives all input events regardless of the filter setting.

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 4162e3b | fix | Allow mouse clicks to pass through RoomBuildUI to Area2D |

---

## Technical Details

### Code Change (RoomBuildUI.gd)

```gdscript
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow Area2D input_event to receive clicks
    hide()  # Start hidden until build mode is activated
    # ... rest of _ready()
```

### Godot Input System Behavior

1. **mouse_filter options:**
   - `MOUSE_FILTER_STOP` (default): Control consumes mouse events, Area2D doesn't receive them
   - `MOUSE_FILTER_PASS`: Control processes events but passes them through
   - `MOUSE_FILTER_IGNORE`: Control doesn't interact with mouse at all

2. **_input() vs mouse_filter:**
   - `mouse_filter` affects GUI events (click detection, hover states)
   - `_input()` receives all InputEvents regardless of mouse_filter
   - RoomBuildUI only uses `_input()`, so MOUSE_FILTER_IGNORE is safe

---

## Impact

### Complete Fix Chain

This completes the room selection fix that spans two plans:
1. **01-03:** Added InputEventMouseButton handling to RoomManager (desktop support)
2. **01-04:** Removed RoomBuildUI blocking of Area2D events (event propagation)

Both fixes were necessary - mouse handling without event propagation = no selection.

### UAT Coverage Restored

All UAT tests 2-6 can now be executed and verified:
- Test 2: Click on completed room triggers selection
- Test 3: Yellow highlight appears on selected room
- Test 4: Selection state properly managed
- Test 5: Click outside to deselect works
- Test 6: Click-and-drag does not trigger selection

---

## Duration

- Start: 2026-01-22
- Tasks: 1/1 complete
- Duration: ~2 minutes
