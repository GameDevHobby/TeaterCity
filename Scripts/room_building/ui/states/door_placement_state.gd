extends LimboState
## Placing doors on walls state.

signal door_placed(position: Vector2i)
signal doors_done

@export var ui: RoomBuildUI


func _enter() -> void:
	if ui:
		ui.show_door_panel()
		ui.queue_redraw()


func _exit() -> void:
	if ui:
		ui.hide_door_panel()


func _update(_delta: float) -> void:
	if ui:
		ui.queue_redraw()


func handle_input(event: InputEvent, current_mouse_tile: Vector2i, room: RoomInstance) -> bool:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		door_placed.emit(current_mouse_tile)
		return true
	return false


func finish_door_placement() -> void:
	doors_done.emit()
	get_root().dispatch(EVENT_FINISHED)
