# Milestone v1.1: Theater Core Mechanics

**Status:** Active
**Phases:** 11-15
**Start Date:** 2026-02-08

## Overview

This roadmap implements the foundational timer system and core theater gameplay loop. Players will be able to schedule movies in theaters and watch patrons attend showings. The abstract timer and state machine patterns established here will be reusable for future room types (snackbar, bathroom, etc.).

## Phases

### Phase 11: Timer & State Foundation

**Goal**: Establish reusable infrastructure for offline-capable timers and data-driven room state machines.
**Depends on**: None (foundation phase)
**Plans:** 5 plans

Plans:
- [x] 11-01-PLAN.md — Timer & state machine core classes (TimerState, RoomStateMachine, StateDefinition)
- [x] 11-02-PLAN.md — Persistence integration (RoomInstance, RoomManager resume logic)
- [x] 11-03-PLAN.md — Visual feedback UI (CircularTimerUI, StateDebugLabel)
- [x] 11-04-PLAN.md — Resume notification UI
- [x] 11-05-PLAN.md — Testing & verification

**Requirements:**
- TIMER-01: Abstract timer system that works offline
- TIMER-02: Timers reusable across room types
- STATE-01: Room state machine pattern for room-type-specific states
- STATE-02: State persistence survives app quit/restart

**Success Criteria:**
1. TimerState can be created, started, and correctly reports elapsed time after simulated offline period
2. State machine can be defined with custom states and transitions without modifying core classes
3. Timer and state data serializes to JSON and restores correctly on load
4. App pause handler triggers immediate save on Android (NOTIFICATION_APPLICATION_PAUSED)
5. On app resume, all timer states are recalculated to correct current state

**Technical Notes:**
- Use `Time.get_unix_time_from_system()` for timestamps (NOT Timer nodes)
- Store timestamps as `int` to avoid scientific notation corruption in JSON
- Use RefCounted classes for state machines (data-driven, not scene-based)
- Cap elapsed time to prevent system clock cheating

---

### Phase 12: Movie Data System

**Goal**: Create movie data model and pool generation so players have movies available to schedule.
**Depends on**: None (can run parallel to Phase 11 data work, but typically sequential)
**Plans:** 3 plans

Plans:
- [ ] 12-01-PLAN.md — MovieResource data class with JSON serialization
- [ ] 12-02-PLAN.md — MovieGenerator and MoviePool with persistence
- [ ] 12-03-PLAN.md — Unit tests for movie data system

**Requirements:**
- THTR-03: Movie data model with title, genre, rating, duration
- THTR-04: Movie pool of randomly generated movies available to schedule

**Success Criteria:**
1. MovieResource exists with title, genre, rating, and duration fields
2. MovieResource can serialize to/from JSON correctly
3. MovieGenerator produces a pool of varied movies on demand
4. Player can see a list of available movies with different properties

**Technical Notes:**
- Follow existing registry pattern (FurnitureRegistry, RoomTypeRegistry)
- Movie generation should produce variety in genre, rating, and duration
- Pool size should be configurable (default: 5-8 movies)

---

### Phase 13: Theater State Machine

**Goal**: Implement theater-specific states and automatic timer-driven transitions.
**Depends on**: Phase 11 (requires TimerState and state machine infrastructure)

**Requirements:**
- THTR-01: Theater room has states: Idle, Scheduled, Previews, Playing, Cleaning
- THTR-02: State transitions happen automatically based on timers

**Success Criteria:**
1. Theater room displays current state through visual feedback (label, color, or indicator)
2. Previews state begins automatically when scheduled time arrives
3. Playing state begins automatically after preview duration ends
4. Cleaning state begins automatically after movie duration ends
5. Idle state resumes automatically after cleaning duration ends

**Technical Notes:**
- TheaterState extends base state machine pattern from Phase 11
- TheaterController orchestrates state updates on `_process()` or timer tick
- Duration values should be configurable per-state

---

### Phase 14: Movie Scheduling UI

**Goal**: Players can schedule movies through an accessible UI connected to theater rooms.
**Depends on**: Phase 12 (movies must exist), Phase 13 (theater state machine must exist)

**Requirements:**
- THTR-05: Scheduling UI accessible from theater room's room-type button
- THTR-06: Player can select a movie from pool and schedule it

**Success Criteria:**
1. Tapping the room-type button on a theater room opens the scheduling panel
2. Scheduling panel displays available movies from the movie pool
3. Each movie shows title, genre, rating, and duration in the list
4. Selecting a movie and confirming triggers Idle -> Scheduled transition
5. Selected movie is stored in the theater's state data

**Technical Notes:**
- Reuse existing room-type button infrastructure
- Panel should follow established UI patterns (PanelContainer, StyleBoxFlat)
- Consider mobile-friendly list scrolling and tap targets

---

### Phase 15: Patron Theater Behavior

**Goal**: Patrons attend scheduled movies by pathfinding to theaters, claiming seats, watching, and leaving.
**Depends on**: Phase 13 (theater states must exist for patron behavior triggers)

**Requirements:**
- PATR-01: Patrons pathfind to theater room during Scheduled/Previews states
- PATR-02: Patrons claim available seats in theater
- PATR-03: Patrons stay seated during Playing state
- PATR-04: Patrons leave after movie ends (Cleaning state begins)

**Success Criteria:**
1. Patrons navigate toward theater when a movie is in Scheduled or Previews state
2. Patron claims a specific seat upon arrival; seat becomes unavailable to others
3. Seated patrons remain stationary during the Playing state
4. When Cleaning state begins, all seated patrons vacate and seats are freed
5. Theater seat capacity limits how many patrons can attend a showing

**Technical Notes:**
- Extend existing Patron pathfinding (NavigationAgent2D)
- Seat tracking could use a simple dictionary in theater state
- Consider behavior tree task or direct state check for patron decision-making

---

## Progress

| Phase | Name | Status | Plans |
|-------|------|--------|-------|
| 11 | Timer & State Foundation | ✓ Complete | 5/5 |
| 12 | Movie Data System | Planned | 0/3 |
| 13 | Theater State Machine | Pending | TBD |
| 14 | Movie Scheduling UI | Pending | TBD |
| 15 | Patron Theater Behavior | Pending | TBD |

---

## Requirement Coverage

| REQ-ID | Requirement | Phase |
|--------|-------------|-------|
| TIMER-01 | Abstract timer system that works offline | Phase 11 |
| TIMER-02 | Timers reusable across room types | Phase 11 |
| STATE-01 | Room state machine pattern for room-type-specific states | Phase 11 |
| STATE-02 | State persistence survives app quit/restart | Phase 11 |
| THTR-01 | Theater room has states: Idle, Scheduled, Previews, Playing, Cleaning | Phase 13 |
| THTR-02 | State transitions happen automatically based on timers | Phase 13 |
| THTR-03 | Movie data model with title, genre, rating, duration | Phase 12 |
| THTR-04 | Movie pool of randomly generated movies available to schedule | Phase 12 |
| THTR-05 | Scheduling UI accessible from theater room's room-type button | Phase 14 |
| THTR-06 | Player can select a movie from pool and schedule it | Phase 14 |
| PATR-01 | Patrons pathfind to theater room during Scheduled/Previews states | Phase 15 |
| PATR-02 | Patrons claim available seats in theater | Phase 15 |
| PATR-03 | Patrons stay seated during Playing state | Phase 15 |
| PATR-04 | Patrons leave after movie ends (Cleaning state begins) | Phase 15 |

**Coverage:** 14/14 requirements mapped

---

## Dependencies Graph

```
Phase 11: Timer & State Foundation
    |
    v
Phase 13: Theater State Machine
    |
    +---> Phase 14: Scheduling UI <--- Phase 12: Movie Data System
    |
    v
Phase 15: Patron Theater Behavior
```

**Execution Order:** 11 -> 12 -> 13 -> 14 -> 15

Note: Phases 11 and 12 could theoretically run in parallel, but sequential execution is recommended to establish foundation patterns first.

---

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| RefCounted state machines | Data-driven, not scene-based; matches existing operation patterns |
| Unix timestamps as int | Avoids JSON scientific notation corruption with floats |
| NOTIFICATION_APPLICATION_PAUSED | Android kills apps without warning; must save immediately |
| Recalculate on resume | State might have changed while offline; timers don't tick when closed |
| Seat claiming via dictionary | Simple tracking; no need for complex seat objects |

---

## Research Flags

From v1.1-SUMMARY.md research:

| Area | Risk | Mitigation |
|------|------|------------|
| Offline timers | HIGH | Use system timestamps, not Timer nodes |
| Float corruption | HIGH | Store timestamps as int |
| Clock cheating | MEDIUM | Cap elapsed time to reasonable max |
| App pause | HIGH | Handle NOTIFICATION_APPLICATION_PAUSED |
| State on load | MEDIUM | Recalculate all states in _ready() |

---

*Created: 2026-02-08*
*Milestone: v1.1 Theater Core Mechanics*
