extends GenericDigimon

@export var target: GenericDigimon        # the PET digimon
@export var player: CharacterBody2D       # the human, to ignore collisions with
@export var zone_radius: float = 80.0     # territory around spawn
@export var return_speed: float = 30.0
@export var stop_distance: float = 18.0   # min distance to target when chasing

var home_position: Vector2

# ---- auto digivolve rules ----
@export var auto_digivolve: bool = true
@export_range(0.0, 1.0) var digivolve_hp_threshold: float = 0.4   # 40% HP
@export var digivolve_min_level: int = 5
@export var digivolve_conditions: Array[StringName] = []          # e.g. ["dark"]

func _ready() -> void:
	super._ready()
	home_position = global_position

	if player:
		add_collision_exception_with(player)


func process_ai(_delta: float) -> void:
	velocity = Vector2.ZERO

	if not target:
		_return_home()
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist_to_target: float = to_target.length()
	var dist_self_to_home: float = (global_position - home_position).length()
	var dist_target_to_home: float = (target.global_position - home_position).length()

	# If target (pet) leaves this enemy's zone: end battle & go home
	if dist_target_to_home > zone_radius:
		if is_evolved():
			end_battle()
		_return_home()
		return

	# Within zone: maybe digivolve mid-fight
	_maybe_auto_digivolve()

	# Chase / attack logic
	if dist_to_target <= attack_range:
		face_direction = "Right" if to_target.x > 0.0 else "Left"
		start_attack(to_target)
		velocity = Vector2.ZERO
	elif dist_to_target > stop_distance:
		face_direction = "Right" if to_target.x > 0.0 else "Left"
		velocity = to_target.normalized() * speed
	else:
		velocity = Vector2.ZERO

	# Hard clamp: don't wander way out of zone
	if dist_self_to_home > zone_radius + 8.0:
		var back: Vector2 = (home_position - global_position).normalized()
		velocity = back * speed


func _return_home() -> void:
	var to_home: Vector2 = home_position - global_position
	if to_home.length() > 4.0:
		velocity = to_home.normalized() * return_speed
		face_direction = "Right" if to_home.x > 0.0 else "Left"
	else:
		velocity = Vector2.ZERO


func _maybe_auto_digivolve() -> void:
	if not auto_digivolve:
		return
	if is_evolved():
		return
	if level < digivolve_min_level:
		return

	if float(health) / float(max_health) > digivolve_hp_threshold:
		return

	# Try evolution via DB; if success, disable further auto digivolve
	if try_digivolve(digivolve_conditions):
		auto_digivolve = false
