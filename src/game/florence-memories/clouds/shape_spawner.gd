extends Node2D
class_name ShapeSpawner

@export var shape_scenes: Array[PackedScene] = []
@export var max_shapes: int = 2
@export var spawn_y_min: float = 100.0
@export var spawn_y_max: float = 300.0
@export var offscreen_margin: float = 200.0

var screen_size: Vector2 = Vector2.ZERO
var active_shapes: int = 0

func _ready():
	screen_size = get_viewport_rect().size
	spawn_initial_shapes()

func spawn_initial_shapes():
	for i in range(max_shapes):
		spawn_shape()

func spawn_shape():
	if shape_scenes.is_empty():
		return

	if active_shapes >= max_shapes:
		return

	var shape_instance = create_shape_instance()
	var spawn_from_left = randf() > 0.5
	var spawn_x = get_spawn_x_position(spawn_from_left)
	var spawn_y = randf_range(spawn_y_min, spawn_y_max)

	shape_instance.position = Vector2(spawn_x, spawn_y)
	connect_shape_signals(shape_instance)
	set_shape_direction(shape_instance, spawn_from_left)
	add_child(shape_instance)
	active_shapes += 1

func create_shape_instance() -> CloudShape:
	var shape_scene = shape_scenes[randi() % shape_scenes.size()]
	return shape_scene.instantiate()

func get_spawn_x_position(spawn_from_left: bool) -> float:
	return -offscreen_margin if spawn_from_left else screen_size.x + offscreen_margin

func connect_shape_signals(shape: CloudShape) -> void:
	shape.shape_vanished.connect(_on_shape_vanished)

func set_shape_direction(shape: CloudShape, spawned_from_left: bool) -> void:
	var direction = 1 if spawned_from_left else -1
	for cloud in shape.clouds:
		cloud.set_direction(direction)

func _on_shape_vanished():
	active_shapes -= 1
	spawn_shape()
