---
status: diagnosed
trigger: "Investigate why room selection still doesn't work after the 01-03 fix"
created: 2026-01-22T00:00:00Z
updated: 2026-01-22T00:10:00Z
---

## Current Focus

hypothesis: CONFIRMED - RoomBuildUI Control (full-screen) blocks Area2D input_event signals
test: Verified RoomBuildUI has anchors_preset=15 (FULL_RECT) and no explicit mouse_filter
expecting: Default mouse_filter=STOP blocks input to underlying Area2D
next_action: Return diagnosis

## Symptoms

expected: Click on completed room triggers selection, console output, highlight
actual: Click on room produces nothing - no console output, no highlight
errors: None reported
reproduction: Click on a completed room in the game
started: After 01-03 fix was applied (fix didn't resolve the issue)

## Eliminated

- hypothesis: Input handler only checks touch events, not mouse events
  evidence: RoomManager._on_area_input() DOES handle InputEventMouseButton (lines 116-125) - fix was already applied
  timestamp: 2026-01-22T00:01:00Z

- hypothesis: Area2D polygon coordinates wrong (tile vs world space)
  evidence: _room_to_polygon uses IsometricMath.tile_to_world correctly; coordinates are world-space
  timestamp: 2026-01-22T00:02:00Z

- hypothesis: Signal not connected
  evidence: line 81 shows area.input_event.connect(_on_area_input.bind(room)) - signal IS connected
  timestamp: 2026-01-22T00:02:30Z

## Evidence

- timestamp: 2026-01-22T00:03:00Z
  checked: RoomManager._on_area_input() implementation (lines 114-136)
  found: Handler properly checks InputEventMouseButton AND InputEventScreenTouch
  implication: The 01-03 fix was correctly applied - input handling code is correct

- timestamp: 2026-01-22T00:04:00Z
  checked: Main.tscn lines 1270-1290 - RoomBuildUI node configuration
  found: RoomBuildUI is a Control with anchors_preset=15 (FULL_RECT), no mouse_filter property set
  implication: Default mouse_filter is MOUSE_FILTER_STOP - blocks all input to nodes below

- timestamp: 2026-01-22T00:05:00Z
  checked: Godot issue #54529 (github.com/godotengine/godot/issues/54529)
  found: Confirmed bug - "Control consumes CollisionObject events for Area2D despite mouse_filter set to pass"
  implication: Even with mouse_filter=PASS, Controls block Area2D input; IGNORE is required

- timestamp: 2026-01-22T00:06:00Z
  checked: RoomBuildUI._input() function (lines 121-160)
  found: Uses _input() to handle input when modes are active - this captures all input events
  implication: Control with _input() receives events BEFORE Area2D.input_event regardless of blocking

- timestamp: 2026-01-22T00:07:00Z
  checked: Godot input order documentation
  found: Godot processes input in order: _input() on all nodes -> Area2D.input_event -> _unhandled_input()
  implication: RoomBuildUI._input() receives events first, but should still allow Area2D to fire if not consumed

- timestamp: 2026-01-22T00:08:00Z
  checked: Scene tree structure
  found: RoomBuildUI is in CanvasLayer child of RoomBuildSystem; Area2D is child of RoomManager autoload
  implication: Area2D is in different canvas layer than Control, but Control still blocks due to STOP filter

## Resolution

root_cause: |
  RoomBuildUI (Control node) covers the entire screen (anchors_preset=15 FULL_RECT) with default
  mouse_filter=MOUSE_FILTER_STOP. This blocks Area2D.input_event signals from firing, even though:
  1. The 01-03 fix correctly added InputEventMouseButton handling to _on_area_input()
  2. The Area2D is correctly configured with input_pickable=true
  3. The collision polygon coordinates are correctly calculated

  The Control's mouse_filter being STOP means mouse events never reach the Area2D collision system.
  This is a known Godot behavior (issue #54529) where Controls block CollisionObject input.

fix: |
  Set RoomBuildUI.mouse_filter = MOUSE_FILTER_IGNORE in the scene file OR in _ready():

  Option A (Scene): Add "mouse_filter = 2" to [node name="RoomBuildUI" ...] in Main.tscn

  Option B (Code): In RoomBuildUI._ready(), add: mouse_filter = Control.MOUSE_FILTER_IGNORE

  Since RoomBuildUI uses _input() (not gui_input), it will still receive input events even with
  mouse_filter=IGNORE. The difference is that IGNORE allows events to pass through to Area2D.

verification:
files_changed: []
