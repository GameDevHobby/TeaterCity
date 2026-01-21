extends GutTest
## Unit tests for WallOperation
## Tests wall generation from bounding boxes

var _wall_op: WallOperation


func before_each() -> void:
	_wall_op = WallOperation.new()


func after_each() -> void:
	_wall_op = null


func test_generate_walls_creates_hollow_rectangle() -> void:
	# 5x5 box should have 16 wall tiles (perimeter only)
	var box = Rect2i(0, 0, 5, 5)
	var walls = _wall_op.generate_walls(box)

	# Perimeter = 4*5 - 4 corners counted twice = 16 tiles
	assert_eq(walls.size(), 16, "5x5 box should have 16 wall tiles")


func test_generate_walls_includes_all_corners() -> void:
	var box = Rect2i(0, 0, 5, 5)
	var walls = _wall_op.generate_walls(box)

	# Check all 4 corners are present
	assert_has(walls, Vector2i(0, 0), "Top-left corner should be in walls")
	assert_has(walls, Vector2i(4, 0), "Top-right corner should be in walls")
	assert_has(walls, Vector2i(0, 4), "Bottom-left corner should be in walls")
	assert_has(walls, Vector2i(4, 4), "Bottom-right corner should be in walls")


func test_generate_walls_excludes_interior() -> void:
	var box = Rect2i(0, 0, 5, 5)
	var walls = _wall_op.generate_walls(box)

	# Interior tiles should not be in walls
	assert_does_not_have(walls, Vector2i(2, 2), "Interior tile (2,2) should not be in walls")
	assert_does_not_have(walls, Vector2i(3, 3), "Interior tile (3,3) should not be in walls")
	assert_does_not_have(walls, Vector2i(1, 1), "Interior tile (1,1) should not be in walls")
	assert_does_not_have(walls, Vector2i(2, 1), "Interior tile (2,1) should not be in walls")


func test_generate_walls_with_offset_position() -> void:
	# Box at offset position (10, 20)
	var box = Rect2i(10, 20, 5, 5)
	var walls = _wall_op.generate_walls(box)

	# Check corners at offset positions
	assert_has(walls, Vector2i(10, 20), "Top-left corner at offset should be in walls")
	assert_has(walls, Vector2i(14, 20), "Top-right corner at offset should be in walls")
	assert_has(walls, Vector2i(10, 24), "Bottom-left corner at offset should be in walls")
	assert_has(walls, Vector2i(14, 24), "Bottom-right corner at offset should be in walls")

	# Interior at offset should not be in walls
	assert_does_not_have(walls, Vector2i(12, 22), "Interior tile at offset should not be in walls")


func test_generate_walls_minimum_size() -> void:
	# 2x2 box = 4 walls (all tiles are walls since there's no interior)
	var box = Rect2i(0, 0, 2, 2)
	var walls = _wall_op.generate_walls(box)

	assert_eq(walls.size(), 4, "2x2 box should have 4 wall tiles")
	assert_has(walls, Vector2i(0, 0), "2x2 should have (0,0)")
	assert_has(walls, Vector2i(1, 0), "2x2 should have (1,0)")
	assert_has(walls, Vector2i(0, 1), "2x2 should have (0,1)")
	assert_has(walls, Vector2i(1, 1), "2x2 should have (1,1)")


func test_generate_walls_rectangular() -> void:
	# 6x4 box: perimeter = 2*6 + 2*4 - 4 = 16 tiles
	var box = Rect2i(0, 0, 6, 4)
	var walls = _wall_op.generate_walls(box)

	assert_eq(walls.size(), 16, "6x4 box should have 16 wall tiles")

	# Verify top and bottom rows
	for x in range(6):
		assert_has(walls, Vector2i(x, 0), "Top row should have (%d, 0)" % x)
		assert_has(walls, Vector2i(x, 3), "Bottom row should have (%d, 3)" % x)

	# Verify left and right columns (excluding corners already counted)
	for y in range(1, 3):
		assert_has(walls, Vector2i(0, y), "Left column should have (0, %d)" % y)
		assert_has(walls, Vector2i(5, y), "Right column should have (5, %d)" % y)


func test_generate_walls_3x3_has_8_walls() -> void:
	# 3x3 box has only 1 interior tile, so 8 wall tiles
	var box = Rect2i(0, 0, 3, 3)
	var walls = _wall_op.generate_walls(box)

	assert_eq(walls.size(), 8, "3x3 box should have 8 wall tiles")
	assert_does_not_have(walls, Vector2i(1, 1), "Center tile (1,1) should not be a wall")
