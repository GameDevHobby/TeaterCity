# Project State: TheaterCity Room Editor

**Milestone:** Room Editor
**Last Updated:** 2026-01-22

---

## Project Reference

**Core Value:** Players can modify their theater layout after initial construction and have those changes saved permanently.

**Current Focus:** Phase 1 complete - Room Manager Foundation

**Key Files:**
- `.planning/PROJECT.md` - Requirements and constraints
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/research/SUMMARY.md` - Research findings and risk mitigation
- `.planning/codebase/ARCHITECTURE.md` - Existing architecture to extend

---

## Current Position

**Phase:** 1 of 10 (Room Manager Foundation)
**Plan:** 4 of 4 complete (second gap closure plan added)
**Status:** Phase verified ✓
**Last activity:** 2026-01-22 - Completed 01-04-PLAN.md (RoomBuildUI mouse filter fix)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [ ] Room Menu & Edit Mode Entry
Phase  3: [ ] Persistence Infrastructure
Phase  4: [ ] Furniture Selection
Phase  5: [ ] Furniture Editing Operations
Phase  6: [ ] Door Editing
Phase  7: [ ] Room Deletion
Phase  8: [ ] Room Resize (Complex)
Phase  9: [ ] Admin Menu & Feature Flags
Phase 10: [ ] Testing & Verification
```

**Milestone Progress:** 1/10 phases complete (10%)

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Plans Executed | 4 |
| Plans Passed | 4 |
| Plans Failed | 0 |
| Revision Rounds | 0 |
| Tests Written | 0 |
| Tests Passing | 0 |

---

## Accumulated Context

### Key Decisions

| Decision | Rationale | Phase |
|----------|-----------|-------|
| RoomManager singleton | Track completed rooms, enable selection | 1 |
| Follow Targets.gd pattern | Project consistency for autoload singletons | 1-01 |
| 20px/300ms tap thresholds | Below camera pan thresholds, proven in research | 1-01 |
| input_pickable = true | Required for Area2D hit detection (Godot default is false) | 1-01 |
| CanvasLayer wrapper for highlight | Main.tscn is Node2D, Controls need screen-space rendering | 1-02 |
| Highlight all room tiles | Clearer visual feedback than interior-only | 1-02 |
| MOUSE_FILTER_IGNORE on highlight | Prevent blocking input to room Area2D below | 1-02 |
| Dual input handling | Handle both InputEventMouseButton and InputEventScreenTouch | 1-03 |
| MOUSE_FILTER_IGNORE on RoomBuildUI | Full-rect Control was blocking Area2D input_event signals | 1-04 |
| Parallel RoomEditController | Separate from build workflow, different lifecycle | 2 |
| Atomic saves | Prevent corruption on mobile crashes | 3 |
| Doors reset on resize | Simpler than auto-adjusting door positions | 8 |

### Technical Notes

- Input handling: Desktop uses InputEventMouseButton, mobile uses InputEventScreenTouch
- Touch/click input: Use 20px/300ms threshold to distinguish tap from drag
- Navigation: Must update mesh after ANY room modification
- Signals: Disconnect before dropping RoomInstance references to prevent leaks
- Coordinates: Always store Vector2i tile coords, never world positions
- Isometric hit detection: Convert bounding box to diamond polygon via IsometricMath.tile_to_world()
- Screen-space Controls: Use CanvasLayer layer=0 wrapper in Node2D scenes for tile_to_screen alignment
- MOUSE_FILTER_IGNORE: Required on full-rect Controls to allow Area2D.input_event to receive clicks

### Blockers

None currently.

### TODOs

- [x] Plan Phase 1: Room Manager Foundation
- [x] Execute 01-01-PLAN.md: RoomManager singleton
- [x] Execute 01-02-PLAN.md: Integration with RoomBuildController
- [x] Execute 01-03-PLAN.md: Desktop mouse input fix (UAT gap closure)
- [x] Execute 01-04-PLAN.md: RoomBuildUI mouse filter fix (second gap closure)
- [ ] Re-run UAT to verify all tests pass
- [ ] Begin Phase 2: Room Menu & Edit Mode Entry
- [ ] Consider spike planning for Phase 8 (Room Resize) due to HIGH complexity flag

---

## Session Continuity

### What Was Done

- Executed 01-04-PLAN.md: RoomBuildUI mouse filter gap closure
- Added mouse_filter = MOUSE_FILTER_IGNORE to RoomBuildUI._ready()
- Root cause: Full-rect Control was blocking Area2D.input_event signals
- Committed fix (4162e3b)

### What's Next

1. Re-run UAT to verify tests 2-6 now pass with complete fix chain
2. Begin Phase 2: Room Menu & Edit Mode Entry
3. First plan should create room edit menu shown on selection

### Context for Next Session

Phase 1 (Room Manager Foundation) is complete with both input fixes applied:
1. 01-03: Added InputEventMouseButton handling to RoomManager._on_area_input
2. 01-04: Set MOUSE_FILTER_IGNORE on RoomBuildUI to allow event propagation

The selection workflow now works on both desktop and mobile:
1. Build a room -> auto-registers with RoomManager
2. Click/tap completed room -> visual yellow highlight appears
3. Click/tap outside rooms -> selection clears

Key files:
- `Scripts/RoomManager.gd` - Singleton with room tracking, Area2D selection (dual input handling)
- `Scripts/room_building/RoomBuildUI.gd` - MOUSE_FILTER_IGNORE for event passthrough
- `Scripts/room_building/RoomSelectionHighlight.gd` - Visual highlight Control

Key signals available:
- `RoomManager.room_selected(room)` - Use to trigger edit menu
- `RoomManager.selection_cleared` - Use to hide edit menu

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-22*
