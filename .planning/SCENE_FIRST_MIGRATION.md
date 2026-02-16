# Scene-First Migration Tracker

Tracks migration of runtime-created fixed node hierarchies into scene-authored `.tscn` composition.

## Status Legend

- [ ] Not started
- [~] In progress
- [x] Complete

## Execution Rules

- Execute in listed order unless a blocker requires resequencing.
- Keep each step shippable and testable.
- For dynamic repeated content, prefer `PackedScene.instantiate()` over `.new()`.
- Do not mix broad refactors into bugfix PRs.

---

## 1) Theater Schedule Modal

- [x] Migrate `scripts/room_editing/TheaterSchedulePanel.gd` to `TheaterSchedulePanel.tscn`
- [x] Move modal tree (dimmer/panel/header/list/actions) into scene
- [x] Keep script focused on data binding/signals only

**Done when:** modal hierarchy is scene-authored and runtime fixed-node construction is removed.

## 2) Room Edit Menu

- [x] Migrate `scripts/room_editing/RoomEditMenu.gd` to `RoomEditMenu.tscn`
- [x] Scene-author fixed menu buttons and delete confirmation dialog
- [x] Keep script focused on room positioning/action emits

**Done when:** menu/dialog hierarchy is scene-authored and script only controls behavior.

## 3) Furniture List Panel

- [ ] Migrate fixed shell in `scripts/room_editing/FurnitureListPanel.gd` to `FurnitureListPanel.tscn`
- [ ] Add reusable item-row scene for repeated entries
- [ ] Switch repeated entries to `PackedScene.instantiate()`

**Done when:** panel/picker shell is scene-authored and dynamic rows are prefab-instanced.

## 4) Admin UI

- [ ] Migrate `scripts/admin/AdminMenuUI.gd` to `AdminMenuUI.tscn`
- [ ] Update `scripts/admin/AdminMenu.gd` to instantiate scene, not `new()`
- [ ] Keep script behavior-only (toggle/open/close wiring)

**Done when:** admin overlay/panel is scene-authored and loaded via scene instancing.

## 5) Main Fixed Hierarchy Extraction

- [ ] Move fixed layers/controllers/buttons from `scripts/Main.gd` to `Main.tscn` or child scenes
- [ ] Replace runtime construction with node references (`@export`/`@onready`)
- [ ] Preserve existing behavior and signal wiring

**Done when:** `_ready()` no longer builds persistent fixed node hierarchies.

## 6) Room Selection Wrapper Migration

- [ ] Refactor persistent selection structure in `scripts/RoomManager.gd`
- [ ] Use pre-authored room selection component scene/template where feasible
- [ ] Keep only truly dynamic parts runtime-driven

**Done when:** stable selection collision structure is scene/component-authored.

## 7) Furniture Helper Nodes

- [ ] Migrate fixed helper nodes in `objects/furniture/furniture_base.gd` into furniture scenes
- [ ] Keep script logic for runtime configuration only
- [ ] Validate representative furniture prefabs after migration

**Done when:** stable collision/navigation helper nodes are authored in furniture scenes.

## 8) Project-Wide Guardrail Pass

- [ ] Sweep for fixed runtime node construction patterns
- [ ] Convert repeated dynamic UI/game elements to prefab instancing where practical
- [ ] Document any intentional exceptions inline with justification

**Done when:** fixed runtime node creation patterns are removed and scene-first policy is enforceable.

---

## Migration Log

Use this section to append step progress notes.

- YYYY-MM-DD: Step N started - note
- YYYY-MM-DD: Step N completed - note
- 2026-02-16: Step 1 completed - TheaterSchedulePanel modal hierarchy moved to `scripts/room_editing/TheaterSchedulePanel.tscn`; `Main.gd` now instantiates the scene.
- 2026-02-16: Step 2 completed - RoomEditMenu hierarchy moved to `scripts/room_editing/RoomEditMenu.tscn`; `Main.gd` now instantiates the scene.
