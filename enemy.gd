extends CharacterBody2D

@export var max_health: int = 3
@export var move_speed: float = 60.0
@export var detection_radius: float = 120.0   # starts chasing when within this distance

var health: int
var _target: Node2D = null
var _last_facing: Vector2 = Vector2.DOWN

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	health = max_health
	add_to_group("Enemy")   # just in case you forget in the editor


func _physics_process(delta: float) -> void:
	# Pick a target (player or companion), then chase if close enough
	_update_target()
	_update_movement(delta)
	_update_animation()


func _update_target() -> void:
	var root = get_tree().get_root()

	# Prefer the player; if not found, fallback to companion
	var player = root.find_child("Player", true, false) as Node2D
	var companion = root.find_child("Companion", true, false) as Node2D

	_target = null
	var best_dist_sq := detection_radius * detection_radius

	if player != null:
		var d_sq = (player.global_position - global_position).length_squared()
		if d_sq < best_dist_sq:
			_target = player
			best_dist_sq = d_sq

	if companion != null:
		var d_sq2 = (companion.global_position - global_position).length_squared()
		if d_sq2 < best_dist_sq:
			_target = companion
			best_dist_sq = d_sq2


func _update_movement(_delta: float) -> void:
	if _target == null:
		velocity = Vector2.ZERO
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

	if dist > detection_radius:
		velocity = Vector2.ZERO
	else:
		var dir = to_target.normalized()
		velocity = dir * move_speed
		_last_facing = dir

	move_and_slide()


func _update_animation() -> void:
	if anim == null:
		return

	var dir_name := _direction_to_string(_last_facing)
	var speed_mag := velocity.length()

	var desired: String
	if speed_mag < 5.0:
		desired = "idle_" + dir_name
	else:
		desired = "walk_" + dir_name

	if anim.animation != desired:
		anim.play(desired)


func _direction_to_string(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	else:
		return "down" if dir.y > 0.0 else "up"


func take_damage(amount: int) -> void:
	health -= amount
	print("Enemy took ", amount, " dmg. HP = ", health)

	# Optional: flash, play hit animation, knockback, etc.

	if health <= 0:
		die()


func die() -> void:
	# TODO: play death anim, drop loot, etc.
	queue_free()
