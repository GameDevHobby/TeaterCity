# Phase 01 Plan 03: Desktop Mouse Input Fix Summary

**One-liner:** Added InputEventMouseButton handling for desktop room selection alongside existing mobile touch support

---

## What Was Done

### Task 1: Add mouse click handling to RoomManager._on_area_input
- **Commit:** 88d6963
- **Files modified:** scripts/RoomManager.gd

Modified `_on_area_input()` to handle both input types:
- `InputEventMouseButton` for desktop mouse clicks (new)
- `InputEventScreenTouch` for mobile touch events (preserved)

Both input handlers use identical tap vs drag discrimination logic:
- 20px distance threshold
- 300ms time threshold
- Click-and-drag exceeding thresholds does not trigger selection

---

## Root Cause Analysis

**Problem:** Room selection only worked on mobile, not desktop.

**Cause:** The `_on_area_input()` function only checked for `InputEventScreenTouch`, completely ignoring desktop mouse input (`InputEventMouseButton`).

**Pattern already existed:** The codebase's `box_drawing_state.gd` and `door_placement_state.gd` already use `InputEventMouseButton` for their input handling. RoomManager was inconsistent with this pattern.

**Fix:** Added parallel handling for `InputEventMouseButton` with the same tap detection logic.

---

## Deviations from Plan

None - plan executed exactly as written.

---

## Commits

| Commit | Type | Description |
|--------|------|-------------|
| 88d6963 | fix | Add mouse click handling for desktop room selection |

---

## Technical Details

### Code Change (RoomManager.gd)

```gdscript
func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, room: RoomInstance) -> void:
    # Handle mouse clicks (desktop)
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed:
            _touch_start_pos = event.position
            _touch_start_time = Time.get_ticks_msec()
        else:
            var distance := event.position.distance_to(_touch_start_pos)
            var duration := Time.get_ticks_msec() - _touch_start_time
            if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
                select_room(room)
        return

    # Handle touch events (mobile)
    if event is InputEventScreenTouch:
        # ... identical tap detection logic
```

### Why This Works

1. `Area2D.input_event` signal fires for both mouse and touch input
2. Godot converts touch to mouse by default, but Area2D gets raw events
3. Desktop testing requires explicit `InputEventMouseButton` handling
4. Mobile devices still use `InputEventScreenTouch`

---

## Impact

### UAT Coverage Restored

This fix unblocks UAT tests 2-6 which were skipped due to selection not working:
- Test 2: Tap on completed room (now works with click)
- Test 3: Visual highlight on selection (can now be verified)
- Test 4: Selection state management (can now be verified)
- Test 5: Tap outside to deselect (can now be verified)
- Test 6: Drag vs tap discrimination (can now be verified)

### Next Steps

Re-run UAT to verify all tests pass with the desktop mouse input fix.

---

## Duration

- Start: 2026-01-22T14:52:26Z
- End: 2026-01-22T14:53:03Z
- Duration: ~37 seconds
