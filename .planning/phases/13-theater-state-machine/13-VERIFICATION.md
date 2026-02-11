phase: 13
phase_name: Theater State Machine
status: human_needed
verified_at: 2026-02-11
score: 4/5

## Goal

Implement theater-specific states and automatic timer-driven transitions.

## Must-Haves Check

1. `Theater room displays current state through visual feedback` - **PASS (code verified)**
   - `scripts/Main.gd` creates and updates `StateDebugLabel` per theater room.
2. `Previews state begins automatically when scheduled time arrives` - **PASS (code verified)**
   - `scripts/state_machine/TheaterStateConfig.gd` chain includes `scheduled -> previews`.
   - `scripts/Main.gd` runtime loop calls `room.state_machine.update()`.
3. `Playing state begins automatically after preview duration ends` - **PASS (code verified)**
   - `previews -> playing` transition defined and ticked at runtime.
4. `Cleaning state begins automatically after movie duration ends` - **PASS (code verified)**
   - `playing -> cleaning` transition defined and ticked at runtime.
5. `Idle state resumes automatically after cleaning duration ends` - **HUMAN VERIFICATION REQUIRED**
   - `cleaning -> idle` transition is implemented, but runtime behavior was not executed in this environment because `godot` binary is unavailable.

## Automated Verification Limits

- `godot --headless --path . --quit` could not run (`godot: command not found`).
- GUT test commands for new Phase 13 test files could not run for the same reason.

## Human Verification Checklist

1. Launch the game and build a `theater_auditorium` room.
2. Confirm theater initializes in `IDLE` state label.
3. Trigger `scheduled` and observe auto-transition chain:
   - `SCHEDULED -> PREVIEWS -> PLAYING -> CLEANING -> IDLE`
4. Delete a theater room and confirm state label is removed cleanly.
5. Save/reload and confirm restored theaters keep working state labels and transitions.

## Recommendation

- After local runtime verification, mark Phase 13 verified and proceed to Phase 14.
