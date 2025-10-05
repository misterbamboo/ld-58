extends Control

const FADE_DURATION: float = 1.5

@onready var aspect_container = $AspectRatioContainer
@onready var button_play = $AspectRatioContainer/Control/ButtonPlay
@onready var button_credits = $AspectRatioContainer/Control/ButtonCredits

var last_viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	position_buttons()
	last_viewport_size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	var current_size = get_viewport().get_visible_rect().size
	if current_size != last_viewport_size:
		last_viewport_size = current_size
		position_buttons()

func _on_viewport_resized() -> void:
	position_buttons()

func position_buttons() -> void:
	var bg_rect = $AspectRatioContainer/BG_Menu
	var bg_size = bg_rect.size

	# Position buttons relative to background
	# Since buttons are under Control (centered), we need to offset from center
	var center_offset = bg_size / 2.0

	button_play.position = (bg_size * Vector2(0.41, 0.68)) - center_offset
	button_credits.position = (bg_size * Vector2(0.56, 0.68)) - center_offset

func _on_button_play_pressed() -> void:
	disable_buttons()
	fade_out_menu()

func disable_buttons() -> void:
	button_play.disabled = true
	button_credits.disabled = true

func fade_out_menu() -> void:
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.finished.connect(on_fade_complete)

func on_fade_complete() -> void:
	hide()
