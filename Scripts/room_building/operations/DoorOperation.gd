class_name DoorOperation
extends RefCounted

# Tileset source and atlas coordinates for WallTileLayer
const SOURCE_ID := 1  # "Classic Walls" source
const DOOR_TILE := Vector2i(0, 1)  # Walkable tile (doors are passable)

# Terrain configuration (must match WallOperation)
const TERRAIN_SET := 0
const TERRAIN_INDEX := 0

# UI coordinate system constants (must match RoomBuildUI)
const HALF_WIDTH := 32.0
const HALF_HEIGHT := 16.0

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

# Convert UI tile coordinates to world position (must match RoomBuildUI._tile_to_world)
func _ui_tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
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

func create_door_visuals(door: RoomInstance.DoorPlacement, tilemap_layer: TileMapLayer) -> void:
	var tilemap_pos = _ui_to_tilemap_coords(door.position, tilemap_layer)

	# Place the door tile (non-terrain, just a walkable tile)
	tilemap_layer.set_cell(tilemap_pos, SOURCE_ID, DOOR_TILE)

	# Update neighboring wall tiles to refresh their terrain connections
	_update_neighbor_terrain(tilemap_pos, tilemap_layer)


func _update_neighbor_terrain(center_pos: Vector2i, tilemap_layer: TileMapLayer) -> void:
	# Use simple orthogonal offsets for tilemap coordinates
	var neighbor_offsets = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]
	var wall_neighbors: Array[Vector2i] = []

	# First pass: get immediate neighbors (all 8 directions)
	for offset in neighbor_offsets:
		var neighbor_pos = center_pos + offset
		var tile_data = tilemap_layer.get_cell_tile_data(neighbor_pos)
		if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
			wall_neighbors.append(neighbor_pos)

	# Second pass: also get neighbors of neighbors (for terrain propagation)
	var extended_neighbors: Array[Vector2i] = wall_neighbors.duplicate()
	for wall_pos in wall_neighbors:
		for offset in neighbor_offsets:
			var neighbor_pos = wall_pos + offset
			if neighbor_pos in extended_neighbors or neighbor_pos == center_pos:
				continue
			var tile_data = tilemap_layer.get_cell_tile_data(neighbor_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				extended_neighbors.append(neighbor_pos)

	# Erase and re-apply terrain to force update
	if extended_neighbors.size() > 0:
		# First erase all affected tiles
		for pos in extended_neighbors:
			tilemap_layer.erase_cell(pos)
		# Then re-place with terrain connect
		tilemap_layer.set_cells_terrain_connect(extended_neighbors, TERRAIN_SET, TERRAIN_INDEX)
