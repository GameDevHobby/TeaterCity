extends GutTest

## Unit tests for RoomSerializer edge cases
## Tests error handling, corrupted files, and boundary conditions

const SAVE_PATH := "user://saves/rooms.json"
const SAVE_DIR := "user://saves"

var _wall_op: WallOperation


func before_each() -> void:
	_wall_op = WallOperation.new()
	RoomSerializer.delete_save_file()
	# Ensure clean directory
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func after_each() -> void:
	RoomSerializer.delete_save_file()
	_wall_op = null


func _write_raw_file(content: String) -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _create_test_room(id: String, box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new(id, "lobby")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	room.add_door(Vector2i(box.position.x + 2, box.position.y), 0)  # North door
	return room


# ============================================================================
# Corrupted JSON tests
# ============================================================================

func test_load_invalid_json_syntax() -> void:
	_write_raw_file("{invalid json")

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for invalid JSON")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array for invalid JSON")
	assert_push_error_count(1, "Should log one push_error for invalid JSON")


func test_load_truncated_json() -> void:
	_write_raw_file('{"version": 1, "rooms": [{"id": "room1", "room_type_id": "lobby"')

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for truncated JSON")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array for truncated JSON")
	assert_push_error_count(1, "Should log one push_error for truncated JSON")


func test_load_empty_file() -> void:
	_write_raw_file("")

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for empty file")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array for empty file")
	assert_push_error_count(1, "Should log one push_error for empty file")


func test_load_null_json() -> void:
	_write_raw_file("null")

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for null JSON")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array for null JSON")
	assert_push_error_count(1, "Should log one push_error for null JSON")


func test_load_array_root() -> void:
	_write_raw_file('[{"id": "room1"}]')

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for array root")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array for array root (not dict)")
	assert_push_error_count(1, "Should log one push_error for array root")


# ============================================================================
# Invalid structure tests
# ============================================================================

func test_load_missing_rooms_key() -> void:
	_write_raw_file('{"version": 1, "saved_at": "2026-01-01"}')

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array when missing rooms key")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array when missing rooms key")
	assert_push_error_count(1, "Should log one push_error for missing rooms key")


func test_load_rooms_not_array() -> void:
	_write_raw_file('{"version": 1, "rooms": "not an array"}')

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array when rooms is not array")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array when rooms is not array")
	assert_push_error_count(1, "Should log one push_error for rooms not array")


func test_load_room_not_dict() -> void:
	_write_raw_file('{"version": 1, "rooms": ["not a dict", "also not a dict"]}')

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array when room entries are not dicts")
	assert_eq(rooms.size(), 0, "load_rooms() should return empty array when room entries are not dicts")


func test_load_partial_valid_rooms() -> void:
	# Create a valid room first
	var valid_room = _create_test_room("valid_room", Rect2i(0, 0, 5, 5))
	var valid_dict = valid_room.to_dict()

	# Build JSON with mix of valid and invalid entries
	var mixed_data = {
		"version": 1,
		"saved_at": "2026-01-01",
		"rooms": [
			"invalid string",
			valid_dict,
			{"id": "incomplete", "missing": "room_type_id"},
			valid_dict
		]
	}

	_write_raw_file(JSON.stringify(mixed_data))

	var rooms = RoomSerializer.load_rooms()

	assert_not_null(rooms, "load_rooms() should return array for partial valid data")
	# Should load only the 2 valid rooms, skip the invalid ones
	assert_eq(rooms.size(), 2, "load_rooms() should load only valid rooms from mixed data")


# ============================================================================
# Boundary condition tests
# ============================================================================

func test_save_load_large_room_set() -> void:
	var rooms: Array[RoomInstance] = []
	for i in range(50):
		var room = RoomInstance.new("room_%d" % i, "lobby")
		room.bounding_box = Rect2i(i * 10, 0, 5, 5)
		room.walls = _wall_op.generate_walls(room.bounding_box)
		rooms.append(room)

	var save_result = RoomSerializer.save_rooms(rooms)
	assert_true(save_result, "Should save large room set")

	var loaded = RoomSerializer.load_rooms()
	assert_eq(loaded.size(), 50, "Should load all 50 rooms")
	assert_eq(loaded[0].id, "room_0", "First room ID should match")
	assert_eq(loaded[49].id, "room_49", "Last room ID should match")


func test_special_characters_in_id() -> void:
	var room = RoomInstance.new("test-room_1", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(Rect2i(0, 0, 5, 5))

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded = RoomSerializer.load_rooms()

	assert_eq(loaded[0].id, "test-room_1", "Special characters in ID should be preserved")


func test_unicode_in_room_id() -> void:
	var room = RoomInstance.new("room_café_🎭", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	room.walls = _wall_op.generate_walls(Rect2i(0, 0, 5, 5))

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded = RoomSerializer.load_rooms()

	assert_eq(loaded[0].id, "room_café_🎭", "Unicode characters in ID should be preserved")


func test_negative_bounding_box() -> void:
	var room = RoomInstance.new("negative_room", "lobby")
	room.bounding_box = Rect2i(-10, -10, 5, 5)
	room.walls = _wall_op.generate_walls(Rect2i(-10, -10, 5, 5))

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	RoomSerializer.save_rooms(save_rooms)
	var loaded = RoomSerializer.load_rooms()

	assert_eq(loaded[0].bounding_box.position, Vector2i(-10, -10), "Negative coordinates should be preserved")


func test_zero_size_bounding_box() -> void:
	var room = RoomInstance.new("zero_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 0, 0)
	# walls defaults to empty array, no need to assign

	var save_rooms: Array[RoomInstance] = []
	save_rooms.append(room)

	var save_result = RoomSerializer.save_rooms(save_rooms)
	assert_true(save_result, "Should save degenerate room without crash")

	var loaded = RoomSerializer.load_rooms()
	assert_eq(loaded[0].bounding_box.size, Vector2i(0, 0), "Zero size should be preserved")


# ============================================================================
# Graceful degradation tests
# ============================================================================

func test_corrupted_does_not_crash() -> void:
	# Test various types of corruption
	var corrupted_files = [
		"{",
		"}",
		"[",
		"]",
		'{"rooms":',
		'{"rooms":[{',
		"random text",
		"123456",
		"true",
		"false",
		'{"version":"not a number","rooms":[]}',
	]

	for corrupted in corrupted_files:
		RoomSerializer.delete_save_file()
		_write_raw_file(corrupted)

		var rooms = RoomSerializer.load_rooms()

		assert_not_null(rooms, "load_rooms() should never crash, even with corruption: %s" % corrupted)
		assert_true(rooms is Array, "load_rooms() should always return an array")

	# Expect errors from corrupted files (most will log push_error)
	assert_push_error_count(10, "Should log push_errors for corrupted files")


func test_error_does_not_delete_file() -> void:
	_write_raw_file("{invalid json")

	var rooms = RoomSerializer.load_rooms()

	assert_eq(rooms.size(), 0, "Should return empty array for corrupt file")
	assert_true(FileAccess.file_exists(SAVE_PATH), "Corrupt file should still exist after failed load")
	assert_push_error_count(1, "Should log one push_error for corrupt file")
