class_name Patron extends CharacterBody2D

@export var movement_speed: float = 3000.0 # not sure why this needs to be so high.
@export var nav_agent: NavigationAgent2D
@export var animated_sprite: AnimatedSprite2D

var _started := false
var _nav_count := 0

func _ready() -> void:
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	nav_agent.navigation_finished.connect(_navigation_finished)
	Targets.navigation_changed.connect(_on_navigation_changed)
	choose_random_target()
	
func choose_random_target() -> void:
	var target = Targets.get_random_entity()
	var noise_strength = 10
	var noise_offset = Vector2(
		randf_range(-noise_strength, noise_strength),
		randf_range(-noise_strength, noise_strength)
	)
	var target_position = target.global_position + noise_offset
	nav_agent.target_position = target_position
#func _process(_delta: float) -> void:
	#if Input.is_action_just_pressed("mouse"):
		#var mousePos = get_global_mouse_position()
		#NavAgent.target_position = mousePos
	#
#func _physics_process(delta: float) -> void:
	#var nextPos = NavAgent.get_next_path_position()
	## Add small random steering variation
	#var noise_strength = 0.1  # Tweak for desired "wobble"
	#
	#
	#if NavAgent.is_navigation_finished():
		#NavAgent.velocity = Vector2.ZERO
	#elif NavAgent.velocity == Vector2.ZERO and started:
		#var path = NavAgent.get_current_navigation_path()
		#var index = NavAgent.get_current_navigation_path_index()
		#if index + 1 < len(path):
			#nextPos = path[index + 1]
			##var nextPos = NavAgent.get_next_path_position()
			#
			#NavAgent.velocity = to_local(nextPos).normalized()
			#NavAgent.velocity = NavAgent.velocity * MovementSpeed * delta
			#started = true
	#else:
		#NavAgent.velocity = to_local(nextPos).normalized()
		#NavAgent.velocity = NavAgent.velocity * MovementSpeed * delta
		#started = true
		#
func _physics_process(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		nav_agent.velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		return

	# Only compute if we have a valid path
	if not nav_agent.is_target_reachable():
		return

	var next_pos = nav_agent.get_next_path_position()
	var noise_strength = 0.5

	# Base direction with anti-clumping noise
	var direction = global_position.direction_to(next_pos).normalized()
	var noise_offset = Vector2(
		randf_range(-noise_strength, noise_strength),
		randf_range(-noise_strength, noise_strength)
	)
	direction = (direction + noise_offset).normalized()

	# Feed desired velocity to agent (avoidance uses this)
	nav_agent.velocity = direction * movement_speed

	# handle animations
	var dir = (next_pos - global_position).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)

	var state = "walk" if nav_agent.velocity.length() > 0.1 else "idle"
	var anim = state + str(idx)
	animated_sprite.play(anim)

func _on_timer_timeout() -> void:
	pass # Replace with function body.


func _navigation_finished() -> void:
	_nav_count += 1

	if _nav_count < 10:
		choose_random_target()
	else:
		queue_free()


func _on_navigation_changed() -> void:
	# Recalculate path to current target when navigation map changes
	var current_target = nav_agent.target_position
	nav_agent.target_position = current_target

# Signal handler - THIS MAKES AVOIDANCE WORK
func _on_velocity_computed(safe_velocity: Vector2):
	velocity = safe_velocity
	move_and_slide()
