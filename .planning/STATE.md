# Project State: TheaterCity

**Last Updated:** 2026-02-16 (Phase 14 executed, pending human verification)

---

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-02-08)

**Core value:** Players experience the satisfying loop of managing a theater: schedule movies, watch patrons arrive, and earn revenue.

**Current focus:** v1.1 Theater Core Mechanics

---

## Current Position

**Milestone:** v1.1 Theater Core Mechanics
**Phase:** 14 - Movie Scheduling UI (HUMAN VERIFICATION NEEDED)
**Current Phase:** 14
**Current Phase Name:** Movie Scheduling UI
**Plan:** 03 of 3 complete
**Current Plan:** 3
**Total Plans in Phase:** 3
**Status:** Phase complete — ready for verification
**Last activity:** 2026-02-16

**Progress:**
[██████████] 98%
Milestone v1.0: SHIPPED 2026-02-08 (10 phases, 41 plans)
See: .planning/milestones/v1.0-ROADMAP.md

Milestone v1.1: IN PROGRESS
[█████] Phase 11: Timer & State Foundation ✓ VERIFIED
[█████] Phase 12: Movie Data System ✓ COMPLETE
[█████] Phase 13: Theater State Machine ✓ VERIFIED
[█████] Phase 14: Movie Scheduling UI ◆ HUMAN VERIFY
[-----] Phase 15: Patron Theater Behavior (pending)

Total: 3/5 phases complete | 6/14 requirements done
```

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| v1.0 Plans Executed | 41 |
| v1.0 Tests Written | 91 |
| v1.1 Plans Executed | 8 |
| v1.1 Tests Written | 149 (91 + 37 + 21) |
| v1.0 LOC | 9,905 GDScript |
| v1.0 Duration | 18 days |
| v1.1 Requirements | 14 |
| v1.1 Phases | 5 |

---
| Phase 14 P02 | 78s | 2 tasks | 2 files |

## Accumulated Context

### Key Decisions

See `.planning/PROJECT.md` Key Decisions table (updated with outcomes).

**v1.1 Decisions:**
- RefCounted state machines (data-driven, not scene-based)
- Unix timestamps as int (avoid JSON float corruption)
- NOTIFICATION_APPLICATION_PAUSED for Android save
- Recalculate all states on app resume
- Overflow time back-dating during fast-forward recalculation (11-01)
- Deferred initialization pattern for state machines (11-02)
- Don't punish backward clock jumps, log only (11-02)
- Programmatic texture generation for progress indicators (11-03)
- MM:SS countdown format over percentage display (11-03)
- Generic toast messaging for Phase 11, enhance later (11-04)
- 3-second toast display with 0.5s fade (11-04)
- Simulate offline periods via backdated timestamps for testing (11-05)
- Separate unit and integration test organization (11-05)
- Int types for rating/duration in MovieResource (12-01)
- Safe defaults in from_dict for robust deserialization (12-01)
- RNG instance per generator for reproducibility (12-02)
- Rating floor of 30 to avoid terrible movies (12-02)
- Default pool size 5-8 movies (12-02)
- Follow existing test patterns for unit tests (12-03)
- Statistical variety assertions for RNG testing (12-03)

### Technical Notes

Core patterns established in v1.0:
- RoomManager singleton for room tracking and selection
- Stateless RefCounted operation classes (ResizeOperation, DeletionOperation, etc.)
- Signal-driven architecture for controller -> Main.gd communication
- Atomic JSON persistence with 5s debounce auto-save
- Area2D per-item selection with isometric collision polygons
- Feature flags via OS.has_feature("debug") + ProjectSettings override

**v1.1 Technical Notes (from research):**
- Use `Time.get_unix_time_from_system()` for offline timers (NOT Timer nodes)
- Store timestamps as `int` (float causes scientific notation corruption in JSON)
- Use RefCounted state machines (data-driven, not LimboHSM which is scene-based)
- Handle `NOTIFICATION_APPLICATION_PAUSED` for immediate save on Android
- Recalculate all timer states on app resume in `_ready()`

### Blockers

None currently.

### TODOs

- [x] Plan Phase 11 (Timer & State Foundation)
- [x] Execute Phase 11
- [x] Plan Phase 12 (Movie Data System)
- [x] Execute Phase 12 (COMPLETE)
- [x] Plan Phase 13 (Theater State Machine)
- [x] Execute Phase 13 (COMPLETE)
- [x] Plan Phase 14 (Movie Scheduling UI)
- [x] Execute Phase 14 (awaiting human verification approval)
- [ ] Plan Phase 15 (Patron Theater Behavior)
- [ ] Execute Phase 15

---

## Session

**Last session:** 2026-02-16T18:58:09.420Z
**Last Date:** 2026-02-16T18:58:09.420Z
**Stopped At:** Completed 14-02-PLAN.md
**Resume File:** None

## Session Continuity

### What Was Done

- Phase 11 Plan 01 executed and completed (2026-02-08)
- Created TimerState, StateDefinition, RoomStateMachine classes
- Phase 11 Plan 02 executed and completed (2026-02-08)
- Integrated state machines into RoomInstance/RoomManager persistence
- Added app resume logic with clock manipulation detection
- Phase 11 Plan 03 executed and completed (2026-02-08)
- Created CircularTimerUI and StateDebugLabel UI components
- Phase 11 Plan 04 executed and completed (2026-02-08)
- Created ResumeNotificationUI toast component for app resume notifications
- Phase 11 Plan 05 executed and completed (2026-02-08)
- Created comprehensive test suite: 37 tests for timer and state machine infrastructure
- All classes use RefCounted with JSON serialization support
- Fast-forward recalculation with overflow handling implemented
- Programmatic texture generation for circular progress

### What's Next

1. Run Phase 14 human verification checklist and approve/fix gaps
2. Execute Phase 15 (Patron Theater Behavior)
3. Complete v1.1 milestone

### Context for Next Session

Phase 14 implementation is complete in code and tests were added, but local Godot execution is unavailable in this environment. Human verification checklist is required before phase closure.

Key files created (Phase 11):
- `scripts/storage/TimerState.gd` - Timestamp-based offline timer
- `scripts/state_machine/StateDefinition.gd` - State configuration data class
- `scripts/state_machine/RoomStateMachine.gd` - State machine with timed transitions
- `scripts/ui/CircularTimerUI.gd` + `.tscn` - Circular progress with MM:SS countdown
- `scripts/ui/StateDebugLabel.gd` - Debug state name display
- `scripts/ui/ResumeNotificationUI.gd` + `.tscn` - Toast notification for app resume
- `test/unit/test_timer_state.gd` - 16 unit tests for TimerState
- `test/unit/test_room_state_machine.gd` - 16 unit tests for RoomStateMachine
- `test/integration/test_timer_persistence.gd` - 5 integration tests for persistence

Key files created (Phase 12):
- `scripts/data/MovieResource.gd` - Movie data model with JSON serialization
- `scripts/generation/MovieGenerator.gd` - Procedural movie generation with seeded RNG
- `scripts/storage/MoviePool.gd` - Runtime movie collection with ID lookup
- `scripts/storage/MoviePoolSerializer.gd` - Atomic JSON persistence for movie pool
- `test/unit/test_movie_data.gd` - 21 unit tests for movie data system

Key files created (Phase 13):
- `scripts/state_machine/TheaterStateConfig.gd` - Canonical theater state definitions + room-type guard
- `test/unit/test_theater_state_machine.gd` - Unit tests for theater graph and timed transitions
- `test/integration/test_theater_state_resume.gd` - Integration tests for save/load and resume progression

Key files updated (Phase 13):
- `scripts/storage/RoomInstance.gd` - Consistent state-machine signal wiring for fresh/restore paths
- `scripts/room_building/RoomBuildController.gd` - Theater state initialization for create + restore lifecycles
- `scripts/Main.gd` - Runtime theater ticking and per-room state label lifecycle
- `scripts/ui/StateDebugLabel.gd` - Improved readable badge-style label theme

Key files created (Phase 14):
- `scripts/room_editing/TheaterSchedulePanel.gd` - Centered scheduling modal with movie list and explicit confirm/cancel flow
- `test/integration/test_theater_schedule_flow.gd` - Integration coverage for idle-only scheduling guards and non-theater no-op path

Key files updated (Phase 14):
- `Scripts/Main.gd` - Runtime movie pool bootstrap, theater scheduling API, and theater modal integration
- `Scripts/storage/RoomInstance.gd` - Scheduled-movie payload fields and serialization helpers
- `test/unit/test_room_instance.gd` - Unit coverage for scheduled movie payload persistence/signals

Summaries:
- `.planning/phases/11-timer-state-foundation/11-01-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-02-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-03-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-04-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-05-SUMMARY.md`
- `.planning/phases/12-movie-data-system/12-01-SUMMARY.md`
- `.planning/phases/12-movie-data-system/12-02-SUMMARY.md`
- `.planning/phases/12-movie-data-system/12-03-SUMMARY.md`
- `.planning/phases/13-theater-state-machine/13-01-SUMMARY.md`
- `.planning/phases/13-theater-state-machine/13-02-SUMMARY.md`
- `.planning/phases/13-theater-state-machine/13-03-SUMMARY.md`
- `.planning/phases/13-theater-state-machine/13-VERIFICATION.md`
- `.planning/phases/14-movie-scheduling-ui/14-01-SUMMARY.md`
- `.planning/phases/14-movie-scheduling-ui/14-02-SUMMARY.md`
- `.planning/phases/14-movie-scheduling-ui/14-03-SUMMARY.md`
- `.planning/phases/14-movie-scheduling-ui/14-VERIFICATION.md`

---

*State initialized: 2026-01-21*
*v1.0 shipped: 2026-02-08*
*v1.1 started: 2026-02-08*
*v1.1 roadmap: 2026-02-08*
