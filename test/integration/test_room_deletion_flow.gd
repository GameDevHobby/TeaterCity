extends GutTest

## Integration tests for room deletion workflow
## Tests RoomManager unregistration and data cleanup

var _wall_op: WallOperation
var _deletion_op: DeletionOperation
var _test_rooms: Array[RoomInstance] = []


func before_each() -> void:
	_wall_op = WallOperation.new()
	_deletion_op = DeletionOperation.new()
	_test_rooms.clear()


func after_each() -> void:
	# Clean up any rooms we registered
	for room in _test_rooms:
		if RoomManager.get_all_rooms().has(room):
			RoomManager.unregister_room(room)
	_test_rooms.clear()
	_wall_op = null
	_deletion_op = null


func _create_and_register_room(id: String, box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new(id, "lobby")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	room.add_door(Vector2i(box.position.x + 2, box.position.y), 0)
	RoomManager.register_room(room)
	_test_rooms.append(room)
	return room


func test_unregister_removes_from_manager() -> void:
	var room = _create_and_register_room("test_room_1", Rect2i(0, 0, 5, 5))

	var initial_count = RoomManager.get_all_rooms().size()
	assert_has(RoomManager.get_all_rooms(), room, "Room should be registered")

	RoomManager.unregister_room(room)

	assert_eq(RoomManager.get_all_rooms().size(), initial_count - 1, "Room count should decrease by 1")
	assert_does_not_have(RoomManager.get_all_rooms(), room, "Room should not be in get_all_rooms() after unregister")


func test_unregister_nonexistent_room() -> void:
	var room = RoomInstance.new("not_registered", "lobby")
	room.bounding_box = Rect2i(10, 10, 5, 5)
	room.walls = _wall_op.generate_walls(room.bounding_box)

	var initial_count = RoomManager.get_all_rooms().size()

	# Unregistering non-existent room should not crash
	RoomManager.unregister_room(room)

	assert_eq(RoomManager.get_all_rooms().size(), initial_count, "Room count should not change")


func test_get_all_rooms_empty_after_unregister_all() -> void:
	var room1 = _create_and_register_room("test_room_1", Rect2i(0, 0, 5, 5))
	var room2 = _create_and_register_room("test_room_2", Rect2i(10, 0, 5, 5))
	var room3 = _create_and_register_room("test_room_3", Rect2i(20, 0, 5, 5))

	var initial_count = RoomManager.get_all_rooms().size()
	assert_true(initial_count >= 3, "Should have at least 3 rooms")

	RoomManager.unregister_room(room1)
	RoomManager.unregister_room(room2)
	RoomManager.unregister_room(room3)

	assert_eq(RoomManager.get_all_rooms().size(), initial_count - 3, "All 3 rooms should be removed")
	assert_does_not_have(RoomManager.get_all_rooms(), room1, "Room 1 should be gone")
	assert_does_not_have(RoomManager.get_all_rooms(), room2, "Room 2 should be gone")
	assert_does_not_have(RoomManager.get_all_rooms(), room3, "Room 3 should be gone")


func test_deletion_operation_clears_furniture() -> void:
	var room = _create_and_register_room("test_room_furniture", Rect2i(0, 0, 6, 6))

	# Add furniture to room
	var bench = load("res://data/furniture/seating_bench.tres") as FurnitureResource
	room.add_furniture(bench, Vector2i(2, 2), 0)
	room.add_furniture(bench, Vector2i(4, 4), 0)

	assert_eq(room.furniture.size(), 2, "Room should have 2 furniture pieces")

	# Delete furniture visuals (this should iterate room.furniture without crashing)
	_deletion_op.delete_furniture_visuals(room)

	# Furniture data still in room (deletion operation doesn't modify data)
	assert_eq(room.furniture.size(), 2, "Furniture data should still be in room after visual cleanup")


func test_shared_walls_preserved_on_delete() -> void:
	# Create two adjacent rooms that share a wall
	var room1 = _create_and_register_room("room_left", Rect2i(0, 0, 5, 5))
	var room2 = _create_and_register_room("room_right", Rect2i(5, 0, 5, 5))

	# Find shared walls (room1's right edge = room2's left edge at x=5)
	var shared_walls: Array[Vector2i] = []
	for wall_pos in room1.walls:
		if wall_pos in room2.walls:
			shared_walls.append(wall_pos)

	assert_true(shared_walls.size() > 0, "Adjacent rooms should have shared wall tiles")

	# Get deletable walls for room1 (should exclude shared walls)
	var deletable_walls = _deletion_op.get_deletable_walls(room1, RoomManager, [])

	# Verify shared walls are NOT in deletable list
	for shared_wall in shared_walls:
		assert_does_not_have(deletable_walls, shared_wall, "Shared wall %s should not be deletable" % shared_wall)


func test_unregister_clears_selection() -> void:
	var room = _create_and_register_room("test_room_selected", Rect2i(0, 0, 5, 5))

	# Select the room
	RoomManager.select_room(room)
	assert_eq(RoomManager.get_selected_room(), room, "Room should be selected")

	watch_signals(RoomManager)

	# Unregister should clear selection
	RoomManager.unregister_room(room)

	assert_null(RoomManager.get_selected_room(), "Selected room should be null after unregister")
	assert_signal_emitted(RoomManager, "selection_cleared", "selection_cleared signal should emit")


func test_unregister_emits_room_removed_signal() -> void:
	var room = _create_and_register_room("test_room_signal", Rect2i(0, 0, 5, 5))

	watch_signals(RoomManager)

	RoomManager.unregister_room(room)

	assert_signal_emitted_with_parameters(RoomManager, "room_removed", [room])


func test_unregister_disconnects_placement_changed_signal() -> void:
	var room = _create_and_register_room("test_room_signals", Rect2i(0, 0, 5, 5))

	# Verify placement_changed is connected
	assert_true(room.placement_changed.is_connected(RoomManager._on_room_changed), "placement_changed should be connected after registration")

	RoomManager.unregister_room(room)

	# After unregister, signal should be disconnected
	assert_false(room.placement_changed.is_connected(RoomManager._on_room_changed), "placement_changed should be disconnected after unregister")
