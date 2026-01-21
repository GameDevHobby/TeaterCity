extends GutTest
## Integration tests for room building workflow
## Tests state transitions and signal flow between RoomBuildController and RoomBuildUI
##
## Note: These tests create a minimal controller setup without full scene dependencies.
## They test the logic flow and state transitions rather than visual rendering.

var _controller: RoomBuildController
var _wall_op: WallOperation


func before_each() -> void:
	_wall_op = WallOperation.new()

	# Create a minimal controller for testing
	_controller = RoomBuildController.new()
	_controller.name = "TestRoomBuildController"
	add_child_autofree(_controller)

	# Initialize controller (this would normally happen in _ready)
	RoomTypeRegistry.get_instance()
	FurnitureRegistry.get_instance()


func after_each() -> void:
	_controller = null
	_wall_op = null


func _get_seating_bench() -> FurnitureResource:
	return load("res://data/furniture/seating_bench.tres") as FurnitureResource


func test_initial_state_is_idle() -> void:
	assert_eq(_controller.state_name, "idle", "Initial state should be idle")


func test_state_idle_to_select_room_on_start_build() -> void:
	watch_signals(_controller)

	_controller.start_build_mode()

	# Note: Without UI connected, state_changed will emit but UI won't show
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["select_room"])


func test_state_to_draw_box_on_room_type_selected() -> void:
	_controller.start_build_mode()
	watch_signals(_controller)

	# Simulate room type selection
	_controller._on_room_type_selected("lobby")

	assert_eq(_controller.state_name, "draw_box", "State should be draw_box after room type selected")
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["draw_box"])
	assert_not_null(_controller.current_room, "Current room should be created")
	assert_eq(_controller.current_room.room_type_id, "lobby", "Room type id should match selection")


func test_state_draw_box_to_place_doors_on_valid_size() -> void:
	# Set up state
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")  # lobby min_size is 4x4

	watch_signals(_controller)

	# Complete box drawing with valid size
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))  # 6x6 box (valid)

	assert_eq(_controller.state_name, "place_doors", "State should be place_doors after valid box")
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["place_doors"])
	assert_true(_controller.current_room.walls.size() > 0, "Room should have walls generated")


func test_invalid_size_stays_in_draw_box() -> void:
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")  # min_size is 4x4

	var initial_state = _controller.state_name
	watch_signals(_controller)

	# Try to complete with too-small size
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(1, 1))  # 2x2 box (too small)

	# State should NOT change because size is invalid
	# The controller stays in draw_box waiting for valid input
	assert_eq(_controller.state_name, "draw_box", "State should remain draw_box for invalid size")


func test_door_placement_adds_valid_door() -> void:
	# Progress to door placement state
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))

	# Try placing a door on valid wall position
	var door_pos = Vector2i(2, 0)  # Top wall, mid-section
	_controller._on_door_placed(door_pos)

	assert_eq(_controller.current_room.doors.size(), 1, "Room should have 1 door")
	assert_eq(_controller.current_room.doors[0].position, door_pos, "Door position should match")


func test_invalid_door_position_not_added() -> void:
	# Progress to door placement state
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))

	# Try placing a door on interior (invalid)
	_controller._on_door_placed(Vector2i(2, 2))

	assert_eq(_controller.current_room.doors.size(), 0, "Invalid door should not be added")


func test_state_place_doors_to_place_furniture() -> void:
	# Progress through states
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	_controller._on_door_placed(Vector2i(2, 0))  # Add required door

	watch_signals(_controller)

	# Complete door placement
	_controller._on_doors_done()

	assert_eq(_controller.state_name, "place_furniture", "State should be place_furniture after doors done")
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["place_furniture"])


func test_furniture_placement_adds_furniture() -> void:
	# Progress to furniture placement state
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	_controller._on_door_placed(Vector2i(2, 0))
	_controller._on_doors_done()

	var furniture = _get_seating_bench()

	# Place furniture in valid interior position
	_controller._on_furniture_placed(furniture, Vector2i(2, 2), 0)

	assert_eq(_controller.current_room.furniture.size(), 1, "Room should have 1 furniture")


func test_furniture_placement_blocked_by_wall() -> void:
	# Progress to furniture placement state
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	_controller._on_door_placed(Vector2i(2, 0))
	_controller._on_doors_done()

	var furniture = _get_seating_bench()

	# Try placing on wall
	_controller._on_furniture_placed(furniture, Vector2i(0, 0), 0)

	assert_eq(_controller.current_room.furniture.size(), 0, "Furniture on wall should not be placed")


func test_room_completed_signal_on_valid_completion() -> void:
	# Build a valid room
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	_controller._on_door_placed(Vector2i(2, 0))
	_controller._on_doors_done()

	var furniture = _get_seating_bench()
	_controller._on_furniture_placed(furniture, Vector2i(2, 2), 0)

	watch_signals(_controller)

	# Note: _on_complete_pressed requires tilemap_layer for visuals
	# We'll test the validation directly instead
	var validation_op = ValidationOperation.new()
	var result = validation_op.validate_complete(_controller.current_room)

	assert_true(result.is_valid, "Completed room should be valid")


func test_end_build_mode_resets_state() -> void:
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")

	_controller.end_build_mode()

	assert_eq(_controller.state_name, "idle", "State should be idle after end")
	assert_null(_controller.current_room, "Current room should be null")
	assert_null(_controller.current_room_type, "Current room type should be null")


func test_full_build_flow_state_transitions() -> void:
	var states: Array[String] = []

	_controller.state_changed.connect(func(state): states.append(state))

	# Execute full flow
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	_controller._on_door_placed(Vector2i(2, 0))
	_controller._on_doors_done()

	# Verify state progression
	assert_has(states, "select_room", "Should have select_room state")
	assert_has(states, "draw_box", "Should have draw_box state")
	assert_has(states, "place_doors", "Should have place_doors state")
	assert_has(states, "place_furniture", "Should have place_furniture state")


func test_multiple_doors_can_be_placed() -> void:
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))

	# Place multiple valid doors
	_controller._on_door_placed(Vector2i(2, 0))  # North wall
	_controller._on_door_placed(Vector2i(5, 2))  # East wall

	assert_eq(_controller.current_room.doors.size(), 2, "Should have 2 doors placed")


func test_multiple_furniture_can_be_placed() -> void:
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(6, 6))
	_controller._on_door_placed(Vector2i(2, 0))
	_controller._on_doors_done()

	var furniture = _get_seating_bench()

	# Place multiple furniture
	_controller._on_furniture_placed(furniture, Vector2i(2, 2), 0)
	_controller._on_furniture_placed(furniture, Vector2i(4, 4), 0)

	assert_eq(_controller.current_room.furniture.size(), 2, "Should have 2 furniture placed")
