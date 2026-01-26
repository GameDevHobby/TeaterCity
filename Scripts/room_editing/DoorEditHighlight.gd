class_name DoorEditHighlight
extends Control

## Visual highlight for door editing mode.
## Shows wall tiles as available for door placement, existing doors as removable.
## Must be wrapped in CanvasLayer by Main.gd for correct screen-space rendering.

# Colors for different states
const WALL_COLOR := Color(0.8, 0.6, 0.2, 0.3)  # Warm orange for available walls
const DOOR_COLOR := Color(0.6, 0.2, 0.8, 0.4)  # Purple for existing doors
const INVALID_COLOR := Color(0.5, 0.5, 0.5, 0.2)  # Gray for invalid positions

# Controller reference (set by Main.gd)
var _controller: DoorEditController = null


func _ready() -> void:
	# Will be hidden until door edit mode is active
	pass


func set_controller(controller: DoorEditController) -> void:
	if _controller != null:
		# Disconnect from previous controller
		if _controller.mode_exited.is_connected(_on_mode_exited):
			_controller.mode_exited.disconnect(_on_mode_exited)

	_controller = controller

	if _controller != null:
		_controller.mode_exited.connect(_on_mode_exited)


func _on_mode_exited() -> void:
	queue_redraw()


func _draw() -> void:
	if _controller == null or not _controller.is_active():
		return

	var room := _controller.get_current_room()
	if room == null:
		return

	var viewport := get_viewport()

	# Draw all wall tiles
	for wall_pos in room.walls:
		# Check if this is a door position
		var is_door = false
		for door in room.doors:
			if door.position == wall_pos:
				is_door = true
				break

		if is_door:
			# Existing door - show as removable
			RoomBuildDrawing.draw_tile_highlight(self, wall_pos, DOOR_COLOR, viewport)
		else:
			# Available wall - show as potential door location
			RoomBuildDrawing.draw_tile_highlight(self, wall_pos, WALL_COLOR, viewport)
