class_name RoomResizeHighlight
extends Control

## Visual highlight for room resize preview.
## Renders box preview during drag with valid/invalid coloring.
## Follows DoorEditHighlight pattern for controller signal connection.
## Must be wrapped in CanvasLayer by Main.gd for correct screen-space rendering.

# Colors (matching RoomBuildUI pattern)
const VALID_FILL := Color(0.2, 0.8, 0.4, 0.2)        # Light green fill
const VALID_BORDER := Color(0.2, 0.8, 0.4, 1.0)      # Green border
const VALID_WALL := Color(0.2, 0.8, 0.4, 0.6)        # Green walls
const INVALID_FILL := Color(0.9, 0.2, 0.2, 0.2)      # Light red fill
const INVALID_BORDER := Color(0.9, 0.2, 0.2, 1.0)    # Red border
const INVALID_WALL := Color(0.9, 0.2, 0.2, 0.6)      # Red walls
const BLOCKED_FURNITURE := Color(1.0, 0.5, 0.0, 0.6) # Orange for blocked furniture
const BLOCKED_ACCESS := Color(1.0, 0.5, 0.0, 0.3)    # Lighter orange for blocked access tiles

# Controller reference (set by Main.gd)
var _controller: RoomResizeController = null

# Preview state (updated via signals from controller)
var _current_box: Rect2i = Rect2i()
var _is_valid: bool = false
var _blocked_furniture: Array[RoomInstance.FurniturePlacement] = []


func _ready() -> void:
	# Controller reference set by Main.gd after instantiation
	pass


func set_controller(controller: RoomResizeController) -> void:
	if _controller != null:
		# Disconnect from previous controller
		if _controller.preview_updated.is_connected(_on_preview_updated):
			_controller.preview_updated.disconnect(_on_preview_updated)
		if _controller.resize_cancelled.is_connected(_on_resize_cancelled):
			_controller.resize_cancelled.disconnect(_on_resize_cancelled)
		if _controller.resize_completed.is_connected(_on_resize_completed):
			_controller.resize_completed.disconnect(_on_resize_completed)

	_controller = controller

	if _controller != null:
		_controller.preview_updated.connect(_on_preview_updated)
		_controller.resize_cancelled.connect(_on_resize_cancelled)
		_controller.resize_completed.connect(_on_resize_completed)


func _on_preview_updated(new_box: Rect2i, validation: RefCounted) -> void:
	_current_box = new_box
	if validation != null:
		_is_valid = validation.is_valid
		_blocked_furniture = validation.blocked_furniture
	else:
		_is_valid = false
		_blocked_furniture = []
	queue_redraw()


func _on_resize_cancelled() -> void:
	_current_box = Rect2i()
	_blocked_furniture = []
	queue_redraw()


func _on_resize_completed(_room: RoomInstance) -> void:
	_current_box = Rect2i()
	_blocked_furniture = []
	queue_redraw()


func _draw() -> void:
	if _controller == null or not _controller.is_active():
		return

	if _current_box.size == Vector2i.ZERO:
		return

	_draw_preview_box()
	_draw_blocked_furniture()


func _draw_preview_box() -> void:
	# Choose colors based on validity
	var fill_color: Color
	var wall_color: Color
	var border_color: Color
	if _is_valid:
		fill_color = VALID_FILL
		wall_color = VALID_WALL
		border_color = VALID_BORDER
	else:
		fill_color = INVALID_FILL
		wall_color = INVALID_WALL
		border_color = INVALID_BORDER

	var min_tile = _current_box.position
	var max_tile = _current_box.position + _current_box.size - Vector2i.ONE
	var viewport := get_viewport()

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
			RoomBuildDrawing.draw_tile_highlight(self, Vector2i(x, y), fill_color, viewport)

	# Draw wall tiles on top
	for wall_pos in wall_positions:
		RoomBuildDrawing.draw_tile_highlight(self, wall_pos, wall_color, viewport)

	# Draw outer border polyline
	var top = IsometricMath.tile_to_screen(min_tile, viewport)
	var right = IsometricMath.tile_to_screen(Vector2i(max_tile.x + 1, min_tile.y), viewport)
	var bottom = IsometricMath.tile_to_screen(Vector2i(max_tile.x + 1, max_tile.y + 1), viewport)
	var left = IsometricMath.tile_to_screen(Vector2i(min_tile.x, max_tile.y + 1), viewport)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), border_color, 2.0)


func _draw_blocked_furniture() -> void:
	if _is_valid or _blocked_furniture.is_empty():
		return

	var viewport := get_viewport()

	# Highlight blocked furniture tiles in orange
	for furn in _blocked_furniture:
		# Draw access tiles first (lighter orange)
		for tile in furn.get_access_tiles():
			RoomBuildDrawing.draw_tile_highlight(self, tile, BLOCKED_ACCESS, viewport)
		# Draw footprint tiles on top (darker orange)
		for tile in furn.get_occupied_tiles():
			RoomBuildDrawing.draw_tile_highlight(self, tile, BLOCKED_FURNITURE, viewport)
