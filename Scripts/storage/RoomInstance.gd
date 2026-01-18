class_name RoomInstance
extends RefCounted

signal placement_changed

var id: String
var room_type_id: String
var bounding_box: Rect2i
var walls: Array[Vector2i] = []
var doors: Array[DoorPlacement] = []
var furniture: Array[FurniturePlacement] = []

class DoorPlacement:
	var position: Vector2i
	var direction: int
	
	func _init(pos: Vector2i, dir: int):
		position = pos
		direction = dir

class FurniturePlacement:
	var furniture_id: String
	var position: Vector2i
	var rotation: int
	
	func _init(id: String, pos: Vector2i, rot: int = 0):
		furniture_id = id
		position = pos
		rotation = rot

func _init(new_id: String, new_type_id: String):
	id = new_id
	room_type_id = new_type_id

func add_door(position: Vector2i, direction: int) -> void:
	doors.append(DoorPlacement.new(position, direction))
	placement_changed.emit()

func add_furniture(furniture_id: String, position: Vector2i, rotation: int = 0) -> void:
	furniture.append(FurniturePlacement.new(furniture_id, position, rotation))
	placement_changed.emit()

func get_furniture_count(furniture_id: String) -> int:
	var count = 0
	for furn in furniture:
		if furn.furniture_id == furniture_id:
			count += 1
	return count

func get_total_cost() -> int:
	var cost = 0
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room_type_id)
	if room_type:
		cost += room_type.base_cost
	
	cost += walls.size() * 10
	cost += doors.size() * 50
	
	var furniture_registry = FurnitureRegistry.get_instance()
	for furn in furniture:
		cost += furniture_registry.get_furniture_cost(furn.furniture_id)
	
	return cost

func get_monthly_upkeep() -> int:
	var upkeep = 0
	var furniture_registry = FurnitureRegistry.get_instance()
	
	for furn in furniture:
		var item = furniture_registry.get_furniture(furn.furniture_id)
		if item:
			upkeep += item.monthly_upkeep
	
	return upkeep
