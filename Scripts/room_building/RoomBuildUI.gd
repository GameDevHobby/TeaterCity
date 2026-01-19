class_name RoomBuildUI
extends Control

signal room_type_selected(room_type_id: String)
signal box_draw_completed(start: Vector2i, end: Vector2i)
signal door_placed(position: Vector2i)
signal doors_done
signal furniture_selected(furniture: FurnitureResource)
signal furniture_placed(furniture: FurnitureResource, position: Vector2i, rotation: int)
signal complete_pressed

@export var room_type_container: Container
@export var info_label: Label
@export var room_type_panel: PanelContainer
@export var tilemap_layer: TileMapLayer  # For proper isometric coordinate conversion

@export_group("Furniture Panel")
@export var furniture_panel: PanelContainer
@export var furniture_container: VBoxContainer
@export var rotate_button: Button
@export var complete_room_button: Button

@export_group("Door Placement")
@export var door_panel: PanelContainer
@export var done_doors_button: Button

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
@export var access_tile_color: Color = Color(0.2, 0.8, 0.2, 0.3)
@export var blocked_access_color: Color = Color(0.8, 0.2, 0.2, 0.3)

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
var _selected_furniture: FurnitureResource
var current_rotation: int = 0
var _preview_sprite: Sprite2D
var _furniture_operation: FurnitureOperation
var _collision_operation: CollisionOperation
var _preview_textures: Dictionary = {}  # Cache for generated preview textures

# UI references (assigned via @export from scene)

func _ready() -> void:
	hide()  # Start hidden until build mode is activated
	_create_room_type_buttons()
	_setup_ui_styles()
	_connect_ui_signals()
	_furniture_operation = FurnitureOperation.new()
	_collision_operation = CollisionOperation.new()
	_setup_preview_sprite()

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
	if door_panel:
		door_panel.show()
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
	if _furniture_placement_active and _selected_furniture:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var tile_pos = _screen_to_tile(event.global_position)
			furniture_placed.emit(_selected_furniture, tile_pos, current_rotation)
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

	# Choose colors based on validity
	var wall_color: Color
	var interior_color: Color
	if is_valid_size:
		wall_color = selection_valid_border.lerp(Color.WHITE, 0.2)
		wall_color.a = 0.6
		interior_color = selection_valid_fill
	else:
		wall_color = selection_invalid_border.lerp(Color.WHITE, 0.2)
		wall_color.a = 0.6
		interior_color = selection_invalid_fill

	# Generate wall positions (same logic as WallOperation.generate_walls)
	var wall_positions: Array[Vector2i] = []
	for x in range(min_tile.x, max_tile.x + 1):
		wall_positions.append(Vector2i(x, min_tile.y))
		wall_positions.append(Vector2i(x, max_tile.y))
	for y in range(min_tile.y + 1, max_tile.y):
		wall_positions.append(Vector2i(min_tile.x, y))
		wall_positions.append(Vector2i(max_tile.x, y))

	# Draw interior tiles first (lighter color)
	for x in range(min_tile.x + 1, max_tile.x):
		for y in range(min_tile.y + 1, max_tile.y):
			_draw_tile_highlight(Vector2i(x, y), interior_color)

	# Draw wall tiles on top
	for wall_pos in wall_positions:
		_draw_tile_highlight(wall_pos, wall_color)

	# Draw outer border
	var top = _tile_to_screen(min_tile)
	var right = _tile_to_screen(Vector2i(max_tile.x + 1, min_tile.y))
	var bottom = _tile_to_screen(Vector2i(max_tile.x + 1, max_tile.y + 1))
	var left = _tile_to_screen(Vector2i(min_tile.x, max_tile.y + 1))
	var border_color = selection_valid_border if is_valid_size else selection_invalid_border
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

	# Draw placed furniture (showing footprint and access tiles)
	for furn in _current_room.furniture:
		# Draw access tiles first (lighter color)
		for tile in furn.get_access_tiles():
			_draw_tile_highlight(tile, access_tile_color)
		# Draw footprint tiles on top
		for tile in furn.get_occupied_tiles():
			_draw_tile_highlight(tile, furniture_placed_color)

	# Draw ghost at cursor if furniture selected (showing full footprint and access tiles)
	if _selected_furniture:
		var hover_pos = _current_mouse_pos

		# Use CollisionOperation to get preview including access tiles
		var preview = _collision_operation.get_placement_preview(
			_selected_furniture, hover_pos, current_rotation, _current_room
		)

		# Draw access tiles first (so furniture tiles draw on top)
		for tile in preview.valid_access_tiles:
			_draw_tile_highlight(tile, access_tile_color)
		for tile in preview.blocked_access_tiles:
			_draw_tile_highlight(tile, blocked_access_color)

		# Draw footprint ghost tiles
		for tile in preview.valid_tiles:
			_draw_tile_highlight(tile, furniture_ghost_color)
		for tile in preview.blocked_tiles:
			_draw_tile_highlight(tile, Color(1.0, 0.2, 0.2, 0.5))  # Red for blocked

		# Position and show preview sprite at cursor
		# The generated placeholder texture has tile (0,0) at a specific position in the image
		# We need to offset the sprite so tile (0,0) aligns with hover_pos
		if _preview_sprite and _preview_sprite.texture:
			var furn_size = _selected_furniture.size
			if current_rotation == 1 or current_rotation == 3:
				furn_size = Vector2i(furn_size.y, furn_size.x)

			# Get camera zoom scale from canvas transform
			var canvas_transform = get_viewport().get_canvas_transform()
			var zoom_scale = canvas_transform.get_scale()

			# In the placeholder texture, tile (0,0)'s top point is at x = furn_size.y * HALF_WIDTH, y = 0
			# With centered=false, sprite position is top-left corner
			# We want tile (0,0)'s top to align with the screen position of hover_pos
			var tile_00_x = furn_size.y * HALF_WIDTH

			# Position sprite's top-left so tile (0,0) top aligns with hover_pos
			# Account for zoom: offset must be scaled
			var base_pos = _tile_to_screen(hover_pos)
			_preview_sprite.position = base_pos - Vector2(tile_00_x * zoom_scale.x, 0)
			_preview_sprite.scale = zoom_scale
			_preview_sprite.modulate = Color(1, 1, 1, 0.7)
			_preview_sprite.show()
	else:
		if _preview_sprite:
			_preview_sprite.hide()

func _get_furniture_footprint(pos: Vector2i, furniture: FurnitureResource, rot: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not furniture:
		tiles.append(pos)
		return tiles

	var furn_size = furniture.size
	# Handle rotation - swap dimensions for 90/270 degree rotations
	if rot == 1 or rot == 3:
		furn_size = Vector2i(furn_size.y, furn_size.x)

	for x in range(furn_size.x):
		for y in range(furn_size.y):
			tiles.append(pos + Vector2i(x, y))
	return tiles

func _is_tile_valid_for_furniture(pos: Vector2i) -> bool:
	if not _current_room:
		return false

	var bbox = _current_room.bounding_box
	var in_bounds = pos.x >= bbox.position.x and pos.x < bbox.position.x + bbox.size.x
	in_bounds = in_bounds and pos.y >= bbox.position.y and pos.y < bbox.position.y + bbox.size.y

	if not in_bounds:
		return false

	if pos in _current_room.walls:
		return false

	if _current_room.is_tile_occupied(pos):
		return false

	return true

func _draw_tile_highlight(tile_pos: Vector2i, color: Color) -> void:
	var top = _tile_to_screen(tile_pos)
	var right = _tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y))
	var bottom = _tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y + 1))
	var left = _tile_to_screen(Vector2i(tile_pos.x, tile_pos.y + 1))

	var points = PackedVector2Array([top, right, bottom, left])
	draw_colored_polygon(points, color)

func _setup_ui_styles() -> void:
	# Apply styles to scene nodes
	if done_doors_button:
		_apply_button_style(done_doors_button)

	if door_panel:
		var door_style = StyleBoxFlat.new()
		door_style.bg_color = Color(0.15, 0.12, 0.18, 0.95)
		door_style.border_color = Color(0.4, 0.35, 0.3, 1.0)
		door_style.set_border_width_all(2)
		door_style.set_corner_radius_all(4)
		door_style.set_content_margin_all(10)
		door_panel.add_theme_stylebox_override("panel", door_style)

	if furniture_panel:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.12, 0.18, 0.95)
		style.border_color = Color(0.4, 0.35, 0.3, 1.0)
		style.set_border_width_all(2)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(10)
		furniture_panel.add_theme_stylebox_override("panel", style)

	if rotate_button:
		_apply_button_style(rotate_button)

	if complete_room_button:
		_apply_button_style(complete_room_button, Color(0.2, 0.5, 0.3))

func _connect_ui_signals() -> void:
	if done_doors_button:
		done_doors_button.pressed.connect(_on_done_doors_pressed)

	if rotate_button:
		rotate_button.pressed.connect(_on_rotate_pressed)

	if complete_room_button:
		complete_room_button.pressed.connect(_on_complete_room_pressed)

func _setup_preview_sprite() -> void:
	# Create a preview sprite that will be reparented to world when needed
	_preview_sprite = Sprite2D.new()
	_preview_sprite.name = "FurniturePreviewSprite"
	_preview_sprite.centered = false  # Position from top-left for easier alignment
	_preview_sprite.hide()
	add_child(_preview_sprite)

func _update_preview_sprite() -> void:
	if not _selected_furniture or not _preview_sprite:
		if _preview_sprite:
			_preview_sprite.hide()
		return

	# Try to get preview sprite from resource's preview_sprites
	var sprite_path = _selected_furniture.get_preview_sprite_for_rotation(current_rotation)
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var texture = load(sprite_path)
		if texture:
			_preview_sprite.texture = texture
			_preview_sprite.show()
			return

	# Fallback: generate placeholder or use cached
	var cache_key = _selected_furniture.id + "_" + str(current_rotation)
	if not _preview_textures.has(cache_key):
		var all_textures = _furniture_operation.generate_placeholder_sprites(_selected_furniture)
		var direction_names = ["north", "east", "south", "west"]
		for rot in range(4):
			var key = _selected_furniture.id + "_" + str(rot)
			_preview_textures[key] = all_textures[direction_names[rot]]

	_preview_sprite.texture = _preview_textures[cache_key]
	_preview_sprite.show()

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
	if door_panel:
		door_panel.hide()
	queue_redraw()
	doors_done.emit()

func _on_rotate_pressed() -> void:
	current_rotation = (current_rotation + 1) % 4
	var degrees = current_rotation * 90
	rotate_button.text = "Rotate (%d°)" % degrees
	_update_preview_sprite()
	queue_redraw()

func _on_complete_room_pressed() -> void:
	complete_pressed.emit()

func show_furniture_panel(room: RoomInstance, room_type: RoomTypeResource) -> void:
	_furniture_placement_active = true
	_current_room = room
	_current_room_type = room_type
	_selected_furniture = null
	current_rotation = 0
	rotate_button.text = "Rotate (0°)"

	info_label.text = "Select and place furniture"

	# Clear existing furniture buttons (keep title at 0, rotate at 1, complete at end)
	var children = furniture_container.get_children()
	for i in range(children.size() - 1, 1, -1):  # Process from end down to index 2
		var child = children[i]
		if child != rotate_button and child != complete_room_button:
			furniture_container.remove_child(child)
			child.queue_free()

	# Move complete button to end by removing and re-adding
	if complete_room_button.get_parent() == furniture_container:
		furniture_container.remove_child(complete_room_button)

	# Add furniture buttons
	_populate_furniture_buttons(room_type)

	# Re-add complete button at end
	furniture_container.add_child(complete_room_button)

	furniture_panel.show()
	queue_redraw()

func _populate_furniture_buttons(room_type: RoomTypeResource) -> void:
	var required_furniture_set: Array[FurnitureResource] = []

	# Create buttons for required furniture first
	for req in room_type.get_required_furniture():
		if not req.furniture:
			continue
		required_furniture_set.append(req.furniture)
		var actual_count = _current_room.get_furniture_count_by_resource(req.furniture) if _current_room else 0
		var display_name = req.furniture.name if req.furniture.name else req.furniture.id

		var btn = Button.new()
		btn.text = "%s (%d/%d)" % [display_name, actual_count, req.count]
		btn.custom_minimum_size = Vector2(160, 32)
		btn.set_meta("furniture", req.furniture)
		btn.set_meta("required_count", req.count)
		_apply_button_style(btn, Color(0.4, 0.25, 0.2))  # Reddish for required
		btn.pressed.connect(_on_furniture_button_pressed.bind(req.furniture))
		furniture_container.add_child(btn)

	# Create buttons for optional allowed furniture
	for furn in room_type.allowed_furniture:
		if furn in required_furniture_set:
			continue  # Skip if already in required
		var display_name = furn.name if furn.name else furn.id

		var btn = Button.new()
		btn.text = display_name
		btn.custom_minimum_size = Vector2(160, 32)
		btn.set_meta("furniture", furn)
		_apply_button_style(btn)
		btn.pressed.connect(_on_furniture_button_pressed.bind(furn))
		furniture_container.add_child(btn)

func _on_furniture_button_pressed(furniture: FurnitureResource) -> void:
	_selected_furniture = furniture
	furniture_selected.emit(furniture)
	var display_name = furniture.name if furniture.name else furniture.id
	info_label.text = "Click to place: " + display_name
	_update_preview_sprite()
	queue_redraw()

func update_furniture_counts() -> void:
	if not _current_room or not _current_room_type:
		return

	for child in furniture_container.get_children():
		if child is Button and child.has_meta("furniture"):
			var furn: FurnitureResource = child.get_meta("furniture")
			var actual_count = _current_room.get_furniture_count_by_resource(furn)
			var display_name = furn.name if furn.name else furn.id

			if child.has_meta("required_count"):
				var required_count = child.get_meta("required_count")
				child.text = "%s (%d/%d)" % [display_name, actual_count, required_count]
			elif actual_count > 0:
				child.text = "%s (%d)" % [display_name, actual_count]
			else:
				child.text = display_name

func hide_furniture_panel() -> void:
	_furniture_placement_active = false
	_selected_furniture = null
	if furniture_panel:
		furniture_panel.hide()
	if _preview_sprite:
		_preview_sprite.hide()
	queue_redraw()

func end_all_modes() -> void:
	_drawing = false
	_is_dragging = false
	_door_placement_active = false
	_furniture_placement_active = false
	_current_room = null
	_current_room_type = null
	_selected_furniture = null
	if door_panel:
		door_panel.hide()
	if furniture_panel:
		furniture_panel.hide()
	if _preview_sprite:
		_preview_sprite.hide()
	queue_redraw()
