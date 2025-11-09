extends Node2D

@export var rise_distance: float = 8.0      # how high it floats
@export var duration: float = 0.6          # how long it lasts

@onready var label: Label = $Label

var amount: int = 0                 # used for normal damage numbers
var base_color: Color = Color.WHITE
var custom_text: String = ""        # if set, we use this instead of amount


func _ready() -> void:
	# Decide what to display
	if custom_text != "":
		label.text = custom_text
	else:
		label.text = str(amount)

	label.modulate = base_color

	# start visible
	modulate = Color(1.0, 1.0, 1.0, 1.0)

	var start_pos := position
	var tween := create_tween()

	# Move up
	tween.tween_property(
		self, "position",
		start_pos + Vector2(0, -rise_distance),
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Fade out
	tween.parallel().tween_property(
		self, "modulate:a",
		0.0,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.finished.connect(queue_free)
