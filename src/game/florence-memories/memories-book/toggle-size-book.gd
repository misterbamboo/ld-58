extends TextureRect

const SIZE_SMALL: int = 100
const SIZE_BIG: int = 600
const MEMORY_ITEM_SIZE_SMALL: int = 12
const MEMORY_ITEM_SIZE_BIG: int = 72
const ANIMATION_DURATION: float = 0.3

const HBOX_OFFSET_SMALL: Vector2 = Vector2(16, 26)
const HBOX_OFFSET_BIG: Vector2 = Vector2(96, 156)  # Adjust these values for BIG mode
const HBOX_SIZE_SMALL: Vector2 = Vector2(68, 44)  # Current size from scene
const HBOX_SIZE_BIG: Vector2 = Vector2(408, 264)  # Adjust these values for BIG mode
const GRID_H_SEPARATION_SMALL: int = 5
const GRID_H_SEPARATION_BIG: int = 23
const GRID_V_SEPARATION_SMALL: int = 4
const GRID_V_SEPARATION_BIG: int = 22

var is_big: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$ClickZone.mouse_filter = Control.MOUSE_FILTER_PASS
	$ClickZone.gui_input.connect(_on_click_zone_input)

func _input(event: InputEvent) -> void:
	if not is_big:
		return

	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_global_mouse_position()
			if not get_global_rect().has_point(mouse_pos):
				toggle_size()
				get_viewport().set_input_as_handled()

func _on_click_zone_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			toggle_size()

func toggle_size() -> void:
	is_big = !is_big

	# Disable ClickZone in BIG mode to allow hover events on memories
	if is_big:
		$ClickZone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		$ClickZone.mouse_filter = Control.MOUSE_FILTER_PASS

	var tween = create_tween()
	var desired_size = get_desired_size()
	var scale_factor = get_scale_factor(desired_size)

	animate_texture_rect(tween, desired_size)
	animate_click_zone(tween, desired_size)
	animate_memory_container(tween, scale_factor)
	animate_memory_items(tween)

func get_desired_size() -> int:
	return SIZE_BIG if is_big else SIZE_SMALL

func get_current_size() -> int:
	return SIZE_SMALL if not is_big else SIZE_BIG

func get_scale_factor(desired_size: int) -> float:
	return float(desired_size) / float(get_current_size())

func animate_texture_rect(tween: Tween, desired_size: int) -> void:
	var new_offset_left = offset_right - desired_size
	var new_offset_top = offset_bottom - desired_size

	tween.tween_property(self, "offset_left", new_offset_left, ANIMATION_DURATION)
	tween.parallel().tween_property(self, "offset_top", new_offset_top, ANIMATION_DURATION)

func animate_click_zone(tween: Tween, desired_size: int) -> void:
	var click_zone = $ClickZone
	var new_offset_left = click_zone.offset_right - desired_size
	var new_offset_top = click_zone.offset_bottom - desired_size

	tween.parallel().tween_property(click_zone, "offset_left", new_offset_left, ANIMATION_DURATION)
	tween.parallel().tween_property(click_zone, "offset_top", new_offset_top, ANIMATION_DURATION)

func animate_memory_container(tween: Tween, scale_factor: float) -> void:
	var hbox = $HBoxContainer
	var target_offset = get_hbox_target_offset()
	var target_size = get_hbox_target_size()

	tween.parallel().tween_property(hbox, "offset_left", target_offset.x, ANIMATION_DURATION)
	tween.parallel().tween_property(hbox, "offset_top", target_offset.y, ANIMATION_DURATION)
	tween.parallel().tween_property(hbox, "offset_right", target_offset.x + target_size.x, ANIMATION_DURATION)
	tween.parallel().tween_property(hbox, "offset_bottom", target_offset.y + target_size.y, ANIMATION_DURATION)

func get_hbox_target_offset() -> Vector2:
	return HBOX_OFFSET_BIG if is_big else HBOX_OFFSET_SMALL

func get_hbox_target_size() -> Vector2:
	return HBOX_SIZE_BIG if is_big else HBOX_SIZE_SMALL

func animate_memory_items(tween: Tween) -> void:
	var memory_size = get_memory_item_size()
	var left_grid = $HBoxContainer/GridContainerLeft
	var right_grid = $HBoxContainer/GridContainerRight

	animate_grid_children(tween, left_grid, memory_size)
	animate_grid_children(tween, right_grid, memory_size)
	animate_grid_separation(tween, left_grid)
	animate_grid_separation(tween, right_grid)

func get_memory_item_size() -> int:
	return MEMORY_ITEM_SIZE_BIG if is_big else MEMORY_ITEM_SIZE_SMALL

func animate_grid_children(tween: Tween, grid: GridContainer, size: int) -> void:
	for child in grid.get_children():
		tween.parallel().tween_property(child, "custom_minimum_size", Vector2(size, size), ANIMATION_DURATION)

func animate_grid_separation(tween: Tween, grid: GridContainer) -> void:
	var h_sep = get_grid_h_separation()
	var v_sep = get_grid_v_separation()

	tween.parallel().tween_property(grid, "theme_override_constants/h_separation", h_sep, ANIMATION_DURATION)
	tween.parallel().tween_property(grid, "theme_override_constants/v_separation", v_sep, ANIMATION_DURATION)

func get_grid_h_separation() -> int:
	return GRID_H_SEPARATION_BIG if is_big else GRID_H_SEPARATION_SMALL

func get_grid_v_separation() -> int:
	return GRID_V_SEPARATION_BIG if is_big else GRID_V_SEPARATION_SMALL

func is_in_big_mode() -> bool:
	return is_big
