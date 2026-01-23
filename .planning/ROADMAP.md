# Roadmap: TheaterCity Room Editor

**Milestone:** Room Editor
**Created:** 2026-01-21
**Depth:** Comprehensive
**Coverage:** 29/29 requirements mapped

---

## Overview

This roadmap transforms the existing room building system into a full room editor with selection, editing, furniture management, and persistence. Phases are derived from natural delivery boundaries in the requirements, with research recommendations incorporated. Room resize is included per PROJECT.md but flagged as high complexity requiring careful planning.

---

## Phase Structure

### Phase 1: Room Manager Foundation

**Goal:** Establish the infrastructure to track completed rooms and enable selection.

**Dependencies:** None (foundation phase)

**Requirements:**
- SEL-01: Player can tap a room to select it
- SEL-02: Selected room shows visual highlight

**Success Criteria:**
1. Tapping anywhere in a completed room selects that room
2. Selected room displays visible highlight (outline or tint)
3. Tapping outside any room deselects current selection
4. Touch input does not conflict with camera pan (toggle camera.enable_pinch_pan)

**Plans:** 4 plans

Plans:
- [x] 01-01-PLAN.md - RoomManager singleton with Area2D selection and tap detection
- [x] 01-02-PLAN.md - Selection highlight visual and system integration
- [x] 01-03-PLAN.md - Desktop mouse input fix (gap closure)
- [x] 01-04-PLAN.md - RoomBuildUI mouse filter fix (gap closure)

**Risk Flags:**
- MEDIUM: Touch conflicts with camera pan - must toggle camera input during edit mode
- LOW: Well-documented selection patterns in research

**Research Notes:**
- Create RoomManager autoload singleton to track completed rooms
- Use Area2D + CollisionShape2D for room hit detection
- Tap detection: distinguish tap from drag using threshold (20px, 300ms)

---

### Phase 2: Room Menu & Edit Mode Entry

**Goal:** Players can access room editing options through a contextual menu.

**Dependencies:** Phase 1 (room selection required)

**Requirements:**
- SEL-03: Room menu appears with options: Edit Furniture, Edit Room, [Room-type placeholder]
- SEL-04: Room-type-specific placeholder button for future features

**Success Criteria:**
1. Menu appears near selected room after selection
2. Menu displays three options: Edit Furniture, Edit Room, placeholder
3. Placeholder button shows room-type-specific label (e.g., "Theater Schedule")
4. Menu dismisses when tapping outside or selecting another room

**Plans:** 1 plan

Plans:
- [x] 02-01-PLAN.md - RoomEditMenu Control with contextual buttons and positioning

**Risk Flags:**
- LOW: Standard UI pattern

**Research Notes:**
- Use PanelContainer (not PopupMenu) for custom-styled buttons
- Position menu using IsometricMath.tile_to_screen() with CanvasLayer layer=1
- Manual dismiss handling via _unhandled_input (both touch and mouse)

---

### Phase 3: Persistence Infrastructure

**Goal:** Room data survives game quit/restart with safe save mechanics.

**Dependencies:** Phase 1 (RoomManager must exist to track rooms)

**Requirements:**
- PER-01: Rooms auto-save on changes
- PER-02: Furniture placements auto-save on changes
- PER-03: Room settings persist through game quit/restart
- PER-04: Data stored in user:// JSON file

**Success Criteria:**
1. Closing and reopening the game restores all rooms to their last saved state
2. Room positions, doors, and furniture all persist correctly
3. Save file exists at user://saves/rooms.json
4. Corrupted save file does not crash the game (graceful fallback)

**Plans:** 4 plans

Plans:
- [x] 03-01-PLAN.md - RoomInstance serialization (to_dict/from_dict methods)
- [x] 03-02-PLAN.md - RoomSerializer atomic JSON file I/O
- [x] 03-03-PLAN.md - Auto-save integration and load on startup
- [x] 03-04-PLAN.md - Visual restoration and human verification

**Risk Flags:**
- HIGH: Save file corruption on mobile - use atomic writes (temp file + rename)
- MEDIUM: Coordinate confusion between tile/world positions - always store Vector2i tile coords
- MEDIUM: Save file versioning for future schema changes

**Research Notes:**
- Research recommends store_var() binary format, PROJECT.md specifies JSON
- Implement RoomInstance.to_dict() / from_dict() for either format
- Atomic save pattern: write to .tmp, verify, rename to final
- Auto-save with 5s debounce on changes, also on app suspension

---

### Phase 4: Furniture Selection

**Goal:** Players can select furniture for editing through multiple input methods.

**Dependencies:** Phase 2 (edit mode entry required)

**Requirements:**
- FUR-01: Player can select furniture by tapping directly in room
- FUR-02: Player can select furniture from list panel

**Success Criteria:**
1. Tapping furniture in a room selects that furniture piece
2. Selected furniture shows visual highlight (distinct from room highlight)
3. Furniture list panel displays all furniture in selected room
4. Selecting from list highlights corresponding furniture in room

**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md - FurnitureEditController with tap selection and cyan highlight
- [x] 04-02-PLAN.md - FurnitureListPanel with bi-directional selection sync

**Risk Flags:**
- MEDIUM: Touch target size for small furniture - ensure minimum tap area
- LOW: Standard selection pattern

**Research Notes:**
- Dual selection (tap + list) improves accessibility and discoverability
- Track selected furniture in FurnitureEditController state

---

### Phase 5: Furniture Editing Operations

**Goal:** Players can move, add, and delete furniture within rooms.

**Dependencies:** Phase 4 (furniture selection required), Phase 3 (persistence for saving changes)

**Requirements:**
- FUR-03: Player can move furniture to new position
- FUR-04: Player can add new furniture (within room type constraints)
- FUR-05: Player can delete furniture (respecting room type minimum requirements)
- OVR-02: Room resize cannot encroach on furniture from other rooms
- OVR-03: Validation prevents invalid room/furniture configurations

**Success Criteria:**
1. Dragging furniture moves it with grid snap and collision preview
2. Adding furniture shows valid/invalid placement feedback before confirming
3. Delete is blocked with error message when furniture is required by room type
4. Furniture cannot overlap with other furniture or walls
5. Changes auto-save after each operation completes

**Plans:** 6 plans

Plans:
- [ ] 05-01-PLAN.md - Drag-to-move with tap detection and collision validation
- [ ] 05-02-PLAN.md - Move drag preview visual feedback
- [ ] 05-03-PLAN.md - Delete operation with room type validation
- [ ] 05-04-PLAN.md - Add operation with furniture picker and placement mode
- [ ] 05-05-PLAN.md - Add placement preview and RoomBuildController accessors
- [ ] 05-06-PLAN.md - Human verification of all furniture operations

**Risk Flags:**
- MEDIUM: Visual node cleanup on delete - must call queue_free() on furniture nodes
- MEDIUM: Room type constraint validation - check min required furniture before delete
- MEDIUM: Mobile drag gesture patterns - research drag-and-drop on touch

**Research Notes:**
- Reuse existing FurnitureOperation and CollisionOperation for validation
- Track visual_node reference in FurniturePlacement for cleanup
- Navigation mesh must update after furniture changes

---

### Phase 6: Door Editing

**Goal:** Players can add and remove doors from existing rooms.

**Dependencies:** Phase 2 (edit mode entry required), Phase 3 (persistence)

**Requirements:**
- DOOR-01: Player can add doors to room walls
- DOOR-02: Player can remove doors from room
- DOOR-03: Doors can only open to empty space (not into adjacent rooms)

**Success Criteria:**
1. Tapping a wall tile in edit mode shows add-door option if valid
2. Tapping an existing door shows remove-door option
3. Door placement blocked with error when adjacent tile is another room
4. Navigation mesh updates after door add/remove

**Estimated Tasks:** 8-12

**Risk Flags:**
- MEDIUM: Navigation mesh update after door changes - must call navigation update
- LOW: Reuses existing DoorOperation validation logic

**Research Notes:**
- DoorOperation.is_valid_door_position() handles wall adjacency checks
- New check needed: adjacent tile occupancy (must be empty or hallway)

---

### Phase 7: Room Deletion

**Goal:** Players can remove unwanted rooms with proper cleanup.

**Dependencies:** Phase 3 (persistence), Phase 6 (door handling for wall healing)

**Requirements:**
- EDIT-04: Player can delete a room
- EDIT-05: Walls heal (fill in) at door locations when room deleted

**Success Criteria:**
1. Delete room option available in room menu with confirmation dialog
2. Deleting room removes all walls, doors, and furniture from tilemap
3. Adjacent rooms maintain their walls (shared boundaries preserved)
4. Deleted room unregistered from navigation targets
5. Patrons do not attempt to navigate to deleted room

**Estimated Tasks:** 10-14

**Risk Flags:**
- HIGH: Navigation targets not unregistered - must call Targets.unregister_room()
- HIGH: Navigation mesh not updated - patrons walk through deleted areas
- MEDIUM: Shared wall handling - adjacent rooms must not lose their walls

**Research Notes:**
- Create DeletionOperation for cleanup logic
- Wall healing: replace door tiles with wall tiles
- Sequence: delete furniture nodes -> delete tilemap cells -> update navigation -> unregister from Targets

---

### Phase 8: Room Resize (Complex)

**Goal:** Players can resize existing rooms by adjusting walls.

**Dependencies:** Phase 7 (room deletion for wall handling), Phase 5 (furniture validation)

**Requirements:**
- EDIT-01: Player can resize room by adjusting walls
- EDIT-02: Resize blocked if furniture would be invalidated
- EDIT-03: Doors reset on resize, player re-places them
- OVR-01: Adjacent rooms can share wall boundaries

**Success Criteria:**
1. Drag handles appear on room corners/edges when in resize mode
2. Dragging handle shows preview of new room size
3. Resize blocked with error message when furniture would be outside new bounds
4. After successful resize, all doors are removed and player enters door placement mode
5. Shared walls with adjacent rooms are preserved correctly

**Estimated Tasks:** 16-24

**Risk Flags:**
- HIGH: Research flags as HIGH complexity - consider additional spike planning
- HIGH: Furniture invalidation logic - must check all furniture fits in new bounds
- HIGH: Shared wall handling during resize - complex edge cases
- MEDIUM: UI/UX for drag handles on mobile touch

**Research Notes:**
- Research recommends deferring resize to post-MVP due to complexity
- PROJECT.md lists as core requirement - included but flagged
- Consider: resize = delete + rebuild with preserved furniture positions?
- Must validate new size against RoomTypeResource min/max constraints
- Door reset simplifies the problem significantly

---

### Phase 9: Admin Menu & Feature Flags

**Goal:** Admin tools for save management, gated behind feature flags.

**Dependencies:** Phase 3 (persistence must exist to manage)

**Requirements:**
- PER-05: Admin menu for save management (revert, reset) - feature-flagged

**Success Criteria:**
1. Admin menu only appears when feature flag is enabled
2. Revert option restores last saved state (discards unsaved changes)
3. Reset option clears all room data (with confirmation)
4. Feature flag can be toggled without code changes (config file or build flag)

**Estimated Tasks:** 6-10

**Risk Flags:**
- LOW: Standard feature flag pattern
- LOW: Simple UI with destructive action confirmations

**Research Notes:**
- Keep admin tools out of production builds easily
- Useful during development and for QA testing

---

### Phase 10: Testing & Verification

**Goal:** Comprehensive test coverage for all room editor features.

**Dependencies:** All previous phases (tests verify completed features)

**Requirements:**
- TEST-01: Unit tests for room editing operations
- TEST-02: Unit tests for furniture management operations
- TEST-03: Unit tests for persistence layer
- TEST-04: Integration tests for edit workflows

**Success Criteria:**
1. Unit tests cover all Operation classes (WallOperation, DoorOperation, FurnitureOperation, DeletionOperation)
2. Unit tests cover RoomSerializer save/load with edge cases (empty, corrupted, large)
3. Integration tests simulate full edit workflows (select -> edit -> save -> reload)
4. All tests pass on CI before milestone completion

**Estimated Tasks:** 14-20

**Risk Flags:**
- MEDIUM: Integration test complexity - may need test fixtures for room state
- LOW: GUT framework already in use

**Research Notes:**
- Follow existing test patterns in codebase
- Mock file system for persistence tests
- Test mobile-specific scenarios (app suspension during save)

---

## Progress

| Phase | Name | Status | Requirements |
|-------|------|--------|--------------|
| 1 | Room Manager Foundation | Complete | SEL-01, SEL-02 |
| 2 | Room Menu & Edit Mode Entry | Complete | SEL-03, SEL-04 |
| 3 | Persistence Infrastructure | Complete | PER-01, PER-02, PER-03, PER-04 |
| 4 | Furniture Selection | Complete | FUR-01, FUR-02 |
| 5 | Furniture Editing Operations | Planned | FUR-03, FUR-04, FUR-05, OVR-02, OVR-03 |
| 6 | Door Editing | Pending | DOOR-01, DOOR-02, DOOR-03 |
| 7 | Room Deletion | Pending | EDIT-04, EDIT-05 |
| 8 | Room Resize (Complex) | Pending | EDIT-01, EDIT-02, EDIT-03, OVR-01 |
| 9 | Admin Menu & Feature Flags | Pending | PER-05 |
| 10 | Testing & Verification | Pending | TEST-01, TEST-02, TEST-03, TEST-04 |

---

## Dependency Graph

```
Phase 1 (Foundation)
    |
    v
Phase 2 (Menu/Edit Mode) -----> Phase 4 (Furniture Selection) -----> Phase 5 (Furniture Editing)
    |                                                                        |
    v                                                                        v
Phase 3 (Persistence) ---------> Phase 6 (Door Editing) ---------> Phase 7 (Room Deletion)
    |                                                                        |
    v                                                                        v
Phase 9 (Admin Menu)                                              Phase 8 (Room Resize - Complex)
                                                                             |
                                                                             v
                                                                  Phase 10 (Testing)
```

**Critical Path:** 1 -> 2 -> 4 -> 5 -> 7 -> 8 -> 10

**Parallel Opportunities:**
- Phase 3 can run parallel to Phase 4 (both depend only on Phase 1-2)
- Phase 6 can run parallel to Phase 5 (both are edit operations)
- Phase 9 can run any time after Phase 3

---

## Risk Summary

| Risk Level | Phase | Risk | Mitigation |
|------------|-------|------|------------|
| HIGH | 8 | Room resize complexity | Consider spike planning or simplified approach |
| HIGH | 7 | Navigation targets not unregistered | Explicit Targets.unregister_room() call |
| HIGH | 7 | Navigation mesh not updated | Call navigation update after deletion |
| HIGH | 3 | Save file corruption | Atomic writes with temp file + rename |
| MEDIUM | 1 | Touch conflicts with camera | Toggle camera input during edit mode |
| MEDIUM | 5 | Visual node cleanup on delete | Track and queue_free() furniture nodes |
| MEDIUM | 3 | Save file versioning | Plan schema migration strategy |

---

## Research Integration

**Incorporated from research/SUMMARY.md:**
- Phase ordering follows research recommendation (Selection -> Persistence -> Furniture -> Deletion)
- RoomManager singleton pattern adopted
- RoomEditController state machine approach adopted
- Touch conflict mitigation (camera toggle)
- Atomic save pattern for corruption prevention
- Navigation update requirements identified

**Deviations from research:**
- Room resize included (research recommended deferring, PROJECT.md requires it)
- JSON format per PROJECT.md (research recommended store_var() binary)
- Testing phase added (not in research phases but in PROJECT.md requirements)

---

*Roadmap created: 2026-01-21*
*Phase 3 planned: 2026-01-22*
*Phase 4 planned: 2026-01-22*
*Phase 5 planned: 2026-01-23*
