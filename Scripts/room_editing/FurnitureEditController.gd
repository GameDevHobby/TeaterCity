class_name FurnitureEditController
extends Control

## Controller for furniture editing mode.
## Manages furniture selection via tap detection on furniture footprints.
## Follows RoomManager pattern for Area2D tap detection.

# Signals
signal furniture_selected(room: RoomInstance, furniture: RoomInstance.FurniturePlacement)
signal furniture_deselected
signal furniture_drag_preview(position: Vector2i, is_valid: bool)
signal furniture_drag_ended
signal mode_exited

# Tap detection thresholds (same as RoomManager)
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds
const MIN_TAP_TARGET_SIZE := 44.0  # pixels (mobile accessibility guideline)

# State
var _active: bool = false
var _current_room: RoomInstance = null
var _selected_furniture: RoomInstance.FurniturePlacement = null
var _furniture_areas: Dictionary = {}  # furniture index -> Area2D

# Tap detection state
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0

# Drag state
var _dragging: bool = false
var _drag_start_tile: Vector2i = Vector2i.ZERO
var _drag_offset: Vector2i = Vector2i.ZERO  # Offset from furniture position to tap point
var _preview_position: Vector2i = Vector2i.ZERO
var _preview_valid: bool = false
var _original_position: Vector2i = Vector2i.ZERO  # For revert on invalid drop

# Operation helpers
var _collision_operation: CollisionOperation = null


# --- Public Methods ---

func enter_edit_mode(room: RoomInstance) -> void:
	if room == null:
		return

	_active = true
	_current_room = room
	_selected_furniture = null

	if _collision_operation == null:
		_collision_operation = CollisionOperation.new()

	_create_furniture_areas(room)


func exit_edit_mode() -> void:
	_clear_furniture_areas()
	_selected_furniture = null
	_current_room = null
	_active = false
	mode_exited.emit()


func get_selected_furniture() -> RoomInstance.FurniturePlacement:
	return _selected_furniture


func get_current_room() -> RoomInstance:
	return _current_room


func is_active() -> bool:
	return _active


func select_furniture(furniture: RoomInstance.FurniturePlacement) -> void:
	if not _active or _current_room == null:
		return

	# Verify furniture belongs to current room
	if furniture not in _current_room.furniture:
		return

	_selected_furniture = furniture
	furniture_selected.emit(_current_room, furniture)


func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	return IsometricMath.screen_to_tile(screen_pos, get_viewport())


# --- Private Methods ---

func _create_furniture_areas(room: RoomInstance) -> void:
	_clear_furniture_areas()

	for i in range(room.furniture.size()):
		var furn: RoomInstance.FurniturePlacement = room.furniture[i]

		var area := Area2D.new()
		area.name = "FurnitureArea_%d" % i
		area.input_pickable = true  # CRITICAL - default is false

		var collision := CollisionPolygon2D.new()
		collision.polygon = _furniture_to_polygon(furn)
		area.add_child(collision)

		area.input_event.connect(_on_furniture_input.bind(i, furn))

		add_child(area)
		_furniture_areas[i] = area


func _clear_furniture_areas() -> void:
	for index in _furniture_areas:
		var area: Area2D = _furniture_areas[index]
		if area and is_instance_valid(area):
			area.queue_free()
	_furniture_areas.clear()


func _furniture_to_polygon(furn: RoomInstance.FurniturePlacement) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var occupied_tiles := furn.get_occupied_tiles()

	if occupied_tiles.is_empty():
		return polygon

	# Calculate bounding box of occupied tiles
	var min_tile := occupied_tiles[0]
	var max_tile := occupied_tiles[0]

	for tile in occupied_tiles:
		min_tile.x = mini(min_tile.x, tile.x)
		min_tile.y = mini(min_tile.y, tile.y)
		max_tile.x = maxi(max_tile.x, tile.x)
		max_tile.y = maxi(max_tile.y, tile.y)

	# Calculate isometric diamond corners for the bounding box
	# Top corner (min_tile position)
	var top := IsometricMath.tile_to_world(min_tile)
	# Right corner (max_x, min_y)
	var right := IsometricMath.tile_to_world(Vector2i(max_tile.x + 1, min_tile.y))
	# Bottom corner (max_tile + 1)
	var bottom := IsometricMath.tile_to_world(Vector2i(max_tile.x + 1, max_tile.y + 1))
	# Left corner (min_x, max_y + 1)
	var left := IsometricMath.tile_to_world(Vector2i(min_tile.x, max_tile.y + 1))

	# Build polygon clockwise from top
	polygon.append(top)
	polygon.append(right)
	polygon.append(bottom)
	polygon.append(left)

	# Check if polygon needs expansion for minimum tap target
	polygon = _ensure_minimum_tap_target(polygon)

	return polygon


func _ensure_minimum_tap_target(polygon: PackedVector2Array) -> PackedVector2Array:
	if polygon.size() < 4:
		return polygon

	# Calculate bounding box of polygon
	var min_pos := polygon[0]
	var max_pos := polygon[0]

	for point in polygon:
		min_pos.x = minf(min_pos.x, point.x)
		min_pos.y = minf(min_pos.y, point.y)
		max_pos.x = maxf(max_pos.x, point.x)
		max_pos.y = maxf(max_pos.y, point.y)

	var width := max_pos.x - min_pos.x
	var height := max_pos.y - min_pos.y

	# If already large enough, return as-is
	if width >= MIN_TAP_TARGET_SIZE and height >= MIN_TAP_TARGET_SIZE:
		return polygon

	# Calculate center of polygon
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= polygon.size()

	# Calculate scale factor needed
	var scale_x := MIN_TAP_TARGET_SIZE / width if width > 0 else 1.0
	var scale_y := MIN_TAP_TARGET_SIZE / height if height > 0 else 1.0
	var scale := maxf(scale_x, scale_y)

	# Only scale up, never down
	if scale <= 1.0:
		return polygon

	# Scale polygon from center
	var expanded := PackedVector2Array()
	for point in polygon:
		var offset := point - center
		expanded.append(center + offset * scale)

	return expanded


func _on_furniture_input(_viewport: Node, event: InputEvent, _shape_idx: int, index: int, furn: RoomInstance.FurniturePlacement) -> void:
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
				_select_furniture(furn)
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
				_select_furniture(furn)


func _select_furniture(furn: RoomInstance.FurniturePlacement) -> void:
	_selected_furniture = furn
	furniture_selected.emit(_current_room, furn)


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	var is_tap := false
	var tap_pos := Vector2.ZERO

	# Handle mouse release (desktop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var distance: float = event.position.distance_to(_touch_start_pos)
		var duration := Time.get_ticks_msec() - _touch_start_time
		if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
			is_tap = true
			tap_pos = event.position

	# Handle touch release (mobile)
	if event is InputEventScreenTouch and not event.pressed:
		var distance: float = event.position.distance_to(_touch_start_pos)
		var duration := Time.get_ticks_msec() - _touch_start_time
		if distance < TAP_DISTANCE_THRESHOLD and duration < TAP_TIME_THRESHOLD:
			is_tap = true
			tap_pos = event.position

	# Track start position for tap detection in _unhandled_input
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_touch_start_pos = event.position
		_touch_start_time = Time.get_ticks_msec()

	if event is InputEventScreenTouch and event.pressed:
		_touch_start_pos = event.position
		_touch_start_time = Time.get_ticks_msec()

	# If tap outside furniture areas, deselect
	if is_tap and _selected_furniture != null:
		_selected_furniture = null
		furniture_deselected.emit()
		get_viewport().set_input_as_handled()
