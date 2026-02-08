class_name TestRoomStateMachine
extends GutTest

## Unit tests for RoomStateMachine
## Tests state definition, transitions, signals, update loop, and multi-state recalculation

var sm: RoomStateMachine


func before_each() -> void:
	sm = RoomStateMachine.new()
	# Define test states: idle -> active (10s) -> cooldown (5s) -> idle
	sm.define_state("idle", 0, "")  # No auto-transition
	sm.define_state("active", 10, "cooldown")  # 10s then -> cooldown
	sm.define_state("cooldown", 5, "idle")  # 5s then -> idle


func after_each() -> void:
	sm = null


# --- State Definition ---

func test_define_state_adds_to_dictionary() -> void:
	assert_true("idle" in sm.states, "idle should be defined")
	assert_true("active" in sm.states, "active should be defined")
	assert_true("cooldown" in sm.states, "cooldown should be defined")


func test_state_definition_properties() -> void:
	var active_def = sm.states["active"]
	assert_eq(active_def.name, "active", "name should match")
	assert_eq(active_def.duration, 10, "duration should match")
	assert_eq(active_def.next_state, "cooldown", "next_state should match")


# --- State Transitions ---

func test_transition_to_valid_state() -> void:
	sm.transition_to("idle")
	assert_eq(sm.current_state, "idle", "should be in idle state")


func test_transition_to_timed_state_starts_timer() -> void:
	sm.transition_to("active")
	assert_not_null(sm.timer, "timer should be created")
	assert_true(sm.timer.is_active, "timer should be active")
	assert_eq(sm.timer.duration, 10, "timer duration should match state duration")


func test_transition_to_untimed_state_stops_timer() -> void:
	sm.transition_to("active")  # Start with timed state
	sm.transition_to("idle")  # Switch to untimed
	assert_false(sm.timer.is_active, "timer should be inactive for untimed state")


func test_transition_to_unknown_state_does_nothing() -> void:
	sm.transition_to("idle")
	sm.transition_to("nonexistent")
	assert_eq(sm.current_state, "idle", "should remain in idle for unknown state")


# --- Signal Emission ---

func test_state_changed_signal_emitted() -> void:
	var signal_received = false
	var received_old = ""
	var received_new = ""

	sm.state_changed.connect(func(old, new):
		signal_received = true
		received_old = old
		received_new = new
	)

	sm.transition_to("active")

	assert_true(signal_received, "state_changed should be emitted")
	assert_eq(received_old, "", "old state should be empty initially")
	assert_eq(received_new, "active", "new state should be active")


# --- Update (single transition check) ---

func test_update_no_transition_when_timer_not_complete() -> void:
	sm.transition_to("active")
	var transitioned = sm.update()
	assert_false(transitioned, "should not transition when timer not complete")
	assert_eq(sm.current_state, "active", "should remain in active")


func test_update_transitions_when_timer_complete() -> void:
	sm.transition_to("active")
	# Simulate timer completion
	sm.timer.start_time = int(Time.get_unix_time_from_system()) - 20  # 20s ago, > 10s duration

	var transitioned = sm.update()
	assert_true(transitioned, "should transition when timer complete")
	assert_eq(sm.current_state, "cooldown", "should be in cooldown state")


# --- Recalculate From Elapsed (multi-transition) ---

func test_recalculate_no_transitions_when_fresh() -> void:
	sm.transition_to("idle")
	var count = sm.recalculate_from_elapsed()
	assert_eq(count, 0, "no transitions for fresh idle state")


func test_recalculate_single_transition() -> void:
	sm.transition_to("active")
	# Simulate 15 seconds passed (> 10s duration, should transition to cooldown)
	sm.timer.start_time = int(Time.get_unix_time_from_system()) - 15

	var count = sm.recalculate_from_elapsed()
	assert_eq(count, 1, "should have 1 transition")
	assert_eq(sm.current_state, "cooldown", "should be in cooldown")


func test_recalculate_multiple_transitions() -> void:
	sm.transition_to("active")
	# Simulate 20 seconds passed (> 10s active + 5s cooldown = 15s total)
	# Should transition: active -> cooldown -> idle
	sm.timer.start_time = int(Time.get_unix_time_from_system()) - 20

	var count = sm.recalculate_from_elapsed()
	assert_eq(count, 2, "should have 2 transitions")
	assert_eq(sm.current_state, "idle", "should end in idle")


func test_recalculate_stops_at_untimed_state() -> void:
	sm.transition_to("active")
	# Simulate very long time passed
	sm.timer.start_time = int(Time.get_unix_time_from_system()) - 3600  # 1 hour

	var count = sm.recalculate_from_elapsed()
	assert_eq(sm.current_state, "idle", "should end in idle")
	# Stops at idle because idle has no next_state


# --- Serialization ---

func test_to_dict_format() -> void:
	sm.transition_to("active")
	var dict = sm.to_dict()

	assert_true(dict.has("current_state"), "should have current_state")
	assert_eq(dict.current_state, "active", "current_state should match")
	assert_true(dict.has("timer"), "should have timer")


func test_from_dict_restores_state() -> void:
	sm.transition_to("active")
	var dict = sm.to_dict()

	var restored = RoomStateMachine.from_dict(dict, sm.states)
	assert_eq(restored.current_state, "active", "current_state should be restored")
	assert_not_null(restored.timer, "timer should be restored")
	assert_eq(restored.timer.duration, 10, "timer duration should be restored")


func test_from_dict_handles_null_timer() -> void:
	sm.transition_to("idle")
	var dict = sm.to_dict()

	var restored = RoomStateMachine.from_dict(dict, sm.states)
	assert_eq(restored.current_state, "idle", "should restore idle state")
