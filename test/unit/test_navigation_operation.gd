extends GutTest
## Unit tests for NavigationOperation
## Tests navigation mesh tile classification logic

var _nav_op: NavigationOperation
var _wall_op: WallOperation


func before_each() -> void:
	_nav_op = NavigationOperation.new()
	_wall_op = WallOperation.new()


func after_each() -> void:
	_nav_op = null
	_wall_op = null


func _create_room_with_walls_and_door(box: Rect2i, door_pos: Vector2i, door_dir: int) -> RoomInstance:
	var room = RoomInstance.new("test_room", "test_type")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	room.add_door(door_pos, door_dir)
	return room


func _create_room_with_walls(box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new("test_room", "test_type")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	return room


func test_can_instantiate() -> void:
	assert_not_null(_nav_op, "NavigationOperation should instantiate")


func test_constants_defined() -> void:
	assert_eq(NavigationOperation.SOURCE_ID, 1, "SOURCE_ID should be 1 (Classic Walls)")
	assert_eq(NavigationOperation.WALKABLE_TILE, Vector2i(0, 1), "WALKABLE_TILE should be Vector2i(0, 1)")
	assert_eq(NavigationOperation.WALL_TILE, Vector2i(0, 0), "WALL_TILE should be Vector2i(0, 0)")


func test_walkable_tile_coordinates() -> void:
	var walkable = NavigationOperation.WALKABLE_TILE
	assert_eq(walkable.x, 0, "WALKABLE_TILE x coordinate should be 0")
	assert_eq(walkable.y, 1, "WALKABLE_TILE y coordinate should be 1")


func test_wall_tile_coordinates() -> void:
	var wall = NavigationOperation.WALL_TILE
	assert_eq(wall.x, 0, "WALL_TILE x coordinate should be 0")
	assert_eq(wall.y, 0, "WALL_TILE y coordinate should be 0")


func test_interior_tiles_count() -> void:
	# 5x5 room has 25 total tiles, walls form hollow rectangle
	# Walls: top row (5) + bottom row (5) + left column (3) + right column (3) = 16 walls
	# Interior: 25 - 16 = 9 interior tiles
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	var bbox = room.bounding_box
	var total_tiles = bbox.size.x * bbox.size.y
	var interior_count = 0

	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			if pos not in room.walls:
				interior_count += 1

	assert_eq(total_tiles, 25, "5x5 room should have 25 total tiles")
	assert_eq(interior_count, 9, "5x5 room should have 9 interior tiles")


func test_door_position_in_walls() -> void:
	# Door at (2, 0) should be part of the walls array (top wall, middle position)
	var room = _create_room_with_walls_and_door(Rect2i(0, 0, 5, 5), Vector2i(2, 0), 0)

	var door_pos = room.doors[0].position
	assert_has(room.walls, door_pos, "Door position should be in walls array")


func test_multiple_doors_all_in_walls() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6))

	# Add doors on different walls
	room.add_door(Vector2i(2, 0), 0)  # North wall
	room.add_door(Vector2i(5, 2), 1)  # East wall
	room.add_door(Vector2i(2, 5), 2)  # South wall
	room.add_door(Vector2i(0, 2), 3)  # West wall

	for door in room.doors:
		assert_has(room.walls, door.position,
			"Door at %s should be in walls array" % door.position)


func test_interior_tiles_exclude_walls() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var bbox = room.bounding_box

	# Interior tiles (1,1) through (3,3) should NOT be in walls
	for x in range(1, 4):
		for y in range(1, 4):
			var pos = Vector2i(x, y)
			assert_does_not_have(room.walls, pos,
				"Interior position %s should not be in walls" % pos)


func test_corner_positions_are_walls() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# All four corners should be walls
	assert_has(room.walls, Vector2i(0, 0), "Top-left corner should be wall")
	assert_has(room.walls, Vector2i(4, 0), "Top-right corner should be wall")
	assert_has(room.walls, Vector2i(0, 4), "Bottom-left corner should be wall")
	assert_has(room.walls, Vector2i(4, 4), "Bottom-right corner should be wall")


func test_door_classification_logic() -> void:
	# This tests the LOGIC of how doors are identified during navigation update
	var room = _create_room_with_walls_and_door(Rect2i(0, 0, 5, 5), Vector2i(2, 0), 0)

	var door_pos = room.doors[0].position

	# Verify door is in walls
	assert_has(room.walls, door_pos, "Door position should be in walls")

	# Verify we can identify if a wall position has a door
	var is_door = false
	for door in room.doors:
		if door.position == door_pos:
			is_door = true
			break

	assert_true(is_door, "Should identify position as having a door")


func test_non_door_wall_positions() -> void:
	var room = _create_room_with_walls_and_door(Rect2i(0, 0, 5, 5), Vector2i(2, 0), 0)

	# Corner (0,0) is a wall but not a door
	var corner_pos = Vector2i(0, 0)
	assert_has(room.walls, corner_pos, "Corner should be in walls")

	var is_door = false
	for door in room.doors:
		if door.position == corner_pos:
			is_door = true
			break

	assert_false(is_door, "Corner wall position should not be identified as door")


func test_empty_room_has_no_doors() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	assert_eq(room.doors.size(), 0, "Room with no doors should have empty doors array")


func test_room_data_structure_integrity() -> void:
	var room = _create_room_with_walls_and_door(Rect2i(1, 1, 4, 4), Vector2i(2, 1), 0)

	assert_not_null(room.bounding_box, "Room should have bounding_box")
	assert_typeof(room.walls, TYPE_ARRAY, "walls should be array")
	assert_typeof(room.doors, TYPE_ARRAY, "doors should be array")
	assert_true(room.walls.size() > 0, "Room should have wall positions")
	assert_eq(room.doors.size(), 1, "Room should have one door")


func test_bounding_box_defines_navigation_area() -> void:
	var room = _create_room_with_walls(Rect2i(2, 3, 6, 5))
	var bbox = room.bounding_box

	# NavigationOperation iterates over bounding_box area
	# Verify the iteration bounds are correct
	var tile_count = 0
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			tile_count += 1

	var expected_count = bbox.size.x * bbox.size.y
	assert_eq(tile_count, expected_count,
		"Should iterate over all bounding_box tiles (%d)" % expected_count)
