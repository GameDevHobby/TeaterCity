# Phase 14: Movie Scheduling UI - Context

**Gathered:** 2026-02-15
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable players to open a scheduling panel from a theater room's room-type action, browse available movies, and schedule one movie into an idle theater. This phase does not add new capabilities outside theater scheduling.

</domain>

<decisions>
## Implementation Decisions

### Panel entry + layout
- The existing `Theater Schedule` room-type button should open the scheduling UI (it should no longer directly force `idle -> scheduled`).
- The scheduling UI should be a centered modal.
- First open should prioritize a compact view (header + concise list preview before scrolling).
- Dismissal should be explicit only (Cancel/X); outside-tap dismissal is not desired.

### Claude's Discretion
- Exact visual styling details (spacing, typography, stylebox variants) while preserving current project UI language.
- Modal sizing and small interaction polish (e.g., transition feel) as long as it remains compact-first.
- Unlocked areas for follow-up discussion/planning: movie list presentation details, selection/confirmation specifics, and edge-state messaging.

</decisions>

<specifics>
## Specific Ideas

No external product references were requested. Direction is functional and mobile-friendly with compact-first information density.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 14-movie-scheduling-ui*
*Context gathered: 2026-02-15*
