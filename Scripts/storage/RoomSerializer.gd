class_name RoomSerializer
extends RefCounted

## RoomSerializer handles atomic file I/O for room persistence.
## Uses JSON format as specified in PROJECT.md.

const SAVE_PATH := "user://saves/rooms.json"
const TEMP_PATH := "user://saves/rooms.json.tmp"
const SAVE_DIR := "user://saves"


## Save rooms to JSON file using atomic write pattern.
## Returns true on success, false on failure.
static func save_rooms(rooms: Array[RoomInstance]) -> bool:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("RoomSerializer: Failed to create save directory: %s" % error_string(err))
			return false

	# Build save data
	var rooms_data: Array = []
	for room in rooms:
		rooms_data.append(room.to_dict())

	var save_data := {
		"version": 1,
		"saved_at": Time.get_datetime_string_from_system(),
		"rooms": rooms_data
	}

	# Convert to JSON
	var json_string := JSON.stringify(save_data, "  ")

	# Write to temp file first (atomic write pattern)
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("RoomSerializer: Failed to open temp file: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(json_string)
	file.close()

	# Verify temp file is valid JSON before renaming
	if not _verify_json_file(TEMP_PATH):
		push_error("RoomSerializer: Temp file verification failed")
		DirAccess.remove_absolute(TEMP_PATH)
		return false

	# Atomic rename: delete old file, rename temp to final
	if FileAccess.file_exists(SAVE_PATH):
		var err = DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_error("RoomSerializer: Failed to remove old save: %s" % error_string(err))
			return false

	var err = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("RoomSerializer: Failed to rename temp to save: %s" % error_string(err))
		return false

	print("RoomSerializer: Saved %d rooms to %s" % [rooms.size(), SAVE_PATH])
	return true


## Load rooms from JSON file.
## Returns empty array on failure (graceful degradation).
static func load_rooms() -> Array[RoomInstance]:
	var rooms: Array[RoomInstance] = []

	if not FileAccess.file_exists(SAVE_PATH):
		print("RoomSerializer: No save file found at %s" % SAVE_PATH)
		return rooms

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("RoomSerializer: Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return rooms

	var json_string := file.get_as_text()
	file.close()

	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("RoomSerializer: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return rooms

	var data = json.data
	if not data is Dictionary:
		push_error("RoomSerializer: Save file root is not a Dictionary")
		return rooms

	# Validate structure
	if not data.has("rooms") or not data.rooms is Array:
		push_error("RoomSerializer: Save file missing 'rooms' array")
		return rooms

	# Deserialize rooms
	for room_data in data.rooms:
		if room_data is Dictionary:
			var room := RoomInstance.from_dict(room_data)
			if room != null:
				rooms.append(room)
			else:
				push_warning("RoomSerializer: Skipping invalid room data")
		else:
			push_warning("RoomSerializer: Skipping non-Dictionary room entry")

	print("RoomSerializer: Loaded %d rooms from %s" % [rooms.size(), SAVE_PATH])
	return rooms


## Verify a JSON file can be parsed correctly.
static func _verify_json_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	return json.parse(content) == OK


## Check if a save file exists.
static func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Delete the save file (for admin reset feature).
static func delete_save_file() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return true

	var err = DirAccess.remove_absolute(SAVE_PATH)
	if err != OK:
		push_error("RoomSerializer: Failed to delete save file: %s" % error_string(err))
		return false

	print("RoomSerializer: Deleted save file")
	return true
