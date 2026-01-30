class_name DeletionOperation
extends RefCounted

## Stateless operation for room deletion logic.
## Handles shared wall detection and visual cleanup in correct sequence.

# Reuse terrain configuration from WallOperation
const TERRAIN_SET := 0
const TERRAIN_INDEX := 0


## Get wall tiles that are NOT shared with other rooms.
## Only these tiles should be erased from the tilemap.
## A wall is shared if it exists in BOTH this room's walls array AND another room's walls array.
func get_non_shared_walls(room: RoomInstance, room_manager: Node) -> Array[Vector2i]:
	var non_shared: Array[Vector2i] = []

	for wall_pos in room.walls:
		var is_shared := false

		# Check if this wall tile is also in any OTHER room's walls array
		for other_room in room_manager.get_all_rooms():
			if other_room == room:
				continue

			# Check if this exact wall position is in the other room's walls
			if wall_pos in other_room.walls:
				is_shared = true
				break

		if not is_shared:
			non_shared.append(wall_pos)

	return non_shared


## Delete all wall tiles for a room (only non-shared tiles).
## Call AFTER navigation and furniture cleanup.
func delete_wall_visuals(room: RoomInstance, wall_tilemap: TileMapLayer, room_manager: Node) -> void:
	var non_shared_walls = get_non_shared_walls(room, room_manager)

	for wall_pos in non_shared_walls:
		var tilemap_pos = IsometricMath.ui_to_tilemap_coords(wall_pos, wall_tilemap)
		wall_tilemap.erase_cell(tilemap_pos)

	# Update neighboring terrain tiles so they reconnect properly
	_update_neighbor_terrain(non_shared_walls, wall_tilemap)


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
## Only restores tiles that were actually deleted (non-shared walls and interior).
func restore_room_floor_tiles(room: RoomInstance, wall_tilemap: TileMapLayer, room_manager: Node) -> void:
	const SOURCE_ID := 1
	const WALKABLE_TILE := Vector2i(0, 1)

	var bbox = room.bounding_box
	var non_shared_walls = get_non_shared_walls(room, room_manager)

	# Restore floor tiles for:
	# 1. Interior tiles (not in walls array)
	# 2. Non-shared wall tiles that were deleted
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)

			# Check if this was an interior tile or a deleted wall tile
			var was_interior = pos not in room.walls
			var was_deleted_wall = pos in non_shared_walls

			if was_interior or was_deleted_wall:
				var tilemap_pos = IsometricMath.ui_to_tilemap_coords(pos, wall_tilemap)
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
