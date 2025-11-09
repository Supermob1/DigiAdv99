extends CanvasLayer
class_name GameHUD

@export var pet_path: NodePath   # you'll assign this in the main scene

var pet: Node                     # we'll cast it at runtime

@onready var pet_name_label: Label      = $Root/PetPanel/VBoxContainer/PetNameLabel
@onready var pet_hp_bar: TextureProgressBar    = $Root/PetPanel/VBoxContainer/PetHpBar
@onready var level_label: Label         = $Root/PetPanel/VBoxContainer/StatsRow1/LevelLabel
@onready var strength_label: Label      = $Root/PetPanel/VBoxContainer/StatsRow1/StrengthLabel
@onready var energy_label: Label        = $Root/PetPanel/VBoxContainer/StatsRow1/EnergyLabel
@onready var bond_label: Label          = $Root/PetPanel/VBoxContainer/BondLabel
@onready var digivolve_label: Label     = $Root/PetPanel/VBoxContainer/DigivolveLabel
@onready var digivolve_prompt: Label    = $Root/DigivolvePrompt


func _ready() -> void:
	if pet_path != NodePath(""):
		pet = get_node(pet_path)

	if pet and pet.has_signal("health_changed"):
		pet_hp_bar.min_value = 0
		pet_hp_bar.max_value = pet.max_health
		pet_hp_bar.value = pet.health
		pet.health_changed.connect(_on_pet_health_changed)

	_update_all()


func _process(_delta: float) -> void:
	if not pet:
		return

	_update_all()


func _update_all() -> void:
	if not pet:
		return

	# name / HP
	pet_name_label.text = str(pet.digimon_name)
	pet_hp_bar.max_value = pet.max_health
	pet_hp_bar.value = pet.health

	# stats – these properties exist on PetDigimon
	level_label.text    = "Lv %d" % pet.level
	strength_label.text = "Str %d" % pet.strength
	energy_label.text   = "Eng %d" % pet.energy
	bond_label.text     = "Bond %d" % pet.bond

	_update_digivolve_indicator()


func _update_digivolve_indicator() -> void:
	var can_digivolve := false

	if pet and is_instance_valid(DigimonEvolutionDB):
		var options = DigimonEvolutionDb.get_possible_evolutions(
			pet.digimon_name,
			pet.level,
			pet._get_bond_for_evo(),
			[]   # no special conditions yet
		)
		# PetForm.NORMAL = 0 in your enum, so just check form_state == 0
		can_digivolve = options.size() > 0 and pet.form_state == 0

	if can_digivolve:
		digivolve_label.text = "Digivolve: READY"
		digivolve_label.modulate = Color(0.2, 1.0, 0.2)
		digivolve_prompt.visible = true
	else:
		digivolve_label.text = "Digivolve: ---"
		digivolve_label.modulate = Color(1, 1, 1)
		digivolve_prompt.visible = false


func _on_pet_health_changed(current: int, max: int) -> void:
	pet_hp_bar.max_value = max
	pet_hp_bar.value = current
