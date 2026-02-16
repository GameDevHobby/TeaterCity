class_name TheaterSchedulePanel
extends Control

signal schedule_confirmed(room: RoomInstance, movie_id: String)
signal schedule_cancelled

const PANEL_WIDTH := 560.0
const LIST_HEIGHT := 260.0

@onready var _panel: PanelContainer = $CenterContainer/SchedulePanel
@onready var _title_label: Label = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var _status_label: Label = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/StatusLabel
@onready var _movie_list: ItemList = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/MovieList
@onready var _details_label: Label = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/DetailsLabel
@onready var _schedule_button: Button = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/Actions/ScheduleButton
@onready var _cancel_button: Button = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/Actions/CancelButton
@onready var _close_button: Button = $CenterContainer/SchedulePanel/MarginContainer/VBoxContainer/Header/CloseButton

var _target_room: RoomInstance = null
var _movies: Array[MovieResource] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_preset(PRESET_FULL_RECT)

	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	UIStyleHelper.apply_panel_style(_panel)

	_title_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	_status_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	_details_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)

	_movie_list.custom_minimum_size = Vector2(0, LIST_HEIGHT)
	_movie_list.select_mode = ItemList.SELECT_SINGLE
	_movie_list.allow_reselect = true
	_movie_list.same_column_width = true

	UIStyleHelper.apply_button_style(_cancel_button)
	UIStyleHelper.apply_button_style(_schedule_button, Color(0.2, 0.42, 0.30, 1.0))
	UIStyleHelper.apply_button_style(_close_button, Color(0.45, 0.22, 0.22, 1.0))

	_close_button.pressed.connect(_on_cancel_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_schedule_button.pressed.connect(_on_schedule_pressed)
	_movie_list.item_selected.connect(_on_movie_selected)

	hide_panel()


func show_for_room(room: RoomInstance, movies: Array[MovieResource]) -> void:
	_target_room = room
	_movies = movies.duplicate()
	_update_room_status()
	_populate_movies()
	show()


func hide_panel() -> void:
	hide()
	_target_room = null
	_movies.clear()
	_movie_list.clear()
	_schedule_button.disabled = true
	_details_label.text = "No movie selected"
	_status_label.text = ""


func _update_room_status() -> void:
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
