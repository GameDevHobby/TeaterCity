# Phase 14 Research: Movie Scheduling UI

**Phase:** 14-movie-scheduling-ui  
**Date:** 2026-02-15  
**Discovery Level:** 0 (internal extension of existing systems)

## Existing Touchpoints

- `scripts/room_editing/RoomEditMenu.gd`
  - Already exposes `room_type_action_pressed(room)` and labels theater action as `Theater Schedule`.
- `scripts/Main.gd`
  - Handles `room_type_action_pressed` in `_on_room_type_action_requested(room)`.
  - Current behavior immediately transitions theater `idle -> scheduled` with no movie selection.
  - Owns layered UI setup (`EditMenuLayer`, CanvasLayer patterns) and room-mode camera toggles.
- `scripts/storage/RoomInstance.gd`
  - Persists room data and state machine payload; currently no theater movie payload.
- `scripts/storage/MoviePool.gd` + `scripts/storage/MoviePoolSerializer.gd`
  - Provide runtime movie collection and JSON persistence utilities, but are not yet wired into `Main.gd` runtime flow.
- `scripts/data/MovieResource.gd` and `scripts/generation/MovieGenerator.gd`
  - Define movie data shape and generation for schedule choices.

## Recommended Implementation Approach

1. **Data + scheduling runtime wiring first**
   - Extend `RoomInstance` with theater schedule payload (selected movie metadata) and serialization.
   - In `Main.gd`, create/load runtime `MoviePool` (fallback generate + save when no file exists).
   - Replace direct transition logic with a scheduling entrypoint that accepts selected movie ID, writes room payload, then transitions `idle -> scheduled`.

2. **Modal UI second**
   - Add `TheaterSchedulePanel` (`Control`) in `scripts/room_editing/` to match existing room editing architecture.
   - Use compact centered `PanelContainer`, scrollable list, explicit Cancel/Close only (no outside-tap dismissal).
   - Emit a confirm signal (`room`, `movie_id`) to `Main.gd` scheduling entrypoint.

3. **Verification last**
   - Unit coverage for new room serialization payload.
   - Integration coverage for schedule transition guardrails (idle-only) and movie payload assignment.
   - Manual runtime check for panel open/list/select/confirm flow.

## Risks and Mitigations

- **Risk:** Transition happens without payload.
  - **Mitigation:** Centralize scheduling in one `Main.gd` method that always sets movie payload before `transition_to("scheduled")`.
- **Risk:** UI becomes inconsistent with existing edit modes.
  - **Mitigation:** Reuse `UIStyleHelper`, CanvasLayer placement, and button creation patterns from `FurnitureListPanel` and `RoomEditMenu`.
- **Risk:** Empty movie pool blocks scheduling.
  - **Mitigation:** On startup, load pool from serializer; if missing/empty, generate default pool and save.
- **Risk:** Serialization regressions for existing rooms.
  - **Mitigation:** Add optional payload fields with safe defaults and keep backward-compatible `from_dict` handling.

## Verification Strategy

- **Automated:**
  - `godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=test/unit -ginclude_subdirs -gexit`
  - `godot --headless --path . --script addons/gut/gut_cmdln.gd -gdir=test/integration -ginclude_subdirs -gexit`
- **Manual runtime:**
  1. Select theater room and tap `Theater Schedule`.
  2. Confirm modal opens centered and lists movie title/genre/rating/duration.
  3. Confirm Cancel closes modal without state change.
  4. Confirm selecting movie + Schedule sets theater to `scheduled` and persists selected movie after save/reload.

## Suggested Plan Breakdown

- **14-01:** Room schedule payload + movie pool runtime wiring + scheduling API in `Main.gd`.
- **14-02:** Build and integrate theater scheduling modal UI.
- **14-03:** Add tests and run final manual verification checkpoint.
