class_name CollisionOperation
extends RefCounted

class CollisionResult:
	var can_place: bool = true
	var blocked_tiles: Array[Vector2i] = []

class PreviewResult:
	var tiles: Array[Vector2i] = []
	var valid_tiles: Array[Vector2i] = []
	var blocked_tiles: Array[Vector2i] = []

func can_place_furniture(furniture: FurnitureResource, position: Vector2i,
						rotation: int, room: RoomInstance) -> CollisionResult:
	var result = CollisionResult.new()
	var tiles = _get_footprint_tiles(furniture, position, rotation)

	for tile in tiles:
		if not _is_tile_valid(tile, room):
			result.can_place = false
			result.blocked_tiles.append(tile)

	return result

func get_placement_preview(furniture: FurnitureResource, position: Vector2i,
						  rotation: int, room: RoomInstance) -> PreviewResult:
	var result = PreviewResult.new()
	result.tiles = _get_footprint_tiles(furniture, position, rotation)

	for tile in result.tiles:
		if _is_tile_valid(tile, room):
			result.valid_tiles.append(tile)
		else:
			result.blocked_tiles.append(tile)

	return result

func _get_footprint_tiles(furniture: FurnitureResource, position: Vector2i,
						 rotation: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if not furniture:
		tiles.append(position)
		return tiles

	var size = furniture.size
	# Handle rotation - swap dimensions for 90/270 degree rotations
	if rotation == 1 or rotation == 3:
		size = Vector2i(size.y, size.x)

	for x in range(size.x):
		for y in range(size.y):
			tiles.append(position + Vector2i(x, y))
	return tiles

func _is_tile_valid(pos: Vector2i, room: RoomInstance) -> bool:
	if not room:
		return false

	var bbox = room.bounding_box
	var in_bounds = pos.x >= bbox.position.x and pos.x < bbox.position.x + bbox.size.x
	in_bounds = in_bounds and pos.y >= bbox.position.y and pos.y < bbox.position.y + bbox.size.y

	if not in_bounds:
		return false

	if pos in room.walls:
		return false

	if room.is_tile_occupied(pos):
		return false

	return true
