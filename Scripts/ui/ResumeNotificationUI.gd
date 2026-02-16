class_name ResumeNotificationUI
extends CanvasLayer

@export var panel_ref: PanelContainer
@export var message_label_ref: Label

const DISPLAY_DURATION := 3.0  # seconds
const FADE_DURATION := 0.5  # seconds

var _display_timer: float = 0.0
var _is_fading := false

func _ready() -> void:
	layer = 100  # Above game UI
	if panel_ref == null or message_label_ref == null:
		push_error("ResumeNotificationUI: panel_ref/message_label_ref exports are not assigned")
		return

	panel_ref.visible = false
	_setup_style()

func _setup_style() -> void:
	# Style matching game aesthetic
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.2, 0.95)  # Dark purple
	style.border_color = Color(0.5, 0.45, 0.4, 1.0)  # Warm brown
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(0)
	panel_ref.add_theme_stylebox_override("panel", style)

	# Label style
	message_label_ref.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	message_label_ref.add_theme_font_size_override("font_size", 16)

func show_notification(transition_count: int) -> void:
	if panel_ref == null or message_label_ref == null:
		return

	if transition_count <= 0:
		return

	# Format message - generic for Phase 11, will be enhanced later
	if transition_count == 1:
		message_label_ref.text = "1 state change while away"
	else:
		message_label_ref.text = "%d state changes while away" % transition_count

	# Reset state
	panel_ref.modulate.a = 1.0
	panel_ref.visible = true
	_display_timer = DISPLAY_DURATION
	_is_fading = false

	# Position at top center
	await get_tree().process_frame  # Wait for layout
	var viewport_size = get_viewport().get_visible_rect().size
	panel_ref.position.x = (viewport_size.x - panel_ref.size.x) / 2.0
	panel_ref.position.y = 20

func _process(delta: float) -> void:
	if panel_ref == null:
		return

	if not panel_ref.visible:
		return

	if _display_timer > 0:
		_display_timer -= delta
		if _display_timer <= 0:
			_is_fading = true

	if _is_fading:
		panel_ref.modulate.a -= delta / FADE_DURATION
		if panel_ref.modulate.a <= 0:
			panel_ref.visible = false
			_is_fading = false
