class_name StateDefinition
extends RefCounted

## Data class for state configuration in data-driven state machines.
## Defines a state with optional timed auto-transition to another state.

## State name identifier
var name: String

## Duration in seconds (0 = no auto-transition)
var duration: int = 0

## Next state name for auto-transition (empty = no auto-transition)
var next_state: String = ""


func _init(p_name: String = "", p_duration: int = 0, p_next: String = "") -> void:
	name = p_name
	duration = p_duration
	next_state = p_next
