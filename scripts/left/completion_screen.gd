extends Control
class_name CompletionScreen

const ConfigLoader = preload("res://scripts/core/config_loader.gd")

signal back_requested
signal screenshot_requested

var _title_label: Label
var _summary_label: Label
var _back_button: Button
var _screenshot_button: Button
var _qr_rect: TextureRect
var _caption_label: Label
var _status_label: Label
var _link_label: Label


func configure(screen_config: Dictionary, stage_size: Vector2i) -> void:
	if _title_label == null:
		_build_ui()
	position = Vector2.ZERO
	size = Vector2(stage_size)
	_title_label.text = ConfigLoader.string_from(screen_config.get("title"), "Share your lantern")
	var back_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("back_button", {}))
	_back_button.text = ConfigLoader.string_from(back_config.get("label"), "Back to Main Menu")
	_back_button.position = ConfigLoader.vector2_from(back_config.get("position"), Vector2(140, 890))
	_back_button.size = ConfigLoader.vector2_from(back_config.get("size"), Vector2(360, 110))
	var screenshot_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("screenshot_button", {}))
	_screenshot_button.text = ConfigLoader.string_from(screenshot_config.get("label"), "Screenshot")
	_screenshot_button.position = ConfigLoader.vector2_from(screenshot_config.get("position"), Vector2(540, 890))
	_screenshot_button.size = ConfigLoader.vector2_from(screenshot_config.get("size"), Vector2(300, 110))
	var qr_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("qr_display", {}))
	_qr_rect.position = ConfigLoader.vector2_from(qr_config.get("position"), Vector2(1280, 240))
	_qr_rect.size = ConfigLoader.vector2_from(qr_config.get("size"), Vector2(360, 360))
	_caption_label.text = ConfigLoader.string_from(qr_config.get("caption"), "Scan after saving the right screen")
	_caption_label.position = _qr_rect.position + Vector2(0, _qr_rect.size.y + 18)
	_caption_label.size = Vector2(_qr_rect.size.x, 50)
	_link_label.position = _qr_rect.position + Vector2(0, _qr_rect.size.y + 74)
	_link_label.size = Vector2(_qr_rect.size.x, 66)
	clear_share_result()


func set_summary(selected_ids: Array) -> void:
	if selected_ids.is_empty():
		_summary_label.text = "Your new lantern is now floating on the right screen."
		return
	var labels: Array[String] = []
	for selected_id in selected_ids:
		labels.append(str(selected_id).capitalize())
	_summary_label.text = "Selections: %s" % ", ".join(labels)


func clear_share_result() -> void:
	_qr_rect.texture = null
	_status_label.text = "Press Screenshot to save the right screen and generate a QR code."
	_link_label.text = ""


func show_share_result(result: Dictionary) -> void:
	_qr_rect.texture = result.get("qr_texture")
	_link_label.text = ConfigLoader.string_from(result.get("payload"), "")
	var saved_path: String = ConfigLoader.string_from(result.get("path"), "")
	var error_message: String = ConfigLoader.string_from(result.get("error"), "")
	if not error_message.is_empty():
		_status_label.text = "%s Saved: %s" % [error_message, saved_path]
	else:
		_status_label.text = "Saved to %s" % saved_path


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_title_label = Label.new()
	_title_label.position = Vector2(140, 78)
	_title_label.size = Vector2(1000, 70)
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color.from_string("#eef7ff", Color.WHITE))
	add_child(_title_label)
	_summary_label = Label.new()
	_summary_label.position = Vector2(140, 140)
	_summary_label.size = Vector2(1040, 70)
	_summary_label.add_theme_font_size_override("font_size", 24)
	_summary_label.add_theme_color_override("font_color", Color.from_string("#d7ebff", Color(0.84, 0.92, 1.0, 1.0)))
	add_child(_summary_label)
	_back_button = Button.new()
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_back_button.add_theme_font_size_override("font_size", 28)
	_apply_action_button_style(_back_button, Color.from_string("#86c8ff", Color(0.53, 0.78, 1.0, 1.0)))
	_back_button.pressed.connect(func() -> void:
		back_requested.emit()
	)
	add_child(_back_button)
	_screenshot_button = Button.new()
	_screenshot_button.focus_mode = Control.FOCUS_NONE
	_screenshot_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_screenshot_button.add_theme_font_size_override("font_size", 28)
	_apply_action_button_style(_screenshot_button, Color.from_string("#f3bc63", Color(0.95, 0.74, 0.39, 1.0)))
	_screenshot_button.pressed.connect(func() -> void:
		screenshot_requested.emit()
	)
	add_child(_screenshot_button)
	_qr_rect = TextureRect.new()
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_qr_rect)
	_caption_label = Label.new()
	_caption_label.add_theme_font_size_override("font_size", 20)
	_caption_label.add_theme_color_override("font_color", Color.from_string("#d7ebff", Color(0.84, 0.92, 1.0, 1.0)))
	add_child(_caption_label)
	_link_label = Label.new()
	_link_label.add_theme_font_size_override("font_size", 18)
	_link_label.add_theme_color_override("font_color", Color.from_string("#f6dcab", Color(0.96, 0.86, 0.67, 1.0)))
	add_child(_link_label)
	_status_label = Label.new()
	_status_label.position = Vector2(140, 820)
	_status_label.size = Vector2(1520, 52)
	_status_label.add_theme_font_size_override("font_size", 22)
	_status_label.add_theme_color_override("font_color", Color.from_string("#f6dcab", Color(0.96, 0.86, 0.67, 1.0)))
	add_child(_status_label)


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