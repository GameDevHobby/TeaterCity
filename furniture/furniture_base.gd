class_name FurnitureBase
extends StaticBody2D

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

@export var furniture_resource: FurnitureResource

var tile_position: Vector2i
var furniture_rotation: int

func setup_from_resource(resource: FurnitureResource, pos: Vector2i, rot: int) -> void:
	furniture_resource = resource
	tile_position = pos
	furniture_rotation = rot

	# Configure collision layer (layer 1 for furniture, patrons have mask 3)
	collision_layer = 1
	collision_mask = 0  # Furniture doesn't need to detect collisions

	# Position in isometric space
	var size = resource.size
	if rot == 1 or rot == 3:
		size = Vector2i(size.y, size.x)

	# Calculate center of footprint for positioning
	var center_offset = Vector2i(size.x / 2, size.y / 2)
	position = _tile_to_world(pos + center_offset)

	# Configure collision shape if we have one
	_setup_collision_shape(size)

func _setup_collision_shape(size: Vector2i) -> void:
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		# Size based on isometric tile footprint
		rect_shape.size = Vector2(size.x * HALF_WIDTH, size.y * HALF_HEIGHT)

func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)

## Get the tiles that need to be accessible for patrons to use this furniture
func get_access_tiles() -> Array[Vector2i]:
	if furniture_resource:
		var rotated_access = furniture_resource.get_rotated_access_tiles(furniture_rotation)
		var world_access: Array[Vector2i] = []
		for offset in rotated_access:
			world_access.append(tile_position + offset)
		return world_access
	return []
