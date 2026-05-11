extends Control

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const PlaceholderFactory = preload("res://scripts/core/placeholder_factory.gd")
const ShareQr = preload("res://scripts/util/share_qr.gd")

@onready var _left_container: SubViewportContainer = $LeftViewportContainer
@onready var _left_viewport: SubViewport = $LeftViewportContainer/LeftViewport
@onready var _left_stage: Node = get_node_or_null("LeftViewportContainer/LeftViewport/LeftStage")
@onready var _right_container: SubViewportContainer = $RightViewportContainer
@onready var _right_viewport: SubViewport = $RightViewportContainer/RightViewport
@onready var _right_stage: Node = get_node_or_null("RightViewportContainer/RightViewport/RightStage")

var _config: Dictionary = {}
var _selected_menu_ids: Array[String] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_config = ConfigLoader.load_installation_config()
	_apply_window_config()
	_layout_viewports()
	_resolve_stage_nodes()
	if _left_stage == null or _right_stage == null:
		push_error("Unable to resolve left/right stage nodes in installation_app.tscn.")
		return
	_connect_stage_signals()
	_left_stage.configure(ConfigLoader.dictionary_from(_config.get("left", {})), _left_viewport.size)
	_right_stage.configure(ConfigLoader.dictionary_from(_config.get("right", {})), _right_viewport.size)
	_set_flow_state("main_menu")


func _resolve_stage_nodes() -> void:
	if _left_stage == null:
		_left_stage = get_node_or_null("LeftViewport#LeftStage")
	if _right_stage == null:
		_right_stage = get_node_or_null("RightViewport#RightStage")


func _connect_stage_signals() -> void:
	if not _left_stage.main_menu_confirmed.is_connected(_on_main_menu_confirmed):
		_left_stage.main_menu_confirmed.connect(_on_main_menu_confirmed)
	if not _left_stage.drawing_confirmed.is_connected(_on_drawing_confirmed):
		_left_stage.drawing_confirmed.connect(_on_drawing_confirmed)
	if not _left_stage.screenshot_requested.is_connected(_on_screenshot_requested):
		_left_stage.screenshot_requested.connect(_on_screenshot_requested)
	if not _left_stage.back_to_main_menu_requested.is_connected(_on_back_to_main_menu_requested):
		_left_stage.back_to_main_menu_requested.connect(_on_back_to_main_menu_requested)


func _apply_window_config() -> void:
	var app_config: Dictionary = ConfigLoader.dictionary_from(_config.get("app", {}))
	var window_size: Vector2i = ConfigLoader.vector2i_from(app_config.get("window_size"), Vector2i(3840, 1080))
	get_window().size = window_size
	get_window().mode = Window.MODE_FULLSCREEN if ConfigLoader.bool_from(app_config.get("fullscreen"), false) else Window.MODE_WINDOWED
	custom_minimum_size = Vector2(window_size)


func _layout_viewports() -> void:
	var app_config: Dictionary = ConfigLoader.dictionary_from(_config.get("app", {}))
	var left_size: Vector2i = ConfigLoader.vector2i_from(app_config.get("left_resolution"), Vector2i(1920, 1080))
	var right_size: Vector2i = ConfigLoader.vector2i_from(app_config.get("right_resolution"), Vector2i(1920, 1080))
	var total_size: Vector2i = Vector2i(left_size.x + right_size.x, maxi(left_size.y, right_size.y))
	size = Vector2(total_size)
	custom_minimum_size = Vector2(total_size)
	_left_container.position = Vector2.ZERO
	_left_container.size = Vector2(left_size)
	_left_viewport.size = left_size
	_right_container.position = Vector2(left_size.x, 0)
	_right_container.size = Vector2(right_size)
	_right_viewport.size = right_size


func _set_flow_state(state_name: String) -> void:
	_left_stage.set_flow_state(state_name)


func _on_main_menu_confirmed(selected_ids: Array) -> void:
	_selected_menu_ids = selected_ids.duplicate(true)
	_set_flow_state("drawing")


func _on_drawing_confirmed(drawing_image: Image) -> void:
	var lantern_texture: Texture2D = PlaceholderFactory.compose_user_lantern(drawing_image)
	_right_stage.add_user_lantern(lantern_texture)
	_left_stage.prepare_completion(_selected_menu_ids)
	_set_flow_state("completion")


func _on_screenshot_requested() -> void:
	var capture_result: Dictionary = await _capture_right_screen()
	_left_stage.show_share_result(capture_result)


func _on_back_to_main_menu_requested() -> void:
	_left_stage.reset_flow()
	_set_flow_state("main_menu")


func _capture_right_screen() -> Dictionary:
	await RenderingServer.frame_post_draw
	var sharing: Dictionary = ConfigLoader.dictionary_from(_config.get("sharing", {}))
	var captures_dir: String = ConfigLoader.string_from(sharing.get("captures_dir"), "user://captures")
	var manifest_path: String = ConfigLoader.string_from(sharing.get("manifest_file"), captures_dir.path_join("index.json"))
	_ensure_directory(captures_dir)
	var manifest: Dictionary = _read_manifest(manifest_path)
	var token: String = _build_share_token(ConfigLoader.int_from(sharing.get("id_length"), 6))
	while manifest.has(token):
		token = _build_share_token(ConfigLoader.int_from(sharing.get("id_length"), 6))
	var user_path: String = captures_dir.path_join("%s.png" % token)
	var capture_image: Image = _right_viewport.get_texture().get_image()
	var save_error: int = capture_image.save_png(user_path)
	if save_error != OK:
		return {
			"error": "Unable to save the screenshot from the right screen.",
			"payload": "",
			"path": "",
			"qr_texture": null
		}
	var payload: String = "%s%s" % [ConfigLoader.string_from(sharing.get("link_prefix"), "sc://"), token]
	manifest[token] = {
		"payload": payload,
		"path": ProjectSettings.globalize_path(user_path),
		"selected_ids": _selected_menu_ids,
		"captured_at": Time.get_datetime_string_from_system()
	}
	_write_manifest(manifest_path, manifest)
	var qr_result: Dictionary = ShareQr.make_texture(payload, Vector2i(360, 360))
	return {
		"error": ConfigLoader.string_from(qr_result.get("error"), ""),
		"payload": payload,
		"path": ProjectSettings.globalize_path(user_path),
		"qr_texture": qr_result.get("texture")
	}


func _build_share_token(length: int) -> String:
	var safe_length: int = clampi(length, 4, 8)
	var alphabet: String = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var token: String = ""
	for _index in range(safe_length):
		token += alphabet[_rng.randi_range(0, alphabet.length() - 1)]
	return token


func _ensure_directory(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))


func _read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	if not (parser.data is Dictionary):
		return {}
	return parser.data


func _write_manifest(path: String, manifest: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(manifest))