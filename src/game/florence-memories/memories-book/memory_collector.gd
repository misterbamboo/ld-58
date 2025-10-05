extends Control

const MAX_MEMORY_SLOTS: int = 12
const ANIMATION_DURATION: float = 0.7

var memory_slots: Array[Texture2D] = []
var next_slot_index: int = 0

func _ready() -> void:
	initialize_memory_slots()
	MessageBus.subscribe("highlight_clicked", _on_highlight_clicked)

func initialize_memory_slots() -> void:
	memory_slots.resize(MAX_MEMORY_SLOTS)

func _on_highlight_clicked(data: Dictionary) -> void:
	var shape = data.get("shape") as CloudShape
	if shape and has_available_slot():
		capture_memory(shape)

func capture_memory(shape: CloudShape) -> void:
	var texture = shape.get_cloud_image()
	if texture == null:
		return

	var start_pos = shape.global_position
	shape.capture_memory()

	spawn_and_animate_memory(texture, start_pos)

func spawn_and_animate_memory(texture: Texture2D, start_pos: Vector2) -> void:
	var flying_sprite = create_flying_sprite(texture, start_pos)
	get_tree().root.add_child(flying_sprite)

	var slot_index = get_next_available_slot()
	var target_pos = get_memory_slot_global_position(slot_index)

	animate_to_book(flying_sprite, target_pos, slot_index, texture)

func create_flying_sprite(texture: Texture2D, start_pos: Vector2) -> Sprite2D:
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.global_position = start_pos
	sprite.z_index = 100
	return sprite

func animate_to_book(sprite: Sprite2D, target_pos: Vector2, slot_index: int, texture: Texture2D) -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(sprite, "global_position", target_pos, ANIMATION_DURATION)
	tween.parallel().tween_property(sprite, "scale", Vector2(0.3, 0.3), ANIMATION_DURATION)

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
