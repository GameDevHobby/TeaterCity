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

	# Get rotated footprint tiles (at origin position Vector2i.ZERO)
	var rotated_footprint = RotationHelper.get_footprint_tiles(Vector2i.ZERO, size, rotation)

	# Apply each rotated direction offset to each footprint tile
	for dir_offset in access_offsets:
		var rotated_dir = RotationHelper.rotate_tile_offset(dir_offset, rotation)
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
