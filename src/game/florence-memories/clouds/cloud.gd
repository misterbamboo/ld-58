class_name Cloud extends Sprite2D

@export var min_speed: float = 1.0
@export var max_speed: float = 5.0
@export var squish_duration: float = 6.0
@export var squish_amount: float = 0.05
@export var rotation_amount: float = 0.05

var speed: float
var direction: int
var initial_position: Vector2
var initial_scale: Vector2
var squish_timer: float = 0.0

func _ready():
	initial_position = position
	initial_scale = scale
	speed = randf_range(min_speed, max_speed)
	squish_timer = randf_range(0.0, squish_duration)
	# Direction defaults to random, can be overridden by spawner
	if direction == 0:
		direction = 1 if randf() > 0.5 else -1

func _process(delta):
	position.x += speed * direction * delta
	apply_squish_animation(delta)

func apply_squish_animation(delta: float) -> void:
	squish_timer += delta
	var squish_progress = squish_timer / squish_duration
	var squish_wave = sin(squish_progress * TAU)

	var scale_x = initial_scale.x + (initial_scale.x * squish_amount * squish_wave)
	var scale_y = initial_scale.y - (initial_scale.y * squish_amount * squish_wave)
	scale = Vector2(scale_x, scale_y)

	rotation = rotation_amount * squish_wave

	if squish_timer >= squish_duration:
		squish_timer = 0.0

func set_direction(new_direction: int) -> void:
	direction = new_direction
