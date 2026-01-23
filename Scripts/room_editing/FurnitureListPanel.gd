class_name FurnitureListPanel
extends Control

## Scrollable list panel showing all furniture in the selected room.
## Provides bi-directional selection sync with FurnitureEditController.

# Signals
signal furniture_item_selected(index: int, furniture: RoomInstance.FurniturePlacement)
signal done_pressed

# UI elements
var _panel: PanelContainer
var _items_container: VBoxContainer
var _done_button: Button

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

	# Position at bottom-left with margin
	_panel.set_anchors_preset(PRESET_BOTTOM_LEFT)
	_panel.position = Vector2(PANEL_MARGIN, -PANEL_MARGIN)
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

	# Done button at bottom
	_done_button = UIStyleHelper.create_styled_button("Done", Vector2(160, 40))
	_done_button.pressed.connect(_on_done_pressed)
	vbox.add_child(_done_button)


# --- Public Methods ---

func set_controller(controller: FurnitureEditController) -> void:
	_controller = controller
	_controller.furniture_selected.connect(_on_controller_furniture_selected)
	_controller.furniture_deselected.connect(_on_controller_furniture_deselected)
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


func hide_panel() -> void:
	_clear_list()
	_current_room = null
	_selected_index = -1
	hide()


func select_item(index: int) -> void:
	# Unhighlight previous selection
	if _selected_index >= 0 and _selected_index < _item_buttons.size():
		UIStyleHelper.apply_button_style(_item_buttons[_selected_index])

	_selected_index = index

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


func _on_done_pressed() -> void:
	done_pressed.emit()


func _on_controller_furniture_selected(room: RoomInstance, furniture: RoomInstance.FurniturePlacement) -> void:
	# Find index of this furniture in room.furniture array
	var index := room.furniture.find(furniture)
	if index >= 0:
		select_item(index)


func _on_controller_furniture_deselected() -> void:
	select_item(-1)  # Clear selection


func _on_controller_mode_exited() -> void:
	hide_panel()
