class_name DoorEditController
extends Control

## Controller for door editing mode.
## Manages door add/remove operations via tap detection on wall tiles.
## Follows FurnitureEditController pattern for Area2D tap detection.

# Signals for door operations
signal door_added(room: RoomInstance, door: RoomInstance.DoorPlacement)
signal door_removed(room: RoomInstance, door: RoomInstance.DoorPlacement)
signal door_add_failed(reason: String)
signal door_remove_failed(reason: String)
signal wall_tile_tapped(position: Vector2i, is_door: bool)
signal mode_exited

# Tap detection thresholds (same as FurnitureEditController)
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

# State
var _active: bool = false
var _current_room: RoomInstance = null
var _wall_areas: Dictionary = {}  # position (Vector2i hash) -> Area2D

# Tap detection state
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0


# --- Lifecycle ---

func _ready() -> void:
	# Prevent blocking input to Area2D below
	mouse_filter = MOUSE_FILTER_IGNORE


# --- Public Methods ---

func enter_edit_mode(room: RoomInstance) -> void:
	if room == null:
		return

	# Check if room type has walls
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
	if room_type and not room_type.has_walls:
		return  # Cannot edit doors on wall-less rooms

	_active = true
	_current_room = room

	_create_wall_areas(room)


func exit_edit_mode() -> void:
	_clear_wall_areas()
	_current_room = null
	_active = false
	mode_exited.emit()


func is_active() -> bool:
	return _active


func get_current_room() -> RoomInstance:
	return _current_room


# --- Private Methods ---

func _create_wall_areas(room: RoomInstance) -> void:
	_clear_wall_areas()

	for wall_pos in room.walls:
		var area := Area2D.new()
		var pos_hash := _position_to_hash(wall_pos)
		area.name = "WallArea_%d_%d" % [wall_pos.x, wall_pos.y]
		area.input_pickable = true  # CRITICAL - default is false

		var collision := CollisionPolygon2D.new()
		collision.polygon = _tile_to_polygon(wall_pos)
		area.add_child(collision)

		area.input_event.connect(_on_wall_input.bind(wall_pos))

		add_child(area)
		_wall_areas[pos_hash] = area


func _clear_wall_areas() -> void:
	for pos_hash in _wall_areas:
		var area: Area2D = _wall_areas[pos_hash]
		if area and is_instance_valid(area):
			area.queue_free()
	_wall_areas.clear()


func _position_to_hash(pos: Vector2i) -> int:
	# Simple hash for dictionary key - combine x and y into unique int
	return pos.x * 100000 + pos.y


func _tile_to_polygon(tile_pos: Vector2i) -> PackedVector2Array:
	var polygon := PackedVector2Array()

	# Calculate isometric diamond corners for single tile
	var top := IsometricMath.tile_to_world(tile_pos)
	var right := IsometricMath.tile_to_world(Vector2i(tile_pos.x + 1, tile_pos.y))
	var bottom := IsometricMath.tile_to_world(Vector2i(tile_pos.x + 1, tile_pos.y + 1))
	var left := IsometricMath.tile_to_world(Vector2i(tile_pos.x, tile_pos.y + 1))

	# Build polygon clockwise from top
	polygon.append(top)
	polygon.append(right)
	polygon.append(bottom)
	polygon.append(left)

	return polygon


func _on_wall_input(_viewport: Node, event: InputEvent, _shape_idx: int, wall_pos: Vector2i) -> void:
	if not _active:
		return

	# Handle mouse clicks (desktop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec()
		else:
			var distance: float = event.position.distance_to(_touch_start_pos)
			var duration := Time.get_ticks_msec() - _touch_start_time
			if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
				_handle_wall_tap(wall_pos)
		return

	# Handle touch events (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec()
		else:
			var distance: float = event.position.distance_to(_touch_start_pos)
			var duration := Time.get_ticks_msec() - _touch_start_time
			if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
				_handle_wall_tap(wall_pos)


func _handle_wall_tap(wall_pos: Vector2i) -> void:
	if _current_room == null:
		return

	# Check if this position is an existing door
	var is_door := false
	for door in _current_room.doors:
		if door.position == wall_pos:
			is_door = true
			break

	wall_tile_tapped.emit(wall_pos, is_door)
