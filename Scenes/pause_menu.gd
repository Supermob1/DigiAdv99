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


func _ready() -> void:
	# The menu should be hidden at start
	hide()

	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	character_button.pressed.connect(_on_character_pressed)
	index_button.pressed.connect(_on_index_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func open() -> void:
	show()
	# optional: grab focus on first button for keyboard / pad
	resume_button.grab_focus()


func close() -> void:
	hide()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_save_pressed() -> void:
	save_requested.emit()


func _on_character_pressed() -> void:
	character_select_requested.emit()


func _on_index_pressed() -> void:
	digimon_index_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Only care if the menu is visible
	if not visible:
		return

	if event.is_action_pressed("pause"):
		# behave as if the Resume button was pressed
		resume_requested.emit()
		# optional: mark it handled so it doesn’t bubble further
		get_viewport().set_input_as_handled()
