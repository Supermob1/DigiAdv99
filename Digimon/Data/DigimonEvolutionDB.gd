extends Node
class_name DigimonEvolutionDB

# Folder where all DigimonLine.tres live
@export_dir var lines_root: String = "res://Digimon/Lines"

# from_name -> Array[DigivolutionStep]
var _steps_by_from: Dictionary = {}
var _steps_by_to: Dictionary = {}    # NEW: reverse mapping

func _ready() -> void:
	_load_lines()


func _load_lines() -> void:
	_steps_by_from.clear()

	var stack: Array[String] = [lines_root]

	while stack.size() > 0:
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
				var ext := name.get_extension().to_lower()
				if ext == "tres" or ext == "res":
					var res_path := dir_path + "/" + name
					var line_res := load(res_path)
					if line_res is DigimonLine:
						var line: DigimonLine = line_res
						for step in line.steps:
							if step.from_name == "":
								continue
							if not _steps_by_from.has(step.from_name):
								_steps_by_from[step.from_name] = []
							_steps_by_from[step.from_name].append(step)
							if not _steps_by_to.has(step.to_name):
								_steps_by_to[step.to_name] = []
							_steps_by_to[step.to_name].append(step)

			name = dir.get_next()
		dir.list_dir_end()


func get_possible_evolutions(
	from_name: StringName,
	level: int,
	bond: int,
	active_conditions: Array[StringName] = []
) -> Array[DigivolutionStep]:
	var results: Array[DigivolutionStep] = []

	if not _steps_by_from.has(from_name):
		return results

	for step in _steps_by_from[from_name]:
		if level < step.min_level:
			continue
		if bond < step.min_bond:
			continue

		# if a special condition is required, it must be in active_conditions
		if step.special_condition != &"" and step.special_condition not in active_conditions:
			continue

		results.append(step)

	return results
	
func get_root_form_for(name: StringName) -> StringName:
	# Walk backwards as long as there is a step that evolves INTO "current"
	var current: StringName = name

	while _steps_by_to.has(current) and _steps_by_to[current].size() > 0:
		# assume a simple line; if multiple, we just pick the first
		var prev_step: DigivolutionStep = _steps_by_to[current][0]
		current = prev_step.from_name

	return current
	
func get_first_child_after_root(ref_name: StringName) -> StringName:
	var root: StringName = get_root_form_for(ref_name)

	# If the root has at least one evolution step, return its first child
	if _steps_by_from.has(root) and _steps_by_from[root].size() > 0:
		var step: DigivolutionStep = _steps_by_from[root][0]
		return step.to_name

	# Fallback if there are no children in the line
	return root
