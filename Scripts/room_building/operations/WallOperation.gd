class_name WallOperation
extends RefCounted

# Tileset source and atlas coordinates for WallTileLayer
const WALL_SOURCE_ID := 1  # "Classic Walls" source in TileSet_3dxm6
const WALL_ATLAS_COORDS := Vector2i(0, 0)  # Basic wall tile

# UI coordinate system constants (must match RoomBuildUI)
const HALF_WIDTH := 32.0
const HALF_HEIGHT := 16.0

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

# Convert UI tile coordinates to world position (must match RoomBuildUI._tile_to_world)
func _ui_tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		((tile_pos.x + tile_pos.y) * HALF_HEIGHT) + HALF_HEIGHT
	)

# Convert UI tile coordinates to tilemap tile coordinates
func _ui_to_tilemap_coords(ui_tile: Vector2i, tilemap_layer: TileMapLayer) -> Vector2i:
	# Double the offset to shift tiles down-right to correct position
	var world_pos = Vector2(
		(ui_tile.x - ui_tile.y) * HALF_WIDTH,
		(ui_tile.x + ui_tile.y) * HALF_HEIGHT + 2 * HALF_HEIGHT
	)
	var local_pos = tilemap_layer.to_local(world_pos)
	return tilemap_layer.local_to_map(local_pos)

func create_wall_visuals(room: RoomInstance, tilemap_layer: TileMapLayer) -> void:
	for wall_pos in room.walls:
		var has_door = false
		for door in room.doors:
			if door.position == wall_pos:
				has_door = true
				break

		if not has_door:
			# Convert UI tile coords to tilemap tile coords
			var tilemap_pos = _ui_to_tilemap_coords(wall_pos, tilemap_layer)
			tilemap_layer.set_cell(tilemap_pos, WALL_SOURCE_ID, WALL_ATLAS_COORDS)
