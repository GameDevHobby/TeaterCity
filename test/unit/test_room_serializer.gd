extends GutTest

## Unit tests for RoomSerializer
## Tests save/load functionality with actual file I/O
## IMPORTANT: Tests use real user:// directory and clean up after each test

var _wall_op: WallOperation


func before_each() -> void:
	_wall_op = WallOperation.new()
	# Ensure clean state before each test
	RoomSerializer.delete_save_file()


func after_each() -> void:
	# Clean up after each test
	RoomSerializer.delete_save_file()
	_wall_op = null


func _create_test_room(id: String, box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new(id, "lobby")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	room.add_door(Vector2i(box.position.x + 2, box.position.y), 0)  # North door
	return room


func _create_test_furniture() -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = "test_chair"
	furn.size = Vector2i(1, 1)
	furn.cost = 50
	furn.monthly_upkeep = 5
	return furn


# ============================================================================
# Save operations tests
# ============================================================================

func test_save_empty_rooms() -> void:
	var rooms: Array[RoomInstance] = []
	var result = RoomSerializer.save_rooms(rooms)
	assert_true(result, "save_rooms() should return true for empty array")


func test_save_single_room() -> void:
	var rooms: Array[RoomInstance] = []
	rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))

	var result = RoomSerializer.save_rooms(rooms)
	assert_true(result, "save_rooms() should return true for single room")


func test_save_multiple_rooms() -> void:
	var rooms: Array[RoomInstance] = []
	rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))
	rooms.append(_create_test_room("room2", Rect2i(10, 0, 5, 5)))
	rooms.append(_create_test_room("room3", Rect2i(20, 0, 5, 5)))

	var result = RoomSerializer.save_rooms(rooms)
	assert_true(result, "save_rooms() should return true for multiple rooms")


func test_save_creates_file() -> void:
	var rooms: Array[RoomInstance] = []
	rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))

	RoomSerializer.save_rooms(rooms)

	assert_true(RoomSerializer.has_save_file(), "has_save_file() should return true after save")


# ============================================================================
# Load operations tests
# ============================================================================

func test_load_no_file() -> void:
	var rooms = RoomSerializer.load_rooms()
	assert_not_null(rooms, "load_rooms() should return array even with no file")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array when no file exists")


func test_load_after_save() -> void:
	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))

	RoomSerializer.save_rooms(save_rooms)

	var loaded_rooms = RoomSerializer.load_rooms()
	assert_not_null(loaded_rooms, "load_rooms() should return rooms after save")
	assert_gt(loaded_rooms.size(), 0, "load_rooms() should return non-empty array after save")


func test_load_room_count() -> void:
	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))
	save_rooms.append(_create_test_room("room2", Rect2i(10, 0, 5, 5)))
	save_rooms.append(_create_test_room("room3", Rect2i(20, 0, 5, 5)))

	RoomSerializer.save_rooms(save_rooms)

	var loaded_rooms = RoomSerializer.load_rooms()
	assert_eq(loaded_rooms.size(), 3, "Loaded room count should match saved count")


# ============================================================================
# Round-trip data integrity tests
# ============================================================================

func test_roundtrip_room_id() -> void:
	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(_create_test_room("unique_room_id", Rect2i(0, 0, 5, 5)))

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].id, "unique_room_id", "Room ID should be preserved in round-trip")


func test_roundtrip_room_type() -> void:
	var room = RoomInstance.new("test_room", "backstage")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(Rect2i(0, 0, 5, 5))

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].room_type_id, "backstage", "Room type ID should be preserved in round-trip")


func test_roundtrip_bounding_box() -> void:
	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(_create_test_room("room1", Rect2i(5, 10, 8, 12)))

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	var expected_box = Rect2i(5, 10, 8, 12)
	assert_eq(loaded_rooms[0].bounding_box, expected_box, "Bounding box should be preserved in round-trip")


func test_roundtrip_walls() -> void:
	var save_rooms: Array[RoomInstance] = []
	var room = _create_test_room("room1", Rect2i(0, 0, 5, 5))
	save_rooms.append(room)

	var original_wall_count = room.walls.size()
	var original_first_wall = room.walls[0]

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].walls.size(), original_wall_count, "Wall count should be preserved")
	assert_eq(loaded_rooms[0].walls[0], original_first_wall, "Wall positions should be preserved")


func test_roundtrip_doors() -> void:
	var save_rooms: Array[RoomInstance] = []
	var room = _create_test_room("room1", Rect2i(0, 0, 5, 5))
	# Add an additional door with different direction
	room.add_door(Vector2i(0, 2), 3)  # West door
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].doors.size(), 2, "Door count should be preserved")
	# Check second door (we know first door is North from _create_test_room)
	assert_eq(loaded_rooms[0].doors[1].direction, 3, "Door direction should be preserved")


func test_roundtrip_furniture() -> void:
	var room = RoomInstance.new("room1", "lobby")
	room.bounding_box = Rect2i(0, 0, 10, 10)
	room.walls = _wall_op.generate_walls(Rect2i(0, 0, 10, 10))

	var furniture = _create_test_furniture()
	room.add_furniture(furniture, Vector2i(3, 3), 0)
	room.add_furniture(furniture, Vector2i(5, 5), 90)

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].furniture.size(), 2, "Furniture count should be preserved")
	assert_eq(loaded_rooms[0].furniture[0].position, Vector2i(3, 3), "Furniture position should be preserved")
	assert_eq(loaded_rooms[0].furniture[1].rotation, 90, "Furniture rotation should be preserved")


func test_roundtrip_multiple_rooms() -> void:
	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))
	save_rooms.append(_create_test_room("room2", Rect2i(10, 0, 6, 6)))
	save_rooms.append(_create_test_room("room3", Rect2i(20, 0, 7, 7)))

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 3, "All rooms should be preserved")
	assert_eq(loaded_rooms[0].id, "room1", "First room ID should match")
	assert_eq(loaded_rooms[1].id, "room2", "Second room ID should match")
	assert_eq(loaded_rooms[2].id, "room3", "Third room ID should match")
	assert_eq(loaded_rooms[1].bounding_box.size, Vector2i(6, 6), "Room properties should be preserved")


# ============================================================================
# has_save_file() tests
# ============================================================================

func test_has_save_file_false_initially() -> void:
	# before_each ensures no file exists
	assert_false(RoomSerializer.has_save_file(), "has_save_file() should return false initially")


func test_has_save_file_true_after_save() -> void:
	var rooms: Array[RoomInstance] = []
	rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))

	RoomSerializer.save_rooms(rooms)

	assert_true(RoomSerializer.has_save_file(), "has_save_file() should return true after save")


# ============================================================================
# delete_save_file() tests
# ============================================================================

func test_delete_nonexistent_returns_true() -> void:
	# before_each ensures no file exists
	var result = RoomSerializer.delete_save_file()
	assert_true(result, "delete_save_file() should return true for nonexistent file (no-op)")


func test_delete_existing_file() -> void:
	var rooms: Array[RoomInstance] = []
	rooms.append(_create_test_room("room1", Rect2i(0, 0, 5, 5)))
	RoomSerializer.save_rooms(rooms)

	assert_true(RoomSerializer.has_save_file(), "File should exist before deletion")

	var result = RoomSerializer.delete_save_file()

	assert_true(result, "delete_save_file() should return true")
	assert_false(RoomSerializer.has_save_file(), "has_save_file() should return false after deletion")


# ============================================================================
# Edge case tests
# ============================================================================

func test_roundtrip_empty_rooms_array() -> void:
	var save_rooms: Array[RoomInstance] = []

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 0, "Empty rooms array should round-trip correctly")


func test_roundtrip_room_with_no_doors() -> void:
	var room = RoomInstance.new("room1", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(Rect2i(0, 0, 5, 5))
	# Don't add any doors

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].doors.size(), 0, "Room with no doors should round-trip correctly")


func test_roundtrip_room_with_no_furniture() -> void:
	var room = _create_test_room("room1", Rect2i(0, 0, 5, 5))
	# _create_test_room doesn't add furniture, only door

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].furniture.size(), 0, "Room with no furniture should round-trip correctly")
