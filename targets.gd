extends Node

signal entity_added(entity: Node2D)
 
var _entitiy_instances: Array[Node2D] = []
 
func add_entity(entity_instance: Node2D) -> void:
	if not entity_instance in _entitiy_instances:
		_entitiy_instances.append(entity_instance)
		# This is another thing groups can't do.
		entity_added.emit(entity_instance)


func get_random_entity() -> Node2D:
	if _entitiy_instances.is_empty():
		return null

	var index := randi_range(0, _entitiy_instances.size() - 1)
	return _entitiy_instances[index]
