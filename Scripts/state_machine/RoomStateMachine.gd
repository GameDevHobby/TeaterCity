class_name RoomStateMachine
extends RefCounted

## Abstract state machine for rooms with timed auto-transitions.
## Uses TimerState for offline-capable state timing.
## Supports fast-forward recalculation for app resume scenarios.

signal state_changed(old_state: String, new_state: String)

## Current state name (empty string if not initialized)
var current_state: String = ""

## Timer for current state (null if state has no duration)
var timer: TimerState = null

## State definitions: state_name -> StateDefinition mapping
var states: Dictionary = {}


## Register a state definition
func define_state(state_name: String, duration_seconds: int = 0, next: String = "") -> void:
	states[state_name] = StateDefinition.new(state_name, duration_seconds, next)


## Transition to a new state; starts timer if state has duration
func transition_to(new_state: String) -> void:
	if not states.has(new_state):
		push_error("RoomStateMachine: Cannot transition to unknown state '%s'" % new_state)
		return

	var old_state = current_state
	current_state = new_state

	var state_def: StateDefinition = states[new_state]

	# Stop any existing timer
	if timer:
		timer.stop()
		timer = null

	# Start new timer if state has duration
	if state_def.duration > 0:
		timer = TimerState.new()
		timer.start(state_def.duration)

	state_changed.emit(old_state, new_state)


## Call on _process or periodically to check for auto-transitions.
## Returns true if a transition occurred.
func update() -> bool:
	if timer and timer.is_complete():
		var state_def = states.get(current_state)
		if state_def and state_def.next_state != "":
			transition_to(state_def.next_state)
			return true
	return false


## Called on app resume to fast-forward through offline transitions.
## Returns the number of state transitions that occurred.
func recalculate_from_elapsed() -> int:
	var transition_count := 0

	while timer and timer.is_complete():
		var state_def = states.get(current_state)
		if state_def and state_def.next_state != "":
			# Account for overflow into next state
			var overflow = timer.get_elapsed() - timer.duration
			transition_to(state_def.next_state)
			transition_count += 1
			if timer and timer.is_active:
				timer.start_time -= overflow  # Back-date to account for overflow
		else:
			break  # No next state, stop

	return transition_count


## Serialize (current_state + timer)
func to_dict() -> Dictionary:
	return {
		"current_state": current_state,
		"timer": timer.to_dict() if timer else null
	}


## Deserialize with state definitions
## state_definitions: Dictionary mapping state names to StateDefinition objects
static func from_dict(data: Dictionary, state_definitions: Dictionary) -> RoomStateMachine:
	var machine = RoomStateMachine.new()

	# Restore state definitions
	machine.states = state_definitions

	# Restore current state (with safe default and type validation)
	var state = data.get("current_state", "")
	machine.current_state = state if state is String else ""

	# Validate current state
	if machine.current_state != "" and not machine.states.has(machine.current_state):
		push_warning("RoomStateMachine: Loaded state '%s' not found in definitions, resetting to empty" % machine.current_state)
		machine.current_state = ""

	# Restore timer if present and valid
	var timer_data = data.get("timer")
	if timer_data != null and timer_data is Dictionary:
		machine.timer = TimerState.from_dict(timer_data)

	return machine
