extends CharacterBody2D

# Animation Player child node
@onready var animation_player = self.get_node("AnimationPlayer/SpriteAnimationPlayer")
@onready var sprite: Sprite2D = $AnimationPlayer

# Reference to the player this pet will follow
@onready var player: CharacterBody2D = get_node("../Player")

# Individual textures (optional, just for clarity)
var skin_koromon: Texture2D = preload("res://textures/Koromon/koromon_16x16.png")
var skin_agumon: Texture2D = preload("res://textures/Agumon/Agumon_16x16.png")
var skin_graymon: Texture2D = preload("res://textures/Graymon/Graymon_16x16.png")
var skin_metalgraymon: Texture2D = preload("res://textures/MetalGraymon/MetalGraymon_16x16.png")

# List of all available skins (order = cycle order)
var skins: Array[Texture2D] = []
var current_skin_index: int = 0

# Movement / behaviour properties
@export var speed: float = 50.0              # normal follow speed
@export var dash_speed: float = 90.0         # speed when trying to get in front
@export var follow_distance: float = 18.0    # distance it tries to stay behind the player
@export var randomness_radius: float = 6.0   # side-to-side wobble
@export var dash_chance_per_second: float = 0.5  # chance per second to start a dash while player is walking
@export var dash_duration: float = 0.6       # how long a dash lasts (in seconds)

var face_direction := "Front"
var animation_to_play := "Front_Idle"

# Internal state for "dash in front" behaviour
var is_dashing: bool = false
var dash_timer: float = 0.0

# To detect whether the player is actually moving
var _previous_player_position: Vector2

func _ready():
	randomize()

	# fill the skin list once (add more here if you create more skins)
	skins = [
		skin_koromon,
		skin_agumon,
		skin_graymon,
		skin_metalgraymon,
	]
	apply_skin_index(0)  # start with first skin
	animation_player.stop()
	animation_player.play("Front_Idle")

	if player:
		_previous_player_position = player.global_position
		# ⬇️ ignore collisions with the player
		add_collision_exception_with(player)

func _physics_process(delta: float) -> void:
	if not player:
		return

	# Swap skin when button pressed once (keep your input for cosmetic stuff)
	if Input.is_action_just_pressed("swap_skin"):
		var next_index := (current_skin_index + 1) % skins.size()
		apply_skin_index(next_index)

	# --- FOLLOW LOGIC ---

	var player_pos: Vector2 = player.global_position
	var to_player: Vector2 = player_pos - global_position
	var distance_to_player: float = to_player.length()

	# Estimate if player is moving
	var player_move_vec: Vector2 = player_pos - _previous_player_position
	_previous_player_position = player_pos
	var player_is_moving: bool = player_move_vec.length() > 1.0

	# Occasionally trigger a dash when the player is walking
	if player_is_moving and not is_dashing:
		# dash_chance_per_second is converted to a per-frame probability
		var dash_prob: float = dash_chance_per_second * delta
		if randf() < dash_prob:
			is_dashing = true
			dash_timer = dash_duration

	# Handle dash timer
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false

	# Decide where we *want* to be relative to the player
	var target_position: Vector2

	if is_dashing:
		# Try to be a bit *in front* of the player (based on their recent movement)
		var forward_dir := player_move_vec.normalized() if player_is_moving else to_player.normalized()
		target_position = player_pos + forward_dir * follow_distance
	else:
		# Stay slightly *behind* the player
		var back_dir := (-player_move_vec).normalized() if player_is_moving else (-to_player).normalized()
		target_position = player_pos + back_dir * follow_distance

	# Add some side-to-side randomness so it doesn't look too robotic
	if player_is_moving:
		var side_dir := Vector2(-player_move_vec.y, player_move_vec.x).normalized()
		var random_offset_amount := randf_range(-randomness_radius, randomness_radius)
		target_position += side_dir * random_offset_amount

	# Compute desired velocity towards target
	var to_target := target_position - global_position
	var current_max_speed: float = dash_speed if is_dashing else speed

	if to_target.length() > 2.0:
		velocity = to_target.normalized() * current_max_speed
	else:
		velocity = Vector2.ZERO

	# --- ANIMATION / FACING ---

	if velocity.length() > 0.1:
		if abs(velocity.x) > abs(velocity.y):
			face_direction = "Right" if velocity.x > 0.0 else "Left"
		else:
			face_direction = "Front" if velocity.y > 0.0 else "Back"
	else:
		# keep last face_direction, just switch to idle
		pass

	animation_to_play = face_direction + "_" + ("Walk" if velocity.length() > 0.1 else "Idle")
	if not animation_player.is_playing() or animation_player.current_animation != animation_to_play:
		animation_player.play(animation_to_play)

	# Move character, slide at collision
	move_and_slide()

func apply_skin_index(index: int) -> void:
	if skins.is_empty():
		return

	current_skin_index = index
	sprite.texture = skins[current_skin_index]
