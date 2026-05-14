extends Control

enum AppState {
	MAIN_MENU,
	DRAWING,
	COMPLETE,
}

const LEFT_SCENES := {
	AppState.MAIN_MENU: preload("res://scenes/left_main_menu.tscn"),
	AppState.DRAWING: preload("res://scenes/left_drawing.tscn"),
	AppState.COMPLETE: preload("res://scenes/left_completion_share.tscn"),
}

@onready var left_viewport: SubViewport = $LeftScreenHost/LeftScreenViewport
@onready var right_display = $RightScreenHost/RightScreenViewport/RightDisplayShared

var current_state: int = AppState.MAIN_MENU
var current_left_scene = null
var selected_style_id := 0
var latest_drawing_texture: Texture2D = null


func _ready() -> void:
	_show_state(AppState.MAIN_MENU)


func _show_state(next_state: int) -> void:
	current_state = next_state
	if is_instance_valid(current_left_scene):
		left_viewport.remove_child(current_left_scene)
		current_left_scene.queue_free()
		current_left_scene = null

	current_left_scene = LEFT_SCENES[next_state].instantiate()
	left_viewport.add_child(current_left_scene)
	_wire_left_scene()


func _wire_left_scene() -> void:
	match current_state:
		AppState.MAIN_MENU:
			current_left_scene.confirm_requested.connect(_on_main_menu_confirm)
			current_left_scene.set_selected_style(selected_style_id)
		AppState.DRAWING:
			current_left_scene.confirm_requested.connect(_on_drawing_confirm)
			current_left_scene.reset_view()
		AppState.COMPLETE:
			current_left_scene.home_requested.connect(_on_home_requested)
			current_left_scene.screenshot_requested.connect(_on_screenshot_requested)
			current_left_scene.show_qr_url("")


func _on_main_menu_confirm(style_id: int) -> void:
	if style_id <= 0:
		return

	selected_style_id = style_id
	_show_state(AppState.DRAWING)


func _on_drawing_confirm(drawing_texture: Texture2D) -> void:
	latest_drawing_texture = drawing_texture
	right_display.spawn_lantern(drawing_texture, selected_style_id)
	_show_state(AppState.COMPLETE)


func _on_screenshot_requested() -> void:
	var screenshot_image: Image = right_display.capture_view_image()
	if screenshot_image == null:
		push_warning("Failed to capture right screen screenshot.")
		return

	var screenshot_path := _save_screenshot(screenshot_image)
	var mock_url := _mock_upload_screenshot(screenshot_path)
	current_left_scene.show_qr_url(mock_url)


func _on_home_requested() -> void:
	_reset_application()
	_show_state(AppState.MAIN_MENU)


func _reset_application() -> void:
	selected_style_id = 0
	latest_drawing_texture = null


func _save_screenshot(image: Image) -> String:
	var captures_dir := ProjectSettings.globalize_path("user://captures")
	var dir_result := DirAccess.make_dir_recursive_absolute(captures_dir)
	if dir_result != OK:
		push_warning("Failed to prepare screenshot directory: %s" % captures_dir)

	var screenshot_path := "%s/right_screen_%s.png" % [captures_dir, int(Time.get_unix_time_from_system())]
	var save_result := image.save_png(screenshot_path)
	if save_result != OK:
		push_warning("Failed to save screenshot to %s" % screenshot_path)

	return screenshot_path


func _mock_upload_screenshot(screenshot_path: String) -> String:
	var mock_url := "https://mock.syglantern.local/captures/%s" % screenshot_path.get_file()
	print("Mock upload screenshot:", screenshot_path, "=>", mock_url)
	return mock_url