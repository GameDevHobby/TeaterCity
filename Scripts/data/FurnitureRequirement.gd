class_name FurnitureRequirement
extends Resource

@export var furniture: FurnitureResource
@export var count: int = 1

func _init(furn: FurnitureResource = null, cnt: int = 1) -> void:
	furniture = furn
	count = cnt
