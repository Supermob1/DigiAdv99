extends CharacterBody2D

@export var walk_speed: float = 70.0
@export var run_speed: float = 120.0
@export var acceleration: float = 800.0
@export var friction: float = 800.0
@export var input_deadzone: float = 0.2

# On récupère directement le node AnimationPlayer dans la scène
@onready var anim_player: AnimationPlayer = $characterSprite/characterSpriteAnimationPlayer

var _input_dir: Vector2 = Vector2.ZERO
var _is_running: bool = false
var _last_facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	# Juste pour vérifier que le chemin est bon
	if anim_player == null:
		push_error("Player: impossible de trouver $characterSprite/characterSpriteAnimationPlayer")

	# Layers de collision (optionnel suivant ton projet)
	collision_layer = 1 << 1   # ex: layer 2
	collision_mask  = 1 << 0   # ex: collide avec layer 1 (décor)


func _physics_process(delta: float) -> void:
	_read_input()
	_move_player(delta)
	_update_animation()


# ---------------- Input ----------------

func _read_input() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Deadzone
	if dir.length() < input_deadzone:
		dir = Vector2.ZERO

	# Forcer 4 directions (pas de diagonales)
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			dir.y = 0.0
			dir.x = sign(dir.x)
		else:
			dir.x = 0.0
			dir.y = sign(dir.y)

	_input_dir = dir

	if _input_dir != Vector2.ZERO:
		_last_facing = _input_dir

	_is_running = Input.is_action_pressed("run")


# ---------------- Déplacement ----------------

func _move_player(delta: float) -> void:
	var target_velocity := Vector2.ZERO

	if _input_dir != Vector2.ZERO:
		var speed := run_speed if _is_running else walk_speed
		target_velocity = _input_dir * speed

	if target_velocity == Vector2.ZERO:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)

	move_and_slide()


# ---------------- Animation ----------------

func _update_animation() -> void:
	if anim_player == null:
		return

	var dir_name := _direction_to_string(_last_facing)

	if _input_dir == Vector2.ZERO:
		var anim_name := "idle_" + dir_name
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
	else:
		var base := "run_" if _is_running else "walk_"
		var anim_name := base + dir_name
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)


func _direction_to_string(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	else:
		return "down" if dir.y > 0.0 else "up"
