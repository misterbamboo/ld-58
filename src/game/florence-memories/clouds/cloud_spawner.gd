extends Node2D
class_name CloudSpawner

class OccupiedRegion:
	var position: Vector2
	var radius: float
	var shape: CloudShape

@export var cloud_scenes: Array[PackedScene] = []
@export var shape_scenes: Array[PackedScene] = []

const PADDING_PERCENT: float = 0.2
const SHAPE_SPAWN_INTERVAL: float = 30.0
const CLOUD_SPAWN_INTERVAL: float = 2.0
const CLOUD_LIFESPAN: float = 30.0

var shape_spawn_timer: float = 0.0
var cloud_spawn_timer: float = 0.0
var screen_size: Vector2 = Vector2.ZERO

var available_shape_scenes: Array[PackedScene] = []
var pending_clouds: Array[Cloud] = []
var pending_shapes: Array[CloudShape] = []
var occupied_regions: Array[OccupiedRegion] = []
var last_viewport_size: Vector2 = Vector2.ZERO

func _ready():
	screen_size = get_viewport_rect().size
	last_viewport_size = screen_size

	# Initialize available shapes (all shapes are available at start)
	available_shape_scenes = shape_scenes.duplicate()

	# Subscribe to events
	MessageBus.subscribe(CloudEvents.SHAPE_VANISHED, _on_shape_vanished)
	MessageBus.subscribe(CloudEvents.SHAPE_FULLY_FADED, _on_shape_captured)

	# Start timers at 0 (will spawn immediately on first _process)
	shape_spawn_timer = SHAPE_SPAWN_INTERVAL
	cloud_spawn_timer = CLOUD_SPAWN_INTERVAL

func _process(delta):
	check_viewport_resize()
	update_spawn_timers(delta)
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

func update_spawn_timers(delta: float):
	# Update shape spawn timer (every 30 seconds)
	shape_spawn_timer += delta
	if shape_spawn_timer >= SHAPE_SPAWN_INTERVAL:
		spawn_shape()
		shape_spawn_timer = 0.0

	# Update cloud spawn timer (every 2 seconds)
	cloud_spawn_timer += delta
	if cloud_spawn_timer >= CLOUD_SPAWN_INTERVAL:
		# Spawn 2-3 clouds for atmosphere
		var cloud_count = randi_range(2, 3)
		for i in range(cloud_count):
			spawn_cloud()
		cloud_spawn_timer = 0.0

func spawn_shape():
	# Only spawn if there are uncollected shapes available
	if available_shape_scenes.is_empty():
		print("[CloudSpawner] No more uncollected shapes to spawn")
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
	# Pick from available (uncollected) shapes
	var shape_scene = available_shape_scenes[randi() % available_shape_scenes.size()]
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
	var lifespan = CLOUD_LIFESPAN

	cloud.initialize(meet_at_pos, direction, lifespan, 0.0)

func initialize_shape(shape: CloudShape):
	var meet_at_pos = find_non_overlapping_position()
	var direction = -1
	var lifespan = CLOUD_LIFESPAN
	var meet_in_time = lifespan / 2.0

	shape.initialize(meet_at_pos, direction, lifespan, meet_in_time)

	var region = OccupiedRegion.new()
	region.position = meet_at_pos
	region.radius = 150.0
	region.shape = shape
	occupied_regions.append(region)

func _on_shape_vanished(data: Dictionary):
	release_occupied_region(data.shape)

func _on_shape_captured(data: Dictionary):
	var captured_shape = data.get("shape") as CloudShape
	if not captured_shape:
		return

	# Remove the captured shape's scene from available pool
	var shape_scene = captured_shape.scene_file_path
	for i in range(available_shape_scenes.size() - 1, -1, -1):
		if available_shape_scenes[i].resource_path == shape_scene:
			available_shape_scenes.remove_at(i)
			print("[CloudSpawner] Removed captured shape from pool: ", shape_scene)
			break

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
