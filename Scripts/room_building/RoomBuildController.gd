class_name RoomBuildController
extends Node

signal room_completed(room: RoomInstance)
signal state_changed(new_state: String)

@export var tilemap_layer: TileMapLayer
@export var ui: RoomBuildUI
@export var furniture_visuals: Node2D

var current_room: RoomInstance
var current_room_type: RoomTypeResource
var state_name: String = "idle"

var _wall_op = WallOperation.new()
var _door_op = DoorOperation.new()
var _validation_op = ValidationOperation.new()
var _collision_op = CollisionOperation.new()
var _furniture_op: FurnitureOperation
var _navigation_op = NavigationOperation.new()

var _room_counter: int = 0

func _ready() -> void:
	# Initialize registries
	RoomTypeRegistry.get_instance()
	FurnitureRegistry.get_instance()

	# Initialize furniture operation
	_furniture_op = FurnitureOperation.new()

	# Connect UI signals
	if ui:
		ui.room_type_selected.connect(_on_room_type_selected)
		ui.box_draw_completed.connect(finish_box_draw)
		ui.door_placed.connect(_on_door_placed)
		ui.doors_placement_completed.connect(_on_doors_done)
		ui.furniture_placed.connect(_on_furniture_placed)
		ui.complete_button_pressed.connect(_on_complete_pressed)
	else:
		push_warning("RoomBuildController: UI not found!")

func start_build_mode() -> void:
	if ui:
		ui.show_all()
		ui.show_room_type_selection()
	state_changed.emit("select_room")

func end_build_mode() -> void:
	current_room = null
	current_room_type = null
	state_name = "idle"
	if ui:
		ui.end_all_modes()
		ui.hide_all()
	state_changed.emit("idle")

func _on_room_type_selected(room_type_id: String) -> void:
	_room_counter += 1
	current_room = RoomInstance.new("room_%d" % _room_counter, room_type_id)
	current_room_type = RoomTypeRegistry.get_instance().get_room_type(room_type_id)
	state_name = "draw_box"
	if ui:
		ui.show_drawing_instructions(current_room_type)
	state_changed.emit("draw_box")

func finish_box_draw(start: Vector2i, end: Vector2i) -> void:
	# Calculate proper bounding box from start/end positions
	var min_pos = Vector2i(mini(start.x, end.x), mini(start.y, end.y))
	var max_pos = Vector2i(maxi(start.x, end.x), maxi(start.y, end.y))
	var box = Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE)

	# Validate size before proceeding (allow swapped width/height)
	if current_room_type:
		var min_s = current_room_type.min_size
		var max_s = current_room_type.max_size
		# Check both orientations
		var normal_valid = box.size.x >= min_s.x and box.size.y >= min_s.y and box.size.x <= max_s.x and box.size.y <= max_s.y
		var swapped_valid = box.size.x >= min_s.y and box.size.y >= min_s.x and box.size.x <= max_s.y and box.size.y <= max_s.x
		if not normal_valid and not swapped_valid:
			var error_msg = "Invalid size! Required: %dx%d to %dx%d (either orientation)" % [min_s.x, min_s.y, max_s.x, max_s.y]
			if ui:
				ui.show_validation_errors([error_msg])
				# Reset to drawing mode so user can try again
				ui.show_drawing_instructions(current_room_type)
			return  # Don't proceed with invalid size

	current_room.bounding_box = box

	# Check if this room type has walls
	if current_room_type and current_room_type.has_walls:
		# Generate walls and transition to door placement
		current_room.walls = _wall_op.generate_walls(box)
		state_name = "place_doors"
		if ui:
			ui.show_door_instructions(current_room, current_room_type)
		state_changed.emit("place_doors")
	else:
		# No walls - skip directly to furniture placement
		_transition_to_furniture_placement()

func _on_door_placed(position: Vector2i) -> void:
	if _door_op.is_valid_door_position(position, current_room):
		var direction = _door_op.determine_door_direction(position, current_room)
		current_room.add_door(position, direction)

func _on_doors_done() -> void:
	_transition_to_furniture_placement()

func _transition_to_furniture_placement() -> void:
	state_name = "place_furniture"
	if ui:
		ui.show_furniture_panel(current_room, current_room_type)
	state_changed.emit("place_furniture")

func _on_furniture_placed(furniture: FurnitureResource, position: Vector2i, rotation: int) -> void:
	if not furniture:
		return

	# Use collision operation to validate placement
	var result = _collision_op.can_place_furniture(furniture, position, rotation, current_room)
	if not result.can_place:
		return

	# Add furniture to room
	current_room.add_furniture(furniture, position, rotation)

	# Update UI counts
	if ui:
		ui.update_furniture_counts()

func _on_complete_pressed() -> void:
	var result = _validation_op.validate_complete(current_room)

	if not result.is_valid:
		if ui:
			ui.show_validation_errors(result.errors)
		return

	# Create wall visuals (only for rooms with walls)
	if current_room_type and current_room_type.has_walls:
		_wall_op.create_wall_visuals(current_room, tilemap_layer)
		for door in current_room.doors:
			_door_op.create_door_visuals(door, tilemap_layer)

	# Create furniture visuals
	for furn in current_room.furniture:
		_furniture_op.create_furniture_visual(furn, furniture_visuals)

	# Update navigation
	_navigation_op.update_room_navigation(current_room, tilemap_layer)

	# Notify patrons to recalculate their paths
	Targets.notify_navigation_changed()

	# Clean up UI
	if ui:
		ui.hide_furniture_panel()
		ui.end_all_modes()

	room_completed.emit(current_room)
	current_room = null
	current_room_type = null
	state_name = "idle"
	state_changed.emit("idle")
