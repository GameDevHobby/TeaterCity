# Phase 10: Testing & Verification - Research

**Researched:** 2025-02-07
**Domain:** Unit and integration testing for Godot 4 game systems using GUT framework
**Confidence:** HIGH

## Summary

Phase 10 focuses on comprehensive test coverage for room editor features using GUT (Godot Unit Testing) framework 9.x, which is already integrated into the project. The research confirms that GUT provides all necessary capabilities for testing the remaining Operations (FurnitureOperation, DeletionOperation, ResizeOperation, NavigationOperation) and RoomSerializer persistence layer.

The project follows established testing patterns with clear separation between unit tests (`test/unit/`) and integration tests (`test/integration/`). GUT 9.5.1 for Godot 4.5+ provides extensive assertion methods, partial doubles for mocking, signal watchers, and memory management utilities that align perfectly with the existing test architecture.

**Primary recommendation:** Follow the existing test patterns in the codebase (before_each/after_each setup, helper methods for common data, operation instantiation per test). Use partial doubles with stubbing for FileAccess operations in RoomSerializer tests to avoid actual file I/O. Structure integration tests to simulate complete edit workflows using the established controller pattern.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| GUT | 9.5.1 | Unit/integration testing framework | Official testing framework for Godot 4.5+, already integrated in project with .gutconfig.json |
| Godot Engine | 4.5 | Runtime environment | Tests run in-engine with full GDScript support |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| GUT CLI | 9.5.1 | Command-line test runner | CI/CD integration, headless testing |
| GitHub Actions | N/A | Continuous integration | Automated test runs on push/PR (optional for this phase) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| GUT | gdUnit4 | gdUnit4 offers more advanced mocking but requires addon replacement; GUT already integrated and sufficient |
| GUT | Custom test runner | No benefits; GUT provides all needed features with official support |

**Installation:**
```bash
# Already installed via Godot Asset Library
# Configuration exists at .gutconfig.json
# No additional installation needed
```

## Architecture Patterns

### Recommended Project Structure
```
test/
├── unit/                           # Unit tests for Operations and data models
│   ├── test_furniture_operation.gd
│   ├── test_deletion_operation.gd
│   ├── test_resize_operation.gd
│   ├── test_navigation_operation.gd
│   ├── test_room_serializer.gd
│   └── test_room_serializer_edge_cases.gd
└── integration/                    # Integration tests for workflows
    ├── test_furniture_edit_flow.gd
    ├── test_room_deletion_flow.gd
    └── test_persistence_flow.gd
```

### Pattern 1: Unit Test Structure (Operation Testing)
**What:** Stateless operation testing with before_each/after_each lifecycle
**When to use:** Testing individual Operation classes (generate, validate, execute methods)
**Example:**
```gdscript
// Source: Existing codebase test_wall_operation.gd
extends GutTest

var _operation: SomeOperation

func before_each() -> void:
    _operation = SomeOperation.new()

func after_each() -> void:
    _operation = null

func test_operation_with_valid_input() -> void:
    var result = _operation.do_something(valid_params)
    assert_eq(result, expected_value, "Error message")
    assert_true(result.is_valid, "Operation should succeed")
```

### Pattern 2: Test Data Helpers
**What:** Helper methods to create commonly used test objects (rooms, furniture, resources)
**When to use:** When multiple tests need similar setup data
**Example:**
```gdscript
// Source: Existing codebase test_collision_operation.gd
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
    room.walls = WallOperation.new().generate_walls(box)
    return room
```

### Pattern 3: Integration Test with Controllers
**What:** Testing full workflows by creating controller instances with add_child_autofree
**When to use:** Testing state transitions and signal flows between components
**Example:**
```gdscript
// Source: Existing codebase test_room_build_flow.gd
var _controller: RoomBuildController

func before_each() -> void:
    _controller = RoomBuildController.new()
    _controller.name = "TestRoomBuildController"
    add_child_autofree(_controller)  # Auto-cleanup after test

    # Initialize singletons if needed
    RoomTypeRegistry.get_instance()

func test_state_transition() -> void:
    watch_signals(_controller)
    _controller.some_action()
    assert_signal_emitted_with_parameters(_controller, "state_changed", ["new_state"])
```

### Pattern 4: Mocking File System Operations
**What:** Using partial doubles with stub to mock FileAccess for save/load tests
**When to use:** Testing RoomSerializer without actual file I/O
**Example:**
```gdscript
// Source: https://ziumper.github.io/blog/2025/testing-error-handling-in-gdscript/
func test_serializer_handles_file_error() -> void:
    # Create wrapper method that can be stubbed
    var serializer = partial_double(RoomSerializer).new()
    stub(serializer, "_file_write").to_return(false)

    var result = serializer.save_rooms([])
    assert_false(result, "Should fail when file write fails")
```

### Pattern 5: Testing Result Objects
**What:** Validating structure and content of operation result objects
**When to use:** For operations that return validation results or detailed feedback
**Example:**
```gdscript
// Source: Existing codebase test_validation_operation.gd
func test_validation_result_structure() -> void:
    var result = _validation_op.validate_complete(room)

    assert_not_null(result, "Result should not be null")
    assert_typeof(result.is_valid, TYPE_BOOL, "is_valid should be bool")
    assert_typeof(result.errors, TYPE_ARRAY, "errors should be array")
```

### Anti-Patterns to Avoid
- **Testing implementation details:** Test public API behavior, not internal private methods
- **Shared state between tests:** Each test should be independent; avoid instance variables modified across tests
- **Over-mocking:** Only mock external dependencies (file system, network); keep domain logic real
- **Visual testing in unit tests:** Don't instantiate scenes/nodes in unit tests unless necessary; use integration tests for visual workflows
- **Ignoring memory management:** Always use add_child_autofree for nodes in tests to prevent memory leaks

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Test assertions | Custom comparison functions | GUT assert_* methods | GUT provides 40+ assertion methods with clear error messages |
| Signal testing | Manual signal connection tracking | watch_signals() + assert_signal_emitted() | GUT tracks up to 9 signal parameters automatically |
| Test fixtures | Manual setup/teardown | before_each/after_each/before_all/after_all | GUT lifecycle methods prevent state leakage |
| Mock objects | Custom stub classes | partial_double() + stub() | GUT partial doubles preserve real behavior, stub specific methods |
| Memory leak detection | Manual orphan counting | assert_no_new_orphans() | GUT tracks object lifecycle automatically |
| File system mocking | Wrapper abstractions | partial_double(FileAccess) + stub | Partial doubles can mock static FileAccess methods |
| Test organization | Flat test files | Inner test classes | GUT supports nested test classes for logical grouping |
| Collection assertions | Loop + individual asserts | assert_has/assert_does_not_have/assert_eq_deep | GUT deep comparison reports exact differences |

**Key insight:** GUT is a mature framework (9.x versions) with comprehensive built-in solutions for common testing challenges in game development. The existing codebase demonstrates effective patterns; don't reinvent them.

## Common Pitfalls

### Pitfall 1: FileAccess Mocking Complexity
**What goes wrong:** RoomSerializer uses static FileAccess methods (FileAccess.open, DirAccess.remove_absolute) which are difficult to mock without full native strategy
**Why it happens:** Godot's static methods on built-in types require DOUBLE_STRATEGY.INCLUDE_NATIVE to override
**How to avoid:** Create wrapper methods in RoomSerializer that can be stubbed, or test with actual temp files in user:// directory that are cleaned up after test
**Warning signs:** Tests fail with "cannot override native method" errors, or tests create actual save files

### Pitfall 2: Integration Test Memory Leaks
**What goes wrong:** Controllers or nodes instantiated in integration tests aren't properly freed, causing orphan warnings
**Why it happens:** add_child without autofree, or forgetting to free objects created in before_all
**How to avoid:** Always use add_child_autofree for nodes, manually free objects in after_all if created in before_all
**Warning signs:** GUT reports orphan nodes after tests complete, memory usage increases with test count

### Pitfall 3: Singleton State Pollution
**What goes wrong:** Tests that modify singleton state (RoomTypeRegistry, FurnitureRegistry) affect subsequent tests
**Why it happens:** Singletons persist across tests, changes aren't reset between test methods
**How to avoid:** Don't modify singleton data in tests; use helper methods to load real resources rather than mutating registry state
**Warning signs:** Tests pass individually but fail when run as suite, order-dependent test failures

### Pitfall 4: Over-Testing Visual Details
**What goes wrong:** Unit tests try to verify tilemap visuals, sprite positions, or rendering details
**Why it happens:** Misunderstanding unit vs integration test scope; operations create visuals as side effects
**How to avoid:** Unit tests verify data correctness (walls array, room bounds, validation results); integration tests verify visual side effects when necessary
**Warning signs:** Tests require TileMapLayer instances, fail without scene tree, depend on rendering

### Pitfall 5: Brittle Error Message Assertions
**What goes wrong:** Tests check for exact error message strings, break when messages are improved
**Why it happens:** Using assert_eq on full error messages instead of checking for key terms
**How to avoid:** Use assert_string_contains or check for key words ("door", "furniture", "size") in lowercase error text
**Warning signs:** Tests fail when error messages are reworded for clarity, but functionality is correct

### Pitfall 6: Testing Private Implementation
**What goes wrong:** Tests verify internal state or call private methods (prefixed with _)
**Why it happens:** Trying to achieve 100% coverage rather than testing behavior
**How to avoid:** Only test public API methods; private methods are covered indirectly through public method tests
**Warning signs:** Tests know too much about class internals, break with refactoring that doesn't change behavior

## Code Examples

Verified patterns from official sources:

### Testing Operations with Result Validation
```gdscript
// Source: Existing codebase test_door_operation.gd
extends GutTest

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
    var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
    var result = _door_op.is_valid_door_position(Vector2i(2, 0), room)
    assert_true(result, "Mid-wall position (2,0) should be valid for door")
```

### Testing Signal Emission in Integration Tests
```gdscript
// Source: Existing codebase test_room_build_flow.gd
func test_state_to_draw_box_on_room_type_selected() -> void:
    _controller.start_build_mode()
    watch_signals(_controller)

    _controller._on_room_type_selected("lobby")

    assert_eq(_controller.state_name, "draw_box", "State should be draw_box")
    assert_signal_emitted_with_parameters(_controller, "state_changed", ["draw_box"])
    assert_not_null(_controller.current_room, "Current room should be created")
```

### Testing Collections and Arrays
```gdscript
// Source: Existing codebase test_wall_operation.gd
func test_generate_walls_includes_all_corners() -> void:
    var box = Rect2i(0, 0, 5, 5)
    var walls = _wall_op.generate_walls(box)

    assert_has(walls, Vector2i(0, 0), "Top-left corner should be in walls")
    assert_has(walls, Vector2i(4, 0), "Top-right corner should be in walls")
    assert_has(walls, Vector2i(0, 4), "Bottom-left corner should be in walls")
    assert_has(walls, Vector2i(4, 4), "Bottom-right corner should be in walls")

    assert_does_not_have(walls, Vector2i(2, 2), "Interior should not be in walls")
```

### Testing with Actual Resources
```gdscript
// Source: Existing codebase test_validation_operation.gd
func _get_seating_bench() -> FurnitureResource:
    # Load actual resource that lobby requires
    return load("res://data/furniture/seating_bench.tres") as FurnitureResource

func test_valid_room_passes() -> void:
    var room = RoomInstance.new("test_room", "lobby")
    room.bounding_box = Rect2i(0, 0, 5, 5)
    room.walls = _wall_op.generate_walls(room.bounding_box)
    room.add_door(Vector2i(2, 0), 0)

    var bench = _get_seating_bench()
    room.add_furniture(bench, Vector2i(2, 2), 0)

    var result = _validation_op.validate_complete(room)
    assert_true(result.is_valid, "Valid room should pass validation")
```

### Testing Multiple Error Conditions
```gdscript
// Source: Existing codebase test_validation_operation.gd
func test_multiple_validation_errors() -> void:
    var room = RoomInstance.new("test_room", "lobby")
    room.bounding_box = Rect2i(0, 0, 2, 2)  # Too small
    room.walls = _wall_op.generate_walls(room.bounding_box)
    # No doors, no furniture

    var result = _validation_op.validate_complete(room)
    assert_false(result.is_valid, "Room with multiple issues should fail")
    assert_true(result.errors.size() >= 2, "Should have multiple error messages")
```

### Testing Edge Cases
```gdscript
// Source: Existing codebase test_collision_operation.gd
func test_null_room_fails() -> void:
    var furniture = _create_furniture("chair")
    var result = _collision_op.can_place_furniture(furniture, Vector2i(2, 2), 0, null)
    assert_false(result.can_place, "Placement with null room should fail")

func test_null_furniture_uses_single_tile() -> void:
    var room = _create_room_with_walls(Rect2i(0, 0, 5, 5))
    var result = _collision_op.can_place_furniture(null, Vector2i(2, 2), 0, room)
    assert_true(result.can_place, "Null furniture in valid position should use single tile")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| GUT 7.x for Godot 3 | GUT 9.5.1 for Godot 4.5+ | Godot 4 release | New assert methods, improved doubles, better memory tracking |
| Manual signal tracking | watch_signals() with 9 param support | GUT 9.x | Automatic signal capture with parameter validation |
| Full doubles only | Partial doubles preferred | GUT 8.x | Keep real behavior, stub only what's needed for tests |
| SCRIPT_ONLY strategy default | INCLUDE_NATIVE for mocking natives | GUT 9.x Godot 4 | Can override native methods with strategy flag |
| Manual file cleanup | add_child_autofree() | GUT 9.x | Automatic memory management in tests |

**Deprecated/outdated:**
- `add_child_autoqfree()`: Renamed to `add_child_autofree()` in GUT 9.x (both work, autofree is canonical)
- `assert_has_signal()`: Still works but less useful; test behavior not signature
- Full doubles as default: Partial doubles preserve more real behavior, reducing test brittleness

## Open Questions

Things that couldn't be fully resolved:

1. **FileAccess static method mocking**
   - What we know: RoomSerializer uses FileAccess.open, DirAccess.remove_absolute (static methods)
   - What's unclear: Whether DOUBLE_STRATEGY.INCLUDE_NATIVE works with static FileAccess methods in GUT 9.5.1
   - Recommendation: Test both approaches - (1) partial_double with INCLUDE_NATIVE strategy, (2) test with actual temp files in user:// with cleanup. If mocking fails, use real file approach with unique temp paths per test.

2. **Mobile-specific save scenarios**
   - What we know: Requirements mention testing "app suspension during save"
   - What's unclear: How to simulate app suspension in GUT tests (requires OS-level signals)
   - Recommendation: Manual testing for app suspension; unit tests verify atomic write pattern (temp file + rename) protects against interruption. Document mobile testing in test plan but don't automate in unit tests.

3. **CI Integration timing**
   - What we know: Phase 10 requirements say "All tests pass on CI before milestone completion"
   - What's unclear: Whether CI setup is in scope for Phase 10 or separate DevOps task
   - Recommendation: Make tests CI-ready (headless compatible, no GUI dependencies) but don't configure CI in this phase unless explicitly requested. Tests can run locally with GUT CLI.

## Sources

### Primary (HIGH confidence)
- [GUT 9.5.1 Official Documentation](https://gut.readthedocs.io/) - Complete assertion reference, lifecycle methods
- [GUT GitHub Repository](https://github.com/bitwes/Gut) - Version info, features, limitations
- [GUT Asserts Reference (9.3.1)](https://gut.readthedocs.io/en/9.3.1/Asserts-and-Methods.html) - All 40+ assertion methods with parameters
- [GUT Doubling Strategy](https://gut.readthedocs.io/en/latest/Double-Strategy.html) - Partial doubles, stubbing, spying patterns
- [GUT Memory Management](https://gut.readthedocs.io/en/9.3.1/Memory-Management.html) - add_child_autofree usage
- Existing codebase tests (test/unit/, test/integration/) - Verified working patterns

### Secondary (MEDIUM confidence)
- [Testing Error Handling in Godot Using GUT (2025)](https://ziumper.github.io/blog/2025/testing-error-handling-in-gdscript/) - FileAccess mocking pattern with partial_double
- [CI-tested GUT for Godot 4 (Medium, 2024)](https://medium.com/@kpicaza/ci-tested-gut-for-godot-4-fast-green-and-reliable-c56f16cde73d) - CI workflow patterns
- [GodotTestDriver GitHub](https://github.com/chickensoft-games/GodotTestDriver) - Alternative fixture patterns (C# focused)
- [Godot Forum: GUT testing instantiated scenes](https://forum.godotengine.org/t/using-gut-to-test-instantiating-scenes-via-autoload-singleton-event-bus-rootscene/86974) - Integration test patterns

### Tertiary (LOW confidence)
- Various Medium articles on Godot testing - General concepts verified with official docs

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - GUT 9.5.1 already integrated in project, official framework for Godot 4
- Architecture: HIGH - Existing test patterns in codebase provide proven structure
- Pitfalls: HIGH - Common issues documented in official GUT docs + identified from existing tests
- FileAccess mocking: MEDIUM - Pattern exists but needs verification with static methods
- Mobile testing: LOW - Simulation approach unclear, recommend manual testing

**Research date:** 2025-02-07
**Valid until:** 90 days (stable framework, Godot 4.5 is current stable)
