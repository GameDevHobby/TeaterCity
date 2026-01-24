# Project State: TheaterCity Room Editor

**Milestone:** Room Editor
**Last Updated:** 2026-01-24

---

## Project Reference

**Core Value:** Players can modify their theater layout after initial construction and have those changes saved permanently.

**Current Focus:** Phase 5 in progress - Furniture Editing Operations

**Key Files:**
- `.planning/PROJECT.md` - Requirements and constraints
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/research/SUMMARY.md` - Research findings and risk mitigation
- `.planning/codebase/ARCHITECTURE.md` - Existing architecture to extend

---

## Current Position

**Phase:** 5 of 10 (Furniture Editing Operations)
**Plan:** 5 of 6 complete
**Status:** In progress
**Last activity:** 2026-01-24 - Completed 05-05-PLAN.md (Placement preview visual feedback)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [X] Room Menu & Edit Mode Entry (1/1 plans) COMPLETE
Phase  3: [>] Persistence Infrastructure (3/4 plans)
Phase  4: [X] Furniture Selection (2/2 plans) COMPLETE
Phase  5: [>] Furniture Editing Operations (5/6 plans)
Phase  6: [ ] Door Editing
Phase  7: [ ] Room Deletion
Phase  8: [ ] Room Resize (Complex)
Phase  9: [ ] Admin Menu & Feature Flags
Phase 10: [ ] Testing & Verification
```

**Milestone Progress:** 4/10 phases complete (40%)

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Plans Executed | 13 |
| Plans Passed | 13 |
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
| Temporary removal during validation | Avoid self-collision when validating drag position | 5-01 |
| visual_node reference in FurniturePlacement | Enable efficient position updates without tree traversal | 5-01 |
| Validate against room type requirements | Prevent deleting required furniture at minimum count | 5-03 |
| Recreate furniture areas after deletion | Deletion shifts array indices, requiring Area2D rebuild | 5-03 |
| Inline error messages in list panel | Less disruptive than modals for validation failures | 5-03 |
| Drag preview replaces selection highlight | Clearer feedback - users see landing position, not current | 5-02 |
| Original position shown as gray ghost | Provides reference for how far furniture has moved | 5-02 |
| Green valid, red invalid drag preview | Universal color convention for success/error states | 5-02 |
| Placement mode as separate state | Independent from selection/drag, has own input handling | 5-04 |
| Picker shows room type constraints | Only allowed/required furniture for current room type | 5-04 |
| Visual creation delegated via signal | Controller emits furniture_added, Main creates visual node | 5-04 |
| Placement preview priority rendering | Checked before selection/drag modes in _draw() | 5-05 |
| Reuse drag colors for placement | Green valid, red invalid for consistency | 5-05 |

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
- Drag detection: InputEventMouseMotion (desktop) and InputEventScreenDrag (mobile) with 20px threshold
- Drag validation: Temporarily remove furniture from array to avoid self-collision during can_place_furniture check
- Visual node updates: FurniturePlacement.visual_node reference enables direct position updates during drag
- Delete validation: ValidationOperation.can_delete_furniture() checks room type requirements before deletion
- Furniture cleanup: queue_free() both visual_node and Area2D, recreate all areas with updated indices
- Delete UI: Button shows when selected, error label shows inline for validation failures
- Drag preview: Signal-driven rendering via furniture_drag_preview, state-based _draw() branching
- Preview rendering: Multi-layer (access tiles → footprint → original ghost), color-coded validity
- Placement mode: Separate state from drag, clears selection on entry, validates with CollisionOperation
- Furniture picker: Positioned above list panel, populated from room type constraints
- Add workflow: Add button → picker → select furniture → placement mode → tap to place → auto-save
- Placement preview: Green/red highlight follows cursor during placement mode, priority in _draw() branching
- Multi-mode highlight: Single FurnitureSelectionHighlight handles selection, drag, and placement rendering

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
- [x] Execute 05-01-PLAN.md: Drag-to-move functionality
- [x] Execute 05-02-PLAN.md: Drag preview visual feedback
- [x] Execute 05-03-PLAN.md: Furniture deletion
- [x] Execute 05-04-PLAN.md: Furniture add operation
- [x] Execute 05-05-PLAN.md: Placement preview visual feedback
- [ ] Execute 05-06-PLAN.md: Furniture rotation (if exists)
- [ ] Complete Phase 5: Furniture Editing Operations
- [ ] Consider spike planning for Phase 8 (Room Resize) due to HIGH complexity flag

---

## Session Continuity

### What Was Done

- Executed 05-05-PLAN.md: Placement preview visual feedback
- Added placement mode state to FurnitureSelectionHighlight (_in_placement_mode flag)
- Connected placement_mode_entered/exited/preview_updated signals
- Implemented _draw_placement_preview with green/red validity colors
- Verified RoomBuildController accessor methods exist from 05-04
- Verified Main.gd furniture visual creation wiring
- Commits: a9aef7b, ca6dbad

### What's Next

1. Check if 05-06-PLAN.md exists (furniture rotation)
2. Complete Phase 5: Furniture Editing Operations
3. Execute Phase 6: Door Editing
4. Consider completing Phase 3 remaining plans (03-04 auto-save if exists)

### Context for Next Session

Phase 5 Plan 05 complete. Furniture add operation has full visual feedback:
- Placement mode shows ghost preview at cursor position
- Valid positions show green preview, invalid show red
- Preview follows cursor via placement_preview_updated signal
- FurnitureSelectionHighlight handles three rendering modes: selection (cyan), drag (green/red with ghost), placement (green/red)
- Tapping valid position places furniture with correct visual node
- New furniture immediately appears in list and is selectable

Complete furniture editing flow:
1. Select furniture → cyan highlight with access tiles
2. Drag furniture → green/red preview at drop position, gray ghost at original
3. Delete furniture → validation against room type, inline error if blocked
4. Add furniture → picker with room type constraints → placement mode → green/red preview → place and auto-save

Key files in Phase 5:
- `Scripts/room_editing/FurnitureEditController.gd` - Selection, drag, placement, delete state management
- `Scripts/room_editing/FurnitureSelectionHighlight.gd` - Multi-mode visual feedback rendering
- `Scripts/room_editing/FurnitureListPanel.gd` - List UI with Add/Delete buttons, picker overlay
- `Scripts/Main.gd` - Signal wiring, visual node creation for placed furniture

Check for 05-06 plan or proceed to Phase 6 (Door Editing).

---

*State initialized: 2026-01-21*
*Last updated: 2026-01-24 (05-05-PLAN.md complete)*
