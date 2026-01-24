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

	_controller = controller

	if _controller != null:
		_controller.furniture_selected.connect(_on_furniture_selected)
		_controller.furniture_deselected.connect(_on_furniture_deselected)
		_controller.mode_exited.connect(_on_mode_exited)


func _on_furniture_selected(_room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	queue_redraw()


func _on_furniture_deselected() -> void:
	queue_redraw()


func _on_mode_exited() -> void:
	queue_redraw()


func _draw() -> void:
	if _controller == null:
		return

	var furniture := _controller.get_selected_furniture()
	if furniture == null:
		return

	var viewport := get_viewport()

	# Draw access tiles first (lighter color, shows where patrons stand)
	var access_tiles := furniture.get_access_tiles()
	for tile in access_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, ACCESS_TILE_COLOR, viewport)

	# Draw occupied tiles on top (main selection highlight)
	var occupied_tiles := furniture.get_occupied_tiles()
	for tile in occupied_tiles:
		RoomBuildDrawing.draw_tile_highlight(self, tile, SELECTION_COLOR, viewport)
