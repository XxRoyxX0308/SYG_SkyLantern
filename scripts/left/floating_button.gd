extends Button
class_name FloatingButton

const ConfigLoader = preload("res://scripts/core/config_loader.gd")

var _base_position: Vector2 = Vector2.ZERO
var _oscillation: Vector2 = Vector2(12.0, 8.0)
var _speed: float = 1.0
var _phase: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	toggle_mode = true
	clip_text = true
	_base_position = position


func configure(button_config: Dictionary, fallback_label: String) -> void:
	text = ConfigLoader.string_from(button_config.get("label"), fallback_label)
	position = ConfigLoader.vector2_from(button_config.get("position"), position)
	size = ConfigLoader.vector2_from(button_config.get("size"), Vector2(280, 110))
	_base_position = position
	_oscillation = ConfigLoader.vector2_from(button_config.get("oscillation"), Vector2(12.0, 8.0))
	_speed = ConfigLoader.float_from(button_config.get("speed"), 1.0)
	_phase = randf() * TAU
	add_theme_font_size_override("font_size", ConfigLoader.int_from(button_config.get("font_size"), 26))
	_apply_styles()


func _process(delta: float) -> void:
	if not visible:
		return
	_phase += delta * _speed
	position = _base_position + Vector2(sin(_phase) * _oscillation.x, cos(_phase * 1.2) * _oscillation.y)


func _apply_styles() -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color.from_string("#17355b", Color(0.09, 0.21, 0.36, 1.0))
	normal.corner_radius_top_left = 24
	normal.corner_radius_top_right = 24
	normal.corner_radius_bottom_right = 24
	normal.corner_radius_bottom_left = 24
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.from_string("#8fd1ff", Color(0.56, 0.82, 1.0, 1.0))
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color.from_string("#214b7a", Color(0.13, 0.29, 0.48, 1.0))
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color.from_string("#f0b75d", Color(0.94, 0.72, 0.36, 1.0))
	pressed.border_color = Color.from_string("#ffe8c4", Color(1.0, 0.91, 0.77, 1.0))
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_color_override("font_color", Color.from_string("#eef8ff", Color.WHITE))
	add_theme_color_override("font_focus_color", Color.from_string("#eef8ff", Color.WHITE))
	add_theme_color_override("font_hover_color", Color.from_string("#eef8ff", Color.WHITE))
	add_theme_color_override("font_pressed_color", Color.from_string("#1f2738", Color(0.12, 0.15, 0.22, 1.0)))