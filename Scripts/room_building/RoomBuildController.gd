class_name RoomBuildController
extends Node

signal room_completed(room: RoomInstance)
signal state_changed(new_state: String)

@export var tilemap_layer: TileMapLayer
@export_node_path("RoomBuildUI") var ui_path: NodePath
@onready var ui: RoomBuildUI = get_node_or_null(ui_path) if ui_path else get_node_or_null("../UILayer/RoomBuildUI")

var current_room: RoomInstance
var state_name: String = "idle"

var wall_op = WallOperation.new()
var door_op = DoorOperation.new()
var validation_op = ValidationOperation.new()

var _room_counter: int = 0

func _ready() -> void:
	# Find UI if not set via export
	if not ui:
		ui = get_node_or_null("../UILayer/RoomBuildUI")
	
	# Initialize registries
	RoomTypeRegistry.get_instance()
	FurnitureRegistry.get_instance()
	
	# Connect UI signals
	if ui:
		ui.room_type_selected.connect(_on_room_type_selected)
		ui.box_draw_completed.connect(finish_box_draw)
		ui.door_placed.connect(_on_door_placed)
		ui.complete_pressed.connect(_on_complete_pressed)
	else:
		push_warning("RoomBuildController: UI not found!")

func start_build_mode() -> void:
	if ui:
		ui.show_all()
		ui.show_room_type_selection()
	state_changed.emit("select_room")

func end_build_mode() -> void:
	current_room = null
	state_name = "idle"
	if ui:
		ui.hide_all()
	state_changed.emit("idle")

func _on_room_type_selected(room_type_id: String) -> void:
	_room_counter += 1
	current_room = RoomInstance.new("room_%d" % _room_counter, room_type_id)
	state_name = "draw_box"
	if ui:
		ui.show_drawing_instructions()
	state_changed.emit("draw_box")

func finish_box_draw(start: Vector2i, end: Vector2i) -> void:
	var box = Rect2i(start, (end - start).abs())
	current_room.bounding_box = box
	current_room.walls = wall_op.generate_walls(box)
	
	state_name = "place_doors"
	if ui:
		ui.show_door_instructions()
	state_changed.emit("place_doors")

func _on_door_placed(position: Vector2i) -> void:
	if door_op.is_valid_door_position(position, current_room):
		var direction = door_op.determine_door_direction(position, current_room)
		current_room.add_door(position, direction)

func _on_complete_pressed() -> void:
	var result = validation_op.validate_complete(current_room)
	
	if not result.is_valid:
		if ui:
			ui.show_validation_errors(result.errors)
		return
	
	# Create visuals
	wall_op.create_wall_visuals(current_room, tilemap_layer)
	for door in current_room.doors:
		door_op.create_door_visuals(door, tilemap_layer)
	
	room_completed.emit(current_room)
	state_name = "idle"
	state_changed.emit("idle")
