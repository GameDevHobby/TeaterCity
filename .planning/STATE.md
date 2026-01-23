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
**Status:** In progress
**Last activity:** 2026-01-23 - Completed 03-03-PLAN.md (SaveLoad Integration)

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

- Executed 03-03-PLAN.md: SaveLoad Integration
- Added load-on-startup to RoomManager via _load_saved_rooms()
- Added debounced auto-save with 5-second timer
- Added app suspension save (NOTIFICATION_WM_GO_BACKGROUND/CLOSE_REQUEST)
- Commits: ca4d30b, 2f40bf2, 78884a5

### What's Next

1. Execute 03-04-PLAN.md: Auto-save on room changes (if exists, or may be complete)
2. Continue to Phase 5 (Furniture Editing Operations)
3. Consider spike planning for Phase 8 (Room Resize)

### Context for Next Session

Phase 3 Plan 3 complete. Persistence integration is ready:
- Rooms load from `user://saves/rooms.json` on game start
- New rooms auto-save after 5-second debounce
- placement_changed signal triggers auto-save
- Mobile app backgrounding triggers immediate save

Key file modified:
- `Scripts/RoomManager.gd` - Auto-save and load-on-startup

Save flow:
1. Game starts -> _load_saved_rooms() -> RoomSerializer.load_rooms()
2. Room built -> register_room() -> _schedule_save() -> 5s debounce -> save
3. Furniture added -> placement_changed -> _on_room_changed() -> _schedule_save()
4. App background -> _notification() -> immediate save

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-23 (03-03-PLAN.md complete)*
