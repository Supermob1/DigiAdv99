extends Node
class_name GameData

# All available tamers in the game.
# 🔧 Change paths / partner_id to fit your project.
const TAMERS := {
	"tai": {
		"display_name": "Taichi",
		"player_texture": preload("res://textures/Tai/tai_16x16.png"),
		"partner_id": "Koromon",   # must match your digimon_name / .png
	},
	"matt": {
		"display_name": "Yamato",
		"player_texture": preload("res://textures/Matt/matt_16x16.png"),
		"partner_id": "Tsunomon",  # example, change if needed
	},
	"teto": {
		"display_name": "Teto",
		"player_texture": preload("res://textures/Teto/Teto_16x16.png"),
		"partner_id": "Punimon",   # example, change if needed
	},
}

var current_tamer_id: StringName = &"tai"

func get_tamer_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for k in TAMERS.keys():
		ids.append(k)
	return ids

func get_current_tamer() -> Dictionary:
	if TAMERS.has(current_tamer_id):
		return TAMERS[current_tamer_id]
	# Fallback: first in dictionary
	for v in TAMERS.values():
		return v
	return {}

func get_tamer_by_index(index: int) -> StringName:
	var ids := get_tamer_ids()
	if index < 0 or index >= ids.size():
		return current_tamer_id
	return ids[index]

func get_index_for_current() -> int:
	var ids := get_tamer_ids()
	return ids.find(current_tamer_id)
