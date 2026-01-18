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
	
	# Furniture check
	var required = room_type.get_required_furniture_dict()
	for furniture_id in required.keys():
		var required_count = required[furniture_id]
		var actual_count = room.get_furniture_count(furniture_id)
		if actual_count < required_count:
			result.is_valid = false
			result.errors.append("Need %d more %s(s)" % [required_count - actual_count, furniture_id])
	
	return result
