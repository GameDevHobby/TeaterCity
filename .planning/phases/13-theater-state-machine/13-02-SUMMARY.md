# 13-02 Summary - Runtime Theater Ticking + State Indicators

## Completed

- Added runtime theater update loop in `scripts/Main.gd` via `_process(_delta)`:
  - Iterates rooms
  - Filters theater rooms through `TheaterStateConfig.is_theater_room(room)`
  - Calls `room.state_machine.update()` when available
- Added per-theater `StateDebugLabel` orchestration in `Main.gd`:
  - One label per theater room
  - Label bound to room state machine with `set_state_machine`
  - Label position updated above room center each frame using `IsometricMath.tile_to_screen`
  - Create on `room_added` and `room_restored`
  - Remove on `room_removed`
- Added dedicated canvas layer for theater state labels to keep labels screen-space and lifecycle-safe.

## Files

- `scripts/Main.gd`

## Verification

Attempted:

- `godot --headless --path . --quit`

Result:

- Could not execute in this environment: `godot: command not found`.
