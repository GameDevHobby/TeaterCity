phase: 14
plan: 03
phase_name: Movie Scheduling UI
status: human_needed
verified_at: 2026-02-16
notes: "Automated test execution blocked in this environment; requires local Godot run."

## Goal

Confirm end-to-end theater scheduling flow with persisted movie selection.

## Automated Checks

- Unit tests: `godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=test/unit -ginclude_subdirs -gexit`
- Integration tests: `godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=test/integration -ginclude_subdirs -gexit`

Result: `godot: command not found` in this environment.

## Human Verification Checklist

1. Run the game: `godot --path .`.
2. Select a theater room and tap `Theater Schedule`.
3. Confirm centered modal appears and movie rows include title/genre/rating/duration.
4. Tap `Cancel` and confirm theater state is unchanged.
5. Reopen modal, select a movie, tap `Schedule`, and confirm theater state becomes `scheduled`.
6. Save/reload and confirm selected movie payload persists on that room.

## Pass Criteria

- UI flow matches checklist steps.
- Scheduled movie persists through save/load.
- Theater state transitions only on valid idle scheduling.
