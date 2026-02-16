class_name RoomSelectionArea
extends Area2D

@export var collision_polygon: CollisionPolygon2D


func set_selection_polygon(polygon: PackedVector2Array) -> void:
	if collision_polygon == null:
		push_error("RoomSelectionArea: collision_polygon is not assigned")
		return
	collision_polygon.polygon = polygon
