extends CharacterBody2D

@export var walk_speed: float = 100.0
@export var run_speed: float = 180.0

var _input_dir: Vector2 = Vector2.ZERO
var _is_running: bool = false
var _last_facing: Vector2 = Vector2.DOWN  # default facing down

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	_read_input()
	_move_player(delta)
	_update_animation()


func _read_input() -> void:
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	_input_dir = Vector2.ZERO

	# Prioritize the axis with the stronger input
	if abs(x) > abs(y):
		_input_dir.x = sign(x)
	elif abs(y) > 0:
		_input_dir.y = sign(y)

	if _input_dir.length() > 0:
		_last_facing = _input_dir  # remember last non-zero direction

	_is_running = Input.is_action_pressed("run")


func _move_player(_delta: float) -> void:
	if _input_dir == Vector2.ZERO:
		velocity = Vector2.ZERO
	else:
		var speed := run_speed if _is_running else walk_speed
		velocity = _input_dir * speed

	move_and_slide()


func _update_animation() -> void:
	var dir_name := _direction_to_string(_last_facing)

	if _input_dir == Vector2.ZERO:
		# Idle
		var idle_anim := "idle_" + dir_name
		if anim.animation != idle_anim:
			anim.play(idle_anim)
	else:
		# Moving: walk or run
		var base := "run_" if _is_running else "walk_"
		var move_anim := base + dir_name
		if anim.animation != move_anim:
			anim.play(move_anim)


func _direction_to_string(dir: Vector2) -> String:
	# Decide whether to prioritize horizontal or vertical
	if abs(dir.x) > abs(dir.y):
		# Left or right
		return "right" if dir.x > 0.0 else "left"
	else:
		# Up or down
		return "down" if dir.y > 0.0 else "up"
