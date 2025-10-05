extends Node2D
class_name CloudShape

@export var cloud_image: Texture2D

@export var min_lifespan: float = 30.0
@export var max_lifespan: float = 90.0
@export var drift_speed: float = 8.0

var clouds: Array[Cloud] = []
var internal_time: float = 0.0
var lifespan: float = 0.0
var direction: int = 1
var meet_at_pos: Vector2
var has_vanished: bool = false

var ready_flag: bool = false
var clouds_initialized: bool = false
var is_fading_out: bool = false

var highlight_window_before_meet: float = 2.5
var highlight_window_after_meet: float = 2.5

var capture_texture: Texture2D = null
var capture_position: Vector2 = Vector2.ZERO

func _ready():
	load_cloud_children()
	mark_clouds_as_managed()

func load_cloud_children():
	for child in get_children():
		if child is Cloud:
			clouds.append(child)

func mark_clouds_as_managed():
	for cloud in clouds:
		cloud.set_managed_by_shape(true)

func set_direction(new_direction: int):
	direction = new_direction
	for cloud in clouds:
		cloud.set_direction(new_direction)

func initialize(meeting_pos: Vector2, spawn_direction: int, spawn_lifespan: float, meet_in_time: float) -> void:
	direction = spawn_direction
	lifespan = spawn_lifespan
	meet_at_pos = meeting_pos
	internal_time = 0.0

func initialize_child_clouds(meeting_pos: Vector2, spawn_direction: int, meet_in_time: float):
	for cloud in clouds:
		var child_lifespan = randf_range(min_lifespan * 1.25, lifespan * 1.25)
		var spawn_delay = randf_range(0, child_lifespan/3)
		cloud.initialize(Vector2.ZERO, -1, child_lifespan, meet_in_time, spawn_delay)

func _process(delta):
	if not clouds_initialized:
		check_and_initialize_children()
		return

	internal_time = clamp(internal_time + delta, 0.0, lifespan)
	update_position()
	check_if_lifetime_ended()

func check_and_initialize_children():
	for cloud in clouds:
		if not cloud.is_ready():
			return

	# All children are ready, initialize them
	var meet_in_time = lifespan / 2.0
	initialize_child_clouds(meet_at_pos, direction, meet_in_time)
	clouds_initialized = true

func update_position():
	var t = internal_time / lifespan
	var half_distance = drift_speed * lifespan / 2.0 * direction
	var start = meet_at_pos - Vector2(half_distance, 0)
	var end = meet_at_pos + Vector2(half_distance, 0)
	position = lerp(start, end, t)

func check_if_lifetime_ended():
	if has_vanished:
		return

	if should_start_fadeout():
		start_fadeout()
		return

	if is_fading_out and all_clouds_faded():
		destroy_shape()

func should_start_fadeout() -> bool:
	return internal_time >= lifespan and not is_fading_out

func start_fadeout():
	is_fading_out = true
	for cloud in clouds:
		cloud.trigger_fadeout()

func all_clouds_faded() -> bool:
	for cloud in clouds:
		if not cloud.is_faded_out():
			return false
	return true

func destroy_shape():
	has_vanished = true
	MessageBus.publish(CloudEvents.SHAPE_VANISHED, {"shape": self})
	queue_free()

func get_internal_time() -> float:
	return internal_time

func get_lifespan() -> float:
	return lifespan

func is_ready() -> bool:
	if ready_flag:
		return true

	for cloud in clouds:
		if not cloud.is_ready():
			return false

	ready_flag = true
	return true

func capture_memory() -> void:
	capture_texture = cloud_image
	capture_position = global_position
	print("[CloudShape] capture_memory() called - texture: ", capture_texture, " position: ", capture_position)

	# Publish event immediately - sprite will appear and animate while clouds fade
	MessageBus.publish(CloudEvents.SHAPE_FULLY_FADED, {
		"shape": self,
		"texture": capture_texture,
		"position": capture_position
	})

	start_fadeout()

	# Notify spawner immediately so replacement shapes spawn right away
	MessageBus.publish(CloudEvents.SHAPE_VANISHED, {"shape": self})

func get_cloud_image() -> Texture2D:
	return cloud_image
