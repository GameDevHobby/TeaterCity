class_name RoomSelectionHighlight
extends Control

## Visual highlight for selected rooms.
## Draws a semi-transparent yellow tint over the selected room's tiles.
## Must be wrapped in CanvasLayer by Main.gd for correct screen-space rendering.

const SELECTION_COLOR := Color(1.0, 0.9, 0.2, 0.3)  # Semi-transparent yellow

# Autoload reference
@onready var _room_manager: Node = RoomManager


func _ready() -> void:
	# Connect to RoomManager signals for selection state changes
	_room_manager.room_selected.connect(_on_room_selected)
	_room_manager.selection_cleared.connect(_on_selection_cleared)


func _on_room_selected(_room: RoomInstance) -> void:
	queue_redraw()


func _on_selection_cleared() -> void:
	queue_redraw()


func _draw() -> void:
	var room = _room_manager.get_selected_room()
	if room == null:
		return

	# Get room's bounding box and highlight all tiles within it
	var bbox = room.bounding_box

	# Loop through all tiles in the bounding box (walls + interior)
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			RoomBuildDrawing.draw_tile_highlight(self, Vector2i(x, y), SELECTION_COLOR, get_viewport())
