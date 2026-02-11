# 13-03 Summary - Theater State Machine Tests

## Completed

- Added unit tests in `test/unit/test_theater_state_machine.gd` covering:
  - Required five-state theater graph
  - Canonical transition chain and durations
  - Fresh theater initialization to `idle`
  - Timer-driven transition sequence back to `idle`
  - Non-theater guard path
- Added integration tests in `test/integration/test_theater_state_resume.gd` covering:
  - Theater state serialization in `RoomInstance.to_dict()`
  - Restore + rehydration via `RoomInstance.from_dict()` and `initialize_state_machine()`
  - Offline fast-forward across multiple transitions
  - Safe recovery from invalid stale payload data

## Files

- `test/unit/test_theater_state_machine.gd`
- `test/integration/test_theater_state_resume.gd`

## Verification

Attempted:

- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gtest=test_theater_state_machine.gd`
- `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/integration -ginclude_subdirs -gtest=test_theater_state_resume.gd`

Result:

- Could not execute in this environment: `godot: command not found`.
