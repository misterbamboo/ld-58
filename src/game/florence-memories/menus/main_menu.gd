extends Control

const FADE_DURATION: float = 1.5

# Button position offsets (as percentage of background size)
# Adjust these to compensate for transparent padding in button textures
const BUTTON_PLAY_OFFSET: Vector2 = Vector2(-0.04, -0.08)  # No offset by default
const BUTTON_EXIT_OFFSET: Vector2 = Vector2(-0.02, -0.08)  # No offset by default

@onready var aspect_container = $AspectRatioContainer
@onready var button_play = $AspectRatioContainer/Control/TextureButtonPlay
@onready var button_exit = $AspectRatioContainer/Control/TextureButtonExit
@onready var bg_menu = $AspectRatioContainer/BG_Menu
@onready var bg_tuto = $AspectRatioContainer/BG_Tuto

var last_viewport_size: Vector2 = Vector2.ZERO
var waiting_for_click: bool = false

func _ready() -> void:
	show()
	bg_tuto.hide()
	bg_tuto.modulate.a = 1.0
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	position_buttons()
	last_viewport_size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	var current_size = get_viewport().get_visible_rect().size
	if current_size != last_viewport_size:
		last_viewport_size = current_size
		position_buttons()

func _input(event: InputEvent) -> void:
	if waiting_for_click and event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			waiting_for_click = false

func _on_viewport_resized() -> void:
	position_buttons()

func position_buttons() -> void:
	var bg_rect = $AspectRatioContainer/BG_Menu
	var bg_size = bg_rect.size

	# Position buttons relative to background slots
	# Since buttons are under Control (centered), we need to offset from center
	var center_offset = bg_size / 2.0

	# Apply percentage-based offsets to compensate for transparent padding
	button_play.position = (bg_size * Vector2(0.42, 0.65)) - center_offset + (bg_size * BUTTON_PLAY_OFFSET)
	button_exit.position = (bg_size * Vector2(0.53, 0.65)) - center_offset + (bg_size * BUTTON_EXIT_OFFSET)

func _on_button_play_pressed() -> void:
	disable_buttons()
	start_tutorial_sequence()

func start_tutorial_sequence() -> void:
	await fade_out_buttons()
	await transition_menu_to_tutorial()
	await wait_for_player_click()
	await fade_out_tutorial()
	hide()

func disable_buttons() -> void:
	button_play.disabled = true
	button_exit.disabled = true

func fade_out_buttons() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(button_play, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(button_exit, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished

func transition_menu_to_tutorial() -> void:
	bg_tuto.show()
	bg_tuto.modulate.a = 0.0

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bg_menu, "modulate:a", 0.0, FADE_DURATION)
	tween.parallel().tween_property(bg_tuto, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

func wait_for_player_click() -> void:
	waiting_for_click = true
	while waiting_for_click:
		await get_tree().process_frame

func fade_out_tutorial() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(bg_tuto, "modulate:a", 0.0, FADE_DURATION)
	await tween.finished


func _on_texture_button_exit_pressed() -> void:
	if OS.has_feature("web"):
		# On web, close the browser tab/window
		JavaScriptBridge.eval("window.close();")
	else:
		# On desktop, quit the application
		get_tree().quit()
