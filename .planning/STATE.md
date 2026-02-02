# Project State: TheaterCity Room Editor

**Milestone:** Room Editor
**Last Updated:** 2026-02-02 (Phase 8 plan 03 complete)

---

## Project Reference

**Core Value:** Players can modify their theater layout after initial construction and have those changes saved permanently.

**Current Focus:** Phase 8 in progress - Room Resize (plan 03 complete)

**Key Files:**
- `.planning/PROJECT.md` - Requirements and constraints
- `.planning/ROADMAP.md` - Phase structure and success criteria
- `.planning/research/SUMMARY.md` - Research findings and risk mitigation
- `.planning/codebase/ARCHITECTURE.md` - Existing architecture to extend

---

## Current Position

**Phase:** 8 of 10 (Room Resize) - IN PROGRESS
**Plan:** 3 of 5 complete
**Status:** In progress
**Last activity:** 2026-02-02 - Completed 08-03-PLAN.md (RoomResizeHighlight)

**Progress:**
```
Phase  1: [X] Room Manager Foundation (4/4 plans) COMPLETE
Phase  2: [X] Room Menu & Edit Mode Entry (1/1 plans) COMPLETE
Phase  3: [X] Persistence Infrastructure (4/4 plans) COMPLETE
Phase  4: [X] Furniture Selection (2/2 plans) COMPLETE
Phase  5: [X] Furniture Editing Operations (6/6 plans) COMPLETE
Phase  6: [X] Door Editing (5/5 plans) COMPLETE
Phase  7: [X] Room Deletion (3/3 plans) COMPLETE
Phase  8: [>] Room Resize (3/5 plans) IN PROGRESS
Phase  9: [ ] Admin Menu & Feature Flags
Phase 10: [ ] Testing & Verification
```

**Milestone Progress:** 7/10 phases complete (70%)

---

## Performance Metrics

| Metric | Value |
|--------|-------|
| Plans Executed | 29 |
| Plans Passed | 29 |
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
| Position hash using x*100000+y | Simple unique key for Dictionary lookup of wall areas | 6-01 |
| DoorEditController follows FurnitureEditController | Consistent pattern for edit mode controllers | 6-01 |
| Dictionary return for door validation | {can_place: bool, reason: String} for structured error reporting | 6-02 |
| Adjacent room check for door placement | Outside tile checked via RoomManager.is_tile_in_another_room() | 6-02 |
| Minimum 1 door even if door_count_min=0 | Rooms need at least one door for patron access | 6-03 |
| Rebuild all wall terrain on door remove | Ensures proper tile transitions after door removal | 6-03 |
| Orange walls, purple doors in highlight | Distinct colors for available vs existing door positions | 6-04 |
| DoorEditLayer at layer 0 | Consistent with furniture edit layer for proper z-order | 6-04 |
| Navigation update after door change | NavigationOperation + Targets.notify_navigation_changed() | 6-04 |
| Shared wall detection via walls array | Check each wall position against all other rooms' walls arrays | 7-01 |
| Separate methods for each visual cleanup | Allows Main.gd to control deletion sequence | 7-01 |
| Terrain reconnection in delete_wall_visuals | Prevents orphaned wall rendering artifacts | 7-01 |
| Restore ground tiles for deleted walls | Maintains navigability through deleted room area | 7-01 |
| Confirmation dialog for room deletion | Prevents accidental deletion with clear warning | 7-02 |
| HSeparator before delete button | Visually distinguishes destructive action from other menu options | 7-02 |
| Tilemap scanning for exterior walls | Scan wall tilemap at startup to detect pre-existing scene walls | 7-03 |
| Exterior wall preservation | Exclude scene walls from deletion and door placement | 7-03 |
| Stop modifying floor tiles | Floor tiles should never be modified by furniture or deletion | 7-03 |
| Three-stage resize validation | Size constraints -> overlap -> furniture bounds (fast-fail order) | 8-01 |
| Both orientations for size validation | Allow swapped width/height for room type constraints | 8-01 |
| Furniture access tiles in resize validation | Check both footprint and access tiles against new walls | 8-01 |
| RoomResizeController signals-only pattern | Controller does not handle visual drawing, emits signals for highlight | 8-02 |
| door_placement_needed signal after resize | Triggers door re-placement workflow after successful resize | 8-02 |
| Separate BLOCKED_ACCESS color | Lighter orange for access tiles vs darker for furniture footprint | 8-03 |
| Access tiles drawn before footprint | Proper layering with footprint tiles on top | 8-03 |

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
- Preview rendering: Multi-layer (access tiles -> footprint -> original ghost), color-coded validity
- Placement mode: Separate state from drag, clears selection on entry, validates with CollisionOperation
- Furniture picker: Positioned above list panel, populated from room type constraints
- Add workflow: Add button -> picker -> select furniture -> placement mode -> tap to place -> auto-save
- Placement preview: Green/red highlight follows cursor during placement mode, priority in _draw() branching
- Multi-mode highlight: Single FurnitureSelectionHighlight handles selection, drag, and placement rendering
- Door edit mode: Create Area2D per wall tile, emit wall_tile_tapped with is_door boolean
- Tile occupancy: RoomManager.is_tile_in_another_room() for adjacent room validation
- Door add validation: can_place_door_edit() checks wall position, existing door, max count, adjacent room
- Door removal: Validate with can_remove_door(), emit door_removed, Main.gd calls remove_door_visuals()
- Wall restoration: remove_door_visuals() rebuilds all wall terrain via set_cells_terrain_connect()
- Door edit highlight: Orange (0.8,0.6,0.2) for walls, purple (0.6,0.2,0.8) for existing doors
- Door edit integration: Main.gd creates controller+highlight, connects signals, handles navigation updates
- Room unregistration: RoomManager.unregister_room() removes from _rooms, cleans Area2D, disconnects signals
- Deletion operations: DeletionOperation provides stateless helpers for shared wall detection and visual cleanup
- Exterior walls: Scanned from tilemap at startup using get_used_cells() and terrain set detection
- Coordinate conversion: IsometricMath.tilemap_to_ui_coords() for reverse coordinate conversion
- Door placement validation: Check exterior walls in both build mode and edit mode
- Resize validation: ResizeOperation.validate_resize() returns detailed result with blocked furniture list
- Resize execution: ResizeOperation.execute_resize() uses delete+rebuild pattern via DeletionOperation and WallOperation
- Resize controller: RoomResizeController follows box drawing input pattern from RoomBuildUI
- Resize state machine: IDLE and DRAWING states, live validation during drag via preview_updated signal
- Resize highlight: RoomResizeHighlight connects to controller signals, renders preview box and blocked furniture

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
- [x] Execute 03-04-PLAN.md: Visual restoration and verification
- [x] Execute 04-01-PLAN.md: FurnitureEditController
- [x] Execute 04-02-PLAN.md: List Selection UI
- [x] Execute 05-01-PLAN.md: Drag-to-move functionality
- [x] Execute 05-02-PLAN.md: Drag preview visual feedback
- [x] Execute 05-03-PLAN.md: Furniture deletion
- [x] Execute 05-04-PLAN.md: Furniture add operation
- [x] Execute 05-05-PLAN.md: Placement preview visual feedback
- [x] Execute 05-06-PLAN.md: Human verification of furniture operations
- [x] Execute 06-01-PLAN.md: Door editing infrastructure
- [x] Execute 06-02-PLAN.md: Door add operation
- [x] Execute 06-03-PLAN.md: Door removal operation
- [x] Execute 06-04-PLAN.md: Visual feedback and Main.gd integration
- [x] Execute 06-05-PLAN.md: Human verification of door editing
- [x] Execute 07-01-PLAN.md: Room deletion infrastructure
- [x] Execute 07-02-PLAN.md: Deletion UI and orchestration
- [x] Execute 07-03-PLAN.md: Human verification of room deletion
- [x] Execute 08-01-PLAN.md: ResizeOperation with validation logic
- [x] Execute 08-02-PLAN.md: RoomResizeController UI
- [x] Execute 08-03-PLAN.md: RoomResizeHighlight preview rendering
- [ ] Execute 08-04-PLAN.md: Main.gd integration
- [ ] Execute 08-05-PLAN.md: Human verification

---

## Session Continuity

### What Was Done

- Completed Phase 8 Plan 03: RoomResizeHighlight
- Created scripts/room_editing/RoomResizeHighlight.gd
- Valid/invalid color scheme (green/red) matching RoomBuildUI pattern
- Blocked furniture highlighting with orange (BLOCKED_FURNITURE) and lighter orange (BLOCKED_ACCESS)
- Signal-driven updates from RoomResizeController (preview_updated, resize_cancelled, resize_completed)
- Key commit: 063724d

### What's Next

1. Execute 08-04-PLAN.md: Main.gd integration
2. Execute 08-05-PLAN.md: Human verification

### Context for Next Session

Phase 8 Plan 03 complete. RoomResizeHighlight ready for integration:
- set_controller() connects to RoomResizeController signals
- _on_preview_updated() stores box and validation state, triggers redraw
- _draw_preview_box() renders interior, walls, and border in valid/invalid colors
- _draw_blocked_furniture() highlights furniture tiles in orange when invalid

Next: Plan 08-04 wires controller and highlight into Main.gd.

---

*State initialized: 2026-01-21*
*Last updated: 2026-02-02 (Phase 8 plan 03 complete)*
