extends GutTest

## Integration tests for persistence workflow
## Tests full save/load cycle simulating game session lifecycle

var _wall_op: WallOperation


func before_each() -> void:
	_wall_op = WallOperation.new()
	# Clean save state
	RoomSerializer.delete_save_file()
	# Clean any rooms from RoomManager (if we're using it)
	_cleanup_room_manager()


func after_each() -> void:
	RoomSerializer.delete_save_file()
	_cleanup_room_manager()
	_wall_op = null


func _cleanup_room_manager() -> void:
	var rooms = RoomManager.get_all_rooms().duplicate()
	for room in rooms:
		RoomManager.unregister_room(room)


func _create_test_room(id: String, box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new(id, "lobby")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	room.add_door(Vector2i(box.position.x + 2, box.position.y), 0)
	return room


func test_create_save_reload_flow() -> void:
	# Create room
	var room = _create_test_room("test_room_1", Rect2i(0, 0, 5, 5))
	var original_walls_count = room.walls.size()
	var original_door_pos = room.doors[0].position

	# Save
	var rooms_to_save: Array[RoomInstance] = [room]
	var save_success = RoomSerializer.save_rooms(rooms_to_save)
	assert_true(save_success, "Save should succeed")

	# Clear data (simulate restart)
	room = null
	rooms_to_save.clear()

	# Load
	var loaded_rooms = RoomSerializer.load_rooms()
	assert_eq(loaded_rooms.size(), 1, "Should load 1 room")

	var loaded_room = loaded_rooms[0]
	assert_eq(loaded_room.id, "test_room_1", "Room ID should match")
	assert_eq(loaded_room.room_type_id, "lobby", "Room type should match")
	assert_eq(loaded_room.walls.size(), original_walls_count, "Wall count should match")
	assert_eq(loaded_room.doors.size(), 1, "Should have 1 door")
	assert_eq(loaded_room.doors[0].position, original_door_pos, "Door position should match")


func test_multiple_rooms_persist() -> void:
	# Create multiple rooms
	var room1 = _create_test_room("room_1", Rect2i(0, 0, 5, 5))
	var room2 = _create_test_room("room_2", Rect2i(10, 0, 6, 6))
	var room3 = _create_test_room("room_3", Rect2i(20, 0, 4, 4))

	var rooms_to_save: Array[RoomInstance] = [room1, room2, room3]
	var save_success = RoomSerializer.save_rooms(rooms_to_save)
	assert_true(save_success, "Save should succeed")

	# Clear and load
	rooms_to_save.clear()
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 3, "Should load 3 rooms")

	# Verify each room loaded
	var ids = [loaded_rooms[0].id, loaded_rooms[1].id, loaded_rooms[2].id]
	assert_has(ids, "room_1", "Should have room_1")
	assert_has(ids, "room_2", "Should have room_2")
	assert_has(ids, "room_3", "Should have room_3")


func test_furniture_persists() -> void:
	var room = _create_test_room("room_with_furniture", Rect2i(0, 0, 6, 6))

	# Add furniture
	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	room.add_furniture(bench, Vector2i(2, 2), 0)
	room.add_furniture(bench, Vector2i(4, 4), 1)

	assert_eq(room.furniture.size(), 2, "Should have 2 furniture pieces before save")

	# Save and reload
	RoomSerializer.save_rooms([room])
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 1, "Should load 1 room")
	var loaded_room = loaded_rooms[0]
	assert_eq(loaded_room.furniture.size(), 2, "Should have 2 furniture pieces after reload")
	assert_eq(loaded_room.furniture[0].position, Vector2i(2, 2), "First furniture position should match")
	assert_eq(loaded_room.furniture[0].rotation, 0, "First furniture rotation should match")
	assert_eq(loaded_room.furniture[1].position, Vector2i(4, 4), "Second furniture position should match")
	assert_eq(loaded_room.furniture[1].rotation, 1, "Second furniture rotation should match")


func test_doors_persist() -> void:
	var room = _create_test_room("room_with_doors", Rect2i(0, 0, 7, 7))

	# Add additional doors
	room.add_door(Vector2i(7, 3), 1)  # East door

	assert_eq(room.doors.size(), 2, "Should have 2 doors before save")

	# Save and reload
	RoomSerializer.save_rooms([room])
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 1, "Should load 1 room")
	var loaded_room = loaded_rooms[0]
	assert_eq(loaded_room.doors.size(), 2, "Should have 2 doors after reload")

	# Verify door positions and directions
	var door_positions = [loaded_room.doors[0].position, loaded_room.doors[1].position]
	assert_has(door_positions, Vector2i(2, 0), "Should have north door")
	assert_has(door_positions, Vector2i(7, 3), "Should have east door")


func test_room_manager_integration() -> void:
	# Create rooms and register with RoomManager
	var room1 = _create_test_room("manager_room_1", Rect2i(0, 0, 5, 5))
	var room2 = _create_test_room("manager_room_2", Rect2i(10, 0, 5, 5))

	RoomManager.register_room(room1)
	RoomManager.register_room(room2)

	assert_eq(RoomManager.get_all_rooms().size(), 2, "Manager should have 2 rooms")

	# Save from RoomManager
	var rooms_to_save = RoomManager.get_all_rooms()
	var save_success = RoomSerializer.save_rooms(rooms_to_save)
	assert_true(save_success, "Save from manager should succeed")

	# Unregister all (simulate restart)
	RoomManager.unregister_room(room1)
	RoomManager.unregister_room(room2)
	assert_eq(RoomManager.get_all_rooms().size(), 0, "Manager should be empty")

	# Load back into manager
	var loaded_rooms = RoomSerializer.load_rooms()
	for loaded_room in loaded_rooms:
		RoomManager.register_room(loaded_room)

	assert_eq(RoomManager.get_all_rooms().size(), 2, "Manager should have 2 rooms after reload")


func test_placement_changed_can_trigger_save() -> void:
	var room = _create_test_room("room_signal_test", Rect2i(0, 0, 5, 5))

	watch_signals(room)

	# Modify room (should emit placement_changed)
	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	room.add_furniture(bench, Vector2i(2, 2), 0)

	assert_signal_emitted(room, "placement_changed", "placement_changed should emit when furniture added")


func test_save_after_modification() -> void:
	var room = _create_test_room("room_modify_test", Rect2i(0, 0, 6, 6))

	# Initial save
	RoomSerializer.save_rooms([room])
	var loaded_rooms = RoomSerializer.load_rooms()
	assert_eq(loaded_rooms[0].furniture.size(), 0, "Should have no furniture initially")

	# Modify: add furniture
	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	room.add_furniture(bench, Vector2i(3, 3), 2)

	# Save modification
	RoomSerializer.save_rooms([room])
	var reloaded_rooms = RoomSerializer.load_rooms()

	assert_eq(reloaded_rooms[0].furniture.size(), 1, "Modification should persist")
	assert_eq(reloaded_rooms[0].furniture[0].position, Vector2i(3, 3), "Modified furniture position should persist")
	assert_eq(reloaded_rooms[0].furniture[0].rotation, 2, "Modified furniture rotation should persist")


func test_simulated_restart() -> void:
	# Session 1: Create and save
	var room1 = _create_test_room("session_room_1", Rect2i(0, 0, 5, 5))
	var room2 = _create_test_room("session_room_2", Rect2i(10, 0, 6, 6))

	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	room1.add_furniture(bench, Vector2i(2, 2), 0)

	RoomManager.register_room(room1)
	RoomManager.register_room(room2)

	var save_success = RoomSerializer.save_rooms(RoomManager.get_all_rooms())
	assert_true(save_success, "Initial save should succeed")

	# Simulate restart: clear all state
	_cleanup_room_manager()
	room1 = null
	room2 = null

	assert_eq(RoomManager.get_all_rooms().size(), 0, "Manager should be empty after simulated restart")

	# Session 2: Load from save
	var loaded_rooms = RoomSerializer.load_rooms()
	assert_eq(loaded_rooms.size(), 2, "Should load 2 rooms after restart")

	for loaded_room in loaded_rooms:
		RoomManager.register_room(loaded_room)

	assert_eq(RoomManager.get_all_rooms().size(), 2, "Manager should have 2 rooms after reload")

	# Verify data integrity
	var room_with_furniture = null
	for room in RoomManager.get_all_rooms():
		if room.furniture.size() > 0:
			room_with_furniture = room
			break

	assert_not_null(room_with_furniture, "Should find room with furniture")
	assert_eq(room_with_furniture.furniture.size(), 1, "Room should have 1 furniture piece")


func test_empty_save_and_load() -> void:
	# Save empty array
	var empty_rooms: Array[RoomInstance] = []
	var save_success = RoomSerializer.save_rooms(empty_rooms)
	assert_true(save_success, "Saving empty array should succeed")

	# Load should return empty array
	var loaded_rooms = RoomSerializer.load_rooms()
	assert_eq(loaded_rooms.size(), 0, "Loading empty save should return empty array")


func test_room_without_furniture_persists() -> void:
	var room = _create_test_room("minimal_room", Rect2i(0, 0, 4, 4))
	# Room has no furniture, just walls and one door from _create_test_room

	RoomSerializer.save_rooms([room])
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms.size(), 1, "Minimal room should load")
	assert_eq(loaded_rooms[0].furniture.size(), 0, "Should have no furniture")
	assert_eq(loaded_rooms[0].doors.size(), 1, "Should have 1 door")
	assert_true(loaded_rooms[0].walls.size() > 0, "Should have walls")


func test_bounding_box_persists() -> void:
	var original_box = Rect2i(5, 10, 7, 8)
	var room = _create_test_room("bbox_test", original_box)

	RoomSerializer.save_rooms([room])
	var loaded_rooms = RoomSerializer.load_rooms()

	assert_eq(loaded_rooms[0].bounding_box, original_box, "Bounding box should match exactly")
	assert_eq(loaded_rooms[0].bounding_box.position.x, 5, "X position should match")
	assert_eq(loaded_rooms[0].bounding_box.position.y, 10, "Y position should match")
	assert_eq(loaded_rooms[0].bounding_box.size.x, 7, "Width should match")
	assert_eq(loaded_rooms[0].bounding_box.size.y, 8, "Height should match")
