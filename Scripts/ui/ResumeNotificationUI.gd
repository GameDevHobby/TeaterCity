class_name ResumeNotificationUI
extends CanvasLayer

@onready var panel: PanelContainer = $PanelContainer
@onready var message_label: Label = $PanelContainer/MarginContainer/MessageLabel

const DISPLAY_DURATION := 3.0  # seconds
const FADE_DURATION := 0.5  # seconds

var _display_timer: float = 0.0
var _is_fading := false

func _ready() -> void:
	layer = 100  # Above game UI
	panel.visible = false
	_setup_style()

func _setup_style() -> void:
	# Style matching game aesthetic
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)  # Dark purple
	style.border_color = Color(0.5, 0.45, 0.4, 1.0)  # Warm brown
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)

	# Label style
	message_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	message_label.add_theme_font_size_override("font_size", 16)

func show_notification(transition_count: int) -> void:
	if transition_count <= 0:
		return

	# Format message - generic for Phase 11, will be enhanced later
	if transition_count == 1:
		message_label.text = "1 state change while away"
	else:
		message_label.text = "%d state changes while away" % transition_count

	# Reset state
	panel.modulate.a = 1.0
	panel.visible = true
	_display_timer = DISPLAY_DURATION
	_is_fading = false

	# Position at top center
	await get_tree().process_frame  # Wait for layout
	var viewport_size = get_viewport().get_visible_rect().size
	panel.position.x = (viewport_size.x - panel.size.x) / 2.0
	panel.position.y = 20

func _process(delta: float) -> void:
	if not panel.visible:
		return

	if _display_timer > 0:
		_display_timer -= delta
		if _display_timer <= 0:
			_is_fading = true

	if _is_fading:
		panel.modulate.a -= delta / FADE_DURATION
		if panel.modulate.a <= 0:
			panel.visible = false
			_is_fading = false
