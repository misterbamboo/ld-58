extends Node2D
class_name CloudSpawner

@export var cloud_scenes: Array[PackedScene] = []
@export var min_spawn_interval: float = 2.0
@export var max_spawn_interval: float = 6.0
@export var spawn_y_min: float = -100.0
@export var spawn_y_max: float = 100.0
@export var initial_cloud_count: int = 5
@export var max_clouds: int = 10
@export var offscreen_margin: float = 100.0

var spawn_timer: float = 0.0
var next_spawn_time: float = 0.0
var screen_size: Vector2 = Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)

	# Spawn initial clouds at random positions
	for i in range(initial_cloud_count):
		spawn_cloud_at_random_position()

func _process(delta):
	spawn_timer += delta

	if spawn_timer >= next_spawn_time:
		if get_child_count() < max_clouds:
			spawn_cloud()
		spawn_timer = 0.0
		next_spawn_time = randf_range(min_spawn_interval, max_spawn_interval)

	# Remove clouds that have moved far off screen
	cleanup_offscreen_clouds()

func spawn_cloud():
	if cloud_scenes.is_empty():
		return

	var cloud_instance = create_cloud_instance()

	# Spawn from either left or right side
	var spawn_from_left = randf() > 0.5
	var spawn_x = get_spawn_x_position(spawn_from_left)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)

	cloud_instance.position = Vector2(spawn_x, spawn_y)
	set_cloud_direction_towards_screen(cloud_instance, spawn_from_left)
	add_child(cloud_instance)

func create_cloud_instance() -> Cloud:
	var cloud_scene = cloud_scenes[randi() % cloud_scenes.size()]
	return cloud_scene.instantiate()

func get_spawn_x_position(spawn_from_left: bool) -> float:
	return -offscreen_margin if spawn_from_left else screen_size.x + offscreen_margin

func set_cloud_direction_towards_screen(cloud: Cloud, spawned_from_left: bool) -> void:
	cloud.set_direction(1 if spawned_from_left else -1)

func spawn_cloud_at_random_position():
	if cloud_scenes.is_empty():
		return

	var cloud_instance = create_cloud_instance()

	# Random position across the entire screen
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)

	cloud_instance.position = Vector2(spawn_x, spawn_y)
	# Direction stays random for initial clouds
	add_child(cloud_instance)

func cleanup_offscreen_clouds():
	for child in get_children():
		if child is Cloud:
			# Remove if beyond the offscreen margin on either side
			if child.position.x < -offscreen_margin or child.position.x > screen_size.x + offscreen_margin:
				child.queue_free()
