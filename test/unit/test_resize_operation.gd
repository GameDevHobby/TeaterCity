extends GutTest
## Unit tests for ResizeOperation
## Tests room resize validation: size constraints, overlap detection, furniture bounds

var _resize_op: ResizeOperation
var _wall_op: WallOperation
var _mock_room_manager: Node


## Mock RoomManager for get_all_rooms() calls
class MockRoomManager extends Node:
	var rooms: Array[RoomInstance] = []

	func get_all_rooms() -> Array[RoomInstance]:
		return rooms

	func add_room(room: RoomInstance) -> void:
		rooms.append(room)

	func clear_rooms() -> void:
		rooms.clear()


func before_each() -> void:
	_resize_op = ResizeOperation.new()
	_wall_op = WallOperation.new()
	_mock_room_manager = MockRoomManager.new()
	add_child_autofree(_mock_room_manager)


func after_each() -> void:
	_resize_op = null
	_wall_op = null
	# _mock_room_manager cleaned up by autofree


func _create_room_with_walls(box: Rect2i, room_type_id: String = "lobby") -> RoomInstance:
	var room = RoomInstance.new("test_room", room_type_id)
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	return room


func _create_furniture(id: String, size: Vector2i, access_offsets: Array[Vector2i] = []) -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = id
	furn.size = size
	furn.access_offsets = access_offsets
	return furn


# ============================================================================
# SIZE CONSTRAINT VALIDATION TESTS
# ============================================================================

func test_valid_resize_within_constraints() -> void:
	# Lobby room type: min 4x4, max 12x12
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Resize to 6x6 (within constraints)
	var new_box = Rect2i(0, 0, 6, 6)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_true(result.is_valid, "Resize within size constraints should be valid")
	assert_eq(result.error, "", "Valid resize should have no error")


func test_invalid_resize_too_small() -> void:
	# Lobby room type: min 4x4
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Resize to 3x3 (below minimum)
	var new_box = Rect2i(0, 0, 3, 3)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize below min size should fail")
	assert_string_contains(result.error.to_lower(), "size", "Error should mention size constraint")


func test_invalid_resize_too_large() -> void:
	# Lobby room type: max 12x12
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Resize to 15x15 (above maximum)
	var new_box = Rect2i(0, 0, 15, 15)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize above max size should fail")
	assert_string_contains(result.error.to_lower(), "size", "Error should mention size constraint")


func test_swapped_orientation_valid() -> void:
	# Lobby room type: min 4x4, max 12x12 (symmetrical, so both orientations valid)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Both 4x6 and 6x4 should be valid within 4x4 to 12x12
	var result_4x6 = _resize_op.validate_resize(room, Rect2i(0, 0, 4, 6), _mock_room_manager)
	var result_6x4 = _resize_op.validate_resize(room, Rect2i(0, 0, 6, 4), _mock_room_manager)

	assert_true(result_4x6.is_valid, "4x6 should be valid")
	assert_true(result_6x4.is_valid, "6x4 should be valid")


func test_result_error_contains_size_info() -> void:
	# Lobby room type: min 4x4, max 12x12
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Resize to 2x2 (invalid)
	var new_box = Rect2i(0, 0, 2, 2)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "2x2 should be invalid")
	# Error should contain actual size and required range
	assert_string_contains(result.error, "2x2", "Error should show actual size")
	assert_string_contains(result.error, "4x4", "Error should show minimum size")


# ============================================================================
# ROOM OVERLAP VALIDATION TESTS
# ============================================================================

func test_valid_resize_no_overlap() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	var other_room = _create_room_with_walls(Rect2i(10, 10, 5, 5), "lobby")
	_mock_room_manager.add_room(room)
	_mock_room_manager.add_room(other_room)

	# Resize to 6x6 (no overlap with other room at 10,10)
	var new_box = Rect2i(0, 0, 6, 6)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_true(result.is_valid, "Resize with no overlap should be valid")


func test_invalid_resize_overlaps_other_room() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	var other_room = _create_room_with_walls(Rect2i(6, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)
	_mock_room_manager.add_room(other_room)

	# Resize to 8x5 (would overlap with room at 6,0)
	var new_box = Rect2i(0, 0, 8, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize overlapping another room should fail")
	assert_string_contains(result.error.to_lower(), "overlap", "Error should mention overlap")


func test_result_contains_overlapped_room() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	var other_room = _create_room_with_walls(Rect2i(6, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)
	_mock_room_manager.add_room(other_room)

	# Resize to 8x5 (overlaps other_room)
	var new_box = Rect2i(0, 0, 8, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Should fail on overlap")
	assert_eq(result.overlapped_room, other_room, "overlapped_room should be set to the overlapping room")


# ============================================================================
# FURNITURE BOUNDS VALIDATION TESTS
# ============================================================================

func test_valid_resize_furniture_fits() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture at (2, 2) - 1x1 size
	var furn = _create_furniture("chair", Vector2i(1, 1))
	room.add_furniture(furn, Vector2i(2, 2), 0)

	# Resize to 5x5 - furniture at (2,2) still fits
	var new_box = Rect2i(0, 0, 5, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_true(result.is_valid, "Resize with furniture still inside should be valid")
	assert_eq(result.blocked_furniture.size(), 0, "No furniture should be blocked")


func test_invalid_resize_furniture_outside() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture at (4, 4)
	var furn = _create_furniture("chair", Vector2i(1, 1))
	room.add_furniture(furn, Vector2i(4, 4), 0)

	# Resize to 4x4 - furniture at (4,4) would be outside (walls at 0,1,2,3)
	var new_box = Rect2i(0, 0, 4, 4)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize with furniture outside should fail")
	assert_string_contains(result.error.to_lower(), "furniture", "Error should mention furniture")


func test_invalid_resize_furniture_on_wall() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture at (2, 2)
	var furn = _create_furniture("chair", Vector2i(1, 1))
	room.add_furniture(furn, Vector2i(2, 2), 0)

	# Resize to 5x5 - position (2,2) becomes interior in 5x5
	# But let's resize to 4x4 where (2,2) is interior - actually walls are at edges
	# For 4x4: walls at (0,y), (3,y), (x,0), (x,3), interior is (1,1), (1,2), (2,1), (2,2)
	# Let's place furniture that will definitely be on a wall
	var room2 = _create_room_with_walls(Rect2i(0, 0, 8, 8), "lobby")
	_mock_room_manager.add_room(room2)

	# Add furniture at (4, 4) - interior of 8x8
	var furn2 = _create_furniture("table", Vector2i(1, 1))
	room2.add_furniture(furn2, Vector2i(4, 4), 0)

	# Resize to 5x5 - walls would be at edges (0,x), (4,x), etc.
	# Position (4,4) would be the bottom-right corner = wall
	var new_box = Rect2i(0, 0, 5, 5)
	var result = _resize_op.validate_resize(room2, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize placing furniture on wall should fail")


func test_invalid_resize_access_tiles_blocked() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 8, 8), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture at (4, 4) with south access tile at (4, 5)
	var access_offsets: Array[Vector2i] = [Vector2i(0, 1)]
	var furn = _create_furniture("counter", Vector2i(1, 1), access_offsets)
	room.add_furniture(furn, Vector2i(4, 4), 0)

	# Resize to 6x6 - access tile at (4,5) would be on the wall (y=5 is bottom wall edge)
	var new_box = Rect2i(0, 0, 6, 6)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Resize blocking access tiles should fail")


func test_result_blocked_furniture_list() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 8, 8), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture at (6, 6)
	var furn = _create_furniture("chair", Vector2i(1, 1))
	room.add_furniture(furn, Vector2i(6, 6), 0)

	# Resize to 5x5 - furniture at (6,6) outside bounds
	var new_box = Rect2i(0, 0, 5, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Should fail with blocked furniture")
	assert_eq(result.blocked_furniture.size(), 1, "Should have 1 blocked furniture")
	assert_eq(result.blocked_furniture[0].position, Vector2i(6, 6), "Blocked furniture should be at (6,6)")


func test_multiple_blocked_furniture() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 8, 8), "lobby")
	_mock_room_manager.add_room(room)

	# Add multiple furniture pieces that will be outside
	var furn1 = _create_furniture("chair1", Vector2i(1, 1))
	var furn2 = _create_furniture("chair2", Vector2i(1, 1))
	room.add_furniture(furn1, Vector2i(6, 6), 0)
	room.add_furniture(furn2, Vector2i(6, 7), 0)

	# Resize to 5x5 - both furniture outside
	var new_box = Rect2i(0, 0, 5, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_false(result.is_valid, "Should fail with multiple blocked furniture")
	assert_eq(result.blocked_furniture.size(), 2, "Should have 2 blocked furniture items")


# ============================================================================
# RESULT STRUCTURE TESTS
# ============================================================================

func test_result_structure_valid() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	var new_box = Rect2i(0, 0, 6, 6)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_typeof(result.is_valid, TYPE_BOOL, "is_valid should be bool")
	assert_typeof(result.error, TYPE_STRING, "error should be string")
	assert_typeof(result.blocked_furniture, TYPE_ARRAY, "blocked_furniture should be array")
	assert_true(result.is_valid, "Valid resize should have is_valid = true")
	assert_eq(result.error, "", "Valid resize should have empty error")
	assert_eq(result.blocked_furniture.size(), 0, "Valid resize should have no blocked furniture")


func test_result_structure_invalid() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5), "lobby")
	_mock_room_manager.add_room(room)

	# Invalid: too small
	var new_box = Rect2i(0, 0, 2, 2)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_typeof(result.is_valid, TYPE_BOOL, "is_valid should be bool")
	assert_typeof(result.error, TYPE_STRING, "error should be string")
	assert_typeof(result.blocked_furniture, TYPE_ARRAY, "blocked_furniture should be array")
	assert_false(result.is_valid, "Invalid resize should have is_valid = false")
	assert_ne(result.error, "", "Invalid resize should have non-empty error")


func test_result_blocked_furniture_type() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 8, 8), "lobby")
	_mock_room_manager.add_room(room)

	# Add furniture that will be blocked
	var furn = _create_furniture("chair", Vector2i(1, 1))
	room.add_furniture(furn, Vector2i(6, 6), 0)

	# Resize to 5x5
	var new_box = Rect2i(0, 0, 5, 5)
	var result = _resize_op.validate_resize(room, new_box, _mock_room_manager)

	assert_typeof(result.blocked_furniture, TYPE_ARRAY, "blocked_furniture should be array")
	assert_true(result.blocked_furniture.size() > 0, "Should have blocked furniture")
	# Verify it's a typed array of FurniturePlacement
	assert_true(result.blocked_furniture[0] is RoomInstance.FurniturePlacement, "blocked_furniture should contain FurniturePlacement objects")
