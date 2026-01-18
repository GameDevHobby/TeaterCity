class_name RoomBuildUI
extends Control

signal room_type_selected(room_type_id: String)
signal box_draw_completed(start: Vector2i, end: Vector2i)
signal door_placed(position: Vector2i)
signal doors_done
signal furniture_selected(furniture_id: String)
signal furniture_placed(furniture_id: String, position: Vector2i, rotation: int)
signal complete_pressed

@export var room_type_container: Container
@export var info_label: Label
@export var room_type_panel: PanelContainer
@export var tilemap_layer: TileMapLayer  # For proper isometric coordinate conversion

@export_group("Selection Box Colors")
@export var selection_valid_fill: Color = Color(0.2, 0.6, 1.0, 0.3)
@export var selection_valid_border: Color = Color(0.2, 0.6, 1.0, 1.0)
@export var selection_invalid_fill: Color = Color(1.0, 0.2, 0.2, 0.3)
@export var selection_invalid_border: Color = Color(1.0, 0.2, 0.2, 1.0)

@export_group("Door Placement Colors")
@export var door_placed_color: Color = Color(0.2, 0.8, 0.2, 0.5)
@export var door_valid_color: Color = Color(0.8, 0.8, 0.2, 0.3)
@export var door_wall_color: Color = Color(0.5, 0.5, 0.5, 0.2)
@export var door_hover_color: Color = Color(0.2, 1.0, 0.2, 0.7)

@export_group("Furniture Placement Colors")
@export var furniture_valid_area_color: Color = Color(0.2, 0.6, 1.0, 0.15)
@export var furniture_placed_color: Color = Color(0.6, 0.4, 0.2, 0.6)
@export var furniture_ghost_color: Color = Color(0.6, 0.4, 0.2, 0.4)

var _box_start: Vector2i
var _box_end: Vector2i
var _current_mouse_pos: Vector2i
var _drawing: bool = false
var _is_dragging: bool = false
var _door_placement_active: bool = false
var _furniture_placement_active: bool = false
var _current_room: RoomInstance
var _current_room_type: RoomTypeResource

# Furniture placement
var selected_furniture_id: String = ""
var current_rotation: int = 0

# UI elements for door/furniture placement
var _done_doors_button: Button
var _furniture_panel: PanelContainer
var _furniture_container: VBoxContainer
var _rotate_button: Button
var _complete_room_button: Button

func _ready() -> void:
	hide()  # Start hidden until build mode is activated
	_create_room_type_buttons()
	_create_door_done_button()
	_create_furniture_panel()

func show_all() -> void:
	show()
	if room_type_panel:
		room_type_panel.show()

func hide_all() -> void:
	hide()

func _create_room_type_buttons() -> void:
	var registry = RoomTypeRegistry.get_instance()

	for room_type in registry.get_all_room_types():
		var button = Button.new()
		button.text = room_type.display_name
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(160, 32)

		# Style the button for pixel art look
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.25, 0.22, 0.3, 1.0)
		style_normal.border_color = Color(0.5, 0.45, 0.4, 1.0)
		style_normal.set_border_width_all(2)
		style_normal.set_corner_radius_all(2)
		style_normal.set_content_margin_all(8)

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.35, 0.32, 0.4, 1.0)
		style_hover.border_color = Color(0.7, 0.6, 0.5, 1.0)
		style_hover.set_border_width_all(2)
		style_hover.set_corner_radius_all(2)
		style_hover.set_content_margin_all(8)

		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.18, 0.15, 0.22, 1.0)
		style_pressed.border_color = Color(0.6, 0.5, 0.4, 1.0)
		style_pressed.set_border_width_all(2)
		style_pressed.set_corner_radius_all(2)
		style_pressed.set_content_margin_all(8)

		button.add_theme_stylebox_override("normal", style_normal)
		button.add_theme_stylebox_override("hover", style_hover)
		button.add_theme_stylebox_override("pressed", style_pressed)
		button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9, 1.0))

		button.pressed.connect(func(): room_type_selected.emit(room_type.id))
		room_type_container.add_child(button)

func show_room_type_selection() -> void:
	info_label.text = "Select a room type"
	if room_type_panel:
		room_type_panel.show()

func show_drawing_instructions(room_type: RoomTypeResource = null) -> void:
	info_label.text = "Click and drag to draw room boundary"
	_drawing = true
	_is_dragging = false
	_current_room_type = room_type
	if room_type_panel:
		room_type_panel.hide()

func show_door_instructions(room: RoomInstance, room_type: RoomTypeResource) -> void:
	_drawing = false
	_is_dragging = false
	_door_placement_active = true
	_current_room = room
	_current_room_type = room_type
	info_label.text = "Click on walls to place doors"
	if _done_doors_button:
		_done_doors_button.show()
	queue_redraw()

func show_validation_errors(errors: Array[String]) -> void:
	var text = "Errors:\n"
	for error in errors:
		text += "• " + error + "\n"
	info_label.text = text

func _input(event: InputEvent) -> void:
	# Handle box drawing
	if _drawing:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_box_start = _screen_to_tile(event.global_position)
				_current_mouse_pos = _box_start
				_is_dragging = true
				queue_redraw()
			elif _is_dragging:
				_box_end = _screen_to_tile(event.global_position)
				_is_dragging = false
				_drawing = false
				queue_redraw()
				box_draw_completed.emit(_box_start, _box_end)
		elif event is InputEventMouseMotion and _is_dragging:
			_current_mouse_pos = _screen_to_tile(event.global_position)
			queue_redraw()
		return

	# Handle door placement
	if _door_placement_active:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tile_pos = _screen_to_tile(event.global_position)
			door_placed.emit(tile_pos)
			queue_redraw()
		elif event is InputEventMouseMotion:
			_current_mouse_pos = _screen_to_tile(event.global_position)
			queue_redraw()
		return

	# Handle furniture placement
	if _furniture_placement_active and selected_furniture_id != "":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tile_pos = _screen_to_tile(event.global_position)
			furniture_placed.emit(selected_furniture_id, tile_pos, current_rotation)
			queue_redraw()
		elif event is InputEventMouseMotion:
			_current_mouse_pos = _screen_to_tile(event.global_position)
			queue_redraw()

# Tile dimensions for isometric conversion (visual size after 0.5 scale)
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	# Convert screen position to world position
	var canvas_transform = get_viewport().get_canvas_transform()
	var world_pos = canvas_transform.affine_inverse() * screen_pos
	# Offset to align with tile center (adjust for tile origin)
	world_pos.y -= HALF_HEIGHT
	# Isometric to tile conversion
	var tile_x = (world_pos.x / HALF_WIDTH + world_pos.y / HALF_HEIGHT) / 2.0
	var tile_y = (world_pos.y / HALF_HEIGHT - world_pos.x / HALF_WIDTH) / 2.0
	return Vector2i(floor(tile_x), floor(tile_y))

func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	# Tile to isometric world position (top corner of tile)
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)

func _tile_to_screen(tile_pos: Vector2i) -> Vector2:
	var world_pos = _tile_to_world(tile_pos)
	var canvas_transform = get_viewport().get_canvas_transform()
	return canvas_transform * world_pos

func _draw() -> void:
	# Draw box selection preview during drag
	if _is_dragging:
		_draw_box_selection()
		return

	# Draw door placement hints
	if _door_placement_active and _current_room:
		_draw_door_placement_hints()
		return

	# Draw furniture placement hints
	if _furniture_placement_active and _current_room:
		_draw_furniture_placement_hints()

func _draw_box_selection() -> void:
	# Get the tile bounds (min/max corners)
	var min_tile = Vector2i(
		mini(_box_start.x, _current_mouse_pos.x),
		mini(_box_start.y, _current_mouse_pos.y)
	)
	var max_tile = Vector2i(
		maxi(_box_start.x, _current_mouse_pos.x),
		maxi(_box_start.y, _current_mouse_pos.y)
	)

	# Calculate current selection size
	var selection_size = max_tile - min_tile + Vector2i.ONE

	# Check if size is valid for the room type (allow swapped width/height)
	var is_valid_size = true
	if _current_room_type:
		var min_s = _current_room_type.min_size
		var max_s = _current_room_type.max_size
		# Check both orientations
		var normal_valid = selection_size.x >= min_s.x and selection_size.y >= min_s.y and selection_size.x <= max_s.x and selection_size.y <= max_s.y
		var swapped_valid = selection_size.x >= min_s.y and selection_size.y >= min_s.x and selection_size.x <= max_s.y and selection_size.y <= max_s.x
		is_valid_size = normal_valid or swapped_valid

	# Draw isometric diamond shape for the selection
	var top = _tile_to_screen(min_tile)
	var right = _tile_to_screen(Vector2i(max_tile.x + 1, min_tile.y))
	var bottom = _tile_to_screen(Vector2i(max_tile.x + 1, max_tile.y + 1))
	var left = _tile_to_screen(Vector2i(min_tile.x, max_tile.y + 1))

	var points = PackedVector2Array([top, right, bottom, left])

	# Use red for invalid size, blue for valid
	var fill_color: Color
	var border_color: Color
	if is_valid_size:
		fill_color = selection_valid_fill
		border_color = selection_valid_border
	else:
		fill_color = selection_invalid_fill
		border_color = selection_invalid_border

	draw_colored_polygon(points, fill_color)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), border_color, 2.0)

func _draw_door_placement_hints() -> void:
	var door_op = DoorOperation.new()
	# Draw all valid door positions
	for wall_pos in _current_room.walls:
		var is_door = false
		for door in _current_room.doors:
			if door.position == wall_pos:
				is_door = true
				break

		if is_door:
			_draw_tile_highlight(wall_pos, door_placed_color)
		elif door_op.is_valid_door_position(wall_pos, _current_room):
			_draw_tile_highlight(wall_pos, door_valid_color)
		else:
			_draw_tile_highlight(wall_pos, door_wall_color)

	# Highlight current hover position
	if _current_mouse_pos in _current_room.walls:
		if door_op.is_valid_door_position(_current_mouse_pos, _current_room):
			_draw_tile_highlight(_current_mouse_pos, door_hover_color)

func _draw_furniture_placement_hints() -> void:
	if not _current_room:
		return

	# Draw room interior (valid placement area)
	var bbox = _current_room.bounding_box
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			if pos not in _current_room.walls:
				_draw_tile_highlight(pos, furniture_valid_area_color)

	# Draw placed furniture
	for furn in _current_room.furniture:
		_draw_tile_highlight(furn.position, furniture_placed_color)

	# Draw ghost at cursor if furniture selected
	if selected_furniture_id != "":
		var hover_pos = _current_mouse_pos
		var bbox_rect = _current_room.bounding_box
		var in_room = hover_pos.x >= bbox_rect.position.x and hover_pos.x < bbox_rect.position.x + bbox_rect.size.x
		in_room = in_room and hover_pos.y >= bbox_rect.position.y and hover_pos.y < bbox_rect.position.y + bbox_rect.size.y
		in_room = in_room and hover_pos not in _current_room.walls
		if in_room:
			_draw_tile_highlight(hover_pos, furniture_ghost_color)

func _draw_tile_highlight(tile_pos: Vector2i, color: Color) -> void:
	var top = _tile_to_screen(tile_pos)
	var right = _tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y))
	var bottom = _tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y + 1))
	var left = _tile_to_screen(Vector2i(tile_pos.x, tile_pos.y + 1))

	var points = PackedVector2Array([top, right, bottom, left])
	draw_colored_polygon(points, color)

func _create_door_done_button() -> void:
	_done_doors_button = Button.new()
	_done_doors_button.text = "Done Placing Doors"
	_done_doors_button.custom_minimum_size = Vector2(180, 40)
	_apply_button_style(_done_doors_button)
	_done_doors_button.pressed.connect(_on_done_doors_pressed)
	_done_doors_button.hide()

	# Position at bottom center
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	center_container.offset_top = -60
	center_container.offset_bottom = -10
	center_container.add_child(_done_doors_button)
	add_child(center_container)

func _create_furniture_panel() -> void:
	# Create panel container for furniture selection
	_furniture_panel = PanelContainer.new()
	_furniture_panel.custom_minimum_size = Vector2(200, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.18, 0.95)
	style.border_color = Color(0.4, 0.35, 0.3, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	_furniture_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	_furniture_container = VBoxContainer.new()
	_furniture_container.add_theme_constant_override("separation", 6)

	var title_label = Label.new()
	title_label.text = "Furniture"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8))
	_furniture_container.add_child(title_label)

	# Rotate button
	_rotate_button = Button.new()
	_rotate_button.text = "Rotate (0°)"
	_rotate_button.custom_minimum_size = Vector2(160, 32)
	_apply_button_style(_rotate_button)
	_rotate_button.pressed.connect(_on_rotate_pressed)
	_furniture_container.add_child(_rotate_button)

	# Complete room button
	_complete_room_button = Button.new()
	_complete_room_button.text = "Complete Room"
	_complete_room_button.custom_minimum_size = Vector2(160, 36)
	_apply_button_style(_complete_room_button, Color(0.2, 0.5, 0.3))
	_complete_room_button.pressed.connect(_on_complete_room_pressed)
	_furniture_container.add_child(_complete_room_button)

	margin.add_child(_furniture_container)
	_furniture_panel.add_child(margin)

	# Position on right side
	_furniture_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_furniture_panel.offset_left = -220
	_furniture_panel.offset_right = -10

	add_child(_furniture_panel)
	_furniture_panel.hide()

func _apply_button_style(button: Button, base_color: Color = Color(0.25, 0.22, 0.3)) -> void:
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = base_color
	style_normal.border_color = Color(0.5, 0.45, 0.4, 1.0)
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(2)
	style_normal.set_content_margin_all(8)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = base_color.lightened(0.15)
	style_hover.border_color = Color(0.7, 0.6, 0.5, 1.0)
	style_hover.set_border_width_all(2)
	style_hover.set_corner_radius_all(2)
	style_hover.set_content_margin_all(8)

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = base_color.darkened(0.15)
	style_pressed.border_color = Color(0.6, 0.5, 0.4, 1.0)
	style_pressed.set_border_width_all(2)
	style_pressed.set_corner_radius_all(2)
	style_pressed.set_content_margin_all(8)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.9, 1.0))

func _on_done_doors_pressed() -> void:
	_door_placement_active = false
	if _done_doors_button:
		_done_doors_button.hide()
	queue_redraw()
	doors_done.emit()

func _on_rotate_pressed() -> void:
	current_rotation = (current_rotation + 1) % 4
	var degrees = current_rotation * 90
	_rotate_button.text = "Rotate (%d°)" % degrees
	queue_redraw()

func _on_complete_room_pressed() -> void:
	complete_pressed.emit()

func show_furniture_panel(room: RoomInstance, room_type: RoomTypeResource) -> void:
	_furniture_placement_active = true
	_current_room = room
	_current_room_type = room_type
	selected_furniture_id = ""
	current_rotation = 0
	_rotate_button.text = "Rotate (0°)"

	info_label.text = "Select and place furniture"

	# Clear existing furniture buttons (keep title at 0, rotate at 1, complete at end)
	var children = _furniture_container.get_children()
	for i in range(children.size() - 1, 1, -1):  # Process from end down to index 2
		var child = children[i]
		if child != _rotate_button and child != _complete_room_button:
			_furniture_container.remove_child(child)
			child.queue_free()

	# Move complete button to end by removing and re-adding
	if _complete_room_button.get_parent() == _furniture_container:
		_furniture_container.remove_child(_complete_room_button)

	# Add furniture buttons
	_populate_furniture_buttons(room_type)

	# Re-add complete button at end
	_furniture_container.add_child(_complete_room_button)

	_furniture_panel.show()
	queue_redraw()

func _populate_furniture_buttons(room_type: RoomTypeResource) -> void:
	var required = room_type.get_required_furniture_dict()
	var furniture_registry = FurnitureRegistry.get_instance()

	# Create buttons for required furniture first
	for furniture_id in required.keys():
		var required_count = required[furniture_id]
		var actual_count = _current_room.get_furniture_count(furniture_id) if _current_room else 0
		var furn = furniture_registry.get_furniture(furniture_id)
		var display_name = furn.name if furn else furniture_id

		var btn = Button.new()
		btn.text = "%s (%d/%d)" % [display_name, actual_count, required_count]
		btn.custom_minimum_size = Vector2(160, 32)
		btn.set_meta("furniture_id", furniture_id)
		btn.set_meta("required_count", required_count)
		_apply_button_style(btn, Color(0.4, 0.25, 0.2))  # Reddish for required
		btn.pressed.connect(_on_furniture_button_pressed.bind(furniture_id))
		_furniture_container.add_child(btn)

	# Create buttons for optional allowed furniture
	for furniture_id in room_type.allowed_furniture:
		if furniture_id in required.keys():
			continue  # Skip if already in required
		var furn = furniture_registry.get_furniture(furniture_id)
		var display_name = furn.name if furn else furniture_id

		var btn = Button.new()
		btn.text = display_name
		btn.custom_minimum_size = Vector2(160, 32)
		btn.set_meta("furniture_id", furniture_id)
		_apply_button_style(btn)
		btn.pressed.connect(_on_furniture_button_pressed.bind(furniture_id))
		_furniture_container.add_child(btn)

func _on_furniture_button_pressed(furniture_id: String) -> void:
	selected_furniture_id = furniture_id
	furniture_selected.emit(furniture_id)
	info_label.text = "Click to place: " + furniture_id
	queue_redraw()

func update_furniture_counts() -> void:
	if not _current_room or not _current_room_type:
		return

	var furniture_registry = FurnitureRegistry.get_instance()

	for child in _furniture_container.get_children():
		if child is Button and child.has_meta("furniture_id"):
			var furniture_id = child.get_meta("furniture_id")
			var actual_count = _current_room.get_furniture_count(furniture_id)
			var furn = furniture_registry.get_furniture(furniture_id)
			var display_name = furn.name if furn else furniture_id

			if child.has_meta("required_count"):
				var required_count = child.get_meta("required_count")
				child.text = "%s (%d/%d)" % [display_name, actual_count, required_count]
			elif actual_count > 0:
				child.text = "%s (%d)" % [display_name, actual_count]
			else:
				child.text = display_name

func hide_furniture_panel() -> void:
	_furniture_placement_active = false
	selected_furniture_id = ""
	if _furniture_panel:
		_furniture_panel.hide()
	queue_redraw()

func end_all_modes() -> void:
	_drawing = false
	_is_dragging = false
	_door_placement_active = false
	_furniture_placement_active = false
	_current_room = null
	_current_room_type = null
	selected_furniture_id = ""
	if _done_doors_button:
		_done_doors_button.hide()
	if _furniture_panel:
		_furniture_panel.hide()
	queue_redraw()
