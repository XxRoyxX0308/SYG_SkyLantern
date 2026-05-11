extends Control
class_name MainMenuScreen

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const FloatingButtonScene = preload("res://scripts/left/floating_button.gd")

signal confirmed(selected_ids)

var _title_label: Label
var _buttons_root: Control
var _confirm_button: Button
var _option_buttons: Dictionary = {}


func configure(screen_config: Dictionary, stage_size: Vector2i) -> void:
	if _title_label == null:
		_build_ui()
	position = Vector2.ZERO
	size = Vector2(stage_size)
	_title_label.text = ConfigLoader.string_from(screen_config.get("title"), "Choose your lantern blessings")
	for child in _buttons_root.get_children():
		child.free()
	_option_buttons.clear()
	var button_configs: Array = ConfigLoader.array_from(screen_config.get("menu_buttons"), [])
	for index in range(button_configs.size()):
		var button: FloatingButton = FloatingButtonScene.new()
		button.configure(ConfigLoader.dictionary_from(button_configs[index]), "Option %d" % [index + 1])
		_buttons_root.add_child(button)
		_option_buttons[button] = ConfigLoader.string_from(button_configs[index].get("id"), "option_%d" % [index + 1])
	var confirm_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("confirm_button"), {})
	_confirm_button.text = ConfigLoader.string_from(confirm_config.get("label"), "Confirm")
	_confirm_button.position = ConfigLoader.vector2_from(confirm_config.get("position"), Vector2(1450, 905))
	_confirm_button.size = ConfigLoader.vector2_from(confirm_config.get("size"), Vector2(300, 110))


func reset_selection() -> void:
	for button in _option_buttons.keys():
		button.button_pressed = false


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_title_label = Label.new()
	_title_label.position = Vector2(140, 78)
	_title_label.size = Vector2(1260, 70)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color.from_string("#eef7ff", Color.WHITE))
	add_child(_title_label)
	_buttons_root = Control.new()
	_buttons_root.position = Vector2.ZERO
	add_child(_buttons_root)
	_confirm_button = Button.new()
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_confirm_button.add_theme_font_size_override("font_size", 30)
	_apply_action_button_style(_confirm_button, Color.from_string("#f3bc63", Color(0.95, 0.74, 0.39, 1.0)))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(_confirm_button)


func _on_confirm_pressed() -> void:
	var selected_ids: Array[String] = []
	for button in _option_buttons.keys():
		if button.button_pressed:
			selected_ids.append(_option_buttons[button])
	confirmed.emit(selected_ids)


func _apply_action_button_style(button: Button, color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 24
	normal.corner_radius_top_right = 24
	normal.corner_radius_bottom_right = 24
	normal.corner_radius_bottom_left = 24
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.from_string("#fff4d6", Color(1.0, 0.96, 0.84, 1.0))
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.from_string("#172233", Color(0.09, 0.13, 0.20, 1.0)))
	button.add_theme_color_override("font_hover_color", Color.from_string("#172233", Color(0.09, 0.13, 0.20, 1.0)))
	button.add_theme_color_override("font_pressed_color", Color.from_string("#172233", Color(0.09, 0.13, 0.20, 1.0)))