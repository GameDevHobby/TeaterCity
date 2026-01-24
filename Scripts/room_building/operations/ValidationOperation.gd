class_name ValidationOperation
extends RefCounted

class ValidationResult:
	var is_valid: bool = true
	var errors: Array[String] = []

func validate_complete(room: RoomInstance) -> ValidationResult:
	var result = ValidationResult.new()

	var room_type_registry = RoomTypeRegistry.get_instance()
	var room_type = room_type_registry.get_room_type(room.room_type_id)

	if not room_type:
		result.is_valid = false
		result.errors.append("Invalid room type")
		return result

	# Size check
	if room.bounding_box.size.x < room_type.min_size.x or room.bounding_box.size.y < room_type.min_size.y:
		result.is_valid = false
		result.errors.append("Room too small")

	# Door check (skip for wall-less rooms)
	if room_type.has_walls:
		var door_count = room.doors.size()
		if door_count < room_type.door_count_min:
			result.is_valid = false
			result.errors.append("Need %d more door(s)" % (room_type.door_count_min - door_count))

	# Furniture check using typed FurnitureRequirement
	for req in room_type.get_required_furniture():
		if not req.furniture:
			continue
		var actual_count = room.get_furniture_count_by_resource(req.furniture)
		if actual_count < req.count:
			var display_name = req.furniture.name if req.furniture.name else req.furniture.id
			result.is_valid = false
			result.errors.append("Need %d more %s(s)" % [req.count - actual_count, display_name])

	return result


## Check if deleting this furniture placement would violate room type requirements
## Returns { can_delete: bool, reason: String }
func can_delete_furniture(room: RoomInstance, furniture: RoomInstance.FurniturePlacement) -> Dictionary:
	var result = { "can_delete": true, "reason": "" }

	if not furniture or not furniture.furniture:
		return result  # Can always delete null/invalid furniture

	var room_type_registry = RoomTypeRegistry.get_instance()
	var room_type = room_type_registry.get_room_type(room.room_type_id)

	if not room_type:
		return result  # Can delete if room type unknown

	# Check if this furniture type is required
	for req in room_type.get_required_furniture():
		if not req.furniture:
			continue

		if req.furniture == furniture.furniture:
			# This furniture type is required - check count
			var current_count = room.get_furniture_count_by_resource(req.furniture)
			if current_count <= req.count:
				var display_name = req.furniture.name if req.furniture.name else req.furniture.id
				result.can_delete = false
				result.reason = "Cannot delete: %s is required (minimum %d)" % [display_name, req.count]
				return result

	return result
