extends Node2D
class_name BackgroundCarousel

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const PlaceholderFactory = preload("res://scripts/core/placeholder_factory.gd")

var _stage_size: Vector2i = Vector2i(1920, 1080)
var _sprite_a: Sprite2D
var _sprite_b: Sprite2D
var _textures: Array[Texture2D] = []
var _current_index: int = 0
var _using_sprite_a: bool = true
var _hold_seconds: float = 5.0
var _transition_seconds: float = 1.2
var _generation: int = 0


func configure(carousel_config: Dictionary, stage_size: Vector2i) -> void:
	_stage_size = stage_size
	if _sprite_a == null:
		_build_scene()
	_textures.clear()
	var paths: Array = ConfigLoader.array_from(carousel_config.get("paths"), [])
	for path in paths:
		var texture: Texture2D = PlaceholderFactory.load_texture(ConfigLoader.string_from(path), null)
		if texture != null:
			_textures.append(texture)
	if _textures.is_empty():
		for index in range(3):
			_textures.append(PlaceholderFactory.make_background_texture(stage_size, index))
	_hold_seconds = ConfigLoader.float_from(carousel_config.get("hold_seconds"), 5.0)
	_transition_seconds = ConfigLoader.float_from(carousel_config.get("transition_seconds"), 1.2)
	_current_index = 0
	_using_sprite_a = true
	_set_sprite_texture(_sprite_a, _textures[0])
	_sprite_a.modulate = Color.WHITE
	_set_sprite_texture(_sprite_b, _textures[mini(1, _textures.size() - 1)])
	_sprite_b.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_generation += 1
	call_deferred("_run_loop", _generation)


func _build_scene() -> void:
	_sprite_a = Sprite2D.new()
	_sprite_a.centered = true
	_sprite_a.z_index = -10
	add_child(_sprite_a)
	_sprite_b = Sprite2D.new()
	_sprite_b.centered = true
	_sprite_b.z_index = -9
	add_child(_sprite_b)


func _run_loop(generation: int) -> void:
	if _textures.size() < 2:
		return
	while is_inside_tree() and generation == _generation:
		await get_tree().create_timer(_hold_seconds).timeout
		if not is_inside_tree() or generation != _generation:
			return
		_advance()
		await get_tree().create_timer(_transition_seconds).timeout


func _advance() -> void:
	if _textures.size() < 2:
		return
	_current_index = (_current_index + 1) % _textures.size()
	var current_sprite: Sprite2D = _sprite_a if _using_sprite_a else _sprite_b
	var next_sprite: Sprite2D = _sprite_b if _using_sprite_a else _sprite_a
	_set_sprite_texture(next_sprite, _textures[_current_index])
	next_sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(current_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.0), _transition_seconds)
	tween.tween_property(next_sprite, "modulate", Color.WHITE, _transition_seconds)
	_using_sprite_a = not _using_sprite_a


func _set_sprite_texture(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.position = Vector2(_stage_size) / 2.0
	if texture == null:
		sprite.scale = Vector2.ONE
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		sprite.scale = Vector2.ONE
		return
	sprite.scale = Vector2(float(_stage_size.x) / texture_size.x, float(_stage_size.y) / texture_size.y)