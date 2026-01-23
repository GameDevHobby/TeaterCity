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

	func to_dict() -> Dictionary:
		return {
			"position": {"x": position.x, "y": position.y},
			"direction": direction
		}

	static func from_dict(data: Dictionary) -> DoorPlacement:
		var pos = Vector2i(data.position.x, data.position.y)
		return DoorPlacement.new(pos, data.direction)

class FurniturePlacement:
	var furniture: FurnitureResource
	var position: Vector2i
	var rotation: int

	func _init(furn: FurnitureResource, pos: Vector2i, rot: int = 0):
		furniture = furn
		position = pos
		rotation = rot

	func to_dict() -> Dictionary:
		return {
			"furniture_id": furniture.id if furniture else "",
			"position": {"x": position.x, "y": position.y},
			"rotation": rotation
		}

	static func from_dict(data: Dictionary) -> FurniturePlacement:
		var pos = Vector2i(data.position.x, data.position.y)
		var furn_id = data.get("furniture_id", "")
		var furn: FurnitureResource = null
		if furn_id != "":
			furn = FurnitureRegistry.get_instance().get_furniture(furn_id)
		var rot = data.get("rotation", 0)
		return FurniturePlacement.new(furn, pos, rot)

	func get_occupied_tiles() -> Array[Vector2i]:
		if not furniture:
			var tiles: Array[Vector2i] = []
			tiles.append(position)
			return tiles

		return RotationHelper.get_footprint_tiles(position, furniture.size, rotation)

	func get_access_tiles() -> Array[Vector2i]:
		var tiles: Array[Vector2i] = []
		if not furniture:
			return tiles

		# Get rotated access tiles and apply position offset
		var rotated_offsets = furniture.get_rotated_access_tiles(rotation)
		for offset in rotated_offsets:
			tiles.append(position + offset)
		return tiles

func _init(new_id: String, new_type_id: String):
	id = new_id
	room_type_id = new_type_id

func add_door(position: Vector2i, direction: int) -> void:
	doors.append(DoorPlacement.new(position, direction))
	placement_changed.emit()

func add_furniture(furn: FurnitureResource, position: Vector2i, rotation: int = 0) -> void:
	furniture.append(FurniturePlacement.new(furn, position, rotation))
	placement_changed.emit()

func get_furniture_count_by_resource(furn: FurnitureResource) -> int:
	var count = 0
	for f in furniture:
		if f.furniture and f.furniture == furn:
			count += 1
	return count

func get_furniture_count(furniture_id: String) -> int:
	var count = 0
	for furn in furniture:
		if furn.furniture and furn.furniture.id == furniture_id:
			count += 1
	return count

func is_tile_occupied(pos: Vector2i) -> bool:
	for furn in furniture:
		if pos in furn.get_occupied_tiles():
			return true
		# Also check access tiles - they need to stay clear
		if pos in furn.get_access_tiles():
			return true
	return false

func get_all_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for furn in furniture:
		for tile in furn.get_occupied_tiles():
			if tile not in tiles:
				tiles.append(tile)
		for tile in furn.get_access_tiles():
			if tile not in tiles:
				tiles.append(tile)
	return tiles

func get_total_cost() -> int:
	var cost = 0
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room_type_id)
	if room_type:
		cost += room_type.base_cost

	cost += walls.size() * 10
	cost += doors.size() * 50

	for furn in furniture:
		if furn.furniture:
			cost += furn.furniture.cost

	return cost

func get_monthly_upkeep() -> int:
	var upkeep = 0

	for furn in furniture:
		if furn.furniture:
			upkeep += furn.furniture.monthly_upkeep

	return upkeep

func to_dict() -> Dictionary:
	var doors_arr: Array = []
	for door in doors:
		doors_arr.append(door.to_dict())

	var furniture_arr: Array = []
	for furn in furniture:
		furniture_arr.append(furn.to_dict())

	var walls_arr: Array = []
	for wall in walls:
		walls_arr.append({"x": wall.x, "y": wall.y})

	return {
		"id": id,
		"room_type_id": room_type_id,
		"bounding_box": {
			"x": bounding_box.position.x,
			"y": bounding_box.position.y,
			"width": bounding_box.size.x,
			"height": bounding_box.size.y
		},
		"walls": walls_arr,
		"doors": doors_arr,
		"furniture": furniture_arr
	}

static func from_dict(data: Dictionary) -> RoomInstance:
	var room = RoomInstance.new(data.id, data.room_type_id)

	# Restore bounding_box
	var bbox = data.bounding_box
	room.bounding_box = Rect2i(bbox.x, bbox.y, bbox.width, bbox.height)

	# Restore walls
	room.walls = []
	for wall_data in data.get("walls", []):
		room.walls.append(Vector2i(wall_data.x, wall_data.y))

	# Restore doors
	room.doors = []
	for door_data in data.get("doors", []):
		room.doors.append(DoorPlacement.from_dict(door_data))

	# Restore furniture
	room.furniture = []
	for furn_data in data.get("furniture", []):
		room.furniture.append(FurniturePlacement.from_dict(furn_data))

	return room
