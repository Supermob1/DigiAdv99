extends CharacterBody2D
class_name GenericDigimon

signal health_changed(current: int, max: int)
signal died

# Where all Digimon folders live (BotamonLine, etc.)
@export_dir var digimon_root_dir: String = "res://Digimon"

# Base name of the files:
#   <digimon_name>.png
#   <digimon_name>_Attack.png
@export var digimon_name: String = "Koromon"

# Base form (the one to regress to after battle)
@export var base_form_name: StringName = &""   # if empty, will default to digimon_name in _ready()

@export var speed: float = 50.0

@export var attack_range: float = 24.0
@export var attack_cooldown: float = 0.4
@export var attack_damage: int = 1

@export var max_health: int = 10
@export var attack_duration: float = 0.25   # duration of the 2-frame attack

@export var level: int = 1                  # shared by pet / enemies

# --- Evolution stat multipliers ---
@export var evo_hp_multiplier: float = 1.5
@export var evo_attack_multiplier: float = 1.5
@export var evo_speed_multiplier: float = 1.2

# Nodes expected in the scene
@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $DigimonCollision
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurt_shape: CollisionShape2D = $Hurtbox/HurtShape
@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/HitShape
@onready var health_bar: TextureProgressBar = get_node_or_null("HealthBar")

# Spritesheet layout (2 frames side view)
const BODY_HFRAMES := 2
const BODY_VFRAMES := 1
const ATTACK_HFRAMES := 2
const ATTACK_VFRAMES := 1

# Box ratios
const HURTBOX_WIDTH_RATIO := 0.5
const HURTBOX_HEIGHT_RATIO := 0.7
const HITBOX_WIDTH_RATIO := 0.6
const HITBOX_HEIGHT_RATIO := 0.4
const HITBOX_DISTANCE_RATIO := 0.45

# Textures
var body_texture: Texture2D
var attack_texture: Texture2D

# State
var face_direction: String = "Right"  # "Left" or "Right"
var is_moving: bool = false
var is_attacking: bool = false

var anim_timer: float = 0.0
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

var health: int = 0
var _ground_y: float = 0.0

# damage visuals
var _hurt_flash_timer: float = 0.0
const HURT_FLASH_TIME := 0.1

# avoid multiple hits per swing
var _already_hit: Array[GenericDigimon] = []

# anim speeds
const IDLE_FPS := 2.0
const WALK_FPS := 6.0
const ATTACK_FPS := 8.0

# directional attack
var _attack_dir: Vector2 = Vector2.RIGHT

# base stats (used for evolution multipliers)
var _base_max_health: int = 0
var _base_attack_damage: int = 0
var _base_speed: float = 0.0

# evolution state
var _is_evolved: bool = false


func _ready() -> void:
	_ground_y = collision_shape.position.y

	if base_form_name == &"":
		base_form_name = digimon_name

	_load_textures_from_root()
	_setup_body()

	# init health
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	# capture base stats for future evolution multipliers
	_capture_base_stats()

	if hitbox:
		hitbox.monitoring = false
		hitbox.area_entered.connect(_on_hitbox_area_entered)


func _capture_base_stats() -> void:
	_base_max_health = max_health
	_base_attack_damage = attack_damage
	_base_speed = speed


# ----------------- AUTOLOADING TEXTURES BY NAME -----------------

func _load_textures_from_root() -> void:
	var body_path: String = ""
	var attack_path: String = ""

	var stack: Array[String] = [digimon_root_dir]

	while stack.size() > 0 and (body_path == "" or attack_path == ""):
		var dir_path: String = stack.pop_back()
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		var name: String = dir.get_next()
		while name != "":
			if dir.current_is_dir():
				if not name.begins_with("."):
					stack.append(dir_path + "/" + name)
			else:
				if name == "%s.png" % digimon_name:
					body_path = dir_path + "/" + name
				elif name == "%s_Attack.png" % digimon_name:
					attack_path = dir_path + "/" + name
			name = dir.get_next()
		dir.list_dir_end()

	if body_path == "":
		push_error("GenericDigimon: body texture for '%s' not found under %s" % [digimon_name, digimon_root_dir])
	else:
		body_texture = load(body_path) as Texture2D

	if attack_path == "":
		push_error("GenericDigimon: attack texture for '%s' not found under %s" % [digimon_name, digimon_root_dir])
	else:
		attack_texture = load(attack_path) as Texture2D


# ----------------- SETUP & MAIN LOOP -----------------

func _setup_body() -> void:
	is_attacking = false
	anim_timer = 0.0

	if body_texture:
		sprite.texture = body_texture
		sprite.hframes = BODY_HFRAMES
		sprite.vframes = BODY_VFRAMES
	else:
		sprite.texture = null

	sprite.flip_h = (face_direction == "Right")
	sprite.frame = 0

	if body_texture:
		var frame_size := Vector2(
			body_texture.get_width() / float(BODY_HFRAMES),
			body_texture.get_height() / float(BODY_VFRAMES)
		)
		_apply_frame_size_and_boxes(frame_size)

	# ⬇️ ADD THIS to set up the HealthBar automatically
	_setup_health_bar()



func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# fade hurt flash
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		if _hurt_flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	if is_attacking:
		_update_attack(delta)
	else:
		process_ai(delta)   # children override this

	_update_animation(delta)
	move_and_slide()


# ----------------- AI HOOK -----------------

func process_ai(_delta: float) -> void:
	# Default: 4-direction player control using side-view sprite.
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_dir.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		is_moving = true

		if abs(input_dir.x) >= abs(input_dir.y):
			face_direction = "Right" if input_dir.x > 0.0 else "Left"
		else:
			# up/down: keep last horizontal facing
			pass
	else:
		velocity = Vector2.ZERO
		is_moving = false

	if Input.is_action_just_pressed("digimon_attack") and not is_attacking:
		var dir := velocity.normalized()
		start_attack(dir)


# ----------------- ANIMATION -----------------

func _update_animation(delta: float) -> void:
	anim_timer += delta

	if is_attacking:
		var attack_frame := int(anim_timer * ATTACK_FPS) % ATTACK_HFRAMES
		sprite.frame = attack_frame
		return

	var fps := WALK_FPS if is_moving else IDLE_FPS
	var frame_idx := int(anim_timer * fps) % BODY_HFRAMES

	sprite.flip_h = (face_direction == "Right")
	sprite.frame = frame_idx


# ----------------- ATTACK LOGIC (DIRECTIONAL) -----------------

func start_attack(direction: Vector2 = Vector2.ZERO) -> void:
	if attack_texture == null:
		return
	if attack_cooldown_timer > 0.0:
		return

	# store attack direction (used for hitbox)
	if direction != Vector2.ZERO:
		_attack_dir = direction.normalized()
	else:
		match face_direction:
			"Left":
				_attack_dir = Vector2.LEFT
			"Right":
				_attack_dir = Vector2.RIGHT
			_:
				_attack_dir = Vector2.RIGHT

	is_attacking = true
	attack_timer = 0.0
	anim_timer = 0.0
	attack_cooldown_timer = attack_cooldown
	_already_hit.clear()

	sprite.texture = attack_texture
	sprite.hframes = ATTACK_HFRAMES
	sprite.vframes = ATTACK_VFRAMES
	sprite.flip_h = (face_direction == "Right")
	sprite.frame = 0

	if attack_texture:
		var frame_size := Vector2(
			attack_texture.get_width() / float(ATTACK_HFRAMES),
			attack_texture.get_height() / float(ATTACK_VFRAMES)
		)
		_apply_frame_size_and_boxes(frame_size)
		_update_hitbox_direction()

	hitbox.monitoring = true


func _update_attack(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_duration:
		_end_attack()


func _end_attack() -> void:
	is_attacking = false
	hitbox.monitoring = false
	_setup_body()

func _setup_health_bar() -> void:
	if not health_bar:
		return

	# Auto size relative to Digimon sprite
	var bar_width := body_texture.get_width() / 2.5
	var bar_height := 4.0
	health_bar.size = Vector2(bar_width, bar_height)

	# Position just above the sprite's head
	var offset_y := -(body_texture.get_height() / 1.6)
	health_bar.position = Vector2(-bar_width / 2, offset_y)

	# Style setup
	health_bar.modulate = Color(0.2, 1.0, 0.2)  # green tint by default
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = health

# ----------------- SIZE / COLLISION BOXES -----------------

func _apply_frame_size_and_boxes(frame_size: Vector2) -> void:
	var frame_size_scaled: Vector2 = frame_size * sprite.scale
	var frame_height: float = frame_size_scaled.y

	# keep feet on ground
	sprite.position.y = _ground_y - frame_height * 0.5

	# Hurtbox
	if hurt_shape and hurt_shape.shape and hurt_shape.shape is RectangleShape2D:
		var rect := hurt_shape.shape as RectangleShape2D
		rect.size = Vector2(
			frame_size_scaled.x * HURTBOX_WIDTH_RATIO,
			frame_size_scaled.y * HURTBOX_HEIGHT_RATIO
		)
		hurt_shape.position = Vector2(0.0, _ground_y - rect.size.y * 0.5)

	# Hitbox
	if hit_shape and hit_shape.shape and hit_shape.shape is RectangleShape2D:
		var hit_rect := hit_shape.shape as RectangleShape2D
		hit_rect.size = Vector2(
			frame_size_scaled.x * HITBOX_WIDTH_RATIO,
			frame_size_scaled.y * HITBOX_HEIGHT_RATIO
		)
		hit_shape.position = Vector2.ZERO


func _update_hitbox_direction() -> void:
	if not hit_shape or not hit_shape.shape:
		return

	var hit_rect := hit_shape.shape as RectangleShape2D
	var distance: float = hit_rect.size.x * HITBOX_DISTANCE_RATIO
	var offset := Vector2.ZERO

	var dir := _attack_dir
	if dir.length() == 0.0:
		dir = Vector2.RIGHT

	if abs(dir.x) >= abs(dir.y):
		offset = Vector2(sign(dir.x) * distance, 0.0)
	else:
		offset = Vector2(0.0, sign(dir.y) * distance)

	hit_shape.position = offset


# ----------------- HEALTH / DAMAGE -----------------

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return

	health = max(0, health - amount)
	_hurt_flash_timer = HURT_FLASH_TIME
	sprite.modulate = Color(1.0, 0.6, 0.6)

	if health_bar:
		health_bar.value = health

	health_changed.emit(health, max_health)

	if health <= 0:
		die()


func die() -> void:
	died.emit()
	queue_free()


# ----------------- HIT DETECTION -----------------

func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_attacking:
		return

	var other := area.get_parent()
	if other == self:
		return

	if other is GenericDigimon:
		var other_digimon: GenericDigimon = other
		if other_digimon in _already_hit:
			return
		_already_hit.append(other_digimon)
		other_digimon.take_damage(attack_damage)


# ----------------- EVOLUTION API -----------------

func _get_bond_for_evo() -> int:
	# default 0; PetDigimon can override and return its bond
	return 0


func try_digivolve(active_conditions: Array[StringName] = []) -> bool:
	if not is_instance_valid(DigimonEvolutionDb):
		return false

	var bond_val := _get_bond_for_evo()
	var options: Array[DigivolutionStep] = DigimonEvolutionDb.get_possible_evolutions(
		digimon_name,
		level,
		bond_val,
		active_conditions
	)

	if options.is_empty():
		return false

	var step: DigivolutionStep = options[0]
	_apply_evolution_step(step)
	return true


func _apply_evolution_step(step: DigivolutionStep) -> void:
	_is_evolved = true
	digimon_name = step.to_name

	_load_textures_from_root()
	_setup_body()

	# multiply from stored base stats
	max_health = int(round(_base_max_health * evo_hp_multiplier))
	attack_damage = int(round(_base_attack_damage * evo_attack_multiplier))
	speed = _base_speed * evo_speed_multiplier

	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health


func regress_to_base_form() -> void:
	if not _is_evolved:
		return

	_is_evolved = false
	digimon_name = base_form_name

	_load_textures_from_root()
	_setup_body()

	max_health = _base_max_health
	attack_damage = _base_attack_damage
	speed = _base_speed

	if health > max_health:
		health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

func is_evolved() -> bool:
	return _is_evolved


func end_battle() -> void:
	# Call this when combat ends to put the digimon back to its base form.
	regress_to_base_form()
