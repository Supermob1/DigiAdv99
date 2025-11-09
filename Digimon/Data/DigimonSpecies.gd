extends Resource
class_name DigimonSpecies

# Internal ID = must match the "digimon_name" used by GenericDigimon
# (i.e. the base filename of the sprite: "Agumon", "Koromon", "Botamon_Digitama", etc.)
@export var id: StringName

# UI name (you can keep it empty and just use id in UI if you want)
@export var display_name: String = ""

# Which evolution family / line this belongs to.
# For your Botamon line, you could use "BotamonLine" for all of them.
@export var line_id: StringName = &""

# Stage index along that line.
# e.g. 0 = egg, 1 = baby, ..., 6 = mega
@export var stage: int = 0

# --- CONDITIONS TO EVOLVE *INTO* THIS SPECIES ---

@export var min_level: int = 1
@export var min_bond: int = 0
# we’re not using these yet in GenericDigimon.try_digivolve, but we can later:
@export var min_strength: int = 0
@export var min_energy: int = 0

# For “unique partner” lines: which child forms are preferred from this form.
# Example: Koromon.preferred_children = [ "Agumon" ]
@export var preferred_children: Array[StringName] = []

# Optional: mark this as the “default partner line” if you want
@export var is_partner_unique: bool = false
