# AGENTS.md

This is the single agent guidance file for this repository.
`CLAUDE.md` content is merged here and should not be maintained separately.

## Project Overview

TheaterCity is a Godot 4.5 mobile-focused simulation game. Core loop: players manage theater rooms, schedule movies, and watch patrons navigate/attend.

## Build and Run Commands

```bash
# Open editor
godot --editor --path .

# Run game
godot --path .

# Headless parse check
godot --headless --path . --quit
```

## Scene-First Node Creation Policy (Hard Rule)

If a node can exist at design time, it must be authored in a `.tscn` scene, not created in GDScript at runtime.

### Mandatory Rules

1. No runtime creation of fixed UI layouts.
2. No runtime creation of fixed gameplay hierarchies.
3. Stable persistent structures (panels, overlays, controllers, helper layers, collision helpers) must be scene-authored.
4. Runtime node creation is only for truly dynamic count (data-driven unknown size) or transient preview artifacts.
5. No exceptions for fixed hierarchies.

### Dynamic Content Rule (Important)

For dynamic collections, prefer scene instancing over `.new()`:

- Use `PackedScene.instantiate()` for dynamic repeated UI/game elements whenever possible.
- Pre-author a reusable row/item/button/card scene and instantiate per data element.
- Only use `Button.new()` (or other direct `.new()`) for trivial one-off dynamic controls when a scene brings no practical benefit.

This preserves visual/editor control while still supporting unknown runtime counts.

### Allowed Runtime Creation

- Data-driven variable-count instances where count is unknown until runtime.
  - Example: patrons spawned from simulation.
  - Example: list rows built from resource data.
- Transient preview artifacts that are intentionally temporary and cleaned up.
- Non-Node data/helper classes (`RefCounted`, pure operation classes) are fine to construct via `.new()`.

### Not Allowed Runtime Creation

- `CanvasLayer.new()`, `PanelContainer.new()`, `Label.new()`, `ItemList.new()` for fixed UI composition.
- Full modal/menu/panel tree construction in code when structure is known at author time.
- Persistent helper/controller node trees created in `_ready()` that could be authored in scene.

## Existing Violations Identified

These areas currently violate scene-first policy and should be migrated to scene composition.

1. `scripts/Main.gd`
   - Creates multiple fixed `CanvasLayer` and persistent helper/control nodes in `_ready()`.
   - Should be moved into `Main.tscn` (or composed child scenes) and referenced.

2. `scripts/room_editing/TheaterSchedulePanel.gd`
   - Builds modal hierarchy in code (`ColorRect`, `PanelContainer`, labels, list, buttons).
   - Should become `TheaterSchedulePanel.tscn` with script behavior only.

3. `scripts/room_editing/RoomEditMenu.gd`
   - Builds fixed room menu and dialog in code.
   - Should become `RoomEditMenu.tscn`.

4. `scripts/room_editing/FurnitureListPanel.gd`
   - Builds fixed panel/picker scaffolding in code.
   - Should become `FurnitureListPanel.tscn` (dynamic item rows can remain runtime-instanced).

5. `scripts/admin/AdminMenuUI.gd`
   - Builds admin overlay/panel tree in code.
   - Should become `AdminMenuUI.tscn`.

6. `scripts/admin/AdminMenu.gd`
   - Instantiates admin UI via `AdminMenuUI.new()`.
   - Should instantiate `AdminMenuUI.tscn` as a scene.

7. `scripts/RoomManager.gd`
   - Creates persistent room selection `Area2D`/`CollisionPolygon2D` wrappers at runtime.
   - Should move toward pre-authored room scene/component templates where feasible.

8. `objects/furniture/furniture_base.gd`
   - Creates fixed collision/navigation helper nodes at runtime.
   - Should be authored in furniture scenes where stable.

## Known Acceptable Runtime Patterns (Do Not Flag)

- `scripts/Spawner.gd`: data-driven patron spawn count (`instantiate()`).
- `scripts/room_building/operations/FurnitureOperation.gd`: data-driven furniture placement instances.
- `scripts/room_building/RoomBuildUI.gd`: dynamic controls from room-type resource lists (prefer scene-instanced row/button prefabs over direct `.new()` when practical).

## Architecture Notes (Merged from CLAUDE.md)

- Room systems use `RoomInstance` data models and operation-style helpers.
- Navigation uses `NavigationAgent2D` with `Targets` autoload.
- Theater flow uses state machines (`idle`, `scheduled`, `previews`, `playing`, `cleaning`).
- Registries (`RoomTypeRegistry`, `FurnitureRegistry`) are singleton data sources.

## Enforcement Checklist (Use Before Adding Nodes in Code)

Before adding `*.new()`, `instantiate()`, or `add_child()`:

1. Is node count unknown until runtime and truly data-driven?
   - If no: author in scene.
2. Is this a stable, persistent UI or gameplay hierarchy?
   - If yes: author in scene.
3. Can this dynamic element be a pre-authored item scene instantiated per data row?
   - If yes: prefer instantiate over `.new()`.
4. Is this only a transient preview artifact that is cleaned up immediately?
   - If yes: runtime creation allowed.

If any answer indicates scene-authored, do not implement via runtime node construction.
