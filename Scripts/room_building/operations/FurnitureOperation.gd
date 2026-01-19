class_name FurnitureOperation
extends RefCounted

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

func create_furniture_visual(placement: RoomInstance.FurniturePlacement, parent_node: Node2D) -> Node2D:
	var furn = placement.furniture
	var furniture_id = furn.id if furn else "unknown"

	# Try to use scene-based furniture if scene_path is defined
	if furn and furn.scene_path != "" and ResourceLoader.exists(furn.scene_path):
		var scene = load(furn.scene_path) as PackedScene
		if scene:
			return _setup_furniture_instance(scene.instantiate(), placement, parent_node)

	# Fallback to sprite-based visual
	var sprite = Sprite2D.new()
	sprite.name = "Furniture_%s_%d_%d" % [furniture_id, placement.position.x, placement.position.y]

	# Try to load sprite from resource
	if furn and furn.sprite_path != "":
		var texture = load(furn.sprite_path)
		if texture:
			sprite.texture = texture
		else:
			_create_placeholder_texture(sprite, furn, placement.rotation)
	else:
		_create_placeholder_texture(sprite, furn, placement.rotation)

	# Position using isometric conversion - center multi-tile furniture
	var center_offset = Vector2i.ZERO
	if furn:
		var size = furn.size
		# Handle rotation - swap dimensions for 90/270 degree rotations
		if placement.rotation == 1 or placement.rotation == 3:
			size = Vector2i(size.y, size.x)
		# Calculate center of footprint
		center_offset = Vector2i(size.x / 2, size.y / 2)

	sprite.position = _tile_to_world(placement.position + center_offset)

	parent_node.add_child(sprite)
	return sprite

func _setup_furniture_instance(instance: Node, placement: RoomInstance.FurniturePlacement, parent_node: Node2D) -> Node2D:
	var furn = placement.furniture
	var furniture_id = furn.id if furn else "unknown"

	instance.name = "Furniture_%s_%d_%d" % [furniture_id, placement.position.x, placement.position.y]

	# If it's a FurnitureBase instance, use its setup method
	if instance is FurnitureBase:
		instance.setup_from_resource(furn, placement.position, placement.rotation)
	else:
		# Fallback positioning for non-FurnitureBase scenes
		var size = furn.size if furn else Vector2i(1, 1)
		if placement.rotation == 1 or placement.rotation == 3:
			size = Vector2i(size.y, size.x)
		var center_offset = Vector2i(size.x / 2, size.y / 2)
		instance.position = _tile_to_world(placement.position + center_offset)

	parent_node.add_child(instance)
	return instance

func _create_placeholder_texture(sprite: Sprite2D, furn: FurnitureResource, rotation: int = 0) -> void:
	# Create isometric placeholder with diamond-shaped tiles
	var size = Vector2i(1, 1)
	if furn:
		size = furn.size
		# Handle rotation - swap dimensions for 90/270 degree rotations
		if rotation == 1 or rotation == 3:
			size = Vector2i(size.y, size.x)

	var texture = _create_isometric_placeholder(furn, size)
	sprite.texture = texture

## Generate placeholder sprites for all 4 directions
func generate_placeholder_sprites(furniture: FurnitureResource) -> Dictionary:
	var sprites = {}
	var direction_names = ["north", "east", "south", "west"]

	for rot in range(4):
		var size = furniture.size
		if rot == 1 or rot == 3:
			size = Vector2i(size.y, size.x)
		var texture = _create_isometric_placeholder(furniture, size)
		sprites[direction_names[rot]] = texture

	return sprites

func _create_isometric_placeholder(furn: FurnitureResource, size: Vector2i) -> ImageTexture:
	# Calculate image size to fit isometric tiles
	# Each tile is 64x32, but they overlap in isometric layout
	var img_width = int((size.x + size.y) * HALF_WIDTH)
	var img_height = int((size.x + size.y) * HALF_HEIGHT) + int(HALF_HEIGHT)
	var img = Image.create(img_width, img_height, false, Image.FORMAT_RGBA8)
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
	# Origin is at top-left of image, tiles are drawn relative to top corner
	var center_x = (tx - ty) * HALF_WIDTH + (total_size.y) * HALF_WIDTH
	var center_y = (tx + ty) * HALF_HEIGHT + HALF_HEIGHT

	# Draw filled diamond
	for dy in range(-int(HALF_HEIGHT), int(HALF_HEIGHT) + 1):
		var width_at_y = int(HALF_WIDTH * (1.0 - abs(float(dy) / HALF_HEIGHT)))
		for dx in range(-width_at_y, width_at_y + 1):
			var px = int(center_x + dx)
			var py = int(center_y + dy)
			if px >= 0 and px < img.get_width() and py >= 0 and py < img.get_height():
				# Check if on border (edge of diamond)
				var is_border = abs(dx) >= width_at_y - 1 or abs(dy) >= int(HALF_HEIGHT) - 1
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

func _tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)
