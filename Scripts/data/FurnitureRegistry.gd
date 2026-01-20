class_name FurnitureRegistry
extends Resource

@export var furniture_items: Array[FurnitureResource] = []

static var _instance: FurnitureRegistry
static var _path = "res://data/configs/furniture_registry.tres"

static func get_instance() -> FurnitureRegistry:
	if _instance == null:
		_instance = ResourceLoader.load(_path)
	return _instance

func get_furniture(id: String) -> FurnitureResource:
	for item in furniture_items:
		if item.id == id:
			return item
	return null

func get_furniture_cost(id: String) -> int:
	var item = get_furniture(id)
	return item.cost if item else 0

func get_all_furniture() -> Array[FurnitureResource]:
	return furniture_items

func get_all_furniture_for_room(room_type: RoomTypeResource) -> Array[FurnitureResource]:
	if not room_type:
		return []
	return room_type.allowed_furniture.duplicate()
