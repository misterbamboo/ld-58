class_name CloudAlpha extends Sprite2D

@export var fade_in_duration: float = 3.0
@export var fade_out_duration: float = 3.0

var cloud: Cloud

func _ready():
	modulate.a = 0.0
	cloud = get_parent().get_parent() as Cloud

func _process(_delta):
	if cloud:
		apply_alpha()

func apply_alpha():
	var current_time = cloud.get_current_time()
	var lifespan = cloud.get_lifespan()
	
	if current_time < fade_in_duration:
		# Fade in phase
		modulate.a = clamp(current_time / fade_in_duration, 0.0, 1.0)
	elif current_time > lifespan - fade_out_duration:
		# Fade out phase
		var fade_out_progress = (current_time - (lifespan - fade_out_duration)) / fade_out_duration
		modulate.a = clamp(1.0 - fade_out_progress, 0.0, 1.0)
	else:
		# Fully visible
		modulate.a = 1.0
