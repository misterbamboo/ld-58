class_name Cloud extends Node2D

@export var min_speed: float = 3.0
@export var max_speed: float = 10.0

var speed: float
var direction: int = 0
var meet_at_pos: Vector2
var meet_in_time: float = 0.0
var is_managed_by_shape: bool = false

var internal_time: float = 0.0
var lifespan: float = 0.0

var initial_offset_pos: Vector2 = Vector2.ZERO
var initial_offset_rotation: float = 0.0

var override_rotation: bool = false
var target_rotation: float = 0.0

var ready_flag: bool = false

func _ready():
	if direction == 0:
		direction = 1 if randf() > 0.5 else -1

	ready_flag = true

func _process(delta):
	if not is_managed_by_shape:
		internal_time = clamp(internal_time + delta, 0.0, lifespan)

	update_position()
	check_if_vanished()

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
	# if is_managed_by_shape:
	# 	var parent_shape = get_parent() as CloudShape
	# 	if parent_shape:
	# 		rotation = initial_offset_rotation
	# 	else:
	# 		position = local_position
	# else:
	# 	position = local_position

func get_current_time() -> float:
	if is_managed_by_shape:
		var parent_shape = get_parent() as CloudShape
		if parent_shape:
			return parent_shape.get_internal_time()
	return internal_time

func check_if_vanished():
	var current_time = get_current_time()
	if current_time >= lifespan:
		if not is_managed_by_shape:
			MessageBus.publish("cloud_vanished", {"cloud": self})
			queue_free()
		else:
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

func set_managed_by_shape(managed: bool) -> void:
	is_managed_by_shape = managed

func initialize(meeting_pos: Vector2, spawn_direction: int, spawn_lifespan: float, spawn_meet_in_time: float) -> void:
	speed = randf_range(min_speed, max_speed)
	direction = 1 if randf() > 0.5 else -1
	lifespan = spawn_lifespan
	meet_in_time = spawn_meet_in_time
	internal_time = 0.0

	if is_managed_by_shape:
		initial_offset_pos = position
		initial_offset_rotation = rotation
		meet_at_pos = meeting_pos
	else:
		meet_at_pos = meeting_pos
