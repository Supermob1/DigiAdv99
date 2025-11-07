extends Camera2D

@export var target_view_size := Vector2(240, 160)

func _ready():
	# --- 1. Set the zoom so the visible area = 240x160 world units ---
	var screen_size = get_viewport_rect().size
	zoom = screen_size / target_view_size
