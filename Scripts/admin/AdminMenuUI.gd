class_name AdminMenuUI
extends Control

## Admin menu UI - provides visual interface for admin functionality.
##
## Structure:
## - CanvasLayer (layer 10) ensures rendering above all other UI
## - PanelContainer with styled buttons for admin actions
## - ConfirmationDialog for destructive actions (Revert, Reset)
##
## Signals are emitted when the user confirms actions, allowing external
## handling of revert/reset operations.

## Emitted when user confirms reverting to last save
signal revert_requested

## Emitted when user confirms resetting all data
signal reset_requested


## Reference to AdminMenu autoload
@onready var _admin_menu: Node = get_node("/root/AdminMenu")

## UI elements created in _ready()
var _canvas_layer: CanvasLayer = null
var _panel: PanelContainer = null
var _revert_button: Button = null
var _reset_button: Button = null
var _close_button: Button = null


# --- Lifecycle ---

func _ready() -> void:
	# Start hidden
	hide()

	# Build UI hierarchy
	_build_ui()


# --- Public Methods ---

## Show the admin menu UI
func show_menu() -> void:
	show()
	if _canvas_layer:
		_canvas_layer.show()


## Hide the admin menu UI
func hide_menu() -> void:
	hide()
	if _canvas_layer:
		_canvas_layer.hide()


# --- Private Methods ---

func _build_ui() -> void:
	# Set self as full-rect but ignore mouse (let CanvasLayer children handle input)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create CanvasLayer to ensure rendering above all other UI
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "AdminMenuCanvasLayer"
	_canvas_layer.layer = 10  # High layer to be above all game UI
	add_child(_canvas_layer)

	# Create centering container
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas_layer.add_child(center_container)

	# Create background overlay to dim game content and capture clicks outside panel
	var bg_overlay = ColorRect.new()
	bg_overlay.name = "BackgroundOverlay"
	bg_overlay.color = Color(0.0, 0.0, 0.0, 0.4)  # Semi-transparent dark
	bg_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block clicks
	# Insert before center_container so it's behind
	_canvas_layer.move_child(bg_overlay, 0)
	_canvas_layer.add_child(bg_overlay)
	_canvas_layer.move_child(bg_overlay, 0)  # Move to back

	# Create styled panel container
	_panel = PanelContainer.new()
	_panel.name = "AdminPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture clicks on panel
	UIStyleHelper.apply_panel_style(_panel)
	center_container.add_child(_panel)

	# Create margin container for padding
	var margin_container = MarginContainer.new()
	margin_container.name = "MarginContainer"
	margin_container.add_theme_constant_override("margin_left", 20)
	margin_container.add_theme_constant_override("margin_right", 20)
	margin_container.add_theme_constant_override("margin_top", 20)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin_container)

	# Create vertical container for content
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 16)
	margin_container.add_child(vbox)

	# Add title label
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Admin Menu"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	vbox.add_child(title_label)

	# Add Revert button
	_revert_button = UIStyleHelper.create_styled_button("Revert to Last Save")
	_revert_button.name = "RevertButton"
	_revert_button.pressed.connect(_on_revert_pressed)
	vbox.add_child(_revert_button)

	# Add Reset button with dangerous red color
	_reset_button = UIStyleHelper.create_styled_button(
		"Reset All Data",
		Vector2(200, 48),
		Color(0.7, 0.2, 0.2)  # Dangerous red
	)
	_reset_button.name = "ResetButton"
	_reset_button.pressed.connect(_on_reset_pressed)
	vbox.add_child(_reset_button)

	# Add separator before close
	var separator = HSeparator.new()
	separator.name = "Separator"
	vbox.add_child(separator)

	# Add Close button
	_close_button = UIStyleHelper.create_styled_button("Close")
	_close_button.name = "CloseButton"
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)


func _on_revert_pressed() -> void:
	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "Revert to last saved state?\n\nAll unsaved changes will be lost."
	dialog.ok_button_text = "Revert"
	dialog.title = "Confirm Revert"

	# Connect confirmed signal
	dialog.confirmed.connect(_perform_revert.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)

	# Add to canvas layer and show
	_canvas_layer.add_child(dialog)
	dialog.popup_centered()


func _perform_revert(dialog: ConfirmationDialog) -> void:
	# Clean up dialog
	dialog.queue_free()

	# Call AdminMenu revert operation
	if _admin_menu:
		var success = _admin_menu.revert_to_save()
		if success:
			print("AdminMenuUI: Revert successful")
		else:
			print("AdminMenuUI: Revert failed")

	# Emit signal for external handling
	revert_requested.emit()

	# Hide the admin menu
	hide_menu()


func _on_reset_pressed() -> void:
	# Create confirmation dialog with strong warning
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "DELETE ALL ROOM DATA?\n\nThis will:\n- Remove all rooms\n- Delete save file\n- Cannot be undone"
	dialog.ok_button_text = "Delete All Data"
	dialog.title = "Confirm Reset"

	# Connect confirmed signal
	dialog.confirmed.connect(_perform_reset.bind(dialog))
	dialog.canceled.connect(dialog.queue_free)

	# Add to canvas layer and show
	_canvas_layer.add_child(dialog)
	dialog.popup_centered()


func _perform_reset(dialog: ConfirmationDialog) -> void:
	# Clean up dialog
	dialog.queue_free()

	# Call AdminMenu reset operation
	if _admin_menu:
		var success = _admin_menu.reset_all_data()
		if success:
			print("AdminMenuUI: Reset successful")
		else:
			print("AdminMenuUI: Reset failed")

	# Emit signal for external handling
	reset_requested.emit()

	# Hide the admin menu
	hide_menu()


func _on_close_pressed() -> void:
	hide_menu()
