---
phase: 09-admin-menu-feature-flags
plan: 01
subsystem: admin
tags: [feature-flags, autoload, singleton, save-management]

# Dependency graph
requires:
  - phase: 03-persistence-infrastructure
    provides: RoomSerializer static methods for load/save/delete
  - phase: 01-room-manager-foundation
    provides: RoomManager singleton with register/unregister
provides:
  - AdminMenu autoload singleton
  - Feature flag detection for debug/release builds
  - revert_to_save() operation
  - reset_all_data() operation
affects: [09-02, 09-03, testing-phase]

# Tech tracking
tech-stack:
  added: []
  patterns: [feature-flag-gating, autoload-singleton-pattern]

key-files:
  created:
    - scripts/admin/AdminMenu.gd
  modified:
    - project.godot

key-decisions:
  - "Debug builds always enable admin features via OS.has_feature('debug')"
  - "Release builds can opt-in via ProjectSettings application/admin/enabled"
  - "AdminMenu loads after RoomManager to ensure dependency available"

patterns-established:
  - "Feature flag pattern: _is_admin_enabled() private, is_admin_enabled() public"
  - "Save management: unregister all rooms, then register loaded rooms"

# Metrics
duration: 8min
completed: 2026-02-07
---

# Phase 9 Plan 1: AdminMenu Autoload Singleton Summary

**AdminMenu autoload with feature flag gating and save management operations (revert_to_save, reset_all_data)**

## Performance

- **Duration:** 8 min
- **Started:** 2026-02-07T16:30:00Z
- **Completed:** 2026-02-07T16:38:00Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments
- Created AdminMenu autoload singleton with feature flag detection
- Implemented revert_to_save() to discard session changes and reload from disk
- Implemented reset_all_data() to delete save file and clear all rooms
- Registered AdminMenu in project.godot after RoomManager dependency

## Task Commits

Each task was committed atomically:

1. **Task 1: Create AdminMenu autoload singleton** - `14dab44` (feat)
2. **Task 2: Register AdminMenu as autoload in project.godot** - `b635dda` (feat)
3. **Task 3: Verify feature flag detection works** - No commit (verification only, code already in Task 1)

## Files Created/Modified
- `scripts/admin/AdminMenu.gd` - AdminMenu singleton with feature flags and save management
- `project.godot` - Added AdminMenu autoload entry after RoomManager

## Decisions Made
- Debug builds (editor + debug exports) always enable admin features via `OS.has_feature("debug")`
- Release builds can explicitly enable admin via `ProjectSettings.get_setting("application/admin/enabled")`
- AdminMenu registered after RoomManager in autoload order to ensure dependency availability
- Feature flag checked once in `_ready()` and cached in `_is_enabled` for performance

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- AdminMenu singleton ready for UI integration in Plan 02
- Feature flag detection working (always enabled in editor)
- revert_to_save() and reset_all_data() ready to be wired to UI buttons
- No blockers for Plan 02 (Admin Menu UI)

---
*Phase: 09-admin-menu-feature-flags*
*Completed: 2026-02-07*
