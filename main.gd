extends Node2D

# Add to your main UI/GameManager
var build_mode_active = false
@onready var room_build_manager: RoomBuildController = $RoomBuildSystem/RoomBuildController
@onready var camera: PinchPanCamera = $PinchPanCamera
@onready var build_button: Button = $MainUILayer/BuildButton

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_on_build_button_pressed()

func _on_build_button_pressed() -> void:
	build_mode_active = !build_mode_active
	if build_mode_active:
		room_build_manager.start_build_mode()
		camera.enable_pinch_pan = false  # Disable camera panning in build mode
		if build_button:
			build_button.text = "X"
	else:
		room_build_manager.end_build_mode()
		camera.enable_pinch_pan = true  # Re-enable camera panning
		if build_button:
			build_button.text = "Build"
