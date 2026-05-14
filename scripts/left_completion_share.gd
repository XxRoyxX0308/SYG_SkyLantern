extends Control

const QR_IMAGE_URL_TEMPLATE := "https://api.qrserver.com/v1/create-qr-code/?size=512x512&format=png&data=%s"

signal home_requested
signal screenshot_requested

@onready var home_button: TextureButton = $FunctionalButtons/BackToMenuButton
@onready var capture_button: TextureButton = $FunctionalButtons/CaptureButton
@onready var qr_texture_rect: TextureRect = $QRCodeDisplay/QRCodeTexture

var _qr_request: HTTPRequest = null
var _pending_qr_url := ""


func _ready() -> void:
	_qr_request = HTTPRequest.new()
	add_child(_qr_request)
	_qr_request.request_completed.connect(_on_qr_request_completed)
	home_button.pressed.connect(_on_home_pressed)
	capture_button.pressed.connect(_on_capture_pressed)
	show_qr_url("")


func show_qr_url(url: String) -> void:
	_pending_qr_url = url
	if url.is_empty():
		qr_texture_rect.texture = null
		return

	var request_error: Error = _qr_request.request(QR_IMAGE_URL_TEMPLATE % url.uri_encode())
	if request_error != OK:
		push_warning("Failed to request QR image: %s" % error_string(request_error))
		qr_texture_rect.texture = null


func _on_home_pressed() -> void:
	home_requested.emit()


func _on_capture_pressed() -> void:
	screenshot_requested.emit()


func _on_qr_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _pending_qr_url.is_empty():
		qr_texture_rect.texture = null
		return

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Failed to download QR image with result %s and response code %s." % [result, response_code])
		qr_texture_rect.texture = null
		return

	var qr_image := Image.new()
	var load_error: Error = qr_image.load_png_from_buffer(body)
	if load_error != OK:
		push_warning("Failed to parse QR PNG: %s" % error_string(load_error))
		qr_texture_rect.texture = null
		return

	qr_texture_rect.texture = ImageTexture.create_from_image(qr_image)