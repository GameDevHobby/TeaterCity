# Project State: TheaterCity Room Editor

**Milestone:** Room Editor
**Last Updated:** 2026-01-23

---

## Project Reference

**Core Value:** Players can modify their theater layout after initial construction and have those changes saved permanently.

**Current Focus:** Phase 4 in progress - Furniture Selection

**Key Files:**
- `.planning/PROJECT.md` - Requirements and constraints
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/research/SUMMARY.md` - Research findings and risk mitigation
- `.planning/codebase/ARCHITECTURE.md` - Existing architecture to extend

---

## Current Position

**Phase:** 4 of 10 (Furniture Selection)
**Plan:** 1 of 2 complete
**Status:** In progress
**Last activity:** 2026-01-23 - Completed 04-01-PLAN.md (FurnitureEditController)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [X] Room Menu & Edit Mode Entry (1/1 plans) COMPLETE
Phase  3: [>] Persistence Infrastructure (1/4 plans)
Phase  4: [>] Furniture Selection (1/2 plans)
Phase  5: [ ] Furniture Editing Operations
Phase  6: [ ] Door Editing
Phase  7: [ ] Room Deletion
Phase  8: [ ] Room Resize (Complex)
Phase  9: [ ] Admin Menu & Feature Flags
Phase 10: [ ] Testing & Verification
```

**Milestone Progress:** 2/10 phases complete (20%)

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Plans Executed | 7 |
| Plans Passed | 7 |
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
| Vector2i as {x,y} objects | JSON.parse_string() handles objects better than arrays | 3-01 |
| Schema versioning | Enables future data migrations without breaking old saves | 3-01 |
| Registry lookup in from_dict | FurniturePlacement restores resource reference by ID | 3-01 |
| Cyan furniture highlight | Color(0.2, 0.8, 1.0) distinct from room yellow | 4-01 |
| 44px minimum tap target | Mobile accessibility guideline for touch targets | 4-01 |
| FurnitureEditLayer at layer 0 | Same z-order as SelectionHighlightLayer | 4-01 |

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
- Serialization: Use direct array assignment in from_dict() to avoid placement_changed signals
- Furniture selection: Create Area2D per furniture piece, expand small footprints to 44x44 min tap target

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
- [x] Verify Phase 2 complete (5/5 must-haves)
- [x] Execute 03-01-PLAN.md: RoomInstance serialization
- [ ] Execute 03-02-PLAN.md: SaveManager implementation
- [ ] Execute 03-03-PLAN.md: SaveLoad integration
- [ ] Execute 03-04-PLAN.md: Auto-save on room changes
- [x] Execute 04-01-PLAN.md: FurnitureEditController
- [ ] Execute 04-02-PLAN.md: List Selection UI
- [ ] Consider spike planning for Phase 8 (Room Resize) due to HIGH complexity flag

---

## Session Continuity

### What Was Done

- Executed 04-01-PLAN.md: FurnitureEditController and highlight
- Created FurnitureEditController with Area2D tap detection per furniture piece
- Created FurnitureSelectionHighlight with cyan color for visual feedback
- Integrated into Main.gd with edit_furniture_pressed signal connection
- Commits: b0c3012, f769fdc, 3384d86

### What's Next

1. Execute 04-02-PLAN.md: List Selection UI (if exists)
2. Complete Phase 3 remaining plans (SaveManager, SaveLoad, Auto-save)
3. Continue to Phase 5 (Furniture Editing Operations)

### Context for Next Session

Phase 4 Plan 1 complete. Furniture selection infrastructure ready:
- `FurnitureEditController` - Manages furniture edit mode, tap detection on furniture
- `FurnitureSelectionHighlight` - Draws cyan highlight on selected furniture
- Entry flow: Room selected -> Edit Furniture button -> furniture edit mode

Key files created:
- `Scripts/room_editing/FurnitureEditController.gd` - Selection controller with signals
- `Scripts/room_editing/FurnitureSelectionHighlight.gd` - Visual highlight
- `Scripts/Main.gd` - Updated with furniture editing integration

Selection flow:
1. User taps room -> yellow highlight + RoomEditMenu
2. User taps "Edit Furniture" -> enters furniture edit mode
3. User taps furniture -> cyan highlight on that piece
4. User taps empty space -> deselect furniture

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-23*
