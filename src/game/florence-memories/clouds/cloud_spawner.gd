extends Node2D
class_name CloudSpawner

@export_group("Individual Clouds")
@export var cloud_scenes: Array[PackedScene] = []
@export var min_cloud_interval: float = 2.0
@export var max_cloud_interval: float = 6.0
@export var initial_cloud_count: int = 5

@export_group("Cloud Shapes")
@export var shape_scenes: Array[PackedScene] = []

@export_group("Spawn Limits")
@export var max_clouds: int = 10

@export_group("Spawn Settings")
@export var spawn_y_min: float = -100.0
@export var spawn_y_max: float = 100.0
@export var offscreen_margin: float = 100.0

var cloud_spawn_timer: float = 0.0
var next_cloud_spawn_time: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var is_first_shape: bool = true

func _ready():
	screen_size = get_viewport_rect().size
	next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)
	MessageBus.subscribe("shape_vanished", _on_entity_vanished)
	MessageBus.subscribe("cloud_vanished", _on_entity_vanished)
	spawn_initial_entities()

func _process(delta):
	update_cloud_spawn_timer(delta)

func update_cloud_spawn_timer(delta: float):
	cloud_spawn_timer += delta
	if cloud_spawn_timer >= next_cloud_spawn_time:
		if count_total_entities() < max_clouds:
			spawn_next_entity()
		cloud_spawn_timer = 0.0
		next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)

func count_total_entities() -> int:
	var count = 0
	for child in get_children():
		if child is CloudShape:
			count += 1
		elif child is Cloud and not child.is_managed_by_shape:
			count += 1
	return count

func has_shape_on_screen() -> bool:
	for child in get_children():
		if child is CloudShape:
			return true
	return false

func spawn_next_entity():
	if not has_shape_on_screen() and not shape_scenes.is_empty():
		spawn_shape()
	else:
		spawn_cloud()

func spawn_cloud():
	if cloud_scenes.is_empty():
		return

	var cloud_instance = create_cloud_instance()
	configure_cloud_phases(cloud_instance)
	configure_cloud_spawn(cloud_instance)
	add_child(cloud_instance)

func configure_cloud_phases(cloud_instance: Cloud):
	var target_lifespan = randf_range(30.0, 90.0)
	cloud_instance.fade_in_duration = randf_range(3.0, 8.0)
	cloud_instance.fade_out_duration = randf_range(3.0, 8.0)
	cloud_instance.lifespan = target_lifespan

func configure_cloud_spawn(cloud_instance: Cloud):
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)

	cloud_instance.position = Vector2(spawn_x, spawn_y)
	cloud_instance.spawn_position = cloud_instance.position
	cloud_instance.target_position = cloud_instance.position

	var direction = 1 if spawn_x < screen_size.x / 2.0 else -1
	cloud_instance.set_direction(direction)

	var remaining_time = cloud_instance.lifespan - cloud_instance.fade_in_duration - cloud_instance.fade_out_duration
	cloud_instance.moving_in_duration = 0.0
	cloud_instance.moving_out_duration = remaining_time

func create_cloud_instance() -> Cloud:
	var cloud_scene = cloud_scenes[randi() % cloud_scenes.size()]
	return cloud_scene.instantiate()

func spawn_initial_entities():
	for i in range(initial_cloud_count):
		if count_total_entities() < max_clouds:
			spawn_next_entity()

func spawn_shape():
	if shape_scenes.is_empty():
		return

	var shape_instance = create_shape_instance()
	configure_shape_spawn(shape_instance)

	if is_first_shape:
		shape_instance.call_deferred("set_first_shape_time")
		is_first_shape = false

	add_child(shape_instance)
	MessageBus.publish("shape_spawned", {"shape": shape_instance})

func configure_shape_spawn(shape: CloudShape):
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)

	shape.position = Vector2(spawn_x, spawn_y)

	var direction = 1 if spawn_x < screen_size.x / 2.0 else -1
	for cloud in shape.clouds:
		cloud.set_direction(direction)

func create_shape_instance() -> CloudShape:
	var shape_scene = shape_scenes[randi() % shape_scenes.size()]
	return shape_scene.instantiate()

func _on_entity_vanished(data: Dictionary):
	if count_total_entities() < max_clouds:
		spawn_next_entity()
