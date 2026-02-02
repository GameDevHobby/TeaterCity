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
## Navigation update happens after door placement (caller responsibility).
func execute_resize(room: RoomInstance, new_box: Rect2i, wall_tilemap: TileMapLayer, room_manager: Node, exterior_walls: Array[Vector2i]) -> void:
	var deletion_op = DeletionOperation.new()
	var wall_op = WallOperation.new()

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

	# Emit placement_changed for auto-save
	room.placement_changed.emit()


## Check if a tile position is inside a bounding box.
func _is_tile_in_box(tile: Vector2i, box: Rect2i) -> bool:
	return tile.x >= box.position.x and tile.x < box.position.x + box.size.x \
	   and tile.y >= box.position.y and tile.y < box.position.y + box.size.y
