extends Control
class_name DrawingScreen

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const DrawingBoardScene = preload("res://scripts/left/drawing_board.gd")

signal confirmed(drawing_image)

var _title_label: Label
var _drawing_board: DrawingBoard
var _confirm_button: Button
var _clear_button: Button
var _status_label: Label


func configure(screen_config: Dictionary, stage_size: Vector2i) -> void:
	if _title_label == null:
		_build_ui()
	position = Vector2.ZERO
	size = Vector2(stage_size)
	_title_label.text = ConfigLoader.string_from(screen_config.get("title"), "Draw your lantern wish")
	_drawing_board.configure(ConfigLoader.dictionary_from(screen_config.get("board", {})))
	var confirm_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("confirm_button", {}))
	_confirm_button.text = ConfigLoader.string_from(confirm_config.get("label"), "Confirm")
	_confirm_button.position = ConfigLoader.vector2_from(confirm_config.get("position"), Vector2(1450, 890))
	_confirm_button.size = ConfigLoader.vector2_from(confirm_config.get("size"), Vector2(300, 110))
	var clear_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("clear_button", {}))
	_clear_button.text = ConfigLoader.string_from(clear_config.get("label"), "Clear")
	_clear_button.position = ConfigLoader.vector2_from(clear_config.get("position"), Vector2(1110, 890))
	_clear_button.size = ConfigLoader.vector2_from(clear_config.get("size"), Vector2(260, 110))
	_status_label.text = ""


func reset_canvas() -> void:
	_drawing_board.clear_canvas()
	_status_label.text = ""


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_title_label = Label.new()
	_title_label.position = Vector2(140, 78)
	_title_label.size = Vector2(1260, 70)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color.from_string("#eef7ff", Color.WHITE))
	add_child(_title_label)
	_drawing_board = DrawingBoardScene.new()
	add_child(_drawing_board)
	_confirm_button = Button.new()
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_confirm_button.add_theme_font_size_override("font_size", 30)
	_apply_action_button_style(_confirm_button, Color.from_string("#f3bc63", Color(0.95, 0.74, 0.39, 1.0)))
	_confirm_button.pressed.connect(_on_confirm_pressed)
	add_child(_confirm_button)
	_clear_button = Button.new()
	_clear_button.focus_mode = Control.FOCUS_NONE
	_clear_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_clear_button.add_theme_font_size_override("font_size", 30)
	_apply_action_button_style(_clear_button, Color.from_string("#86c8ff", Color(0.53, 0.78, 1.0, 1.0)))
	_clear_button.pressed.connect(_on_clear_pressed)
	add_child(_clear_button)
	_status_label = Label.new()
	_status_label.position = Vector2(140, 900)
	_status_label.size = Vector2(900, 60)
	_status_label.add_theme_font_size_override("font_size", 24)
	_status_label.add_theme_color_override("font_color", Color.from_string("#f7dfb3", Color(0.97, 0.87, 0.70, 1.0)))
	add_child(_status_label)


func _on_confirm_pressed() -> void:
	if not _drawing_board.has_content():
		_status_label.text = "Draw something on the board before confirming."
		return
	_status_label.text = ""
	confirmed.emit(_drawing_board.get_output_image())


func _on_clear_pressed() -> void:
	_drawing_board.clear_canvas()
	_status_label.text = ""


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
	normal.border_color = Color.from_string("#eef8ff", Color.WHITE)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.08)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = color.darkened(0.12)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color.from_string("#152234", Color(0.08, 0.13, 0.20, 1.0)))
	button.add_theme_color_override("font_hover_color", Color.from_string("#152234", Color(0.08, 0.13, 0.20, 1.0)))
	button.add_theme_color_override("font_pressed_color", Color.from_string("#152234", Color(0.08, 0.13, 0.20, 1.0)))