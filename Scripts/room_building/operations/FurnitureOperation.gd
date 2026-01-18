class_name FurnitureOperation
extends RefCounted

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

func create_furniture_visual(placement: RoomInstance.FurniturePlacement, parent_node: Node2D) -> Node2D:
	var furniture_registry = FurnitureRegistry.get_instance()
	var furn = furniture_registry.get_furniture(placement.furniture_id)

	# Create sprite for the furniture
	var sprite = Sprite2D.new()
	sprite.name = "Furniture_%s_%d_%d" % [placement.furniture_id, placement.position.x, placement.position.y]

	# Try to load sprite from resource
	if furn and furn.sprite_path != "":
		var texture = load(furn.sprite_path)
		if texture:
			sprite.texture = texture
		else:
			_create_placeholder_texture(sprite, placement.furniture_id, furn)
	else:
		_create_placeholder_texture(sprite, placement.furniture_id, furn)

	# Position using isometric conversion
	sprite.position = _tile_to_world(placement.position)

	# Apply rotation
	sprite.rotation_degrees = placement.rotation * 90.0

	parent_node.add_child(sprite)
	return sprite

func _create_placeholder_texture(sprite: Sprite2D, furniture_id: String, furn: FurnitureResource) -> void:
	# Create a placeholder colored rectangle
	var size = Vector2i(1, 1)
	if furn:
		size = furn.size

	# Create a simple image as placeholder
	var img_size = Vector2i(int(TILE_WIDTH * size.x), int(TILE_HEIGHT * size.y))
	var img = Image.create(img_size.x, img_size.y, false, Image.FORMAT_RGBA8)

	# Choose color based on furniture type
	var color = _get_furniture_color(furniture_id)
	img.fill(color)

	# Add a border
	var border_color = color.darkened(0.3)
	for x in range(img_size.x):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, img_size.y - 1, border_color)
	for y in range(img_size.y):
		img.set_pixel(0, y, border_color)
		img.set_pixel(img_size.x - 1, y, border_color)

	var texture = ImageTexture.create_from_image(img)
	sprite.texture = texture

func _get_furniture_color(furniture_id: String) -> Color:
	# Return different colors for different furniture types
	match furniture_id:
		"seat", "chair":
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

func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)
