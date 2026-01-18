class_name RoomTypeRegistry
extends Resource

@export var room_types: Dictionary = {}

static var _instance: RoomTypeRegistry
static var _path = "res://data/resources/configs/room_type_registry.tres"

static func get_instance() -> RoomTypeRegistry:
	if _instance == null:
		_instance = ResourceLoader.load(_path)
	return _instance

func get_room_type(id: String) -> RoomTypeResource:
	return room_types.get(id, null)

func get_all_room_types() -> Array:
	return room_types.values()

func has_room_type(id: String) -> bool:
	return room_types.has(id)
