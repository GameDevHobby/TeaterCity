## One-time setup script - run once from editor
extends Node
class_name PopReg

func _ready():
	populate_room_type_registry()
	populate_furniture_registry()
	print("✓ Registries populated!")
	get_tree().quit()

func populate_room_type_registry():
	var registry = RoomTypeRegistry.new()
	
	var room_type_names = [
		"theater_auditorium",
		"bathroom",
		"snack_bar",
		"ticket_counter",
		"lobby"
	]
	
	for name in room_type_names:
		var path = "res://data/resources/room_types/%s.tres" % name
		var resource = ResourceLoader.load(path)
		if resource:
			registry.room_types[name] = resource
	
	ResourceSaver.save(registry, "res://data/resources/configs/room_type_registry.tres")

func populate_furniture_registry():
	var registry = FurnitureRegistry.new()
	
	var furniture_names = [
		"seat", "screen", "speaker", "toilet", "sink", "stall",
		"counter", "display_case", "register", "seating_bench",
		"ticket_window", "mirror", "dispenser"
	]
	
	for name in furniture_names:
		var path = "res://data/resources/furniture/%s.tres" % name
		var resource = ResourceLoader.load(path)
		if resource:
			registry.furniture_items[name] = resource
	
	ResourceSaver.save(registry, "res://data/resources/configs/furniture_registry.tres")
