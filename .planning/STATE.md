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
**Phase:** 11 - Timer & State Foundation (not started)
**Plan:** --
**Status:** Ready for planning
**Last activity:** 2026-02-08 -- Roadmap created

**Progress:**
```
Milestone v1.0: SHIPPED 2026-02-08 (10 phases, 41 plans)
See: .planning/milestones/v1.0-ROADMAP.md

Milestone v1.1: ROADMAP CREATED
[=----] Phase 11: Timer & State Foundation (pending)
[-----] Phase 12: Movie Data System (pending)
[-----] Phase 13: Theater State Machine (pending)
[-----] Phase 14: Movie Scheduling UI (pending)
[-----] Phase 15: Patron Theater Behavior (pending)

Total: 0/5 phases complete | 0/14 requirements done
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

- [ ] Plan Phase 11 (Timer & State Foundation)
- [ ] Execute Phase 11
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

- v1.1 milestone scope defined: Theater Core Mechanics
- Requirements defined (14 total in REQUIREMENTS.md)
- Research completed (v1.1-SUMMARY.md)
- Roadmap created with 5 phases (11-15)
- All requirements mapped to phases (100% coverage)

### What's Next

1. Plan Phase 11: Timer & State Foundation
2. Execute Phase 11 plans
3. Continue through phases 12-15

### Context for Next Session

v1.1 roadmap complete. Ready to begin Phase 11 planning.

Key files:
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/REQUIREMENTS.md` - Requirements with traceability
- `.planning/research/v1.1-SUMMARY.md` - Technical research findings

---

*State initialized: 2026-01-21*
*v1.0 shipped: 2026-02-08*
*v1.1 started: 2026-02-08*
*v1.1 roadmap: 2026-02-08*
