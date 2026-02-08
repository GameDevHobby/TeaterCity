class_name TestTimerState
extends GutTest

## Unit tests for TimerState
## Tests offline timer with Unix timestamps, clock manipulation handling, and serialization

var timer: TimerState


func before_each() -> void:
	timer = TimerState.new()


func after_each() -> void:
	timer = null


# --- Basic Functionality ---

func test_initial_state() -> void:
	assert_eq(timer.start_time, 0, "start_time should be 0 initially")
	assert_eq(timer.duration, 0, "duration should be 0 initially")
	assert_false(timer.is_active, "should not be active initially")


func test_start_sets_active() -> void:
	timer.start(60)
	assert_true(timer.is_active, "should be active after start")
	assert_eq(timer.duration, 60, "duration should be set")
	assert_true(timer.start_time > 0, "start_time should be set to current time")


func test_stop_clears_active() -> void:
	timer.start(60)
	timer.stop()
	assert_false(timer.is_active, "should not be active after stop")


func test_elapsed_when_not_active() -> void:
	assert_eq(timer.get_elapsed(), 0, "elapsed should be 0 when not active")


func test_remaining_calculation() -> void:
	timer.start(60)
	# Immediately after start, remaining should be close to duration
	var remaining = timer.get_remaining()
	assert_true(remaining >= 59 and remaining <= 60, "remaining should be near duration immediately after start")


func test_is_complete_false_when_time_remaining() -> void:
	timer.start(3600)  # 1 hour
	assert_false(timer.is_complete(), "should not be complete with time remaining")


# --- Offline Simulation ---

func test_elapsed_after_simulated_offline() -> void:
	# Simulate timer started 30 seconds ago
	timer.is_active = true
	timer.duration = 60
	timer.start_time = int(Time.get_unix_time_from_system()) - 30

	var elapsed = timer.get_elapsed()
	assert_true(elapsed >= 29 and elapsed <= 31, "elapsed should be ~30 seconds: got %d" % elapsed)


func test_is_complete_after_duration_passed() -> void:
	# Simulate timer started 120 seconds ago with 60 second duration
	timer.is_active = true
	timer.duration = 60
	timer.start_time = int(Time.get_unix_time_from_system()) - 120

	assert_true(timer.is_complete(), "should be complete when elapsed > duration")


func test_remaining_clamps_to_zero() -> void:
	# Simulate timer expired long ago
	timer.is_active = true
	timer.duration = 60
	timer.start_time = int(Time.get_unix_time_from_system()) - 3600  # 1 hour ago

	assert_eq(timer.get_remaining(), 0, "remaining should clamp to 0")


# --- Clock Manipulation ---

func test_backward_clock_clamps_to_zero() -> void:
	# Simulate clock set backward (start_time in future)
	timer.is_active = true
	timer.duration = 60
	timer.start_time = int(Time.get_unix_time_from_system()) + 100  # 100 seconds in future

	var elapsed = timer.get_elapsed()
	assert_eq(elapsed, 0, "elapsed should clamp to 0 for backward clock")


# --- Serialization ---

func test_to_dict_format() -> void:
	timer.start(120)
	var dict = timer.to_dict()

	assert_true(dict.has("start_time"), "should have start_time")
	assert_true(dict.has("duration"), "should have duration")
	assert_true(dict.has("is_active"), "should have is_active")
	assert_eq(dict.duration, 120, "duration should match")
	assert_true(dict.is_active, "is_active should match")


func test_from_dict_restores_state() -> void:
	timer.start(180)
	var dict = timer.to_dict()

	var restored = TimerState.from_dict(dict)
	assert_eq(restored.start_time, timer.start_time, "start_time should be restored")
	assert_eq(restored.duration, timer.duration, "duration should be restored")
	assert_eq(restored.is_active, timer.is_active, "is_active should be restored")


func test_from_dict_handles_missing_fields() -> void:
	var restored = TimerState.from_dict({})
	assert_eq(restored.start_time, 0, "should default to 0")
	assert_eq(restored.duration, 0, "should default to 0")
	assert_false(restored.is_active, "should default to false")


func test_start_time_is_int() -> void:
	timer.start(60)
	var dict = timer.to_dict()
	# Verify start_time is int (not float that could corrupt to scientific notation)
	assert_true(dict.start_time is int, "start_time should be int, got %s" % typeof(dict.start_time))
