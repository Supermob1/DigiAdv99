extends GenericDigimon

# Group where the pet lives
@export var target_group: StringName = "PetDigimon"

# Territory around spawn
@export var zone_radius: float = 80.0
@export var engage_distance: float = 120.0   # how far they “notice” the pet
@export var stop_distance: float = 18.0      # min distance when chasing
@export var return_speed: float = 30.0

# Idle wandering around home
@export var wander_radius: float = 32.0
@export var wander_change_interval: float = 1.5

var target: Node2D = null
var home_position: Vector2
var _wander_offset: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0


func _ready() -> void:
	super._ready()
	# Spawner overwrites this to the spawn point; this is just a safe default
	home_position = global_position
	_pick_new_wander_offset()


func process_ai(delta: float) -> void:
	# 1) Find / refresh target from group
	if target == null or not is_instance_valid(target):
		var candidates := get_tree().get_nodes_in_group(target_group)
		if candidates.size() > 0 and candidates[0] is Node2D:
			target = candidates[0] as Node2D

	# 2) No valid target → wander around home
	if target == null or not is_instance_valid(target):
		_handle_wander(delta)
		return

	var target_pos: Vector2 = target.global_position
	var to_target: Vector2 = target_pos - global_position
	var dist_to_target: float = to_target.length()
	var dist_self_home: float = (global_position - home_position).length()
	var dist_target_home: float = (target_pos - home_position).length()

	# Pet is outside our territory → ignore it, but still wander at home
	if dist_target_home > zone_radius:
		_handle_wander(delta)
		return

	# Pet is inside territory but too far to care → wander
	if dist_to_target > engage_distance:
		_handle_wander(delta)
		return

	# Inside zone & in engagement range:
	if dist_to_target <= attack_range:
		# Face pet
		if abs(to_target.x) > abs(to_target.y):
			face_direction = "Right" if to_target.x > 0.0 else "Left"
		else:
			face_direction = "Front" if to_target.y > 0.0 else "Back"

		start_attack()
		velocity = Vector2.ZERO
	elif dist_to_target > stop_distance:
		# Chase toward pet
		if abs(to_target.x) > abs(to_target.y):
			face_direction = "Right" if to_target.x > 0.0 else "Left"
		else:
			face_direction = "Front" if to_target.y > 0.0 else "Back"

		velocity = to_target.normalized() * speed
	else:
		# Close but not in attack range: shuffle around a bit
		_handle_wander(delta)

	# Clamp: don’t wander too far from home
	if dist_self_home > zone_radius + 8.0:
		var back: Vector2 = (home_position - global_position).normalized()
		velocity = back * speed


# ------------------ WANDER AROUND HOME ------------------

func _handle_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or _wander_offset == Vector2.ZERO:
		_pick_new_wander_offset()

	var target_pos: Vector2 = home_position + _wander_offset
	var to_pos: Vector2 = target_pos - global_position

	if to_pos.length() > 2.0:
		velocity = to_pos.normalized() * speed
	else:
		velocity = Vector2.ZERO

	if velocity.length() > 0.1:
		if abs(velocity.x) > abs(velocity.y):
			face_direction = "Right" if velocity.x > 0.0 else "Left"
		else:
			face_direction = "Front" if velocity.y > 0.0 else "Back"


func _pick_new_wander_offset() -> void:
	var angle: float = randf() * TAU
	var r: float = randf() * wander_radius
	_wander_offset = Vector2(cos(angle), sin(angle)) * r
	_wander_timer = wander_change_interval + randf_range(-0.5, 0.5)


# ------------------ RETURN HOME (still used if they get pushed away) ------------------

func _return_home() -> void:
	var to_home: Vector2 = home_position - global_position
	if to_home.length() > 4.0:
		velocity = to_home.normalized() * return_speed

		if abs(to_home.x) > abs(to_home.y):
			face_direction = "Right" if to_home.x > 0.0 else "Left"
		else:
			face_direction = "Front" if to_home.y > 0.0 else "Back"
	else:
		velocity = Vector2.ZERO


# ------------------ XP REWARD ON DEATH ------------------

func die() -> void:
	_give_xp_to_pet()
	super.die()


func _give_xp_to_pet() -> void:
	var pets := get_tree().get_nodes_in_group("PetDigimon")
	if pets.is_empty():
		return

	var pet_node := pets[0]
	if pet_node == null or not is_instance_valid(pet_node):
		return

	# Compute XP reward based on enemy level (placeholder curve)
	var base: float = 10.0
	var level_factor: float = 1.0 + float(level) * 0.4
	var xp_reward: int = int(round(base * level_factor))

	# Call add_xp on the pet if it exists
	if pet_node.has_method("add_xp"):
		pet_node.call("add_xp", xp_reward)
