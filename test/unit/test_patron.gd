extends GutTest
## Unit tests for Patron logic
## Tests patron-related algorithms and calculations that can be tested without
## instantiating the full Patron scene.
##
## Note: The Patron scene relies on the global Targets autoload during _ready(),
## which makes isolated unit testing challenging. Tests that require scene
## instantiation with full navigation are in test/integration/test_patron_spawner_flow.gd


func test_direction_index_from_angle_right() -> void:
	# Test 8-way direction calculation - Right (0)
	var dir = Vector2(1, 0)
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 0, "Right direction should map to index 0")


func test_direction_index_from_angle_down_right() -> void:
	# Test 8-way direction calculation - Down-Right (1)
	var dir = Vector2(1, 1).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 1, "Down-Right direction should map to index 1")


func test_direction_index_from_angle_down() -> void:
	# Test 8-way direction calculation - Down (2)
	var dir = Vector2(0, 1)
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 2, "Down direction should map to index 2")


func test_direction_index_from_angle_down_left() -> void:
	# Test 8-way direction calculation - Down-Left (3)
	var dir = Vector2(-1, 1).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 3, "Down-Left direction should map to index 3")


func test_direction_index_from_angle_left() -> void:
	# Test 8-way direction calculation - Left (4)
	var dir = Vector2(-1, 0)
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 4, "Left direction should map to index 4")


func test_direction_index_from_angle_up_left() -> void:
	# Test 8-way direction calculation - Up-Left (5)
	var dir = Vector2(-1, -1).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 5, "Up-Left direction should map to index 5")


func test_direction_index_from_angle_up() -> void:
	# Test 8-way direction calculation - Up (6)
	var dir = Vector2(0, -1)
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 6, "Up direction should map to index 6")


func test_direction_index_from_angle_up_right() -> void:
	# Test 8-way direction calculation - Up-Right (7)
	var dir = Vector2(1, -1).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)
	assert_eq(idx, 7, "Up-Right direction should map to index 7")


func test_all_8_directions_are_unique() -> void:
	# Verify all 8 directions produce unique indices
	var directions = [
		Vector2(1, 0),          # Right
		Vector2(1, 1).normalized(),   # Down-Right
		Vector2(0, 1),          # Down
		Vector2(-1, 1).normalized(),  # Down-Left
		Vector2(-1, 0),         # Left
		Vector2(-1, -1).normalized(), # Up-Left
		Vector2(0, -1),         # Up
		Vector2(1, -1).normalized(),  # Up-Right
	]

	var indices: Array[int] = []
	for dir in directions:
		var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
		var idx = wrapi(int(angle), 0, 8)
		indices.append(idx)

	# Check all indices are unique and cover 0-7
	var unique_indices = {}
	for idx in indices:
		unique_indices[idx] = true

	assert_eq(unique_indices.size(), 8, "Should have 8 unique direction indices")

	for i in range(8):
		assert_true(unique_indices.has(i), "Index %d should be present" % i)


func test_patron_scene_exists() -> void:
	# Verify the patron scene file can be loaded
	var scene = load("res://objects/patron/patron.tscn")
	assert_not_null(scene, "Patron scene should be loadable")


func test_patron_scene_is_packed_scene() -> void:
	var scene = load("res://objects/patron/patron.tscn")
	assert_true(scene is PackedScene, "Patron scene should be a PackedScene")


func test_patron_class_has_expected_exports() -> void:
	# Test that Patron class has expected exported properties by checking script
	var script = load("res://scripts/Patron.gd") as GDScript
	assert_not_null(script, "Patron script should load")

	# Check script exists and has expected class_name
	var source = script.source_code
	assert_true("class_name Patron" in source, "Script should define Patron class")
	assert_true("@export var movement_speed" in source, "Should export movement_speed")
	assert_true("@export var nav_agent" in source, "Should export nav_agent")
	assert_true("@export var animated_sprite" in source, "Should export animated_sprite")


func test_patron_nav_count_logic() -> void:
	# Test the navigation count logic conceptually
	# Patron should despawn after 10 navigation finishes

	# Simulate the logic from _navigation_finished:
	# _nav_count += 1
	# if _nav_count < 10: choose_random_target() else: queue_free()

	for initial in range(15):
		var nav_count = initial
		nav_count += 1  # Simulate increment
		var should_despawn = nav_count >= 10

		if initial < 9:
			assert_false(should_despawn, "Nav count %d should not trigger despawn" % initial)
		else:
			assert_true(should_despawn, "Nav count %d should trigger despawn" % initial)
