extends Node2D
class_name CloudSpawner

class OccupiedRegion:
	var position: Vector2
	var radius: float
	var shape: CloudShape

@export var cloud_scenes: Array[PackedScene] = []
@export var shape_scenes: Array[PackedScene] = []

const SHAPE_PADDING_SIDES: float = 0.05  # 5% padding for left, top, right
const SHAPE_PADDING_BOTTOM: float = 0.15  # 15% padding for bottom
const CLOUD_PADDING_RIGHT: float = -0.05  # Allow 5% outside right edge
const SHAPE_SPAWN_INTERVAL: float = 30.0
const CLOUD_SPAWN_INTERVAL: float = 2.0
const CLOUD_LIFESPAN: float = 30.0

const CLOUD_MIN_SCALE: float = 1.0
const CLOUD_MAX_SCALE: float = 2.5

const CLOUD_BASE_MIN_SPEED: float = 10.0
const CLOUD_BASE_MAX_SPEED: float = 25.0

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

func get_shape_spawn_bounds() -> Dictionary:
	# CloudShapes: 5% padding on left/top/right, 15% padding on bottom
	var padding_left = screen_size.x * SHAPE_PADDING_SIDES
	var padding_right = screen_size.x * SHAPE_PADDING_SIDES
	var padding_top = screen_size.y * SHAPE_PADDING_SIDES
	var padding_bottom = screen_size.y * SHAPE_PADDING_BOTTOM

	return {
		"min_x": padding_left,
		"max_x": screen_size.x - padding_right,
		"min_y": padding_top,
		"max_y": screen_size.y - padding_bottom
	}

func get_cloud_spawn_bounds() -> Dictionary:
	# Individual clouds: full screen, can spawn 5% outside right edge
	var extend_right = screen_size.x * abs(CLOUD_PADDING_RIGHT)

	return {
		"min_x": 0,
		"max_x": screen_size.x + extend_right,
		"min_y": 0,
		"max_y": screen_size.y
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
	var bounds = get_cloud_spawn_bounds()
	var spawn_x = randf_range(bounds.min_x, bounds.max_x)
	var spawn_y = randf_range(bounds.min_y, bounds.max_y)
	var meet_at_pos = Vector2(spawn_x, spawn_y)

	var direction = -1
	var lifespan = CLOUD_LIFESPAN

	# Override cloud speed values with spawner constants
	cloud.min_speed = CLOUD_BASE_MIN_SPEED
	cloud.max_speed = CLOUD_BASE_MAX_SPEED

	# Random scale based on constants
	var random_scale = randf_range(CLOUD_MIN_SCALE, CLOUD_MAX_SCALE)
	cloud.scale = Vector2(random_scale, random_scale)

	# Speed inversely proportional to scale (bigger = slower)
	var speed_multiplier = 1.0 / random_scale

	cloud.initialize(meet_at_pos, direction, lifespan, 0.0, 0.0, speed_multiplier)

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
	var bounds = get_shape_spawn_bounds()
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
