class_name WallOperation
extends RefCounted

# Terrain configuration for auto-tiling
const TERRAIN_SET := 0  # Terrain set index in wall-tileset.tres
const TERRAIN_INDEX := 0  # Terrain index (wall type) within the set
const WALL_SOURCE_ID := 1  # "Classic Walls" source - only update tiles from this source

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

# Convert UI tile coordinates to tilemap tile coordinates (uses IsometricMath utility)
func _ui_to_tilemap_coords(ui_tile: Vector2i, tilemap_layer: TileMapLayer) -> Vector2i:
	return IsometricMath.ui_to_tilemap_coords(ui_tile, tilemap_layer)

func create_wall_visuals(room: RoomInstance, tilemap_layer: TileMapLayer) -> void:
	# Collect all wall positions (excluding doors) for terrain placement
	var wall_tilemap_positions: Array[Vector2i] = []

	for wall_pos in room.walls:
		var has_door = false
		for door in room.doors:
			if door.position == wall_pos:
				has_door = true
				break

		if not has_door:
			var tilemap_pos = _ui_to_tilemap_coords(wall_pos, tilemap_layer)
			wall_tilemap_positions.append(tilemap_pos)

	# Also include existing neighboring wall tiles so they update their connections
	var all_positions_to_update = wall_tilemap_positions.duplicate()
	_add_existing_wall_neighbors(wall_tilemap_positions, tilemap_layer, all_positions_to_update)

	# Erase existing tiles first, then place with terrain auto-tiling
	if all_positions_to_update.size() > 0:
		# Erase all affected tiles first to force terrain re-evaluation
		for pos in all_positions_to_update:
			tilemap_layer.erase_cell(pos)
		# Then place with terrain connect
		tilemap_layer.set_cells_terrain_connect(all_positions_to_update, TERRAIN_SET, TERRAIN_INDEX)


func _add_existing_wall_neighbors(positions: Array[Vector2i], tilemap_layer: TileMapLayer, result: Array[Vector2i]) -> void:
	# Use simple orthogonal offsets for tilemap coordinates (all 8 directions)
	var neighbor_offsets = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]

	for pos in positions:
		for offset in neighbor_offsets:
			var neighbor_pos = pos + offset
			# Skip if already in our list
			if neighbor_pos in result:
				continue
			# Check if this neighbor has an existing terrain tile (wall from another room)
			var tile_data = tilemap_layer.get_cell_tile_data(neighbor_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				result.append(neighbor_pos)
