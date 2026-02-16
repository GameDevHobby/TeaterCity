class_name AdminMenuUI
extends CanvasLayer

## Admin menu UI with scene-authored structure.

signal reset_requested

@onready var _admin_menu: Node = get_node("/root/AdminMenu")

@onready var _panel: PanelContainer = $CenterContainer/AdminPanel
@onready var _title_label: Label = $CenterContainer/AdminPanel/MarginContainer/ContentVBox/TitleLabel
@onready var _reset_button: Button = $CenterContainer/AdminPanel/MarginContainer/ContentVBox/ResetButton
@onready var _close_button: Button = $CenterContainer/AdminPanel/MarginContainer/ContentVBox/CloseButton
@onready var _confirm_dialog: ConfirmationDialog = $ResetConfirmDialog


func _ready() -> void:
	layer = 10
	UIStyleHelper.apply_panel_style(_panel)
	UIStyleHelper.apply_button_style(_reset_button, Color(0.7, 0.2, 0.2, 1.0))
	UIStyleHelper.apply_button_style(_close_button)
	_title_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)

	_confirm_dialog.title = "Confirm Reset"
	_confirm_dialog.dialog_text = "DELETE ALL ROOM DATA?\n\nThis will:\n- Remove all rooms\n- Delete save file\n- Cannot be undone"
	_confirm_dialog.ok_button_text = "Delete All Data"

	_reset_button.pressed.connect(_on_reset_pressed)
	_close_button.pressed.connect(_on_close_pressed)
	_confirm_dialog.confirmed.connect(_on_reset_confirmed)

	hide_menu()


func show_menu() -> void:
	show()


func hide_menu() -> void:
	hide()


func _on_reset_pressed() -> void:
	_confirm_dialog.popup_centered()


func _on_reset_confirmed() -> void:
	if _admin_menu:
		var success = _admin_menu.reset_all_data()
		if success:
			print("AdminMenuUI: Reset successful")
		else:
			print("AdminMenuUI: Reset failed")

	reset_requested.emit()
	hide_menu()


func _on_close_pressed() -> void:
	hide_menu()
