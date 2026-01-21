# TheaterCity Room Editor

## What This Is

A room editor for TheaterCity, a mobile theater/venue simulation game built in Godot 4.5. Players can select, resize, and delete rooms, manage furniture (add, move, delete), and have their changes persist across game sessions. The editor extends the existing room building system with full editing capabilities and data persistence.

## Core Value

Players can modify their theater layout after initial construction and have those changes saved permanently.

## Requirements

### Validated

<!-- Shipped and confirmed working from existing codebase -->

- [x] Room building workflow (draw box -> place doors -> place furniture -> complete) -- existing
- [x] Room type definitions with size constraints and furniture requirements -- existing
- [x] Furniture placement with collision detection and access tile validation -- existing
- [x] Room validation against type constraints (door count, required furniture) -- existing
- [x] Patron navigation with pathfinding that updates when rooms change -- existing
- [x] Isometric coordinate system with screen<->tile conversion -- existing
- [x] Mobile-optimized touch UI with PinchPanCamera -- existing
- [x] Room type and furniture registries with lazy loading -- existing

### Active

<!-- Current scope. Building toward these. -->

**Room Selection & Menu:**
- [ ] SEL-01: Player can tap a room to select it
- [ ] SEL-02: Selected room shows visual highlight
- [ ] SEL-03: Room menu appears with options: Edit Furniture, Edit Room, [Room-type placeholder]
- [ ] SEL-04: Room-type-specific placeholder button for future features (e.g., theater scheduling)

**Room Editing:**
- [ ] EDIT-01: Player can resize room by adjusting walls
- [ ] EDIT-02: Resize blocked if furniture would be invalidated
- [ ] EDIT-03: Doors reset on resize, player re-places them
- [ ] EDIT-04: Player can delete a room
- [ ] EDIT-05: Walls heal (fill in) at door locations when room deleted

**Door Editing:**
- [ ] DOOR-01: Player can add doors to room walls
- [ ] DOOR-02: Player can remove doors from room
- [ ] DOOR-03: Doors can only open to empty space (not into adjacent rooms)

**Furniture Management:**
- [ ] FUR-01: Player can select furniture by tapping directly in room
- [ ] FUR-02: Player can select furniture from list panel
- [ ] FUR-03: Player can move furniture to new position
- [ ] FUR-04: Player can add new furniture (within room type constraints)
- [ ] FUR-05: Player can delete furniture (respecting room type minimum requirements)

**Overlap Prevention:**
- [ ] OVR-01: Adjacent rooms can share wall boundaries
- [ ] OVR-02: Room resize cannot encroach on furniture from other rooms
- [ ] OVR-03: Validation prevents invalid room/furniture configurations

**Persistence:**
- [ ] PER-01: Rooms auto-save on changes
- [ ] PER-02: Furniture placements auto-save on changes
- [ ] PER-03: Room settings persist through game quit/restart
- [ ] PER-04: Data stored in user:// JSON file
- [ ] PER-05: Admin menu for save management (revert, reset) -- feature-flagged

**Testing:**
- [ ] TEST-01: Unit tests for room editing operations
- [ ] TEST-02: Unit tests for furniture management operations
- [ ] TEST-03: Unit tests for persistence layer
- [ ] TEST-04: Integration tests for edit workflows

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
| Block resize if furniture invalidated | Simpler UX than auto-moving furniture; prevents accidental data loss | -- Pending |
| Reset doors on resize | Walls change shape, easier to re-place doors than auto-adjust | -- Pending |
| Doors to empty space only | Prevents confusing room-to-room connections; matches player mental model | -- Pending |
| Auto-save with admin reset | Reduces friction vs explicit save; admin menu handles edge cases | -- Pending |
| Feature-flag admin menu | Keep admin tools out of production builds easily | -- Pending |
| Both tap and list for furniture selection | Accessibility and discoverability; tap is faster, list helps find items | -- Pending |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| SEL-01 | Phase 1 | Pending |
| SEL-02 | Phase 1 | Pending |
| SEL-03 | Phase 2 | Pending |
| SEL-04 | Phase 2 | Pending |
| EDIT-01 | Phase 8 | Pending |
| EDIT-02 | Phase 8 | Pending |
| EDIT-03 | Phase 8 | Pending |
| EDIT-04 | Phase 7 | Pending |
| EDIT-05 | Phase 7 | Pending |
| DOOR-01 | Phase 6 | Pending |
| DOOR-02 | Phase 6 | Pending |
| DOOR-03 | Phase 6 | Pending |
| FUR-01 | Phase 4 | Pending |
| FUR-02 | Phase 4 | Pending |
| FUR-03 | Phase 5 | Pending |
| FUR-04 | Phase 5 | Pending |
| FUR-05 | Phase 5 | Pending |
| OVR-01 | Phase 8 | Pending |
| OVR-02 | Phase 5 | Pending |
| OVR-03 | Phase 5 | Pending |
| PER-01 | Phase 3 | Pending |
| PER-02 | Phase 3 | Pending |
| PER-03 | Phase 3 | Pending |
| PER-04 | Phase 3 | Pending |
| PER-05 | Phase 9 | Pending |
| TEST-01 | Phase 10 | Pending |
| TEST-02 | Phase 10 | Pending |
| TEST-03 | Phase 10 | Pending |
| TEST-04 | Phase 10 | Pending |

---
*Last updated: 2026-01-21 after roadmap creation*
