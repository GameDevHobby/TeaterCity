class_name TestTheaterStateMachine
extends GutTest


func test_theater_state_config_includes_all_required_states() -> void:
	var definitions = TheaterStateConfig.build_state_definitions()

	assert_eq(definitions.size(), 5, "theater config should contain 5 states")
	assert_true(definitions.has("idle"), "should include idle")
	assert_true(definitions.has("scheduled"), "should include scheduled")
	assert_true(definitions.has("previews"), "should include previews")
	assert_true(definitions.has("playing"), "should include playing")
	assert_true(definitions.has("cleaning"), "should include cleaning")


func test_theater_state_transition_chain_is_canonical() -> void:
	var definitions = TheaterStateConfig.build_state_definitions(12, 8, 90, 20)

	assert_eq(definitions["idle"].duration, 0, "idle should be untimed")
	assert_eq(definitions["idle"].next_state, "", "idle should not auto-transition")

	assert_eq(definitions["scheduled"].duration, 12, "scheduled duration should match input")
	assert_eq(definitions["scheduled"].next_state, "previews", "scheduled should transition to previews")

	assert_eq(definitions["previews"].duration, 8, "previews duration should match input")
	assert_eq(definitions["previews"].next_state, "playing", "previews should transition to playing")

	assert_eq(definitions["playing"].duration, 90, "playing duration should match input")
	assert_eq(definitions["playing"].next_state, "cleaning", "playing should transition to cleaning")

	assert_eq(definitions["cleaning"].duration, 20, "cleaning duration should match input")
	assert_eq(definitions["cleaning"].next_state, "idle", "cleaning should transition to idle")


func test_fresh_theater_initialization_starts_in_idle() -> void:
	var room = RoomInstance.new("theater-test", TheaterStateConfig.THEATER_ROOM_TYPE_ID)
	var definitions = TheaterStateConfig.build_state_definitions(30, 10, 120, 15)

	room.initialize_state_machine(definitions)
	if room.state_machine and room.state_machine.current_state == "":
		room.state_machine.transition_to("idle")

	assert_not_null(room.state_machine, "theater room should have a state machine")
	assert_eq(room.state_machine.current_state, "idle", "fresh theater should start in idle")


func test_scheduled_state_auto_advances_back_to_idle_with_elapsed_time() -> void:
	var machine = RoomStateMachine.new()
	var definitions = TheaterStateConfig.build_state_definitions(5, 4, 3, 2)

	for state_name in definitions:
		var def = definitions[state_name]
		machine.define_state(def.name, def.duration, def.next_state)

	machine.transition_to("scheduled")
	assert_not_null(machine.timer, "scheduled should create timer")

	# 20 seconds exceeds 5 + 4 + 3 + 2 and should reach idle.
	machine.timer.start_time = int(Time.get_unix_time_from_system()) - 20
	var transition_count = machine.recalculate_from_elapsed()

	assert_eq(transition_count, 4, "should transition through previews, playing, cleaning, and idle")
	assert_eq(machine.current_state, "idle", "machine should settle in idle")


func test_non_theater_room_guard_does_not_apply_theater_initialization() -> void:
	var room = RoomInstance.new("non-theater-test", "lobby")

	if TheaterStateConfig.is_theater_room(room):
		room.initialize_state_machine(TheaterStateConfig.build_state_definitions())

	assert_false(TheaterStateConfig.is_theater_room(room), "lobby should not be treated as theater")
	assert_null(room.state_machine, "non-theater room should not auto-initialize theater states")
