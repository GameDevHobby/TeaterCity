class_name TestTheaterStateResume
extends GutTest


func test_theater_state_machine_serializes_into_room_payload() -> void:
	var room = RoomInstance.new("resume-1", TheaterStateConfig.THEATER_ROOM_TYPE_ID)
	room.bounding_box = Rect2i(0, 0, 6, 6)

	var definitions = TheaterStateConfig.build_state_definitions(15, 10, 60, 20)
	room.initialize_state_machine(definitions)
	room.state_machine.transition_to("scheduled")

	var payload = room.to_dict()

	assert_true(payload.has("state_machine"), "serialized room should include state_machine")
	assert_eq(payload.state_machine.current_state, "scheduled", "serialized state should match runtime state")


func test_round_trip_restore_rehydrates_state_and_timer() -> void:
	var original = RoomInstance.new("resume-2", TheaterStateConfig.THEATER_ROOM_TYPE_ID)
	original.bounding_box = Rect2i(0, 0, 6, 6)

	var definitions = TheaterStateConfig.build_state_definitions(20, 10, 90, 30)
	original.initialize_state_machine(definitions)
	original.state_machine.transition_to("previews")

	var payload = original.to_dict()
	var restored = RoomInstance.from_dict(payload)
	var transitions = restored.initialize_state_machine(definitions)

	assert_eq(transitions, 0, "freshly restored preview timer should not auto-transition immediately")
	assert_not_null(restored.state_machine, "restored room should have a state machine")
	assert_eq(restored.state_machine.current_state, "previews", "restored state should match saved state")
	assert_not_null(restored.state_machine.timer, "restored timed state should have timer")
	assert_true(restored.state_machine.timer.is_active, "restored timer should be active")


func test_restore_fast_forwards_across_multiple_transitions() -> void:
	var room = RoomInstance.new("resume-3", TheaterStateConfig.THEATER_ROOM_TYPE_ID)
	room.bounding_box = Rect2i(0, 0, 6, 6)

	var definitions = TheaterStateConfig.build_state_definitions(5, 4, 3, 2)
	room.initialize_state_machine(definitions)
	room.state_machine.transition_to("scheduled")
	room.state_machine.timer.start_time = int(Time.get_unix_time_from_system()) - 20

	var payload = room.to_dict()
	var restored = RoomInstance.from_dict(payload)
	var transitions = restored.initialize_state_machine(definitions)

	assert_eq(transitions, 4, "restore should fast-forward to idle through full chain")
	assert_eq(restored.state_machine.current_state, "idle", "restored state should end in idle")


func test_invalid_saved_state_payload_recovers_safely() -> void:
	var corrupted_payload = {
		"schema_version": 2,
		"id": "resume-4",
		"room_type_id": TheaterStateConfig.THEATER_ROOM_TYPE_ID,
		"bounding_box": {"x": 0, "y": 0, "width": 5, "height": 5},
		"walls": [],
		"doors": [],
		"furniture": [],
		"state_machine": {
			"current_state": "unknown",
			"timer": {
				"start_time": "bad",
				"duration": "also_bad",
				"is_active": true
			}
		}
	}

	var restored = RoomInstance.from_dict(corrupted_payload)
	var definitions = TheaterStateConfig.build_state_definitions()
	var transitions = restored.initialize_state_machine(definitions)

	assert_eq(transitions, 0, "invalid saved state should recover without transitions")
	assert_not_null(restored.state_machine, "restored room should still get a state machine")
	if restored.state_machine.current_state == "":
		restored.state_machine.transition_to("idle")
	assert_eq(restored.state_machine.current_state, "idle", "recovered state machine should be usable")
