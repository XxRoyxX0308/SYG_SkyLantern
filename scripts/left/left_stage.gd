extends Node2D

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const SequenceAnimatorScene = preload("res://scripts/left/sequence_animator.gd")
const MainMenuScreenScene = preload("res://scripts/left/main_menu_screen.gd")
const DrawingScreenScene = preload("res://scripts/left/drawing_screen.gd")
const CompletionScreenScene = preload("res://scripts/left/completion_screen.gd")

signal main_menu_confirmed(selected_ids)
signal drawing_confirmed(drawing_image)
signal screenshot_requested
signal back_to_main_menu_requested

var _config: Dictionary = {}
var _stage_size: Vector2i = Vector2i(1920, 1080)
var _character: SequenceAnimator
var _canvas_layer: CanvasLayer
var _background: ColorRect
var _main_menu_screen: MainMenuScreen
var _drawing_screen: DrawingScreen
var _completion_screen: CompletionScreen


func configure(left_config: Dictionary, stage_size: Vector2i) -> void:
	_config = left_config
	_stage_size = stage_size
	if _canvas_layer == null:
		_build_scene()
	_background.color = ConfigLoader.color_from(left_config.get("background_color"), Color.from_string("#0f1d34", Color(0.06, 0.11, 0.20, 1.0)))
	_background.size = Vector2(stage_size)
	_main_menu_screen.configure(ConfigLoader.dictionary_from(left_config.get("main_menu", {})), stage_size)
	_drawing_screen.configure(ConfigLoader.dictionary_from(left_config.get("drawing", {})), stage_size)
	_completion_screen.configure(ConfigLoader.dictionary_from(left_config.get("completion", {})), stage_size)
	_apply_character_config("main_menu")


func set_flow_state(state_name: String) -> void:
	_main_menu_screen.visible = state_name == "main_menu"
	_drawing_screen.visible = state_name == "drawing"
	_completion_screen.visible = state_name == "completion"
	_apply_character_config(state_name)


func prepare_completion(selected_ids: Array) -> void:
	_completion_screen.set_summary(selected_ids)
	_completion_screen.clear_share_result()


func show_share_result(result: Dictionary) -> void:
	_completion_screen.show_share_result(result)


func reset_flow() -> void:
	_main_menu_screen.reset_selection()
	_drawing_screen.reset_canvas()
	_completion_screen.set_summary([])
	_completion_screen.clear_share_result()


func _build_scene() -> void:
	_character = SequenceAnimatorScene.new()
	add_child(_character)
	_canvas_layer = CanvasLayer.new()
	add_child(_canvas_layer)
	_background = ColorRect.new()
	_background.position = Vector2.ZERO
	_canvas_layer.add_child(_background)
	_main_menu_screen = MainMenuScreenScene.new()
	_canvas_layer.add_child(_main_menu_screen)
	_main_menu_screen.confirmed.connect(func(selected_ids: Array) -> void:
		main_menu_confirmed.emit(selected_ids)
	)
	_drawing_screen = DrawingScreenScene.new()
	_canvas_layer.add_child(_drawing_screen)
	_drawing_screen.confirmed.connect(func(drawing_image: Image) -> void:
		drawing_confirmed.emit(drawing_image)
	)
	_completion_screen = CompletionScreenScene.new()
	_canvas_layer.add_child(_completion_screen)
	_completion_screen.screenshot_requested.connect(func() -> void:
		screenshot_requested.emit()
	)
	_completion_screen.back_requested.connect(func() -> void:
		back_to_main_menu_requested.emit()
	)


func _apply_character_config(state_name: String) -> void:
	var screen_config: Dictionary = ConfigLoader.dictionary_from(_config.get(state_name, {}))
	var character_config: Dictionary = ConfigLoader.dictionary_from(screen_config.get("character", {}))
	if character_config.is_empty() and state_name == "completion":
		_character.visible = false
		return
	if character_config.is_empty():
		character_config = {
			"position": [1510, 710],
			"scale": [1.0, 1.0],
			"fps": 3.0,
			"frames": []
		}
	_character.apply_config(character_config)