extends Node

## RoomManager singleton - tracks completed rooms and handles selection.
## Follows Targets.gd pattern for autoload singleton architecture.

# Signals
signal room_added(room: RoomInstance)
signal room_selected(room: RoomInstance)
signal selection_cleared

# Tap detection thresholds (distinguish tap from drag)
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

# Private state
var _rooms: Array[RoomInstance] = []
var _selected_room: RoomInstance = null
var _selection_areas: Dictionary = {}  # room.id -> Area2D

# Tap detection state
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0


# --- Public Methods ---

func register_room(room: RoomInstance) -> void:
	if room == null:
		return

	# Check if room already registered
	for existing_room in _rooms:
		if existing_room.id == room.id:
			return

	_rooms.append(room)
	_create_selection_area(room)
	room_added.emit(room)


func get_all_rooms() -> Array[RoomInstance]:
	return _rooms


func get_room_by_id(id: String) -> RoomInstance:
	for room in _rooms:
		if room.id == id:
			return room
	return null


func select_room(room: RoomInstance) -> void:
	if room == null:
		return

	_selected_room = room
	room_selected.emit(room)


func clear_selection() -> void:
	if _selected_room != null:
		_selected_room = null
		selection_cleared.emit()


func get_selected_room() -> RoomInstance:
	return _selected_room


# --- Private Methods ---

func _create_selection_area(room: RoomInstance) -> void:
	var area := Area2D.new()
	area.name = "SelectionArea_%s" % room.id
	area.input_pickable = true  # CRITICAL - default is false

	var collision := CollisionPolygon2D.new()
	collision.polygon = _room_to_polygon(room)
	area.add_child(collision)

	area.input_event.connect(_on_area_input.bind(room))

	add_child(area)
	_selection_areas[room.id] = area


func _room_to_polygon(room: RoomInstance) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var bbox := room.bounding_box

	# Get the four corners of the bounding box
	var top_left := bbox.position
	var bottom_right := bbox.position + bbox.size

	# Calculate isometric diamond corners using IsometricMath
	# Top corner of diamond (top-left tile in grid space)
	var top := IsometricMath.tile_to_world(top_left)
	# Right corner of diamond (top-right tile in grid space)
	var right := IsometricMath.tile_to_world(Vector2i(bottom_right.x, top_left.y))
	# Bottom corner of diamond (bottom-right tile in grid space)
	var bottom := IsometricMath.tile_to_world(bottom_right)
	# Left corner of diamond (bottom-left tile in grid space)
	var left := IsometricMath.tile_to_world(Vector2i(top_left.x, bottom_right.y))

	# Build polygon clockwise from top
	polygon.append(top)
	polygon.append(right)
	polygon.append(bottom)
	polygon.append(left)

	return polygon


func _on_area_input(_viewport: Node, event: InputEvent, _shape_idx: int, room: RoomInstance) -> void:
	# Handle mouse clicks (desktop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec()
		else:
			var distance:float = event.position.distance_to(_touch_start_pos)
			var duration := Time.get_ticks_msec() - _touch_start_time
			if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
				select_room(room)
		return

	# Handle touch events (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
			_touch_start_time = Time.get_ticks_msec()
		else:
			var distance:float = event.position.distance_to(_touch_start_pos)
			var duration := Time.get_ticks_msec() - _touch_start_time
			if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
				select_room(room)
