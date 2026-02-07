class_name AdminMenu
extends Node

## AdminMenu autoload singleton - provides admin functionality with feature flag gating.
##
## Feature Flag Behavior:
## - In debug builds (editor or debug exports): Admin features always enabled.
## - In release builds: Admin features disabled unless explicitly enabled via ProjectSettings.
##
## To enable admin features in release builds, add this to project.godot:
##   [application]
##   admin/enabled=true
##
## This singleton provides operations for save management:
## - revert_to_save(): Discard current session changes, reload from last save
## - reset_all_data(): Delete all saved data and clear current session


## Private state
var _is_enabled: bool = false

## Reference to RoomManager autoload (deferred to ensure RoomManager loads first)
@onready var _room_manager: Node = get_node("/root/RoomManager")


# --- Lifecycle ---

func _ready() -> void:
	_is_enabled = _is_admin_enabled()
	if _is_enabled:
		print("AdminMenu: Enabled (debug build or admin flag set)")
	else:
		print("AdminMenu: Disabled (release build, no override)")


# --- Public Methods ---

## Returns true if admin features are enabled.
## Use this to gate UI elements and operations.
func is_admin_enabled() -> bool:
	return _is_enabled


## Revert all rooms to the last saved state.
## Discards any unsaved changes from the current session.
## Returns true on success, false on failure.
func revert_to_save() -> bool:
	if not _is_enabled:
		push_warning("AdminMenu: revert_to_save() called but admin features disabled")
		return false

	if _room_manager == null:
		push_error("AdminMenu: RoomManager not available")
		return false

	# Get all current rooms (duplicate to avoid modification during iteration)
	var current_rooms: Array[RoomInstance] = _room_manager.get_all_rooms().duplicate()

	# Unregister each current room
	for room in current_rooms:
		_room_manager.unregister_room(room)

	# Load saved rooms
	var saved_rooms := RoomSerializer.load_rooms()

	# Register each loaded room
	for room in saved_rooms:
		_room_manager.register_room(room)

	print("AdminMenu: Reverted to save - %d rooms restored" % saved_rooms.size())
	return true


## Reset all room data - deletes save file and clears current session.
## WARNING: This is destructive and cannot be undone!
## Returns true on success, false on failure.
func reset_all_data() -> bool:
	if not _is_enabled:
		push_warning("AdminMenu: reset_all_data() called but admin features disabled")
		return false

	if _room_manager == null:
		push_error("AdminMenu: RoomManager not available")
		return false

	# Get all current rooms (duplicate to avoid modification during iteration)
	var current_rooms: Array[RoomInstance] = _room_manager.get_all_rooms().duplicate()

	# Unregister each current room
	for room in current_rooms:
		_room_manager.unregister_room(room)

	# Delete the save file
	var success := RoomSerializer.delete_save_file()

	if success:
		print("AdminMenu: Reset all data - save file deleted")
	else:
		push_error("AdminMenu: Failed to delete save file")

	return success


# --- Private Methods ---

## Check if admin features should be enabled.
## Returns true if:
## - Running in debug mode (editor or debug export), OR
## - ProjectSettings has application/admin/enabled set to true
func _is_admin_enabled() -> bool:
	# Debug builds always have admin enabled
	if OS.has_feature("debug"):
		return true

	# Check for explicit admin override in project settings
	if ProjectSettings.has_setting("application/admin/enabled"):
		return ProjectSettings.get_setting("application/admin/enabled", false) as bool

	return false
