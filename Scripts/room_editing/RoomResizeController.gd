class_name RoomResizeController
extends Control

## Controller for room resize mode.
## Manages box drawing input to define new room bounds.
## Follows DoorEditController pattern for edit mode management.

# Signals
signal resize_started(room: RoomInstance)
signal preview_updated(new_box: Rect2i, validation: RefCounted)  # validation is ResizeValidationResult
signal resize_completed(room: RoomInstance)
signal resize_cancelled
signal mode_exited
signal door_placement_needed(room: RoomInstance)  # After resize, doors must be re-placed

# State machine
enum State { IDLE, DRAWING }
var _state: State = State.IDLE
var _current_room: RoomInstance = null
var _original_box: Rect2i  # Store original in case of cancel

# Drag state (same pattern as RoomBuildUI)
var _draw_start: Vector2i = Vector2i.ZERO
var _current_mouse_pos: Vector2i = Vector2i.ZERO
var _is_dragging: bool = false

# Validation state
var _resize_op: ResizeOperation = ResizeOperation.new()
var _last_validation: ResizeOperation.ResizeValidationResult = null
var _room_manager: Node = RoomManager
var _exterior_walls: Array[Vector2i] = []
var _wall_tilemap: TileMapLayer = null
var _nav_tilemap: TileMapLayer = null


# --- Lifecycle ---

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE  # Don't block input


func _input(event: InputEvent) -> void:
	if _state != State.DRAWING:
		return

	# Handle box drawing - same pattern as RoomBuildUI lines 122-140
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_draw_start = _screen_to_tile(event.global_position)
			_current_mouse_pos = _draw_start
			_is_dragging = true
			_update_preview()
			queue_redraw()
		elif _is_dragging:
			_is_dragging = false
			_try_commit_resize()
	elif event is InputEventMouseMotion and _is_dragging:
		_current_mouse_pos = _screen_to_tile(event.global_position)
		_update_preview()
		queue_redraw()

	# Handle touch events (mobile)
	if event is InputEventScreenTouch:
		if event.pressed:
			_draw_start = _screen_to_tile(event.position)
			_current_mouse_pos = _draw_start
			_is_dragging = true
			_update_preview()
			queue_redraw()
		elif _is_dragging:
			_is_dragging = false
			_try_commit_resize()
	elif event is InputEventScreenDrag and _is_dragging:
		_current_mouse_pos = _screen_to_tile(event.position)
		_update_preview()
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _state == State.IDLE:
		return

	# Exit resize mode with Escape key or ui_cancel action
	if event.is_action_pressed("ui_cancel"):
		exit_resize_mode()
		get_viewport().set_input_as_handled()


# --- Coordinate Conversion ---

func _screen_to_tile(screen_pos: Vector2) -> Vector2i:
	return IsometricMath.screen_to_tile(screen_pos, get_viewport())


# --- Preview Update ---

func _update_preview() -> void:
	var preview_box = _get_preview_box()
	_last_validation = _resize_op.validate_resize(_current_room, preview_box, _room_manager)
	preview_updated.emit(preview_box, _last_validation)


func _get_preview_box() -> Rect2i:
	var min_tile = Vector2i(
		mini(_draw_start.x, _current_mouse_pos.x),
		mini(_draw_start.y, _current_mouse_pos.y)
	)
	var max_tile = Vector2i(
		maxi(_draw_start.x, _current_mouse_pos.x),
		maxi(_draw_start.y, _current_mouse_pos.y)
	)
	# Create Rect2i from min to max (size is max - min + 1)
	return Rect2i(min_tile, max_tile - min_tile + Vector2i.ONE)


# --- Commit Resize ---

func _try_commit_resize() -> void:
	if _last_validation == null or not _last_validation.is_valid:
		# Invalid - don't commit, show error feedback
		# User can try again or cancel
		queue_redraw()
		return

	var new_box = _get_preview_box()

	# Execute the resize
	_resize_op.execute_resize(_current_room, new_box, _wall_tilemap, _nav_tilemap, _room_manager, _exterior_walls)

	# Emit completion
	resize_completed.emit(_current_room)

	# Doors need to be re-placed (requirement EDIT-03)
	door_placement_needed.emit(_current_room)

	# Exit drawing state but DON'T emit mode_exited - door placement will handle that
	_state = State.IDLE
	_is_dragging = false
	queue_redraw()


# --- Public API ---

func enter_resize_mode(room: RoomInstance) -> void:
	if room == null:
		return

	_current_room = room
	_original_box = room.bounding_box
	_state = State.DRAWING
	_is_dragging = false
	_last_validation = null
	resize_started.emit(room)
	queue_redraw()


func exit_resize_mode() -> void:
	_state = State.IDLE
	_current_room = null
	_is_dragging = false
	_last_validation = null
	resize_cancelled.emit()
	mode_exited.emit()
	queue_redraw()


func is_active() -> bool:
	return _state != State.IDLE


func get_current_room() -> RoomInstance:
	return _current_room


func get_preview_box() -> Rect2i:
	if not _is_dragging:
		return Rect2i()
	return _get_preview_box()


func get_last_validation() -> ResizeOperation.ResizeValidationResult:
	return _last_validation


func set_exterior_walls(walls: Array[Vector2i]) -> void:
	_exterior_walls = walls


func set_wall_tilemap(tilemap: TileMapLayer) -> void:
	_wall_tilemap = tilemap


func set_nav_tilemap(tilemap: TileMapLayer) -> void:
	_nav_tilemap = tilemap
