extends CharacterBody2D

@export var player: CharacterBody2D        # assign in inspector, or auto-found by name "Player"

# Distance de suivi
@export var follow_distance: float = 24.0      # distance idéale derrière le joueur

# Vitesse relative au joueur
@export var speed_factor: float = 1.1          # >1 = légèrement plus rapide que le joueur
@export var min_speed: float = 60.0            # vitesse minimale pour rattraper le joueur à l'arrêt
@export var catchup_multiplier: float = 1.5    # si trop loin, va plus vite

# Random autour du joueur
@export var side_random_radius: float = 10.0
@export var offset_change_interval: float = 0.6   # secondes avant de changer de décalage

var _last_facing: Vector2 = Vector2.DOWN
var _random_local_offset: Vector2 = Vector2.ZERO
var _offset_timer: float = 0.0

# Pour éviter les resets d’animation:
var _anim_dir: String = "down"
var _anim_mode: String = "idle"   # "idle", "walk", "run"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $Area2D
@onready var hitbox_shape: CollisionShape2D = $Area2D/Hitbox
@onready var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# --- Attack settings ---
@export var attack_range: float = 64.0          # max distance in front of player
@export var attack_dash_speed: float = 400.0    # dash speed
@export var attack_dash_time: float = 0.12      # how long the dash lasts
@export var attack_swing_time: float = 0.18     # how long the attack animation lasts
@export var attack_cooldown_time: float = 0.25  # delay before next attack
# Empêche de se recaler direct derrière le joueur juste après une attaque
var _front_snap_lock_time: float = 0.0

const ATTACK_NONE := 0
const ATTACK_DASH := 1
const ATTACK_SWING := 2

var _attack_state: int = ATTACK_NONE
var _attack_timer: float = 0.0
var _attack_cooldown: float = 0.0
var _attack_target: Vector2 = Vector2.ZERO
var _attack_active: bool = false    # true only during the swing (hit window)

# --- Guard / bodyguard behaviour ---
@export var guard_radius: float = 96.0          # how close an enemy must be to trigger guard mode
@export var guard_offset_from_player: float = 16.0  # distance from player towards enemy

signal attack_hit(target)


func _ready() -> void:
	_rng.randomize()

	# Auto-find du joueur si non assigné dans l’inspecteur
	if player == null:
		var root = get_tree().get_root()
		player = root.find_child("Player", true, false) as CharacterBody2D
		if player == null:
			push_warning("Companion: could not find a node named 'Player' in the scene tree.")
		else:
			print("Companion: auto-found player: ", player.name)

	# Ne JAMAIS collider avec le joueur (pas de pushing)
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if player == null:
		return
	# --- Attack state / cooldown ---
	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta
	# small timer to not re-snap right after an attack
	if _front_snap_lock_time > 0.0:
		_front_snap_lock_time -= delta

	# start attack on button press
	if Input.is_action_just_pressed("attack") and _attack_state == ATTACK_NONE and _attack_cooldown <= 0.0:
		_start_attack()

	# if we are in an attack state, override normal follow logic
	if _attack_state != ATTACK_NONE:
		_update_attack(delta)
		return


	var player_pos: Vector2 = player.global_position
	var player_vel: Vector2 = player.velocity
	var player_speed: float = player_vel.length()
	var player_facing: Vector2 = _get_player_facing()

	# --- Check for enemy to guard against ---
	var guard_enemy: Node2D = _get_nearest_enemy(guard_radius)
	var guarding: bool = guard_enemy != null
	var guard_target: Vector2 = Vector2.ZERO
	if guarding:
		guard_target = _compute_guard_position(player_pos, guard_enemy.global_position)

	# --- Normal "behind player" position ---
	var behind_pos: Vector2 = player_pos - player_facing * follow_distance

	# Random offset around behind position (keep your existing code)
	_offset_timer -= delta
	if _offset_timer <= 0.0:
		_offset_timer = offset_change_interval
		_random_local_offset = Vector2(
			_rng.randf_range(-side_random_radius, side_random_radius),
			_rng.randf_range(-side_random_radius * 0.5, side_random_radius)
		)
	var angle: float = player_facing.angle()
	var rotated_offset: Vector2 = _random_local_offset.rotated(angle)

	var target: Vector2
	if guarding:
		# Bodyguard mode: move between player and enemy
		target = guard_target
		# face towards the enemy
		var face_dir: Vector2 = (guard_enemy.global_position - player_pos).normalized()
		if face_dir.length() > 0.0:
			_last_facing = face_dir
	else:
		# Normal follow behind the player
		target = behind_pos + rotated_offset

		# Only snap behind if not in guard mode
		var to_comp_from_player: Vector2 = global_position - player_pos
		var is_in_front: bool = player_facing.dot(to_comp_from_player) > 0.3
		if is_in_front and _front_snap_lock_time <= 0.0:
			target = behind_pos



	# --- Mouvement vers la cible ---
	var to_target: Vector2 = target - global_position
	var dist: float = to_target.length()

	# Vitesse relative au joueur
	var speed: float = player_speed * speed_factor
	if speed < min_speed:
		speed = min_speed

	# Si on est vraiment loin, boost de rattrapage
	if dist > follow_distance * 2.0:
		speed *= catchup_multiplier

	# ⚠️ Changement important : ne plus faire ON/OFF, mais un mouvement lissé
	if dist > 1.0:
		var dir: Vector2 = to_target.normalized()
		# Plus on est loin, plus on va vite, mais jamais 0
		var dist_factor: float = clamp(dist / follow_distance, 0.2, 1.5)
		velocity = dir * speed * dist_factor
		_last_facing = dir
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	_update_animation()
	_update_hitbox_offset()


# ----------------- Helpers -----------------

func _get_player_facing() -> Vector2:
	if player == null:
		return Vector2.DOWN

	# Utilise le _last_facing du joueur si dispo
	var facing: Vector2 = player._last_facing
	if facing.length() > 0.0:
		return facing

	# Sinon, direction de la vélocité
	if player.velocity.length() > 1.0:
		return player.velocity.normalized()

	return Vector2.DOWN
func _get_nearest_enemy(max_radius: float) -> Node2D:
	if player == null:
		return null

	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return null

	var best_enemy: Node2D = null
	var best_dist_sq: float = max_radius * max_radius
	var player_pos: Vector2 = player.global_position

	for e in enemies:
		if not (e is Node2D):
			continue
		var d_sq: float = player_pos.distance_squared_to(e.global_position)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_enemy = e

	return best_enemy


func _compute_guard_position(player_pos: Vector2, enemy_pos: Vector2) -> Vector2:
	var dir: Vector2 = enemy_pos - player_pos
	if dir.length() < 0.001:
		return player_pos

	dir = dir.normalized()
	# position between player and enemy, closer to the player
	return player_pos + dir * guard_offset_from_player


func _update_animation() -> void:
	if anim == null:
		return

	var dir_name: String = _direction_to_string(_last_facing)
	var speed_mag: float = velocity.length()

	var new_mode: String
	if speed_mag < 5.0:
		new_mode = "idle"
	else:
		# Se base UNIQUEMENT sur la vitesse du compagnon
		# On prend les vitesses du joueur comme référence pour walk / run
		var walk_speed: float = 100.0
		var run_speed: float = 180.0

		if player != null:
			walk_speed = player.walk_speed
			run_speed = player.run_speed

		var run_threshold: float = (walk_speed + run_speed) * 0.5

		if speed_mag > run_threshold:
			new_mode = "run"
		else:
			new_mode = "walk"

	# Ne relance l’animation QUE si mode ou direction ont changé
	if new_mode != _anim_mode or dir_name != _anim_dir:
		_anim_mode = new_mode
		_anim_dir = dir_name
		var anim_name = _anim_mode + "_" + _anim_dir
		anim.play(anim_name)


func _direction_to_string(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "right" if dir.x > 0.0 else "left"
	else:
		return "down" if dir.y > 0.0 else "up"


func _update_hitbox_offset() -> void:
	var offset_dist: float = 8.0  # ajuste selon la taille de ton sprite
	var offset := Vector2.ZERO
	var dir_name: String = _direction_to_string(_last_facing)

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
	
func _start_attack() -> void:
	if player == null:
		return

	var facing: Vector2 = _get_player_facing()
	if facing == Vector2.ZERO:
		facing = Vector2.DOWN

	_last_facing = facing  # direction for animation + hitbox

	var player_pos: Vector2 = player.global_position

	# target point in front of the player, limited by attack_range
	_attack_target = player_pos + facing * attack_range

	_attack_state = ATTACK_DASH
	_attack_timer = attack_dash_time
	_attack_active = false           # we don’t hit during the dash
	_attack_cooldown = attack_dash_time + attack_swing_time + attack_cooldown_time


func _update_attack(delta: float) -> void:
	match _attack_state:
		ATTACK_DASH:
			_attack_update_dash(delta)
		ATTACK_SWING:
			_attack_update_swing(delta)


func _attack_update_dash(delta: float) -> void:
	var to_target: Vector2 = _attack_target - global_position
	var dist: float = to_target.length()

	if dist > 4.0:
		velocity = to_target.normalized() * attack_dash_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0.0 or dist <= 4.0:
		# dash finished -> stop and start swing
		velocity = Vector2.ZERO
		_attack_state = ATTACK_SWING
		_attack_timer = attack_swing_time
		_attack_active = true   # now hits are valid

		# choose attack animation (stop + swing)
		var dir_name: String = _direction_to_string(_last_facing)
		var frames := anim.sprite_frames
		var anim_name: String

		if frames != null and frames.has_animation("attack_" + dir_name):
			anim_name = "attack_" + dir_name
		else:
			anim_name = "run_" + dir_name   # fallback if no dedicated attack anim

		if anim.animation != anim_name:
			anim.play(anim_name)

	_update_hitbox_offset()   # keep hitbox in front


func _attack_update_swing(delta: float) -> void:
	# stand still, just play the attack anim already started
	velocity = Vector2.ZERO
	move_and_slide()

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_attack_state = ATTACK_NONE
		_attack_active = false

		# pendant un court instant, on NE le force PAS à se recaler derrière
		_front_snap_lock_time = 0.25   # ajuste (0.2–0.3 marche bien)

	_update_hitbox_offset()
