extends Node2D
class_name CloudShape

@export var min_lifespan: float = 30.0
@export var max_lifespan: float = 90.0
@export var fade_in_duration: float = 8.0
@export var fade_out_duration: float = 8.0
@export var drift_speed: float = 0.5

var clouds: Array[Cloud] = []
var drift_offset: Vector2 = Vector2.ZERO
var cloud_phase_data: Dictionary = {}
var vanished_cloud_count: int = 0
var has_vanished: bool = false
var internal_time: float = 0.0
var lifespan: float = 0.0

var highlightable_start: float = -2.5
var highlightable_end: float = 2.5

func _ready():
	lifespan = randf_range(min_lifespan, max_lifespan)
	internal_time = -lifespan / 2.0
	load_cloud_children()
	set_cloud_target_positions()
	setup_cloud_phases()
	mark_clouds_as_managed()

func load_cloud_children():
	for child in get_children():
		if child is Cloud:
			clouds.append(child)

func set_cloud_target_positions():
	for cloud in clouds:
		cloud.target_position = cloud.initial_position
		cloud.spawn_position = cloud.position

func setup_cloud_phases():
	for cloud in clouds:
		var phases = create_phase_timeline_for_cloud(cloud)
		var phase_data = create_cloud_phase_data(phases)
		cloud_phase_data[cloud] = phase_data
		initialize_cloud_appearance(cloud)

func create_phase_timeline_for_cloud(cloud: Cloud) -> Array:
	var movement = calculate_cloud_movement_positions(cloud)
	var offsets = calculate_random_offsets()
	var boundaries = calculate_time_boundaries(offsets)
	return build_phase_array(cloud, boundaries, movement)

func calculate_cloud_movement_positions(cloud: Cloud) -> Dictionary:
	var zero_position = cloud.initial_position
	var half_lifespan = lifespan / 2.0
	var movement_offset = cloud.speed * cloud.direction * half_lifespan

	var start_position = Vector2(zero_position.x - movement_offset, zero_position.y)
	var end_position = Vector2(zero_position.x + movement_offset, zero_position.y)

	return {
		"start_position": start_position,
		"zero_position": zero_position,
		"end_position": end_position
	}

func calculate_random_offsets() -> Dictionary:
	return {
		"fade_in": randf_range(0.0, fade_in_duration * 0.5),
		"fade_out": randf_range(0.0, fade_out_duration * 0.5)
	}

func calculate_time_boundaries(offsets: Dictionary) -> Dictionary:
	var fade_in_start = internal_time + offsets["fade_in"]
	var fade_in_end = fade_in_start + fade_in_duration
	var moving_in_end = highlightable_end
	var moving_out_end = (lifespan / 2.0) - fade_out_duration + offsets["fade_out"]
	var fade_out_end = moving_out_end + fade_out_duration

	return {
		"fade_in_start": fade_in_start,
		"fade_in_end": fade_in_end,
		"moving_in_end": moving_in_end,
		"moving_out_end": moving_out_end,
		"fade_out_end": fade_out_end
	}

func build_phase_array(cloud: Cloud, boundaries: Dictionary, movement: Dictionary) -> Array:
	var phases = []
	var fade_in_end_pos = calculate_position_at_time(
		movement["start_position"], movement["zero_position"],
		boundaries["fade_in_start"], boundaries["fade_in_end"]
	)

	phases.append(create_fade_in_phase(boundaries, movement, fade_in_end_pos))

	var moving_in_end_pos = calculate_position_at_time(
		movement["start_position"], movement["zero_position"],
		boundaries["fade_in_end"], boundaries["moving_in_end"]
	)

	phases.append(create_moving_in_phase(boundaries, movement, fade_in_end_pos, moving_in_end_pos))

	var moving_out_end_pos = calculate_position_at_time(
		movement["zero_position"], movement["end_position"],
		boundaries["moving_in_end"], boundaries["moving_out_end"]
	)

	phases.append(create_moving_out_phase(boundaries, movement, moving_in_end_pos, moving_out_end_pos))
	phases.append(create_fade_out_phase(boundaries, movement, moving_out_end_pos))
	return phases

func calculate_position_at_time(start_pos: Vector2, end_pos: Vector2,
								time_start: float, time_end: float) -> Vector2:
	var total_duration = time_end - time_start
	var progress = 1.0 if total_duration == 0 else 1.0
	return lerp(start_pos, end_pos, progress)

func create_fade_in_phase(b: Dictionary, m: Dictionary, fade_in_end_pos: Vector2) -> Dictionary:
	return create_phase(
		CloudPhase.Phase.FADE_IN,
		b["fade_in_start"], b["fade_in_end"],
		0.0, 1.0,
		m["start_position"], fade_in_end_pos
	)

func create_moving_in_phase(b: Dictionary, m: Dictionary, fade_in_end_pos: Vector2, moving_in_end_pos: Vector2) -> Dictionary:
	return create_phase(
		CloudPhase.Phase.MOVING_IN,
		b["fade_in_end"], b["moving_in_end"],
		1.0, 1.0,
		fade_in_end_pos, moving_in_end_pos
	)

func create_moving_out_phase(b: Dictionary, m: Dictionary, moving_in_end_pos: Vector2, moving_out_end_pos: Vector2) -> Dictionary:
	return create_phase(
		CloudPhase.Phase.MOVING_OUT,
		b["moving_in_end"], b["moving_out_end"],
		1.0, 1.0,
		moving_in_end_pos, moving_out_end_pos
	)

func create_fade_out_phase(b: Dictionary, m: Dictionary, moving_out_end_pos: Vector2) -> Dictionary:
	return create_phase(
		CloudPhase.Phase.FADE_OUT,
		b["moving_out_end"], b["fade_out_end"],
		1.0, 0.0,
		moving_out_end_pos, m["end_position"]
	)

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

func create_cloud_phase_data(phases: Array) -> Dictionary:
	return {
		"phases": phases,
		"current_phase_index": 0
	}

func initialize_cloud_appearance(cloud: Cloud):
	cloud.modulate.a = 0.0

func mark_clouds_as_managed():
	for cloud in clouds:
		cloud.is_managed_by_shape = true

func set_first_shape_time():
	internal_time = -lifespan / 4.0

func _process(delta):
	internal_time += delta
	update_drift_offset(delta)
	update_cloud_states()
	dispose_shape_if_all_clouds_vanished()

func update_drift_offset(delta: float):
	if clouds.is_empty():
		return
	var direction = clouds[0].direction
	drift_offset += Vector2(drift_speed * direction, 0.0) * delta

func get_drift_offset() -> Vector2:
	return drift_offset

func update_cloud_states():
	for cloud in clouds:
		var data = cloud_phase_data[cloud]
		advance_phase_if_needed(cloud, data)
		apply_current_phase_state(cloud, data)

func advance_phase_if_needed(cloud: Cloud, data: Dictionary):
	if is_in_vanished_phase(data):
		return

	var current_phase = get_current_phase(data)

	if should_advance_to_next_phase(current_phase):
		increment_phase_index(data)
		handle_vanished_phase_if_needed(cloud, data)

func should_advance_to_next_phase(phase: Dictionary) -> bool:
	return internal_time >= phase["t_end"]

func get_current_phase(data: Dictionary) -> Dictionary:
	return data["phases"][data["current_phase_index"]]

func increment_phase_index(data: Dictionary):
	data["current_phase_index"] += 1

func handle_vanished_phase_if_needed(cloud: Cloud, data: Dictionary):
	if is_in_vanished_phase(data):
		mark_cloud_as_vanished(cloud)

func is_in_vanished_phase(data: Dictionary) -> bool:
	return data["current_phase_index"] >= data["phases"].size()

func mark_cloud_as_vanished(cloud: Cloud):
	if cloud.visible:
		cloud.visible = false
		vanished_cloud_count += 1

func apply_current_phase_state(cloud: Cloud, data: Dictionary):
	if is_in_vanished_phase(data):
		return

	var phase = get_current_phase(data)
	var progress = calculate_phase_progress(phase)

	apply_alpha_lerp(cloud, phase, progress)
	apply_position_lerp(cloud, phase, progress)
	apply_rotation_override_if_needed(cloud, phase)

func calculate_phase_progress(phase: Dictionary) -> float:
	var elapsed = internal_time - phase["t_start"]
	var progress = elapsed / phase["duration"]
	return clamp(progress, 0.0, 1.0)

func apply_alpha_lerp(cloud: Cloud, phase: Dictionary, progress: float):
	cloud.modulate.a = lerp(phase["start_alpha"], phase["end_alpha"], progress)

func apply_position_lerp(cloud: Cloud, phase: Dictionary, progress: float):
	cloud.position = lerp(phase["start_position"], phase["end_position"], progress)
	if is_near_time_zero():
		cloud.position = cloud.initial_position

func is_near_time_zero() -> bool:
	return abs(internal_time) < 0.1

func apply_rotation_override_if_needed(cloud: Cloud, phase: Dictionary):
	if is_near_time_zero():
		enable_rotation_override(cloud)
	else:
		disable_rotation_override(cloud)

func enable_rotation_override(cloud: Cloud):
	cloud.override_rotation = true
	cloud.target_rotation = 0.0

func disable_rotation_override(cloud: Cloud):
	cloud.override_rotation = false

func dispose_shape_if_all_clouds_vanished():
	if not has_vanished and vanished_cloud_count >= clouds.size():
		has_vanished = true
		MessageBus.publish("shape_vanished", {"shape": self})
		queue_free()
