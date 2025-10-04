class_name CloudSquish extends Node2D

@export var squish_duration: float = 6.0
@export var squish_amount: float = 0.05
@export var rotation_amount: float = 0.05

var initial_scale: Vector2
var squish_timer: float = 0.0
var cloud: Cloud

func _ready():
	initial_scale = scale
	squish_timer = randf_range(0.0, squish_duration)
	cloud = get_parent() as Cloud

func _process(delta):
	apply_squish_animation(delta)

func apply_squish_animation(delta: float) -> void:
	squish_timer += delta
	var squish_progress = squish_timer / squish_duration
	var squish_wave = sin(squish_progress * TAU)

	var scale_x = initial_scale.x + (initial_scale.x * squish_amount * squish_wave)
	var scale_y = initial_scale.y - (initial_scale.y * squish_amount * squish_wave)
	scale = Vector2(scale_x, scale_y)

	if cloud and cloud.should_override_rotation():
		rotation = cloud.get_target_rotation()
	else:
		rotation = rotation_amount * squish_wave

	if squish_timer >= squish_duration:
		squish_timer = 0.0
