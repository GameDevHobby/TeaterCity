class_name Main 
extends Node2D

@export var room_build_manager: RoomBuildController
@export var camera: PinchPanCamera
@export var build_button: Button

var _build_mode_active = false

func _ready() -> void:
	room_build_manager.room_completed.connect(_on_room_completed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_on_build_button_pressed()

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

func _exit_build_mode() -> void:
	_build_mode_active = false
	room_build_manager.end_build_mode()
	camera.enable_pinch_pan = true  # Re-enable camera panning
	if build_button:
		build_button.text = "Build"
