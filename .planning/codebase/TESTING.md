# Testing Patterns

**Analysis Date:** 2026-01-20

## Test Framework

**Runner:**
- GUT (Godot Unit Testing) v9.x
- Config: `C:\git\TheaterCity\.gutconfig.json`
- Test directories: `res://test/unit/` and `res://test/integration/`

**Assertion Library:**
- GUT built-in assertions: `assert_eq()`, `assert_true()`, `assert_false()`, `assert_not_null()`, `assert_null()`, `assert_has()`, `assert_does_not_have()`, `assert_typeof()`, `assert_signal_emitted()`, etc.
- Custom assertions inherit from `GutTest` base class

**Run Commands:**
```bash
godot --path . -d    # Run GUT tests (debug mode)
# OR open GUT panel in Godot editor (Tools -> GUT menu)
```

**Environment:**
- Tests run in Godot 4.5
- GUT plugin located at `C:\git\TheaterCity\addons\gut\`
- Tests have access to autoloaded singletons: `Targets`, `RoomTypeRegistry`, `FurnitureRegistry`

## Test File Organization

**Location:**
- Separated from source code: Unit tests in `res://test/unit/`, integration tests in `res://test/integration/`
- Not co-located with source files

**Naming:**
- Files start with `test_` prefix: `test_wall_operation.gd`, `test_room_instance.gd`, `test_patron.gd`
- Classes extend `GutTest`: `extends GutTest`
- Test functions start with `test_` prefix: `test_generate_walls_creates_hollow_rectangle()`, `test_can_add_door()`

**Structure:**
```
test/
├── unit/
│   ├── test_collision_operation.gd
│   ├── test_door_operation.gd
│   ├── test_patron.gd
│   ├── test_room_instance.gd
│   ├── test_targets.gd
│   ├── test_validation_operation.gd
│   └── test_wall_operation.gd
└── integration/
    ├── test_patron_spawner_flow.gd
    └── test_room_build_flow.gd
```

## Test Structure

**Suite Organization:**
```gdscript
extends GutTest
## Brief description of what this test file covers

var _operation: OperationClass  # Member variable for reuse


func before_each() -> void:
	# Set up test fixtures - runs before each test function
	_operation = OperationClass.new()


func after_each() -> void:
	# Clean up - runs after each test function
	_operation = null


func test_feature_name() -> void:
	# Arrange - set up test data
	var input = setup_fixture()

	# Act - call the function being tested
	var result = _operation.do_something(input)

	# Assert - verify the result
	assert_eq(result, expected_value, "Descriptive failure message")
```

**Patterns:**

1. **Setup Pattern** (before_each):
   - Create fresh instances: `_operation = WallOperation.new()`
   - Initialize singletons: `RoomTypeRegistry.get_instance()`
   - Helper functions to create test data: `_create_mock_entity()`, `_get_seating_bench()`

2. **Teardown Pattern** (after_each):
   - Set to null: `_operation = null`
   - GUT's `add_child_autofree()` automatically cleans up scene nodes

3. **Assertion Pattern:**
   - Descriptive messages: `assert_eq(walls.size(), 16, "5x5 box should have 16 wall tiles")`
   - Precondition assertions: `assert_not_null(script, "Patron script should load")`
   - Post-condition assertions: `assert_true(room.is_tile_occupied(Vector2i(2, 2)), "Furniture position should be occupied")`

**Example from `test_room_instance.gd` lines 8-52:**
```gdscript
func before_each() -> void:
	# Create a mock furniture resource for testing
	_test_furniture = FurnitureResource.new()
	_test_furniture.id = "test_chair"
	_test_furniture.name = "Test Chair"
	_test_furniture.size = Vector2i(1, 1)
	_test_furniture.cost = 100
	_test_furniture.monthly_upkeep = 10
	_test_furniture.access_offsets = [Vector2i(0, 1)]

func test_can_create_room_instance() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	assert_not_null(room, "RoomInstance should be created")

func test_room_has_correct_initial_values() -> void:
	var room = RoomInstance.new("my_room", "lobby")
	assert_eq(room.id, "my_room", "Room id should match constructor argument")
	assert_eq(room.room_type_id, "lobby", "Room type id should match constructor argument")
```

## Mocking

**Framework:**
- GUT's `double_strategy: "partial"` in `.gutconfig.json` for selective mocking
- Manual mocking by creating test instances: `FurnitureResource.new()`, `Node2D.new()`
- Autofree mechanism: `add_child_autofree()` automatically cleans up nodes added to test

**Patterns:**

1. **Mock Creation:**
```gdscript
func _create_mock_entity() -> Node2D:
	var entity = Node2D.new()
	add_child_autofree(entity)
	return entity
```

2. **Test Resource Creation:**
```gdscript
var _test_furniture = FurnitureResource.new()
_test_furniture.id = "test_chair"
_test_furniture.name = "Test Chair"
_test_furniture.size = Vector2i(1, 1)
```

3. **Load Real Resources:**
```gdscript
func _get_seating_bench() -> FurnitureResource:
	return load("res://data/furniture/seating_bench.tres") as FurnitureResource
```

**What to Mock:**
- External dependencies that have side effects: UI components, filesystem access
- Third-party services (not applicable in this game)
- Complex objects that are hard to instantiate

**What NOT to Mock:**
- Data structures/models: Test with real `RoomInstance`, `FurnitureResource`
- Utility functions: Use real implementations
- Registry singletons: Tests intentionally use real registries to validate data integrity
- Signal connections: Test real signal emission behavior

**Example from `test_targets.gd` lines 22-34:**
```gdscript
func _create_mock_entity() -> Node2D:
	var entity = Node2D.new()
	add_child_autofree(entity)
	return entity

func test_add_entity_stores_entity() -> void:
	var entity = _create_mock_entity()
	_targets.add_entity(entity)
	var result = _targets.get_random_entity()
	assert_eq(result, entity, "Added entity should be retrievable")
```

## Fixtures and Factories

**Test Data:**
```gdscript
# Factory function for common test setup
func _create_test_room(size_x: int, size_y: int) -> RoomInstance:
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, size_x, size_y)
	room.walls = _wall_op.generate_walls(room.bounding_box)
	return room

# Used in multiple tests
func test_valid_room_passes() -> void:
	var room = _create_test_room(5, 5)
	room.add_door(Vector2i(2, 0), 0)
	var bench = _get_seating_bench()
	room.add_furniture(bench, Vector2i(2, 2), 0)
	# ... assertions
```

**Location:**
- Fixtures defined in `before_each()` for reusable setup
- Helper functions in test file (prefixed with underscore): `_create_mock_entity()`, `_get_seating_bench()`, `_create_furniture_resource()`
- Real resources loaded from `.tres` files: `load("res://data/furniture/seating_bench.tres")`

**Pattern from `test_validation_operation.gd` lines 24-34:**
```gdscript
func _create_furniture_resource(id: String, name: String) -> FurnitureResource:
	var furn = FurnitureResource.new()
	furn.id = id
	furn.name = name
	furn.size = Vector2i(1, 1)
	return furn

func _get_seating_bench() -> FurnitureResource:
	# Load the actual seating bench resource that the lobby requires
	return load("res://data/furniture/seating_bench.tres") as FurnitureResource
```

## Coverage

**Requirements:** Not explicitly enforced, but comprehensive coverage observed

**Current Coverage:**
- Unit tests: `test/unit/` - 7 test files covering data models, operations, and utility algorithms
- Integration tests: `test/integration/` - 2 test files covering workflow state transitions
- Key systems tested:
  - `RoomInstance`: 25+ tests covering construction, doors, furniture, occupancy, costs
  - `WallOperation`: 8 tests covering wall generation algorithms
  - `DoorOperation`: 5 tests (in `test_room_build_flow.gd` integration tests)
  - `ValidationOperation`: 8 tests covering validation rules and error messages
  - `Patron`: 9 tests covering direction calculation and navigation logic
  - `Targets`: 10 tests covering entity management and signals
  - `RoomBuildController`: 13 tests covering state transitions and workflows

**View Coverage:**
```bash
# GUT doesn't have built-in coverage reporting
# Coverage assessment done via test file inspection and line coverage analysis
```

## Test Types

**Unit Tests** (`C:\git\TheaterCity\test\unit\`):
- Scope: Individual functions and classes in isolation
- Approach: Test algorithms, data structures, and utility functions without scene dependencies
- Example: `test_wall_operation.gd` tests the `generate_walls()` algorithm with various bounding box inputs
- No scene instantiation; pure function testing with mocked data
- Fast execution (<1 second per test)

**Integration Tests** (`C:\git\TheaterCity\test\integration\`):
- Scope: Component interactions and state machine workflows
- Approach: Test multi-step processes and signal flow between systems
- Example from `test_room_build_flow.gd`: Tests full room building workflow through state transitions
- May instantiate nodes via `add_child_autofree()` but avoid full scene rendering
- Verify signal emissions and parameter passing between components

**E2E Tests:**
- Not implemented
- Manual testing performed in Godot editor for full scene rendering and visual behavior

**Example Unit Test from `test_wall_operation.gd` lines 16-22:**
```gdscript
func test_generate_walls_creates_hollow_rectangle() -> void:
	# 5x5 box should have 16 wall tiles (perimeter only)
	var box = Rect2i(0, 0, 5, 5)
	var walls = _wall_op.generate_walls(box)

	# Perimeter = 4*5 - 4 corners counted twice = 16 tiles
	assert_eq(walls.size(), 16, "5x5 box should have 16 wall tiles")
```

**Example Integration Test from `test_room_build_flow.gd` lines 34-57:**
```gdscript
func test_initial_state_is_idle() -> void:
	assert_eq(_controller.state_name, "idle", "Initial state should be idle")

func test_state_idle_to_select_room_on_start_build() -> void:
	watch_signals(_controller)
	_controller.start_build_mode()
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["select_room"])

func test_state_to_draw_box_on_room_type_selected() -> void:
	_controller.start_build_mode()
	watch_signals(_controller)
	_controller._on_room_type_selected("lobby")
	assert_eq(_controller.state_name, "draw_box", "State should be draw_box after room type selected")
	assert_not_null(_controller.current_room, "Current room should be created")
```

## Common Patterns

**Async Testing:**
- No async operations detected in codebase
- No await patterns; all operations are synchronous
- Signals tested via `watch_signals()` and `assert_signal_emitted()`

**Error/Failure Testing:**
```gdscript
# Test invalid inputs
func test_invalid_door_position_not_added() -> void:
	_controller._on_door_placed(Vector2i(2, 2))  # Interior position
	assert_eq(_controller.current_room.doors.size(), 0, "Invalid door should not be added")

# Test validation failures
func test_room_too_small_fails() -> void:
	var room = RoomInstance.new("test_room", "lobby")
	room.bounding_box = Rect2i(0, 0, 3, 3)  # Too small
	var result = _validation_op.validate_complete(room)
	assert_false(result.is_valid, "Room below min_size should fail")
	assert_true(result.errors.size() > 0, "Should have error messages")
```

**State Testing (State Machine):**
```gdscript
func test_state_draw_box_to_place_doors_on_valid_size() -> void:
	_controller.start_build_mode()
	_controller._on_room_type_selected("lobby")
	watch_signals(_controller)
	_controller.finish_box_draw(Vector2i(0, 0), Vector2i(5, 5))
	assert_eq(_controller.state_name, "place_doors", "State should be place_doors after valid box")
	assert_signal_emitted_with_parameters(_controller, "state_changed", ["place_doors"])

func test_full_build_flow_state_transitions() -> void:
	var states: Array[String] = []
	_controller.state_changed.connect(func(state): states.append(state))
	# Execute flow...
	assert_has(states, "select_room", "Should have select_room state")
	assert_has(states, "draw_box", "Should have draw_box state")
```

**Signal Testing:**
```gdscript
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

func test_placement_changed_emits() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	watch_signals(room)
	room.add_door(Vector2i(5, 0), 0)
	assert_signal_emitted(room, "placement_changed", "add_door should emit placement_changed")
```

**Array and Collection Testing:**
```gdscript
func test_get_all_occupied_tiles() -> void:
	var room = RoomInstance.new("test_id", "test_type")
	room.add_furniture(_test_furniture, Vector2i(2, 2), 0)
	var occupied = room.get_all_occupied_tiles()
	assert_has(occupied, Vector2i(2, 2), "Occupied tiles should include furniture position")
	assert_has(occupied, Vector2i(2, 3), "Occupied tiles should include access tile")

func test_multiple_entities_stored() -> void:
	var entities: Array[Node2D] = []
	for i in range(5):
		var entity = _create_mock_entity()
		entities.append(entity)
		_targets.add_entity(entity)
	var result = _targets.get_random_entity()
	assert_has(entities, result, "Random entity should be one of the added entities")
```

## Notes on Testing Challenges

**Scene Dependencies:**
- Tests that require the full `Patron` scene are challenging because `Patron._ready()` depends on `Targets` autoload
- Workaround: Test patron algorithms separately from scene instantiation (e.g., direction calculation tests)
- Full scene testing documented in comments: See `test_patron.gd` lines 4-8

**Singleton State:**
- `RoomTypeRegistry` and `FurnitureRegistry` are global singletons
- Tests intentionally use real registry data (not mocked) to validate configuration integrity
- Data persists between tests; fixtures designed to avoid state pollution

**UI Testing:**
- UI components are difficult to test in isolation (require full node tree)
- UI testing deferred to manual editor testing
- Integration tests verify signal flow without full UI rendering

---

*Testing analysis: 2026-01-20*
