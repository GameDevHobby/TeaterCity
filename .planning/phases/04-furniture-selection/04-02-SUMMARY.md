---
phase: 04-furniture-selection
plan: 02
subsystem: room-editing
tags: [furniture, list-panel, selection, ui, bi-directional-sync]

dependency-graph:
  requires:
    - phase-4-plan-01 (FurnitureEditController with selection signals)
    - UIStyleHelper (styled button creation)
    - RoomInstance.FurniturePlacement (furniture data model)
  provides:
    - FurnitureListPanel scrollable list UI
    - Bi-directional selection sync between list and room view
    - Done button for mode exit
  affects:
    - phase-5 (Furniture editing operations will use selection state)

tech-stack:
  added: []
  patterns:
    - ScrollContainer for list overflow handling
    - Signal-based bi-directional sync pattern
    - PanelContainer anchored bottom-left for list UI

key-files:
  created:
    - Scripts/room_editing/FurnitureListPanel.gd
  modified:
    - Scripts/Main.gd
    - Scripts/room_editing/FurnitureEditController.gd

decisions:
  - id: list-panel-position
    choice: "Bottom-left with 20px margin"
    rationale: "Clear of room view, accessible for right-handed users"
  - id: scroll-height
    choice: "Max 200px scroll height"
    rationale: "Limits panel size while allowing 5+ items to scroll"
  - id: cyan-accent-selection
    choice: "Color(0.2, 0.5, 0.6) for selected list item"
    rationale: "Matches cyan furniture highlight in room view"

metrics:
  duration: "~5 minutes"
  completed: "2026-01-23"
---

# Phase 4 Plan 02: Furniture List Panel Summary

**One-liner:** Scrollable furniture list with bi-directional selection sync to room tap selection.

## What Was Built

### FurnitureListPanel (`Scripts/room_editing/FurnitureListPanel.gd`)

Scrollable list panel showing all furniture in selected room:

- **Structure:** PRESET_FULL_RECT Control with PanelContainer anchored bottom-left
- **Signals:** `furniture_item_selected(index, furniture)`, `done_pressed`
- **Layout:** 200px width, up to 200px scroll height, 20px margin from edges
- **Item Buttons:** Dynamically created for each FurniturePlacement with furniture name
- **Selection Highlight:** Cyan accent color matching furniture highlight in room

### Bi-directional Selection Sync

Two-way sync between list and room view:

**List -> Room:**
1. User clicks item in list
2. `furniture_item_selected` signal emits
3. `Main._on_furniture_list_item_selected` calls `FurnitureEditController.select_furniture()`
4. Controller emits `furniture_selected`
5. `FurnitureSelectionHighlight` redraws with cyan highlight

**Room -> List:**
1. User taps furniture in room
2. `FurnitureEditController._select_furniture()` emits `furniture_selected`
3. `FurnitureListPanel._on_controller_furniture_selected()` finds index
4. `select_item(index)` highlights button with cyan accent

### FurnitureEditController.select_furniture() Method

New public method added to support list-based selection:

```gdscript
func select_furniture(furniture: RoomInstance.FurniturePlacement) -> void:
    if not _active or _current_room == null:
        return
    if furniture not in _current_room.furniture:
        return
    _selected_furniture = furniture
    furniture_selected.emit(_current_room, furniture)
```

### Main.gd Integration

- Creates `FurnitureListPanel` in EditMenuLayer (screen-space UI)
- Wires `set_controller()` for signal connections
- Shows panel via `show_for_room()` when entering furniture edit mode
- Handles `done_pressed` by calling `exit_edit_mode()`

## Commits

| Commit | Description |
|--------|-------------|
| 0572996 | feat(04-02): add FurnitureListPanel for list-based furniture selection |
| 540b8b0 | feat(04-02): integrate FurnitureListPanel with bi-directional selection sync |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Status

- [x] File exists: `Scripts/room_editing/FurnitureListPanel.gd`
- [x] FurnitureListPanel has class_name
- [x] Has `furniture_item_selected` signal
- [x] Has `done_pressed` signal
- [x] Has `set_controller()`, `show_for_room()`, `hide_panel()`, `select_item()` methods
- [x] FurnitureEditController has `select_furniture()` method
- [x] Main.gd creates FurnitureListPanel
- [x] Main.gd wires list selection to controller
- [x] List panel shows when entering furniture edit mode

## Success Criteria Status

- [x] Furniture list panel displays all furniture in selected room
- [x] Selecting from list highlights corresponding furniture in room
- [x] Tapping furniture in room selects it in list (bi-directional sync)
- [x] Panel scrolls if room has many furniture items
- [x] Done button exits furniture edit mode cleanly

## Next Phase Readiness

Phase 4 complete. Furniture selection infrastructure ready:
- FurnitureEditController manages selection state
- FurnitureListPanel provides alternative selection method
- FurnitureSelectionHighlight provides visual feedback
- All three components synchronized via signals

Phase 5 (Furniture Editing Operations) can proceed with:
- Selection state available via `FurnitureEditController.get_selected_furniture()`
- Selected room available via `FurnitureEditController.get_current_room()`
