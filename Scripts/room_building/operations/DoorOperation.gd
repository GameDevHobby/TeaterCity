class_name DoorOperation
extends RefCounted

# Tileset source and atlas coordinates for WallTileLayer (TileSet_3dxm6)
const SOURCE_ID := 1  # "Classic Walls" source
const DOOR_TILE := Vector2i(0, 1)  # Walkable tile (doors are passable)

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
	var world_pos = _ui_tile_to_world(ui_tile)
	var local_pos = tilemap_layer.to_local(world_pos)
	return tilemap_layer.local_to_map(local_pos)

func create_door_visuals(door: RoomInstance.DoorPlacement, tilemap_layer: TileMapLayer) -> void:
	var tilemap_pos = _ui_to_tilemap_coords(door.position, tilemap_layer)
	tilemap_layer.set_cell(tilemap_pos, SOURCE_ID, DOOR_TILE)
