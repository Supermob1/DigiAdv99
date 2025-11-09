extends Node2D
class_name EnemySpawner

# Scene to instance (your EnemyDigimon scene that extends GenericDigimon)
@export var enemy_scene: PackedScene

# Names of Digimon this spawner can produce
@export var digimon_name_pool: Array[StringName] = []

# Spawn positions; if empty, Marker2D children will be used,
# and if STILL empty, it will use this spawner's own position.
@export var spawn_points: Array[Vector2] = []

@export var max_alive: int = 5
@export var respawn_delay: float = 8.0
@export var random_level_range: Vector2i = Vector2i(1, 10)  # [min, max]

var _active_enemies: Array[Node2D] = []
var _respawn_queue: Array[Vector2] = []


func _ready() -> void:
	randomize()

	# If no explicit spawn_points, use Marker2D children
	if spawn_points.is_empty():
		for child in get_children():
			if child is Marker2D:
				spawn_points.append(child.global_position)

	# If STILL empty, fall back to this node's own position
	if spawn_points.is_empty():
		push_warning("EnemySpawner '%s': no spawn_points/Marker2D, using own position." % name)
		spawn_points.append(global_position)

	_spawn_initial()


func _process(_delta: float) -> void:
	_cleanup_dead()
	_check_respawns()


func _spawn_initial() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner '%s': enemy_scene is not assigned." % name)
		return

	if max_alive <= 0:
		push_warning("EnemySpawner '%s': max_alive <= 0, nothing will spawn." % name)
		return

	for i in range(spawn_points.size()):
		if _active_enemies.size() >= max_alive:
			break
		_spawn_enemy(spawn_points[i])


func _pick_random_digimon_name() -> StringName:
	if digimon_name_pool.is_empty():
		return &""
	var idx := randi_range(0, digimon_name_pool.size() - 1)
	return digimon_name_pool[idx]


func _spawn_enemy(pos: Vector2) -> void:
	if enemy_scene == null:
		return

	var enemy := enemy_scene.instantiate()
	if not enemy:
		return

	# ---- Configure BEFORE adding to tree ----
	var chosen_name: StringName = _pick_random_digimon_name()

	if chosen_name != &"" and ("digimon_name" in enemy):
		enemy.digimon_name = chosen_name

	if "level" in enemy:
		enemy.level = randi_range(random_level_range.x, random_level_range.y)

	# Defer the actual add_child() so we don't hit "Parent node is busy"
	call_deferred("_deferred_add_enemy", enemy, pos, chosen_name)

	_active_enemies.append(enemy)


func _deferred_add_enemy(enemy: Node, pos: Vector2, chosen_name: StringName) -> void:
	if not is_instance_valid(enemy):
		return

	var parent := get_parent()
	if parent == null:
		return

	# Add to tree
	parent.add_child(enemy)

	# Place it at the spawn position
	enemy.global_position = pos

	# Make sure its "home_position" matches the spawn, if that property exists
	if "home_position" in enemy:
		enemy.home_position = pos

	# Add to groups
	if not enemy.is_in_group("Digimon"):
		enemy.add_to_group("Digimon")
	if not enemy.is_in_group("WildDigimon"):
		enemy.add_to_group("WildDigimon")

	# Debug print
	print("Spawner '%s' spawned %s at %s (Groups: Digimon, WildDigimon)" %
		[name, chosen_name if chosen_name != &"" else "<default>", pos])

	# Hook respawn on death if the enemy has 'died' signal
	if enemy.has_signal("died"):
		enemy.died.connect(func():
			_queue_respawn(pos)
		)



func _queue_respawn(pos: Vector2) -> void:
	await get_tree().create_timer(respawn_delay).timeout
	_respawn_queue.append(pos)


func _check_respawns() -> void:
	if _respawn_queue.is_empty():
		return

	for pos in _respawn_queue:
		if _active_enemies.size() < max_alive:
			_spawn_enemy(pos)
	_respawn_queue.clear()


func _cleanup_dead() -> void:
	_active_enemies = _active_enemies.filter(
		func(e):
			return is_instance_valid(e)
	)
