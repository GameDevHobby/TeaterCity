class_name FurnitureListPanel
extends Control

## Scrollable list panel showing all furniture in the selected room.
## Provides bi-directional selection sync with FurnitureEditController.

# Signals
signal furniture_item_selected(index: int, furniture: RoomInstance.FurniturePlacement)
signal furniture_delete_requested
signal furniture_add_requested  # Request to show picker
signal furniture_selected_for_add(furniture: FurnitureResource)  # Furniture chosen from picker
signal placement_cancelled
signal done_pressed

# UI elements
var _panel: PanelContainer
var _items_container: VBoxContainer
var _done_button: Button
var _delete_button: Button
var _error_label: Label  # For showing delete error messages
var _add_button: Button
var _picker_panel: PanelContainer = null  # Furniture picker overlay
var _picker_buttons: Array[Button] = []
var _cancel_add_button: Button = null
var _rotate_button: Button = null

# State
var _controller: FurnitureEditController = null
var _item_buttons: Array[Button] = []
var _selected_index: int = -1
var _current_room: RoomInstance = null

# Layout constants
const PANEL_WIDTH := 200.0
const PANEL_MARGIN := 20.0
const SCROLL_MAX_HEIGHT := 200.0
const ITEM_HEIGHT := 36


func _ready() -> void:
	# Don't block clicks (this Control covers full screen)
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	_create_panel()
	hide()  # Start hidden until furniture edit mode is entered


func _create_panel() -> void:
	# Create the main panel container
	_panel = PanelContainer.new()
	_panel.name = "ListPanel"
	_panel.mouse_filter = MOUSE_FILTER_STOP  # Capture button clicks
	UIStyleHelper.apply_panel_style(_panel)
	add_child(_panel)

	# Set minimum size, position will be calculated after layout
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 150)

	# Add margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	# Add vertical box for layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Title label
	var title := Label.new()
	title.text = "Furniture"
	title.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(title)

	# Scroll container for item list
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.set_deferred("custom_minimum_size", Vector2(0, mini(SCROLL_MAX_HEIGHT, 100)))
	vbox.add_child(scroll)

	# Container for item buttons inside scroll
	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 4)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_container)

	# Add button (for adding new furniture)
	_add_button = UIStyleHelper.create_styled_button("+ Add Furniture", Vector2(160, 40), Color(0.2, 0.4, 0.3))
	_add_button.pressed.connect(_on_add_pressed)
	vbox.add_child(_add_button)

	# Delete button (hidden until furniture selected)
	_delete_button = UIStyleHelper.create_styled_button("Delete", Vector2(160, 40), Color(0.6, 0.2, 0.2))
	_delete_button.pressed.connect(_on_delete_pressed)
	_delete_button.hide()  # Hidden until selection
	vbox.add_child(_delete_button)

	# Error label for delete failures
	_error_label = Label.new()
	_error_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_error_label.custom_minimum_size = Vector2(160, 0)
	_error_label.hide()
	vbox.add_child(_error_label)

	# Done button at bottom
	_done_button = UIStyleHelper.create_styled_button("Done", Vector2(160, 40))
	_done_button.pressed.connect(_on_done_pressed)
	vbox.add_child(_done_button)


# --- Public Methods ---

func set_controller(controller: FurnitureEditController) -> void:
	_controller = controller
	_controller.furniture_selected.connect(_on_controller_furniture_selected)
	_controller.furniture_deselected.connect(_on_controller_furniture_deselected)
	_controller.furniture_deleted.connect(_on_controller_furniture_deleted)
	_controller.furniture_delete_failed.connect(_on_controller_furniture_delete_failed)
	_controller.placement_mode_exited.connect(_on_controller_placement_exited)
	_controller.furniture_added.connect(_on_controller_furniture_added)
	_controller.mode_exited.connect(_on_controller_mode_exited)


func show_for_room(room: RoomInstance) -> void:
	_current_room = room
	_populate_list(room)
	_selected_index = -1

	# Update scroll container height based on item count
	var scroll := _items_container.get_parent() as ScrollContainer
	if scroll:
		var item_count := room.furniture.size()
		var content_height := item_count * (ITEM_HEIGHT + 4)  # height + separation
		scroll.custom_minimum_size.y = minf(content_height, SCROLL_MAX_HEIGHT)

	show()
	_panel.show()

	# Position at bottom-left after layout is ready
	call_deferred("_deferred_position_list_panel")


func _deferred_position_list_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = _panel.get_combined_minimum_size()
	_panel.position = Vector2(
		PANEL_MARGIN,
		viewport_size.y - panel_size.y - PANEL_MARGIN
	)


func hide_panel() -> void:
	_clear_list()
	_current_room = null
	_selected_index = -1
	hide()


func _create_picker_panel(room: RoomInstance) -> void:
	if _picker_panel != null:
		_picker_panel.queue_free()

	_picker_panel = PanelContainer.new()
	_picker_panel.name = "FurniturePicker"
	_picker_panel.mouse_filter = MOUSE_FILTER_STOP
	UIStyleHelper.apply_panel_style(_picker_panel)
	add_child(_picker_panel)

	# Position at bottom-right - calculate position after content is added
	_picker_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_picker_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Select Furniture"
	title.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(title)

	# Get room type for allowed furniture
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type:
		_populate_picker_buttons(vbox, room_type)

	# Cancel button
	_cancel_add_button = UIStyleHelper.create_styled_button("Cancel", Vector2(160, 36))
	_cancel_add_button.pressed.connect(_on_cancel_add_pressed)
	vbox.add_child(_cancel_add_button)

	# Position at bottom-right after content is ready
	call_deferred("_deferred_position_picker")


func _deferred_position_picker() -> void:
	if _picker_panel == null or not is_instance_valid(_picker_panel):
		return
	# Get viewport size and position at bottom-right with margin
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = _picker_panel.get_combined_minimum_size()
	_picker_panel.position = Vector2(
		viewport_size.x - panel_size.x - PANEL_MARGIN,
		viewport_size.y - panel_size.y - PANEL_MARGIN
	)


func _populate_picker_buttons(container: VBoxContainer, room_type: RoomTypeResource) -> void:
	_picker_buttons.clear()

	# Add all allowed furniture as buttons
	var all_furniture: Array[FurnitureResource] = []

	# Add required furniture
	for req in room_type.get_required_furniture():
		if req.furniture and req.furniture not in all_furniture:
			all_furniture.append(req.furniture)

	# Add optional allowed furniture
	for furn in room_type.allowed_furniture:
		if furn not in all_furniture:
			all_furniture.append(furn)

	for furn in all_furniture:
		var display_name = furn.name if furn.name else furn.id
		var btn = UIStyleHelper.create_styled_button(display_name, Vector2(160, 36))
		btn.pressed.connect(_on_picker_furniture_selected.bind(furn))
		container.add_child(btn)
		_picker_buttons.append(btn)


func _hide_picker() -> void:
	if _picker_panel != null:
		_picker_panel.queue_free()
		_picker_panel = null
	_picker_buttons.clear()


func select_item(index: int) -> void:
	# Unhighlight previous selection
	if _selected_index >= 0 and _selected_index < _item_buttons.size():
		UIStyleHelper.apply_button_style(_item_buttons[_selected_index])

	_selected_index = index

	# Show/hide delete button based on selection
	if index >= 0:
		_delete_button.show()
		_error_label.hide()  # Clear any previous error
	else:
		_delete_button.hide()
		_error_label.hide()

	# Highlight new selection with cyan accent color
	if index >= 0 and index < _item_buttons.size():
		UIStyleHelper.apply_button_style(
			_item_buttons[index],
			Color(0.2, 0.5, 0.6, 1.0)  # Cyan-ish to match furniture highlight
		)

		# Ensure selected item is visible in scroll
		var scroll := _items_container.get_parent() as ScrollContainer
		if scroll:
			var btn := _item_buttons[index]
			scroll.ensure_control_visible(btn)


# --- Private Methods ---

func _populate_list(room: RoomInstance) -> void:
	_clear_list()

	for i in range(room.furniture.size()):
		var furn: RoomInstance.FurniturePlacement = room.furniture[i]
		var btn := _create_item_button(i, furn)
		_items_container.add_child(btn)
		_item_buttons.append(btn)


func _clear_list() -> void:
	for btn in _item_buttons:
		if btn and is_instance_valid(btn):
			btn.queue_free()
	_item_buttons.clear()


func _create_item_button(index: int, furniture: RoomInstance.FurniturePlacement) -> Button:
	var furn_resource := furniture.furniture
	var btn := UIStyleHelper.create_styled_button(
		furn_resource.name if furn_resource else "Unknown",
		Vector2(160, ITEM_HEIGHT)
	)
	btn.pressed.connect(_on_item_pressed.bind(index, furniture))
	return btn


func _on_item_pressed(index: int, furniture: RoomInstance.FurniturePlacement) -> void:
	furniture_item_selected.emit(index, furniture)


func _on_add_pressed() -> void:
	if _current_room == null:
		return
	_create_picker_panel(_current_room)
	furniture_add_requested.emit()


func _on_cancel_add_pressed() -> void:
	_hide_picker()
	placement_cancelled.emit()


func _on_picker_furniture_selected(furniture: FurnitureResource) -> void:
	_hide_picker()
	furniture_selected_for_add.emit(furniture)


func _on_done_pressed() -> void:
	done_pressed.emit()


func _on_delete_pressed() -> void:
	furniture_delete_requested.emit()


func _on_controller_furniture_selected(room: RoomInstance, furniture: RoomInstance.FurniturePlacement) -> void:
	# Find index of this furniture in room.furniture array
	var index := room.furniture.find(furniture)
	if index >= 0:
		select_item(index)


func _on_controller_furniture_deselected() -> void:
	select_item(-1)  # Clear selection


func _on_controller_furniture_deleted(room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	# Refresh the list
	_populate_list(room)
	_selected_index = -1
	_delete_button.hide()
	_error_label.hide()


func _on_controller_furniture_delete_failed(reason: String) -> void:
	_error_label.text = reason
	_error_label.show()


func _on_controller_placement_exited() -> void:
	_hide_picker()


func _on_controller_furniture_added(room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	# Refresh the list with new furniture
	_populate_list(room)


func _on_controller_mode_exited() -> void:
	hide_panel()
