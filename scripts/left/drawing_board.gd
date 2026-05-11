extends Control
class_name DrawingBoard

const ConfigLoader = preload("res://scripts/core/config_loader.gd")

signal drawing_changed(has_content)

var board_background_color: Color = Color.from_string("#10263f", Color(0.06, 0.15, 0.25, 1.0))
var border_color: Color = Color.from_string("#84c9ff", Color(0.52, 0.79, 1.0, 1.0))
var stroke_color: Color = Color.from_string("#fff4dd", Color.WHITE)
var line_width: int = 8

var _canvas_image: Image
var _canvas_texture: Texture2D
var _last_point: Vector2 = Vector2.ZERO
var _is_drawing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_canvas()


func configure(board_config: Dictionary) -> void:
	position = ConfigLoader.vector2_from(board_config.get("position"), Vector2(140, 170))
	size = ConfigLoader.vector2_from(board_config.get("size"), Vector2(1120, 700))
	custom_minimum_size = size
	board_background_color = ConfigLoader.color_from(board_config.get("background_color"), board_background_color)
	border_color = ConfigLoader.color_from(board_config.get("border_color"), border_color)
	stroke_color = ConfigLoader.color_from(board_config.get("line_color"), stroke_color)
	line_width = maxi(1, ConfigLoader.int_from(board_config.get("line_width"), line_width))
	_ensure_canvas()
	clear_canvas()


func clear_canvas() -> void:
	_ensure_canvas()
	_canvas_image.fill(Color(1.0, 1.0, 1.0, 0.0))
	_update_texture()
	queue_redraw()
	drawing_changed.emit(false)


func has_content() -> bool:
	return not _canvas_image.is_invisible()


func get_output_image() -> Image:
	return _canvas_image.duplicate()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_is_drawing = true
			_last_point = touch_event.position
			_stamp_at(_last_point)
			accept_event()
		else:
			_is_drawing = false
	elif event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event
		if _is_drawing:
			_draw_segment(_last_point, drag_event.position)
			_last_point = drag_event.position
			accept_event()
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				_is_drawing = true
				_last_point = button_event.position
				_stamp_at(_last_point)
			else:
				_is_drawing = false
			accept_event()
	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if _is_drawing and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_draw_segment(_last_point, motion_event.position)
			_last_point = motion_event.position
			accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), board_background_color, true)
	if _canvas_texture != null:
		draw_texture_rect(_canvas_texture, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 6.0)


func _ensure_canvas() -> void:
	var canvas_size: Vector2i = Vector2i(maxi(1, int(round(size.x))), maxi(1, int(round(size.y))))
	if _canvas_image == null or _canvas_image.get_size() != canvas_size:
		_canvas_image = Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
		_canvas_image.fill(Color(1.0, 1.0, 1.0, 0.0))
		_update_texture()


func _draw_segment(start_point: Vector2, end_point: Vector2) -> void:
	var distance: float = start_point.distance_to(end_point)
	var steps: int = maxi(int(distance / maxf(float(line_width) * 0.35, 1.0)), 1)
	for index in range(steps + 1):
		var point: Vector2 = start_point.lerp(end_point, float(index) / float(steps))
		_stamp_at(point)


func _stamp_at(point: Vector2) -> void:
	var radius: int = maxi(1, int(round(float(line_width) * 0.5)))
	var center: Vector2i = Vector2i(int(round(point.x)), int(round(point.y)))
	for y_offset in range(-radius, radius + 1):
		for x_offset in range(-radius, radius + 1):
			if x_offset * x_offset + y_offset * y_offset > radius * radius:
				continue
			var pixel: Vector2i = center + Vector2i(x_offset, y_offset)
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= _canvas_image.get_width() or pixel.y >= _canvas_image.get_height():
				continue
			_canvas_image.set_pixelv(pixel, stroke_color)
	_update_texture()
	queue_redraw()
	drawing_changed.emit(has_content())


func _update_texture() -> void:
	_canvas_texture = ImageTexture.create_from_image(_canvas_image)