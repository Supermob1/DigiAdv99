extends CharacterBody2D

@export var walk_speed: float = 100.0
@export var run_speed: float = 180.0

var _input_dir: Vector2 = Vector2.ZERO
var _is_running: bool = false
var _last_facing: Vector2 = Vector2.DOWN  # default facing down

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $Area2D
@onready var hitbox_shape: CollisionShape2D = $Area2D/Hitbox

func _ready() -> void:
	# --- Physics layers/masks (example) ---
	# Player body: layer 2, collides only with world (layer 1)
	collision_layer = 1 << 1
	collision_mask  = 1 << 0

	# Hitbox: layer 4, no mask yet (doesn't hit anything until you decide)
	hitbox_area.collision_layer = 1 << 3
	hitbox_area.collision_mask  = 0
	# If later you add NPC/monster hurtboxes, you can set:
	# hitbox_area.collision_mask = 1 << 4

	_update_hitbox_offset()  # put hitbox in front of starting facing dir


func _physics_process(delta: float) -> void:
	_read_input()
	_move_player(delta)
	_update_animation()
	_update_hitbox_offset()


func _read_input() -> void:
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	_input_dir = Vector2.ZERO

	# Prioritize the axis with the stronger input (no diagonal)
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


func _update_hitbox_offset() -> void:
	# Move the Area2D in front of the player based on facing direction
	var offset_dist := 8.0  # tweak for how far in front the hitbox is
	var offset := Vector2.ZERO
	var dir_name := _direction_to_string(_last_facing)

	match dir_name:
		"up":
			offset = Vector2(0, -offset_dist)
		"down":
			offset = Vector2(0, offset_dist)
		"left":
			offset = Vector2(-offset_dist, 0)
		"right":
			offset = Vector2(offset_dist, 0)

	hitbox_area.position = offset
