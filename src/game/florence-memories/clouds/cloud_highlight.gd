extends Line2D
class_name CloudHighlight

@export var highlight_duration: float = 2.5

var is_mouse_over: bool = false
var is_captured: bool = false
var line_min_x: float
var line_max_x: float
var line_min_y: float
var line_max_y: float

func _ready():
	precompute_line_bounds()

func _process(_delta):
	update_highlight_visibility()

func update_highlight_visibility():
	var parent_shape = get_parent() as CloudShape
	if parent_shape == null:
		visible = false
		return

	var current_time = parent_shape.get_internal_time()
	var meeting_time = parent_shape.get_lifespan() / 2.0
	var window_start = meeting_time - highlight_duration
	var window_end = meeting_time + highlight_duration
	var is_in_time_window = current_time >= window_start and current_time <= window_end
	visible = is_in_time_window and is_mouse_over and not is_captured

func _input(event):
	if event is InputEventMouseMotion:
		is_mouse_over = is_mouse_in_line_bounds(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var parent_shape = get_parent() as CloudShape
		if parent_shape and is_mouse_over and not is_captured:
			var current_time = parent_shape.get_internal_time()
			var meeting_time = parent_shape.get_lifespan() / 2.0
			var window_start = meeting_time - highlight_duration
			var window_end = meeting_time + highlight_duration
			var is_in_time_window = current_time >= window_start and current_time <= window_end
			if is_in_time_window:
				is_captured = true
				MessageBus.publish(CloudEvents.HIGHLIGHT_CLICKED, {"highlight": self, "shape": parent_shape})

func precompute_line_bounds():
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

func is_mouse_in_line_bounds(mouse_pos: Vector2) -> bool:
	var local_mouse_pos = to_local(mouse_pos)
	return local_mouse_pos.x >= line_min_x and local_mouse_pos.x <= line_max_x and local_mouse_pos.y >= line_min_y and local_mouse_pos.y <= line_max_y
