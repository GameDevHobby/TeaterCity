class_name ResizeOperation
extends RefCounted

## Stateless operation for room resize validation and execution.
## Validates furniture bounds, room overlap, and type constraints before resize.
## Executes resize via delete+rebuild pattern (reuses DeletionOperation and WallOperation).


## Result of resize validation.
## Contains validation state and detailed information about what would block the resize.
class ResizeValidationResult:
	var is_valid: bool = true
	var error: String = ""
	var blocked_furniture: Array[RoomInstance.FurniturePlacement] = []
	var overlapped_room: RoomInstance = null  # Room that new bounds would overlap


## Validate a proposed resize operation.
## Checks in order: room type size constraints, room overlap, furniture bounds.
## Returns a ResizeValidationResult with validation state and error details.
func validate_resize(room: RoomInstance, new_box: Rect2i, room_manager: Node) -> ResizeValidationResult:
	var result = ResizeValidationResult.new()

	# 1. Room type size constraints (fast fail)
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type:
		var min_s = room_type.min_size
		var max_s = room_type.max_size
		var new_size = new_box.size

		# Check both orientations (allow swapped width/height)
		var normal_valid = new_size.x >= min_s.x and new_size.y >= min_s.y and new_size.x <= max_s.x and new_size.y <= max_s.y
		var swapped_valid = new_size.x >= min_s.y and new_size.y >= min_s.x and new_size.x <= max_s.y and new_size.y <= max_s.x

		if not normal_valid and not swapped_valid:
			result.is_valid = false
			result.error = "Invalid size: %dx%d (required %dx%d to %dx%d)" % [
				new_size.x, new_size.y,
				min_s.x, min_s.y,
				max_s.x, max_s.y
			]
			return result

	# 2. Room overlap detection (fast fail)
	for other_room in room_manager.get_all_rooms():
		if other_room == room:
			continue
		if new_box.intersects(other_room.bounding_box):
			result.is_valid = false
			result.error = "Would overlap with another room"
			result.overlapped_room = other_room
			return result

	# 3. Furniture bounds validation (detailed feedback)
	var wall_op = WallOperation.new()
	var new_walls = wall_op.generate_walls(new_box)

	for furn in room.furniture:
		var is_blocked = false

		# Check footprint tiles
		for tile in furn.get_occupied_tiles():
			if not _is_tile_in_box(tile, new_box):
				is_blocked = true
				break
			if tile in new_walls:
				is_blocked = true
				break

		# Check access tiles (only if not already blocked)
		if not is_blocked:
			for tile in furn.get_access_tiles():
				if not _is_tile_in_box(tile, new_box):
					is_blocked = true
					break
				if tile in new_walls:
					is_blocked = true
					break

		if is_blocked:
			if furn not in result.blocked_furniture:
				result.blocked_furniture.append(furn)

	if result.blocked_furniture.size() > 0:
		result.is_valid = false
		result.error = "%d furniture item(s) would be outside new bounds or have blocked access" % result.blocked_furniture.size()

	return result


## Execute the resize operation.
## Deletes old wall/door visuals, updates room data, creates new wall visuals.
## Doors are reset on resize (per requirement EDIT-03).
## Furniture stays in place - validation should be run first to confirm fit.
## nav_tilemap is the floor/navigation tilemap, wall_tilemap is for walls.
func execute_resize(room: RoomInstance, new_box: Rect2i, wall_tilemap: TileMapLayer, _nav_tilemap: TileMapLayer, room_manager: Node, exterior_walls: Array[Vector2i]) -> void:
	var deletion_op = DeletionOperation.new()
	var wall_op = WallOperation.new()
	var nav_op = NavigationOperation.new()

	# Store old bounds before modifying (needed for floor restoration)
	var old_box = room.bounding_box
	var old_walls = room.walls.duplicate()

	# Clear navigation tiles for old bounds (we'll restore what's needed later)
	# NOTE: Floor tiles are on wall_tilemap, not nav_tilemap (matches RoomBuildController pattern)
	nav_op.clear_room_navigation(room, wall_tilemap)

	# Delete old door visuals
	deletion_op.delete_door_visuals(room, wall_tilemap)

	# Delete old wall visuals (only deletable walls - preserves shared/exterior)
	deletion_op.delete_wall_visuals(room, wall_tilemap, room_manager, exterior_walls)

	# Clear doors array (doors reset on resize per requirement EDIT-03)
	room.doors.clear()

	# Update room data
	room.bounding_box = new_box
	room.walls = wall_op.generate_walls(new_box)

	# Create new wall visuals
	wall_op.create_wall_visuals(room, wall_tilemap)

	# Update navigation for new bounds (sets floor tiles for new interior)
	# NOTE: Floor tiles are on wall_tilemap, not nav_tilemap (matches RoomBuildController pattern)
	nav_op.update_room_navigation(room, wall_tilemap)

	# Restore floor tiles for OLD area that is no longer part of the room
	# NOTE: Floor tiles are on wall_tilemap (matches RoomBuildController pattern)
	_restore_old_area_floor(old_box, old_walls, new_box, wall_tilemap, exterior_walls)

	# Restore exterior walls that may have been cleared
	# (clear_room_navigation erases ALL tiles in old bounds, including exterior walls)
	_restore_exterior_walls(old_box, new_box, wall_tilemap, exterior_walls)

	# Emit placement_changed for auto-save
	room.placement_changed.emit()


## Restore floor tiles for the old room area that is no longer part of the new room.
## This handles both shrinking and moving scenarios.
## NOTE: Floor tiles are on wall_tilemap (matches RoomBuildController pattern)
func _restore_old_area_floor(old_box: Rect2i, _old_walls: Array[Vector2i], new_box: Rect2i, wall_tilemap: TileMapLayer, exterior_walls: Array[Vector2i]) -> void:
	const SOURCE_ID := 1
	const WALKABLE_TILE := Vector2i(0, 1)
	const TERRAIN_SET := 0

	# Iterate through all tiles in the old bounding box
	for x in range(old_box.position.x, old_box.position.x + old_box.size.x):
		for y in range(old_box.position.y, old_box.position.y + old_box.size.y):
			var pos = Vector2i(x, y)

			# Skip if this position is within the new bounding box (already handled)
			if _is_tile_in_box(pos, new_box):
				continue

			# Skip exterior walls - never modify these
			if pos in exterior_walls:
				continue

			var tilemap_pos = IsometricMath.ui_to_tilemap_coords(pos, wall_tilemap)

			# Check if there's still a wall tile here (shared wall from another room)
			var tile_data = wall_tilemap.get_cell_tile_data(tilemap_pos)
			if tile_data and tile_data.get_terrain_set() == TERRAIN_SET:
				continue  # Don't restore floor where walls still exist

			# Restore floor tile for this position
			wall_tilemap.set_cell(tilemap_pos, SOURCE_ID, WALKABLE_TILE)


## Check if a tile position is inside a bounding box.
func _is_tile_in_box(tile: Vector2i, box: Rect2i) -> bool:
	return tile.x >= box.position.x and tile.x < box.position.x + box.size.x \
	   and tile.y >= box.position.y and tile.y < box.position.y + box.size.y


## Restore exterior walls that were cleared during resize.
## clear_room_navigation erases ALL tiles in old bounds, including exterior walls.
## This function restores those exterior wall tiles using terrain auto-tiling.
func _restore_exterior_walls(old_box: Rect2i, new_box: Rect2i, wall_tilemap: TileMapLayer, exterior_walls: Array[Vector2i]) -> void:
	const TERRAIN_SET := 0
	const TERRAIN_INDEX := 0

	# Find exterior walls that were in old bounds but not in new bounds
	var walls_to_restore: Array[Vector2i] = []

	for ext_wall in exterior_walls:
		# Was this exterior wall in the old room bounds?
		if _is_tile_in_box(ext_wall, old_box):
			# Is it NOT in the new room bounds? (needs restoration)
			# Also restore if it IS in new bounds but not a new room wall
			var tilemap_pos = IsometricMath.ui_to_tilemap_coords(ext_wall, wall_tilemap)
			var tile_data = wall_tilemap.get_cell_tile_data(tilemap_pos)
			# If there's no tile here, it was cleared and needs restoration
			if tile_data == null:
				walls_to_restore.append(tilemap_pos)

	if walls_to_restore.size() > 0:
		# Use terrain auto-tiling to restore walls with proper connections
		wall_tilemap.set_cells_terrain_connect(walls_to_restore, TERRAIN_SET, TERRAIN_INDEX)
