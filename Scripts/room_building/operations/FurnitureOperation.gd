class_name FurnitureOperation
extends RefCounted

func create_furniture_visual(placement: RoomInstance.FurniturePlacement, parent_node: Node2D, tilemap_layer: TileMapLayer = null) -> Node2D:
	var furn = placement.furniture
	var furniture_id = furn.id if furn else "unknown"

	# Try to use scene-based furniture if scene is assigned
	if furn and furn.scene:
		return _setup_furniture_instance(furn.scene.instantiate(), placement, parent_node, tilemap_layer)

	# Fallback to sprite-based visual
	var sprite_node = Sprite2D.new()
	sprite_node.name = "Furniture_%s_%d_%d" % [furniture_id, placement.position.x, placement.position.y]

	# Use sprite texture if available, otherwise create placeholder
	if furn and furn.sprite:
		sprite_node.texture = furn.sprite
	else:
		_create_placeholder_texture(sprite_node, furn, placement.rotation)

	# Position using tilemap's coordinate system for precise alignment
	sprite_node.position = _calculate_furniture_position(placement, furn, tilemap_layer)

	parent_node.add_child(sprite_node)
	return sprite_node

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

func _create_placeholder_texture(sprite: Sprite2D, furn: FurnitureResource, rotation: int = 0) -> void:
	# Create isometric placeholder with diamond-shaped tiles
	var size = Vector2i(1, 1)
	if furn:
		size = RotationHelper.get_rotated_size(furn.size, rotation)

	var texture = _create_isometric_placeholder(furn, size)
	sprite.texture = texture

## Generate placeholder sprites for all 4 directions
func generate_placeholder_sprites(furniture: FurnitureResource) -> Dictionary:
	var sprites = {}
	var direction_names = ["north", "east", "south", "west"]

	for rot in range(4):
		var size = RotationHelper.get_rotated_size(furniture.size, rot)
		var texture = _create_isometric_placeholder(furniture, size)
		sprites[direction_names[rot]] = texture

	return sprites

func _create_isometric_placeholder(furn: FurnitureResource, size: Vector2i) -> ImageTexture:
	# Calculate image size to fit isometric tiles
	var img_size = IsometricMath.get_isometric_image_size(size)
	var img = Image.create(img_size.x, img_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

	var furniture_id = furn.id if furn else "unknown"
	var color = _get_furniture_color(furniture_id)
	var border_color = color.darkened(0.3)

	# Draw diamond-shaped isometric tiles
	for tx in range(size.x):
		for ty in range(size.y):
			_draw_isometric_tile(img, tx, ty, size, color, border_color)

	return ImageTexture.create_from_image(img)

func _draw_isometric_tile(img: Image, tx: int, ty: int, total_size: Vector2i, fill_color: Color, border_color: Color) -> void:
	# Calculate center of this tile in image space
	var center = IsometricMath.get_tile_center_in_image(tx, ty, total_size)
	var half_h = int(IsometricMath.HALF_HEIGHT)
	var half_w = int(IsometricMath.HALF_WIDTH)

	# Draw filled diamond
	for dy in range(-half_h, half_h + 1):
		var width_at_y = int(half_w * (1.0 - abs(float(dy) / half_h)))
		for dx in range(-width_at_y, width_at_y + 1):
			var px = int(center.x + dx)
			var py = int(center.y + dy)
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				# Check if on border (edge of diamond)
				var is_border = abs(dx) >= width_at_y - 1 or abs(dy) >= half_h - 1
				img.set_pixel(px, py, border_color if is_border else fill_color)

func _get_furniture_color(furniture_id: String) -> Color:
	# Return different colors for different furniture types
	match furniture_id:
		"seat", "chair", "seating_bench":
			return Color(0.6, 0.4, 0.2, 0.8)  # Brown
		"screen":
			return Color(0.2, 0.2, 0.3, 0.8)  # Dark gray
		"counter":
			return Color(0.5, 0.4, 0.3, 0.8)  # Tan
		"ticket_window":
			return Color(0.3, 0.5, 0.6, 0.8)  # Teal
		"toilet", "sink":
			return Color(0.7, 0.7, 0.8, 0.8)  # Light gray
		_:
			return Color(0.5, 0.5, 0.5, 0.8)  # Default gray
