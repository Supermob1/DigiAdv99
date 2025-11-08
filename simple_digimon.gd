extends CharacterBody2D
class_name SimpleDigimon

# How many frames in our sheets (you said always 2)
const BODY_HFRAMES := 2
const BODY_VFRAMES := 1        # for now: 1 row (side view). We can expand later.
const ATTACK_HFRAMES := 2
const ATTACK_VFRAMES := 1

@export var speed: float = 50.0
@export var attack_duration: float = 0.25   # seconds for 2 attack frames

@onready var sprite: Sprite2D = $Sprite     # child Sprite2D

var body_texture: Texture2D
var attack_texture: Texture2D

var face_direction: String = "Right"  # "Left" or "Right" for now
var is_moving: bool = false
var is_attacking: bool = false

var anim_timer: float = 0.0
var attack_timer: float = 0.0

const IDLE_FPS := 2.0
const WALK_FPS := 6.0
const ATTACK_FPS := 8.0


func _ready() -> void:
	_load_textures_from_scene_folder()
	_setup_body()


func _load_textures_from_scene_folder() -> void:
	# Example scene path: res://Digimon/BotamonLine/5.2 - SkullGraymon/SkullGraymon.tscn
	var scene_path: String = get_scene_file_path()
	var dir: String = scene_path.get_base_dir()            # .../5.2 - SkullGraymon
	var scene_file: String = scene_path.get_file()         # SkullGraymon.tscn
	var base_name: String = scene_file.get_basename()      # SkullGraymon

	var body_path: String = dir + "/" + base_name + ".png"
	var attack_path: String = dir + "/" + base_name + "_Attack.png"

	body_texture = load(body_path) as Texture2D
	attack_texture = load(attack_path) as Texture2D

	if body_texture == null:
		push_error("Could not load body texture at: " + body_path)
	if attack_texture == null:
		push_error("Could not load attack texture at: " + attack_path)


func _setup_body() -> void:
	is_attacking = false
	sprite.texture = body_texture
	sprite.hframes = BODY_HFRAMES
	sprite.vframes = BODY_VFRAMES
	sprite.flip_h = (face_direction == "Right")
	sprite.frame = 0


func _physics_process(delta: float) -> void:
	if is_attacking:
		_update_attack(delta)
	else:
		_update_movement_and_input(delta)

	_update_animation(delta)
	move_and_slide()


func _update_movement_and_input(_delta: float) -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

	# For now: side view only (Left/Right)
	if input_dir.x != 0.0:
		input_dir = input_dir.normalized()
		velocity = input_dir * speed
		is_moving = true

		face_direction = "Right" if input_dir.x > 0.0 else "Left"
	else:
		velocity = Vector2.ZERO
		is_moving = false

	# Attack input
	if Input.is_action_just_pressed("digimon_attack") and not is_attacking:
		_start_attack()


func _start_attack() -> void:
	is_attacking = true
	attack_timer = 0.0
	anim_timer = 0.0

	sprite.texture = attack_texture
	sprite.hframes = ATTACK_HFRAMES
	sprite.vframes = ATTACK_VFRAMES
	sprite.flip_h = (face_direction == "Right")
	sprite.frame = 0


func _update_attack(delta: float) -> void:
	attack_timer += delta
	if attack_timer >= attack_duration:
		_setup_body()
		return


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
