class_name DoorOperation
extends RefCounted

# Tileset source and atlas coordinates for WallTileLayer
const SOURCE_ID := 1  # "Classic Walls" source
const DOOR_TILE := Vector2i(0, 1)  # Walkable tile (doors are passable)

# Terrain configuration (must match WallOperation)
const TERRAIN_SET := 0
const TERRAIN_INDEX := 0

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

# Convert UI tile coordinates to tilemap tile coordinates (uses IsometricMath utility)
func _ui_to_tilemap_coords(ui_tile: Vector2i, tilemap_layer: TileMapLayer) -> Vector2i:
	return IsometricMath.ui_to_tilemap_coords(ui_tile, tilemap_layer)

## Validate door removal
## Returns Dictionary with { can_remove: bool, reason: String }
func can_remove_door(room: RoomInstance) -> Dictionary:
	var result = { "can_remove": true, "reason": "" }

	# Check room type minimum door count
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type:
		var min_doors = room_type.door_count_min if room_type.door_count_min > 0 else 1
		if room.doors.size() <= min_doors:
			result.can_remove = false
			result.reason = "Minimum %d door(s) required" % min_doors
			return result

	return result


## Validate door placement for edit mode (stricter than build mode)
## Returns Dictionary with { can_place: bool, reason: String }
func can_place_door_edit(position: Vector2i, room: RoomInstance) -> Dictionary:
	var result = { "can_place": true, "reason": "" }

	# Check if position is valid wall tile (2-3 neighbors)
	if not is_valid_door_position(position, room):
		result.can_place = false
		result.reason = "Invalid wall position for door"
		return result

	# Check if door already exists at this position
	for door in room.doors:
		if door.position == position:
			result.can_place = false
			result.reason = "Door already exists here"
			return result

	# Check room type maximum door count
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type and room_type.door_count_max > 0:
		if room.doors.size() >= room_type.door_count_max:
			result.can_place = false
			result.reason = "Maximum %d door(s) reached" % room_type.door_count_max
			return result

	# Check adjacent tile (outside door) for other rooms
	var direction = determine_door_direction(position, room)
	var outside_tile = _get_outside_tile(position, direction)

	if RoomManager.is_tile_in_another_room(outside_tile, room):
		result.can_place = false
		result.reason = "Cannot place door into adjacent room"
		return result

	return result


## Get the tile position outside the door based on direction
func _get_outside_tile(door_pos: Vector2i, direction: int) -> Vector2i:
	# Direction: 0=North, 1=East, 2=South, 3=West
	match direction:
		0: return door_pos + Vector2i(0, -1)  # North: outside is y-1
		1: return door_pos + Vector2i(1, 0)   # East: outside is x+1
		2: return door_pos + Vector2i(0, 1)   # South: outside is y+1
		3: return door_pos + Vector2i(-1, 0)  # West: outside is x-1
	return door_pos


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
