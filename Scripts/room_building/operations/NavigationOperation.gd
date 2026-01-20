class_name NavigationOperation
extends RefCounted

# Tileset source and atlas coordinates for WallTileLayer (TileSet_3dxm6)
const SOURCE_ID := 1  # "Classic Walls" source
const WALKABLE_TILE := Vector2i(0, 1)  # Floor tile with NavigationPolygon_20pc6 (walkable)
const WALL_TILE := Vector2i(0, 0)       # Wall tile with NavigationPolygon_03owx (blocking)

# Convert UI tile coordinates to tilemap tile coordinates (uses IsometricMath utility)
func _ui_to_tilemap_coords(ui_tile: Vector2i, tilemap: TileMapLayer) -> Vector2i:
	return IsometricMath.ui_to_tilemap_coords(ui_tile, tilemap)

func update_room_navigation(room: RoomInstance, tilemap: TileMapLayer) -> void:
	if not tilemap:
		push_warning("NavigationOperation: No tilemap provided")
		return

	var bbox = room.bounding_box

	# Place walkable tiles on interior (bounding_box minus walls)
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			var tilemap_pos = _ui_to_tilemap_coords(pos, tilemap)

			# Check if this is a wall position
			if pos in room.walls:
				# Check if this is a door position
				var is_door = false
				for door in room.doors:
					if door.position == pos:
						is_door = true
						break

				if is_door:
					# Doors are walkable
					tilemap.set_cell(tilemap_pos, SOURCE_ID, WALKABLE_TILE)
				else:
					# Walls are not walkable (tile already set by WallOperation)
					pass
			else:
				# Interior tiles are walkable
				tilemap.set_cell(tilemap_pos, SOURCE_ID, WALKABLE_TILE)

func clear_room_navigation(room: RoomInstance, tilemap: TileMapLayer) -> void:
	if not tilemap:
		return

	var bbox = room.bounding_box

	# Clear all tiles in the room's bounding box
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			var tilemap_pos = _ui_to_tilemap_coords(pos, tilemap)
			tilemap.erase_cell(tilemap_pos)
