class_name TimerState
extends RefCounted

## Timestamp-based offline timer for room state tracking.
## Uses Unix timestamps to track elapsed time, allowing for offline progression.
## CRITICAL: All timestamps stored as int to avoid JSON scientific notation corruption.

## Unix timestamp when timer started (0 if not started)
var start_time: int = 0

## Duration in seconds
var duration: int = 0

## Whether timer is running
var is_active: bool = false


## Start timer with given duration, sets start_time to current Unix time
func start(duration_seconds: int) -> void:
	duration = duration_seconds
	start_time = int(Time.get_unix_time_from_system())
	is_active = true


## Stop timer (set is_active = false)
func stop() -> void:
	is_active = false


## Returns elapsed seconds (clamped to >= 0 to handle backward clock manipulation)
func get_elapsed() -> int:
	if not is_active:
		return 0

	var current_time = int(Time.get_unix_time_from_system())
	var elapsed = current_time - start_time
	# Clamp to handle backward clock manipulation
	return maxi(0, elapsed)


## Returns remaining seconds (clamped to >= 0)
func get_remaining() -> int:
	if not is_active:
		return 0

	var elapsed = get_elapsed()
	var remaining = duration - elapsed
	return maxi(0, remaining)


## Returns true if timer is active AND elapsed >= duration
func is_complete() -> bool:
	if not is_active:
		return false

	return get_elapsed() >= duration


## Serialize to JSON-safe dictionary
func to_dict() -> Dictionary:
	return {
		"start_time": start_time,
		"duration": duration,
		"is_active": is_active
	}


## Helper to safely convert JSON numbers (which may be float) to int
static func _to_int(value, default: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return default


## Deserialize from dictionary with safe defaults
static func from_dict(data: Dictionary) -> TimerState:
	var timer = TimerState.new()

	# Use safe defaults for missing/invalid data, with type validation
	timer.start_time = _to_int(data.get("start_time", 0))
	timer.duration = _to_int(data.get("duration", 0))

	var active = data.get("is_active", false)
	timer.is_active = active if active is bool else false

	return timer
