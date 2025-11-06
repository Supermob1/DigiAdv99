extends Camera2D

@export var target_view_size := Vector2(240, 160)
@export var tilt_amount := 0.15  # change this for more/less tilt

func _ready():
	# --- 1. Set the zoom so the visible area = 240x160 world units ---
	var screen_size = get_viewport_rect().size
	zoom = screen_size / target_view_size

	# --- 2. Apply a subtle tilt toward the horizon (fake perspective) ---
	# This skews the camera view slightly
	self.transform = Transform2D(tilt_amount, Vector2.ZERO)
