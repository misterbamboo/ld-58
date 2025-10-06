class_name Cloud extends Node2D

@export var min_speed: float = 3.0
@export var max_speed: float = 10.0

var speed: float
var direction: int = 0
var meet_at_pos: Vector2
var meet_in_time: float = 0.0
var spawn_delay: float = 0.0
var is_managed_by_shape: bool = false

var internal_time: float = 0.0
var lifespan: float = 0.0

var force_fadeout: bool = false
var fadeout_start_time: float = 0.0

var force_fade_in: bool = false
var fade_in_start_time: float = 0.0

var initial_offset_pos: Vector2 = Vector2.ZERO
var initial_offset_rotation: float = 0.0

var override_rotation: bool = false
var target_rotation: float = 0.0

var ready_flag: bool = false
var cloud_size: float = 0.0

func _ready():
	if direction == 0:
		direction = 1 if randf() > 0.5 else -1

	cloud_size = calculate_cloud_size()
	apply_depth_effects()
	ready_flag = true

func calculate_cloud_size() -> float:
	var sprite_node = find_child("CloudSprite")
	if sprite_node and sprite_node is Sprite2D:
		var texture = sprite_node.texture
		if texture:
			var width = texture.get_width()
			var height = texture.get_height()
			return (width + height) / 2.0
	return 0.0

func apply_depth_effects():
	if cloud_size == 0.0:
		return

	# Size threshold: clouds with average dimension > 600 are large (background)
	var size_threshold = 600.0

	if cloud_size > size_threshold:
		# Large clouds: background layer
		z_index = -3
	else:
		# Small clouds: foreground layer
		z_index = -2

func _process(delta):
	internal_time = internal_time + delta

	check_fade_in_start()
	update_position()
	check_if_vanished()

func check_fade_in_start():
	if not force_fade_in and ready_to_show():
		force_fade_in = true
		fade_in_start_time = get_current_time()

func update_position():
	var current_time = get_current_time()
	var t = current_time / lifespan

	var distance_before_meet = speed * direction * meet_in_time
	var distance_after_meet = speed * direction * (lifespan - meet_in_time)

	var meet = Vector2.ZERO if is_managed_by_shape else meet_at_pos

	var start = meet - Vector2(distance_before_meet, 0)
	var end = meet + Vector2(distance_after_meet, 0)
	var local_position = lerp(start, end, t)

	position = local_position + initial_offset_pos

func get_current_time() -> float:
	if is_managed_by_shape:
		var parent_shape = get_parent() as CloudShape
		if parent_shape:
			return parent_shape.get_internal_time()
	return internal_time
	
func ready_to_show() -> bool:
	return internal_time > 0

func check_if_vanished():
	var current_time = get_current_time()
	if not is_managed_by_shape:
		# Individual clouds: wait for fadeout to complete before destroying
		if current_time >= lifespan and is_faded_out():
			MessageBus.publish(CloudEvents.CLOUD_VANISHED, {"cloud": self})
			queue_free()
	else:
		# Managed clouds: just hide when time is up
		if current_time >= lifespan:
			visible = false

func set_direction(new_direction: int) -> void:
	direction = new_direction

func get_lifespan() -> float:
	return lifespan

func should_override_rotation() -> bool:
	return override_rotation

func get_target_rotation() -> float:
	return target_rotation

func get_meet_at_pos() -> Vector2:
	return meet_at_pos

func is_ready() -> bool:
	return ready_flag

func trigger_fadeout() -> void:
	force_fadeout = true
	fadeout_start_time = get_current_time()

func is_force_fadeout() -> bool:
	return force_fadeout

func get_fadeout_time() -> float:
	return get_current_time() - fadeout_start_time

func is_force_fade_in() -> bool:
	return force_fade_in

func get_fade_in_time() -> float:
	return get_current_time() - fade_in_start_time

func get_alpha() -> float:
	var alpha_node = find_child("CloudAlpha")
	if alpha_node and alpha_node is Sprite2D:
		return alpha_node.modulate.a
	return 1.0

func is_faded_out() -> bool:
	return get_alpha() <= 0.01

func set_managed_by_shape(managed: bool) -> void:
	is_managed_by_shape = managed

func initialize(meeting_pos: Vector2, spawn_direction: int, spawn_lifespan: float, spawn_meet_in_time: float, delay: float = 0.0, speed_multiplier: float = 1.0) -> void:
	speed = randf_range(min_speed, max_speed) * speed_multiplier
	direction = spawn_direction
	lifespan = spawn_lifespan
	meet_in_time = spawn_meet_in_time
	spawn_delay = delay
	internal_time = -spawn_delay

	if is_managed_by_shape:
		initial_offset_pos = position
		initial_offset_rotation = rotation
		meet_at_pos = meeting_pos
	else:
		meet_at_pos = meeting_pos
