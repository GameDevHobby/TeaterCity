class_name RoomTypeResource
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var min_size: Vector2i
@export var max_size: Vector2i
@export var has_seating: bool = false
@export var has_walls: bool = true
@export var door_count_min: int = 1
@export var door_count_max: int = 2
@export var base_cost: int = 0
@export var allowed_furniture: Array[String] = []
@export var required_furniture: Array[String] = []

func get_required_furniture_dict() -> Dictionary[String, int]:
	var result: Dictionary[String, int] = {}
	for item in required_furniture:
		var parts = item.split(":")
		if parts.size() == 2:
			result[parts[0]] = parts[1].to_int()
	return result
