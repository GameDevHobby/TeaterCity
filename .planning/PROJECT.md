# TheaterCity Room Editor

## What This Is

A room editor for TheaterCity, a mobile theater/venue simulation game built in Godot 4.5. Players can select, resize, and delete rooms, manage furniture (add, move, delete), and have their changes persist across game sessions. The editor extends the existing room building system with full editing capabilities and data persistence.

## Core Value

Players can modify their theater layout after initial construction and have those changes saved permanently.

## Requirements

### Validated

<!-- Shipped and confirmed working from existing codebase -->

- ✓ Room building workflow (draw box → place doors → place furniture → complete) — existing
- ✓ Room type definitions with size constraints and furniture requirements — existing
- ✓ Furniture placement with collision detection and access tile validation — existing
- ✓ Room validation against type constraints (door count, required furniture) — existing
- ✓ Patron navigation with pathfinding that updates when rooms change — existing
- ✓ Isometric coordinate system with screen↔tile conversion — existing
- ✓ Mobile-optimized touch UI with PinchPanCamera — existing
- ✓ Room type and furniture registries with lazy loading — existing

### Active

<!-- Current scope. Building toward these. -->

**Room Selection & Menu:**
- [ ] Player can tap a room to select it
- [ ] Selected room shows visual highlight
- [ ] Room menu appears with options: Edit Furniture, Edit Room, [Room-type placeholder]
- [ ] Room-type-specific placeholder button for future features (e.g., theater scheduling)

**Room Editing:**
- [ ] Player can resize room by adjusting walls
- [ ] Resize blocked if furniture would be invalidated
- [ ] Doors reset on resize, player re-places them
- [ ] Player can delete a room
- [ ] Walls heal (fill in) at door locations when room deleted

**Door Editing:**
- [ ] Player can add doors to room walls
- [ ] Player can remove doors from room
- [ ] Doors can only open to empty space (not into adjacent rooms)

**Furniture Management:**
- [ ] Player can select furniture by tapping directly in room
- [ ] Player can select furniture from list panel
- [ ] Player can move furniture to new position
- [ ] Player can add new furniture (within room type constraints)
- [ ] Player can delete furniture (respecting room type minimum requirements)

**Overlap Prevention:**
- [ ] Adjacent rooms can share wall boundaries
- [ ] Room resize cannot encroach on furniture from other rooms
- [ ] Validation prevents invalid room/furniture configurations

**Persistence:**
- [ ] Rooms auto-save on changes
- [ ] Furniture placements auto-save on changes
- [ ] Room settings persist through game quit/restart
- [ ] Data stored in user:// JSON file
- [ ] Admin menu for save management (revert, reset) — feature-flagged

**Testing:**
- [ ] Unit tests for room editing operations
- [ ] Unit tests for furniture management operations
- [ ] Unit tests for persistence layer
- [ ] Integration tests for edit workflows

### Out of Scope

- Cloud sync / online saves — local device only for v1
- Undo/redo stack — admin reset is sufficient for now
- Room-type-specific features (theater scheduling, etc.) — placeholder only, implemented later
- Mouse/keyboard input — touch-only mobile design
- Room rotation — rooms stay axis-aligned

## Context

TheaterCity is an existing Godot 4.5 project with a working room building system. The codebase uses:
- Event-driven architecture with Godot signals
- Stateless operation classes (WallOperation, DoorOperation, CollisionOperation, etc.)
- RoomInstance data model with inner classes for DoorPlacement and FurniturePlacement
- Registry singletons for room types and furniture definitions
- GUT testing framework with existing test coverage

The room building flow currently creates rooms but doesn't support editing after completion. This milestone adds editing capabilities and data persistence.

Key existing files:
- `scripts/room_building/RoomBuildController.gd` — workflow state machine
- `scripts/room_building/RoomBuildUI.gd` — input handling and UI
- `scripts/storage/RoomInstance.gd` — room data model
- `scripts/room_building/operations/` — stateless operation classes

## Constraints

- **Platform**: Mobile-first (Android), touch-only UI, no mouse/keyboard
- **Tech stack**: Godot 4.5, GDScript, existing architecture patterns
- **UI consistency**: Must match existing pixel-art style and UI patterns from CLAUDE.md
- **Testing**: GUT framework, tests required for all new features
- **Data format**: user:// JSON file for persistence

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Block resize if furniture invalidated | Simpler UX than auto-moving furniture; prevents accidental data loss | — Pending |
| Reset doors on resize | Walls change shape, easier to re-place doors than auto-adjust | — Pending |
| Doors to empty space only | Prevents confusing room-to-room connections; matches player mental model | — Pending |
| Auto-save with admin reset | Reduces friction vs explicit save; admin menu handles edge cases | — Pending |
| Feature-flag admin menu | Keep admin tools out of production builds easily | — Pending |
| Both tap and list for furniture selection | Accessibility and discoverability; tap is faster, list helps find items | — Pending |

---
*Last updated: 2026-01-21 after initialization*
