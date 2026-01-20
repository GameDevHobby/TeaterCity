class_name RoomTypeRegistry
extends Resource

@export var room_types: Array[RoomTypeResource] = []

static var _instance: RoomTypeRegistry
static var _path = "res://data/configs/room_type_registry.tres"

static func get_instance() -> RoomTypeRegistry:
	if _instance == null:
		_instance = ResourceLoader.load(_path)
	return _instance

func get_room_type(id: String) -> RoomTypeResource:
	for rt in room_types:
		if rt.id == id:
			return rt
	return null

func get_all_room_types() -> Array[RoomTypeResource]:
	return room_types

func has_room_type(id: String) -> bool:
	return get_room_type(id) != null
