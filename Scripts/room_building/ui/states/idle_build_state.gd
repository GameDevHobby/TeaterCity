extends LimboState
## Idle state - no active input mode, shows room type selection.

signal room_type_selected(room_type_id: String)

@export var ui: RoomBuildUI


func _enter() -> void:
	if ui:
		ui.show_room_type_panel()
		ui.queue_redraw()


func _exit() -> void:
	if ui:
		ui.hide_room_type_panel()
