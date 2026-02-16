extends Node

## RoomManager singleton - tracks completed rooms and handles selection.
## Follows Targets.gd pattern for autoload singleton architecture.

# Signals
signal room_added(room: RoomInstance)
signal room_restored(room: RoomInstance)
signal room_removed(room: RoomInstance)
signal room_selected(room: RoomInstance)
signal selection_cleared
signal room_states_recalculated(transition_count: int)

# Tap detection thresholds (distinguish tap from drag)
const TAP_DISTANCE_THRESHOLD := 20.0  # pixels
const TAP_TIME_THRESHOLD := 300  # milliseconds

# Auto-save configuration
const SAVE_DEBOUNCE_SECONDS := 5.0
const ROOM_SELECTION_AREA_SCENE := preload("res://scripts/room_editing/RoomSelectionArea.tscn")

# Private state
var _rooms: Array[RoomInstance] = []
var _selected_room: RoomInstance = null
var _selection_areas: Dictionary = {}  # room.id -> Area2D

# Tap detection state
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: int = 0

# Auto-save state
var _save_debounce_timer: Timer = null
var _save_pending := false

# Timestamp tracking for clock manipulation detection
var _last_known_timestamp: int = 0
const TIMESTAMP_SAVE_KEY := "last_timestamp"


# --- Lifecycle ---

func _ready() -> void:
	_setup_save_timer()
	# Defer loading until scene tree is ready (allows scene nodes to connect to room_restored first)
	call_deferred("_load_saved_rooms")


func _setup_save_timer() -> void:
	_save_debounce_timer = Timer.new()
	_save_debounce_timer.one_shot = true
	_save_debounce_timer.wait_time = SAVE_DEBOUNCE_SECONDS
	_save_debounce_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_debounce_timer)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			# App going to background (mobile) - save immediately
			_last_known_timestamp = int(Time.get_unix_time_from_system())
			if _save_pending:
				_save_debounce_timer.stop()
				_perform_save()
		NOTIFICATION_APPLICATION_RESUMED:
			# App returned from background - check for clock manipulation and recalculate states
			_handle_app_resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Window close requested (desktop) - save immediately
			if _save_pending:
				_save_debounce_timer.stop()
				_perform_save()


func _load_saved_rooms() -> void:
	var saved_rooms := RoomSerializer.load_rooms()
	for room in saved_rooms:
		# Register without triggering save (we just loaded!)
		if room == null:
			continue

		# Check if room already registered (shouldn't happen, but safe)
		var already_exists := false
		for existing in _rooms:
			if existing.id == room.id:
				already_exists = true
				break

		if not already_exists:
			_rooms.append(room)
			_create_selection_area(room)
			# Connect to placement_changed for future changes
			room.placement_changed.connect(_on_room_changed)
			# Emit signal for visual restoration (RoomBuildController subscribes to this)
			room_restored.emit(room)

	if saved_rooms.size() > 0:
		print("RoomManager: Restored %d rooms from save file" % saved_rooms.size())

	# After all rooms loaded, recalculate states (simulates resume from closed app)
	var total_transitions := 0
	for room in _rooms:
		if room.state_machine:
			total_transitions += room.state_machine.recalculate_from_elapsed()

	if total_transitions > 0:
		room_states_recalculated.emit(total_transitions)
		print("RoomManager: %d state transitions occurred while app was closed" % total_transitions)

	# Initialize timestamp
	_last_known_timestamp = int(Time.get_unix_time_from_system())


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

	# Connect to placement_changed for auto-save
	room.placement_changed.connect(_on_room_changed)

	room_added.emit(room)

	# Schedule save for new room
	_schedule_save()


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


## Remove a room from tracking and clean up associated resources
func unregister_room(room: RoomInstance) -> void:
	if room == null:
		return

	# Remove from _rooms array
	var index = _rooms.find(room)
	if index >= 0:
		_rooms.remove_at(index)

	# Clean up selection Area2D if it exists
	if room.id in _selection_areas:
		var area = _selection_areas[room.id]
		if is_instance_valid(area):
			area.queue_free()
		_selection_areas.erase(room.id)

	# Clear selection if this was the selected room
	if _selected_room == room:
		_selected_room = null
		selection_cleared.emit()

	# Disconnect placement_changed signal to prevent memory leaks
	if room.placement_changed.is_connected(_on_room_changed):
		room.placement_changed.disconnect(_on_room_changed)

	# Emit signal to notify listeners
	room_removed.emit(room)

	# Trigger auto-save
	_schedule_save()


## Disable room selection input (for edit modes that need to capture input)
func disable_selection() -> void:
	for area in _selection_areas.values():
		area.input_pickable = false


## Re-enable room selection input
func enable_selection() -> void:
	for area in _selection_areas.values():
		area.input_pickable = true


## Check if a tile position is inside any room other than the excluded one
func is_tile_in_another_room(tile: Vector2i, exclude_room: RoomInstance) -> bool:
	for room in _rooms:
		if room == exclude_room:
			continue
		if _is_tile_in_room(tile, room):
			return true
	return false


func _is_tile_in_room(tile: Vector2i, room: RoomInstance) -> bool:
	var bbox = room.bounding_box
	if tile.x < bbox.position.x or tile.x >= bbox.position.x + bbox.size.x:
		return false
	if tile.y < bbox.position.y or tile.y >= bbox.position.y + bbox.size.y:
		return false
	return true


# --- Private Methods ---

func _create_selection_area(room: RoomInstance) -> void:
	var area := ROOM_SELECTION_AREA_SCENE.instantiate() as RoomSelectionArea
	area.name = "SelectionArea_%s" % room.id
	area.input_pickable = true  # CRITICAL - default is false
	area.set_selection_polygon(_room_to_polygon(room))

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


func _on_room_changed() -> void:
	_schedule_save()


# --- Auto-save Methods ---

func _schedule_save() -> void:
	_save_pending = true
	# Reset timer if already running (debounce)
	if _save_debounce_timer.is_stopped():
		_save_debounce_timer.start()
	# Timer already running, it will save when it fires


func _on_save_timer_timeout() -> void:
	if _save_pending:
		_save_pending = false
		_perform_save()


func _perform_save() -> void:
	var success := RoomSerializer.save_rooms(_rooms)
	if success:
		print("RoomManager: Auto-saved %d rooms" % _rooms.size())
	else:
		push_error("RoomManager: Auto-save failed!")


# --- Resume & Recalculation ---

func _handle_app_resume() -> void:
	var current_time = int(Time.get_unix_time_from_system())

	# Check for backward clock manipulation
	if _last_known_timestamp > 0 and current_time < _last_known_timestamp:
		var jump_seconds = _last_known_timestamp - current_time
		print("RoomManager: Backward clock jump detected (%d seconds). Ignoring." % jump_seconds)
		# Don't update _last_known_timestamp - keep the forward progress
	else:
		_last_known_timestamp = current_time

	# Recalculate all room states
	var total_transitions = _recalculate_all_room_states()

	if total_transitions > 0:
		room_states_recalculated.emit(total_transitions)
		print("RoomManager: %d state transitions occurred while app was backgrounded" % total_transitions)


func _recalculate_all_room_states() -> int:
	var total_transitions := 0
	for room in _rooms:
		if room.state_machine:
			var transitions = room.state_machine.recalculate_from_elapsed()
			total_transitions += transitions
	return total_transitions
