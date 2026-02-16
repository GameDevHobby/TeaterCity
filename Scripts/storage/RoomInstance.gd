class_name RoomInstance
extends RefCounted

const SCHEMA_VERSION := 3

signal placement_changed
signal state_changed(old_state: String, new_state: String)

var id: String
var room_type_id: String
var bounding_box: Rect2i
var walls: Array[Vector2i] = []
var doors: Array[DoorPlacement] = []
var furniture: Array[FurniturePlacement] = []
var scheduled_movie_id: String = ""
var scheduled_movie_title: String = ""
var scheduled_movie_genre: String = ""
var scheduled_movie_rating: int = 0
var scheduled_movie_duration: int = 0

# Optional state machine for rooms with timed states (null if room type doesn't use it)
var state_machine: RoomStateMachine = null

# Pending state machine data (set by from_dict, consumed by room type initializer)
var _pending_state_machine_data: Dictionary = {}

## Helper to safely convert JSON numbers (which may be float) to int
static func _to_int(value, default: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(value)
	return default

class DoorPlacement:
	var position: Vector2i
	var direction: int

	func _init(pos: Vector2i, dir: int):
		position = pos
		direction = dir

	func to_dict() -> Dictionary:
		return {
			"position": {"x": position.x, "y": position.y},
			"direction": direction
		}

	static func from_dict(data: Dictionary) -> DoorPlacement:
		var pos_data = data.get("position", {})
		var pos = Vector2i(
			RoomInstance._to_int(pos_data.get("x", 0)) if pos_data is Dictionary else 0,
			RoomInstance._to_int(pos_data.get("y", 0)) if pos_data is Dictionary else 0
		)
		var dir = RoomInstance._to_int(data.get("direction", 0))
		return DoorPlacement.new(pos, dir)

class FurniturePlacement:
	var furniture: FurnitureResource
	var position: Vector2i
	var rotation: int
	var visual_node: Node2D = null  # Reference to visual node for position updates and cleanup

	func _init(furn: FurnitureResource, pos: Vector2i, rot: int = 0):
		furniture = furn
		position = pos
		rotation = rot

	func to_dict() -> Dictionary:
		return {
			"furniture_id": furniture.id if furniture else "",
			"position": {"x": position.x, "y": position.y},
			"rotation": rotation
		}

	static func from_dict(data: Dictionary) -> FurniturePlacement:
		var pos_data = data.get("position", {})
		var pos = Vector2i(
			RoomInstance._to_int(pos_data.get("x", 0)) if pos_data is Dictionary else 0,
			RoomInstance._to_int(pos_data.get("y", 0)) if pos_data is Dictionary else 0
		)
		var furn_id = data.get("furniture_id", "")
		var furn: FurnitureResource = null
		if furn_id != "" and furn_id is String:
			furn = FurnitureRegistry.get_instance().get_furniture(furn_id)
		var rot = RoomInstance._to_int(data.get("rotation", 0))
		return FurniturePlacement.new(furn, pos, rot)

	func get_occupied_tiles() -> Array[Vector2i]:
		if not furniture:
			var tiles: Array[Vector2i] = []
			tiles.append(position)
			return tiles

		return RotationHelper.get_footprint_tiles(position, furniture.size, rotation)

	func get_access_tiles() -> Array[Vector2i]:
		var tiles: Array[Vector2i] = []
		if not furniture:
			return tiles

		# Get rotated access tiles and apply position offset
		var rotated_offsets = furniture.get_rotated_access_tiles(rotation)
		for offset in rotated_offsets:
			tiles.append(position + offset)
		return tiles

	func cleanup_visual() -> void:
		if visual_node and is_instance_valid(visual_node):
			visual_node.queue_free()
		visual_node = null

func _init(new_id: String, new_type_id: String):
	id = new_id
	room_type_id = new_type_id

func add_door(position: Vector2i, direction: int) -> void:
	doors.append(DoorPlacement.new(position, direction))
	placement_changed.emit()

func add_furniture(furn: FurnitureResource, position: Vector2i, rotation: int = 0) -> void:
	furniture.append(FurniturePlacement.new(furn, position, rotation))
	placement_changed.emit()

func get_furniture_count_by_resource(furn: FurnitureResource) -> int:
	var count = 0
	for f in furniture:
		if f.furniture and f.furniture == furn:
			count += 1
	return count

func get_furniture_count(furniture_id: String) -> int:
	var count = 0
	for furn in furniture:
		if furn.furniture and furn.furniture.id == furniture_id:
			count += 1
	return count

func is_tile_occupied(pos: Vector2i) -> bool:
	for furn in furniture:
		if pos in furn.get_occupied_tiles():
			return true
		# Also check access tiles - they need to stay clear
		if pos in furn.get_access_tiles():
			return true
	return false

func get_all_occupied_tiles() -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for furn in furniture:
		for tile in furn.get_occupied_tiles():
			if tile not in tiles:
				tiles.append(tile)
		for tile in furn.get_access_tiles():
			if tile not in tiles:
				tiles.append(tile)
	return tiles

func get_total_cost() -> int:
	var cost = 0
	var room_type = RoomTypeRegistry.get_instance().get_room_type(room_type_id)
	if room_type:
		cost += room_type.base_cost

	cost += walls.size() * 10
	cost += doors.size() * 50

	for furn in furniture:
		if furn.furniture:
			cost += furn.furniture.cost

	return cost

func get_monthly_upkeep() -> int:
	var upkeep = 0

	for furn in furniture:
		if furn.furniture:
			upkeep += furn.furniture.monthly_upkeep

	return upkeep


func has_scheduled_movie() -> bool:
	return scheduled_movie_id != ""


func set_scheduled_movie(movie: MovieResource) -> void:
	if movie == null:
		clear_scheduled_movie()
		return

	scheduled_movie_id = movie.id
	scheduled_movie_title = movie.title
	scheduled_movie_genre = movie.genre
	scheduled_movie_rating = movie.rating
	scheduled_movie_duration = movie.duration
	placement_changed.emit()


func clear_scheduled_movie() -> void:
	scheduled_movie_id = ""
	scheduled_movie_title = ""
	scheduled_movie_genre = ""
	scheduled_movie_rating = 0
	scheduled_movie_duration = 0
	placement_changed.emit()


## Initialize state machine with room-type-specific state definitions.
## Call this after loading, with the state definitions for this room type.
## Returns number of state transitions that occurred during recalculation.
func initialize_state_machine(state_definitions: Dictionary) -> int:
	if state_definitions.is_empty():
		return 0

	if _pending_state_machine_data.is_empty():
		# No saved state - create fresh state machine starting in first defined state
		state_machine = RoomStateMachine.new()
		for state_name in state_definitions:
			var def = state_definitions[state_name]
			state_machine.define_state(def.name, def.duration, def.next_state)
		_connect_state_machine_signal()
		return 0

	# Restore from saved data
	state_machine = RoomStateMachine.from_dict(_pending_state_machine_data, state_definitions)
	_pending_state_machine_data = {}

	if state_machine == null:
		# Recovery: corrupted data, log and reset
		push_warning("RoomInstance %s: Corrupted state machine data, resetting" % id)
		state_machine = RoomStateMachine.new()
		for state_name in state_definitions:
			var def = state_definitions[state_name]
			state_machine.define_state(def.name, def.duration, def.next_state)
		_connect_state_machine_signal()
		return 0

	# Connect state changed signal for forwarding
	_connect_state_machine_signal()

	# Recalculate and count transitions
	var transitions = state_machine.recalculate_from_elapsed()
	return transitions


func _connect_state_machine_signal() -> void:
	if state_machine == null:
		return
	if not state_machine.state_changed.is_connected(_on_state_machine_changed):
		state_machine.state_changed.connect(_on_state_machine_changed)


func _on_state_machine_changed(old_state: String, new_state: String) -> void:
	state_changed.emit(old_state, new_state)
	placement_changed.emit()  # Trigger auto-save

func to_dict() -> Dictionary:
	var doors_arr: Array = []
	for door in doors:
		doors_arr.append(door.to_dict())

	var furniture_arr: Array = []
	for furn in furniture:
		furniture_arr.append(furn.to_dict())

	var walls_arr: Array = []
	for wall in walls:
		walls_arr.append({"x": wall.x, "y": wall.y})

	var dict = {
		"schema_version": SCHEMA_VERSION,
		"id": id,
		"room_type_id": room_type_id,
		"bounding_box": {
			"x": bounding_box.position.x,
			"y": bounding_box.position.y,
			"width": bounding_box.size.x,
			"height": bounding_box.size.y
		},
		"walls": walls_arr,
		"doors": doors_arr,
		"furniture": furniture_arr,
		"scheduled_movie": {
			"id": scheduled_movie_id,
			"title": scheduled_movie_title,
			"genre": scheduled_movie_genre,
			"rating": scheduled_movie_rating,
			"duration": scheduled_movie_duration
		}
	}

	# After furniture serialization
	if state_machine:
		dict["state_machine"] = state_machine.to_dict()

	return dict

static func from_dict(data: Dictionary) -> RoomInstance:
	var version = data.get("schema_version", 1)
	if version > SCHEMA_VERSION:
		push_warning("RoomInstance: Loading data from newer schema version %d (current: %d)" % [version, SCHEMA_VERSION])

	# Validate required fields
	var room_id = data.get("id", "")
	var type_id = data.get("room_type_id", "")
	if not room_id is String or room_id == "":
		push_warning("RoomInstance.from_dict: Missing or invalid 'id' field")
		return null
	if not type_id is String or type_id == "":
		push_warning("RoomInstance.from_dict: Missing or invalid 'room_type_id' field")
		return null

	var room = RoomInstance.new(room_id, type_id)

	# Restore bounding_box with safe access
	var bbox = data.get("bounding_box", {})
	if bbox is Dictionary:
		room.bounding_box = Rect2i(
			_to_int(bbox.get("x", 0)),
			_to_int(bbox.get("y", 0)),
			_to_int(bbox.get("width", 0)),
			_to_int(bbox.get("height", 0))
		)

	# Restore walls (clear and append to preserve typed array)
	room.walls.clear()
	for wall_data in data.get("walls", []):
		if wall_data is Dictionary:
			room.walls.append(Vector2i(
				_to_int(wall_data.get("x", 0)),
				_to_int(wall_data.get("y", 0))
			))

	# Restore doors (clear and append to preserve typed array)
	room.doors.clear()
	for door_data in data.get("doors", []):
		if door_data is Dictionary:
			room.doors.append(DoorPlacement.from_dict(door_data))

	# Restore furniture (clear and append to preserve typed array)
	room.furniture.clear()
	for furn_data in data.get("furniture", []):
		if furn_data is Dictionary:
			room.furniture.append(FurniturePlacement.from_dict(furn_data))

	# Restore scheduled movie payload (safe defaults for older saves)
	var scheduled_data = data.get("scheduled_movie", {})
	if scheduled_data is Dictionary:
		room.scheduled_movie_id = str(scheduled_data.get("id", ""))
		room.scheduled_movie_title = str(scheduled_data.get("title", ""))
		room.scheduled_movie_genre = str(scheduled_data.get("genre", ""))
		room.scheduled_movie_rating = _to_int(scheduled_data.get("rating", 0))
		room.scheduled_movie_duration = _to_int(scheduled_data.get("duration", 0))

	# Store raw state machine data for later configuration by room type
	var sm_data = data.get("state_machine")
	if sm_data != null and sm_data is Dictionary:
		room._pending_state_machine_data = sm_data

	return room
