extends CharacterBody2D

# Animation Player child node
@onready var animation_player = self.get_node("AnimationPlayer/SpriteAnimationPlayer")
@onready var sprite: Sprite2D = $AnimationPlayer

# Individual textures (optional, just for clarity)
var skin_koromon: Texture2D = preload("res://textures/Koromon/koromon_16x16_alt.png")
var skin_agumon: Texture2D = preload("res://textures/Agumon/Agumon_16x16.png")
var skin_graymon: Texture2D = preload("res://textures/Graymon/Graymon_16x16.png")
var skin_metalgraymon: Texture2D = preload("res://textures/MetalGraymon/MetalGraymon_16x16.png")


# List of all available skins (order = cycle order)
var skins: Array[Texture2D] = []
var current_skin_index: int = 0
# Properties
@export var speed = 50.0
var face_direction = "Front"
var animation_to_play = "Front_Idle"

# Start front idle animation on load
func _ready():
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

func _physics_process(_delta):
	
	# Swap skin when button pressed once
	if Input.is_action_just_pressed("swap_skin"):
		var next_index := (current_skin_index + 1) % skins.size()
		apply_skin_index(next_index)
		
	# Reset velocity
	velocity = Vector2.ZERO
	# Add appropriate velocities depending on button press
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1.0 * speed
		# Only face left/right if not diagonal movement
		if velocity.y == 0.0:
			face_direction = "Left"
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1.0 * speed
		# Only face left/right if not diagonal movement
		if velocity.y == 0.0:
			face_direction = "Right"
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1.0 * speed
		face_direction = "Back"
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1.0 * speed
		face_direction = "Front"
		
	# All movement animations named appropriately, eg "Left_Idle" or "Back_Walk"
	animation_to_play = face_direction + "_" + ("Walk" if velocity.length() > 0.0 else "Idle")
	animation_player.play(animation_to_play)
	
	# Move character, slide at collision
	move_and_slide()

func apply_skin_index(index: int) -> void:
	if skins.is_empty():
		return
	
	current_skin_index = index
	sprite.texture = skins[current_skin_index]
