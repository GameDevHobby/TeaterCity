# Phase 2: Room Menu & Edit Mode Entry - Research

**Researched:** 2026-01-22
**Domain:** Contextual popup menus, room edit workflow, UI positioning in isometric games
**Confidence:** HIGH

## Summary

This phase implements a contextual menu that appears when a player selects a room, providing options to edit furniture, edit the room itself, or access room-type-specific features. The research focuses on Godot 4 popup/panel patterns and integration with the existing RoomManager selection system.

Key findings:
- Use PanelContainer (not PopupMenu/PopupPanel) for custom-styled buttons matching existing UI patterns
- Position menu in screen-space using `IsometricMath.tile_to_screen()` based on room bounding box center
- Manual dismiss handling via `_unhandled_input` (detect clicks outside panel bounds)
- RoomTypeResource.display_name provides room-type-specific label for placeholder button
- Wrap panel in CanvasLayer (layer=1) to render above selection highlight

**Primary recommendation:** Create `RoomEditMenu` as a Control with PanelContainer child, positioned near selected room's center tile, using existing UIStyleHelper for consistent styling. Listen to `RoomManager.room_selected` and `RoomManager.selection_cleared` signals.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PanelContainer | Godot 4.5 | Menu container with auto-sizing | Matches existing RoomBuildUI pattern, allows custom Button children |
| Control | Godot 4.5 | Base class for menu | Supports `_unhandled_input`, drawing, positioning |
| CanvasLayer | Godot 4.5 | Screen-space rendering | Required for Controls in Node2D main scene |
| UIStyleHelper | Project util | Button and panel styling | Consistent pixel-art theme |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| IsometricMath | Project util | Tile-to-screen conversion | Positioning menu near room center |
| RoomManager | Project singleton | Selection signals | Trigger menu show/hide |
| RoomTypeRegistry | Project singleton | Room type data | Get display_name for placeholder button |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PanelContainer | PopupPanel | PopupPanel is a Window subclass with quirky positioning in Godot 4; PanelContainer simpler |
| PanelContainer | PopupMenu | PopupMenu only supports predefined item types, not custom styled buttons |
| Manual dismiss | Popup.popup() | Popup auto-dismiss passes clicks through in Godot 4, causing unwanted interactions |
| CanvasLayer | Direct Control child | Controls in Node2D scenes don't render in screen-space correctly |

**Installation:**
```bash
# Nothing to install - uses built-in Godot 4.5 features
# Reuses existing project utilities (UIStyleHelper, IsometricMath)
```

## Architecture Patterns

### Recommended Project Structure

```
scripts/
├── RoomManager.gd              # Existing: Selection signals
├── Main.gd                     # Modified: Create RoomEditMenu
└── room_editing/
    └── RoomEditMenu.gd         # NEW: Contextual menu UI
```

### Pattern 1: RoomEditMenu Control with PanelContainer

**What:** A Control that contains a PanelContainer with VBoxContainer of styled buttons
**When to use:** For the contextual room menu

```gdscript
# RoomEditMenu.gd
class_name RoomEditMenu
extends Control

signal edit_furniture_pressed(room: RoomInstance)
signal edit_room_pressed(room: RoomInstance)
signal room_type_action_pressed(room: RoomInstance)

var _current_room: RoomInstance = null
var _panel: PanelContainer
var _edit_furniture_btn: Button
var _edit_room_btn: Button
var _room_type_btn: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block clicks
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _create_panel()
    hide()

    # Connect to RoomManager signals
    RoomManager.room_selected.connect(_on_room_selected)
    RoomManager.selection_cleared.connect(_on_selection_cleared)

func _create_panel() -> void:
    _panel = PanelContainer.new()
    UIStyleHelper.apply_panel_style(_panel)
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Panel blocks clicks
    add_child(_panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    _panel.add_child(margin)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    margin.add_child(vbox)

    # Create buttons
    _edit_furniture_btn = UIStyleHelper.create_styled_button("Edit Furniture", Vector2(160, 40))
    _edit_furniture_btn.pressed.connect(_on_edit_furniture)
    vbox.add_child(_edit_furniture_btn)

    _edit_room_btn = UIStyleHelper.create_styled_button("Edit Room", Vector2(160, 40))
    _edit_room_btn.pressed.connect(_on_edit_room)
    vbox.add_child(_edit_room_btn)

    _room_type_btn = UIStyleHelper.create_styled_button("", Vector2(160, 40))
    _room_type_btn.pressed.connect(_on_room_type_action)
    vbox.add_child(_room_type_btn)
```

### Pattern 2: Position Menu Near Room Center

**What:** Calculate screen position from room's bounding box center tile
**When to use:** When showing menu after room selection

```gdscript
func _on_room_selected(room: RoomInstance) -> void:
    _current_room = room
    _update_room_type_button(room)
    _position_near_room(room)
    show()

func _position_near_room(room: RoomInstance) -> void:
    # Calculate center tile of room
    var bbox = room.bounding_box
    var center_tile = Vector2i(
        bbox.position.x + bbox.size.x / 2,
        bbox.position.y + bbox.size.y / 2
    )

    # Convert to screen position
    var screen_pos = IsometricMath.tile_to_screen(center_tile, get_viewport())

    # Offset menu to appear to the right of center
    # Adjust for panel size after first frame renders
    await get_tree().process_frame
    var offset = Vector2(20, -_panel.size.y / 2)
    _panel.position = screen_pos + offset

    # Clamp to viewport bounds
    var viewport_size = get_viewport_rect().size
    _panel.position.x = clampf(_panel.position.x, 0, viewport_size.x - _panel.size.x)
    _panel.position.y = clampf(_panel.position.y, 0, viewport_size.y - _panel.size.y)
```

### Pattern 3: Manual Dismiss on Outside Click

**What:** Hide menu when user clicks outside the panel
**When to use:** For click-outside-to-dismiss behavior

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not visible or _current_room == null:
        return

    # Handle touch release (mobile) and mouse click (desktop)
    var is_click = false
    var click_pos = Vector2.ZERO

    if event is InputEventScreenTouch and not event.pressed:
        is_click = true
        click_pos = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        is_click = true
        click_pos = event.position

    if is_click:
        var panel_rect = Rect2(_panel.global_position, _panel.size)
        if not panel_rect.has_point(click_pos):
            # Click outside - clear selection (which hides menu)
            RoomManager.clear_selection()
            get_viewport().set_input_as_handled()
```

### Pattern 4: Room-Type-Specific Button Label

**What:** Update placeholder button text based on selected room's type
**When to use:** When room is selected

```gdscript
func _update_room_type_button(room: RoomInstance) -> void:
    var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
    if room_type:
        # Map room type to feature name
        var feature_name = _get_room_type_feature(room_type.id)
        _room_type_btn.text = feature_name
    else:
        _room_type_btn.text = "Room Options"

func _get_room_type_feature(room_type_id: String) -> String:
    # Map room types to their specific features
    match room_type_id:
        "theater_auditorium":
            return "Theater Schedule"
        "ticket_counter":
            return "Ticket Prices"
        "snack_bar":
            return "Menu Items"
        "bathroom":
            return "Maintenance"
        "lobby":
            return "Decorations"
        _:
            return "Room Options"
```

### Pattern 5: Integration with Main.gd

**What:** Create RoomEditMenu in Main._ready() similar to SelectionHighlight
**When to use:** During scene initialization

```gdscript
# In Main.gd _ready()
func _ready() -> void:
    # ... existing code ...

    # Create edit menu layer (above selection highlight)
    var edit_menu_layer = CanvasLayer.new()
    edit_menu_layer.name = "EditMenuLayer"
    edit_menu_layer.layer = 1  # Above selection highlight (layer 0)
    add_child(edit_menu_layer)

    var edit_menu = RoomEditMenu.new()
    edit_menu.name = "RoomEditMenu"
    edit_menu_layer.add_child(edit_menu)

    # Connect signals for future edit mode implementation
    edit_menu.edit_furniture_pressed.connect(_on_edit_furniture)
    edit_menu.edit_room_pressed.connect(_on_edit_room)
```

### Anti-Patterns to Avoid

- **Using PopupMenu/PopupPanel:** These are Window subclasses with positioning quirks in Godot 4; use PanelContainer instead
- **Positioning in world coordinates:** Menu needs screen-space coordinates; use tile_to_screen(), not tile_to_world()
- **Forgetting CanvasLayer:** Controls in Node2D scenes must be wrapped in CanvasLayer for screen-space rendering
- **MOUSE_FILTER_PASS on panel:** The panel itself must be MOUSE_FILTER_STOP to capture button clicks; only the parent Control should be IGNORE
- **Handling dismiss in Area2D:** The existing RoomManager Area2D selection handles room switching; menu dismiss should be separate

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Button styling | Custom StyleBox creation | `UIStyleHelper.create_styled_button()` | Consistent theme, handles all states |
| Panel styling | Manual StyleBoxFlat setup | `UIStyleHelper.apply_panel_style()` | Matches existing panels |
| Tile-to-screen conversion | Custom math | `IsometricMath.tile_to_screen()` | Handles camera zoom/pan |
| Room type lookup | Iterate through array | `RoomTypeRegistry.get_instance().get_room_type()` | Already implemented |

**Key insight:** The project has established patterns for UI creation (UIStyleHelper), coordinate conversion (IsometricMath), and data access (Registry singletons). Use these consistently.

## Common Pitfalls

### Pitfall 1: Menu Blocks Room Selection Clicks

**What goes wrong:** Clicking a different room doesn't select it because menu captures click
**Why it happens:** Menu's mouse_filter set incorrectly, or full-rect Control captures all input
**How to avoid:** Set outer Control to `MOUSE_FILTER_IGNORE`, only PanelContainer to `MOUSE_FILTER_STOP`
**Warning signs:** Can't select another room while menu is visible

### Pitfall 2: Menu Position Wrong After Camera Zoom/Pan

**What goes wrong:** Menu appears at wrong location after user zooms or pans camera
**Why it happens:** Using world coordinates instead of screen coordinates, or caching position
**How to avoid:** Always recalculate with `tile_to_screen()` when showing menu; position in screen-space via CanvasLayer
**Warning signs:** Menu drifts from room when camera moves

### Pitfall 3: Menu Doesn't Hide When Selecting Another Room

**What goes wrong:** Old menu stays visible when tapping different room
**Why it happens:** Not listening to `selection_cleared` or `room_selected` properly
**How to avoid:** Hide on `selection_cleared`, show with new room on `room_selected`
**Warning signs:** Multiple menus appear or menu shows for wrong room

### Pitfall 4: Click-Outside Dismiss Not Working on Mobile

**What goes wrong:** Tapping outside menu doesn't dismiss on mobile devices
**Why it happens:** Only handling InputEventMouseButton, not InputEventScreenTouch
**How to avoid:** Handle both event types in `_unhandled_input`
**Warning signs:** Works in editor but not on device

### Pitfall 5: Panel Size Unknown at Position Time

**What goes wrong:** Menu clamps to wrong position because panel.size is zero
**Why it happens:** PanelContainer hasn't calculated size yet in same frame
**How to avoid:** Use `await get_tree().process_frame` before reading size, or set minimum size
**Warning signs:** Menu appears at edge of screen initially, then jumps

## Code Examples

### Complete RoomEditMenu Implementation

```gdscript
# scripts/room_editing/RoomEditMenu.gd
class_name RoomEditMenu
extends Control

signal edit_furniture_pressed(room: RoomInstance)
signal edit_room_pressed(room: RoomInstance)
signal room_type_action_pressed(room: RoomInstance)

var _current_room: RoomInstance = null
var _panel: PanelContainer
var _edit_furniture_btn: Button
var _edit_room_btn: Button
var _room_type_btn: Button

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _create_panel()
    hide()

    RoomManager.room_selected.connect(_on_room_selected)
    RoomManager.selection_cleared.connect(_on_selection_cleared)

func _create_panel() -> void:
    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    UIStyleHelper.apply_panel_style(_panel)
    add_child(_panel)

    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_top", 12)
    margin.add_theme_constant_override("margin_bottom", 12)
    _panel.add_child(margin)

    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    margin.add_child(vbox)

    _edit_furniture_btn = UIStyleHelper.create_styled_button("Edit Furniture", Vector2(160, 40))
    _edit_furniture_btn.pressed.connect(_on_edit_furniture)
    vbox.add_child(_edit_furniture_btn)

    _edit_room_btn = UIStyleHelper.create_styled_button("Edit Room", Vector2(160, 40))
    _edit_room_btn.pressed.connect(_on_edit_room)
    vbox.add_child(_edit_room_btn)

    _room_type_btn = UIStyleHelper.create_styled_button("Room Options", Vector2(160, 40))
    _room_type_btn.pressed.connect(_on_room_type_action)
    vbox.add_child(_room_type_btn)

func _unhandled_input(event: InputEvent) -> void:
    if not visible or _current_room == null:
        return

    var is_click = false
    var click_pos = Vector2.ZERO

    if event is InputEventScreenTouch and not event.pressed:
        is_click = true
        click_pos = event.position
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        is_click = true
        click_pos = event.position

    if is_click:
        var panel_rect = Rect2(_panel.global_position, _panel.size)
        if not panel_rect.has_point(click_pos):
            RoomManager.clear_selection()
            get_viewport().set_input_as_handled()

func _on_room_selected(room: RoomInstance) -> void:
    _current_room = room
    _update_room_type_button(room)
    _position_near_room(room)
    show()

func _on_selection_cleared() -> void:
    _current_room = null
    hide()

func _position_near_room(room: RoomInstance) -> void:
    var bbox = room.bounding_box
    var center_tile = Vector2i(
        bbox.position.x + bbox.size.x / 2,
        bbox.position.y + bbox.size.y / 2
    )

    var screen_pos = IsometricMath.tile_to_screen(center_tile, get_viewport())

    # Wait for panel to calculate size
    await get_tree().process_frame

    # Position to the right of room center
    var offset = Vector2(30, -_panel.size.y / 2)
    _panel.position = screen_pos + offset

    # Clamp to viewport
    var viewport_size = get_viewport_rect().size
    _panel.position.x = clampf(_panel.position.x, 8, viewport_size.x - _panel.size.x - 8)
    _panel.position.y = clampf(_panel.position.y, 8, viewport_size.y - _panel.size.y - 8)

func _update_room_type_button(room: RoomInstance) -> void:
    var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
    if room_type:
        _room_type_btn.text = _get_room_type_feature(room_type.id)
    else:
        _room_type_btn.text = "Room Options"

func _get_room_type_feature(room_type_id: String) -> String:
    match room_type_id:
        "theater_auditorium": return "Theater Schedule"
        "ticket_counter": return "Ticket Prices"
        "snack_bar": return "Menu Items"
        "bathroom": return "Maintenance"
        "lobby": return "Decorations"
        _: return "Room Options"

func _on_edit_furniture() -> void:
    if _current_room:
        edit_furniture_pressed.emit(_current_room)

func _on_edit_room() -> void:
    if _current_room:
        edit_room_pressed.emit(_current_room)

func _on_room_type_action() -> void:
    if _current_room:
        room_type_action_pressed.emit(_current_room)
```

### Main.gd Integration

```gdscript
# Addition to Main.gd _ready()
func _ready() -> void:
    room_build_manager.room_completed.connect(_on_room_completed)
    RoomManager.room_selected.connect(_on_room_selected)

    # Selection highlight layer (existing)
    var selection_layer = CanvasLayer.new()
    selection_layer.name = "SelectionHighlightLayer"
    selection_layer.layer = 0
    add_child(selection_layer)

    var selection_highlight = RoomSelectionHighlight.new()
    selection_highlight.name = "SelectionHighlight"
    selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
    selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
    selection_layer.add_child(selection_highlight)

    # Edit menu layer (NEW)
    var edit_menu_layer = CanvasLayer.new()
    edit_menu_layer.name = "EditMenuLayer"
    edit_menu_layer.layer = 1  # Above selection highlight
    add_child(edit_menu_layer)

    var edit_menu = RoomEditMenu.new()
    edit_menu.name = "RoomEditMenu"
    edit_menu_layer.add_child(edit_menu)

    # Connect edit signals (stub handlers for now)
    edit_menu.edit_furniture_pressed.connect(_on_edit_furniture_requested)
    edit_menu.edit_room_pressed.connect(_on_edit_room_requested)
    edit_menu.room_type_action_pressed.connect(_on_room_type_action_requested)

func _on_edit_furniture_requested(room: RoomInstance) -> void:
    print("Edit furniture: ", room.id)  # Placeholder for Phase 3+

func _on_edit_room_requested(room: RoomInstance) -> void:
    print("Edit room: ", room.id)  # Placeholder for Phase 3+

func _on_room_type_action_requested(room: RoomInstance) -> void:
    print("Room type action: ", room.id, " type: ", room.room_type_id)  # Placeholder
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Popup/PopupMenu for menus | PanelContainer with custom Controls | Godot 4.0 | Popup is Window subclass with quirks; PanelContainer simpler |
| Global input handlers | Local `_unhandled_input` in Control | Godot 4.0 | Better encapsulation, clearer event flow |
| Manual StyleBox each time | UIStyleHelper utility class | Project convention | Consistent styling, less code duplication |

**Deprecated/outdated:**
- `Popup.popup_centered()` for positioned popups: Use Control + PanelContainer for screen-space positioning
- Window-based popups for in-game menus: Reserved for system dialogs, not game UI

## Open Questions

1. **Camera zoom affecting menu position?**
   - What we know: `tile_to_screen()` accounts for camera transform
   - What's unclear: Should menu reposition if user zooms while menu is visible?
   - Recommendation: Recalculate position each show; don't track during zoom (menu hides on selection change)

2. **Menu overlap with room highlight?**
   - What we know: Menu on layer 1, highlight on layer 0
   - What's unclear: Visual design of menu near highlight border
   - Recommendation: Add 30px offset from room center; test visually during implementation

3. **Disable camera pan while menu is visible?**
   - What we know: Build mode disables camera pan
   - What's unclear: Should selection mode also disable pan?
   - Recommendation: Keep pan enabled; menu is brief interaction. If problematic, disable in future phase.

## Sources

### Primary (HIGH confidence)
- Existing codebase: `UIStyleHelper.gd` - button and panel styling patterns
- Existing codebase: `RoomBuildUI.gd` - Control/PanelContainer structure, coordinate conversion
- Existing codebase: `RoomManager.gd` - selection signals to connect to
- Existing codebase: `Main.gd` - CanvasLayer creation pattern for screen-space UI
- Existing codebase: `IsometricMath.gd` - tile_to_screen conversion
- Existing codebase: `RoomTypeRegistry.gd` - room type data access

### Secondary (MEDIUM confidence)
- [Godot Forum: PopupMenu at mouse position](https://forum.godotengine.org/t/how-to-poup-a-popupmenu-at-the-mouse-position/75356) - positioning patterns
- [GDScript.com: Popups](https://gdscript.com/solutions/popups/) - popup behavior overview
- [Godot Forum: Best practices for popup menus](https://forum.godotengine.org/t/general-best-practices-for-popup-menus/39183) - PopupPanel vs PopupMenu comparison

### Tertiary (LOW confidence)
- [Godot GitHub Issue #95151](https://github.com/godotengine/godot/issues/95151) - Popup positioning bugs in Godot 4
- [Godot GitHub Issue #94930](https://github.com/godotengine/godot/issues/94930) - Click-through behavior in Godot 4 popups

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - uses existing project patterns (UIStyleHelper, IsometricMath, CanvasLayer)
- Architecture: HIGH - follows established Main.gd initialization and RoomBuildUI structure
- Positioning: HIGH - tile_to_screen verified in codebase, CanvasLayer pattern proven
- Dismiss handling: MEDIUM - manual approach due to Godot 4 Popup quirks; tested patterns from forums

**Research date:** 2026-01-22
**Valid until:** 90 days (stable Godot 4.5 patterns, project-specific architecture)
