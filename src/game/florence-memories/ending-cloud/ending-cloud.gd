extends Sprite2D

# Static coordination for sequential animation
static var clouds: Array[Sprite2D] = []

const FADE_DURATION: float = 0.1
const FADE_OUT_DURATION: float = 1.0
const ANIM_SCALE: float = 0.15
const ANIM_ROTATION: float = 0.15

var cloud_index: int = -1
var initial_scale: Vector2
var initial_rotation: float
var fade_in_start_time: float = 0.0
var is_faded_in: bool = false
var is_fading_out: bool = false
var fade_out_start_time: float = 0.0

# Random animation parameters for unique movement
var animation_offset: float = 0.0
var scale_speed: float = 1.0
var rotation_speed: float = 1.0

func _ready() -> void:
	# Store initial values
	initial_scale = scale
	initial_rotation = rotation

	# Start invisible
	modulate.a = 0.0

	# Register in static array
	cloud_index = clouds.size()
	clouds.append(self)

	# Calculate when this cloud should start fading in
	fade_in_start_time = cloud_index * FADE_DURATION

	# Randomize animation parameters for unique movement
	animation_offset = randf() * TAU  # Random phase 0 to 2π
	scale_speed = randf_range(0.5, 1.5)
	rotation_speed = randf_range(0.5, 1.5)

func _process(delta: float) -> void:
	var timer = get_timer()

	# Handle fade-out (takes priority)
	if is_fading_out:
		update_fade_out(timer)
		return

	# Handle fade-in
	if not is_faded_in:
		update_fade_in(timer)
	else:
		# Gentle animation after fade-in
		apply_gentle_animation(timer)

func get_timer() -> float:
	var parent = get_parent()
	if parent and parent.has_method("get_timer"):
		return parent.get_timer()
	return 0.0

func update_fade_in(timer: float) -> void:
	if timer >= fade_in_start_time:
		var fade_progress = (timer - fade_in_start_time) / FADE_DURATION
		modulate.a = clamp(fade_progress, 0.0, 1.0)

		if fade_progress >= 1.0:
			is_faded_in = true

func apply_gentle_animation(timer: float) -> void:
	# Gentle scale and rotation oscillation with random timing
	var scale_oscillation = 1.0 + sin((timer + animation_offset) * scale_speed) * ANIM_SCALE
	scale = initial_scale * scale_oscillation

	rotation = initial_rotation + sin((timer + animation_offset) * rotation_speed * 0.8) * ANIM_ROTATION

func start_fade_out(timer: float) -> void:
	is_fading_out = true
	fade_out_start_time = timer

func update_fade_out(timer: float) -> void:
	var fade_progress = (timer - fade_out_start_time) / FADE_OUT_DURATION
	modulate.a = clamp(1.0 - fade_progress, 0.0, 1.0)
