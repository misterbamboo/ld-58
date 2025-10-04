class_name Cloud extends Sprite2D

@export var min_speed: float = 2.0
@export var max_speed: float = 3.0
@export var squish_duration: float = 6.0
@export var squish_amount: float = 0.05
@export var rotation_amount: float = 0.05

var speed: float
var direction: int
var initial_position: Vector2
var initial_scale: Vector2
var squish_timer: float = 0.0
var is_managed_by_shape: bool = false

var internal_time: float = 0.0
var lifespan: float = 0.0
var target_position: Vector2
var spawn_position: Vector2

var fade_in_duration: float = 3.0
var moving_in_duration: float = 5.0
var moving_out_duration: float = 5.0
var fade_out_duration: float = 3.0

var override_rotation: bool = false
var target_rotation: float = 0.0

var phase_data: Dictionary = {}
var current_phase_index: int = 0

func _ready():
	initial_position = position
	initial_scale = scale
	speed = randf_range(min_speed, max_speed)
	squish_timer = randf_range(0.0, squish_duration)
	modulate.a = 0.0
	spawn_position = position
	target_position = position
	# Direction defaults to random, can be overridden by spawner
	if direction == 0:
		direction = 1 if randf() > 0.5 else -1

	if not is_managed_by_shape:
		setup_individual_cloud_phases()

func _process(delta):
	if is_managed_by_shape:
		apply_squish_animation(delta)
		return

	internal_time += delta
	update_individual_cloud_state()
	apply_squish_animation(delta)

func setup_individual_cloud_phases():
	calculate_lifespan()
	var movement = calculate_movement_positions()
	var boundaries = calculate_phase_boundaries()
	var phases = build_individual_phase_array(boundaries, movement)
	phase_data = {"phases": phases}

func calculate_lifespan():
	internal_time = 0.0

func calculate_movement_positions() -> Dictionary:
	var total_movement_time = moving_in_duration + moving_out_duration
	var movement_offset = speed * direction * total_movement_time / 2.0

	var start_position = Vector2(spawn_position.x - movement_offset, spawn_position.y)
	var end_position = Vector2(target_position.x + movement_offset, target_position.y)

	return {
		"start_position": start_position,
		"target_position": target_position,
		"end_position": end_position
	}

func calculate_phase_boundaries() -> Dictionary:
	var fade_in_end = fade_in_duration
	var moving_in_end = fade_in_end + moving_in_duration
	var moving_out_end = moving_in_end + moving_out_duration
	var fade_out_end = moving_out_end + fade_out_duration

	return {
		"fade_in_end": fade_in_end,
		"moving_in_end": moving_in_end,
		"moving_out_end": moving_out_end,
		"fade_out_end": fade_out_end
	}

func build_individual_phase_array(b: Dictionary, m: Dictionary) -> Array:
	var phases = []

	var fade_in_end_pos = calculate_position_between(
		m["start_position"], m["target_position"], 0.0, b["fade_in_end"]
	)

	phases.append(create_phase(
		CloudPhase.Phase.FADE_IN, 0.0, b["fade_in_end"],
		0.0, 1.0, m["start_position"], fade_in_end_pos
	))

	phases.append(create_phase(
		CloudPhase.Phase.MOVING_IN, b["fade_in_end"], b["moving_in_end"],
		1.0, 1.0, fade_in_end_pos, m["target_position"]
	))

	var moving_out_end_pos = calculate_position_between(
		m["target_position"], m["end_position"], b["moving_in_end"], b["moving_out_end"]
	)

	phases.append(create_phase(
		CloudPhase.Phase.MOVING_OUT, b["moving_in_end"], b["moving_out_end"],
		1.0, 1.0, m["target_position"], moving_out_end_pos
	))

	phases.append(create_phase(
		CloudPhase.Phase.FADE_OUT, b["moving_out_end"], b["fade_out_end"],
		1.0, 0.0, moving_out_end_pos, m["end_position"]
	))

	return phases

func calculate_position_between(start: Vector2, end: Vector2, t_start: float, t_end: float) -> Vector2:
	var duration = t_end - t_start
	var progress = 1.0 if duration == 0 else 1.0
	return lerp(start, end, progress)

func create_phase(type: CloudPhase.Phase, t_start: float, t_end: float,
				  alpha_start: float, alpha_end: float,
				  pos_start: Vector2, pos_end: Vector2) -> Dictionary:
	return {
		"type": type,
		"t_start": t_start,
		"t_end": t_end,
		"duration": t_end - t_start,
		"start_alpha": alpha_start,
		"end_alpha": alpha_end,
		"start_position": pos_start,
		"end_position": pos_end
	}

func update_individual_cloud_state():
	advance_phase_if_needed()
	apply_current_phase()

func advance_phase_if_needed():
	if is_in_vanished_phase():
		return

	var current_phase = get_current_phase()
	if internal_time >= current_phase["t_end"]:
		current_phase_index += 1
		if is_in_vanished_phase():
			publish_vanished_event()
			queue_free()

func publish_vanished_event():
	if not is_managed_by_shape:
		MessageBus.publish("cloud_vanished", {"cloud": self})

func is_in_vanished_phase() -> bool:
	return current_phase_index >= phase_data["phases"].size()

func get_current_phase() -> Dictionary:
	return phase_data["phases"][current_phase_index]

func apply_current_phase():
	if is_in_vanished_phase():
		return

	var phase = get_current_phase()
	var progress = calculate_progress(phase)

	modulate.a = lerp(phase["start_alpha"], phase["end_alpha"], progress)

	if is_managed_by_shape:
		apply_position_with_drift()
	else:
		apply_position_over_lifetime()

func apply_position_over_lifetime():
	var total_duration = phase_data["phases"][-1]["t_end"]
	var lifetime_progress = internal_time / total_duration
	var start_pos = phase_data["phases"][0]["start_position"]
	var end_pos = phase_data["phases"][-1]["end_position"]
	position = lerp(start_pos, end_pos, clamp(lifetime_progress, 0.0, 1.0))

func apply_position_with_drift():
	var parent_shape = get_parent() as CloudShape
	if parent_shape == null:
		apply_position_over_lifetime()
		return

	var total_duration = phase_data["phases"][-1]["t_end"]
	var lifetime_progress = internal_time / total_duration
	var start_pos = phase_data["phases"][0]["start_position"]
	var end_pos = phase_data["phases"][-1]["end_position"]
	var base_position = lerp(start_pos, end_pos, clamp(lifetime_progress, 0.0, 1.0))
	var drift = parent_shape.get_drift_offset()
	position = base_position + drift

func calculate_progress(phase: Dictionary) -> float:
	var elapsed = internal_time - phase["t_start"]
	var progress = elapsed / phase["duration"]
	return clamp(progress, 0.0, 1.0)

func apply_squish_animation(delta: float) -> void:
	squish_timer += delta
	var squish_progress = squish_timer / squish_duration
	var squish_wave = sin(squish_progress * TAU)

	var scale_x = initial_scale.x + (initial_scale.x * squish_amount * squish_wave)
	var scale_y = initial_scale.y - (initial_scale.y * squish_amount * squish_wave)
	scale = Vector2(scale_x, scale_y)

	if override_rotation:
		rotation = target_rotation
	else:
		rotation = rotation_amount * squish_wave

	if squish_timer >= squish_duration:
		squish_timer = 0.0

func set_direction(new_direction: int) -> void:
	direction = new_direction
