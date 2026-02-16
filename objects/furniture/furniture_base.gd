class_name FurnitureBase
extends StaticBody2D

var _furniture_resource: FurnitureResource

var _tile_position: Vector2i
var _furniture_rotation: int

func setup_from_resource(resource: FurnitureResource, pos: Vector2i, rot: int, _tilemap_layer: TileMapLayer = null) -> void:
	_furniture_resource = resource
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

	# Set up directional sprite based on rotation
	_setup_sprite()

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

func _setup_sprite() -> void:
	# Try to find AnimatedSprite2D child for directional sprites
	var animated_sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite and animated_sprite.sprite_frames:
		# Set frame based on rotation direction (0=North, 1=East, 2=South, 3=West)
		var frame_count = animated_sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			# For sprites with only 2 frames, map rotations 0,2 to frame 0 and 1,3 to frame 1
			if frame_count == 2:
				animated_sprite.frame = _furniture_rotation % 2
			else:
				animated_sprite.frame = _furniture_rotation % frame_count

		# Position sprite - center horizontally, align bottom with tile position
		# IIP sprites have their visual base at the bottom of the image
		animated_sprite.centered = true

		# Get the current frame texture to calculate offset
		var texture = animated_sprite.sprite_frames.get_frame_texture("default", animated_sprite.frame)
		if texture:
			# Offset sprite so its bottom aligns with the isometric tile center
			# The sprite's visual "foot" should be at our position
			var sprite_height = texture.get_height()
			animated_sprite.offset = Vector2(0, -sprite_height / 2.0 + IsometricMath.HALF_HEIGHT)
		return

	# Fallback: check for legacy Sprite2D (placeholder - no setup needed)
	var sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		# Legacy placeholder sprite - will be replaced by scene updates
		pass

func _setup_navigation_obstacle(size: Vector2i) -> void:
	var obstacle = get_node_or_null("NavigationObstacle2D") as NavigationObstacle2D
	if not obstacle:
		push_warning("FurnitureBase %s: missing NavigationObstacle2D child (scene-author this node)" % name)
		return

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

## Get the tiles that need to be accessible for patrons to use this furniture
func get_access_tiles() -> Array[Vector2i]:
	if _furniture_resource:
		var rotated_access = _furniture_resource.get_rotated_access_tiles(_furniture_rotation)
		var world_access: Array[Vector2i] = []
		for offset in rotated_access:
			world_access.append(_tile_position + offset)
		return world_access
	return []
