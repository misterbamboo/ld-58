extends Control
class_name MemoryTooltip

class MemoryData:
	var title: String
	var description: String

	func _init(p_title: String, p_description: String):
		title = p_title
		description = p_description

var memory_configs: Dictionary = {}

var tooltip_container: VBoxContainer
var title_label: Label
var desc_label: Label
var toggle_book: Control

func _ready() -> void:
	initialize_memory_configs()
	create_tooltip()
	setup_memory_hover_handlers()

func initialize_memory_configs() -> void:
	memory_configs = {
		"tractor": MemoryData.new(
			"Tractor",
			"A tractor cloud that reminds me of when Grandpa let me sit on his lap and steer the big red one in the field."
		),
		"train": MemoryData.new(
			"Train",
			"A train cloud that makes me think of the choo-choo we watched together, waving as it passed by."
		),
		"tricycle": MemoryData.new(
			"Tricycle",
			"A tricycle cloud that looks just like my first ride, when Mom ran beside me and laughed every time I wobbled."
		),
		"car": MemoryData.new(
			"Car",
			"A car cloud that reminds me of our family trips — snacks, songs, and everyone trying to spot the first moose."
		),
		"dinosaur": MemoryData.new(
			"Dinosaur",
			"A dinosaur cloud that makes me think of the little green toy Grandpa gave me, and how I made it roar louder than him."
		),
		"dog": MemoryData.new(
			"Dog",
			"A dog cloud that reminds me of cuddling with our puppy under a blanket after the rain."
		),
		"elephant": MemoryData.new(
			"Elephant",
			"An elephant cloud that makes me remember my first zoo trip — I held Grandma's hand so tight when it trumpeted!"
		),
		"flower": MemoryData.new(
			"Flower",
			"A flower cloud that reminds me of picking daisies for Mom and how she smiled like sunshine."
		),
		"piggybank": MemoryData.new(
			"Piggy Bank",
			"A piggy bank cloud that makes me think of the coins Dad helped me save for my favorite candy."
		),
		"rainbow": MemoryData.new(
			"Rainbow",
			"A rainbow cloud that reminds me that even after the rain, something beautiful always comes."
		),
		"shoehorse": MemoryData.new(
			"Horseshoe",
			"A horseshoe cloud that makes me think of the lucky charm Grandma hung by the door — she said it keeps joy inside."
		),
		"butterfly": MemoryData.new(
			"Butterfly",
			"A butterfly cloud that reminds me of chasing colors in the garden while everyone cheered me on."
		)
	}

func create_tooltip() -> void:
	tooltip_container = VBoxContainer.new()
	tooltip_container.visible = false
	tooltip_container.z_index = 100
	tooltip_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_container.top_level = true  # Escape parent clipping
	tooltip_container.custom_minimum_size = Vector2(280, 0)

	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(280, 160)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.96, 0.93, 0.85, 0.95)
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.6, 0.5, 0.4, 1.0)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	style_box.content_margin_left = 5
	style_box.content_margin_right = 5
	style_box.content_margin_top = 5
	style_box.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style_box)

	print("[MemoryTooltip] Panel created with size: ", panel.size)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15, 1))
	title_label.add_theme_constant_override("line_spacing", 2)

	desc_label = Label.new()
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(250, 0)
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1))
	desc_label.add_theme_constant_override("line_spacing", 4)

	content.add_child(title_label)
	content.add_child(desc_label)
	margin.add_child(content)
	panel.add_child(margin)
	tooltip_container.add_child(panel)
	add_child(tooltip_container)

func setup_memory_hover_handlers() -> void:
	toggle_book = $"../TextureRect"

	var hbox = toggle_book.get_node("HBoxContainer")
	var left_grid = toggle_book.get_node("HBoxContainer/GridContainerLeft")
	var right_grid = toggle_book.get_node("HBoxContainer/GridContainerRight")

	# Fix mouse_filter for all parent containers
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	left_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	right_grid.mouse_filter = Control.MOUSE_FILTER_PASS

	connect_memory_signals(left_grid, 0)
	connect_memory_signals(right_grid, 6)

func connect_memory_signals(grid: GridContainer, offset: int) -> void:
	for i in range(grid.get_child_count()):
		var memory = grid.get_child(i)
		if memory is TextureRect:
			memory.mouse_filter = Control.MOUSE_FILTER_PASS
			memory.mouse_entered.connect(_on_memory_hover.bind(offset + i))
			memory.mouse_exited.connect(_on_memory_hover_end)

func _on_memory_hover(slot_index: int) -> void:
	if not toggle_book.is_in_big_mode():
		return

	var memory_collector = get_parent()
	if not memory_collector:
		return

	var memory_data = memory_collector.get_memory_data(slot_index)
	if not memory_data:
		return

	title_label.text = memory_data.title
	desc_label.text = memory_data.description

	# Force layout recalculation after setting text
	tooltip_container.reset_size()

	tooltip_container.visible = true

	var mouse_pos = get_global_mouse_position()
	tooltip_container.global_position = mouse_pos + Vector2(20, 20)

	print("[MemoryTooltip] Tooltip visible, container size: ", tooltip_container.size)

func _on_memory_hover_end() -> void:
	tooltip_container.visible = false

func get_memory_data_for_texture(texture_path: String) -> MemoryData:
	var path_lower = texture_path.to_lower()
	for keyword in memory_configs.keys():
		if keyword in path_lower:
			return memory_configs[keyword]
	return null
