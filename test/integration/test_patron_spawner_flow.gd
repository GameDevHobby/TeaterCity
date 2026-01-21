extends GutTest
## Integration tests for Spawner
## Tests Spawner configuration and basic behavior
##
## Note: Full patron spawning tests that involve the Targets autoload are limited
## because the global Targets singleton retains references to mock entities that
## get freed between tests. These tests focus on what can be verified in isolation.

const PATRON_SCENE_PATH = "res://objects/patron/patron.tscn"

var _spawner: Spawner
var _patron_scene: PackedScene


func before_each() -> void:
	_patron_scene = load(PATRON_SCENE_PATH)
	_spawner = Spawner.new()
	add_child_autofree(_spawner)


func after_each() -> void:
	_spawner = null


func test_spawner_exists() -> void:
	assert_not_null(_spawner, "Spawner should be created")


func test_spawner_extends_marker2d() -> void:
	assert_true(_spawner is Marker2D, "Spawner should extend Marker2D")


func test_spawner_can_set_patron_scene() -> void:
	_spawner.patron_scene = _patron_scene
	assert_eq(_spawner.patron_scene, _patron_scene, "Spawner should hold patron scene reference")


func test_spawner_has_timer_timeout_method() -> void:
	# Verify the spawner has the expected method
	assert_true(_spawner.has_method("_on_timer_timeout"), "Spawner should have _on_timer_timeout method")


func test_spawner_position_can_be_set() -> void:
	_spawner.global_position = Vector2(500, 300)
	assert_eq(_spawner.global_position, Vector2(500, 300), "Spawner position should be settable")


func test_patron_scene_is_loadable() -> void:
	assert_not_null(_patron_scene, "Patron scene should be loadable")
	assert_true(_patron_scene is PackedScene, "Patron scene should be a PackedScene")


func test_spawner_has_expected_properties() -> void:
	# Verify the spawner has expected properties by checking a real instance
	# (Avoids reloading the script which causes class name conflicts)
	assert_true("patron_scene" in _spawner, "Spawner should have patron_scene property")


func test_targets_autoload_exists() -> void:
	# Verify the Targets autoload is available (needed for patron spawning)
	assert_not_null(Targets, "Targets autoload should exist")


func test_targets_has_expected_methods() -> void:
	assert_true(Targets.has_method("add_entity"), "Targets should have add_entity method")
	assert_true(Targets.has_method("get_random_entity"), "Targets should have get_random_entity method")
	assert_true(Targets.has_method("notify_navigation_changed"), "Targets should have notify_navigation_changed method")


func test_targets_has_expected_signals() -> void:
	assert_true(Targets.has_signal("entity_added"), "Targets should have entity_added signal")
	assert_true(Targets.has_signal("navigation_changed"), "Targets should have navigation_changed signal")
