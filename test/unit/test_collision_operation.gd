extends GutTest
## Unit tests for CollisionOperation
## Tests furniture placement collision detection

var _collision_op: CollisionOperation
var _wall_op: WallOperation


func before_each() -> void:
	_collision_op = CollisionOperation.new()
	_wall_op = WallOperation.new()


func after_each() -> void:
	_collision_op = null
	_wall_op = null


func _create_furniture(id: String, size: Vector2i = Vector2i(1, 1),
					  access_offsets: Array[Vector2i] = []) -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = id
	furn.size = size
	furn.access_offsets = access_offsets
	return furn


func _create_room_with_walls(box: Rect2i) -> RoomInstance:
	var room = RoomInstance.new("test_room", "test_type")
	room.bounding_box = box
	room.walls = _wall_op.generate_walls(box)
	return room


func test_valid_placement_in_empty_room() -> void:
	# 5x5 room with walls, interior is 3x3 (positions 1-3, 1-3)
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("chair")

	# Place in interior
	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, room)
	assert_true(result.can_place, "Interior placement should succeed")
	assert_eq(result.blocked_tiles.size(), 0, "Should have no blocked tiles")


func test_placement_blocked_by_wall() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("chair")

	# Place on wall (0,0)
	var result = _collision_op.can_place_furniture(furniture, Vector2i(0, 0), 0, room)
	assert_false(result.can_place, "Wall placement should fail")
	assert_has(result.blocked_tiles, Vector2i(0, 0), "Blocked tiles should include wall position")


func test_placement_blocked_by_existing_furniture() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var existing_furniture = _create_furniture("table")
	var new_furniture = _create_furniture("chair")

	# Add existing furniture at (2, 2)
	room.add_furniture(existing_furniture, Vector2i(2, 2), 0)

	# Try to place new furniture at same position
	var result = _collision_op.can_place_furniture(new_furniture, Vector2i(2, 2), 0, room)
	assert_false(result.can_place, "Overlapping furniture placement should fail")


func test_placement_outside_bounds_fails() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("chair")

	# Place outside room bounds
	var result = _collision_op.can_place_furniture(furniture, Vector2i(100, 100), 0, room)
	assert_false(result.can_place, "Out of bounds placement should fail")


func test_multi_tile_furniture_checks_all_tiles() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6))
	# 2x2 furniture
	var furniture = _create_furniture("large_table", Vector2i(2, 2))

	# Place at interior where all 4 tiles are free
	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, room)
	assert_true(result.can_place, "Multi-tile furniture in valid interior should succeed")


func test_multi_tile_furniture_partial_wall_overlap() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	# 2x2 furniture
	var furniture = _create_furniture("large_table", Vector2i(2, 2))

	# Place at (1, 1) - top-left is interior but edges may hit walls
	# Actually, (1,1), (2,1), (1,2), (2,2) - all should be interior in 5x5
	var result = _collision_op.can_place_furniture(furniture, Vector2i(1, 1), 0, room)
	assert_true(result.can_place, "2x2 furniture at (1,1) in 5x5 room should fit")

	# Now try placing where it overlaps a wall
	# Position (0, 1) would have (0,1), (1,1), (0,2), (1,2)
	# (0,1) and (0,2) are walls in a 5x5 room
	var result2 = _collision_op.can_place_furniture(furniture, Vector2i(0, 1), 0, room)
	assert_false(result2.can_place, "2x2 furniture overlapping wall should fail")


func test_access_tiles_blocked_by_wall() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# Furniture with south access offset
	var access_offsets: Array[Vector2i] = [Vector2i(0, 1)]
	var furniture = _create_furniture("counter", Vector2i(1, 1), access_offsets)

	# Place at (2, 3) - furniture is valid, but access tile at (2, 4) is on wall
	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 3), 0, room)
	assert_false(result.can_place, "Furniture with access tile on wall should fail")
	assert_has(result.blocked_access_tiles, Vector2i(2, 4), "Blocked access tiles should include wall position")


func test_access_tiles_valid_interior() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6))

	# Furniture with south access offset
	var access_offsets: Array[Vector2i] = [Vector2i(0, 1)]
	var furniture = _create_furniture("counter", Vector2i(1, 1), access_offsets)

	# Place at (2, 2) - furniture valid, access tile at (2, 3) is interior
	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, room)
	assert_true(result.can_place, "Furniture with valid access tile should succeed")


func test_access_tiles_blocked_by_other_furniture() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 6, 6))

	# First furniture (no access tiles)
	var blocking_furniture = _create_furniture("chair")
	room.add_furniture(blocking_furniture, Vector2i(2, 3), 0)

	# Second furniture with south access offset
	var access_offsets: Array[Vector2i] = [Vector2i(0, 1)]
	var furniture = _create_furniture("counter", Vector2i(1, 1), access_offsets)

	# Place at (2, 2) - access tile at (2, 3) is blocked by existing furniture
	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, room)
	assert_false(result.can_place, "Furniture with blocked access tile should fail")


func test_preview_returns_valid_and_blocked_tiles() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("large_table", Vector2i(2, 2))

	# Place overlapping wall - position (0, 1) has tiles (0,1), (1,1), (0,2), (1,2)
	var preview = _collision_op.get_placement_preview(furniture, Vector2i(0, 1), 0, room)

	assert_true(preview.tiles.size() == 4, "Preview should have 4 tiles")
	assert_true(preview.blocked_tiles.size() > 0, "Preview should have some blocked tiles")
	assert_true(preview.valid_tiles.size() > 0, "Preview should have some valid tiles")


func test_collision_result_structure() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("chair")

	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, room)

	assert_typeof(result.can_place, TYPE_BOOL, "can_place should be bool")
	assert_typeof(result.blocked_tiles, TYPE_ARRAY, "blocked_tiles should be array")
	assert_typeof(result.blocked_access_tiles, TYPE_ARRAY, "blocked_access_tiles should be array")


func test_preview_result_structure() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
	var furniture = _create_furniture("chair")

	var preview = _collision_op.get_placement_preview(furniture, Vector2i(2, 2), 0, room)

	assert_typeof(preview.tiles, TYPE_ARRAY, "tiles should be array")
	assert_typeof(preview.valid_tiles, TYPE_ARRAY, "valid_tiles should be array")
	assert_typeof(preview.blocked_tiles, TYPE_ARRAY, "blocked_tiles should be array")
	assert_typeof(preview.access_tiles, TYPE_ARRAY, "access_tiles should be array")


func test_null_room_fails() -> void:
	var furniture = _create_furniture("chair")

	var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, null)
	assert_false(result.can_place, "Placement with null room should fail")


func test_null_furniture_uses_single_tile() -> void:
	var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))

	# Null furniture should default to single tile at position
	var result = _collision_op.can_place_furniture(null, Vector2i(2, 2), 0, room)
	assert_true(result.can_place, "Null furniture in valid position should use single tile")
