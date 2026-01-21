extends GutTest
## Unit tests for RoomInstance
## Tests room data model, door/furniture management, and cost calculations

var _test_furniture: FurnitureResource


func before_each() -> void:
	# Create a mock furniture resource for testing
	_test_furniture = FurnitureResource.new()
	_test_furniture.id = "test_chair"
	_test_furniture.name = "Test Chair"
	_test_furniture.size = Vector2i(1, 1)
	_test_furniture.cost = 100
	_test_furniture.monthly_upkeep = 10
	_test_furniture.access_offsets = [Vector2i(0, 1)]  # South access


func after_each() -> void:
	_test_furniture = null


func test_can_create_room_instance() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	assert_not_null(room, "RoomInstance should be created")


func test_room_has_correct_initial_values() -> void:
	var room = RoomInstance.new("my_room", "lobby")
	assert_eq(room.id, "my_room", "Room id should match constructor argument")
	assert_eq(room.room_type_id, "lobby", "Room type id should match constructor argument")


func test_can_set_bounding_box() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.bounding_box = Rect2i(0, 0, 10, 10)
	assert_eq(room.bounding_box, Rect2i(0, 0, 10, 10), "Bounding box should be set")


func test_can_add_door() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_door(Vector2i(5, 0), 0)  # position, direction (North)
	assert_eq(room.doors.size(), 1, "Room should have one door")
	assert_eq(room.doors[0].position, Vector2i(5, 0), "Door position should match")
	assert_eq(room.doors[0].direction, 0, "Door direction should match")


func test_can_add_furniture() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(null, Vector2i(2, 2), 0)  # furniture_resource, position, rotation
	assert_eq(room.furniture.size(), 1, "Room should have one furniture")
	assert_eq(room.furniture[0].position, Vector2i(2, 2), "Furniture position should match")


# ============================================================================
# Additional tests for furniture counting
# ============================================================================

func test_get_furniture_count_by_resource() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)
	room.add_furniture(_test_furniture, Vector2i(3, 3), 0)

	var count = room.get_furniture_count_by_resource(_test_furniture)
	assert_eq(count, 2, "Should count 2 furniture items with same resource")


func test_get_furniture_count_by_resource_different_furniture() -> void:
	var other_furniture = FurnitureResource.new()
	other_furniture.id = "other_item"

	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)
	room.add_furniture(other_furniture, Vector2i(3, 3), 0)

	var count = room.get_furniture_count_by_resource(_test_furniture)
	assert_eq(count, 1, "Should only count matching furniture resource")


func test_get_furniture_count_by_id() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)
	room.add_furniture(_test_furniture, Vector2i(3, 3), 0)

	var count = room.get_furniture_count("test_chair")
	assert_eq(count, 2, "Should count 2 furniture items by ID")


func test_get_furniture_count_by_id_no_match() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	var count = room.get_furniture_count("nonexistent")
	assert_eq(count, 0, "Should return 0 for non-matching ID")


# ============================================================================
# Tile occupation tests
# ============================================================================

func test_tile_occupied_by_furniture_footprint() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	assert_true(room.is_tile_occupied(Vector2i(2, 2)), "Furniture position should be occupied")


func test_tile_occupied_by_access_tiles() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	# Furniture at (2,2) with access_offset (0,1) means access tile at (2,3)
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	assert_true(room.is_tile_occupied(Vector2i(2, 3)), "Access tile should be occupied")


func test_tile_not_occupied_when_empty() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	assert_false(room.is_tile_occupied(Vector2i(5, 5)), "Non-furniture tile should not be occupied")


func test_get_all_occupied_tiles() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	var occupied = room.get_all_occupied_tiles()
	assert_has(occupied, Vector2i(2, 2), "Occupied tiles should include furniture position")
	assert_has(occupied, Vector2i(2, 3), "Occupied tiles should include access tile")


# ============================================================================
# Cost calculation tests
# ============================================================================

func test_get_total_cost_furniture_only() -> void:
	var room = RoomInstance.new("test_id", "nonexistent_type")  # No room type = no base cost
	room.bounding_box = Rect2i(0, 0, 5, 5)
	# walls starts as empty typed array by default

	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	# Cost = base (0, no valid room type) + walls (0) + doors (0) + furniture (100)
	# Note: If room type doesn't exist, base_cost won't be added
	var cost = room.get_total_cost()
	assert_eq(cost, 100, "Total cost should include furniture cost")


func test_get_total_cost_with_walls() -> void:
	var room = RoomInstance.new("test_id", "nonexistent_type")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	# Each wall costs 10 - use proper typed array
	var wall_array: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	room.walls = wall_array  # 3 walls

	# Cost = walls (3 * 10 = 30)
	var cost = room.get_total_cost()
	assert_eq(cost, 30, "Total cost should include wall costs")


func test_get_total_cost_with_doors() -> void:
	var room = RoomInstance.new("test_id", "nonexistent_type")
	room.bounding_box = Rect2i(0, 0, 5, 5)
	# Each door costs 50
	room.add_door(Vector2i(2, 0), 0)
	room.add_door(Vector2i(2, 4), 2)

	# Cost = doors (2 * 50 = 100)
	var cost = room.get_total_cost()
	assert_eq(cost, 100, "Total cost should include door costs")


func test_get_monthly_upkeep() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)  # 10 upkeep
	room.add_furniture(_test_furniture, Vector2i(3, 3), 0)  # 10 upkeep

	var upkeep = room.get_monthly_upkeep()
	assert_eq(upkeep, 20, "Monthly upkeep should sum furniture upkeep")


func test_get_monthly_upkeep_empty_room() -> void:
	var room = RoomInstance.new("test_id", "test_type")

	var upkeep = room.get_monthly_upkeep()
	assert_eq(upkeep, 0, "Empty room should have 0 upkeep")


# ============================================================================
# Signal tests
# ============================================================================

func test_add_door_emits_placement_changed() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	watch_signals(room)

	room.add_door(Vector2i(5, 0), 0)

	assert_signal_emitted(room, "placement_changed", "add_door should emit placement_changed")


func test_add_furniture_emits_placement_changed() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	watch_signals(room)

	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)

	assert_signal_emitted(room, "placement_changed", "add_furniture should emit placement_changed")


# ============================================================================
# Multi-tile furniture tests
# ============================================================================

func test_multi_tile_furniture_occupied_tiles() -> void:
	var large_furniture = FurnitureResource.new()
	large_furniture.id = "large_table"
	large_furniture.size = Vector2i(2, 2)
	large_furniture.cost = 200

	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(large_furniture, Vector2i(2, 2), 0)

	# 2x2 furniture at (2,2) should occupy (2,2), (3,2), (2,3), (3,3)
	assert_true(room.is_tile_occupied(Vector2i(2, 2)), "Top-left of 2x2 should be occupied")
	assert_true(room.is_tile_occupied(Vector2i(3, 2)), "Top-right of 2x2 should be occupied")
	assert_true(room.is_tile_occupied(Vector2i(2, 3)), "Bottom-left of 2x2 should be occupied")
	assert_true(room.is_tile_occupied(Vector2i(3, 3)), "Bottom-right of 2x2 should be occupied")
