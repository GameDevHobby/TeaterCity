# Phase 11: Timer & State Foundation - Context

**Gathered:** 2026-02-08
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish reusable infrastructure for offline-capable timers and data-driven room state machines. This phase creates the foundational systems that theater rooms (and future room types) will use for timed activities and state tracking.

</domain>

<decisions>
## Implementation Decisions

### State Visibility/Feedback
- Circular progress bar displayed above room center when room is selected
- Progress bar shows countdown timer (time remaining, not percentage)
- Debug label visible when room is selected (shows state name like "IDLE", "PLAYING")
- Progress indicator only appears on selection, not always visible

### Timer Behavior on Resume
- Calculate full elapsed time when app reopens (no cap on offline time)
- Fast-forward all state transitions that occurred while away (e.g., Playing → Cleaning → Idle all resolve)
- Show brief notification like "3 movies finished while you were away"
- Notification content deferred to later phase (no earnings display yet — revenue system not in scope)

### Clock Manipulation Handling
- Allow forward time jumps (casual game, let players skip if they want)
- Ignore backward time jumps (once time passes, progress is kept)
- Persist last known timestamp to detect clock changes
- Debug log only when backward jump detected (no player-facing effect)

### Error Recovery
- Corrupted timer/state data → reset room to idle state
- Invalid state references → reset to idle state
- Always log recovery events (all builds, for analytics/debugging)
- Add save file validation and resilience in this phase (beyond just timer data)

### Claude's Discretion
- Progress bar visual style (radius, thickness, colors)
- Debug label formatting and positioning
- Exact notification UI implementation (toast style, duration)
- State machine internal architecture details
- Validation approach for save file resilience

</decisions>

<specifics>
## Specific Ideas

- Progress bar should be circular, positioned floating above the room center
- Countdown shows time remaining (e.g., "2:30") rather than percentage filled
- "Last known time" tracking enables detecting both forward and backward clock manipulation
- Recovery should be silent for the player but logged for developer analytics

</specifics>

<deferred>
## Deferred Ideas

- Earnings/revenue display in catch-up notification — requires revenue system (future phase)
- Detailed activity log panel showing what completed while away — potential future enhancement

</deferred>

---

*Phase: 11-timer-state-foundation*
*Context gathered: 2026-02-08*
