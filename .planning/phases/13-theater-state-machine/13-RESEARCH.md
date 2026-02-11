---
phase: 13-theater-state-machine
date: 2026-02-10
status: complete
depends_on:
  - 11-timer-state-foundation
  - 12-movie-data-system
---

# Phase 13 Research: Theater State Machine

## Objective

Define the implementation approach for theater-specific room states and automatic timer-driven transitions using the existing Phase 11 state machine infrastructure.

## What Already Exists

- `scripts/state_machine/RoomStateMachine.gd` supports timed states, `update()`, and offline `recalculate_from_elapsed()`.
- `scripts/storage/RoomInstance.gd` supports optional `state_machine`, persistence, and deferred initialization via `initialize_state_machine(state_definitions)`.
- `scripts/RoomManager.gd` recalculates room state machines on app load/resume and emits `room_states_recalculated`.
- `scripts/data/MovieResource.gd` and `scripts/storage/MoviePool.gd` provide movie data foundation from Phase 12.
- `scripts/ui/StateDebugLabel.gd` already exists for visual state display and signal-driven updates.

## Requirements to Implement in Phase 13

- THTR-01: Theater room has states: `Idle`, `Scheduled`, `Previews`, `Playing`, `Cleaning`.
- THTR-02: Transitions occur automatically based on timers.

## Recommended Architecture

1. Add a theater-specific state definition helper that configures the canonical state graph.
2. Initialize theater room state machines when rooms are created/restored.
3. Add a per-frame (or periodic) update loop that calls `state_machine.update()` on theater rooms.
4. Add visual feedback for current theater state (reuse `StateDebugLabel` pattern).

### Canonical State Graph

- `idle` (no timer)
- `scheduled` (timer until show start) -> `previews`
- `previews` (fixed duration) -> `playing`
- `playing` (movie duration) -> `cleaning`
- `cleaning` (fixed duration) -> `idle`

## File-Level Impact (Likely)

### Create

- `scripts/state_machine/TheaterStateConfig.gd`
  - Builds `Dictionary[String -> StateDefinition]` for theater states
  - Centralizes durations and default values

### Modify

- `scripts/Main.gd`
  - Initialize theater state machine for `theater_auditorium` rooms (new + restored)
  - Tick theater state machines in `_process` (or existing update loop)
  - Wire state debug label lifecycle and positioning
- `scripts/storage/RoomInstance.gd`
  - Ensure fresh initialization path also connects `state_changed` signal (currently done only in restore path)
- `scripts/RoomManager.gd` (optional)
  - If needed, add helper accessor/filter for theater rooms (only if this simplifies Main integration)

### Tests

- `test/unit/test_theater_state_machine.gd`
  - State graph configuration correctness
  - Timed transition chain correctness
  - Reset to `idle` after cleaning
- `test/integration/test_theater_state_resume.gd` (optional but recommended)
  - Offline progression across multiple transitions after resume/load

## Key Risks and Pitfalls

1. **Signal connection gap on fresh initialization**
   - In `RoomInstance.initialize_state_machine`, `state_changed` is connected in restore path but not in fresh path.
   - If not fixed, state changes may not emit `placement_changed` and may miss auto-save triggers.

2. **Double progression (update + recalculate)**
   - Runtime ticking (`update`) and resume recalculation (`recalculate_from_elapsed`) must not both run for same elapsed span unexpectedly.
   - Keep runtime ticking simple and rely on resume hooks only for offline elapsed time.

3. **Dictionary iteration order assumptions**
   - Do not rely on dictionary insertion order for selecting an initial state.
   - Explicitly transition to `idle` after definitions are set.

4. **Duration source mismatch**
   - `playing` duration should come from selected movie duration in later scheduling phase.
   - For Phase 13, use safe defaults and prepare override hooks for Phase 14.

## Verification Guidance

### Functional

- Create/select a theater room and confirm it starts in `idle`.
- Force/seed a scheduled scenario and verify automatic sequence:
  - `scheduled` -> `previews` -> `playing` -> `cleaning` -> `idle`
- Verify state indicator updates visually as transitions occur.

### Persistence/Resume

- Save while in timed state, reopen app, and verify state fast-forwards correctly.
- Background app beyond one or more durations, resume, and verify expected final state.

### Regression

- Non-theater rooms remain unaffected (no state machine unless explicitly configured).
- Existing Phase 11 tests remain green.

## Planning Notes

- Discovery level: **Level 0 (skip external research)**. This phase extends established in-repo patterns and does not require new dependencies.
- Prefer vertical-slice plans:
  1) Theater state configuration + initialization wiring
  2) Runtime ticking + visual feedback
  3) Tests/verification
