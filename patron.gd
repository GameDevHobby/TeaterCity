class_name Patron extends CharacterBody2D

@export var MovementSpeed: float = 10.0
@export var NavAgent: NavigationAgent2D
@export var AnimatedSprite: AnimatedSprite2D

var started = false

func _ready() -> void:
	var mousePos = get_global_mouse_position()
	NavAgent.target_position = mousePos
	
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("mouse"):	
		var mousePos = get_global_mouse_position()
		NavAgent.target_position = mousePos
	
func _physics_process(delta: float) -> void:
	var nextPos = NavAgent.get_next_path_position()
	
	if NavAgent.is_navigation_finished():
		velocity = Vector2.ZERO
	elif velocity == Vector2.ZERO and started:
		var path = NavAgent.get_current_navigation_path()
		var index = NavAgent.get_current_navigation_path_index()
		if index + 1 < len(path):
			nextPos = path[index + 1]
			#var nextPos = NavAgent.get_next_path_position()
			
			velocity = to_local(nextPos).normalized()
			velocity = velocity * MovementSpeed * delta
			started = true
	else:
		velocity = to_local(nextPos).normalized()
		velocity = velocity * MovementSpeed * delta
		started = true
		
	move_and_slide()
	
	var dir = (nextPos - global_position).normalized()
	var angle = snappedf(dir.angle(), PI / 4) / (PI / 4)
	var idx = wrapi(int(angle), 0, 8)

	var state = "walk" if velocity.length() > 0.1 else "idle"
	var anim = state + str(idx)
	AnimatedSprite.play(anim)

func _on_timer_timeout() -> void:
	pass # Replace with function body.


func _navigation_finished() -> void:
	pass # Replace with function body.
