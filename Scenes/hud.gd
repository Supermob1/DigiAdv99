extends CanvasLayer

# In the inspector, drag your Pet Digimon node (CharacterBody2D with the stats script)
@export var pet: CharacterBody2D   # no explicit type, so no "max_health" warnings

# ---- NODE REFS ----
@onready var pet_name_label: Label          = $Root/PetPanel/VBoxContainer/PetNameLabel
@onready var pet_hp_bar: TextureProgressBar = $Root/PetPanel/VBoxContainer/PetHpBar

@onready var strength_bar: TextureProgressBar = $Root/STATSBars/HBoxContainer/StrengthBar
@onready var strength_label: Label            = $Root/STATSBars/HBoxContainer/StrengthLabel

@onready var energy_bar: TextureProgressBar = $Root/STATSBars/HBoxContainer2/EnergyBar
@onready var energy_label: Label            = $Root/STATSBars/HBoxContainer2/EnergyLabel

@onready var bond_bar: TextureProgressBar = $Root/STATSBars/HBoxContainer3/BondBar
@onready var bond_label: Label            = $Root/STATSBars/HBoxContainer3/BondLabel

@onready var digivolve_prompt: Label = $Root/DigivolvePrompt

# ---- CONFIG ----
@export var max_strength: int = 20
@export var max_energy: int = 20
@export var digivolve_bond_threshold: int = 50  # when DIGIVOLVE starts glowing

var _last_can_digivolve: bool = false
var _glow_tween: Tween = null


func _ready() -> void:
	if pet == null:
		push_warning("HUD: 'pet' is not assigned in the inspector.")
		return

	# Setup HP bar based on current pet stats
	if "max_health" in pet:
		pet_hp_bar.min_value = 0
		pet_hp_bar.max_value = pet.max_health

	# Stats bars
	strength_bar.min_value = 0
	strength_bar.max_value = max_strength

	energy_bar.min_value = 0
	energy_bar.max_value = max_energy

	bond_bar.min_value = 0
	bond_bar.max_value = 100

	_update_all(true)


func _process(_delta: float) -> void:
	_update_all(false)


func _update_all(force: bool) -> void:
	if pet == null:
		return

	# --- Name & HP ---
	if "digimon_name" in pet:
		pet_name_label.text = str(pet.digimon_name)
	else:
		pet_name_label.text = "???"

	if "max_health" in pet and "health" in pet:
		pet_hp_bar.max_value = pet.max_health
		pet_hp_bar.value = pet.health

	# --- Stats ---
	var str_val := 0
	var eng_val := 0
	var bond_val := 0

	if "strength" in pet:
		str_val = pet.strength
	if "energy" in pet:
		eng_val = pet.energy
	if "bond" in pet:
		bond_val = pet.bond

	strength_bar.value = clamp(str_val, 0, max_strength)
	energy_bar.value   = clamp(eng_val, 0, max_energy)
	bond_bar.value     = clamp(bond_val, 0, 100)

	strength_label.text = "STR"
	energy_label.text   = "ENG"
	bond_label.text     = "BND"

	# --- DIGIVOLVE available? (for now just based on bond) ---
	var can_digivolve: bool = bond_val >= digivolve_bond_threshold

	if force or can_digivolve != _last_can_digivolve:
		_last_can_digivolve = can_digivolve
		if can_digivolve:
			_start_glow()
		else:
			_stop_glow()


func _start_glow() -> void:
	_stop_glow()

	digivolve_prompt.modulate = Color(1, 1, 1, 1)

	_glow_tween = create_tween()
	_glow_tween.set_loops()

	_glow_tween.tween_property(
		digivolve_prompt, "modulate",
		Color(1.0, 1.0, 0.4, 1.0), 0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_glow_tween.tween_property(
		digivolve_prompt, "modulate",
		Color(1.0, 1.0, 1.0, 1.0), 0.45
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
		_glow_tween = null

	digivolve_prompt.modulate = Color(0.4, 0.4, 0.4, 1.0)
