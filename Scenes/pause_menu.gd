extends Control
class_name PauseMenu

signal resume_requested
signal save_requested
signal quit_requested
signal character_select_requested
signal digimon_index_requested

@onready var resume_button: Button = $CenterContainer/Panel/VBox/ResumeButton
@onready var save_button: Button = $CenterContainer/Panel/VBox/SaveButton
@onready var character_button: Button = $CenterContainer/Panel/VBox/CharacterSelectButton
@onready var index_button: Button = $CenterContainer/Panel/VBox/DigimonIndexButton
@onready var quit_button: Button = $CenterContainer/Panel/VBox/QuitButton
@onready var character_selector: OptionButton = $CenterContainer/Panel/VBox/CharacterRow/CharacterSelector
@onready var character_row: HBoxContainer = $CenterContainer/Panel/VBox/CharacterRow

var _player: Node = null
var _pet: PetDigimon = null


func _ready() -> void:
	hide()
	character_row.visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	character_button.pressed.connect(_on_character_pressed)
	index_button.pressed.connect(_on_index_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	character_selector.item_selected.connect(_on_character_selector_item_selected)

	# make sure Player/Pet exist
	await get_tree().process_frame
	_find_player_and_pet()
	_populate_character_selector()


func open() -> void:
	show()
	resume_button.grab_focus()


func close() -> void:
	hide()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_character_pressed() -> void:
	character_row.visible = not character_row.visible
	if character_row.visible:
		character_selector.grab_focus()
	character_select_requested.emit()


func _on_index_pressed() -> void:
	digimon_index_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()


func _find_player_and_pet() -> void:
	var player_candidates := get_tree().get_nodes_in_group("Player")
	if player_candidates.size() > 0:
		_player = player_candidates[0]
	else:
		print("PauseMenu: no Player found in group 'Player'")

	var pet_candidates := get_tree().get_nodes_in_group("PetDigimon")
	if pet_candidates.size() > 0:
		_pet = pet_candidates[0] as PetDigimon
	else:
		print("PauseMenu: no PetDigimon found in group 'PetDigimon'")


func _populate_character_selector() -> void:
	if not is_instance_valid(GameData):
		return

	character_selector.clear()

	var ids: Array[StringName] = Game_Data.get_tamer_ids()
	var current_index: int = Game_Data.get_index_for_current()

	for i in ids.size():
		var id: StringName = ids[i]
		var cfg: Dictionary = GameData.TAMERS[id]
		var label: String = cfg.get("display_name", str(id))
		character_selector.add_item(label)

	if current_index >= 0 and current_index < ids.size():
		character_selector.select(current_index)


func _on_character_selector_item_selected(index: int) -> void:
	if not is_instance_valid(GameData):
		return

	var new_id := Game_Data.get_tamer_by_index(index)
	Game_Data.current_tamer_id = new_id

	print("PauseMenu: selected tamer id =", new_id)

	# Apply to player
	if _player and _player.has_method("_apply_tamer_skin"):
		print("PauseMenu: calling _apply_tamer_skin on Player:", _player)
		_player._apply_tamer_skin()

	# Apply to pet
	if _pet and _pet.has_method("refresh_from_tamer"):
		print("PauseMenu: calling refresh_from_tamer on pet")
		_pet.refresh_from_tamer()



func _unhandled_input(event: InputEvent) -> void:
	# Only care if the menu is visible
	if not visible:
		return

	if event.is_action_pressed("pause"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
