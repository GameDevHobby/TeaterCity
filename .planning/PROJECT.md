# TheaterCity Room Editor

## What This Is

A room editor for TheaterCity, a mobile theater/venue simulation game built in Godot 4.5. Players can select, resize, and delete rooms, manage furniture (add, move, delete), and have their changes persist across game sessions. The editor extends the existing room building system with full editing capabilities and data persistence.

## Core Value

Players can modify their theater layout after initial construction and have those changes saved permanently.

## Requirements

### Validated

<!-- Shipped and confirmed working -->

**Pre-existing (before v1.0):**
- [x] Room building workflow (draw box -> place doors -> place furniture -> complete)
- [x] Room type definitions with size constraints and furniture requirements
- [x] Furniture placement with collision detection and access tile validation
- [x] Room validation against type constraints (door count, required furniture)
- [x] Patron navigation with pathfinding that updates when rooms change
- [x] Isometric coordinate system with screen<->tile conversion
- [x] Mobile-optimized touch UI with PinchPanCamera
- [x] Room type and furniture registries with lazy loading

**v1.0 Room Editor:**
- [x] SEL-01: Player can tap a room to select it -- v1.0
- [x] SEL-02: Selected room shows visual highlight -- v1.0
- [x] SEL-03: Room menu appears with options: Edit Furniture, Edit Room, [Room-type placeholder] -- v1.0
- [x] SEL-04: Room-type-specific placeholder button for future features -- v1.0
- [x] EDIT-01: Player can resize room by adjusting walls -- v1.0
- [x] EDIT-02: Resize blocked if furniture would be invalidated -- v1.0
- [x] EDIT-03: Doors reset on resize, player re-places them -- v1.0
- [x] EDIT-04: Player can delete a room -- v1.0
- [x] EDIT-05: Walls heal (fill in) at door locations when room deleted -- v1.0
- [x] DOOR-01: Player can add doors to room walls -- v1.0
- [x] DOOR-02: Player can remove doors from room -- v1.0
- [x] DOOR-03: Doors can only open to empty space (not into adjacent rooms) -- v1.0
- [x] FUR-01: Player can select furniture by tapping directly in room -- v1.0
- [x] FUR-02: Player can select furniture from list panel -- v1.0
- [x] FUR-03: Player can move furniture to new position -- v1.0
- [x] FUR-04: Player can add new furniture (within room type constraints) -- v1.0
- [x] FUR-05: Player can delete furniture (respecting room type minimum requirements) -- v1.0
- [x] OVR-01: Adjacent rooms can share wall boundaries -- v1.0
- [x] OVR-02: Room resize cannot encroach on furniture from other rooms -- v1.0
- [x] OVR-03: Validation prevents invalid room/furniture configurations -- v1.0
- [x] PER-01: Rooms auto-save on changes -- v1.0
- [x] PER-02: Furniture placements auto-save on changes -- v1.0
- [x] PER-03: Room settings persist through game quit/restart -- v1.0
- [x] PER-04: Data stored in user:// JSON file -- v1.0
- [x] PER-05: Admin menu for save management (reset) -- v1.0
- [x] TEST-01: Unit tests for room editing operations -- v1.0
- [x] TEST-02: Unit tests for furniture management operations -- v1.0
- [x] TEST-03: Unit tests for persistence layer -- v1.0
- [x] TEST-04: Integration tests for edit workflows -- v1.0

### Active

<!-- Future scope. Not yet started. -->

(None - next milestone TBD)

### Out of Scope

- Cloud sync / online saves -- local device only for v1
- Undo/redo stack -- admin reset is sufficient for now
- Room-type-specific features (theater scheduling, etc.) -- placeholder only, implemented later
- Mouse/keyboard input -- touch-only mobile design
- Room rotation -- rooms stay axis-aligned

## Context

TheaterCity is an existing Godot 4.5 project with a working room building system. The codebase uses:
- Event-driven architecture with Godot signals
- Stateless operation classes (WallOperation, DoorOperation, CollisionOperation, etc.)
- RoomInstance data model with inner classes for DoorPlacement and FurniturePlacement
- Registry singletons for room types and furniture definitions
- GUT testing framework with existing test coverage

The room building flow currently creates rooms but doesn't support editing after completion. This milestone adds editing capabilities and data persistence.

Key existing files:
- `scripts/room_building/RoomBuildController.gd` -- workflow state machine
- `scripts/room_building/RoomBuildUI.gd` -- input handling and UI
- `scripts/storage/RoomInstance.gd` -- room data model
- `scripts/room_building/operations/` -- stateless operation classes

## Constraints

- **Platform**: Mobile-first (Android), touch-only UI, no mouse/keyboard
- **Tech stack**: Godot 4.5, GDScript, existing architecture patterns
- **UI consistency**: Must match existing pixel-art style and UI patterns from CLAUDE.md
- **Testing**: GUT framework, tests required for all new features
- **Data format**: user:// JSON file for persistence

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Block resize if furniture invalidated | Simpler UX than auto-moving furniture; prevents accidental data loss | ✓ Good - ResizeOperation validates furniture bounds before allowing resize |
| Reset doors on resize | Walls change shape, easier to re-place doors than auto-adjust | ✓ Good - room.doors.clear() on resize, user re-places doors |
| Doors to empty space only | Prevents confusing room-to-room connections; matches player mental model | ✓ Good - DoorOperation validates adjacent tile is not in another room |
| Auto-save with admin reset | Reduces friction vs explicit save; admin menu handles edge cases | ✓ Good - 5s debounce auto-save, admin reset clears all |
| Feature-flag admin menu | Keep admin tools out of production builds easily | ✓ Good - OS.has_feature("debug") + ProjectSettings flag |
| Both tap and list for furniture selection | Accessibility and discoverability; tap is faster, list helps find items | ✓ Good - FurnitureListPanel syncs with tap selection |
| Delete+rebuild for resize | Simpler than in-place wall modification; reuses existing WallOperation | ✓ Good - 80%+ code reuse from build system |
| Area2D for room selection | Handles isometric diamond shapes better than rect collision | ✓ Good - CollisionPolygon2D matches isometric footprint |
| Stateless operation classes | Easy to test, no side effects, follows existing patterns | ✓ Good - ResizeOperation, DeletionOperation, etc. all RefCounted |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEL-01 | Phase 1 | Complete |
| SEL-02 | Phase 1 | Complete |
| SEL-03 | Phase 2 | Complete |
| SEL-04 | Phase 2 | Complete |
| EDIT-01 | Phase 8 | Complete |
| EDIT-02 | Phase 8 | Complete |
| EDIT-03 | Phase 8 | Complete |
| EDIT-04 | Phase 7 | Complete |
| EDIT-05 | Phase 7 | Complete |
| DOOR-01 | Phase 6 | Complete |
| DOOR-02 | Phase 6 | Complete |
| DOOR-03 | Phase 6 | Complete |
| FUR-01 | Phase 4 | Complete |
| FUR-02 | Phase 4 | Complete |
| FUR-03 | Phase 5 | Complete |
| FUR-04 | Phase 5 | Complete |
| FUR-05 | Phase 5 | Complete |
| OVR-01 | Phase 8 | Complete |
| OVR-02 | Phase 5 | Complete |
| OVR-03 | Phase 5 | Complete |
| PER-01 | Phase 3 | Complete |
| PER-02 | Phase 3 | Complete |
| PER-03 | Phase 3 | Complete |
| PER-04 | Phase 3 | Complete |
| PER-05 | Phase 9 | Complete |
| TEST-01 | Phase 10 | Complete |
| TEST-02 | Phase 10 | Complete |
| TEST-03 | Phase 10 | Complete |
| TEST-04 | Phase 10 | Complete |

## Context

Shipped v1.0 with 9,905 LOC GDScript (6,223 scripts + 3,682 tests).
Tech stack: Godot 4.5, GDScript, GUT testing framework.
91 automated tests covering all room editor features.

---
*Last updated: 2026-02-08 after v1.0 milestone*
