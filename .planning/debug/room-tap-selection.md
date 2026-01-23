---
status: diagnosed
trigger: "Investigate why tapping rooms doesn't trigger selection"
created: 2026-01-22T00:00:00Z
updated: 2026-01-22T00:05:00Z
symptoms_prefilled: true
---

## Current Focus

hypothesis: CONFIRMED - Input handler only checks InputEventScreenTouch, not InputEventMouseButton
test: Compare RoomManager._on_area_input with other input handlers in codebase
expecting: RoomManager only handles touch, others handle mouse
next_action: Return diagnosis

## Symptoms

expected: Tapping inside a completed room should print "Room selected: room_X" and show yellow highlight
actual: Nothing happens when tapping room or anywhere in scene
errors: None reported
reproduction: Complete a room, then tap inside it
started: Unknown - may have never worked

## Eliminated

## Evidence

- timestamp: 2026-01-22T00:01:00Z
  checked: RoomManager.gd _on_area_input function (lines 114-130)
  found: Only handles InputEventScreenTouch - `if not event is InputEventScreenTouch: return`
  implication: Mouse clicks on desktop won't trigger selection

- timestamp: 2026-01-22T00:02:00Z
  checked: Other input handlers in codebase (box_drawing_state.gd, door_placement_state.gd, furniture_placement_state.gd, RoomBuildUI.gd)
  found: All use `InputEventMouseButton` for click detection, not InputEventScreenTouch
  implication: Inconsistent input handling - build UI works with mouse, selection doesn't

- timestamp: 2026-01-22T00:03:00Z
  checked: RoomBuildController.gd line 165
  found: register_room IS being called after room completion
  implication: Room registration works, problem is input handling not registration

- timestamp: 2026-01-22T00:04:00Z
  checked: RoomManager._create_selection_area function (lines 72-84)
  found: Area2D is created with input_pickable=true, collision polygon, and signal connected
  implication: Area2D setup is correct, problem is event type filtering

## Resolution

root_cause: RoomManager._on_area_input() only handles InputEventScreenTouch (mobile touch), but desktop clicks generate InputEventMouseButton. The handler at line 115 returns early for all non-touch events.
fix: Modify _on_area_input to also handle InputEventMouseButton with MOUSE_BUTTON_LEFT, matching the pattern used in RoomBuildUI and other input handlers
verification:
files_changed: []
