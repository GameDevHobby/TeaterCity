class_name MoviePoolSerializer
extends RefCounted

## JSON persistence for MoviePool with atomic write pattern.
## Follows the same pattern as RoomSerializer for consistency.

const SAVE_PATH := "user://saves/movie_pool.json"
const TEMP_PATH := "user://saves/movie_pool.json.tmp"
const SAVE_DIR := "user://saves"
const SCHEMA_VERSION := 1


## Save pool to JSON file using atomic write pattern.
## Returns true on success, false on failure.
static func save_pool(pool: MoviePool) -> bool:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("MoviePoolSerializer: Failed to create save directory: %s" % error_string(err))
			return false

	# Build save data with metadata
	var save_data := {
		"version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"pool": pool.to_dict()
	}

	# Convert to JSON with pretty formatting
	var json_string := JSON.stringify(save_data, "  ")

	# Write to temp file first (atomic write pattern)
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("MoviePoolSerializer: Failed to open temp file: %s" % error_string(FileAccess.get_open_error()))
		return false

	file.store_string(json_string)
	file.close()

	# Verify temp file is valid JSON before renaming
	if not _verify_json_file(TEMP_PATH):
		push_error("MoviePoolSerializer: Temp file verification failed")
		DirAccess.remove_absolute(TEMP_PATH)
		return false

	# Atomic rename: delete old file, rename temp to final
	if FileAccess.file_exists(SAVE_PATH):
		var err = DirAccess.remove_absolute(SAVE_PATH)
		if err != OK:
			push_error("MoviePoolSerializer: Failed to remove old save: %s" % error_string(err))
			return false

	var err = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("MoviePoolSerializer: Failed to rename temp to save: %s" % error_string(err))
		return false

	print("MoviePoolSerializer: Saved %d movies to %s" % [pool.size(), SAVE_PATH])
	return true


## Load pool from JSON file.
## Returns null if file doesn't exist or on error.
static func load_pool() -> MoviePool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("MoviePoolSerializer: No save file found at %s" % SAVE_PATH)
		return null

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("MoviePoolSerializer: Failed to open save file: %s" % error_string(FileAccess.get_open_error()))
		return null

	var json_string := file.get_as_text()
	file.close()

	# Parse JSON
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("MoviePoolSerializer: JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null

	var data = json.data
	if not data is Dictionary:
		push_error("MoviePoolSerializer: Save file root is not a Dictionary")
		return null

	# Version check
	var version = data.get("version", 1)
	if version > SCHEMA_VERSION:
		push_warning("MoviePoolSerializer: Loading data from newer schema version %d (current: %d)" % [version, SCHEMA_VERSION])

	# Validate structure
	if not data.has("pool") or not data.pool is Dictionary:
		push_error("MoviePoolSerializer: Save file missing 'pool' dictionary")
		return null

	var pool = MoviePool.from_dict(data.pool)
	print("MoviePoolSerializer: Loaded %d movies from %s" % [pool.size(), SAVE_PATH])
	return pool


## Check if a save file exists.
static func exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


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
