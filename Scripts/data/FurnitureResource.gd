class_name FurnitureResource
extends Resource

@export var id: String
@export var name: String
@export var size: Vector2i = Vector2i(1, 1)
@export var cost: int = 0
@export var monthly_upkeep: int = 0
@export var description: String = ""
@export var sprite_path: String = ""

@export_group("Scene & Collision")
@export var scene_path: String = ""
@export var access_offsets: Array[Vector2i] = []  # Direction offsets like [(0, 1)] for south access - applied to each footprint tile
@export var preview_sprites: Dictionary = {}  # {"north": "...", "east": "...", "south": "...", "west": "..."}

func get_grid_footprint() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			tiles.append(Vector2i(x, y))
	return tiles

## Returns access tile offsets for placement, computed from footprint + rotated directions
## Rotation: 0=north, 1=east, 2=south, 3=west
func get_rotated_access_tiles(rotation: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []

	# Handle rotation - swap dimensions for 90/270 degree rotations
	var rotated_size = size
	if rotation == 1 or rotation == 3:
		rotated_size = Vector2i(size.y, size.x)

	# Get rotated footprint tiles
	var rotated_footprint: Array[Vector2i] = []
	for x in range(rotated_size.x):
		for y in range(rotated_size.y):
			rotated_footprint.append(Vector2i(x, y))

	# Apply each rotated direction offset to each footprint tile
	for dir_offset in access_offsets:
		var rotated_dir = _rotate_tile_offset(dir_offset, rotation)
		for fp_tile in rotated_footprint:
			var access_tile = fp_tile + rotated_dir
			if access_tile not in tiles:
				tiles.append(access_tile)

	return tiles

## Maps rotation (0-3) to directional preview sprite path
func get_preview_sprite_for_rotation(rotation: int) -> String:
	var direction_names = ["north", "east", "south", "west"]
	var direction = direction_names[rotation % 4]
	if preview_sprites.has(direction):
		return preview_sprites[direction]
	return ""

## Rotate a tile offset based on furniture rotation
## 0 (north): offset unchanged
## 1 (east): (x, y) -> (y, -x)
## 2 (south): (x, y) -> (-x, -y)
## 3 (west): (x, y) -> (-y, x)
func _rotate_tile_offset(offset: Vector2i, rotation: int) -> Vector2i:
	match rotation % 4:
		0:  # North - no rotation
			return offset
		1:  # East - 90 degrees CW
			return Vector2i(offset.y, -offset.x)
		2:  # South - 180 degrees
			return Vector2i(-offset.x, -offset.y)
		3:  # West - 270 degrees CW (90 CCW)
			return Vector2i(-offset.y, offset.x)
	return offset
