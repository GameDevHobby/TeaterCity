extends Node

signal entity_added(entity: Node2D)
signal navigation_changed

var _entity_instances: Array[Node2D] = []
 
func add_entity(entity_instance: Node2D) -> void:
	if not entity_instance in _entity_instances:
		_entity_instances.append(entity_instance)
		# This is another thing groups can't do.
		entity_added.emit(entity_instance)


func get_random_entity() -> Node2D:
	if _entity_instances.is_empty():
		return null

	var index := randi_range(0, _entity_instances.size() - 1)
	return _entity_instances[index]


func notify_navigation_changed() -> void:
	navigation_changed.emit()
