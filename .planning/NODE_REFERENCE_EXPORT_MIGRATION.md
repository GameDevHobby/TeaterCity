# Node Reference Export Migration Plan

Goal: migrate scene/node references to exported fields and remove fragile string path lookups.

## Scope Baseline (2026-02-16)

Detected usages to migrate:

- `$Node/Path` shorthand: **47** occurrences across **7** files
- `get_node(...)` / `get_node_or_null(...)`: **13** occurrences across **10** files

Primary files with scene-path references:

- `scripts/Main.gd`
- `scripts/admin/AdminMenuUI.gd`
- `scripts/room_editing/FurnitureListPanel.gd`
- `scripts/room_editing/RoomEditMenu.gd`
- `scripts/room_editing/TheaterSchedulePanel.gd`
- `scripts/ui/CircularTimerUI.gd`
- `scripts/ui/ResumeNotificationUI.gd`

Additional string-node access sites:

- `scripts/Main.gd` (direct `get_node("...")`)
- `scripts/RoomManager.gd` (instanced helper child lookup)
- `scripts/room_building/RoomBuildUI.gd` (instanced temp child lookup)
- autoload lookups via `get_node("/root/...")` in:
  - `scripts/Main.gd`
  - `scripts/admin/AdminMenuUI.gd`
  - `scripts/admin/AdminMenu.gd`
  - `scripts/room_building/RoomBuildController.gd`
  - `scripts/room_building/RoomSelectionHighlight.gd`
  - `scripts/room_editing/DoorEditController.gd`
  - `scripts/room_editing/RoomResizeController.gd`
  - `scripts/room_editing/RoomEditMenu.gd`

---

## Migration Strategy

## Progress

- [~] Phase A - in progress
  - [x] `scripts/ui/CircularTimerUI.gd`
  - [x] `scripts/ui/ResumeNotificationUI.gd`
  - [x] `scripts/admin/AdminMenuUI.gd`
  - [ ] `scripts/room_editing/TheaterSchedulePanel.gd`
  - [ ] `scripts/room_editing/RoomEditMenu.gd`
  - [ ] `scripts/room_editing/FurnitureListPanel.gd`
  - [ ] `scripts/Main.gd` (scene-owned refs only)
- [ ] Phase B
- [ ] Phase C
- [ ] Phase D

### Phase A - Scene-owned references (highest value, lowest risk)

Convert all stable scene node references from `$...` to `@export` in scripts with scene files.

Targets:

1. `scripts/ui/CircularTimerUI.gd`
2. `scripts/ui/ResumeNotificationUI.gd`
3. `scripts/admin/AdminMenuUI.gd`
4. `scripts/room_editing/TheaterSchedulePanel.gd`
5. `scripts/room_editing/RoomEditMenu.gd`
6. `scripts/room_editing/FurnitureListPanel.gd`
7. `scripts/Main.gd` (scene-owned refs only)

Done when:

- No `$...` in target files
- Corresponding `.tscn` files have exported fields wired

### Phase B - Remove relative `get_node(...)` for stable scene refs

Targets:

1. `scripts/Main.gd`:
   - replace `get_node("SelectionHighlightLayer/SelectionHighlight")`
   - replace `get_node("FurnitureEditLayer/FurnitureSelectionHighlight")`
2. `scripts/RoomManager.gd`:
   - replace `area.get_node("CollisionPolygon2D")` by adding script API to `RoomSelectionArea.tscn`
3. `scripts/room_building/RoomBuildUI.gd`:
   - replace `temp_instance.get_node_or_null("AnimatedSprite2D")` with typed script API on furniture scenes (or exported sprite ref in furniture base scene)

Done when:

- No `get_node("relative/path")` / `get_node_or_null("relative/path")` in scene-owned flows

### Phase C - Autoload reference migration

Replace `/root/...` lookups with a consistent singleton access pattern.

Preferred pattern:

- Use autoload singleton names directly where available (`RoomManager`, `AdminMenu`, `Targets`)
- If direct global access is unavailable in context, use one local adapter method and avoid scattered path strings

Targets:

- `scripts/Main.gd`
- `scripts/admin/AdminMenuUI.gd`
- `scripts/admin/AdminMenu.gd`
- `scripts/room_building/RoomBuildController.gd`
- `scripts/room_building/RoomSelectionHighlight.gd`
- `scripts/room_editing/DoorEditController.gd`
- `scripts/room_editing/RoomResizeController.gd`
- `scripts/room_editing/RoomEditMenu.gd`

Done when:

- No direct `get_node("/root/...")` usages remain, or they are isolated to one intentional adapter per subsystem

### Phase D - Guardrail and verification pass

Validation checks:

1. `grep -R "\$[A-Za-z0-9_/]" scripts`
2. `grep -R "get_node(" scripts`
3. `grep -R "get_node_or_null(" scripts`
4. Godot headless parse: `godot --headless --path . --quit`

Done when:

- Scene-owned scripts have export-wired dependencies
- Path-string node lookups are removed or explicitly documented exceptions

---

## Execution Notes

- Migrate one file at a time and wire exports in the matching `.tscn` immediately.
- Avoid mixing behavior changes during reference migration.
- For dynamic helper scenes, attach tiny scripts exposing typed child refs instead of parent-side string lookups.
