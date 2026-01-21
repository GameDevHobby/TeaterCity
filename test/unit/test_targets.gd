extends GutTest
## Unit tests for Targets singleton
## Tests entity management and signal emission
##
## Note: We test against a local instance of the Targets script since the autoload
## may have state from other tests. The script extends Node, so we instantiate it directly.

var _targets: Node


func before_each() -> void:
	# Load and instantiate the Targets script directly for isolated testing
	var TargetsScript = load("res://scripts/Targets.gd")
	_targets = TargetsScript.new()
	add_child_autofree(_targets)


func after_each() -> void:
	pass


func _create_mock_entity() -> Node2D:
	var entity = Node2D.new()
	add_child_autofree(entity)
	return entity


func test_add_entity_stores_entity() -> void:
	var entity = _create_mock_entity()

	_targets.add_entity(entity)

	var result = _targets.get_random_entity()
	assert_eq(result, entity, "Added entity should be retrievable via get_random_entity")


func test_add_entity_emits_signal() -> void:
	var entity = _create_mock_entity()

	watch_signals(_targets)
	_targets.add_entity(entity)

	assert_signal_emitted(_targets, "entity_added", "entity_added signal should be emitted")


func test_add_entity_signal_includes_entity() -> void:
	var entity = _create_mock_entity()

	watch_signals(_targets)
	_targets.add_entity(entity)

	var params = get_signal_parameters(_targets, "entity_added")
	assert_eq(params[0], entity, "Signal should include the added entity")


func test_add_entity_prevents_duplicates() -> void:
	var entity = _create_mock_entity()

	watch_signals(_targets)
	_targets.add_entity(entity)
	_targets.add_entity(entity)  # Add same entity again

	# Should only emit signal once (duplicate prevention)
	assert_signal_emit_count(_targets, "entity_added", 1, "Signal should only emit once for duplicates")


func test_get_random_entity_returns_null_when_empty() -> void:
	var result = _targets.get_random_entity()
	assert_null(result, "get_random_entity should return null when empty")


func test_get_random_entity_returns_entity() -> void:
	var entity1 = _create_mock_entity()
	var entity2 = _create_mock_entity()

	_targets.add_entity(entity1)
	_targets.add_entity(entity2)

	var result = _targets.get_random_entity()
	assert_true(result == entity1 or result == entity2, "get_random_entity should return one of the added entities")


func test_get_random_entity_with_single_entity() -> void:
	var entity = _create_mock_entity()
	_targets.add_entity(entity)

	# Call multiple times to ensure it always returns the single entity
	for i in range(5):
		var result = _targets.get_random_entity()
		assert_eq(result, entity, "With single entity, get_random_entity should always return it")


func test_notify_navigation_changed_emits_signal() -> void:
	watch_signals(_targets)
	_targets.notify_navigation_changed()

	assert_signal_emitted(_targets, "navigation_changed", "navigation_changed signal should be emitted")


func test_multiple_entities_stored() -> void:
	var entities: Array[Node2D] = []
	for i in range(5):
		var entity = _create_mock_entity()
		entities.append(entity)
		_targets.add_entity(entity)

	# Verify random entity is one of the added entities
	var result = _targets.get_random_entity()
	assert_has(entities, result, "Random entity should be one of the added entities")
