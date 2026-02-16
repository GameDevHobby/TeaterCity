class_name FurnitureListPanel
extends Control

## Scrollable list panel showing all furniture in the selected room.
## Provides bi-directional selection sync with FurnitureEditController.

signal furniture_item_selected(index: int, furniture: RoomInstance.FurniturePlacement)
signal furniture_delete_requested
signal furniture_add_requested
signal furniture_selected_for_add(furniture: FurnitureResource)
signal placement_cancelled
signal done_pressed

const PANEL_MARGIN := 20.0
const SCROLL_MAX_HEIGHT := 200.0
const SCROLL_MIN_HEIGHT := 100.0
const ITEM_HEIGHT := 36

const ITEM_BUTTON_SCENE := preload("res://scripts/room_editing/FurnitureListItemButton.tscn")

@onready var _panel: PanelContainer = $ListPanel
@onready var _scroll: ScrollContainer = $ListPanel/MarginContainer/VBoxContainer/ItemScroll
@onready var _items_container: VBoxContainer = $ListPanel/MarginContainer/VBoxContainer/ItemScroll/ItemsContainer
@onready var _add_button: Button = $ListPanel/MarginContainer/VBoxContainer/AddButton
@onready var _delete_button: Button = $ListPanel/MarginContainer/VBoxContainer/DeleteButton
@onready var _error_label: Label = $ListPanel/MarginContainer/VBoxContainer/ErrorLabel
@onready var _done_button: Button = $ListPanel/MarginContainer/VBoxContainer/DoneButton

@onready var _picker_panel: PanelContainer = $PickerPanel
@onready var _picker_items_container: VBoxContainer = $PickerPanel/MarginContainer/VBoxContainer/PickerItemsContainer
@onready var _cancel_add_button: Button = $PickerPanel/MarginContainer/VBoxContainer/CancelAddButton

var _controller: FurnitureEditController = null
var _item_buttons: Array[Button] = []
var _picker_buttons: Array[Button] = []
var _selected_index := -1
var _current_room: RoomInstance = null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_preset(PRESET_FULL_RECT)

	UIStyleHelper.apply_panel_style(_panel)
	UIStyleHelper.apply_panel_style(_picker_panel)
	UIStyleHelper.apply_button_style(_add_button, Color(0.2, 0.4, 0.3, 1.0))
	UIStyleHelper.apply_button_style(_delete_button, Color(0.6, 0.2, 0.2, 1.0))
	UIStyleHelper.apply_button_style(_done_button)
	UIStyleHelper.apply_button_style(_cancel_add_button)

	_add_button.pressed.connect(_on_add_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_done_button.pressed.connect(_on_done_pressed)
	_cancel_add_button.pressed.connect(_on_cancel_add_pressed)

	_delete_button.hide()
	_error_label.hide()
	_picker_panel.hide()
	hide()


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
	_update_scroll_height(room.furniture.size())

	show()
	_panel.show()
	call_deferred("_deferred_position_list_panel")


func hide_panel() -> void:
	_clear_list()
	_hide_picker()
	_current_room = null
	_selected_index = -1
	hide()


func _deferred_position_list_panel() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.position = Vector2(PANEL_MARGIN, viewport_size.y - panel_size.y - PANEL_MARGIN)


func _deferred_position_picker() -> void:
	if _picker_panel == null or not is_instance_valid(_picker_panel):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _picker_panel.get_combined_minimum_size()
	_picker_panel.position = Vector2(viewport_size.x - panel_size.x - PANEL_MARGIN, viewport_size.y - panel_size.y - PANEL_MARGIN)


func _update_scroll_height(item_count: int) -> void:
	var content_height := float(item_count) * float(ITEM_HEIGHT + 4)
	_scroll.custom_minimum_size.y = minf(maxf(content_height, SCROLL_MIN_HEIGHT), SCROLL_MAX_HEIGHT)


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
	var btn := ITEM_BUTTON_SCENE.instantiate() as Button
	var furn_resource := furniture.furniture
	btn.text = furn_resource.name if furn_resource else "Unknown"
	btn.custom_minimum_size = Vector2(160, ITEM_HEIGHT)
	UIStyleHelper.apply_button_style(btn)
	btn.pressed.connect(_on_item_pressed.bind(index, furniture))
	return btn


func _show_picker(room: RoomInstance) -> void:
	_clear_picker_buttons()

	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type:
		_populate_picker_buttons(room_type)

	_picker_panel.show()
	call_deferred("_deferred_position_picker")


func _populate_picker_buttons(room_type: RoomTypeResource) -> void:
	var all_furniture: Array[FurnitureResource] = []

	for req in room_type.get_required_furniture():
		if req.furniture and req.furniture not in all_furniture:
			all_furniture.append(req.furniture)

	for furn in room_type.allowed_furniture:
		if furn not in all_furniture:
			all_furniture.append(furn)

	for furn in all_furniture:
		var btn := ITEM_BUTTON_SCENE.instantiate() as Button
		btn.text = furn.name if furn.name else furn.id
		btn.custom_minimum_size = Vector2(160, 36)
		UIStyleHelper.apply_button_style(btn)
		btn.pressed.connect(_on_picker_furniture_selected.bind(furn))
		_picker_items_container.add_child(btn)
		_picker_buttons.append(btn)


func _clear_picker_buttons() -> void:
	for btn in _picker_buttons:
		if btn and is_instance_valid(btn):
			btn.queue_free()
	_picker_buttons.clear()


func _hide_picker() -> void:
	_clear_picker_buttons()
	_picker_panel.hide()


func select_item(index: int) -> void:
	if _selected_index >= 0 and _selected_index < _item_buttons.size():
		UIStyleHelper.apply_button_style(_item_buttons[_selected_index])

	_selected_index = index

	if index >= 0:
		_delete_button.show()
		_error_label.hide()
	else:
		_delete_button.hide()
		_error_label.hide()

	if index >= 0 and index < _item_buttons.size():
		UIStyleHelper.apply_button_style(_item_buttons[index], Color(0.2, 0.5, 0.6, 1.0))
		_scroll.ensure_control_visible(_item_buttons[index])


func _on_item_pressed(index: int, furniture: RoomInstance.FurniturePlacement) -> void:
	furniture_item_selected.emit(index, furniture)


func _on_add_pressed() -> void:
	if _current_room == null:
		return
	_show_picker(_current_room)
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
	var index := room.furniture.find(furniture)
	if index >= 0:
		select_item(index)


func _on_controller_furniture_deselected() -> void:
	select_item(-1)


func _on_controller_furniture_deleted(room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	_populate_list(room)
	_update_scroll_height(room.furniture.size())
	_selected_index = -1
	_delete_button.hide()
	_error_label.hide()


func _on_controller_furniture_delete_failed(reason: String) -> void:
	_error_label.text = reason
	_error_label.show()


func _on_controller_placement_exited() -> void:
	_hide_picker()


func _on_controller_furniture_added(room: RoomInstance, _furniture: RoomInstance.FurniturePlacement) -> void:
	_populate_list(room)
	_update_scroll_height(room.furniture.size())


func _on_controller_mode_exited() -> void:
	hide_panel()
