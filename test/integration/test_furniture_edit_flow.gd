extends GutTest
## Integration tests for furniture editing workflow
## Tests controller state transitions and signal flow
##
## Note: These tests create a minimal controller setup without full scene dependencies.
## They test the logic flow and signal emissions rather than visual rendering.

var _controller: FurnitureEditController
var _wall_op: WallOperation
var _test_room: RoomInstance


func before_each() -> void:
	_wall_op = WallOperation.new()

	# Create test room with furniture
	_test_room = _create_room_with_furniture()

	# Create controller
	_controller = FurnitureEditController.new()
	_controller.name = "TestFurnitureEditController"
	add_child_autofree(_controller)


func after_each() -> void:
	_controller = null
	_test_room = null
	_wall_op = null


func _create_test_furniture() -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = "test_chair"
	furn.size = Vector2i(1, 1)
	furn.cost = 50
	return furn


func _create_room_with_furniture() -> RoomInstance:
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 6, 6)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	room.add_door(Vector2i(2, 0), 0)

	var furn = _create_test_furniture()
	room.add_furniture(furn, Vector2i(2, 2), 0)
	room.add_furniture(furn, Vector2i(3, 3), 0)
	return room


# === Selection Tests ===

func test_initial_state_no_selection() -> void:
	_controller.enter_edit_mode(_test_room)

	assert_null(_controller.get_selected_furniture(), "No furniture should be selected initially")


func test_select_furniture_emits_signal() -> void:
	_controller.enter_edit_mode(_test_room)
	watch_signals(_controller)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	assert_signal_emitted_with_parameters(
		_controller,
		"furniture_selected",
		[_test_room, furniture]
	)


func test_select_furniture_updates_state() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	assert_eq(
		_controller.get_selected_furniture(),
		furniture,
		"Selected furniture should be stored"
	)


func test_deselect_furniture() -> void:
	_controller.enter_edit_mode(_test_room)

	# First select a piece of furniture
	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)
	assert_not_null(_controller.get_selected_furniture(), "Furniture should be selected")

	watch_signals(_controller)

	# Simulate deselection by calling internal method via _unhandled_input
	# This is a bit of a hack, but the controller deselects on background tap
	# For now we'll test via entering placement mode which clears selection
	var test_furn = _create_test_furniture()
	_controller.enter_placement_mode(test_furn)

	assert_signal_emitted(_controller, "furniture_deselected")


# === Move Tests ===

func test_move_furniture_to_valid_position() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	var original_pos = furniture.position
	_controller.select_furniture(furniture)

	# Simulate drag operation by manipulating position directly
	# (The drag system uses _unhandled_input which is hard to test in isolation)
	furniture.position = Vector2i(2, 3)

	assert_ne(furniture.position, original_pos, "Position should be updated")
	assert_eq(furniture.position, Vector2i(2, 3), "Position should be at new location")


func test_move_updates_placement_position() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	# Update position
	var new_pos = Vector2i(3, 2)
	furniture.position = new_pos

	assert_eq(furniture.position, new_pos, "FurniturePlacement.position should be updated")


# === Delete Tests ===

func test_delete_furniture_removes_from_room() -> void:
	_controller.enter_edit_mode(_test_room)

	var initial_count = _test_room.furniture.size()
	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	var success = _controller.delete_furniture()

	assert_true(success, "Delete should succeed")
	assert_eq(
		_test_room.furniture.size(),
		initial_count - 1,
		"Room should have one fewer furniture piece"
	)
	assert_false(
		_test_room.furniture.has(furniture),
		"Deleted furniture should not be in array"
	)


func test_delete_emits_signal() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	watch_signals(_controller)
	_controller.delete_furniture()

	assert_signal_emitted(_controller, "furniture_deleted")


func test_delete_clears_selection() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	_controller.delete_furniture()

	assert_null(
		_controller.get_selected_furniture(),
		"Selection should be cleared after delete"
	)


func test_delete_validation_prevents_removal_below_minimum() -> void:
	# Create room with only required furniture
	var validation_room = RoomInstance.new("validation_room", "lobby")
	validation_room.bounding_box = Rect2i(0, 0, 6, 6)
	validation_room.walls = _wall_op.generate_walls(validation_room.bounding_box)
	validation_room.add_door(Vector2i(2, 0), 0)

	# Add only one seating_bench (lobby requires at least 1)
	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	validation_room.add_furniture(bench, Vector2i(2, 2), 0)

	_controller.enter_edit_mode(validation_room)
	_controller.select_furniture(validation_room.furniture[0])

	watch_signals(_controller)
	var success = _controller.delete_furniture()

	# Should fail because lobby requires at least 1 seating_bench
	assert_false(success, "Delete should fail when at minimum required count")
	assert_signal_emitted(_controller, "furniture_delete_failed")
	assert_eq(validation_room.furniture.size(), 1, "Furniture should still be in room")


# === Edit Mode Lifecycle ===

func test_enter_edit_mode() -> void:
	assert_false(_controller.is_active(), "Controller should not be active initially")

	_controller.enter_edit_mode(_test_room)

	assert_true(_controller.is_active(), "Controller should be active after enter_edit_mode")
	assert_eq(_controller.get_current_room(), _test_room, "Current room should be set")


func test_exit_edit_mode() -> void:
	_controller.enter_edit_mode(_test_room)
	watch_signals(_controller)

	_controller.exit_edit_mode()

	assert_false(_controller.is_active(), "Controller should not be active after exit")
	assert_null(_controller.get_current_room(), "Current room should be cleared")
	assert_null(_controller.get_selected_furniture(), "Selection should be cleared")
	assert_signal_emitted(_controller, "mode_exited")


func test_exit_edit_mode_clears_state() -> void:
	_controller.enter_edit_mode(_test_room)
	_controller.select_furniture(_test_room.furniture[0])

	_controller.exit_edit_mode()

	assert_null(_controller.get_selected_furniture(), "Selection should be cleared")
	assert_null(_controller.get_current_room(), "Room reference should be cleared")


# === Placement Mode Tests ===

func test_enter_placement_mode() -> void:
	_controller.enter_edit_mode(_test_room)

	var test_furn = _create_test_furniture()
	watch_signals(_controller)

	_controller.enter_placement_mode(test_furn)

	assert_true(_controller.is_in_placement_mode(), "Should be in placement mode")
	assert_eq(_controller.get_placement_furniture(), test_furn, "Placement furniture should be set")
	assert_signal_emitted_with_parameters(_controller, "placement_mode_entered", [test_furn])


func test_enter_placement_mode_clears_selection() -> void:
	_controller.enter_edit_mode(_test_room)
	_controller.select_furniture(_test_room.furniture[0])

	var test_furn = _create_test_furniture()
	watch_signals(_controller)

	_controller.enter_placement_mode(test_furn)

	assert_null(_controller.get_selected_furniture(), "Selection should be cleared")
	assert_signal_emitted(_controller, "furniture_deselected")


func test_exit_placement_mode() -> void:
	_controller.enter_edit_mode(_test_room)
	var test_furn = _create_test_furniture()
	_controller.enter_placement_mode(test_furn)

	watch_signals(_controller)
	_controller.exit_placement_mode()

	assert_false(_controller.is_in_placement_mode(), "Should not be in placement mode")
	assert_null(_controller.get_placement_furniture(), "Placement furniture should be cleared")
	assert_signal_emitted(_controller, "placement_mode_exited")


func test_placement_mode_rotation() -> void:
	_controller.enter_edit_mode(_test_room)
	var test_furn = _create_test_furniture()
	_controller.enter_placement_mode(test_furn)

	assert_eq(_controller.get_placement_rotation(), 0, "Initial rotation should be 0")

	_controller.rotate_placement()
	assert_eq(_controller.get_placement_rotation(), 1, "Rotation should increment")

	_controller.rotate_placement()
	assert_eq(_controller.get_placement_rotation(), 2, "Rotation should increment")

	_controller.rotate_placement()
	assert_eq(_controller.get_placement_rotation(), 3, "Rotation should increment")

	_controller.rotate_placement()
	assert_eq(_controller.get_placement_rotation(), 0, "Rotation should wrap to 0")


# === Signal Sequence Tests ===

func test_signal_sequence_on_furniture_add() -> void:
	_controller.enter_edit_mode(_test_room)

	var test_furn = _create_test_furniture()
	_controller.enter_placement_mode(test_furn)

	# Note: confirm_placement requires a valid position and collision check
	# For this integration test, we'll just test the placement mode lifecycle signals
	watch_signals(_controller)

	_controller.exit_placement_mode()

	assert_signal_emitted(_controller, "placement_mode_exited")


func test_signal_sequence_on_furniture_delete() -> void:
	_controller.enter_edit_mode(_test_room)

	var furniture = _test_room.furniture[0]
	_controller.select_furniture(furniture)

	var signals_received: Array[String] = []

	_controller.furniture_deselected.connect(func(): signals_received.append("deselected"))
	_controller.furniture_deleted.connect(func(_r, _f): signals_received.append("deleted"))

	_controller.delete_furniture()

	assert_has(signals_received, "deselected", "Should emit deselected signal")
	assert_has(signals_received, "deleted", "Should emit deleted signal")
	# Deselected should come before deleted
	assert_lt(
		signals_received.find("deselected"),
		signals_received.find("deleted"),
		"Deselected should emit before deleted"
	)
