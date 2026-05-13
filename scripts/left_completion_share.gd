extends Control

const QR_GRID_SIZE := 29
const QR_CELL_SIZE := 14

signal home_requested
signal screenshot_requested

@onready var home_button: TextureButton = $FunctionalButtons/BackToMenuButton
@onready var capture_button: TextureButton = $FunctionalButtons/CaptureButton
@onready var qr_texture_rect: TextureRect = $QRCodeDisplay/QRCodeTexture


func _ready() -> void:
	home_button.pressed.connect(_on_home_pressed)
	capture_button.pressed.connect(_on_capture_pressed)
	show_qr_url("")


func show_qr_url(url: String) -> void:
	if url.is_empty():
		qr_texture_rect.texture = null
		return

	print("Mock QR URL:", url)
	qr_texture_rect.texture = _build_qr_texture(url)


func _on_home_pressed() -> void:
	home_requested.emit()


func _on_capture_pressed() -> void:
	screenshot_requested.emit()


func _build_qr_texture(url: String) -> Texture2D:
	var image_size: int = QR_GRID_SIZE * QR_CELL_SIZE
	var image := Image.create(image_size, image_size, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	_draw_finder_pattern(image, Vector2i(0, 0))
	_draw_finder_pattern(image, Vector2i(QR_GRID_SIZE - 7, 0))
	_draw_finder_pattern(image, Vector2i(0, QR_GRID_SIZE - 7))

	var seed: int = abs(url.hash())
	for y in range(QR_GRID_SIZE):
		for x in range(QR_GRID_SIZE):
			if _is_finder_cell(x, y):
				continue
			seed = int((seed * 1103515245 + 12345) & 0x7fffffff)
			if seed % 3 == 0:
				_fill_cell(image, x, y, Color.BLACK)

	return ImageTexture.create_from_image(image)


func _draw_finder_pattern(image: Image, origin: Vector2i) -> void:
	for y in range(7):
		for x in range(7):
			var is_border := x == 0 or x == 6 or y == 0 or y == 6
			var is_center := x >= 2 and x <= 4 and y >= 2 and y <= 4
			if is_border or is_center:
				_fill_cell(image, origin.x + x, origin.y + y, Color.BLACK)


func _is_finder_cell(x: int, y: int) -> bool:
	return (x < 7 and y < 7) \
		or (x >= QR_GRID_SIZE - 7 and y < 7) \
		or (x < 7 and y >= QR_GRID_SIZE - 7)


func _fill_cell(image: Image, cell_x: int, cell_y: int, color: Color) -> void:
	var start_x := cell_x * QR_CELL_SIZE
	var start_y := cell_y * QR_CELL_SIZE
	for y in range(start_y, start_y + QR_CELL_SIZE):
		for x in range(start_x, start_x + QR_CELL_SIZE):
			image.set_pixel(x, y, color)