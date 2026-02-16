class_name TheaterSchedulePanel
extends Control

signal schedule_confirmed(room: RoomInstance, movie_id: String)
signal schedule_cancelled

const PANEL_WIDTH := 560.0
const LIST_HEIGHT := 260.0
const PANEL_MARGIN := 16.0

var _panel: PanelContainer
var _title_label: Label
var _status_label: Label
var _movie_list: ItemList
var _details_label: Label
var _schedule_button: Button
var _cancel_button: Button
var _close_button: Button

var _target_room: RoomInstance = null
var _movies: Array[MovieResource] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)
	_create_ui()
	hide_panel()


func _create_ui() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.color = Color(0, 0, 0, 0.35)
	dimmer.mouse_filter = MOUSE_FILTER_STOP
	dimmer.set_anchors_preset(PRESET_FULL_RECT)
	add_child(dimmer)

	_panel = PanelContainer.new()
	_panel.name = "SchedulePanel"
	_panel.mouse_filter = MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.set_anchors_preset(PRESET_TOP_LEFT)
	UIStyleHelper.apply_panel_style(_panel)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Schedule Theater"
	_title_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_button = UIStyleHelper.create_styled_button("X", Vector2(42, 34), Color(0.45, 0.22, 0.22, 1.0))
	_close_button.pressed.connect(_on_cancel_pressed)
	header.add_child(_close_button)

	var subtitle := Label.new()
	subtitle.text = "Pick a movie to move this theater into Scheduled"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD
	subtitle.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(subtitle)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(_status_label)

	_movie_list = ItemList.new()
	_movie_list.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_movie_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_movie_list.select_mode = ItemList.SELECT_SINGLE
	_movie_list.allow_reselect = true
	_movie_list.same_column_width = true
	_movie_list.item_selected.connect(_on_movie_selected)
	vbox.add_child(_movie_list)

	_details_label = Label.new()
	_details_label.text = "No movie selected"
	_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_details_label.custom_minimum_size = Vector2(0, 64)
	_details_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(_details_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	vbox.add_child(actions)

	_cancel_button = UIStyleHelper.create_styled_button("Cancel", Vector2(120, 40))
	_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cancel_button.pressed.connect(_on_cancel_pressed)
	actions.add_child(_cancel_button)

	_schedule_button = UIStyleHelper.create_styled_button("Schedule", Vector2(160, 40), Color(0.2, 0.42, 0.30, 1.0))
	_schedule_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_schedule_button.pressed.connect(_on_schedule_pressed)
	_schedule_button.disabled = true
	actions.add_child(_schedule_button)


func show_for_room(room: RoomInstance, movies: Array[MovieResource]) -> void:
	_target_room = room
	_movies = movies.duplicate()
	_update_room_status()
	_populate_movies()
	show()
	call_deferred("_recenter_panel_after_layout")


func _recenter_panel_after_layout() -> void:
	_recenter_panel()
	# First open can be one layout pass behind due to wrapped labels/theme sizing.
	call_deferred("_recenter_panel")


func hide_panel() -> void:
	hide()
	_target_room = null
	_movies.clear()
	if _movie_list:
		_movie_list.clear()
	if _schedule_button:
		_schedule_button.disabled = true
	if _details_label:
		_details_label.text = "No movie selected"
	if _status_label:
		_status_label.text = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_recenter_panel()


func _recenter_panel() -> void:
	if _panel == null:
		return

	var viewport_size := get_viewport_rect().size
	var max_height: float = max(220.0, viewport_size.y - (PANEL_MARGIN * 2.0))

	# Fix width before measuring wrapped-label minimum heights.
	_panel.size.x = PANEL_WIDTH

	# Keep list roomy by default, only shrink when viewport is too short.
	_movie_list.custom_minimum_size.y = LIST_HEIGHT
	var panel_size := _panel.get_combined_minimum_size()
	if panel_size.y > max_height:
		var overflow := panel_size.y - max_height
		_movie_list.custom_minimum_size.y = max(140.0, LIST_HEIGHT - overflow)
		panel_size = _panel.get_combined_minimum_size()

	panel_size.x = max(panel_size.x, PANEL_WIDTH)
	_panel.size = panel_size
	_panel.position = (viewport_size - panel_size) * 0.5


func _update_room_status() -> void:
	if _status_label == null:
		return
	if _target_room == null:
		_status_label.text = ""
		return

	var current_state := "unknown"
	var state_raw := ""
	if _target_room.state_machine and _target_room.state_machine.current_state != "":
		state_raw = _target_room.state_machine.current_state
		current_state = state_raw.capitalize()

	if _target_room.has_scheduled_movie():
		var movie_label := "Scheduled movie"
		if state_raw == "" or state_raw == "idle":
			movie_label = "Last scheduled movie"

		_status_label.text = "State: %s\n%s: %s (%s, %d%%, %d min)" % [
			current_state,
			movie_label,
			_target_room.scheduled_movie_title,
			_target_room.scheduled_movie_genre,
			_target_room.scheduled_movie_rating,
			_target_room.scheduled_movie_duration
		]
		return

	_status_label.text = "State: %s\nNo movie currently scheduled." % current_state


func _populate_movies() -> void:
	_movie_list.clear()

	for movie in _movies:
		var row := "%s | %s | %d%% | %d min" % [movie.title, movie.genre, movie.rating, movie.duration]
		_movie_list.add_item(row)

	if _movies.is_empty():
		_details_label.text = "No movies available"
		_schedule_button.disabled = true
		return

	_movie_list.select(0)
	_update_details(0)
	_schedule_button.disabled = false


func _on_movie_selected(index: int) -> void:
	_update_details(index)
	_schedule_button.disabled = index < 0 or index >= _movies.size()


func _update_details(index: int) -> void:
	if index < 0 or index >= _movies.size():
		_details_label.text = "No movie selected"
		return

	var movie := _movies[index]
	_details_label.text = "Title: %s\nGenre: %s\nRating: %d%%\nDuration: %d min" % [
		movie.title,
		movie.genre,
		movie.rating,
		movie.duration
	]


func _on_schedule_pressed() -> void:
	if _target_room == null:
		return

	var selected := _movie_list.get_selected_items()
	if selected.is_empty():
		return

	var index: int = selected[0]
	if index < 0 or index >= _movies.size():
		return

	schedule_confirmed.emit(_target_room, _movies[index].id)


func _on_cancel_pressed() -> void:
	schedule_cancelled.emit()
