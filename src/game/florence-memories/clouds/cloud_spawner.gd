extends Node2D
class_name CloudSpawner

@export var cloud_scenes: Array[PackedScene] = []
@export var shape_scenes: Array[PackedScene] = []
@export var min_cloud_interval: float = 2.0
@export var max_cloud_interval: float = 6.0
@export var spawn_y_min: float = -100.0
@export var spawn_y_max: float = 100.0

var cloud_spawn_timer: float = 0.0
var next_cloud_spawn_time: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var spawn_shape_next: bool = false
var is_first_shape: bool = true

var pending_clouds: Array[Cloud] = []
var pending_shapes: Array[CloudShape] = []

func _ready():
	screen_size = get_viewport_rect().size
	next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)
	MessageBus.subscribe("shape_vanished", _on_shape_vanished)
	spawn_initial_entities()

func spawn_initial_entities():
	spawn_shape()
	for i in range(9):
		spawn_cloud()

func _process(delta):
	update_spawn_timer(delta)
	process_pending_initialization()

func update_spawn_timer(delta: float):
	cloud_spawn_timer += delta
	if cloud_spawn_timer >= next_cloud_spawn_time:
		spawn_next_entity()
		cloud_spawn_timer = 0.0
		next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)

func spawn_next_entity():
	if spawn_shape_next:
		spawn_shape()
		spawn_shape_next = false
	else:
		spawn_cloud()

func spawn_shape():
	if shape_scenes.is_empty():
		return

	var shape_instance = create_shape_instance()
	add_child(shape_instance)
	pending_shapes.append(shape_instance)

	MessageBus.publish("shape_spawned", {"shape": shape_instance})

func spawn_cloud():
	if cloud_scenes.is_empty():
		return

	var cloud_instance = create_cloud_instance()
	add_child(cloud_instance)
	pending_clouds.append(cloud_instance)

func create_cloud_instance() -> Cloud:
	var cloud_scene = cloud_scenes[randi() % cloud_scenes.size()]
	return cloud_scene.instantiate()

func create_shape_instance() -> CloudShape:
	var shape_scene = shape_scenes[randi() % shape_scenes.size()]
	return shape_scene.instantiate()

func process_pending_initialization():
	# Process pending clouds
	var i = 0
	while i < pending_clouds.size():
		var cloud = pending_clouds[i]
		if cloud.is_ready():
			initialize_cloud(cloud)
			pending_clouds.remove_at(i)
		else:
			i += 1

	# Process pending shapes
	i = 0
	while i < pending_shapes.size():
		var shape = pending_shapes[i]
		if shape.is_ready():
			initialize_shape(shape)
			pending_shapes.remove_at(i)
		else:
			i += 1

func initialize_cloud(cloud: Cloud):
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)
	var meet_at_pos = Vector2(spawn_x, spawn_y)

	var direction = 1 if spawn_x < screen_size.x / 2.0 else -1
	var lifespan = randf_range(30.0, 90.0)

	cloud.initialize(meet_at_pos, direction, lifespan, 0.0)

func initialize_shape(shape: CloudShape):
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)
	var meet_at_pos = Vector2(spawn_x, spawn_y)

	var direction = 1 if spawn_x < screen_size.x / 2.0 else -1
	var lifespan = randf_range(30.0, 90.0)
	var meet_in_time = lifespan / 2.0

	shape.initialize(meet_at_pos, direction, lifespan, meet_in_time)

	if is_first_shape:
		shape.set_first_shape_time()
		is_first_shape = false

func _on_shape_vanished(data: Dictionary):
	spawn_shape_next = true
