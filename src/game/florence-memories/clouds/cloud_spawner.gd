extends Node2D
class_name CloudSpawner

@export var cloud_scenes: Array[PackedScene] = []
@export var shape_scenes: Array[PackedScene] = []
@export var min_cloud_interval: float = 4.0
@export var max_cloud_interval: float = 10.0
@export var spawn_y_min: float = -100.0
@export var spawn_y_max: float = 100.0
@export var min_lifespan: float = 30.0
@export var max_lifespan: float = 90.0

var cloud_spawn_timer: float = 0.0
var next_cloud_spawn_time: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var spawn_shape_next: bool = false
var shapes_to_spawn: int = 0

var pending_clouds: Array[Cloud] = []
var pending_shapes: Array[CloudShape] = []

func _ready():
	screen_size = get_viewport_rect().size
	next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)
	MessageBus.subscribe(CloudEvents.SHAPE_VANISHED, _on_shape_vanished)
	spawn_initial_entities()

func spawn_initial_entities():
	# Spawn 2-3 shapes initially for spread
	for i in range(randi_range(1, 3)):
		spawn_shape()

	for i in range(randi_range(8, 12)):
		spawn_cloud()

func _process(delta):
	update_spawn_timer(delta)
	process_pending_initialization()

func update_spawn_timer(delta: float):
	# Safety check: ensure at least one shape is always present
	if get_active_shapes_count() == 0:
		for i in range(randi_range(1, 2)):
			spawn_shape()

	cloud_spawn_timer += delta
	if cloud_spawn_timer >= next_cloud_spawn_time:
		spawn_next_entity()
		cloud_spawn_timer = 0.0
		next_cloud_spawn_time = randf_range(min_cloud_interval, max_cloud_interval)

func spawn_next_entity():
	if spawn_shape_next:
		# Spawn 2-3 shapes for spread
		for i in range(shapes_to_spawn):
			spawn_shape()
		spawn_shape_next = false
		shapes_to_spawn = 0
	else:
		# Sometimes spawn 2-3 clouds at once for ambiguity
		var burst_count = 1
		var rand = randf()
		if rand < 0.1:  # 10% chance for burst
			burst_count = 2

		for i in range(burst_count):
			spawn_cloud()

func spawn_shape():
	if shape_scenes.is_empty():
		return

	var shape_instance = create_shape_instance()
	add_child(shape_instance)
	pending_shapes.append(shape_instance)

	MessageBus.publish(CloudEvents.SHAPE_SPAWNED, {"shape": shape_instance})

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
	var lifespan = randf_range(min_lifespan, max_lifespan)

	cloud.initialize(meet_at_pos, direction, lifespan, 0.0)

func initialize_shape(shape: CloudShape):
	var spawn_x = randf_range(0.0, screen_size.x)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)
	var meet_at_pos = Vector2(spawn_x, spawn_y)

	var direction = 1 if spawn_x < screen_size.x / 2.0 else -1
	var lifespan = randf_range(min_lifespan, max_lifespan)
	var meet_in_time = lifespan / 2.0

	shape.initialize(meet_at_pos, direction, lifespan, meet_in_time)

func get_active_shapes_count() -> int:
	var count = 0
	for child in get_children():
		if child is CloudShape:
			count += 1
	return count

func _on_shape_vanished(data: Dictionary):
	spawn_shape_next = true
	shapes_to_spawn = randi_range(2, 3)
