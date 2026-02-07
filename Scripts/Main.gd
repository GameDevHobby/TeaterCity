class_name Main
extends Node2D

@export var room_build_manager: RoomBuildController
@export var camera: PinchPanCamera
@export var build_button: Button

## Exterior wall positions scanned from tilemap at startup.
## These walls exist in the scene and should never be deleted.
var _exterior_walls: Array[Vector2i] = []

# Autoload reference (avoids static analysis issues in Godot 4.5)
@onready var _room_manager: Node = get_node("/root/RoomManager")

var _build_mode_active = false
var _furniture_controller: FurnitureEditController = null
var _furniture_list_panel: FurnitureListPanel = null
var _door_edit_controller: DoorEditController = null
var _door_edit_highlight: DoorEditHighlight = null
var _room_edit_menu: RoomEditMenu = null
var _door_edit_done_button: Button = null
var _deletion_op: DeletionOperation = null
var _resize_controller: RoomResizeController = null
var _resize_highlight: RoomResizeHighlight = null
var _resize_cancel_button: Button = null

func _ready() -> void:
	# Scan exterior walls FIRST, before any rooms are loaded/restored
	_scan_exterior_walls()

	# Pass exterior walls to room build controller (prevents doors on exterior)
	room_build_manager.set_exterior_walls(_exterior_walls)

	room_build_manager.room_completed.connect(_on_room_completed)

	# Connect to RoomManager selection signals for future menu handling
	_room_manager.room_selected.connect(_on_room_selected)

	# Create selection highlight overlay in its own CanvasLayer for screen-space rendering
	# CanvasLayer ensures the Control draws in screen space (matching tile_to_screen coords)
	var selection_layer = CanvasLayer.new()
	selection_layer.name = "SelectionHighlightLayer"
	selection_layer.layer = 0  # Same layer as game world, but rendered after
	add_child(selection_layer)

	var selection_highlight = RoomSelectionHighlight.new()
	selection_highlight.name = "SelectionHighlight"
	selection_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Don't block input
	selection_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)  # Cover full screen
	selection_layer.add_child(selection_highlight)

	# Create edit menu CanvasLayer (above selection highlight)
	var edit_menu_layer = CanvasLayer.new()
	edit_menu_layer.name = "EditMenuLayer"
	edit_menu_layer.layer = 1  # Above selection highlight (layer 0)
	add_child(edit_menu_layer)

	# Create RoomEditMenu instance
	_room_edit_menu = RoomEditMenu.new()
	_room_edit_menu.name = "RoomEditMenu"
	edit_menu_layer.add_child(_room_edit_menu)

	# Create DeletionOperation
	_deletion_op = DeletionOperation.new()

	# Connect edit menu signals to handlers
	_room_edit_menu.edit_furniture_pressed.connect(_on_edit_furniture_requested)
	_room_edit_menu.edit_room_pressed.connect(_on_edit_room_requested)
	_room_edit_menu.room_type_action_pressed.connect(_on_room_type_action_requested)
	_room_edit_menu.delete_room_pressed.connect(_on_delete_room_requested)
	_room_edit_menu.resize_room_pressed.connect(_on_resize_room_requested)

	# Create furniture editing CanvasLayer (same layer as room selection for correct z-order)
	var furniture_edit_layer = CanvasLayer.new()
	furniture_edit_layer.name = "FurnitureEditLayer"
	furniture_edit_layer.layer = 0  # Same layer as SelectionHighlightLayer
	add_child(furniture_edit_layer)

	# Create FurnitureEditController
	_furniture_controller = FurnitureEditController.new()
	_furniture_controller.name = "FurnitureEditController"
	_furniture_controller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_furniture_controller.set_anchors_preset(Control.PRESET_FULL_RECT)
	furniture_edit_layer.add_child(_furniture_controller)

	# Create FurnitureSelectionHighlight
	var furniture_highlight = FurnitureSelectionHighlight.new()
	furniture_highlight.name = "FurnitureSelectionHighlight"
	furniture_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	furniture_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	furniture_edit_layer.add_child(furniture_highlight)
	furniture_highlight.set_controller(_furniture_controller)

	# Connect furniture controller mode_exited signal
	_furniture_controller.mode_exited.connect(_on_furniture_edit_exited)

	# Create furniture list panel (in EditMenuLayer since it's screen-space UI)
	_furniture_list_panel = FurnitureListPanel.new()
	_furniture_list_panel.name = "FurnitureListPanel"
	edit_menu_layer.add_child(_furniture_list_panel)
	_furniture_list_panel.set_controller(_furniture_controller)

	# Connect list panel signals
	_furniture_list_panel.furniture_item_selected.connect(_on_furniture_list_item_selected)
	_furniture_list_panel.furniture_delete_requested.connect(_on_furniture_delete_requested)
	_furniture_list_panel.furniture_selected_for_add.connect(_on_furniture_selected_for_add)
	_furniture_list_panel.placement_cancelled.connect(_on_placement_cancelled)
	_furniture_list_panel.done_pressed.connect(_on_furniture_edit_done)

	# Connect controller placement signals
	_furniture_controller.furniture_added.connect(_on_furniture_added)
	_furniture_controller.placement_preview_updated.connect(_on_placement_preview_updated)

	# Create door editing CanvasLayer (same layer as room selection for correct z-order)
	var door_edit_layer = CanvasLayer.new()
	door_edit_layer.name = "DoorEditLayer"
	door_edit_layer.layer = 0  # Same layer as SelectionHighlightLayer
	add_child(door_edit_layer)

	# Create DoorEditController
	_door_edit_controller = DoorEditController.new()
	_door_edit_controller.name = "DoorEditController"
	_door_edit_controller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_edit_controller.set_anchors_preset(Control.PRESET_FULL_RECT)
	door_edit_layer.add_child(_door_edit_controller)

	# Create DoorEditHighlight
	_door_edit_highlight = DoorEditHighlight.new()
	_door_edit_highlight.name = "DoorEditHighlight"
	_door_edit_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_edit_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	door_edit_layer.add_child(_door_edit_highlight)
	_door_edit_highlight.set_controller(_door_edit_controller)

	# Connect door edit controller signals
	_door_edit_controller.door_added.connect(_on_door_added)
	_door_edit_controller.door_removed.connect(_on_door_removed)
	_door_edit_controller.door_add_failed.connect(_on_door_add_failed)
	_door_edit_controller.door_remove_failed.connect(_on_door_remove_failed)
	_door_edit_controller.mode_exited.connect(_on_door_edit_mode_exited)

	# Create Done button for door edit mode (in EditMenuLayer for screen-space UI)
	_door_edit_done_button = Button.new()
	_door_edit_done_button.name = "DoorEditDoneButton"
	_door_edit_done_button.text = "Done"
	_door_edit_done_button.custom_minimum_size = Vector2(70, 40)
	UIStyleHelper.apply_button_style(_door_edit_done_button)
	_door_edit_done_button.pressed.connect(_on_door_edit_done_pressed)
	edit_menu_layer.add_child(_door_edit_done_button)
	_door_edit_done_button.hide()  # Hidden until door edit mode

	# Create resize editing CanvasLayer (same layer as room selection)
	var resize_edit_layer = CanvasLayer.new()
	resize_edit_layer.name = "ResizeEditLayer"
	resize_edit_layer.layer = 0  # Same layer as SelectionHighlightLayer
	add_child(resize_edit_layer)

	# Create RoomResizeController
	_resize_controller = RoomResizeController.new()
	_resize_controller.name = "RoomResizeController"
	_resize_controller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_controller.set_anchors_preset(Control.PRESET_FULL_RECT)
	resize_edit_layer.add_child(_resize_controller)

	# Create RoomResizeHighlight
	_resize_highlight = RoomResizeHighlight.new()
	_resize_highlight.name = "RoomResizeHighlight"
	_resize_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	resize_edit_layer.add_child(_resize_highlight)
	_resize_highlight.set_controller(_resize_controller)

	# Connect resize controller signals
	_resize_controller.resize_completed.connect(_on_resize_completed)
	_resize_controller.door_placement_needed.connect(_on_resize_door_placement_needed)
	_resize_controller.mode_exited.connect(_on_resize_mode_exited)

	# Create Cancel button for resize mode (in EditMenuLayer for screen-space UI)
	_resize_cancel_button = Button.new()
	_resize_cancel_button.name = "ResizeCancelButton"
	_resize_cancel_button.text = "Cancel"
	_resize_cancel_button.custom_minimum_size = Vector2(80, 40)
	UIStyleHelper.apply_button_style(_resize_cancel_button)
	_resize_cancel_button.pressed.connect(_on_resize_cancel_pressed)
	edit_menu_layer.add_child(_resize_cancel_button)
	_resize_cancel_button.hide()  # Hidden until resize mode


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_build"):
		_on_build_button_pressed()

	# Deselect room when tapping empty space (touch release not consumed by Area2D)
	if event is InputEventScreenTouch and not event.pressed:
		# If we get here, no room area consumed the event
		# Area2D.input_event fires BEFORE _unhandled_input
		if _room_manager.get_selected_room():
			_room_manager.clear_selection()

func _on_build_button_pressed() -> void:
	_build_mode_active = !_build_mode_active
	if _build_mode_active:
		room_build_manager.start_build_mode()
		camera.enable_pinch_pan = false  # Disable camera panning in build mode
		if build_button:
			build_button.text = "X"
	else:
		_exit_build_mode()

func _on_room_completed(_room: RoomInstance) -> void:
	_exit_build_mode()


func _on_room_selected(room: RoomInstance) -> void:
	# RoomEditMenu handles showing the menu via its own signal connection
	print("Room selected: ", room.id)


func _on_edit_furniture_requested(room: RoomInstance) -> void:
	print("Entering furniture edit mode: ", room.id)
	# Hide room edit menu while in furniture edit mode
	# (RoomEditMenu hides itself when selection_cleared fires)
	_room_manager.clear_selection()
	camera.enable_pinch_pan = false  # Disable camera panning during furniture edit
	_furniture_controller.enter_edit_mode(room)
	_furniture_list_panel.show_for_room(room)  # Show list panel


func _on_edit_room_requested(room: RoomInstance) -> void:
	print("Entering door edit mode: ", room.id)

	# Exit furniture edit if active
	if _furniture_controller and _furniture_controller.is_active():
		_furniture_controller.exit_edit_mode()

	# Hide room menu
	_room_edit_menu.hide()

	# Clear room selection (menu already hidden)
	_room_manager.clear_selection()

	# Disable room selection input so wall tiles can receive taps
	_room_manager.disable_selection()

	# Disable camera panning during door edit
	camera.enable_pinch_pan = false

	# Pass exterior walls to controller (cannot place doors on exterior)
	_door_edit_controller.set_exterior_walls(_exterior_walls)

	# Enter door edit mode
	_door_edit_controller.enter_edit_mode(room)
	_door_edit_highlight.queue_redraw()

	# Show Done button positioned near room
	_door_edit_done_button.show()
	_position_door_edit_button(room)


func _on_room_type_action_requested(room: RoomInstance) -> void:
	print("Room type action requested: ", room.id, " type: ", room.room_type_id)


func _on_delete_room_requested(room: RoomInstance) -> void:
	print("Deleting room: ", room.id)

	# Get tilemap references
	var wall_layer = room_build_manager.get_wall_tilemap_layer()

	# 1. Delete furniture visuals (calls cleanup_visual -> queue_free)
	_deletion_op.delete_furniture_visuals(room)

	# 2. Delete door visuals (erase door tiles)
	if wall_layer:
		_deletion_op.delete_door_visuals(room, wall_layer)

	# 3. Delete wall visuals (ONLY non-shared tiles, preserve exterior)
	if wall_layer:
		_deletion_op.delete_wall_visuals(room, wall_layer, _room_manager, _exterior_walls)

	# 4. Restore floor tiles where walls were deleted (for navigation)
	if wall_layer:
		_deletion_op.restore_room_floor_tiles(room, wall_layer, _room_manager, _exterior_walls)

	# 5. Unregister from RoomManager (cleans up Area2D, triggers auto-save)
	_room_manager.unregister_room(room)

	# 6. Clear selection (menu already hidden by RoomEditMenu)
	_room_manager.clear_selection()

	# 7. Notify patrons to recalculate paths (AFTER all changes complete)
	Targets.notify_navigation_changed()

	print("Room deleted: ", room.id)


func _on_resize_room_requested(room: RoomInstance) -> void:
	print("Entering resize mode: ", room.id)

	# Hide room menu
	_room_edit_menu.hide()

	# Clear room selection
	_room_manager.clear_selection()

	# Disable room selection input during resize
	_room_manager.disable_selection()

	# Disable camera panning during resize
	camera.enable_pinch_pan = false

	# Pass exterior walls and tilemaps to controller
	_resize_controller.set_exterior_walls(_exterior_walls)
	_resize_controller.set_wall_tilemap(room_build_manager.get_wall_tilemap_layer())
	_resize_controller.set_nav_tilemap(room_build_manager.get_tilemap_layer())

	# Enter resize mode
	_resize_controller.enter_resize_mode(room)

	# Show cancel button
	_resize_cancel_button.show()
	_position_resize_cancel_button(room)


func _on_resize_completed(room: RoomInstance) -> void:
	print("Main._on_resize_completed: ", room.id)

	# Hide cancel button (successful resize transitions to door placement)
	_resize_cancel_button.hide()

	# Update RoomManager's Area2D to match new bounding box
	# Unregister and re-register to recreate the selection polygon
	print("  Unregistering room...")
	_room_manager.unregister_room(room)
	print("  Re-registering room...")
	_room_manager.register_room(room)

	# Update navigation tiles for new room bounds
	print("  Updating navigation tiles...")
	_update_navigation_for_room(room)

	print("  _on_resize_completed done")


func _on_resize_door_placement_needed(room: RoomInstance) -> void:
	print("Main._on_resize_door_placement_needed: ", room.id)

	# Disable room selection (the re-registered room's Area2D would capture clicks otherwise)
	_room_manager.disable_selection()

	# Pass exterior walls to door controller
	_door_edit_controller.set_exterior_walls(_exterior_walls)

	# Enter door edit mode (doors were cleared during resize)
	print("  Calling door edit controller enter_edit_mode...")
	_door_edit_controller.enter_edit_mode(room)
	print("  Door edit controller is_active: ", _door_edit_controller.is_active())
	_door_edit_highlight.queue_redraw()

	# Show Done button after a frame delay to prevent click-through
	# (the mouse release that committed resize would otherwise hit the button)
	print("  Awaiting frame...")
	await get_tree().process_frame
	print("  Frame passed, showing Done button, is_active: ", _door_edit_controller.is_active())
	_door_edit_done_button.show()
	_position_door_edit_button(room)


func _on_resize_mode_exited() -> void:
	print("Exited resize mode")
	camera.enable_pinch_pan = true
	_room_manager.enable_selection()
	_resize_cancel_button.hide()


func _on_resize_cancel_pressed() -> void:
	_resize_controller.exit_resize_mode()


func _position_resize_cancel_button(_room: RoomInstance) -> void:
	# Position at top-right corner of viewport
	var viewport_size := get_viewport_rect().size
	var button_size := _resize_cancel_button.custom_minimum_size  # Use min size (layout may not have run)
	var margin := 16.0
	_resize_cancel_button.position = Vector2(
		viewport_size.x - button_size.x - margin,
		margin
	)


func _on_furniture_edit_exited() -> void:
	print("Exited furniture edit mode")
	camera.enable_pinch_pan = true  # Re-enable camera panning
	# Room can be re-selected now via normal RoomManager flow


func _on_furniture_list_item_selected(_index: int, furniture: RoomInstance.FurniturePlacement) -> void:
	_furniture_controller.select_furniture(furniture)


func _on_furniture_delete_requested() -> void:
	_furniture_controller.delete_furniture()


func _on_furniture_selected_for_add(furniture: FurnitureResource) -> void:
	_furniture_controller.enter_placement_mode(furniture)


func _on_placement_cancelled() -> void:
	_furniture_controller.exit_placement_mode()


func _on_furniture_added(room: RoomInstance, placement: RoomInstance.FurniturePlacement) -> void:
	# Get furniture parent node (don't pass tilemap - floor tiles shouldn't be modified)
	var furniture_parent = room_build_manager.get_furniture_parent()

	if furniture_parent:
		var furniture_op = FurnitureOperation.new()
		furniture_op.create_furniture_visual(placement, furniture_parent, null)

	print("Furniture added: ", placement.furniture.name if placement.furniture else "unknown")


func _on_placement_preview_updated(_position: Vector2i, _is_valid: bool) -> void:
	# FurnitureSelectionHighlight handles visual preview via its own signal connection
	pass


func _on_furniture_edit_done() -> void:
	_furniture_controller.exit_edit_mode()


func _exit_build_mode() -> void:
	_build_mode_active = false
	room_build_manager.end_build_mode()
	camera.enable_pinch_pan = true  # Re-enable camera panning
	if build_button:
		build_button.text = "Build"


func _on_door_added(room: RoomInstance, door: RoomInstance.DoorPlacement) -> void:
	# Create door visuals on the WALL tilemap layer
	var wall_layer = room_build_manager.get_wall_tilemap_layer()
	if wall_layer:
		var door_op = DoorOperation.new()
		door_op.create_door_visuals(door, wall_layer)

	# Note: Door tiles are already walkable, no need to update floor navigation
	# Notify targets of navigation change (paths may need recalculation)
	Targets.notify_navigation_changed()

	# Refresh highlight
	_door_edit_highlight.queue_redraw()

	print("Door added at: ", door.position)


func _on_door_removed(room: RoomInstance, door: RoomInstance.DoorPlacement) -> void:
	# Remove door visuals and restore wall on the WALL tilemap layer
	var wall_layer = room_build_manager.get_wall_tilemap_layer()
	if wall_layer:
		var door_op = DoorOperation.new()
		door_op.remove_door_visuals(door, room, wall_layer)

	# Note: Wall tiles are already non-walkable, no need to update floor navigation
	# Notify targets of navigation change (paths may need recalculation)
	Targets.notify_navigation_changed()

	# Refresh highlight
	_door_edit_highlight.queue_redraw()

	print("Door removed at: ", door.position)


func _on_door_add_failed(reason: String) -> void:
	print("Door add failed: ", reason)
	# TODO: Show inline error like furniture delete failed


func _on_door_remove_failed(reason: String) -> void:
	print("Door remove failed: ", reason)
	# TODO: Show inline error


func _on_door_edit_mode_exited() -> void:
	print("Exited door edit mode")
	camera.enable_pinch_pan = true  # Re-enable camera panning
	_room_manager.enable_selection()  # Re-enable room selection input
	_door_edit_highlight.queue_redraw()
	_door_edit_done_button.hide()  # Hide Done button


func _on_door_edit_done_pressed() -> void:
	# Validate minimum door count before allowing exit
	var room = _door_edit_controller.get_current_room()
	if room:
		var room_type = RoomTypeRegistry.get_instance().get_room_type(room.room_type_id)
		if room_type:
			var min_doors = room_type.door_count_min
			if room.doors.size() < min_doors:
				# Show feedback - flash button text temporarily
				var original_text = _door_edit_done_button.text
				_door_edit_done_button.text = "Need %d+ doors" % min_doors
				await get_tree().create_timer(1.5).timeout
				if is_instance_valid(_door_edit_done_button):
					_door_edit_done_button.text = original_text
				return

	_door_edit_controller.exit_edit_mode()


func _position_door_edit_button(room: RoomInstance) -> void:
	# Calculate room center tile from bounding box
	var bbox := room.bounding_box
	var center_x := bbox.position.x + bbox.size.x / 2
	var center_y := bbox.position.y + bbox.size.y / 2
	var center_tile := Vector2i(center_x, center_y)

	# Convert to screen position
	var screen_pos := IsometricMath.tile_to_screen(center_tile, get_viewport())

	# Position button below room center
	var button_size := _door_edit_done_button.size
	var offset := Vector2(-button_size.x / 2, 60)  # Centered, below room
	var target_pos := screen_pos + offset

	# Clamp to viewport bounds with margin
	var viewport_size := get_viewport_rect().size
	var margin := 8.0
	target_pos.x = clampf(target_pos.x, margin, viewport_size.x - button_size.x - margin)
	target_pos.y = clampf(target_pos.y, margin, viewport_size.y - button_size.y - margin)

	_door_edit_done_button.position = target_pos


func _update_navigation_for_room(room: RoomInstance) -> void:
	# NOTE: Floor tiles are on wall_tilemap (matches RoomBuildController pattern)
	var tilemap_layer = room_build_manager.get_wall_tilemap_layer()
	if tilemap_layer:
		var nav_op = NavigationOperation.new()
		nav_op.update_room_navigation(room, tilemap_layer)
	# Notify targets of navigation change
	Targets.notify_navigation_changed()


## Scan the wall tilemap for all existing wall tiles at game start.
## These are exterior walls that should never be deleted.
func _scan_exterior_walls() -> void:
	var wall_layer = room_build_manager.get_wall_tilemap_layer()
	if not wall_layer:
		push_warning("Main: Could not scan exterior walls - no wall tilemap")
		return

	# Get all used cells in the wall tilemap
	var used_cells = wall_layer.get_used_cells()

	# For each cell, check if it's a wall tile (has terrain set 0)
	for tilemap_pos in used_cells:
		var tile_data = wall_layer.get_cell_tile_data(tilemap_pos)
		if tile_data and tile_data.get_terrain_set() == 0:
			# Convert tilemap position to UI coordinates
			var ui_pos = IsometricMath.tilemap_to_ui_coords(tilemap_pos, wall_layer)
			_exterior_walls.append(ui_pos)

	print("Main: Scanned %d exterior wall tiles" % _exterior_walls.size())
