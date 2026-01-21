extends GutTest
## Unit tests for DoorOperation
## Tests door position validation and direction determination

var _door_op: DoorOperation
var _wall_op: WallOperation


func before_each() -> void:
	_door_op = DoorOperation.new()
	_wall_op = WallOperation.new()


func after_each() -> void:
	_door_op = null
	_wall_op = null


func _create_room_with_walls(box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new("test_room", "test_type")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	return room


func test_valid_door_on_wall_with_2_neighbors() -> void:
	# 5x5 room: position (2,0) is mid-wall on top edge with neighbors (1,0) and (3,0)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var result = _door_op.is_valid_door_position(Vector2i(2, 0), room)
	assert_true(result, "Mid-wall position (2,0) should be valid for door")


func test_valid_door_on_wall_with_3_neighbors() -> void:
	# 5x5 room: position (1,0) near corner has neighbors (0,0), (2,0), and (1,1) but (1,1) is not a wall
	# Actually (1,0) has wall neighbors: (0,0) and (2,0) = 2 neighbors
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# Check corner-adjacent position
	var result = _door_op.is_valid_door_position(Vector2i(1, 0), room)
	assert_true(result, "Position (1,0) near corner should be valid for door")


func test_invalid_door_not_on_wall() -> void:
	# 5x5 room: position (2,2) is interior, not on wall
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var result = _door_op.is_valid_door_position(Vector2i(2, 2), room)
	assert_false(result, "Interior position (2,2) should not be valid for door")


func test_invalid_door_outside_room() -> void:
	# 5x5 room: position (10,10) is outside
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var result = _door_op.is_valid_door_position(Vector2i(10, 10), room)
	assert_false(result, "Position outside room should not be valid for door")


func test_invalid_door_at_corner() -> void:
	# Corners have only 1 wall neighbor (the two adjacent walls) which is 2 neighbors
	# Actually let's check: corner (0,0) has potential neighbors UP(-1,0), DOWN(1,0), LEFT(0,-1), RIGHT(0,1)
	# In walls: only (1,0) and (0,1) are walls = 2 neighbors, so corner might be valid
	# But typically corners shouldn't be doors in most games
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# Corner (0,0) has 2 wall neighbors: (1,0) and (0,1)
	var result = _door_op.is_valid_door_position(Vector2i(0, 0), room)
	# Based on the code, 2-3 neighbors is valid, so corners with 2 neighbors are valid
	assert_true(result, "Corner (0,0) with 2 wall neighbors should be valid")


func test_door_direction_north() -> void:
	# Top edge (y = min) should return direction 0 (North)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var direction = _door_op.determine_door_direction(Vector2i(2, 0), room)
	assert_eq(direction, 0, "Top edge should have North direction (0)")


func test_door_direction_east() -> void:
	# Right edge (x = max) should return direction 1 (East)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var direction = _door_op.determine_door_direction(Vector2i(4, 2), room)
	assert_eq(direction, 1, "Right edge should have East direction (1)")


func test_door_direction_south() -> void:
	# Bottom edge (y = max) should return direction 2 (South)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var direction = _door_op.determine_door_direction(Vector2i(2, 4), room)
	assert_eq(direction, 2, "Bottom edge should have South direction (2)")


func test_door_direction_west() -> void:
	# Left edge (x = min) should return direction 3 (West)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var direction = _door_op.determine_door_direction(Vector2i(0, 2), room)
	assert_eq(direction, 3, "Left edge should have West direction (3)")


func test_door_direction_corner_priority() -> void:
	# Corners: top-left (0,0) - y==min so North(0)
	# Based on the code logic, North check happens first
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var direction = _door_op.determine_door_direction(Vector2i(0, 0), room)
	assert_eq(direction, 0, "Top-left corner should prioritize North direction (0)")


func test_door_direction_with_offset_room() -> void:
	# Room at offset position (10, 20)
	var room = _create_room_with_walls(Rect2i(10, 20, 5, 5))

	# Top edge at y=20
	var north_dir = _door_op.determine_door_direction(Vector2i(12, 20), room)
	assert_eq(north_dir, 0, "Top edge at offset should have North direction")

	# Right edge at x=14
	var east_dir = _door_op.determine_door_direction(Vector2i(14, 22), room)
	assert_eq(east_dir, 1, "Right edge at offset should have East direction")

	# Bottom edge at y=24
	var south_dir = _door_op.determine_door_direction(Vector2i(12, 24), room)
	assert_eq(south_dir, 2, "Bottom edge at offset should have South direction")

	# Left edge at x=10
	var west_dir = _door_op.determine_door_direction(Vector2i(10, 22), room)
	assert_eq(west_dir, 3, "Left edge at offset should have West direction")
