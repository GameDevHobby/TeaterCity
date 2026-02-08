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


## Check if current timer complete and auto-transition if needed
## Call from _process or periodically
func update() -> void:
	if not timer or not timer.is_active:
		return

	if timer.is_complete():
		var state_def: StateDefinition = states.get(current_state)
		if state_def and state_def.next_state != "":
			transition_to(state_def.next_state)


## Fast-forward through all completed states (call on app resume)
## Loops through transitions as long as timer is complete and next_state exists
## Accounts for overflow time when transitioning
func recalculate_from_elapsed() -> void:
	var max_iterations = 100  # Safety limit to prevent infinite loops
	var iterations = 0

	while iterations < max_iterations:
		iterations += 1

		# Check if we have an active timer
		if not timer or not timer.is_active:
			break

		# Check if timer is complete
		if not timer.is_complete():
			break

		# Get current state definition
		var state_def: StateDefinition = states.get(current_state)
		if not state_def or state_def.next_state == "":
			break

		# Calculate overflow time
		var overflow = timer.get_elapsed() - timer.duration

		# Transition to next state
		transition_to(state_def.next_state)

		# Back-date timer to account for overflow
		if timer and timer.is_active:
			timer.start_time -= overflow


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

	# Restore current state (with safe default)
	machine.current_state = data.get("current_state", "")

	# Validate current state
	if machine.current_state != "" and not machine.states.has(machine.current_state):
		push_warning("RoomStateMachine: Loaded state '%s' not found in definitions, resetting to empty" % machine.current_state)
		machine.current_state = ""

	# Restore timer if present
	var timer_data = data.get("timer")
	if timer_data != null:
		machine.timer = TimerState.from_dict(timer_data)

	return machine
