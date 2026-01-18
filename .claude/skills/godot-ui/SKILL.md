---
name: godot-ui
description: Build Godot 4 UI with proper layout containers, anchoring, CanvasLayer, and pixel-art styling. Use when creating UI panels, menus, HUDs, buttons, or fixing UI layout/visibility issues in Godot.
allowed-tools: Read, Glob, Grep, mcp__gdai-mcp__get_scene_tree, mcp__gdai-mcp__add_node, mcp__gdai-mcp__update_property, mcp__gdai-mcp__set_anchor_preset, mcp__gdai-mcp__get_editor_screenshot
---

# Godot UI Building

## Core Principles

1. **Screen-space UI must use CanvasLayer** - Never place Control nodes directly under Node2D
2. **Use container hierarchy for layout** - Don't manually position elements
3. **PanelContainer for auto-sizing** - Panel does NOT auto-size
4. **Anchor presets for responsive positioning** - Don't use fixed pixel positions

## Standard UI Structure

```
GameScene (Node2D)
├── WorldContent
├── UILayer (CanvasLayer)           # Modal/overlay UI
│   └── GameUI (Control, full_rect)
│       └── CenterContainer (full_rect)
│           └── PanelContainer
│               └── MarginContainer
│                   └── VBoxContainer
└── HUDLayer (CanvasLayer)          # Persistent UI
    └── HUD (Control, full_rect)
        └── Button (anchored bottom_right)
```

## Container Selection Guide

| Need | Container | Notes |
|------|-----------|-------|
| Auto-size to content | `PanelContainer` | NOT Panel |
| Center children | `CenterContainer` | Set to full_rect |
| Vertical list | `VBoxContainer` | Set separation |
| Horizontal list | `HBoxContainer` | Set separation |
| Grid layout | `GridContainer` | Set columns |
| Padding/margins | `MarginContainer` | Set margin constants |
| Scrollable content | `ScrollContainer` | Wrap in this |

## Anchor Presets

Use `set_anchor_preset` MCP tool or set in code:

| Position | Preset Name | Value |
|----------|-------------|-------|
| Top-left | `top_left` | 0 |
| Top-right | `top_right` | 2 |
| Bottom-left | `bottom_left` | 6 |
| Bottom-right | `bottom_right` | 3 |
| Center | `center` | 8 |
| Full rect | `full_rect` | 15 |
| Top-wide | `top_wide` | 10 |
| Bottom-wide | `bottom_wide` | 12 |

## Building a Centered Panel

### Step 1: Create CanvasLayer
```
add_node: parent="/root/Main", type="CanvasLayer", name="UILayer"
```

### Step 2: Add Control with full_rect
```
add_node: parent="UILayer", type="Control", name="PanelUI"
set_anchor_preset: node_path="UILayer/PanelUI", preset="full_rect"
```

### Step 3: Add CenterContainer
```
add_node: parent="UILayer/PanelUI", type="CenterContainer", name="CenterContainer"
set_anchor_preset: node_path="UILayer/PanelUI/CenterContainer", preset="full_rect"
```

### Step 4: Add PanelContainer (auto-sizes!)
```
add_node: parent="UILayer/PanelUI/CenterContainer", type="PanelContainer", name="Panel"
```

### Step 5: Add MarginContainer for padding
```
add_node: parent=".../Panel", type="MarginContainer", name="MarginContainer"
update_property: node_path=".../MarginContainer", property_path="theme_override_constants/margin_left", value="20"
update_property: node_path=".../MarginContainer", property_path="theme_override_constants/margin_top", value="20"
update_property: node_path=".../MarginContainer", property_path="theme_override_constants/margin_right", value="20"
update_property: node_path=".../MarginContainer", property_path="theme_override_constants/margin_bottom", value="20"
```

### Step 6: Add content container
```
add_node: parent=".../MarginContainer", type="VBoxContainer", name="ContentContainer"
update_property: node_path=".../ContentContainer", property_path="theme_override_constants/separation", value="8"
```

## Pixel-Art Styling (GDScript)

```gdscript
# Panel style
var panel_style = StyleBoxFlat.new()
panel_style.bg_color = Color(0.12, 0.1, 0.15, 0.95)    # Dark purple-gray
panel_style.border_color = Color(0.55, 0.45, 0.35, 1)  # Warm brown
panel_style.set_border_width_all(3)
panel_style.set_corner_radius_all(3)                    # Minimal rounding
panel.add_theme_stylebox_override("panel", panel_style)

# Button styles
var btn_normal = StyleBoxFlat.new()
btn_normal.bg_color = Color(0.25, 0.22, 0.3, 1.0)
btn_normal.border_color = Color(0.5, 0.45, 0.4, 1.0)
btn_normal.set_border_width_all(2)
btn_normal.set_corner_radius_all(2)
btn_normal.set_content_margin_all(8)

var btn_hover = StyleBoxFlat.new()
btn_hover.bg_color = Color(0.35, 0.32, 0.4, 1.0)
btn_hover.border_color = Color(0.7, 0.6, 0.5, 1.0)
btn_hover.set_border_width_all(2)
btn_hover.set_corner_radius_all(2)
btn_hover.set_content_margin_all(8)

var btn_pressed = StyleBoxFlat.new()
btn_pressed.bg_color = Color(0.18, 0.15, 0.22, 1.0)
btn_pressed.border_color = Color(0.6, 0.5, 0.4, 1.0)
btn_pressed.set_border_width_all(2)
btn_pressed.set_corner_radius_all(2)
btn_pressed.set_content_margin_all(8)

button.add_theme_stylebox_override("normal", btn_normal)
button.add_theme_stylebox_override("hover", btn_hover)
button.add_theme_stylebox_override("pressed", btn_pressed)
button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1.0))
button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9, 1.0))
```

## Visibility Toggle Pattern

```gdscript
# In UI script
func _ready() -> void:
    hide()  # Start hidden

func show_ui() -> void:
    show()

func hide_ui() -> void:
    hide()

# In controller
func toggle_ui() -> void:
    if ui.visible:
        ui.hide_ui()
        camera.enable_input = true   # Re-enable camera
    else:
        ui.show_ui()
        camera.enable_input = false  # Disable camera to allow UI clicks
```

## Common Issues & Fixes

### UI moves with camera
**Cause**: Control under Node2D without CanvasLayer
**Fix**: Add CanvasLayer between Node2D and Control

### Panel doesn't resize to content
**Cause**: Using Panel instead of PanelContainer
**Fix**: Change node type to PanelContainer

### UI not centered
**Cause**: Missing CenterContainer or wrong anchors
**Fix**: Wrap in CenterContainer with full_rect anchors

### Buttons not clickable
**Cause**: Camera or other node capturing input
**Fix**: Disable camera input during UI mode, or set `mouse_filter = MOUSE_FILTER_IGNORE` on overlapping nodes

### Button text cut off
**Cause**: Fixed size too small
**Fix**: Set `custom_minimum_size` or use `SIZE_EXPAND_FILL`

## Isometric Coordinate Conversion

For UI that interacts with isometric world (64x32 tiles):

```gdscript
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

func screen_to_tile(screen_pos: Vector2) -> Vector2i:
    var canvas_transform = get_viewport().get_canvas_transform()
    var world_pos = canvas_transform.affine_inverse() * screen_pos
    world_pos.y -= HALF_HEIGHT
    var tile_x = (world_pos.x / HALF_WIDTH + world_pos.y / HALF_HEIGHT) / 2.0
    var tile_y = (world_pos.y / HALF_HEIGHT - world_pos.x / HALF_WIDTH) / 2.0
    return Vector2i(floor(tile_x), floor(tile_y))

func tile_to_screen(tile_pos: Vector2i) -> Vector2:
    var world_pos = Vector2(
        (tile_pos.x - tile_pos.y) * HALF_WIDTH,
        (tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
    )
    return get_viewport().get_canvas_transform() * world_pos
```

## Checklist Before Building UI

- [ ] Is there a CanvasLayer for this UI?
- [ ] Does the root Control have full_rect anchors?
- [ ] Am I using PanelContainer (not Panel) for auto-sizing?
- [ ] Is there a CenterContainer if centering is needed?
- [ ] Is there a MarginContainer for padding?
- [ ] Will camera input conflict with UI clicks?
