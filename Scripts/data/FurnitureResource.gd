class_name FurnitureResource
extends Resource

@export var id: String
@export var name: String
@export var size: Vector2i = Vector2i(1, 1)
@export var cost: int = 0
@export var monthly_upkeep: int = 0
@export var description: String = ""
@export var sprite_path: String = ""

func get_grid_footprint() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			tiles.append(Vector2i(x, y))
	return tiles
