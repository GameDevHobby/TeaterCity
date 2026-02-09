extends GutTest
## Unit tests for DeletionOperation
## Tests shared wall detection and cleanup sequences

var _deletion_op: DeletionOperation
var _wall_op: WallOperation


func before_each() -> void:
	_deletion_op = DeletionOperation.new()
	_wall_op = WallOperation.new()


func after_each() -> void:
	_deletion_op = null
	_wall_op = null


func _create_room_with_walls(box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new("test_room", "test_type")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	return room


class MockRoomManager extends Node:
	var rooms: Array[RoomInstance] = []

	func get_all_rooms() -> Array[RoomInstance]:
		return rooms

	func add_room(room: RoomInstance) -> void:
		rooms.append(room)


func _create_mock_room_manager() -> MockRoomManager:
	var rm = MockRoomManager.new()
	add_child_autofree(rm)
	return rm


func test_all_walls_deletable_no_shared_no_exterior() -> void:
	# Single room, no exterior walls, all walls should be deletable
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room)

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room, room_manager, exterior_walls)

	assert_eq(deletable.size(), room.walls.size(), "All walls should be deletable")


func test_exterior_walls_excluded() -> void:
	# Room with some exterior walls - those should be excluded
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room)

	# Mark top-left corner and top wall as exterior
	var exterior_walls: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0)
	]

	var deletable = _deletion_op.get_deletable_walls(room, room_manager, exterior_walls)

	# 16 walls - 3 exterior = 13 deletable
	assert_eq(deletable.size(), 13, "Should exclude 3 exterior walls")
	assert_does_not_have(deletable, Vector2i(0, 0), "Exterior wall (0,0) should be excluded")
	assert_does_not_have(deletable, Vector2i(1, 0), "Exterior wall (1,0) should be excluded")
	assert_does_not_have(deletable, Vector2i(2, 0), "Exterior wall (2,0) should be excluded")


func test_shared_walls_excluded() -> void:
	# Two adjacent rooms sharing a wall
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(5, 0, 5, 5))  # Adjacent on the right

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	var exterior_walls: Array[Vector2i] = []

	# Room1's right wall tiles: (4, 0), (4, 1), (4, 2), (4, 3), (4, 4)
	# Room2's left wall tiles: (5, 0), (5, 1), (5, 2), (5, 3), (5, 4)
	# These are adjacent but NOT shared (different positions)
	# Actually for walls to be shared, they must be at the same position

	# Let me manually create a shared wall scenario
	# If room2 shares walls with room1, add room1's wall positions to room2
	for i in range(5):
		var shared_pos = Vector2i(4, i)
		if shared_pos in room1.walls:
			room2.walls.append(shared_pos)

	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# 16 walls - 5 shared = 11 deletable
	assert_eq(deletable.size(), 11, "Should exclude 5 shared wall positions")
	assert_does_not_have(deletable, Vector2i(4, 0), "Shared wall (4,0) should be excluded")
	assert_does_not_have(deletable, Vector2i(4, 1), "Shared wall (4,1) should be excluded")


func test_partial_shared_wall() -> void:
	# Two rooms where only part of a wall is shared
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(5, 0, 3, 3))  # Smaller adjacent room

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	# Manually add partial shared wall - only top 3 tiles of room1's right wall
	room2.walls.append(Vector2i(4, 0))
	room2.walls.append(Vector2i(4, 1))
	room2.walls.append(Vector2i(4, 2))

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# Room1 has 16 walls - 3 shared = 13 deletable
	assert_eq(deletable.size(), 13, "Should exclude only 3 shared positions")
	assert_does_not_have(deletable, Vector2i(4, 0), "Shared portion should be excluded")
	assert_does_not_have(deletable, Vector2i(4, 1), "Shared portion should be excluded")
	assert_does_not_have(deletable, Vector2i(4, 2), "Shared portion should be excluded")
	assert_has(deletable, Vector2i(4, 3), "Non-shared portion should be deletable")
	assert_has(deletable, Vector2i(4, 4), "Non-shared portion should be deletable")


func test_mixed_exterior_and_shared() -> void:
	# Room with both exterior walls and shared walls
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(5, 0, 5, 5))

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	# Mark top wall as exterior
	var exterior_walls: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(3, 0),
		Vector2i(4, 0)
	]

	# Add shared wall on right side
	for i in range(5):
		room2.walls.append(Vector2i(4, i))

	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# 16 walls - 5 exterior - 5 shared + 1 overlap (4,0 is both exterior and shared) = 7 deletable
	# Actually: Vector2i(4,0) is in both exterior and shared, so it's excluded once
	# Total exclusions: 5 exterior + 4 unique shared (excluding overlap) = 9
	# 16 - 9 = 7 deletable
	assert_true(deletable.size() == 7, "Should exclude both exterior and shared walls")
	assert_does_not_have(deletable, Vector2i(0, 0), "Exterior corner should be excluded")
	assert_does_not_have(deletable, Vector2i(4, 0), "Corner that's both exterior and shared")
	assert_does_not_have(deletable, Vector2i(4, 3), "Shared but not exterior")


func test_empty_room_returns_empty() -> void:
	# Room with no walls (walls defaults to empty array, no need to assign)
	var room = RoomInstance.new("empty_room", "test_type")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	# walls is already [] by default

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room)

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room, room_manager, exterior_walls)

	assert_eq(deletable.size(), 0, "Empty room should return empty array")


func test_adjacent_rooms_share_wall() -> void:
	# Two rooms sharing a complete wall edge
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(0, 5, 5, 5))  # Below room1

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	# Room1's bottom wall: (0,4), (1,4), (2,4), (3,4), (4,4)
	# Room2's top wall: (0,5), (1,5), (2,5), (3,5), (4,5)
	# These are adjacent but at different positions, so NOT shared

	# For true sharing, manually add room1's bottom wall to room2
	for x in range(5):
		room2.walls.append(Vector2i(x, 4))

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# 16 walls - 5 shared = 11 deletable
	assert_eq(deletable.size(), 11, "Should exclude shared wall edge")
	assert_does_not_have(deletable, Vector2i(2, 4), "Shared wall position should be excluded")


func test_rooms_not_touching() -> void:
	# Two separate rooms, no shared walls
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(10, 10, 5, 5))  # Far away

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# All 16 walls should be deletable
	assert_eq(deletable.size(), 16, "Non-touching rooms should have all walls deletable")


func test_delete_furniture_visuals_calls_cleanup() -> void:
	# Create room with mock furniture placements that track cleanup calls
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# Create mock furniture resource
	var furn1 = FurnitureResource.new()
	furn1.id = "chair"
	furn1.size = Vector2i(1, 1)

	var furn2 = FurnitureResource.new()
	furn2.id = "table"
	furn2.size = Vector2i(2, 2)

	# Add furniture to room
	room.add_furniture(furn1, Vector2i(2, 2), 0)
	room.add_furniture(furn2, Vector2i(1, 1), 0)

	# Create mock visual nodes to track cleanup
	var mock_node1 = Node2D.new()
	var mock_node2 = Node2D.new()

	room.furniture[0].visual_node = mock_node1
	room.furniture[1].visual_node = mock_node2

	# Store references before cleanup (cleanup sets them to null)
	var node1_ref = mock_node1
	var node2_ref = mock_node2

	# Call delete_furniture_visuals
	_deletion_op.delete_furniture_visuals(room)

	# Verify cleanup was called - visual_node should be set to null
	assert_null(room.furniture[0].visual_node, "First furniture visual_node should be null after cleanup")
	assert_null(room.furniture[1].visual_node, "Second furniture visual_node should be null after cleanup")

	# Clean up nodes we created (they should be marked for deletion but we'll free them now for test cleanup)
	if is_instance_valid(node1_ref):
		node1_ref.free()
	if is_instance_valid(node2_ref):
		node2_ref.free()


func test_three_rooms_with_complex_sharing() -> void:
	# Three rooms: room1 shares wall with room2, room2 shares wall with room3
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(5, 0, 5, 5))
	var room3 = _create_room_with_walls(Rect2i(10, 0, 5, 5))

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)
	room_manager.add_room(room3)

	# Room1 shares right wall with room2 (add room1's right wall x=4 to room2)
	for i in range(5):
		room2.walls.append(Vector2i(4, i))

	# Room2 shares right wall with room3 (add room2's right wall x=9 to room3)
	for i in range(5):
		room3.walls.append(Vector2i(9, i))

	var exterior_walls: Array[Vector2i] = []

	# Room1 has 16 walls, 5 at x=4 are shared with room2 -> 11 deletable
	var deletable1 = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)
	assert_eq(deletable1.size(), 11, "Room1 should exclude 5 shared walls")

	# Room2 has 16 original + 5 appended = 21 walls
	# 5 at x=4 shared with room1, 5 at x=9 shared with room3 = 10 shared
	# But wait - room2's x=9 walls are its OWN right wall, not appended
	# room2 original walls include x=9, room3 has appended x=9 walls
	# So room2.walls at x=9 are shared because room3.walls also has x=9
	# 21 total - 10 shared = 11 deletable (not 6)
	var deletable2 = _deletion_op.get_deletable_walls(room2, room_manager, exterior_walls)
	assert_eq(deletable2.size(), 11, "Room2 should exclude 10 shared walls from 21 total")

	# Room3 has 16 original + 5 appended = 21 walls
	# 5 at x=9 are shared with room2 -> 16 deletable
	var deletable3 = _deletion_op.get_deletable_walls(room3, room_manager, exterior_walls)
	assert_eq(deletable3.size(), 16, "Room3 should exclude 5 shared walls from 21 total")


func test_single_shared_tile() -> void:
	# Two rooms sharing only a single corner tile
	var room1 = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var room2 = _create_room_with_walls(Rect2i(5, 5, 5, 5))  # Diagonal adjacent

	var room_manager = _create_mock_room_manager()
	room_manager.add_room(room1)
	room_manager.add_room(room2)

	# Manually share corner (4, 4)
	room2.walls.append(Vector2i(4, 4))

	var exterior_walls: Array[Vector2i] = []
	var deletable = _deletion_op.get_deletable_walls(room1, room_manager, exterior_walls)

	# 16 walls - 1 shared = 15 deletable
	assert_eq(deletable.size(), 15, "Should exclude single shared corner tile")
	assert_does_not_have(deletable, Vector2i(4, 4), "Shared corner should be excluded")
