# Requirements: v1.1 Theater Core Mechanics

**Milestone:** v1.1 Theater Core Mechanics
**Created:** 2026-02-08
**Status:** Active

---

## Overview

This milestone implements the foundational timer system and core theater gameplay loop. Players will be able to schedule movies in theaters and watch patrons attend showings.

**Scope:**
- Abstract timer system (offline-capable, reusable)
- Room state machine pattern
- Theater states and transitions
- Movie data and scheduling UI
- Patron theater attendance behavior

**Deferred to v1.2+:**
- Patron movie preferences
- Movie matching / leave behavior
- Movie duration progression
- Theater upgrades / movie queue

---

## Requirements

### Foundation Systems

| REQ-ID | Requirement | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| TIMER-01 | Abstract timer system that works offline | Must | Timer continues counting while app is closed; correct elapsed time on resume |
| TIMER-02 | Timers reusable across room types | Must | Same timer pattern usable for theater, snackbar, bathroom without modification |
| STATE-01 | Room state machine pattern for room-type-specific states | Must | Rooms can define custom states; state machine is data-driven (not scene-based) |
| STATE-02 | State persistence survives app quit/restart | Must | Room state and timer progress saved to JSON; restored correctly on load |

### Theater Implementation

| REQ-ID | Requirement | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| THTR-01 | Theater room has states: Idle, Scheduled, Previews, Playing, Cleaning | Must | All 5 states exist; visual feedback shows current state |
| THTR-02 | State transitions happen automatically based on timers | Must | Previews→Playing→Cleaning transitions occur automatically at correct times |
| THTR-03 | Movie data model with title, genre, rating, duration | Must | MovieResource exists with all fields; can serialize to/from JSON |
| THTR-04 | Movie pool of randomly generated movies available to schedule | Must | Player sees list of available movies; movies have varied properties |
| THTR-05 | Scheduling UI accessible from theater room's room-type button | Must | Tapping room-type button on theater opens scheduling panel |
| THTR-06 | Player can select a movie from pool and schedule it | Must | Selection triggers Idle→Scheduled transition; movie stored in room state |

### Patron Theater Behavior

| REQ-ID | Requirement | Priority | Acceptance Criteria |
|--------|-------------|----------|---------------------|
| PATR-01 | Patrons pathfind to theater room during Scheduled/Previews states | Must | Patrons navigate to theater when movie scheduled; use existing pathfinding |
| PATR-02 | Patrons claim available seats in theater | Must | Patron occupies specific seat; seat marked unavailable to others |
| PATR-03 | Patrons stay seated during Playing state | Must | Seated patrons do not move during movie playback |
| PATR-04 | Patrons leave after movie ends (Cleaning state begins) | Must | Patrons vacate seats when movie ends; seats freed for next showing |

---

## Traceability

| REQ-ID | Phase | Plan | Status |
|--------|-------|------|--------|
| TIMER-01 | TBD | TBD | Pending |
| TIMER-02 | TBD | TBD | Pending |
| STATE-01 | TBD | TBD | Pending |
| STATE-02 | TBD | TBD | Pending |
| THTR-01 | TBD | TBD | Pending |
| THTR-02 | TBD | TBD | Pending |
| THTR-03 | TBD | TBD | Pending |
| THTR-04 | TBD | TBD | Pending |
| THTR-05 | TBD | TBD | Pending |
| THTR-06 | TBD | TBD | Pending |
| PATR-01 | TBD | TBD | Pending |
| PATR-02 | TBD | TBD | Pending |
| PATR-03 | TBD | TBD | Pending |
| PATR-04 | TBD | TBD | Pending |

---

## Technical Notes

From research (v1.1-SUMMARY.md):

**Critical Implementation Details:**
- Use `Time.get_unix_time_from_system()` for offline timers (NOT Timer nodes)
- Store timestamps as `int` (float causes scientific notation corruption in JSON)
- Use RefCounted state machines (data-driven, not LimboHSM which is scene-based)
- Handle `NOTIFICATION_APPLICATION_PAUSED` for immediate save on Android
- Recalculate all timer states on app resume in `_ready()`

**Key Pitfalls to Avoid:**
1. Timer nodes for offline (they stop when app closes)
2. Float timestamps (corrupt to scientific notation)
3. System clock cheating (cap elapsed time, detect jumps)
4. Missing app pause handler (Android kills without warning)
5. State not recalculated on load (room stuck in wrong state)

---

*14 requirements total for v1.1*
