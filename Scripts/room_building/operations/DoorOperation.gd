class_name DoorOperation
extends RefCounted

func is_valid_door_position(position: Vector2i, room: RoomInstance) -> bool:
	if position not in room.walls:
		return false
	
	var neighbors = 0
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if (position + dir) in room.walls:
			neighbors += 1
	
	return neighbors >= 2 and neighbors <= 3

func determine_door_direction(position: Vector2i, room: RoomInstance) -> int:
	var bbox = room.bounding_box
	
	if position.y == bbox.position.y:
		return 0
	elif position.x == bbox.position.x + bbox.size.x - 1:
		return 1
	elif position.y == bbox.position.y + bbox.size.y - 1:
		return 2
	else:
		return 3

func create_door_visuals(door: RoomInstance.DoorPlacement, tilemap_layer: TileMapLayer) -> void:
	tilemap_layer.set_cell(door.position, 0, Vector2i(2, 0))
