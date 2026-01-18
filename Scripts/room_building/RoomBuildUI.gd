class_name RoomBuildUI
extends Control

signal room_type_selected(room_type_id: String)
signal box_draw_completed(start: Vector2i, end: Vector2i)
signal door_placed(position: Vector2i)
signal complete_pressed

@export var room_type_container: Container
@export var info_label: Label
@export var room_type_panel: PanelContainer

var _box_start: Vector2i
var _box_end: Vector2i
var _current_mouse_pos: Vector2i
var _drawing: bool = false
var _is_dragging: bool = false

func _ready() -> void:
	hide()  # Start hidden until build mode is activated
	_create_room_type_buttons()

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

func show_drawing_instructions() -> void:
	info_label.text = "Click and drag to draw room boundary"
	_drawing = true
	_is_dragging = false
	if room_type_panel:
		room_type_panel.hide()

func show_door_instructions() -> void:
	_drawing = false
	_is_dragging = false
	info_label.text = "Click on walls to place doors"

func show_validation_errors(errors: Array[String]) -> void:
	var text = "Errors:\n"
	for error in errors:
		text += "• " + error + "\n"
	info_label.text = text

func _input(event: InputEvent) -> void:
	if not _drawing:
		return

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
	if not _is_dragging:
		return

	# Get the tile bounds (min/max corners)
	var min_tile = Vector2i(
		mini(_box_start.x, _current_mouse_pos.x),
		mini(_box_start.y, _current_mouse_pos.y)
	)
	var max_tile = Vector2i(
		maxi(_box_start.x, _current_mouse_pos.x),
		maxi(_box_start.y, _current_mouse_pos.y)
	)

	# Draw isometric diamond shape for the selection
	# Four corners of isometric rectangle:
	# Top: min_x, min_y
	# Right: max_x, min_y
	# Bottom: max_x, max_y
	# Left: min_x, max_y
	var top = _tile_to_screen(min_tile)
	var right = _tile_to_screen(Vector2i(max_tile.x + 1, min_tile.y))
	var bottom = _tile_to_screen(Vector2i(max_tile.x + 1, max_tile.y + 1))
	var left = _tile_to_screen(Vector2i(min_tile.x, max_tile.y + 1))

	var points = PackedVector2Array([top, right, bottom, left])

	draw_colored_polygon(points, Color(0.2, 0.6, 1.0, 0.3))  # Fill
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), Color(0.2, 0.6, 1.0, 1.0), 2.0)  # Border
