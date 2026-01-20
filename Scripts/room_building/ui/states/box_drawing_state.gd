extends LimboState
## Drawing room bounding box state.

signal box_completed(start: Vector2i, end: Vector2i)

@export var ui: RoomBuildUI

var _box_start: Vector2i
var _is_dragging: bool = false


func _enter() -> void:
	_is_dragging = false
	if ui:
		ui.queue_redraw()


func _exit() -> void:
	_is_dragging = false


func _update(_delta: float) -> void:
	if ui:
		ui.queue_redraw()


func handle_input(event: InputEvent, current_mouse_tile: Vector2i, room_type: RoomTypeResource) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_box_start = current_mouse_tile
			_is_dragging = true
			return true
		elif _is_dragging:
			_is_dragging = false
			box_completed.emit(_box_start, current_mouse_tile)
			get_root().dispatch(EVENT_FINISHED)
			return true
	return false


func is_dragging() -> bool:
	return _is_dragging


func get_box_start() -> Vector2i:
	return _box_start
