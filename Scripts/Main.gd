class_name Main 
extends Node2D

@export var room_build_manager: RoomBuildController
@export var camera: PinchPanCamera
@export var build_button: Button

var _build_mode_active = false

func _ready() -> void:
	room_build_manager.room_completed.connect(_on_room_completed)

	# Connect to RoomManager selection signals for future menu handling
	RoomManager.room_selected.connect(_on_room_selected)

	# Create selection highlight overlay in its own CanvasLayer for screen-space rendering
	# CanvasLayer ensures the Control draws in screen space (matching tile_to_screen coords)
	var selection_layer = CanvasLayer.new()
	selection_layer.name = "SelectionHighlightLayer"
	selection_layer.layer = 0  # Same layer as game world, but rendered after
	add_child(selection_layer)

	var selection_highlight = RoomSelectionHighlight.new()
	selection_highlight.name = "SelectionHighlight"
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)  # Cover full screen
	selection_layer.add_child(selection_highlight)

	# Create edit menu CanvasLayer (above selection highlight)
	var edit_menu_layer = CanvasLayer.new()
	edit_menu_layer.name = "EditMenuLayer"
	edit_menu_layer.layer = 1  # Above selection highlight (layer 0)
	add_child(edit_menu_layer)

	# Create RoomEditMenu instance
	var edit_menu = RoomEditMenu.new()
	edit_menu.name = "RoomEditMenu"
	edit_menu_layer.add_child(edit_menu)

	# Connect edit menu signals to stub handlers
	edit_menu.edit_furniture_pressed.connect(_on_edit_furniture_requested)
	edit_menu.edit_room_pressed.connect(_on_edit_room_requested)
	edit_menu.room_type_action_pressed.connect(_on_room_type_action_requested)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_on_build_button_pressed()

	# Deselect room when tapping empty space (touch release not consumed by Area2D)
	if event is InputEventScreenTouch and not event.pressed:
		# If we get here, no room area consumed the event
		# Area2D.input_event fires BEFORE _unhandled_input
		if RoomManager.get_selected_room():
			RoomManager.clear_selection()

func _on_build_button_pressed() -> void:
	_build_mode_active = !_build_mode_active
	if _build_mode_active:
		room_build_manager.start_build_mode()
		camera.enable_pinch_pan = false  # Disable camera panning in build mode
		if build_button:
			build_button.text = "X"
	else:
		_exit_build_mode()

func _on_room_completed(_room: RoomInstance) -> void:
	_exit_build_mode()


func _on_room_selected(room: RoomInstance) -> void:
	# RoomEditMenu handles showing the menu via its own signal connection
	print("Room selected: ", room.id)


func _on_edit_furniture_requested(room: RoomInstance) -> void:
	print("Edit furniture requested: ", room.id)


func _on_edit_room_requested(room: RoomInstance) -> void:
	print("Edit room requested: ", room.id)


func _on_room_type_action_requested(room: RoomInstance) -> void:
	print("Room type action requested: ", room.id, " type: ", room.room_type_id)


func _exit_build_mode() -> void:
	_build_mode_active = false
	room_build_manager.end_build_mode()
	camera.enable_pinch_pan = true  # Re-enable camera panning
	if build_button:
		build_button.text = "Build"
