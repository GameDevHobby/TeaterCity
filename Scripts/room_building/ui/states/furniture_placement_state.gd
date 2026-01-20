extends LimboState
## Placing furniture in room state.

signal furniture_selected(furniture: FurnitureResource)
signal furniture_placed(furniture: FurnitureResource, position: Vector2i, rotation: int)
signal placement_complete

@export var ui: RoomBuildUI

var _selected_furniture: FurnitureResource
var _current_rotation: int = 0


func _enter() -> void:
	_selected_furniture = null
	_current_rotation = 0
	if ui:
		ui.show_furniture_panel()
		ui.queue_redraw()


func _exit() -> void:
	_selected_furniture = null
	if ui:
		ui.hide_furniture_panel()


func _update(_delta: float) -> void:
	if ui:
		ui.queue_redraw()


func handle_input(event: InputEvent, current_mouse_tile: Vector2i, room: RoomInstance) -> bool:
	if _selected_furniture:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			furniture_placed.emit(_selected_furniture, current_mouse_tile, _current_rotation)
			return true
	return false


func select_furniture(furniture: FurnitureResource) -> void:
	_selected_furniture = furniture
	furniture_selected.emit(furniture)


func rotate_furniture() -> void:
	_current_rotation = (_current_rotation + 1) % 4


func get_rotation() -> int:
	return _current_rotation


func get_selected_furniture() -> FurnitureResource:
	return _selected_furniture


func finish_placement() -> void:
	placement_complete.emit()
	get_root().dispatch(EVENT_FINISHED)
