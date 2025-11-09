extends Node
class_name DigimonEvolutionDB

# Where all *.mon species files live (we'll scan recursively)
@export_dir var species_root: String = "res://Digimon/Species"

# ---------- internal data ----------

class Species:
	var id: StringName = &""
	var name: String = ""
	var type: StringName = &""

	var stage_index: int = 0
	var stage_name: StringName = &""

	var min_level: int = 1
	var min_bond: int = 0

	var digivolutions: Array[StringName] = []
	var preferred_children: Array[StringName] = []

# id -> Species
var _species_by_id: Dictionary = {}
# child_id -> Array[parent_id]
var _parents_by_child: Dictionary = {}

# mapping Stage string -> numeric index
const STAGE_TO_INDEX := {
	"egg": 0,
	"baby": 1,
	"intraining": 2,
	"rookie": 3,
	"champion": 4,
	"ultimate": 5,
	"mega": 6,
	"ultra": 7
}

func _ready() -> void:
	_load_species()


# ---------------------------------------------------------
# LOADING / PARSING
# ---------------------------------------------------------

func _load_species() -> void:
	_species_by_id.clear()
	_parents_by_child.clear()

	var stack: Array[String] = [species_root]

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
				if name.get_extension().to_lower() == "mon":
					_parse_mon_file(dir_path + "/" + name)
			name = dir.get_next()
		dir.list_dir_end()

	_build_parent_map()
	print("Loaded species:", _species_by_id.keys())


func _build_parent_map() -> void:
	_parents_by_child.clear()

	for s in _species_by_id.values():
		var species: Species = s
		for child_id in species.digivolutions:
			if not _parents_by_child.has(child_id):
				_parents_by_child[child_id] = []
			var arr: Array = _parents_by_child[child_id]
			arr.append(species.id)
			_parents_by_child[child_id] = arr


func _parse_mon_file(path: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("DigimonEvolutionDB: cannot open species file: %s" % path)
		return

	var s := Species.new()
	s.id = &""  # we'll fill from Id or filename

	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#") or line.begins_with(";"):
			continue

		var eq := line.find("=")
		if eq == -1:
			continue

		var key := line.substr(0, eq).strip_edges()
		var value := line.substr(eq + 1).strip_edges()

		match key.to_lower():
			"id":
				s.id = value
			"name":
				s.name = value
			"type":
				s.type = value
			"stage":
				s.stage_name = value
				s.stage_index = _stage_string_to_index(value)
			"stageindex":
				s.stage_index = int(value)
			"minlevel":
				s.min_level = int(value)
			"minbond":
				s.min_bond = int(value)
			"digivolution":
				s.digivolutions = _parse_list(value)
			"preferred":
				s.preferred_children = _parse_list(value)

	f.close()

	# Fallback id from filename
	if s.id == &"":
		var base := path.get_file().get_basename()
		s.id = base

	# Register in dictionary
	_species_by_id[s.id] = s


func _stage_string_to_index(stage: String) -> int:
	var key := stage.strip_edges().to_lower().replace(" ", "")
	if STAGE_TO_INDEX.has(key):
		return STAGE_TO_INDEX[key]
	return 0  # default to egg/baby if unknown


func _parse_list(raw: String) -> Array[StringName]:
	var txt := raw.strip_edges()
	if txt.begins_with("[") and txt.ends_with("]"):
		txt = txt.substr(1, txt.length() - 2)

	if txt == "":
		return []

	var parts := txt.split(",", false)
	var out: Array[StringName] = []
	for p in parts:
		var id := p.strip_edges()
		if id != "":
			out.append(id)
	return out


func _cmp_species_by_stage(a: Species, b: Species) -> int:
	if a.stage_index == b.stage_index:
		return 0
	return -1 if a.stage_index < b.stage_index else 1


# ---------------------------------------------------------
# INTERNAL HELPERS
# ---------------------------------------------------------

func get_species(id: StringName) -> Species:
	return _species_by_id.get(id, null)


func get_root_form_for(name: StringName) -> StringName:
	var current_id: StringName = name
	var current := get_species(current_id)
	if current == null:
		return name

	while _parents_by_child.has(current_id) and (_parents_by_child[current_id] as Array).size() > 0:
		var best_parent_id: StringName = current_id
		var best_parent := current

		for pid in _parents_by_child[current_id]:
			var ps := get_species(pid)
			if ps == null:
				continue
			if ps.stage_index < best_parent.stage_index:
				best_parent = ps
				best_parent_id = ps.id

		if best_parent_id == current_id:
			break
		current_id = best_parent_id
		current = best_parent

	return current_id


# ---------------------------------------------------------
# PUBLIC API – USED BY YOUR OTHER SCRIPTS
# ---------------------------------------------------------

# Used by GenericDigimon._get_stage_base_access()
func get_stage_info_for(name: StringName) -> Dictionary:
	var s := get_species(name)
	if s == null:
		return {"index": 0, "count": 1}

	var root_id := get_root_form_for(name)

	var visited := {}
	var ordered: Array[Species] = []
	var queue: Array[StringName] = [root_id]

	while queue.size() > 0:
		var cur_id: StringName = queue.pop_front()
		if visited.has(cur_id):
			continue
		visited[cur_id] = true

		var cur := get_species(cur_id)
		if cur == null:
			continue

		ordered.append(cur)

		for child_id in cur.digivolutions:
			if not visited.has(child_id):
				queue.append(child_id)

	if ordered.is_empty():
		return {"index": 0, "count": 1}

	ordered.sort_custom(Callable(self, "_cmp_species_by_stage"))

	var idx := 0
	for i in ordered.size():
		if ordered[i].id == name:
			idx = i
			break

	return {"index": idx, "count": ordered.size()}


# Used by PetDigimon egg logic
func get_first_child_after_root(ref_name: StringName) -> StringName:
	var root_id := get_root_form_for(ref_name)
	var root := get_species(root_id)
	if root == null:
		return ref_name

	var best_child_id: StringName = root_id
	var best_stage := 999

	for child_id in root.digivolutions:
		var cs := get_species(child_id)
		if cs == null:
			continue
		if cs.stage_index > root.stage_index and cs.stage_index < best_stage:
			best_stage = cs.stage_index
			best_child_id = cs.id

	return best_child_id


# Main evolution query, used by GenericDigimon.try_digivolve()
func get_possible_evolutions(
	from_name: StringName,
	level: int,
	bond: int,
	active_conditions: Array[StringName] = []
) -> Array[DigivolutionStep]:
	var results: Array[DigivolutionStep] = []

	var from_species := get_species(from_name)
	if from_species == null:
		return results

	for child_id in from_species.digivolutions:
		var target := get_species(child_id)
		if target == null:
			continue

		if level < target.min_level:
			continue
		if bond < target.min_bond:
			continue

		var step := DigivolutionStep.new()
		step.from_name = from_name
		step.to_name = target.id
		step.min_level = target.min_level
		step.min_bond = target.min_bond
		step.special_condition = &""

		results.append(step)

	return results
