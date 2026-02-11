class_name StateDebugLabel
extends Label

## Debug label that displays the current state name from a RoomStateMachine.
## Updates automatically via signal when state changes.
## Hides when no state machine is set or state is empty.

var _state_machine: RoomStateMachine = null
var _is_showing := false


func _ready() -> void:
	visible = false
	# Readable non-button badge styling
	add_theme_color_override("font_color", Color(0.95, 0.95, 0.9, 1.0))
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)

	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.09, 0.12, 0.72)
	badge_style.border_color = Color(0.66, 0.69, 0.72, 0.5)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(4)
	badge_style.set_content_margin(SIDE_LEFT, 6)
	badge_style.set_content_margin(SIDE_RIGHT, 6)
	badge_style.set_content_margin(SIDE_TOP, 3)
	badge_style.set_content_margin(SIDE_BOTTOM, 3)
	add_theme_stylebox_override("normal", badge_style)

	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Set the state machine to monitor
func set_state_machine(sm: RoomStateMachine) -> void:
	# Disconnect old signal if any
	if _state_machine and _state_machine.state_changed.is_connected(_on_state_changed):
		_state_machine.state_changed.disconnect(_on_state_changed)

	_state_machine = sm

	if _state_machine:
		_state_machine.state_changed.connect(_on_state_changed)
		_update_text()

	_update_visibility()


## Show label at specified world position
func show_at_position(world_pos: Vector2) -> void:
	_is_showing = true
	global_position = world_pos - Vector2(size.x / 2.0, 0)  # Center above position
	_update_visibility()


## Hide the label
func hide_label() -> void:
	_is_showing = false
	visible = false


## Update visibility based on state machine and showing flag
func _update_visibility() -> void:
	visible = _is_showing and _state_machine != null and _state_machine.current_state != ""


## Update text to show current state name
func _update_text() -> void:
	if _state_machine:
		text = _state_machine.current_state.to_upper()
	else:
		text = ""


## Signal handler for state changes
func _on_state_changed(_old_state: String, new_state: String) -> void:
	text = new_state.to_upper()
