class_name RoomEditMenu
extends Control

## Contextual menu for room editing options.
## Appears when a room is selected, positioned near the room.

# Signals
signal edit_furniture_pressed(room: RoomInstance)
signal edit_room_pressed(room: RoomInstance)
signal room_type_action_pressed(room: RoomInstance)
signal delete_room_pressed(room: RoomInstance)

# UI elements
var _panel: PanelContainer
var _edit_furniture_btn: Button
var _edit_room_btn: Button
var _room_type_btn: Button
var _delete_room_btn: Button
var _delete_dialog: ConfirmationDialog = null

# State
var _current_room: RoomInstance = null
var _room_to_delete: RoomInstance = null

# Autoload reference (avoids static analysis issues in Godot 4.5)
@onready var _room_manager: Node = get_node("/root/RoomManager")


func _ready() -> void:
	# Don't block clicks to rooms below (this Control covers full screen)
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_create_panel()
	hide()  # Start hidden until a room is selected

	# Create confirmation dialog for delete action
	_delete_dialog = ConfirmationDialog.new()
	_delete_dialog.title = "Confirm Deletion"
	_delete_dialog.dialog_text = "Delete this room?\n\nAll furniture will be removed.\nThis cannot be undone."
	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_dialog)

	# Connect to RoomManager selection signals
	_room_manager.room_selected.connect(_on_room_selected)
	_room_manager.selection_cleared.connect(_on_selection_cleared)


func _create_panel() -> void:
	# Create the main panel container
	_panel = PanelContainer.new()
	_panel.name = "MenuPanel"
	_panel.mouse_filter = MOUSE_FILTER_STOP  # Capture button clicks
	UIStyleHelper.apply_panel_style(_panel)
	add_child(_panel)

	# Add margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	# Add vertical box for button layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Create the three menu buttons
	_edit_furniture_btn = UIStyleHelper.create_styled_button("Edit Furniture", Vector2(160, 40))
	_edit_furniture_btn.pressed.connect(_on_edit_furniture)
	vbox.add_child(_edit_furniture_btn)

	_edit_room_btn = UIStyleHelper.create_styled_button("Edit Room", Vector2(160, 40))
	_edit_room_btn.pressed.connect(_on_edit_room)
	vbox.add_child(_edit_room_btn)

	_room_type_btn = UIStyleHelper.create_styled_button("", Vector2(160, 40))  # Text set dynamically
	_room_type_btn.pressed.connect(_on_room_type_action)
	vbox.add_child(_room_type_btn)

	# Add separator before destructive action
	var separator = HSeparator.new()
	vbox.add_child(separator)

	_delete_room_btn = UIStyleHelper.create_styled_button("Delete Room", Vector2(160, 40))
	_delete_room_btn.pressed.connect(_on_delete_room_pressed)
	vbox.add_child(_delete_room_btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_room == null:
		return

	var click_pos: Vector2 = Vector2.ZERO
	var is_click := false

	# Handle mobile touch release
	if event is InputEventScreenTouch and not event.pressed:
		click_pos = event.position
		is_click = true

	# Handle desktop mouse click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
		is_click = true

	if is_click:
		# Check if click is outside the menu panel
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
	# Calculate center tile from bounding box
	var bbox := room.bounding_box
	var center_x := bbox.position.x + bbox.size.x / 2
	var center_y := bbox.position.y + bbox.size.y / 2
	var center_tile := Vector2i(center_x, center_y)

	# Convert to screen position
	var screen_pos := IsometricMath.tile_to_screen(center_tile, get_viewport())

	# Wait for panel size calculation (deferred call)
	await get_tree().process_frame

	# Apply offset to position right of room center
	var offset := Vector2(30, -_panel.size.y / 2)
	var target_pos := screen_pos + offset

	# Clamp to viewport bounds with margin
	var viewport_size := get_viewport_rect().size
	var margin := 8.0
	target_pos.x = clampf(target_pos.x, margin, viewport_size.x - _panel.size.x - margin)
	target_pos.y = clampf(target_pos.y, margin, viewport_size.y - _panel.size.y - margin)

	_panel.position = target_pos


func _update_room_type_button(room: RoomInstance) -> void:
	# Try to get room type from registry
	var registry := RoomTypeRegistry.get_instance()
	if registry:
		var room_type := registry.get_room_type(room.room_type_id)
		if room_type:
			_room_type_btn.text = _get_room_type_feature(room_type.id)
			return

	# Fallback if no room type found
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
		# Hide menu (selection will be cleared by Main.gd after deletion)
		hide()
