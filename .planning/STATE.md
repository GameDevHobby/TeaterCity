# Project State: TheaterCity

**Last Updated:** 2026-02-08 (v1.1 roadmap created)

---

## Project Reference

See: `.planning/PROJECT.md` (updated 2026-02-08)

**Core value:** Players experience the satisfying loop of managing a theater: schedule movies, watch patrons arrive, and earn revenue.

**Current focus:** v1.1 Theater Core Mechanics

---

## Current Position

**Milestone:** v1.1 Theater Core Mechanics
**Phase:** 11 - Timer & State Foundation (complete)
**Plan:** 02 of 02 (Plan 11-02 complete)
**Status:** Phase 11 complete
**Last activity:** 2026-02-08 -- Completed plan 11-02

**Progress:**
```
Milestone v1.0: SHIPPED 2026-02-08 (10 phases, 41 plans)
See: .planning/milestones/v1.0-ROADMAP.md

Milestone v1.1: IN PROGRESS
[█----] Phase 11: Timer & State Foundation (complete)
[-----] Phase 12: Movie Data System (pending)
[-----] Phase 13: Theater State Machine (pending)
[-----] Phase 14: Movie Scheduling UI (pending)
[-----] Phase 15: Patron Theater Behavior (pending)

Total: 1/5 phases complete | 3/14 requirements done
```

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| v1.0 Plans Executed | 41 |
| v1.0 Tests Written | 91 |
| v1.0 LOC | 9,905 GDScript |
| v1.0 Duration | 18 days |
| v1.1 Requirements | 14 |
| v1.1 Phases | 5 |

---

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
- [ ] Plan Phase 12 (Movie Data System)
- [ ] Execute Phase 12
- [ ] Plan Phase 13 (Theater State Machine)
- [ ] Execute Phase 13
- [ ] Plan Phase 14 (Movie Scheduling UI)
- [ ] Execute Phase 14
- [ ] Plan Phase 15 (Patron Theater Behavior)
- [ ] Execute Phase 15

---

## Session Continuity

### What Was Done

- Phase 11 Plan 01 executed and completed (2026-02-08)
- Created TimerState, StateDefinition, RoomStateMachine classes
- Phase 11 Plan 02 executed and completed (2026-02-08)
- Integrated state machines into RoomInstance/RoomManager persistence
- Added app resume logic with clock manipulation detection
- Phase 11 Plan 03 executed and completed (2026-02-08)
- Created CircularTimerUI and StateDebugLabel UI components
- All classes use RefCounted with JSON serialization support
- Fast-forward recalculation with overflow handling implemented
- Programmatic texture generation for circular progress

### What's Next

1. Plan Phase 12: Movie Data System
2. Execute Phase 12 plans
3. Continue through phases 13-15

### Context for Next Session

Phase 11 complete. Ready to begin Phase 12 planning.

Key files created:
- `Scripts/storage/TimerState.gd` - Timestamp-based offline timer
- `Scripts/state_machine/StateDefinition.gd` - State configuration data class
- `Scripts/state_machine/RoomStateMachine.gd` - State machine with timed transitions
- `Scripts/ui/CircularTimerUI.gd` + `.tscn` - Circular progress with MM:SS countdown
- `Scripts/ui/StateDebugLabel.gd` - Debug state name display

Summaries:
- `.planning/phases/11-timer-state-foundation/11-01-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-02-SUMMARY.md`
- `.planning/phases/11-timer-state-foundation/11-03-SUMMARY.md`

---

*State initialized: 2026-01-21*
*v1.0 shipped: 2026-02-08*
*v1.1 started: 2026-02-08*
*v1.1 roadmap: 2026-02-08*
