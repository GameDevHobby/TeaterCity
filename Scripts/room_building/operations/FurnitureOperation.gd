class_name FurnitureOperation
extends RefCounted

func create_furniture_visual(placement: RoomInstance.FurniturePlacement, parent_node: Node2D, tilemap_layer: TileMapLayer = null) -> Node2D:
	var furn = placement.furniture
	var furniture_id = furn.id if furn else "unknown"

	# Clear tiles from tilemap where furniture is placed (removes navigation mesh)
	if tilemap_layer:
		_clear_furniture_tiles(placement, tilemap_layer)

	# Use scene-based furniture (required - no fallback)
	if furn and furn.scene:
		var instance = _setup_furniture_instance(furn.scene.instantiate(), placement, parent_node, tilemap_layer)
		placement.visual_node = instance
		return instance

	# No scene assigned - create empty placeholder node
	push_warning("Furniture '%s' has no scene assigned" % furniture_id)
	var placeholder = Node2D.new()
	placeholder.name = "Furniture_%s_%d_%d" % [furniture_id, placement.position.x, placement.position.y]
	placeholder.position = _calculate_furniture_position(placement, furn, tilemap_layer)
	parent_node.add_child(placeholder)
	placement.visual_node = placeholder
	return placeholder

func _setup_furniture_instance(instance: Node, placement: RoomInstance.FurniturePlacement, parent_node: Node2D, tilemap_layer: TileMapLayer = null) -> Node2D:
	var furn = placement.furniture
	var furniture_id = furn.id if furn else "unknown"

	instance.name = "Furniture_%s_%d_%d" % [furniture_id, placement.position.x, placement.position.y]

	# If it's a FurnitureBase instance, use its setup method
	if instance is FurnitureBase:
		instance.setup_from_resource(furn, placement.position, placement.rotation, tilemap_layer)
	else:
		# Fallback positioning for non-FurnitureBase scenes
		instance.position = _calculate_furniture_position(placement, furn, tilemap_layer)

	parent_node.add_child(instance)
	return instance

func _calculate_furniture_position(placement: RoomInstance.FurniturePlacement, furn: FurnitureResource, _tilemap_layer: TileMapLayer) -> Vector2:
	var center_offset = Vector2.ZERO
	if furn:
		center_offset = RotationHelper.get_center_offset(furn.size, placement.rotation)

	var tile_pos = Vector2(placement.position) + center_offset
	return IsometricMath.tile_to_world_float(tile_pos)

## Clear tiles from tilemap where furniture occupies (removes navigation mesh from those tiles)
func _clear_furniture_tiles(placement: RoomInstance.FurniturePlacement, tilemap_layer: TileMapLayer) -> void:
	var occupied_tiles = placement.get_occupied_tiles()
	for tile in occupied_tiles:
		tilemap_layer.erase_cell(tile)
