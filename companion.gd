extends CharacterBody2D

# ---------------- Player & movement settings ----------------

@export var player: CharacterBody2D

@export var follow_distance: float = 24.0
@export var speed_factor: float = 1.1
@export var min_speed: float = 60.0
@export var catchup_multiplier: float = 1.5

@export var side_random_radius: float = 10.0
@export var offset_change_interval: float = 0.6

@export var protect_distance: float = 20.0

# ---------------- Attack settings ----------------

@export var attack_duration: float = 0.25    # how long the hitbox is active
@export var attack_cooldown_time: float = 0.6

# ---------------- Animation & hitbox nodes ----------------
# Adaptés à ta scène :
# Player/characterSprite/characterSpriteAnimationPlay
# Player/BasicHitBox2D

@onready var anim_player: AnimationPlayer = $characterSprite/characterSpriteAnimationPlayer
@onready var attack_hitbox: Area2D = $BasicHitBox2D   # BasicHitBox2D du plugin

# ---------------- Internal state ----------------

var _last_facing: Vector2 = Vector2.DOWN
var _is_protecting: bool = false

var _random_local_offset: Vector2 = Vector2.ZERO
var _offset_timer: float = 0.0

var _is_attacking: bool = false
var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0

var _front_snap_lock_time: float = 0.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()

	# Auto-find player if not set
	if player == null:
		player = get_tree().get_root().find_child("Player", true, false) as CharacterBody2D

	if player:
		add_collision_exception_with(player)
	else:
		push_warning("Companion: Player reference not set and auto-find failed.")

	# Debug safety
	if anim_player == null:
		push_error("Companion: can't find $characterSprite/characterSpriteAnimationPlayer")
	if attack_hitbox == null:
		push_error("Companion: can't find $BasicHitBox2D")

	# Start with attack hitbox disabled (addon handles damage when enabled)
	if attack_hitbox:
		attack_hitbox.monitoring = false
		var shape: CollisionShape2D = attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.disabled = true


func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Timers
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_front_snap_lock_time = maxf(_front_snap_lock_time - delta, 0.0)

	# Attack input
	if Input.is_action_just_pressed("attack") and not _is_attacking and _attack_cooldown <= 0.0:
		_start_attack()

	# While attacking: stand still, keep hitbox active
	if _is_attacking:
		_update_attack(delta)
		_update_animation()
		return

	# Protect input: hold to stand in front of player
	_is_protecting = Input.is_action_pressed("protect")

	var target := _compute_target_position(delta)
	_move_towards_target(target, delta)
	_update_animation()


# ============================================================
# Movement / AI
# ============================================================

func _compute_target_position(delta: float) -> Vector2:
	var player_pos := player.global_position
	var player_facing := _get_player_facing()

	if _is_protecting:
		_last_facing = player_facing
		return player_pos + player_facing * protect_distance

	# Follow behind player with a bit of randomness
	_offset_timer -= delta
	if _offset_timer <= 0.0:
		_offset_timer = offset_change_interval
		_random_local_offset = Vector2(
			_rng.randf_range(-side_random_radius, side_random_radius),
			_rng.randf_range(-side_random_radius * 0.5, side_random_radius)
		)

	var behind_pos := player_pos - player_facing * follow_distance
	var rotated_offset := _random_local_offset.rotated(player_facing.angle())
	var target := behind_pos + rotated_offset

	# If companion drifts in front of player, snap back behind
	var to_comp_from_player := global_position - player_pos
	var is_in_front := player_facing.dot(to_comp_from_player) > 0.3
	if is_in_front and _front_snap_lock_time <= 0.0:
		target = behind_pos

	return target


func _move_towards_target(target: Vector2, _delta: float) -> void:
	var to_target := target - global_position
	var dist := to_target.length()

	if dist <= 1.0:
		velocity = Vector2.ZERO
		return

	var dir := to_target.normalized()
	var player_speed := player.velocity.length()
	var base_speed := maxf(player_speed * speed_factor, min_speed)

	if dist > follow_distance * 2.0:
		base_speed *= catchup_multiplier

	var dist_factor := clampf(dist / follow_distance, 0.2, 1.5)
	velocity = dir * base_speed * dist_factor
	_last_facing = dir

	move_and_slide()


# ============================================================
# Attack logic (hitbox toggling)
# ============================================================

func _start_attack() -> void:
	_is_attacking = true
	_attack_timer = attack_duration
	_attack_cooldown = attack_cooldown_time
	_front_snap_lock_time = 0.4

	_update_attack_hitbox_position()
	_set_attack_hitbox_enabled(true)
	_play_attack_animation()


func _update_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_is_attacking = false
		_set_attack_hitbox_enabled(false)


func _update_attack_hitbox_position() -> void:
	if attack_hitbox == null:
		return

	var dir_name := _direction_to_string(_last_facing)
	var offset := Vector2.ZERO

	match dir_name:
		"up":
			offset = Vector2(0, -12)
		"down":
			offset = Vector2(0, 12)
		"left":
			offset = Vector2(-12, 0)
		"right":
			offset = Vector2(12, 0)

	attack_hitbox.position = offset


func _set_attack_hitbox_enabled(enabled: bool) -> void:
	if attack_hitbox == null:
		return

	attack_hitbox.monitoring = enabled
	var shape: CollisionShape2D = attack_hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.disabled = not enabled


# ============================================================
# Animation
# ============================================================

func _update_animation() -> void:
	if anim_player == null:
		return

	if _is_attacking:
		# Attack animation already started in _start_attack()
		return

	var dir_name := _direction_to_string(_last_facing)
	var mode := "idle"

	if _is_protecting:
		mode = "guard"
	elif velocity.length() > 5.0:
		var walk_speed := 100.0
		var run_speed := 180.0
		if player:
			walk_speed = player.walk_speed
			run_speed = player.run_speed

		var run_threshold := (walk_speed + run_speed) * 0.5
		mode = "run" if velocity.length() > run_threshold else "walk"

	var anim_name := mode + "_" + dir_name

	# Fallback if guard animations don't exist
	if mode == "guard" and not anim_player.has_animation(anim_name):
		anim_name = "idle_" + dir_name

	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _play_attack_animation() -> void:
	if anim_player == null:
		return

	var dir_name := _direction_to_string(_last_facing)
	var base_name := "attack_" + dir_name
	var anim_name := base_name if anim_player.has_animation(base_name) else "run_" + dir_name
	anim_player.play(anim_name)


# ============================================================
# Helpers
# ============================================================

func _get_player_facing() -> Vector2:
	if player == null:
		return Vector2.DOWN

	if player._last_facing.length() > 0.0:
		return player._last_facing

	if player.velocity.length() > 1.0:
		return player.velocity.normalized()

	return Vector2.DOWN


func _direction_to_string(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	else:
		return "down" if dir.y > 0.0 else "up"
