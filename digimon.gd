extends GenericDigimon

enum PetForm { NORMAL, EGG }

@export var player: Node2D                      # the human character
@export var enemy_group: StringName = "WildDigimon"

# --- PET STATS ---
@export var base_max_health: int = 10
@export var base_attack_damage: int = 1

@export var energy: int = 0        # increases max HP
@export_range(0, 100) var bond: int = 0     # 0–100, used for digivolve
@export var strength: int = 0      # increases base damage

const HP_PER_ENERGY := 2
const DAMAGE_PER_STRENGTH := 1

# --- EGG / RESPawn ---
@export var egg_duration: float = 5.0     # seconds as egg before respawning

var form_state: int = PetForm.NORMAL
@onready var egg_timer: Timer = get_node_or_null("EggTimer")

# --- FOLLOW / WANDER WHEN NORMAL ---
@export var wander_radius: float = 32.0
@export var wander_change_interval: float = 1.5
@export var engage_distance: float = 100.0      # auto-combat detection range
@export var combat_max_chase_distance: float = 160.0

# --- EGG VISUAL TWEAKS ---
@export var egg_scale: float = 0.6               # how big the egg looks
@export var egg_idle_fps: float = 2.0            # animation speed for egg (2 frames)
@export var egg_offset: Vector2 = Vector2(20, 0) # offset from player when turning into egg

var _wander_offset: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0


func _ready() -> void:
	super._ready()

	# Pet-specific stats sit on top of GenericDigimon stats
	_recompute_stats()
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# egg timer
	if egg_timer == null:
		egg_timer = Timer.new()
		egg_timer.one_shot = true
		add_child(egg_timer)
	egg_timer.timeout.connect(_on_egg_timer_timeout)

	_pick_new_wander_offset()


# ------------- hook bond into evolution -------------

func _get_bond_for_evo() -> int:
	return bond


# ------------- INPUT: Digivolve button instead of Attack -------------

func _physics_process(delta: float) -> void:
	# Player presses “digivolve” instead of attack
	if form_state == PetForm.NORMAL and Input.is_action_just_pressed("digimon_digivolve"):
		try_digivolve()
		super._physics_process(delta)
		return

	super._physics_process(delta)


# --------------------- AI OVERRIDE ---------------------

func process_ai(delta: float) -> void:
	if not player:
		velocity = Vector2.ZERO
		return

	# If we are an EGG: just follow the player, no combat
	if form_state == PetForm.EGG:
		_handle_egg_follow()
		return

	# ---- NORMAL FORM ----

	var enemy: Node2D = _find_closest_enemy()

	if enemy:
		_handle_combat(enemy)
		return
	else:
		# No enemies in range: if evolved, regress back to partner form
		if is_evolved():
			end_battle()
		_handle_wander(delta)


# ------------- STATS -------------

func _recompute_stats() -> void:
	max_health = base_max_health + energy * HP_PER_ENERGY
	attack_damage = base_attack_damage + strength * DAMAGE_PER_STRENGTH


# ------------- EGG LOGIC -------------

func _handle_egg_follow() -> void:
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > 8.0:
		velocity = to_player.normalized() * speed
	else:
		velocity = Vector2.ZERO

	if velocity.length() > 0.1:
		face_direction = "Right" if velocity.x > 0.0 else "Left"


func _become_egg() -> void:
	form_state = PetForm.EGG

	is_attacking = false
	attack_cooldown_timer = 0.0
	hitbox.monitoring = false

	# Eggs can't fight
	attack_damage = 0
	max_health = 1
	health = 1
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# --- choose egg form from the evolution line ---
	if is_instance_valid(DigimonEvolutionDB):
		# Use the partner base form (base_form_name) as reference, else current name
		var ref_name: StringName = base_form_name if base_form_name != &"" else digimon_name
		var egg_name: StringName = DigimonEvolutionDb.get_root_form_for(ref_name)

		digimon_name = egg_name
		_load_textures_from_root()
		_setup_body()

		# shrink egg & recompute boxes
		sprite.scale = Vector2(egg_scale, egg_scale)
		if body_texture:
			var frame_size := Vector2(
				body_texture.get_width() / float(BODY_HFRAMES),
				body_texture.get_height() / float(BODY_VFRAMES)
			)
			_apply_frame_size_and_boxes(frame_size)

	# move a bit away from the player so egg isn't glued to their back
	if player:
		global_position = player.global_position + egg_offset

	# start respawn timer
	if egg_timer:
		egg_timer.start(egg_duration)


func _on_egg_timer_timeout() -> void:
	form_state = PetForm.NORMAL

	# Back to first non-egg form in the evolution line (e.g. Botamon)
	if is_instance_valid(DigimonEvolutionDB):
		var ref_name: StringName = base_form_name if base_form_name != &"" else digimon_name
		var child_name: StringName = DigimonEvolutionDb.get_first_child_after_root(ref_name)
		digimon_name = child_name
	else:
		# fallback: partner base form
		if base_form_name != &"":
			digimon_name = base_form_name

	# reload textures for new form
	_load_textures_from_root()

	# restore normal scale and recompute boxes
	sprite.scale = Vector2.ONE
	_setup_body()

	# recompute stats & restore health
	_recompute_stats()
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	if player:
		global_position = player.global_position + Vector2(16, 0)

	_play_evolution_glow()



func _play_evolution_glow() -> void:
	var tween := create_tween()
	sprite.modulate = Color(1.5, 1.5, 1.5, 1.0)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.3)


func take_damage(amount: int) -> void:
	if form_state == PetForm.EGG:
		return
	super.take_damage(amount)


func die() -> void:
	if form_state == PetForm.NORMAL:
		_become_egg()
	else:
		super.die()


# ------------- WANDER / FOLLOW (NORMAL FORM) -------------

func _handle_wander(delta: float) -> void:
	var player_pos: Vector2 = player.global_position

	_wander_timer -= delta
	if _wander_timer <= 0.0 or _wander_offset == Vector2.ZERO:
		_pick_new_wander_offset()

	var target_pos: Vector2 = player_pos + _wander_offset
	var to_target: Vector2 = target_pos - global_position

	if to_target.length() > 2.0:
		velocity = to_target.normalized() * speed
	else:
		velocity = Vector2.ZERO

	if velocity.length() > 0.1:
		face_direction = "Right" if velocity.x > 0.0 else "Left"


func _pick_new_wander_offset() -> void:
	var angle: float = randf() * TAU
	var r: float = randf() * wander_radius
	_wander_offset = Vector2(cos(angle), sin(angle)) * r
	_wander_timer = wander_change_interval + randf_range(-0.5, 0.5)


# ------------- COMBAT (NORMAL FORM) -------------

func _find_closest_enemy() -> Node2D:
	var closest: Node2D = null
	var best_dist: float = INF

	for enemy in get_tree().get_nodes_in_group(enemy_group):
		if not enemy is Node2D:
			continue

		var d: float = (enemy.global_position - global_position).length()
		if d > engage_distance:
			continue

		if d < best_dist:
			best_dist = d
			closest = enemy

	return closest


func _handle_combat(enemy: Node2D) -> void:
	var enemy_pos: Vector2 = enemy.global_position
	var to_enemy: Vector2 = enemy_pos - global_position
	var dist_to_enemy: float = to_enemy.length()

	var dist_self_player: float = (global_position - player.global_position).length()
	if dist_self_player > combat_max_chase_distance:
		_handle_wander(0.0)
		return

	face_direction = "Right" if to_enemy.x > 0.0 else "Left"

	if dist_to_enemy <= attack_range:
		start_attack(to_enemy)
		velocity = Vector2.ZERO
	else:
		velocity = to_enemy.normalized() * speed


# ------------- ANIMATION OVERRIDE (EGG) -------------

func _update_animation(delta: float) -> void:
	# If we are an egg, play a simple 2-frame idle animation
	if form_state == PetForm.EGG:
		anim_timer += delta
		var frame := int(anim_timer * egg_idle_fps) % BODY_HFRAMES
		sprite.flip_h = false
		sprite.frame = frame
		return

	# otherwise, use the normal GenericDigimon animation
	super._update_animation(delta)
