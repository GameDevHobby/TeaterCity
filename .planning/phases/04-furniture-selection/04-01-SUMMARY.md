---
phase: 04-furniture-selection
plan: 01
subsystem: room-editing
tags: [furniture, selection, tap-detection, highlight, area2d]

dependency-graph:
  requires:
    - phase-2 (RoomEditMenu with edit_furniture_pressed signal)
    - RoomManager pattern (Area2D tap detection)
    - RoomSelectionHighlight pattern (highlight drawing)
  provides:
    - FurnitureEditController for furniture selection mode
    - FurnitureSelectionHighlight for visual feedback
    - Furniture edit mode entry via edit_furniture_pressed
  affects:
    - phase-5 (Furniture Editing Operations will use selection)

tech-stack:
  added: []
  patterns:
    - Area2D with CollisionPolygon2D for tap detection (same as RoomManager)
    - CanvasLayer wrapper for screen-space UI
    - Controller + Highlight separation (follows room selection pattern)

key-files:
  created:
    - scripts/room_editing/FurnitureEditController.gd
    - scripts/room_editing/FurnitureSelectionHighlight.gd
  modified:
    - scripts/Main.gd

decisions:
  - id: furniture-cyan-color
    choice: "Cyan (0.2, 0.8, 1.0) for furniture vs yellow for rooms"
    rationale: "Clear visual distinction between room and furniture selection"
  - id: min-tap-target
    choice: "44x44 pixel minimum tap target"
    rationale: "Mobile accessibility guideline for touch targets"
  - id: same-canvas-layer
    choice: "FurnitureEditLayer at layer 0 (same as SelectionHighlightLayer)"
    rationale: "Furniture highlights should appear at same z-order as room highlights"

metrics:
  duration: "~3 minutes"
  completed: "2026-01-23"
---

# Phase 4 Plan 01: Furniture Selection Controller Summary

**One-liner:** Tap selection on furniture with cyan highlight using Area2D pattern from RoomManager.

## What Was Built

### FurnitureEditController (`scripts/room_editing/FurnitureEditController.gd`)

Controller managing furniture edit mode:

- **Signals:** `furniture_selected(room, furniture)`, `furniture_deselected`, `mode_exited`
- **Area2D Tap Detection:** Creates Area2D with CollisionPolygon2D for each furniture piece
- **Tap Thresholds:** 20px distance, 300ms time (matches RoomManager)
- **Minimum Tap Target:** Expands small furniture polygons to 44x44px minimum
- **Dual Input:** Handles both InputEventMouseButton (desktop) and InputEventScreenTouch (mobile)
- **Deselection:** `_unhandled_input` detects taps outside furniture areas

### FurnitureSelectionHighlight (`scripts/room_editing/FurnitureSelectionHighlight.gd`)

Visual feedback for selected furniture:

- **Selection Color:** Cyan `Color(0.2, 0.8, 1.0, 0.4)` - distinct from room yellow
- **Access Tile Color:** Lighter cyan `Color(0.2, 0.8, 1.0, 0.2)` for patron standing positions
- **Drawing:** Uses `RoomBuildDrawing.draw_tile_highlight()` helper
- **Signal Connections:** Listens to controller signals for redraw triggers

### Main.gd Integration

- Creates `FurnitureEditLayer` CanvasLayer at layer 0
- Instantiates `FurnitureEditController` and `FurnitureSelectionHighlight`
- Wires `edit_furniture_pressed` signal to `enter_edit_mode(room)`
- Clears room selection when entering furniture edit mode

## Key Implementation Details

### Furniture to Polygon Conversion

```gdscript
func _furniture_to_polygon(furn: RoomInstance.FurniturePlacement) -> PackedVector2Array:
    var occupied_tiles := furn.get_occupied_tiles()
    # Calculate bounding box, convert to isometric diamond
    var top := IsometricMath.tile_to_world(min_tile)
    var right := IsometricMath.tile_to_world(Vector2i(max_tile.x + 1, min_tile.y))
    var bottom := IsometricMath.tile_to_world(Vector2i(max_tile.x + 1, max_tile.y + 1))
    var left := IsometricMath.tile_to_world(Vector2i(min_tile.x, max_tile.y + 1))
    # Expand if needed for minimum tap target
    return _ensure_minimum_tap_target(polygon)
```

### Mode Entry Flow

1. User taps room -> Room selected (yellow highlight)
2. RoomEditMenu appears with "Edit Furniture" button
3. User taps "Edit Furniture"
4. `edit_furniture_pressed` signal emits
5. Main.gd calls `RoomManager.clear_selection()` (hides room menu)
6. Main.gd calls `_furniture_controller.enter_edit_mode(room)`
7. Controller creates Area2D for each furniture piece
8. User can now tap furniture to select (cyan highlight)

## Commits

| Commit | Description |
|--------|-------------|
| b0c3012 | feat(04-01): add FurnitureEditController for furniture selection |
| f769fdc | feat(04-01): add FurnitureSelectionHighlight for furniture feedback |
| 3384d86 | feat(04-01): integrate FurnitureEditController into Main.gd |

## Deviations from Plan

None - plan executed exactly as written.

## Verification Status

- [x] File exists: `scripts/room_editing/FurnitureEditController.gd`
- [x] File exists: `scripts/room_editing/FurnitureSelectionHighlight.gd`
- [x] FurnitureEditController has class_name
- [x] FurnitureEditController has required signals
- [x] FurnitureSelectionHighlight has class_name
- [x] FurnitureSelectionHighlight uses cyan color (distinct from yellow)
- [x] Main.gd connects edit_furniture_pressed signal
- [x] FurnitureSelectionHighlight connects furniture_selected signal

## Next Phase Readiness

Phase 4 Plan 02 (List Selection UI) can proceed:
- FurnitureEditController provides selection state
- Signals available for UI to listen to
- Mode entry/exit flow established
