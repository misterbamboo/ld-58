extends Node2D
class_name CloudShape

@export var offscreen_margin: float = 100.0
@export var time_offset: float = -20.0

var clouds: Array[Cloud] = []
var screen_size: Vector2
var has_vanished: bool = false
var internal_time: float = 0.0

func _ready():
	screen_size = get_viewport_rect().size
	internal_time = time_offset
	load_cloud_children()
	disable_individual_cloud_movement()

func load_cloud_children():
	for child in get_children():
		if child is Cloud:
			clouds.append(child)

func disable_individual_cloud_movement():
	for cloud in clouds:
		cloud.set_process(false)

func _process(delta):
	internal_time += delta
	update_cloud_positions()

	if not has_vanished and are_all_clouds_offscreen():
		has_vanished = true
		MessageBus.publish("shape_vanished", {"shape": self})
		queue_free()

func update_cloud_positions():
	for cloud in clouds:
		cloud.position.x = cloud.initial_position.x + (internal_time * cloud.speed * cloud.direction)

func are_all_clouds_offscreen() -> bool:
	if clouds.is_empty():
		return false

	for cloud in clouds:
		var world_pos = to_global(cloud.position)
		if world_pos.x >= -offscreen_margin and world_pos.x <= screen_size.x + offscreen_margin:
			return false

	return true
