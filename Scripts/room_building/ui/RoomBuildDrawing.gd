class_name RoomBuildDrawing
extends RefCounted

## Static drawing helpers for room building UI.
## Consolidates drawing code from RoomBuildUI.

static func draw_tile_highlight(control: CanvasItem, tile_pos: Vector2i, color: Color, viewport: Viewport) -> void:
	var top = IsometricMath.tile_to_screen(tile_pos, viewport)
	var right = IsometricMath.tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y), viewport)
	var bottom = IsometricMath.tile_to_screen(Vector2i(tile_pos.x + 1, tile_pos.y + 1), viewport)
	var left = IsometricMath.tile_to_screen(Vector2i(tile_pos.x, tile_pos.y + 1), viewport)

	var points = PackedVector2Array([top, right, bottom, left])
	control.draw_colored_polygon(points, color)

static func draw_box_selection(
	control: CanvasItem,
	min_tile: Vector2i,
	max_tile: Vector2i,
	is_valid: bool,
	colors: Dictionary,
	viewport: Viewport
) -> void:
	# Choose colors based on validity
	var wall_color: Color
	var interior_color: Color
	if is_valid:
		wall_color = colors.valid_border.lerp(Color.WHITE, 0.2)
		wall_color.a = 0.6
		interior_color = colors.valid_fill
	else:
		wall_color = colors.invalid_border.lerp(Color.WHITE, 0.2)
		wall_color.a = 0.6
		interior_color = colors.invalid_fill

	# Generate wall positions (same logic as WallOperation.generate_walls)
	var wall_positions: Array[Vector2i] = []
	for x in range(min_tile.x, max_tile.x + 1):
		wall_positions.append(Vector2i(x, min_tile.y))
		wall_positions.append(Vector2i(x, max_tile.y))
	for y in range(min_tile.y + 1, max_tile.y):
		wall_positions.append(Vector2i(min_tile.x, y))
		wall_positions.append(Vector2i(max_tile.x, y))

	# Draw interior tiles first (lighter color)
	for x in range(min_tile.x + 1, max_tile.x):
		for y in range(min_tile.y + 1, max_tile.y):
			draw_tile_highlight(control, Vector2i(x, y), interior_color, viewport)

	# Draw wall tiles on top
	for wall_pos in wall_positions:
		draw_tile_highlight(control, wall_pos, wall_color, viewport)

	# Draw outer border
	var top = IsometricMath.tile_to_screen(min_tile, viewport)
	var right = IsometricMath.tile_to_screen(Vector2i(max_tile.x + 1, min_tile.y), viewport)
	var bottom = IsometricMath.tile_to_screen(Vector2i(max_tile.x + 1, max_tile.y + 1), viewport)
	var left = IsometricMath.tile_to_screen(Vector2i(min_tile.x, max_tile.y + 1), viewport)
	var border_color = colors.valid_border if is_valid else colors.invalid_border
	control.draw_polyline(PackedVector2Array([top, right, bottom, left, top]), border_color, 2.0)

static func draw_door_placement_hints(
	control: CanvasItem,
	room: RoomInstance,
	hover_pos: Vector2i,
	colors: Dictionary,
	viewport: Viewport
) -> void:
	var door_op = DoorOperation.new()

	# Draw all valid door positions
	for wall_pos in room.walls:
		var is_door = false
		for door in room.doors:
			if door.position == wall_pos:
				is_door = true
				break

		if is_door:
			draw_tile_highlight(control, wall_pos, colors.placed, viewport)
		elif door_op.is_valid_door_position(wall_pos, room):
			draw_tile_highlight(control, wall_pos, colors.valid, viewport)
		else:
			draw_tile_highlight(control, wall_pos, colors.wall, viewport)

	# Highlight current hover position
	if hover_pos in room.walls:
		if door_op.is_valid_door_position(hover_pos, room):
			draw_tile_highlight(control, hover_pos, colors.hover, viewport)

static func draw_furniture_placement_hints(
	control: CanvasItem,
	room: RoomInstance,
	preview: CollisionOperation.PreviewResult,
	colors: Dictionary,
	viewport: Viewport
) -> void:
	# Draw room interior (valid placement area)
	var bbox = room.bounding_box
	for x in range(bbox.position.x, bbox.position.x + bbox.size.x):
		for y in range(bbox.position.y, bbox.position.y + bbox.size.y):
			var pos = Vector2i(x, y)
			if pos not in room.walls:
				draw_tile_highlight(control, pos, colors.valid_area, viewport)

	# Draw placed furniture (showing footprint and access tiles)
	for furn in room.furniture:
		# Draw access tiles first (lighter color)
		for tile in furn.get_access_tiles():
			draw_tile_highlight(control, tile, colors.access, viewport)
		# Draw footprint tiles on top
		for tile in furn.get_occupied_tiles():
			draw_tile_highlight(control, tile, colors.placed, viewport)

	# Draw preview tiles if we have a preview
	if preview:
		# Draw access tiles first (so furniture tiles draw on top)
		for tile in preview.valid_access_tiles:
			draw_tile_highlight(control, tile, colors.access, viewport)
		for tile in preview.blocked_access_tiles:
			draw_tile_highlight(control, tile, colors.blocked_access, viewport)

		# Draw footprint ghost tiles
		for tile in preview.valid_tiles:
			draw_tile_highlight(control, tile, colors.ghost, viewport)
		for tile in preview.blocked_tiles:
			draw_tile_highlight(control, tile, colors.blocked, viewport)
