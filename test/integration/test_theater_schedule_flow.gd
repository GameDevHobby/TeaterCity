class_name TestTheaterScheduleFlow
extends GutTest


func test_valid_idle_theater_schedule_sets_payload_and_transitions() -> void:
	var main := Main.new()
	main._movie_pool = _build_movie_pool()

	var room := _build_theater_room("room_valid")
	room.state_machine.transition_to("idle")

	var did_schedule = main.schedule_theater_movie(room, "movie_alpha")

	assert_true(did_schedule, "Idle theater with valid movie should schedule")
	assert_eq(room.scheduled_movie_id, "movie_alpha", "Scheduled movie id should be assigned")
	assert_eq(room.state_machine.current_state, "scheduled", "State should transition to scheduled")


func test_missing_movie_id_does_not_schedule() -> void:
	var main := Main.new()
	main._movie_pool = _build_movie_pool()

	var room := _build_theater_room("room_missing_movie")
	room.state_machine.transition_to("idle")

	var did_schedule = main.schedule_theater_movie(room, "movie_missing")

	assert_false(did_schedule, "Unknown movie should fail schedule")
	assert_false(room.has_scheduled_movie(), "Movie payload should remain empty")
	assert_eq(room.state_machine.current_state, "idle", "State should stay idle")


func test_non_idle_theater_does_not_reschedule() -> void:
	var main := Main.new()
	main._movie_pool = _build_movie_pool()

	var room := _build_theater_room("room_non_idle")
	room.state_machine.transition_to("playing")

	var did_schedule = main.schedule_theater_movie(room, "movie_alpha")

	assert_false(did_schedule, "Non-idle theater should not schedule")
	assert_false(room.has_scheduled_movie(), "Movie payload should not be assigned")
	assert_eq(room.state_machine.current_state, "playing", "State should remain unchanged")


func test_non_theater_room_type_action_remains_noop() -> void:
	var main := Main.new()
	main._movie_pool = _build_movie_pool()

	var room := RoomInstance.new("room_lobby", "lobby")
	room.bounding_box = Rect2i(0, 0, 5, 5)

	main._on_room_type_action_requested(room)

	assert_false(room.has_scheduled_movie(), "Non-theater action should not set scheduled movie")


func _build_theater_room(room_id: String) -> RoomInstance:
	var room := RoomInstance.new(room_id, TheaterStateConfig.THEATER_ROOM_TYPE_ID)
	room.bounding_box = Rect2i(0, 0, 6, 6)
	room.initialize_state_machine(TheaterStateConfig.build_state_definitions())
	return room


func _build_movie_pool() -> MoviePool:
	var pool := MoviePool.new()

	var movie_a := MovieResource.new()
	movie_a.id = "movie_alpha"
	movie_a.title = "Alpha"
	movie_a.genre = "Action"
	movie_a.rating = 80
	movie_a.duration = 100
	pool.add_movie(movie_a)

	var movie_b := MovieResource.new()
	movie_b.id = "movie_bravo"
	movie_b.title = "Bravo"
	movie_b.genre = "Drama"
	movie_b.rating = 74
	movie_b.duration = 95
	pool.add_movie(movie_b)

	return pool
