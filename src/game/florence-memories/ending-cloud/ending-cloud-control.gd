extends Node2D

var timer: float = 0.0
var is_timer_active: bool = false
var all_faded_in: bool = false
var cloud_count: int = 0
var total_fade_time: float = 0.0
var click_area: Area2D

# Centering variables
var virtual_center: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
const LERP_SPEED: float = 2.0

func _ready() -> void:
	# Subscribe to all memories collected event
	MessageBus.subscribe(CloudEvents.ALL_MEMORIES_COLLECTED, _on_all_memories_collected)

	# Count child clouds
	cloud_count = 0
	for child in get_children():
		if child is Sprite2D:
			cloud_count += 1

	# Calculate total time for all clouds to fade in
	total_fade_time = cloud_count * 0.1  # 0.1s per cloud (updated FADE_DURATION)

func _input(event: InputEvent) -> void:
	# Debug trigger: Ctrl+P to start animation
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_P and event.ctrl_pressed:
			print("[EndingCloudControl] DEBUG: Ctrl+P pressed - triggering animation")
			_on_all_memories_collected({})

func _process(delta: float) -> void:
	# Update centering (always active for smooth repositioning)
	update_centering(delta)

	if not is_timer_active:
		return

	timer += delta

	# Check if all clouds have faded in
	if not all_faded_in and timer >= total_fade_time:
		all_faded_in = true
		create_click_area()

func get_timer() -> float:
	return timer

func _on_all_memories_collected(data: Dictionary) -> void:
	print("[EndingCloudControl] All memories collected! Starting animation...")
	is_timer_active = true

func create_click_area() -> void:
	# Calculate bounds from all child cloud positions
	var bounds = calculate_clickable_bounds()

	# Create clickable area
	click_area = Area2D.new()
	add_child(click_area)

	var collision_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()

	var width = bounds.max_x - bounds.min_x
	var height = bounds.max_y - bounds.min_y
	var center_x = (bounds.min_x + bounds.max_x) / 2.0
	var center_y = (bounds.min_y + bounds.max_y) / 2.0

	rect_shape.size = Vector2(width, height)
	collision_shape.shape = rect_shape
	collision_shape.position = Vector2(center_x, center_y)

	click_area.add_child(collision_shape)
	click_area.input_event.connect(_on_click_area_input_event)

	print("[EndingCloudControl] Click area created at: ", center_x, ",", center_y, " size: ", width, "x", height)

func update_centering(delta: float) -> void:
	# Calculate virtual bounds and center
	var bounds = calculate_virtual_bounds()

	var virtual_width = bounds.max_x - bounds.min_x
	var virtual_height = bounds.max_y - bounds.min_y
	virtual_center = Vector2(
		(bounds.min_x + bounds.max_x) / 2.0,
		(bounds.min_y + bounds.max_y) / 2.0
	)

	# Get screen center
	var screen_size = get_viewport().get_visible_rect().size
	var screen_center = screen_size / 2.0

	# Calculate target position (screen center - virtual center offset)
	target_position = screen_center - virtual_center

	# Smoothly lerp to target position
	position = position.lerp(target_position, delta * LERP_SPEED)

func calculate_virtual_bounds() -> Dictionary:
	var min_x = INF
	var max_x = -INF
	var min_y = INF
	var max_y = -INF

	for child in get_children():
		if child is Sprite2D:
			var pos = child.position
			min_x = min(min_x, pos.x)
			max_x = max(max_x, pos.x)
			min_y = min(min_y, pos.y)
			max_y = max(max_y, pos.y)

	return {
		"min_x": min_x,
		"max_x": max_x,
		"min_y": min_y,
		"max_y": max_y
	}

func calculate_clickable_bounds() -> Dictionary:
	# Reuse virtual bounds calculation
	return calculate_virtual_bounds()

func _on_click_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("[EndingCloudControl] Ending cloud clicked! Starting fade out...")
			fade_out_all_clouds()

func fade_out_all_clouds() -> void:
	# Disable click area
	if click_area:
		click_area.queue_free()

	# Start fade out for all clouds
	for child in get_children():
		if child is Sprite2D and child.has_method("start_fade_out"):
			child.start_fade_out(timer)

	# Wait for fade out to complete, then publish game completed event
	await get_tree().create_timer(1.0).timeout  # FADE_OUT_DURATION
	MessageBus.publish(CloudEvents.GAME_COMPLETED, {})
