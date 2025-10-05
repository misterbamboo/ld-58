extends Node2D
class_name CloudSpawner

class OccupiedRegion:
	var position: Vector2
	var radius: float
	var shape: CloudShape

@export var cloud_scenes: Array[PackedScene] = []
@export var shape_scenes: Array[PackedScene] = []
@export var min_cloud_interval: float = 4.0
@export var max_cloud_interval: float = 10.0
@export var spawn_y_min: float = -100.0
@export var spawn_y_max: float = 100.0
@export var min_lifespan: float = 30.0
@export var max_lifespan: float = 90.0

const PADDING_PERCENT: float = 0.2

var cloud_spawn_timer: float = 0.0
var next_cloud_spawn_time: float = 0.0
var screen_size: Vector2 = Vector2.ZERO
var spawn_shape_next: bool = false
var shapes_to_spawn: int = 0

var pending_clouds: Array[Cloud] = []
var pending_shapes: Array[CloudShape] = []
var occupied_regions: Array[OccupiedRegion] = []
var last_viewport_size: Vector2 = Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	last_viewport_size = screen_size
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
	check_viewport_resize()
	update_spawn_timer(delta)
	process_pending_initialization()

func check_viewport_resize():
	var current_size = get_viewport().get_visible_rect().size
	if current_size != last_viewport_size:
		last_viewport_size = current_size
		screen_size = current_size

func get_spawn_bounds() -> Dictionary:
	var padding_x = screen_size.x * PADDING_PERCENT
	var padding_y = screen_size.y * PADDING_PERCENT

	return {
		"min_x": padding_x,
		"max_x": screen_size.x - padding_x,
		"min_y": padding_y,
		"max_y": screen_size.y - padding_y
	}

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
	var bounds = get_spawn_bounds()
	var spawn_x = randf_range(bounds.min_x, bounds.max_x)
	var spawn_y = randf_range(bounds.min_y, bounds.max_y)
	var meet_at_pos = Vector2(spawn_x, spawn_y)

	var direction = -1
	var lifespan = randf_range(min_lifespan, max_lifespan)

	cloud.initialize(meet_at_pos, direction, lifespan, 0.0)

func initialize_shape(shape: CloudShape):
	var meet_at_pos = find_non_overlapping_position()
	var direction = -1
	var lifespan = randf_range(min_lifespan, max_lifespan)
	var meet_in_time = lifespan / 2.0

	shape.initialize(meet_at_pos, direction, lifespan, meet_in_time)

	var region = OccupiedRegion.new()
	region.position = meet_at_pos
	region.radius = 150.0
	region.shape = shape
	occupied_regions.append(region)

func get_active_shapes_count() -> int:
	var count = 0
	for child in get_children():
		if child is CloudShape:
			count += 1
	return count

func _on_shape_vanished(data: Dictionary):
	spawn_shape_next = true
	shapes_to_spawn = randi_range(2, 3)
	release_occupied_region(data.shape)

func release_occupied_region(shape: CloudShape):
	for i in range(occupied_regions.size() - 1, -1, -1):
		if occupied_regions[i].shape == shape:
			occupied_regions.remove_at(i)
			return

func find_non_overlapping_position() -> Vector2:
	var bounds = get_spawn_bounds()
	var max_attempts = 10
	for attempt in range(max_attempts):
		var spawn_x = randf_range(bounds.min_x, bounds.max_x)
		var spawn_y = randf_range(bounds.min_y, bounds.max_y)
		var candidate_pos = Vector2(spawn_x, spawn_y)

		if is_position_available(candidate_pos):
			return candidate_pos

	# Fallback: return random position even if overlapping
	return Vector2(randf_range(bounds.min_x, bounds.max_x), randf_range(bounds.min_y, bounds.max_y))

func is_position_available(candidate_pos: Vector2) -> bool:
	var min_distance = 150.0
	for region in occupied_regions:
		var distance = candidate_pos.distance_to(region.position)
		if distance < (min_distance + region.radius):
			return false
	return true
