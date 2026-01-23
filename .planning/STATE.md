# Project State: TheaterCity Room Editor

**Milestone:** Room Editor
**Last Updated:** 2026-01-23

---

## Project Reference

**Core Value:** Players can modify their theater layout after initial construction and have those changes saved permanently.

**Current Focus:** Phase 2 in progress - Room Menu & Edit Mode Entry

**Key Files:**
- `.planning/PROJECT.md` - Requirements and constraints
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/research/SUMMARY.md` - Research findings and risk mitigation
- `.planning/codebase/ARCHITECTURE.md` - Existing architecture to extend

---

## Current Position

**Phase:** 2 of 10 (Room Menu & Edit Mode Entry)
**Plan:** 1 of ? complete
**Status:** In progress
**Last activity:** 2026-01-23 - Completed 02-01-PLAN.md (RoomEditMenu contextual menu)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [/] Room Menu & Edit Mode Entry (1/? plans)
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
| Plans Executed | 5 |
| Plans Passed | 5 |
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
| MOUSE_FILTER_IGNORE on menu Control | Full-rect with STOP on panel for click capture | 2-01 |
| Menu offset 30px right of center | Keep menu near but not covering room | 2-01 |
| Contextual room-type button labels | Match statement maps room_type_id to feature names | 2-01 |

### Technical Notes

- Input handling: Desktop uses InputEventMouseButton, mobile uses InputEventScreenTouch
- Touch/click input: Use 20px/300ms threshold to distinguish tap from drag
- Navigation: Must update mesh after ANY room modification
- Signals: Disconnect before dropping RoomInstance references to prevent leaks
- Coordinates: Always store Vector2i tile coords, never world positions
- Isometric hit detection: Convert bounding box to diamond polygon via IsometricMath.tile_to_world()
- Screen-space Controls: Use CanvasLayer layer=0 wrapper in Node2D scenes for tile_to_screen alignment
- MOUSE_FILTER_IGNORE: Required on full-rect Controls to allow Area2D.input_event to receive clicks
- Menu positioning: Use IsometricMath.tile_to_screen, await process_frame for panel size, clamp to viewport

### Blockers

None currently.

### TODOs

- [x] Plan Phase 1: Room Manager Foundation
- [x] Execute 01-01-PLAN.md: RoomManager singleton
- [x] Execute 01-02-PLAN.md: Integration with RoomBuildController
- [x] Execute 01-03-PLAN.md: Desktop mouse input fix (UAT gap closure)
- [x] Execute 01-04-PLAN.md: RoomBuildUI mouse filter fix (second gap closure)
- [x] Re-run UAT to verify all tests pass (6/6 passed)
- [x] Begin Phase 2: Room Menu & Edit Mode Entry
- [x] Execute 02-01-PLAN.md: RoomEditMenu contextual menu
- [ ] Execute remaining Phase 2 plans (if any)
- [ ] Consider spike planning for Phase 8 (Room Resize) due to HIGH complexity flag

---

## Session Continuity

### What Was Done

- Executed 02-01-PLAN.md: RoomEditMenu contextual menu
- Created RoomEditMenu.gd Control with three buttons (Edit Furniture, Edit Room, room-type-specific)
- Integrated into Main.gd with EditMenuLayer CanvasLayer (layer=1)
- Connected menu signals to stub handlers for future phases
- Commits: ab2493f, a7132b4

### What's Next

1. Manual test: Run game, build room, select it, verify menu appears
2. Continue Phase 2 plans (if any remaining)
3. Or proceed to Phase 3: Persistence Infrastructure

### Context for Next Session

Phase 2 Plan 1 complete. RoomEditMenu is now functional:
1. Build a room -> auto-registers with RoomManager
2. Click/tap completed room -> yellow highlight AND edit menu appear
3. Menu has three buttons: Edit Furniture, Edit Room, Room Options
4. Click/tap outside menu -> menu hides and selection clears

Key new files:
- `Scripts/room_editing/RoomEditMenu.gd` - Contextual menu Control
- `Scripts/Main.gd` - Updated with EditMenuLayer and menu integration

Menu signals for future phases:
- `edit_furniture_pressed(room)` - Phase 4/5
- `edit_room_pressed(room)` - Phase 6/7/8
- `room_type_action_pressed(room)` - Room-specific features

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-23*
