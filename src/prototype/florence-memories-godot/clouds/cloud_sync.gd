extends Node2D
class_name CloudSync

const Cloud = preload("res://clouds/cloud.gd")

@export var time_offset: float = -20.0
@export var highlight_line: Line2D
@export var highlight_duration: float = 2.5

signal cloud_sync_clicked

var clouds: Array = []
var internal_time: float = 0.0
var is_mouse_over: bool = false
var line_min_x: float
var line_max_x: float
var line_min_y: float
var line_max_y: float

func _ready():
	load_cloud_children()
	internal_time = time_offset
	precompute_line_bounds()

func load_cloud_children():
	for child in get_children():
		if child is Cloud:
			clouds.append(child)

func _process(delta):
	internal_time += delta

	for cloud in clouds:
		cloud.position.x = cloud.initial_position.x + (internal_time * cloud.speed * cloud.direction)

	update_highlight_visibility()

func update_highlight_visibility():
	if highlight_line == null:
		return

	var is_in_time_window = internal_time >= -highlight_duration and internal_time <= highlight_duration
	highlight_line.visible = is_in_time_window and is_mouse_over

func _input(event):
	if event is InputEventMouseMotion:
		is_mouse_over = _is_mouse_in_line_bounds(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_mouse_over and internal_time >= -highlight_duration and internal_time <= highlight_duration:
			cloud_sync_clicked.emit()

func precompute_line_bounds():
	if highlight_line == null:
		return

	var points = highlight_line.points
	if points.size() < 2:
		return

	line_min_x = INF
	line_max_x = -INF
	line_min_y = INF
	line_max_y = -INF

	for point in points:
		line_min_x = min(line_min_x, point.x)
		line_max_x = max(line_max_x, point.x)
		line_min_y = min(line_min_y, point.y)
		line_max_y = max(line_max_y, point.y)

func _is_mouse_in_line_bounds(mouse_pos: Vector2) -> bool:
	if highlight_line == null:
		return false

	var local_mouse_pos = to_local(mouse_pos)

	return local_mouse_pos.x >= line_min_x and local_mouse_pos.x <= line_max_x and local_mouse_pos.y >= line_min_y and local_mouse_pos.y <= line_max_y
