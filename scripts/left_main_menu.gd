extends Control

class LanternOptionData:
	var style_id := 1
	var button_center: Control
	var button: TextureButton
	var animation_player: AnimationPlayer


signal confirm_requested(style_id: int)

@onready var menu_buttons_grid: GridContainer = $MenuButtonsContainer/MenuButtonsGrid
@onready var confirm_button: TextureButton = $ConfirmButton
@onready var character_sprite: AnimatedSprite2D = $CharacterAnimation/CharacterSprite

var _lantern_options: Array = []
var _selected_style_id := 0


func _ready() -> void:
	_lantern_options = _collect_lantern_options()
	for option in _lantern_options:
		option.button.pressed.connect(_on_lantern_pressed.bind(option.style_id))

	confirm_button.pressed.connect(_on_confirm_pressed)
	character_sprite.play("idle")
	set_selected_style(_selected_style_id)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_handle_pointer_press(mouse_event.position)
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_handle_pointer_press(touch_event.position)


func set_selected_style(style_id: int) -> void:
	if _lantern_options.is_empty():
		_selected_style_id = maxi(style_id, 0)
		_update_confirm_button_visibility()
		return

	if style_id <= 0:
		_selected_style_id = 0
	else:
		_selected_style_id = clampi(style_id, 1, _lantern_options.size())

	for option in _lantern_options:
		var is_selected: bool = option.style_id == _selected_style_id
		option.button.set_pressed_no_signal(is_selected)
		_set_option_active(option, is_selected)

	_update_confirm_button_visibility()


func _collect_lantern_options() -> Array:
	var options: Array = []
	var style_id := 1
	for child in menu_buttons_grid.get_children():
		var option_root := child as Control
		if option_root == null:
			continue

		var option := LanternOptionData.new()
		option.style_id = style_id
		option.button_center = option_root.get_node("ButtonCenter") as Control
		option.button = option_root.get_node("ButtonCenter/Button") as TextureButton
		option.animation_player = option_root.get_node("FloatingPlayer") as AnimationPlayer
		options.append(option)
		style_id += 1

	return options


func _on_lantern_pressed(style_id: int) -> void:
	set_selected_style(style_id)


func _on_confirm_pressed() -> void:
	if _selected_style_id <= 0:
		return

	confirm_requested.emit(_selected_style_id)


func _set_option_active(option: LanternOptionData, is_selected: bool) -> void:
	if is_selected:
		option.animation_player.play("selected")
		return

	option.animation_player.stop()
	option.button_center.rotation = 0.0


func _handle_pointer_press(pointer_position: Vector2) -> void:
	if _is_pointer_over_lantern_button(pointer_position):
		return

	if confirm_button.visible and confirm_button.get_global_rect().has_point(pointer_position):
		return

	set_selected_style(0)


func _is_pointer_over_lantern_button(pointer_position: Vector2) -> bool:
	for option in _lantern_options:
		if option.button.get_global_rect().has_point(pointer_position):
			return true

	return false


func _update_confirm_button_visibility() -> void:
	var has_selection: bool = _selected_style_id > 0
	confirm_button.visible = has_selection
	confirm_button.disabled = not has_selection