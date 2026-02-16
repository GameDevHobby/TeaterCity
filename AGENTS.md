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

## Node Reference Policy (Hard Rule)

For scene node references and runtime scene loading, use exported references, not string paths.

### Mandatory Rules

1. Use `@export` node references for persistent scene dependencies (buttons, panels, controllers, overlays).
2. Do not use `$Node/Path` shorthand in production scripts.
3. Do not use `get_node("relative/path")` or `get_node_or_null("relative/path")` for stable scene-owned references.
4. For runtime-instanced scenes, use exported `PackedScene` fields instead of hardcoded `preload("res://...")` strings.
5. If a dynamic helper scene needs child access, prefer a script API on that scene over string-based child lookups.

### Allowed Exceptions (Narrow)

- Autoload/global singleton access (`/root/...`) may remain temporarily during migration.
- Transient one-off introspection/debug code where exported references are not practical.

### Why

- Protects against editor hierarchy/path changes.
- Makes dependencies visible and editable in Inspector.
- Removes fragile hidden string-coupling.

## Prioritized Migration Sequence (Scene-First Compliance)

Use this order to migrate existing violations with lowest risk first and fastest visual-editing wins.

1. `scripts/room_editing/TheaterSchedulePanel.gd` -> `TheaterSchedulePanel.tscn`
   - **Why first:** High-impact active UI with isolated scope.
   - **Done when:** Modal tree is scene-authored; script only handles data binding and signals.

2. `scripts/room_editing/RoomEditMenu.gd` -> `RoomEditMenu.tscn`
   - **Why second:** Core room action UI and still relatively isolated.
   - **Done when:** Fixed menu buttons/dialog are scene-authored; script only positions and emits actions.

3. `scripts/room_editing/FurnitureListPanel.gd` -> `FurnitureListPanel.tscn` (+ row prefab)
   - **Why third:** Large UI surface with good payoff for visual iteration.
   - **Done when:** Static shell is scene-authored and repeated rows/items use scene instancing (`PackedScene.instantiate()`).

4. `scripts/admin/AdminMenuUI.gd` + `scripts/admin/AdminMenu.gd` -> `AdminMenuUI.tscn`
   - **Why fourth:** Administrative UI has clear boundaries and low gameplay coupling.
   - **Done when:** Admin overlay/panel is scene-authored and `AdminMenu` instantiates scene, not `new()`.

5. `scripts/Main.gd` fixed hierarchy extraction into `Main.tscn`/child scenes
   - **Why fifth:** Largest blast radius; safer after child UI components are scene-backed.
   - **Done when:** `_ready()` no longer builds persistent fixed layers/controllers/buttons in code.

6. `scripts/RoomManager.gd` persistent selection wrapper migration
   - **Why sixth:** Gameplay-level structure, moderate risk.
   - **Done when:** Persistent room selection collision structure is scene/component-authored where feasible.

7. `objects/furniture/furniture_base.gd` helper-node migration into furniture scenes
   - **Why seventh:** Broad asset impact across furniture content.
   - **Done when:** Stable collision/navigation helper nodes are authored in furniture scenes, not created at runtime.

8. Project-wide cleanup + guardrail pass
   - **Why last:** Lock policy after major migrations land.
   - **Done when:** Fixed runtime node creation patterns are removed; dynamic repeated elements prefer scene instancing; exceptions are documented in code comments only when necessary.
