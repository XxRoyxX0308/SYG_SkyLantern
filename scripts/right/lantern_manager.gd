extends Node2D
class_name LanternManager

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const PlaceholderFactory = preload("res://scripts/core/placeholder_factory.gd")
const LanternScene = preload("res://scripts/right/lantern.gd")

var _stage_size := Vector2i(1920, 1080)
var _settings := {}
var _default_texture: Texture2D
var _rng := RandomNumberGenerator.new()


func configure(settings: Dictionary, stage_size: Vector2i) -> void:
	_settings = settings
	_stage_size = stage_size
	_rng.randomize()
	for child in get_children():
		child.free()
	_default_texture = PlaceholderFactory.load_texture(
		ConfigLoader.string_from(settings.get("default_texture_path"), ""),
		PlaceholderFactory.make_lantern_texture()
	)
	var count := max(0, ConfigLoader.int_from(settings.get("count"), 12))
	for _index in range(count):
		add_child(_create_lantern(_default_texture, false))
	_refresh_depths()


func add_user_lantern(texture: Texture2D) -> void:
	var lantern_texture := texture if texture != null else PlaceholderFactory.make_lantern_texture()
	add_child(_create_lantern(lantern_texture, true))
	_refresh_depths()


func _create_lantern(texture: Texture2D, is_user_generated: bool) -> Lantern:
	var lantern := LanternScene.new()
	var drift_direction := ConfigLoader.vector2_from(_settings.get("drift_direction"), Vector2(12.0, -8.0))
	if drift_direction == Vector2.ZERO:
		drift_direction = Vector2(12.0, -8.0)
	drift_direction = drift_direction.normalized()
	var speed_range := ConfigLoader.vector2_from(_settings.get("drift_speed_range"), Vector2(16.0, 40.0))
	var speed := _rng.randf_range(speed_range.x, speed_range.y)
	var oscillation_range := ConfigLoader.vector2_from(_settings.get("oscillation_speed_range"), Vector2(0.5, 1.2))
	var amplitude := ConfigLoader.vector2_from(_settings.get("oscillation_amplitude"), Vector2(30.0, 18.0))
	var start_position := Vector2(
		_rng.randf_range(100.0, _stage_size.x - 100.0),
		_rng.randf_range(180.0, _stage_size.y - 120.0)
	)
	if is_user_generated:
		start_position = Vector2(_stage_size.x * 0.52, _stage_size.y * 0.78)
		if speed < speed_range.y:
			speed = speed_range.y
	var tint := Color(
		1.0,
		_rng.randf_range(0.78, 0.92),
		_rng.randf_range(0.58, 0.76),
		_rng.randf_range(0.84, 0.98)
	)
	lantern.configure(texture, _stage_size, {
		"start_position": start_position,
		"drift_velocity": drift_direction * speed,
		"oscillation_amplitude": amplitude * _rng.randf_range(0.8, 1.2),
		"oscillation_speed": _rng.randf_range(oscillation_range.x, oscillation_range.y),
		"phase": _rng.randf() * TAU,
		"tint": tint if not is_user_generated else Color.WHITE
	})
	return lantern


func _refresh_depths() -> void:
	var lanterns := []
	for child in get_children():
		if child is Lantern:
			lanterns.append(child)
	var min_scale := ConfigLoader.float_from(_settings.get("min_scale"), 0.45)
	var max_scale := ConfigLoader.float_from(_settings.get("max_scale"), 1.1)
	for index in range(lanterns.size()):
		lanterns[index].set_display_depth(index, lanterns.size(), min_scale, max_scale)