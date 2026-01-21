extends GutTest
## Unit tests for ValidationOperation
## Tests room validation against room type requirements
##
## Note: These tests use the actual RoomTypeRegistry singleton since ValidationOperation
## relies on it internally. Tests use real room type IDs like "lobby" from the registry.

var _validation_op: ValidationOperation
var _wall_op: WallOperation


func before_each() -> void:
	_validation_op = ValidationOperation.new()
	_wall_op = WallOperation.new()
	# Ensure registry is loaded
	RoomTypeRegistry.get_instance()


func after_each() -> void:
	_validation_op = null
	_wall_op = null


func _create_furniture_resource(id: String, name: String) -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = id
	furn.name = name
	furn.size = Vector2i(1, 1)
	return furn


func _get_seating_bench() -> FurnitureResource:
	# Load the actual seating bench resource that the lobby requires
	return load("res://data/furniture/seating_bench.tres") as FurnitureResource


func test_valid_room_passes() -> void:
	# Create a valid lobby room (4x4 min size, requires 1 door, requires 1 seating_bench)
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	room.add_door(Vector2i(2, 0), 0)

	# Add required furniture (seating_bench)
	var bench = _get_seating_bench()
	room.add_furniture(bench, Vector2i(2, 2), 0)

	var result = _validation_op.validate_complete(room)
	assert_true(result.is_valid, "Valid room should pass validation")
	assert_eq(result.errors.size(), 0, "Valid room should have no errors")


func test_room_too_small_fails() -> void:
	# Create room smaller than min_size (4x4 for lobby)
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 3, 3)  # Too small
	room.walls = _wall_op.generate_walls(room.bounding_box)
	room.add_door(Vector2i(1, 0), 0)

	var bench = _get_seating_bench()
	room.add_furniture(bench, Vector2i(1, 1), 0)

	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room below min_size should fail")
	assert_true(result.errors.size() > 0, "Should have error messages")


func test_room_too_small_error_message() -> void:
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 2, 2)
	room.walls = _wall_op.generate_walls(room.bounding_box)

	var result = _validation_op.validate_complete(room)

	var has_size_error = false
	for error in result.errors:
		if "small" in error.to_lower():
			has_size_error = true
			break

	assert_true(has_size_error, "Should have a 'too small' error message")


func test_missing_doors_fails() -> void:
	# Create room without required doors (lobby requires min 1 door)
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	# No doors added

	var bench = _get_seating_bench()
	room.add_furniture(bench, Vector2i(2, 2), 0)

	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room without required doors should fail")

	var has_door_error = false
	for error in result.errors:
		if "door" in error.to_lower():
			has_door_error = true
			break

	assert_true(has_door_error, "Should have a door requirement error")


func test_missing_required_furniture_fails() -> void:
	# Create room without required furniture (lobby requires seating_bench)
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	room.add_door(Vector2i(2, 0), 0)
	# No furniture added

	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room without required furniture should fail")

	var has_furniture_error = false
	for error in result.errors:
		if "need" in error.to_lower() and ("bench" in error.to_lower() or "seating" in error.to_lower()):
			has_furniture_error = true
			break

	assert_true(has_furniture_error, "Should have a furniture requirement error")


func test_invalid_room_type_fails() -> void:
	# Create room with nonexistent room_type_id
	var room = RoomInstance.new("test_room", "nonexistent_room_type_xyz")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(room.bounding_box)

	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room with invalid room type should fail")

	var has_invalid_type_error = false
	for error in result.errors:
		if "invalid" in error.to_lower() and "type" in error.to_lower():
			has_invalid_type_error = true
			break

	assert_true(has_invalid_type_error, "Should have an 'invalid room type' error")


func test_validation_result_structure() -> void:
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 2, 2)  # Invalid size

	var result = _validation_op.validate_complete(room)

	# Check that result has expected properties
	assert_not_null(result, "Result should not be null")
	assert_typeof(result.is_valid, TYPE_BOOL, "is_valid should be bool")
	assert_typeof(result.errors, TYPE_ARRAY, "errors should be array")


func test_multiple_validation_errors() -> void:
	# Create room with multiple issues: too small, no doors, no furniture
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 2, 2)  # Too small (min 4x4)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	# No doors, no furniture

	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room with multiple issues should fail")
	assert_true(result.errors.size() >= 2, "Should have multiple error messages")


func test_valid_room_with_extra_furniture() -> void:
	# Room with required furniture plus extra should still pass
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 6, 6)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	room.add_door(Vector2i(3, 0), 0)

	var bench = _get_seating_bench()
	room.add_furniture(bench, Vector2i(2, 2), 0)
	room.add_furniture(bench, Vector2i(3, 2), 0)  # Extra bench

	var result = _validation_op.validate_complete(room)
	assert_true(result.is_valid, "Room with extra furniture should still pass")
