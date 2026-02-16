class_name TheaterSchedulePanel
extends Control

signal schedule_confirmed(room: RoomInstance, movie_id: String)
signal schedule_cancelled

const PANEL_WIDTH := 360.0
const PANEL_HEIGHT := 420.0
const LIST_HEIGHT := 230.0

var _panel: PanelContainer
var _title_label: Label
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

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = MOUSE_FILTER_IGNORE
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "SchedulePanel"
	_panel.mouse_filter = MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	UIStyleHelper.apply_panel_style(_panel)
	center.add_child(_panel)

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

	_movie_list = ItemList.new()
	_movie_list.custom_minimum_size = Vector2(0, LIST_HEIGHT)
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
	_populate_movies()
	show()


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
