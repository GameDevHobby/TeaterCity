class_name WallOperation
extends RefCounted

func generate_walls(bounding_box: Rect2i) -> Array[Vector2i]:
	var walls: Array[Vector2i] = []
	
	var x_min = bounding_box.position.x
	var x_max = bounding_box.position.x + bounding_box.size.x - 1
	var y_min = bounding_box.position.y
	var y_max = bounding_box.position.y + bounding_box.size.y - 1
	
	for x in range(x_min, x_max + 1):
		walls.append(Vector2i(x, y_min))
		walls.append(Vector2i(x, y_max))
	
	for y in range(y_min + 1, y_max):
		walls.append(Vector2i(x_min, y))
		walls.append(Vector2i(x_max, y))
	
	return walls

func create_wall_visuals(room: RoomInstance, tilemap_layer: TileMapLayer) -> void:
	for wall_pos in room.walls:
		var has_door = false
		for door in room.doors:
			if door.position == wall_pos:
				has_door = true
				break
		
		if not has_door:
			tilemap_layer.set_cell(wall_pos, 0, Vector2i(1, 0))
