class_name FurnitureSelectionHighlight
extends Control

## Visual highlight for selected furniture.
## Draws a semi-transparent cyan tint over the selected furniture's tiles.
## Must be wrapped in CanvasLayer by Main.gd for correct screen-space rendering.

# Distinct cyan color (different from room selection yellow)
const SELECTION_COLOR := Color(0.2, 0.8, 1.0, 0.4)  # Semi-transparent cyan
const ACCESS_TILE_COLOR := Color(0.2, 0.8, 1.0, 0.2)  # Lighter cyan for access tiles
const DRAG_VALID_COLOR := Color(0.2, 0.8, 0.4, 0.5)  # Green for valid placement
const DRAG_INVALID_COLOR := Color(0.9, 0.2, 0.2, 0.5)  # Red for invalid placement
const DRAG_ACCESS_VALID_COLOR := Color(0.2, 0.8, 0.4, 0.25)  # Lighter green for access tiles
const DRAG_ACCESS_INVALID_COLOR := Color(0.9, 0.2, 0.2, 0.25)  # Lighter red for access tiles

# Controller reference (set by Main.gd)
var _controller: FurnitureEditController = null

# Drag preview state
var _is_dragging: bool = false
var _drag_preview_position: Vector2i = Vector2i.ZERO
var _drag_preview_valid: bool = false


func _ready() -> void:
	# Controller reference set by Main.gd after instantiation
	pass


func set_controller(controller: FurnitureEditController) -> void:
	if _controller != null:
		# Disconnect from previous controller if any
		if _controller.furniture_selected.is_connected(_on_furniture_selected):
			_controller.furniture_selected.disconnect(_on_furniture_selected)
		if _controller.furniture_deselected.is_connected(_on_furniture_deselected):
			_controller.furniture_deselected.disconnect(_on_furniture_deselected)
		if _controller.mode_exited.is_connected(_on_mode_exited):
			_controller.mode_exited.disconnect(_on_mode_exited)
		if _controller.furniture_drag_preview.is_connected(_on_drag_preview):
			_controller.furniture_drag_preview.disconnect(_on_drag_preview)
		if _controller.furniture_drag_ended.is_connected(_on_drag_ended):
			_controller.furniture_drag_ended.disconnect(_on_drag_ended)

	_controller = controller

	if _controller != null:
		_controller.furniture_selected.connect(_on_furniture_selected)
		_controller.furniture_deselected.connect(_on_furniture_deselected)
		_controller.mode_exited.connect(_on_mode_exited)
		_controller.furniture_drag_preview.connect(_on_drag_preview)
		_controller.furniture_drag_ended.connect(_on_drag_ended)


func _on_furniture_selected(_room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	queue_redraw()


func _on_furniture_deselected() -> void:
	queue_redraw()


func _on_mode_exited() -> void:
	queue_redraw()


func _on_drag_preview(position: Vector2i, is_valid: bool) -> void:
	_is_dragging = true
	_drag_preview_position = position
	_drag_preview_valid = is_valid
	queue_redraw()


func _on_drag_ended() -> void:
	_is_dragging = false
	queue_redraw()


func _draw() -> void:
	if _controller == null:
		return

	var furniture := _controller.get_selected_furniture()
	if furniture == null:
		return

	var viewport := get_viewport()

	# During drag, show preview at drag position
	if _is_dragging:
		_draw_drag_preview(furniture, viewport)
		return

	# Normal selection highlight when not dragging
	# Draw access tiles first (lighter color, shows where patrons stand)
	var access_tiles := furniture.get_access_tiles()
	for tile in access_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, ACCESS_TILE_COLOR, viewport)

	# Draw occupied tiles on top (main selection highlight)
	var occupied_tiles := furniture.get_occupied_tiles()
	for tile in occupied_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, SELECTION_COLOR, viewport)


func _draw_drag_preview(furniture: RoomInstance.FurniturePlacement, viewport: Viewport) -> void:
	# Calculate tiles at preview position (not current furniture.position)
	var furn_resource := furniture.furniture
	if furn_resource == null:
		return

	# Get footprint tiles at preview position
	var preview_tiles := RotationHelper.get_footprint_tiles(
		_drag_preview_position,
		furn_resource.size,
		furniture.rotation
	)

	# Get access tiles at preview position
	var access_offsets := furn_resource.get_rotated_access_tiles(furniture.rotation)
	var preview_access_tiles: Array[Vector2i] = []
	for offset in access_offsets:
		preview_access_tiles.append(_drag_preview_position + offset)

	# Choose colors based on validity
	var tile_color: Color
	var access_color: Color
	if _drag_preview_valid:
		tile_color = DRAG_VALID_COLOR
		access_color = DRAG_ACCESS_VALID_COLOR
	else:
		tile_color = DRAG_INVALID_COLOR
		access_color = DRAG_ACCESS_INVALID_COLOR

	# Draw access tiles first
	for tile in preview_access_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, access_color, viewport)

	# Draw footprint tiles on top
	for tile in preview_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, tile_color, viewport)

	# Also draw original position faintly (ghost showing where it was)
	var original_tiles := furniture.get_occupied_tiles()
	for tile in original_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, Color(0.5, 0.5, 0.5, 0.2), viewport)
