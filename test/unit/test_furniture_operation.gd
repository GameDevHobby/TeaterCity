extends GutTest
## Unit tests for FurnitureOperation
## Tests furniture visual creation, naming, and positioning logic

var _furn_op: FurnitureOperation
var _parent_node: Node2D


func before_each() -> void:
	_furn_op = FurnitureOperation.new()
	_parent_node = Node2D.new()
	add_child_autofree(_parent_node)


func after_each() -> void:
	_furn_op = null
	# _parent_node cleaned up by autofree


func _create_furniture(id: String, size: Vector2i = Vector2i(1, 1)) -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = id
	furn.size = size
	return furn


func _create_placement(furn: FurnitureResource, pos: Vector2i, rot: int) -> RoomInstance.FurniturePlacement:
	return RoomInstance.FurniturePlacement.new(furn, pos, rot)


func test_can_instantiate() -> void:
	assert_not_null(_furn_op, "FurnitureOperation should instantiate")


func test_create_visual_returns_node() -> void:
	var furn = _create_furniture("chair")
	var placement = _create_placement(furn, Vector2i(2, 2), 0)

	var result = _furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_not_null(result, "create_furniture_visual should return a Node2D")
	assert_true(result is Node2D, "Result should be Node2D instance")


func test_create_visual_adds_to_parent() -> void:
	var furn = _create_furniture("table")
	var placement = _create_placement(furn, Vector2i(3, 3), 0)

	var initial_child_count = _parent_node.get_child_count()
	_furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_eq(_parent_node.get_child_count(), initial_child_count + 1, "Visual should be added as child of parent_node")


func test_visual_name_format() -> void:
	var furn = _create_furniture("bench")
	var placement = _create_placement(furn, Vector2i(5, 7), 0)

	var visual = _furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_eq(visual.name, "Furniture_bench_5_7", "Name should follow Furniture_{id}_{x}_{y} pattern")


func test_visual_name_with_different_positions() -> void:
	var furn1 = _create_furniture("chair")
	var placement1 = _create_placement(furn1, Vector2i(1, 1), 0)

	var furn2 = _create_furniture("chair")
	var placement2 = _create_placement(furn2, Vector2i(9, 3), 0)

	var visual1 = _furn_op.create_furniture_visual(placement1, _parent_node, null)
	var visual2 = _furn_op.create_furniture_visual(placement2, _parent_node, null)

	assert_eq(visual1.name, "Furniture_chair_1_1", "First chair name should include position (1,1)")
	assert_eq(visual2.name, "Furniture_chair_9_3", "Second chair name should include position (9,3)")
	assert_ne(visual1.name, visual2.name, "Names should differ based on position")


func test_placement_visual_node_set() -> void:
	var furn = _create_furniture("counter")
	var placement = _create_placement(furn, Vector2i(4, 4), 0)

	assert_null(placement.visual_node, "visual_node should be null before creation")

	var visual = _furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_not_null(placement.visual_node, "visual_node should be set after creation")
	assert_eq(placement.visual_node, visual, "visual_node should reference created visual")


func test_no_scene_creates_placeholder() -> void:
	var furn = _create_furniture("no_scene_item")
	# Don't set furn.scene, leaving it null
	var placement = _create_placement(furn, Vector2i(2, 2), 0)

	var visual = _furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_not_null(visual, "Should create placeholder node when scene is null")
	assert_true(visual is Node2D, "Placeholder should be Node2D")
	assert_eq(visual.name, "Furniture_no_scene_item_2_2", "Placeholder should have correct name")


func test_null_furniture_in_placement() -> void:
	var placement = RoomInstance.FurniturePlacement.new(null, Vector2i(3, 3), 0)

	var visual = _furn_op.create_furniture_visual(placement, _parent_node, null)

	assert_not_null(visual, "Should create visual even with null furniture")
	assert_eq(visual.name, "Furniture_unknown_3_3", "Null furniture should use 'unknown' as id")


func test_visual_position_calculated() -> void:
	var furn = _create_furniture("table", Vector2i(2, 2))
	var placement = _create_placement(furn, Vector2i(5, 5), 0)

	var visual = _furn_op.create_furniture_visual(placement, _parent_node, null)

	# Visual should have a world position calculated from tile position
	assert_not_null(visual.position, "Visual should have position set")
	# Don't test exact position values (depends on IsometricMath implementation)
	# Just verify position is non-zero for non-origin tiles
	assert_ne(visual.position, Vector2.ZERO, "Visual at (5,5) should not be at world origin")


func test_multiple_furniture_visuals_independent() -> void:
	var furn1 = _create_furniture("chair")
	var placement1 = _create_placement(furn1, Vector2i(1, 1), 0)

	var furn2 = _create_furniture("table")
	var placement2 = _create_placement(furn2, Vector2i(2, 2), 0)

	var visual1 = _furn_op.create_furniture_visual(placement1, _parent_node, null)
	var visual2 = _furn_op.create_furniture_visual(placement2, _parent_node, null)

	assert_ne(visual1, visual2, "Different visuals should be distinct instances")
	assert_eq(_parent_node.get_child_count(), 2, "Both visuals should be added to parent")


func test_furniture_with_rotation() -> void:
	var furn = _create_furniture("counter", Vector2i(2, 1))
	# Use different positions to avoid duplicate name issues
	var placement_rot0 = _create_placement(furn, Vector2i(3, 3), 0)
	var placement_rot1 = _create_placement(furn, Vector2i(5, 5), 1)

	var visual_rot0 = _furn_op.create_furniture_visual(placement_rot0, _parent_node, null)
	var visual_rot1 = _furn_op.create_furniture_visual(placement_rot1, _parent_node, null)

	# Position should differ based on rotation (RotationHelper.get_center_offset affects position)
	assert_not_null(visual_rot0.position, "Rotation 0 visual should have position")
	assert_not_null(visual_rot1.position, "Rotation 1 visual should have position")
	# Names should follow the format with their respective positions
	assert_eq(visual_rot0.name, "Furniture_counter_3_3", "Rotation 0 name")
	assert_eq(visual_rot1.name, "Furniture_counter_5_5", "Rotation 1 name")
