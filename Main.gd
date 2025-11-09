extends Node2D   # or whatever your root is

@onready var pause_menu: PauseMenu = $HUD/PauseMenu


func _ready() -> void:
	# Connect pause menu signals
	pause_menu.resume_requested.connect(_on_pause_menu_resume)
	pause_menu.save_requested.connect(_on_pause_menu_save)
	pause_menu.quit_requested.connect(_on_pause_menu_quit)
	pause_menu.character_select_requested.connect(_on_pause_menu_character)
	pause_menu.digimon_index_requested.connect(_on_pause_menu_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):   # define "pause" in Input Map (Esc, Start, etc.)
		_toggle_pause()


func _toggle_pause() -> void:
	var now_paused := get_tree().paused

	if now_paused:
		# Unpause
		get_tree().paused = false
		pause_menu.close()
	else:
		# Pause
		get_tree().paused = true
		pause_menu.open()


func _on_pause_menu_resume() -> void:
	get_tree().paused = false
	pause_menu.close()


func _on_pause_menu_save() -> void:
	# 🔹 Placeholder for now – hook your save system here.
	print("SAVE: (TODO) collect player/pet state and write to a file.")


func _on_pause_menu_quit() -> void:
	# For now, just quit the whole game. Later: go to title screen scene.
	get_tree().paused = false
	get_tree().quit()


func _on_pause_menu_character() -> void:
	# Later: open a character-selection panel, or switch to a sub-menu.
	print("Character selection menu (TODO)")


func _on_pause_menu_index() -> void:
	# Later: open Digimon index UI that reads from DigimonEvolutionDb.
	print("Digimon index menu (TODO)")
