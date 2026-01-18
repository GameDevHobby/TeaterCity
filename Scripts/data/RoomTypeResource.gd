class_name RoomTypeResource
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var min_size: Vector2i
@export var max_size: Vector2i
@export var has_seating: bool = false
@export var has_walls: bool = true
@export var door_count_min: int = 1
@export var door_count_max: int = 2
@export var base_cost: int = 0
@export var allowed_furniture: Array[FurnitureResource] = []
@export var required_furniture: Array[FurnitureRequirement] = []

func get_required_furniture() -> Array[FurnitureRequirement]:
	return required_furniture
