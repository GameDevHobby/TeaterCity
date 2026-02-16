class_name RoomEditMenu
extends Control

## Contextual menu for room editing options.
## Appears when a room is selected, positioned near the room.

signal edit_furniture_pressed(room: RoomInstance)
signal edit_room_pressed(room: RoomInstance)
signal resize_room_pressed(room: RoomInstance)
signal room_type_action_pressed(room: RoomInstance)
signal delete_room_pressed(room: RoomInstance)

@onready var _panel: PanelContainer = $MenuPanel
@onready var _edit_furniture_btn: Button = $MenuPanel/MarginContainer/VBoxContainer/EditFurnitureButton
@onready var _edit_room_btn: Button = $MenuPanel/MarginContainer/VBoxContainer/EditRoomButton
@onready var _resize_room_btn: Button = $MenuPanel/MarginContainer/VBoxContainer/ResizeRoomButton
@onready var _room_type_btn: Button = $MenuPanel/MarginContainer/VBoxContainer/RoomTypeButton
@onready var _delete_room_btn: Button = $MenuPanel/MarginContainer/VBoxContainer/DeleteRoomButton
@onready var _delete_dialog: ConfirmationDialog = $DeleteDialog

var _current_room: RoomInstance = null
var _room_to_delete: RoomInstance = null

@onready var _room_manager: Node = get_node("/root/RoomManager")


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	UIStyleHelper.apply_panel_style(_panel)
	UIStyleHelper.apply_button_style(_edit_furniture_btn)
	UIStyleHelper.apply_button_style(_edit_room_btn)
	UIStyleHelper.apply_button_style(_resize_room_btn)
	UIStyleHelper.apply_button_style(_room_type_btn)
	UIStyleHelper.apply_button_style(_delete_room_btn)

	_delete_dialog.title = "Confirm Deletion"
	_delete_dialog.dialog_text = "Delete this room?\n\nAll furniture will be removed.\nThis cannot be undone."

	_edit_furniture_btn.pressed.connect(_on_edit_furniture)
	_edit_room_btn.pressed.connect(_on_edit_room)
	_resize_room_btn.pressed.connect(_on_resize_room)
	_room_type_btn.pressed.connect(_on_room_type_action)
	_delete_room_btn.pressed.connect(_on_delete_room_pressed)
	_delete_dialog.confirmed.connect(_on_delete_confirmed)

	hide()

	_room_manager.room_selected.connect(_on_room_selected)
	_room_manager.selection_cleared.connect(_on_selection_cleared)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_room == null:
		return

	var click_pos: Vector2 = Vector2.ZERO
	var is_click := false

	if event is InputEventScreenTouch and not event.pressed:
		click_pos = event.position
		is_click = true

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
		is_click = true

	if is_click:
		var panel_rect := Rect2(_panel.global_position, _panel.size)
		if not panel_rect.has_point(click_pos):
			_room_manager.clear_selection()
			get_viewport().set_input_as_handled()


func _on_room_selected(room: RoomInstance) -> void:
	_current_room = room
	_update_room_type_button(room)
	_position_near_room(room)
	show()


func _on_selection_cleared() -> void:
	_current_room = null
	hide()


func _position_near_room(room: RoomInstance) -> void:
	var bbox := room.bounding_box
	var center_x := bbox.position.x + bbox.size.x / 2
	var center_y := bbox.position.y + bbox.size.y / 2
	var center_tile := Vector2i(center_x, center_y)

	var screen_pos := IsometricMath.tile_to_screen(center_tile, get_viewport())

	await get_tree().process_frame

	var offset := Vector2(30, -_panel.size.y / 2)
	var target_pos := screen_pos + offset

	var viewport_size := get_viewport_rect().size
	var margin := 8.0
	target_pos.x = clampf(target_pos.x, margin, viewport_size.x - _panel.size.x - margin)
	target_pos.y = clampf(target_pos.y, margin, viewport_size.y - _panel.size.y - margin)

	_panel.position = target_pos


func _update_room_type_button(room: RoomInstance) -> void:
	if room.room_type_id == "theater_auditorium":
		var state_name := ""
		if room.state_machine and room.state_machine.current_state != "":
			state_name = room.state_machine.current_state

		if state_name == "" or state_name == "idle":
			_room_type_btn.text = "Theater Schedule"
			if room.has_scheduled_movie():
				_room_type_btn.tooltip_text = "Idle\nLast scheduled: %s" % room.scheduled_movie_title
			else:
				_room_type_btn.tooltip_text = "Open movie scheduling"
			return

		_room_type_btn.text = "Theater Active"
		if room.has_scheduled_movie():
			_room_type_btn.tooltip_text = "%s\nMovie: %s" % [state_name.capitalize(), room.scheduled_movie_title]
		else:
			_room_type_btn.tooltip_text = state_name.capitalize()
		return

	_room_type_btn.tooltip_text = ""

	var registry := RoomTypeRegistry.get_instance()
	if registry:
		var room_type := registry.get_room_type(room.room_type_id)
		if room_type:
			_room_type_btn.text = _get_room_type_feature(room_type.id)
			return

	_room_type_btn.text = "Room Options"


func _get_room_type_feature(room_type_id: String) -> String:
	match room_type_id:
		"theater_auditorium":
			return "Theater Schedule"
		"ticket_counter":
			return "Ticket Prices"
		"snack_bar":
			return "Menu Items"
		"bathroom":
			return "Maintenance"
		"lobby":
			return "Decorations"
		_:
			return "Room Options"


func _on_edit_furniture() -> void:
	if _current_room:
		edit_furniture_pressed.emit(_current_room)


func _on_edit_room() -> void:
	if _current_room:
		edit_room_pressed.emit(_current_room)


func _on_resize_room() -> void:
	if _current_room:
		resize_room_pressed.emit(_current_room)


func _on_room_type_action() -> void:
	if _current_room:
		room_type_action_pressed.emit(_current_room)


func _on_delete_room_pressed() -> void:
	if _current_room == null:
		return
	_room_to_delete = _current_room
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	if _room_to_delete:
		delete_room_pressed.emit(_room_to_delete)
		_room_to_delete = null
		hide()
