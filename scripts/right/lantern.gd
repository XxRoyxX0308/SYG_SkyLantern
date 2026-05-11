extends Node2D
class_name Lantern

const ConfigLoader = preload("res://scripts/core/config_loader.gd")

var _sprite: Sprite2D
var _viewport_size: Vector2 = Vector2.ZERO
var _anchor_position: Vector2 = Vector2.ZERO
var _drift_velocity: Vector2 = Vector2.ZERO
var _oscillation_amplitude: Vector2 = Vector2.ZERO
var _oscillation_speed: float = 1.0
var _phase: float = 0.0
var _elapsed: float = 0.0
var _travel: Vector2 = Vector2.ZERO
var _margin: float = 220.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	_rng.randomize()


func configure(texture: Texture2D, viewport_size: Vector2i, lantern_config: Dictionary) -> void:
	if _sprite == null:
		_ready()
	_sprite.texture = texture
	_viewport_size = Vector2(viewport_size)
	_anchor_position = ConfigLoader.vector2_from(lantern_config.get("start_position"), _viewport_size / 2.0)
	_drift_velocity = ConfigLoader.vector2_from(lantern_config.get("drift_velocity"), Vector2(18.0, -10.0))
	_oscillation_amplitude = ConfigLoader.vector2_from(lantern_config.get("oscillation_amplitude"), Vector2(30.0, 18.0))
	_oscillation_speed = ConfigLoader.float_from(lantern_config.get("oscillation_speed"), 0.9)
	_phase = ConfigLoader.float_from(lantern_config.get("phase"), randf() * TAU)
	_travel = Vector2.ZERO
	_elapsed = 0.0
	position = _anchor_position
	_sprite.modulate = ConfigLoader.color_from(lantern_config.get("tint"), Color.WHITE)


func set_display_depth(rank: int, total: int, min_scale: float, max_scale: float) -> void:
	var factor: float = 1.0 if total <= 1 else float(rank) / float(total - 1)
	var display_scale: float = lerpf(min_scale, max_scale, factor)
	scale = Vector2.ONE * display_scale
	z_index = rank


func _process(delta: float) -> void:
	_elapsed += delta
	_travel += _drift_velocity * delta
	_wrap_if_needed()
	var oscillation: Vector2 = Vector2(
		sin(_phase + _elapsed * _oscillation_speed) * _oscillation_amplitude.x,
		cos(_phase * 0.7 + _elapsed * _oscillation_speed * 1.15) * _oscillation_amplitude.y
	)
	position = _anchor_position + _travel + oscillation


func _wrap_if_needed() -> void:
	var base_position: Vector2 = _anchor_position + _travel
	var wrapped: bool = false
	if _drift_velocity.x >= 0.0 and base_position.x > _viewport_size.x + _margin:
		_anchor_position.x = -_margin
		_travel.x = 0.0
		wrapped = true
	elif _drift_velocity.x < 0.0 and base_position.x < -_margin:
		_anchor_position.x = _viewport_size.x + _margin
		_travel.x = 0.0
		wrapped = true
	if _drift_velocity.y >= 0.0 and base_position.y > _viewport_size.y + _margin:
		_anchor_position.y = -_margin
		_travel.y = 0.0
		wrapped = true
	elif _drift_velocity.y < 0.0 and base_position.y < -_margin:
		_anchor_position.y = _viewport_size.y + _margin
		_travel.y = 0.0
		wrapped = true
	if wrapped:
		_anchor_position.y = clampf(_anchor_position.y + _rng.randf_range(-140.0, 140.0), -_margin, _viewport_size.y + _margin)