# 13-01 Summary - Theater State Config + Initialization Wiring

## Completed

- Added `TheaterStateConfig` helper in `scripts/state_machine/TheaterStateConfig.gd` with canonical theater graph:
  - `idle -> (none)`
  - `scheduled -> previews`
  - `previews -> playing`
  - `playing -> cleaning`
  - `cleaning -> idle`
- Added reusable room-type guards:
  - `is_theater_room_type(room_type_id)`
  - `is_theater_room(room)`
- Updated `RoomInstance.initialize_state_machine()` to consistently forward `state_changed` for both fresh and restored initialization paths and avoid duplicate signal connection.
- Updated `RoomBuildController` to initialize theater state machines in both lifecycle boundaries:
  - New room completion (`_on_complete_pressed`)
  - Room restore (`_on_room_restored`)
- Freshly initialized theater rooms now transition to `idle` when current state is empty.

## Files

- `scripts/state_machine/TheaterStateConfig.gd`
- `scripts/storage/RoomInstance.gd`
- `scripts/room_building/RoomBuildController.gd`

## Verification

Attempted:

- `godot --headless --path . --quit`

Result:

- Could not execute in this environment: `godot: command not found`.
