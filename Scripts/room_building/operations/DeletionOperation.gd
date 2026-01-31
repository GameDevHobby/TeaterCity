class_name DeletionOperation
extends RefCounted

## Stateless operation for room deletion logic.
## Handles shared wall detection and visual cleanup in correct sequence.

# Reuse terrain configuration from WallOperation
const TERRAIN_SET := 0
const TERRAIN_INDEX := 0


## Get wall tiles that can be safely deleted.
## A wall is deletable if:
## 1. It's not shared with another room (not in any other room's walls array)
## 2. It's not connected to exterior walls (walls outside the room that exist in tilemap)
func get_deletable_walls(room: RoomInstance, room_manager: Node, wall_tilemap: TileMapLayer) -> Array[Vector2i]:
	var deletable: Array[Vector2i] = []

	for wall_pos in room.walls:
		# Check 1: Is this wall shared with another room?
		var is_shared := false
		for other_room in room_manager.get_all_rooms():
			if other_room == room:
				continue
			if wall_pos in other_room.walls:
				is_shared = true
				break

		if is_shared:
			continue  # Don't delete shared walls

		# Check 2: Is this wall connected to an exterior wall?
		# (a wall tile OUTSIDE the room's bounding box)
		var is_connected_to_exterior := _is_connected_to_exterior(wall_pos, room, wall_tilemap)

		if is_connected_to_exterior:
			continue  # Don't delete walls connected to exterior

		deletable.append(wall_pos)

	return deletable


## Check if a wall position is connected to walls outside the room's bounding box.
## If there's a wall tile adjacent to this position that's outside the room, it's exterior.
func _is_connected_to_exterior(wall_pos: Vector2i, room: RoomInstance, tilemap: TileMapLayer) -> bool:
	var bbox = room.bounding_box
	var neighbor_offsets = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)
	]

	for offset in neighbor_offsets:
		var neighbor_pos = wall_pos + offset

		# Check if neighbor is OUTSIDE the room's bounding box
		var outside_x = neighbor_pos.x < bbox.position.x or neighbor_pos.x >= bbox.position.x + bbox.size.x
		var outside_y = neighbor_pos.y < bbox.position.y or neighbor_pos.y >= bbox.position.y + bbox.size.y

		if outside_x or outside_y:
			# Neighbor is outside room - check if it has a wall tile in the tilemap
			var tilemap_pos = IsometricMath.ui_to_tilemap_coords(neighbor_pos, tilemap)
			var tile_data = tilemap.get_cell_tile_data(tilemap_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				# There's a wall outside the room boundary - this is exterior
				return true

	return false


## Delete all wall tiles for a room (only safely deletable tiles).
## Call AFTER furniture cleanup.
func delete_wall_visuals(room: RoomInstance, wall_tilemap: TileMapLayer, room_manager: Node) -> void:
	var deletable_walls = get_deletable_walls(room, room_manager, wall_tilemap)

	for wall_pos in deletable_walls:
		var tilemap_pos = IsometricMath.ui_to_tilemap_coords(wall_pos, wall_tilemap)
		wall_tilemap.erase_cell(tilemap_pos)

	# Update neighboring terrain tiles so they reconnect properly
	_update_neighbor_terrain(deletable_walls, wall_tilemap)


## Delete all furniture visuals for a room.
## Uses FurniturePlacement.cleanup_visual() which handles null checks and queue_free().
func delete_furniture_visuals(room: RoomInstance) -> void:
	for furn in room.furniture:
		furn.cleanup_visual()


## Delete door visuals by reverting them to wall tiles.
## This is effectively a no-op since we delete walls anyway, but keeps doors from
## appearing during cleanup if wall deletion is animated in the future.
func delete_door_visuals(room: RoomInstance, wall_tilemap: TileMapLayer) -> void:
	for door in room.doors:
		var tilemap_pos = IsometricMath.ui_to_tilemap_coords(door.position, wall_tilemap)
		wall_tilemap.erase_cell(tilemap_pos)


## Restore ground/floor tiles where furniture was placed.
## Furniture erases ground tiles for navigation; deletion should restore them.
func restore_furniture_ground_tiles(room: RoomInstance, ground_tilemap: TileMapLayer) -> void:
	# Get all tiles that were occupied by furniture (footprint + access tiles)
	var tiles_to_restore: Array[Vector2i] = []
	for furn in room.furniture:
		for tile in furn.get_occupied_tiles():
			if tile not in tiles_to_restore:
				tiles_to_restore.append(tile)

	# Use NavigationOperation constants for walkable tile
	const SOURCE_ID := 1
	const WALKABLE_TILE := Vector2i(0, 1)

	for tile in tiles_to_restore:
		var tilemap_pos = IsometricMath.ui_to_tilemap_coords(tile, ground_tilemap)
		ground_tilemap.set_cell(tilemap_pos, SOURCE_ID, WALKABLE_TILE)


## Restore walkable floor tiles for the entire room area after deletion.
## This makes the deleted room area navigable again.
## Only restores tiles that were actually deleted (deletable walls and interior).
## Does NOT restore floor tiles where walls still exist (shared or exterior walls).
func restore_room_floor_tiles(room: RoomInstance, wall_tilemap: TileMapLayer, room_manager: Node) -> void:
	const SOURCE_ID := 1
	const WALKABLE_TILE := Vector2i(0, 1)

	var bbox = room.bounding_box
	var deletable_walls = get_deletable_walls(room, room_manager, wall_tilemap)

	# Restore floor tiles for:
	# 1. Interior tiles (not in walls array)
	# 2. Wall tiles that were actually deleted
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			var tilemap_pos = IsometricMath.ui_to_tilemap_coords(pos, wall_tilemap)

			# Skip if there's still a wall tile here (shared or exterior)
			var tile_data = wall_tilemap.get_cell_tile_data(tilemap_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				continue  # Don't overwrite existing walls

			# Check if this was an interior tile or a deleted wall tile
			var was_interior = pos not in room.walls
			var was_deleted_wall = pos in deletable_walls

			if was_interior or was_deleted_wall:
				wall_tilemap.set_cell(tilemap_pos, SOURCE_ID, WALKABLE_TILE)


func _update_neighbor_terrain(deleted_positions: Array[Vector2i], tilemap_layer: TileMapLayer) -> void:
	if deleted_positions.is_empty():
		return

	# Collect all neighboring wall tiles that need terrain update
	var neighbor_offsets = [
		Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
	]

	var walls_to_update: Array[Vector2i] = []

	for deleted_pos in deleted_positions:
		var tilemap_pos = IsometricMath.ui_to_tilemap_coords(deleted_pos, tilemap_layer)
		for offset in neighbor_offsets:
			var neighbor_pos = tilemap_pos + offset
			# Check if neighbor has a terrain tile (wall from another room)
			var tile_data = tilemap_layer.get_cell_tile_data(neighbor_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				if neighbor_pos not in walls_to_update:
					walls_to_update.append(neighbor_pos)

	# Re-apply terrain to update connections
	if walls_to_update.size() > 0:
		for pos in walls_to_update:
			tilemap_layer.erase_cell(pos)
		tilemap_layer.set_cells_terrain_connect(walls_to_update, TERRAIN_SET, TERRAIN_INDEX)
