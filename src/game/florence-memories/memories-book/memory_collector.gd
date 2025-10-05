extends Control

const MAX_MEMORY_SLOTS: int = 12
const ANIMATION_DURATION: float = 1.5
const WAIT_AFTER_FADEOUT: float = 1.0
const CURVE_HEIGHT: float = 100.0
const MAX_FLYING_SPRITE_SIZE: float = 150.0

var memory_slots: Array[Texture2D] = []
var next_slot_index: int = 0

func _ready() -> void:
	initialize_memory_slots()
	MessageBus.subscribe("highlight_clicked", _on_highlight_clicked)
	MessageBus.subscribe("shape_fully_faded", _on_shape_fully_faded)

func initialize_memory_slots() -> void:
	memory_slots.resize(MAX_MEMORY_SLOTS)

func _on_highlight_clicked(data: Dictionary) -> void:
	var shape = data.get("shape") as CloudShape
	if shape and has_available_slot():
		shape.capture_memory()

func _on_shape_fully_faded(data: Dictionary) -> void:
	print("[MemoryCollector] Received shape_fully_faded event")
	var texture = data.get("texture") as Texture2D
	var start_pos = data.get("position") as Vector2

	print("[MemoryCollector] Texture: ", texture, " | Position: ", start_pos, " | Has slot: ", has_available_slot())

	if texture and has_available_slot():
		print("[MemoryCollector] Waiting ", WAIT_AFTER_FADEOUT, " seconds before spawning sprite")
		await get_tree().create_timer(WAIT_AFTER_FADEOUT).timeout
		spawn_and_animate_memory(texture, start_pos)

func spawn_and_animate_memory(texture: Texture2D, start_pos: Vector2) -> void:
	var flying_sprite = create_flying_sprite(texture, start_pos)
	get_tree().root.add_child(flying_sprite)

	print("[MemoryCollector] Added flying sprite to scene tree")

	var slot_index = get_next_available_slot()
	var target_pos = get_memory_slot_global_position(slot_index)

	print("[MemoryCollector] Animating to slot ", slot_index, " at position: ", target_pos)

	animate_with_curve(flying_sprite, target_pos, slot_index, texture)

func create_flying_sprite(texture: Texture2D, start_pos: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = start_pos

	# Scale down to reasonable size while maintaining aspect ratio
	var texture_size = texture.get_size()
	var max_dimension = max(texture_size.x, texture_size.y)
	var initial_scale = MAX_FLYING_SPRITE_SIZE / max_dimension
	sprite.scale = Vector2(initial_scale, initial_scale)

	print("[MemoryCollector] Created flying sprite at position: ", start_pos, " with initial scale: ", initial_scale)
	return sprite

func animate_with_curve(sprite: Sprite2D, target_pos: Vector2, slot_index: int, texture: Texture2D) -> void:
	var start_pos = sprite.global_position
	var initial_scale = sprite.scale
	var tween = create_tween()

	var arc_peak_y = min(start_pos.y, target_pos.y) - CURVE_HEIGHT
	var mid_pos = Vector2((start_pos.x + target_pos.x) / 2.0, arc_peak_y)

	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)

	tween.tween_property(sprite, "global_position", mid_pos, ANIMATION_DURATION / 2.0)
	tween.tween_property(sprite, "global_position", target_pos, ANIMATION_DURATION / 2.0)

	# Scale down to memory slot size (30% of initial scale)
	var final_scale = initial_scale * 0.3
	tween.parallel().tween_property(sprite, "scale", final_scale, ANIMATION_DURATION)

	tween.finished.connect(func(): on_animation_complete(sprite, slot_index, texture))

func on_animation_complete(sprite: Sprite2D, slot_index: int, texture: Texture2D) -> void:
	fill_memory_slot(slot_index, texture)
	sprite.queue_free()
	next_slot_index += 1

func fill_memory_slot(slot_index: int, texture: Texture2D) -> void:
	memory_slots[slot_index] = texture
	var memory_node = get_memory_node_by_index(slot_index)
	if memory_node:
		memory_node.texture = texture

func get_memory_node_by_index(slot_index: int) -> TextureRect:
	var texture_rect = $TextureRect
	if slot_index < 6:
		return texture_rect.get_node("HBoxContainer/GridContainerLeft").get_child(slot_index)
	else:
		return texture_rect.get_node("HBoxContainer/GridContainerRight").get_child(slot_index - 6)

func get_memory_slot_global_position(slot_index: int) -> Vector2:
	var memory_node = get_memory_node_by_index(slot_index)
	if memory_node:
		return memory_node.global_position + memory_node.size / 2.0
	return Vector2.ZERO

func has_available_slot() -> bool:
	return next_slot_index < MAX_MEMORY_SLOTS

func get_next_available_slot() -> int:
	if has_available_slot():
		return next_slot_index
	return -1
