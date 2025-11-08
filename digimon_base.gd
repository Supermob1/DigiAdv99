extends CharacterBody2D
class_name DigimonBase

signal health_changed(current: int, max: int)
signal died

@export var skin_set: DigimonSkinSet
@export var speed: float = 50.0

@export var attack_range: float = 24.0
@export var attack_cooldown: float = 0.4
@export var attack_damage: int = 1

@export var max_health: int = 10
@export var starting_skin_index: int = 0  # choose which Digimon this is

@onready var animation_player: AnimationPlayer = $AnimationPlayer/SpriteAnimationPlayer
@onready var sprite: Sprite2D = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $DigimonCollision
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurt_shape: CollisionShape2D = $Hurtbox/HurtShape
@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/HitShape

# OPTIONAL health bar (TextureProgressBar called "HealthBar" as child of the Digimon)
@onready var health_bar: TextureProgressBar = get_node_or_null("HealthBar")

# Spritesheet layout
const SKIN_HFRAMES := 4
const SKIN_VFRAMES := 8
const ATTACK_HFRAMES := 2
const ATTACK_VFRAMES := 1
const ATTACK_DURATION := 0.25

# Box ratios
const HURTBOX_WIDTH_RATIO := 0.5
const HURTBOX_HEIGHT_RATIO := 0.7
const HITBOX_WIDTH_RATIO := 0.6
const HITBOX_HEIGHT_RATIO := 0.4
const HITBOX_DISTANCE_RATIO := 0.45

var skins: Array[Texture2D] = []
var attack_skins: Array[Texture2D] = []
var current_skin_index: int = 0

var face_direction := "Front"
var animation_to_play := "Front_Idle"

var is_attacking: bool = false
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0

var _ground_y: float = 0.0
var health: int = 0

# damage visuals
var _hurt_flash_timer: float = 0.0
const HURT_FLASH_TIME := 0.1

# to avoid hitting same target many times in one swing
var _already_hit: Array[DigimonBase] = []


func _ready() -> void:
	_ground_y = collision_shape.position.y

	if skin_set:
		skins = skin_set.skins
		if "attack_skins" in skin_set:
			attack_skins = skin_set.attack_skins
	else:
		push_warning("No skin_set assigned on %s" % name)
		return

	if skins.is_empty():
		push_warning("skin_set.skins is empty on %s" % name)
		return

	current_skin_index = starting_skin_index
	apply_skin_index(current_skin_index)

	# init health
	health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health

	hitbox.monitoring = false

	# connect hitbox overlap
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)


func _physics_process(delta: float) -> void:
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta

	# fade hurt flash
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		if _hurt_flash_timer <= 0.0:
			sprite.modulate = Color.WHITE

	if is_attacking:
		update_attack(delta)
	else:
		process_ai(delta)

	_update_animation()
	move_and_slide()


# --------- To be overridden by child scripts ---------
func process_ai(_delta: float) -> void:
	# children (pet/enemy) implement their own AI
	pass


# --------- Animation from velocity / facing ---------
func _update_animation() -> void:
	if is_attacking:
		return  # during attack we use sprite frames, not AnimationPlayer

	if velocity.length() > 0.1:
		if abs(velocity.x) > abs(velocity.y):
			face_direction = "Right" if velocity.x > 0.0 else "Left"
		else:
			face_direction = "Front" if velocity.y > 0.0 else "Back"
		animation_to_play = face_direction + "_Walk"
	else:
		animation_to_play = face_direction + "_Idle"

	if not animation_player.is_playing() or animation_player.current_animation != animation_to_play:
		animation_player.play(animation_to_play)


# --------- Size & position helpers ---------
func _apply_frame_size_and_boxes(frame_size: Vector2) -> void:
	var frame_size_scaled: Vector2 = frame_size * sprite.scale
	var frame_height: float = frame_size_scaled.y

	# Place sprite so feet touch ground
	sprite.position.y = _ground_y - frame_height * 0.5

	# Hurtbox
	if hurt_shape and hurt_shape.shape and hurt_shape.shape is RectangleShape2D:
		var rect := hurt_shape.shape as RectangleShape2D
		rect.size = Vector2(
			frame_size_scaled.x * HURTBOX_WIDTH_RATIO,
			frame_size_scaled.y * HURTBOX_HEIGHT_RATIO
		)
		hurt_shape.position = Vector2(0.0, _ground_y - rect.size.y * 0.5)

	# Hitbox (size only; direction later)
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

	match face_direction:
		"Front":
			offset = Vector2(0, distance)
		"Back":
			offset = Vector2(0, -distance)
		"Left":
			offset = Vector2(-distance, 0)
		"Right":
			offset = Vector2(distance, 0)
		_:
			offset = Vector2.ZERO

	hit_shape.position = offset


# --------- Skins ---------
func apply_skin_index(index: int) -> void:
	if skins.is_empty():
		return

	current_skin_index = clamp(index, 0, skins.size() - 1)
	var tex: Texture2D = skins[current_skin_index]
	sprite.texture = tex

	sprite.flip_h = false
	sprite.flip_v = false
	sprite.hframes = SKIN_HFRAMES
	sprite.vframes = SKIN_VFRAMES
	sprite.scale = Vector2.ONE

	var frame_size := Vector2(
		tex.get_width() / float(SKIN_HFRAMES),
		tex.get_height() / float(SKIN_VFRAMES)
	)

	_apply_frame_size_and_boxes(frame_size)


# --------- Attack logic ---------
func start_attack() -> void:
	if attack_skins.is_empty():
		return
	if attack_cooldown_timer > 0.0:
		return
	if current_skin_index >= attack_skins.size():
		return

	is_attacking = true
	attack_timer = 0.0
	attack_cooldown_timer = attack_cooldown

	# clear per-swing hit list
	_already_hit.clear()

	animation_player.stop()

	var tex: Texture2D = attack_skins[current_skin_index]
	sprite.texture = tex
	sprite.hframes = ATTACK_HFRAMES
	sprite.vframes = ATTACK_VFRAMES
	sprite.scale = Vector2.ONE

	# horizontal flip only
	sprite.flip_h = (face_direction == "Right")
	sprite.flip_v = false

	var frame_size := Vector2(
		tex.get_width() / float(ATTACK_HFRAMES),
		tex.get_height() / float(ATTACK_VFRAMES)
	)

	_apply_frame_size_and_boxes(frame_size)
	_update_hitbox_direction()

	hitbox.monitoring = true
	sprite.frame = 0


func update_attack(delta: float) -> void:
	attack_timer += delta

	if attack_timer < ATTACK_DURATION * 0.5:
		sprite.frame = 0
	else:
		sprite.frame = 1

	if attack_timer >= ATTACK_DURATION:
		end_attack()


func end_attack() -> void:
	is_attacking = false
	hitbox.monitoring = false

	apply_skin_index(current_skin_index)
	animation_player.play(animation_to_play)


# --------- Health / damage ---------
func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return

	health = max(0, health - amount)
	_hurt_flash_timer = HURT_FLASH_TIME
	sprite.modulate = Color(1.0, 0.6, 0.6)  # slight red flash

	if health_bar:
		health_bar.value = health

	health_changed.emit(health, max_health)

	if health <= 0:
		die()


func die() -> void:
	died.emit()
	queue_free()


# --------- Hit detection via Hitbox ---------
func _on_hitbox_area_entered(area: Area2D) -> void:
	if not is_attacking:
		return

	# We expect the hitbox to collide with other Digimon's Hurtbox
	var other := area.get_parent()
	if other == self:
		return

	if other is DigimonBase:
		var other_digimon: DigimonBase = other
		if other_digimon in _already_hit:
			return

		_already_hit.append(other_digimon)
		other_digimon.take_damage(attack_damage)
