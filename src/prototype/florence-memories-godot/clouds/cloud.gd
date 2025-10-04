class_name Cloud extends Node2D

@export var min_speed: float = 1.0
@export var max_speed: float = 5.0

var speed: float
var direction: int
var initial_position: Vector2

func _ready():
	initial_position = position
	speed = randf_range(min_speed, max_speed)
	direction = 1 if randf() > 0.5 else -1
