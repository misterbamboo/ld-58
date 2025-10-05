class_name CloudAlpha extends Sprite2D

@export var fade_in_duration: float = 3.0
@export var fade_out_duration: float = 3.0
@export var max_alpha_change_per_second: float = 0.25

var cloud: Cloud
var previous_alpha: float = 0.0

func _ready():
	modulate.a = 0.0
	cloud = get_parent().get_parent() as Cloud

func _process(delta):
	if cloud:
		apply_alpha(delta)

func apply_alpha(delta: float):
	var desired_alpha = calculate_desired_alpha()
	var clamped_alpha = apply_rate_limit(desired_alpha, delta)

	modulate.a = clamped_alpha
	previous_alpha = clamped_alpha

func calculate_desired_alpha() -> float:
	if should_be_invisible():
		return 0.0

	if should_force_fadeout():
		return calculate_force_fadeout_alpha()

	return calculate_normal_alpha()

func apply_rate_limit(desired: float, delta: float) -> float:
	var max_change = max_alpha_change_per_second * delta
	return clamp(desired, previous_alpha - max_change, previous_alpha + max_change)

func should_be_invisible() -> bool:
	return not cloud.ready_to_show()

func should_force_fadeout() -> bool:
	return cloud.is_force_fadeout()

func calculate_force_fadeout_alpha() -> float:
	var fadeout_time = cloud.get_fadeout_time()
	var progress = fadeout_time / fade_out_duration
	return clamp(1.0 - progress, 0.0, 1.0)

func calculate_normal_alpha() -> float:
	var current_time = cloud.get_current_time()
	var lifespan = cloud.get_lifespan()

	if is_fading_in(current_time):
		return calculate_fade_in_alpha(current_time)
	elif is_fading_out(current_time, lifespan):
		return calculate_fade_out_alpha(current_time, lifespan)
	else:
		return 1.0

func is_fading_in(current_time: float) -> bool:
	return current_time < fade_in_duration

func is_fading_out(current_time: float, lifespan: float) -> bool:
	return current_time > lifespan - fade_out_duration

func calculate_fade_in_alpha(current_time: float) -> float:
	var time_to_use = current_time

	if cloud.is_force_fade_in():
		time_to_use = cloud.get_fade_in_time()

	var progress = time_to_use / fade_in_duration
	return clamp(progress, 0.0, 1.0)

func calculate_fade_out_alpha(current_time: float, lifespan: float) -> float:
	var fade_start = lifespan - fade_out_duration
	var progress = (current_time - fade_start) / fade_out_duration
	return clamp(1.0 - progress, 0.0, 1.0)
