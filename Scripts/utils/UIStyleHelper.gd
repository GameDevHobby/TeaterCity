class_name UIStyleHelper
extends RefCounted

## UI styling utilities for consistent pixel-art theming in TheaterCity.
## Consolidates duplicate styling code from RoomBuildUI.

# Default theme colors
const DEFAULT_BG_COLOR := Color(0.25, 0.22, 0.3, 1.0)
const DEFAULT_BORDER_COLOR := Color(0.5, 0.45, 0.4, 1.0)
const DEFAULT_FONT_COLOR := Color(0.9, 0.85, 0.8, 1.0)
const DEFAULT_FONT_HOVER_COLOR := Color(1.0, 0.95, 0.9, 1.0)
const PANEL_BG_COLOR := Color(0.15, 0.12, 0.18, 0.95)
const PANEL_BORDER_COLOR := Color(0.4, 0.35, 0.3, 1.0)

## Create a pixel-art StyleBoxFlat with specified parameters
static func create_pixel_style(
	bg_color: Color,
	border_color: Color,
	border_width: int = 2,
	corner_radius: int = 2,
	margin: int = 8
) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(margin)
	return style

## Apply complete button styling with normal, hover, and pressed states
static func apply_button_style(
	button: Button,
	base_color: Color = DEFAULT_BG_COLOR,
	font_color: Color = DEFAULT_FONT_COLOR
) -> void:
	var style_normal = create_pixel_style(base_color, DEFAULT_BORDER_COLOR)

	var style_hover = create_pixel_style(
		base_color.lightened(0.15),
		Color(0.7, 0.6, 0.5, 1.0)
	)

	var style_pressed = create_pixel_style(
		base_color.darkened(0.15),
		Color(0.6, 0.5, 0.4, 1.0)
	)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", DEFAULT_FONT_HOVER_COLOR)

## Apply panel styling consistent with the game theme
static func apply_panel_style(panel: PanelContainer) -> void:
	var style = create_pixel_style(PANEL_BG_COLOR, PANEL_BORDER_COLOR, 2, 4, 10)
	panel.add_theme_stylebox_override("panel", style)

## Create a fully styled button ready to add to container
static func create_styled_button(
	text: String,
	min_size: Vector2 = Vector2(200, 48),
	base_color: Color = DEFAULT_BG_COLOR
) -> Button:
	var button = Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = min_size
	apply_button_style(button, base_color)
	return button
