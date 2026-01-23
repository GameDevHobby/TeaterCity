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
**Plan:** 2 of 2 complete
**Status:** Phase complete
**Last activity:** 2026-01-23 - Completed 04-02-PLAN.md (FurnitureListPanel)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [X] Room Menu & Edit Mode Entry (1/1 plans) COMPLETE
Phase  3: [>] Persistence Infrastructure (3/4 plans)
Phase  4: [X] Furniture Selection (2/2 plans) COMPLETE
Phase  5: [ ] Furniture Editing Operations
Phase  6: [ ] Door Editing
Phase  7: [ ] Room Deletion
Phase  8: [ ] Room Resize (Complex)
Phase  9: [ ] Admin Menu & Feature Flags
Phase 10: [ ] Testing & Verification
```

**Milestone Progress:** 3/10 phases complete (30%)

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Plans Executed | 8 |
| Plans Passed | 8 |
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
| Atomic write pattern | Write to .tmp, verify JSON, rename to final | 3-02 |
| Static serializer methods | RoomSerializer is stateless helper, not singleton | 3-02 |
| Cyan furniture highlight | Color(0.2, 0.8, 1.0) distinct from room yellow | 4-01 |
| 44px minimum tap target | Mobile accessibility guideline for touch targets | 4-01 |
| FurnitureEditLayer at layer 0 | Same z-order as SelectionHighlightLayer | 4-01 |
| 5-second save debounce | Balances responsiveness with disk I/O efficiency | 3-03 |
| Immediate save on app suspend | Mobile apps can be killed without warning | 3-03 |
| List panel bottom-left position | Clear of room view, accessible for right-handed users | 4-02 |
| Cyan accent for list selection | Matches furniture highlight color in room view | 4-02 |
| Bi-directional signal sync | List and room tap selection stay synchronized | 4-02 |

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
- Auto-save: 5-second debounce timer consolidates rapid changes into single save
- Save on suspend: Handle NOTIFICATION_WM_GO_BACKGROUND for mobile, NOTIFICATION_WM_CLOSE_REQUEST for desktop
- List selection: ScrollContainer with dynamic height (max 200px) for furniture item overflow
- Bi-directional sync: List click -> select_furniture() -> signal; Room tap -> signal -> select_item()

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
- [x] Execute 03-02-PLAN.md: RoomSerializer atomic file I/O
- [x] Execute 03-03-PLAN.md: SaveLoad integration
- [ ] Execute 03-04-PLAN.md: Auto-save on room changes
- [x] Execute 04-01-PLAN.md: FurnitureEditController
- [x] Execute 04-02-PLAN.md: List Selection UI
- [ ] Consider spike planning for Phase 8 (Room Resize) due to HIGH complexity flag

---

## Session Continuity

### What Was Done

- Executed 04-02-PLAN.md: FurnitureListPanel with bi-directional sync
- Created FurnitureListPanel with scrollable list of furniture items
- Added select_furniture() to FurnitureEditController for list-based selection
- Integrated list panel into Main.gd with signal wiring
- Commits: 0572996, 540b8b0

### What's Next

1. Complete Phase 3 remaining plans (03-04 if exists)
2. Continue to Phase 5 (Furniture Editing Operations)
3. Consider spike planning for Phase 8 (Room Resize)

### Context for Next Session

Phase 4 complete. Furniture selection infrastructure ready:
- FurnitureEditController manages selection state and tap detection
- FurnitureListPanel provides alternative list-based selection
- FurnitureSelectionHighlight draws cyan highlight on selected furniture

Key files created/modified:
- `Scripts/room_editing/FurnitureListPanel.gd` - List panel UI
- `Scripts/room_editing/FurnitureEditController.gd` - Added select_furniture()
- `Scripts/Main.gd` - Panel creation and signal wiring

Selection flow:
1. User taps room -> yellow highlight + RoomEditMenu
2. User taps "Edit Furniture" -> furniture edit mode, list panel shows
3. User taps furniture in room OR clicks item in list -> cyan highlight (bi-directional sync)
4. User clicks "Done" -> exit furniture edit mode, list hides

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-23 (04-02-PLAN.md complete)*
