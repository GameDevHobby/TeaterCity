class_name TestTimerPersistence
extends GutTest

## Integration tests for timer/state machine persistence
## Tests serialization round-trip through RoomInstance, state recalculation, and error recovery

# --- Integration tests for timer/state machine persistence ---

func test_room_instance_with_state_machine_serializes() -> void:
	# Create room with state machine
	var room = RoomInstance.new("test-1", "theater")
	room.bounding_box = Rect2i(0, 0, 5, 5)

	# Set up state machine
	var states = {}
	states["idle"] = StateDefinition.new("idle", 0, "")
	states["playing"] = StateDefinition.new("playing", 60, "cleaning")
	states["cleaning"] = StateDefinition.new("cleaning", 30, "idle")

	room.initialize_state_machine(states)
	room.state_machine.transition_to("playing")

	# Serialize
	var dict = room.to_dict()

	# Verify state machine is in dict
	assert_true(dict.has("state_machine"), "should have state_machine in dict")
	assert_eq(dict.state_machine.current_state, "playing", "state should be playing")


func test_room_instance_state_machine_round_trip() -> void:
	# Create and configure original
	var original = RoomInstance.new("test-2", "theater")
	original.bounding_box = Rect2i(0, 0, 5, 5)

	var states = {}
	states["idle"] = StateDefinition.new("idle", 0, "")
	states["scheduled"] = StateDefinition.new("scheduled", 10, "playing")
	states["playing"] = StateDefinition.new("playing", 60, "idle")

	original.initialize_state_machine(states)
	original.state_machine.transition_to("scheduled")

	# Serialize and deserialize
	var dict = original.to_dict()
	var restored = RoomInstance.from_dict(dict)

	# Initialize state machine on restored room
	restored.initialize_state_machine(states)

	# Verify
	assert_eq(restored.state_machine.current_state, "scheduled", "state should be restored")
	assert_true(restored.state_machine.timer.is_active, "timer should be active")


func test_state_recalculates_on_restore() -> void:
	# Create room with state machine
	var room = RoomInstance.new("test-3", "theater")
	room.bounding_box = Rect2i(0, 0, 5, 5)

	var states = {}
	states["idle"] = StateDefinition.new("idle", 0, "")
	states["playing"] = StateDefinition.new("playing", 10, "idle")  # 10 second duration

	room.initialize_state_machine(states)
	room.state_machine.transition_to("playing")

	# Simulate time passing (backdate timer start)
	room.state_machine.timer.start_time = int(Time.get_unix_time_from_system()) - 20  # 20s ago

	# Serialize
	var dict = room.to_dict()

	# Deserialize
	var restored = RoomInstance.from_dict(dict)
	var transitions = restored.initialize_state_machine(states)

	# Should have auto-transitioned to idle
	assert_eq(transitions, 1, "should have 1 transition on recalculate")
	assert_eq(restored.state_machine.current_state, "idle", "should be in idle after recalculate")


func test_corrupted_state_machine_data_recovers() -> void:
	# Create room with intentionally corrupted state machine data
	var dict = {
		"schema_version": 2,
		"id": "test-4",
		"room_type_id": "theater",
		"bounding_box": {"x": 0, "y": 0, "width": 5, "height": 5},
		"walls": [],
		"doors": [],
		"furniture": [],
		"state_machine": {
			"current_state": "nonexistent_state",  # Invalid state
			"timer": {"start_time": "invalid", "duration": "bad", "is_active": "yes"}  # Invalid types
		}
	}

	var states = {}
	states["idle"] = StateDefinition.new("idle", 0, "")

	var restored = RoomInstance.from_dict(dict)
	var transitions = restored.initialize_state_machine(states)

	# Should recover gracefully
	assert_not_null(restored.state_machine, "should have state machine after recovery")
	# The implementation should either reset to first state or handle the error


func test_room_without_state_machine_serializes_normally() -> void:
	# Room without state machine should work as before
	var room = RoomInstance.new("test-5", "lobby")
	room.bounding_box = Rect2i(0, 0, 3, 3)

	var dict = room.to_dict()
	assert_false(dict.has("state_machine"), "should not have state_machine key")

	var restored = RoomInstance.from_dict(dict)
	assert_null(restored.state_machine, "state_machine should remain null")
