class_name CircularTimerUI
extends Control

## Circular progress indicator with countdown display for room timers.
## Shows remaining time in MM:SS format with visual circular progress.
## Hides automatically when timer is inactive or completes.

@export var progress_bar: TextureProgressBar
@export var time_label: Label

var _timer_state: TimerState = null
var _is_showing := false

const RADIUS := 24.0
const THICKNESS := 4.0
const BG_COLOR := Color(0.2, 0.2, 0.25, 0.8)
const FILL_COLOR := Color(0.4, 0.8, 0.4, 1.0)  # Green for active


func _ready() -> void:
	visible = false
	_setup_progress_textures()
	_setup_time_label_style()


## Create circular progress textures programmatically to avoid external assets
func _setup_progress_textures() -> void:
	var size = int(RADIUS * 2 + THICKNESS * 2)
	var center = Vector2(size / 2.0, size / 2.0)

	# Background ring
	var bg_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	bg_image.fill(Color.TRANSPARENT)
	_draw_ring_to_image(bg_image, center, RADIUS, THICKNESS, BG_COLOR)
	var bg_texture = ImageTexture.create_from_image(bg_image)

	# Progress ring (full circle, TextureProgressBar clips it)
	var progress_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	progress_image.fill(Color.TRANSPARENT)
	_draw_ring_to_image(progress_image, center, RADIUS, THICKNESS, FILL_COLOR)
	var progress_texture = ImageTexture.create_from_image(progress_image)

	progress_bar.texture_under = bg_texture
	progress_bar.texture_progress = progress_texture
	progress_bar.custom_minimum_size = Vector2(size, size)


## Draw a circular ring into an image
func _draw_ring_to_image(image: Image, center: Vector2, radius: float, thickness: float, color: Color) -> void:
	var inner_radius = radius - thickness / 2.0
	var outer_radius = radius + thickness / 2.0
	for x in range(image.get_width()):
		for y in range(image.get_height()):
			var dist = Vector2(x, y).distance_to(center)
			if dist >= inner_radius and dist <= outer_radius:
				image.set_pixel(x, y, color)


## Apply pixel-art friendly styling to time label
func _setup_time_label_style() -> void:
	time_label.add_theme_color_override("font_color", UIStyleHelper.DEFAULT_FONT_COLOR)
	time_label.add_theme_font_size_override("font_size", 10)


## Set the timer state to display
func set_timer(timer: TimerState) -> void:
	_timer_state = timer
	_update_visibility()


## Show timer at specified world position
func show_at_position(world_pos: Vector2) -> void:
	_is_showing = true
	global_position = world_pos - size / 2.0  # Center on position
	_update_visibility()


## Hide the timer UI
func hide_timer() -> void:
	_is_showing = false
	visible = false


## Update visibility based on state
func _update_visibility() -> void:
	visible = _is_showing and _timer_state != null and _timer_state.is_active


## Update progress bar and time label each frame
func _process(_delta: float) -> void:
	if not visible or _timer_state == null:
		return

	var remaining = _timer_state.get_remaining()
	var total = _timer_state.duration

	# Update progress (100% = full, 0% = empty)
	if total > 0:
		progress_bar.value = (float(remaining) / total) * 100.0
	else:
		progress_bar.value = 0

	# Update time label (MM:SS format)
	var minutes = remaining / 60
	var seconds = remaining % 60
	time_label.text = "%d:%02d" % [minutes, seconds]

	# Check if timer completed (hide if so)
	if not _timer_state.is_active or _timer_state.is_complete():
		_update_visibility()
