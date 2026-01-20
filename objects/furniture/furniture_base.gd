class_name FurnitureBase
extends StaticBody2D

@export var furniture_resource: FurnitureResource

var _tile_position: Vector2i
var _furniture_rotation: int

func setup_from_resource(resource: FurnitureResource, pos: Vector2i, rot: int, _tilemap_layer: TileMapLayer = null) -> void:
	furniture_resource = resource
	_tile_position = pos
	_furniture_rotation = rot

	# Configure collision layer (layer 1 for furniture, patrons have mask 3)
	collision_layer = 1
	collision_mask = 0  # Furniture doesn't need to detect collisions

	# Position in isometric space
	var size = RotationHelper.get_rotated_size(resource.size, rot)

	# Calculate center of footprint for positioning (use float for proper centering)
	var center_offset = RotationHelper.get_center_offset(resource.size, rot)
	var tile_pos = Vector2(pos) + center_offset
	position = IsometricMath.tile_to_world_float(tile_pos)

	# Configure collision shape if we have one
	_setup_collision_shape(size)

	# Generate and set placeholder sprite
	_setup_sprite(resource, size)

	# Configure navigation obstacle
	_setup_navigation_obstacle(size)

func _compute_isometric_hull(size: Vector2i) -> PackedVector2Array:
	var all_vertices: PackedVector2Array = []
	var center_offset = Vector2(float(size.x) / 2.0, float(size.y) / 2.0)
	var half_w = IsometricMath.HALF_WIDTH
	var half_h = IsometricMath.HALF_HEIGHT

	# The sprite has an offset to align visually. We need to match that offset.
	# The hull calculation doesn't include the +HALF_HEIGHT from tile_to_world,
	# but the furniture position does. This creates a HALF_HEIGHT offset.
	var y_offset = half_h

	for tx in range(size.x):
		for ty in range(size.y):
			# Tile center relative to furniture center (in world coords)
			var tile_x = (tx - ty) * half_w
			var tile_y = (tx + ty) * half_h
			var furn_x = (center_offset.x - center_offset.y) * half_w
			var furn_y = (center_offset.x + center_offset.y) * half_h
			var rel_x = tile_x - furn_x
			var rel_y = tile_y - furn_y + y_offset

			# 4 diamond vertices for this tile
			all_vertices.append(Vector2(rel_x, rel_y - half_h))  # Top
			all_vertices.append(Vector2(rel_x + half_w, rel_y))   # Right
			all_vertices.append(Vector2(rel_x, rel_y + half_h))  # Bottom
			all_vertices.append(Vector2(rel_x - half_w, rel_y))   # Left

	var hull = Geometry2D.convex_hull(all_vertices)
	# Remove duplicate closing vertex if present
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull


func _setup_collision_shape(size: Vector2i) -> void:
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape:
		return
	var hull_vertices = _compute_isometric_hull(size)
	var polygon_shape = ConvexPolygonShape2D.new()
	polygon_shape.points = hull_vertices
	collision_shape.shape = polygon_shape

func _setup_sprite(resource: FurnitureResource, size: Vector2i) -> void:
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return

	var half_w = IsometricMath.HALF_WIDTH
	var half_h = IsometricMath.HALF_HEIGHT

	# Generate placeholder texture
	var texture = _create_isometric_placeholder(resource.id, size)
	sprite.texture = texture
	sprite.centered = true

	# The sprite is centered on the furniture position, which is at the center of the footprint
	# The texture is generated with tile (0,0) at a specific position, so we need to offset
	# to center the texture properly on our position
	var tex_width = (size.x + size.y) * half_w
	var tex_height = (size.x + size.y) * half_h + half_h

	# Tile (0,0) top in texture is at (size.y * HALF_WIDTH, 0)
	# Our position is at the center of the footprint
	# We need to offset the sprite so it draws correctly centered on our position
	var tile_00_x = size.y * half_w
	var tile_00_y = 0.0

	# Center of footprint in local texture coords (relative to tile 0,0)
	var center_tile = Vector2(float(size.x) / 2.0, float(size.y) / 2.0)
	var center_in_tex_x = tile_00_x + (center_tile.x - center_tile.y) * half_w
	var center_in_tex_y = tile_00_y + (center_tile.x + center_tile.y) * half_h

	# Offset from texture center to footprint center
	sprite.offset = Vector2(tex_width / 2.0 - center_in_tex_x, tex_height / 2.0 - center_in_tex_y)

func _setup_navigation_obstacle(size: Vector2i) -> void:
	var obstacle = get_node_or_null("NavigationObstacle2D") as NavigationObstacle2D
	if not obstacle:
		# Create obstacle if it doesn't exist
		obstacle = NavigationObstacle2D.new()
		obstacle.name = "NavigationObstacle2D"
		add_child(obstacle)

	# Enable avoidance
	obstacle.avoidance_enabled = true
	obstacle.affect_navigation_mesh = true

	# Use the same hull vertices as collision shape (for nav mesh baking)
	var hull_vertices = _compute_isometric_hull(size)
	obstacle.vertices = hull_vertices

	# Compute radius as distance to furthest hull vertex (for RVO avoidance)
	# The radius determines the circular avoidance area agents use
	var max_radius := 0.0
	for vertex in hull_vertices:
		var dist = vertex.length()
		if dist > max_radius:
			max_radius = dist
	obstacle.radius = max_radius

func _create_isometric_placeholder(furniture_id: String, size: Vector2i) -> ImageTexture:
	# Calculate image size to fit isometric tiles
	var img_size = IsometricMath.get_isometric_image_size(size)
	var img = Image.create(img_size.x, img_size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))  # Transparent background

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
				var is_border = abs(dx) >= width_at_y - 1 or abs(dy) >= half_h - 1
				img.set_pixel(px, py, border_color if is_border else fill_color)

func _get_furniture_color(furniture_id: String) -> Color:
	match furniture_id:
		"seat", "chair", "seating_bench":
			return Color(0.6, 0.4, 0.2, 0.9)  # Brown
		"screen":
			return Color(0.2, 0.2, 0.3, 0.9)  # Dark gray
		"counter":
			return Color(0.5, 0.4, 0.3, 0.9)  # Tan
		"ticket_window":
			return Color(0.3, 0.5, 0.6, 0.9)  # Teal
		"toilet", "sink", "stall":
			return Color(0.7, 0.7, 0.8, 0.9)  # Light gray
		"register":
			return Color(0.4, 0.5, 0.3, 0.9)  # Olive
		"display_case":
			return Color(0.5, 0.6, 0.7, 0.9)  # Light blue-gray
		"dispenser":
			return Color(0.6, 0.6, 0.6, 0.9)  # Gray
		"mirror":
			return Color(0.7, 0.8, 0.9, 0.9)  # Light blue
		"speaker":
			return Color(0.3, 0.3, 0.35, 0.9)  # Dark gray
		_:
			return Color(0.5, 0.5, 0.5, 0.9)  # Default gray

## Get the tiles that need to be accessible for patrons to use this furniture
func get_access_tiles() -> Array[Vector2i]:
	if furniture_resource:
		var rotated_access = furniture_resource.get_rotated_access_tiles(_furniture_rotation)
		var world_access: Array[Vector2i] = []
		for offset in rotated_access:
			world_access.append(_tile_position + offset)
		return world_access
	return []
