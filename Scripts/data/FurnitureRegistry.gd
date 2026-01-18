class_name FurnitureRegistry
extends Resource

@export var furniture_items: Dictionary = {}

static var _instance: FurnitureRegistry
static var _path = "res://data/resources/configs/furniture_registry.tres"

static func get_instance() -> FurnitureRegistry:
	if _instance == null:
		_instance = ResourceLoader.load(_path)
	return _instance

func get_furniture(id: String) -> FurnitureResource:
	return furniture_items.get(id, null)

func get_furniture_cost(id: String) -> int:
	var item = get_furniture(id)
	return item.cost if item else 0

func get_all_furniture_for_room(room_type_id: String) -> Array[FurnitureResource]:
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room_type_id)
	if not room_type:
		return []
	
	var result: Array[FurnitureResource] = []
	for furniture_id in room_type.allowed_furniture:
		var item = get_furniture(furniture_id)
		if item:
			result.append(item)
	return result
