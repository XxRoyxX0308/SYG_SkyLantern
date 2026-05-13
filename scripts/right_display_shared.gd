extends Control

class LanternEntry:
	var root: Node2D
	var base_x := 0.0
	var base_y := 0.0
	var speed := 0.0
	var amplitude := 0.0
	var frequency := 0.0
	var phase := 0.0
	var age := 0.0
	var order := 0


const STYLE_TEXTURES := [
	preload("res://assets/lanterns/lantern_01.png"),
	preload("res://assets/lanterns/lantern_02.png"),
	preload("res://assets/lanterns/lantern_03.png"),
	preload("res://assets/lanterns/lantern_04.png"),
	preload("res://assets/lanterns/lantern_05.png"),
	preload("res://assets/lanterns/lantern_06.png"),
	preload("res://assets/lanterns/lantern_07.png"),
	preload("res://assets/lanterns/lantern_08.png"),
]

const OFFSCREEN_MARGIN := 260.0
const OVERLAY_WIDTH_RATIO := 0.42
const OVERLAY_HEIGHT_RATIO := 0.34

@export var max_lanterns := 8
@export var min_vertical_speed := 28.0
@export var max_vertical_speed := 48.0
@export var min_amplitude := 24.0
@export var max_amplitude := 88.0
@export var min_frequency := 0.55
@export var max_frequency := 1.35
@export var newest_scale := 0.95
@export var oldest_scale := 0.55
@export var oldest_alpha := 0.32

@onready var history_container: Node2D = $SkyLanternsContainer/HistoryLanterns
@onready var latest_container: Node2D = $SkyLanternsContainer/LatestLanterns
@onready var drift_origin: Marker2D = $SkyLanternsContainer/DriftOrigin
@onready var latest_front_anchor: Marker2D = $SkyLanternsContainer/LatestFrontAnchor

var _lanterns: Array = []
var _rng := RandomNumberGenerator.new()
var _spawn_counter := 0


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	var needs_refresh := false
	for index in range(_lanterns.size() - 1, -1, -1):
		var entry: LanternEntry = _lanterns[index]
		if not is_instance_valid(entry.root):
			_lanterns.remove_at(index)
			needs_refresh = true
			continue

		entry.age += delta
		entry.base_y -= entry.speed * delta
		if index == _lanterns.size() - 1:
			entry.base_x = lerp(entry.base_x, latest_front_anchor.position.x, 0.015)

		entry.root.position = Vector2(
			entry.base_x + sin(entry.age * entry.frequency + entry.phase) * entry.amplitude,
			entry.base_y
		)
		_apply_entry_visuals(entry, index)

		if entry.base_y < -OFFSCREEN_MARGIN:
			_remove_lantern_at(index)
			needs_refresh = true

	if needs_refresh:
		_refresh_lantern_layers()


func spawn_lantern(drawing_texture: Texture2D, style_id: int) -> void:
	var entry := LanternEntry.new()
	entry.order = _spawn_counter
	_spawn_counter += 1
	entry.root = _build_lantern_node(drawing_texture, style_id, entry.order)
	entry.base_x = drift_origin.position.x + _rng.randf_range(-220.0, 220.0)
	entry.base_y = drift_origin.position.y + _rng.randf_range(-40.0, 30.0)
	entry.speed = _rng.randf_range(min_vertical_speed, max_vertical_speed)
	entry.amplitude = _rng.randf_range(min_amplitude, max_amplitude)
	entry.frequency = _rng.randf_range(min_frequency, max_frequency)
	entry.phase = _rng.randf_range(0.0, TAU)
	entry.root.position = Vector2(entry.base_x, entry.base_y)

	latest_container.add_child(entry.root)
	_lanterns.append(entry)
	_trim_oldest_if_needed()
	_refresh_lantern_layers()


func capture_view_image() -> Image:
	var image := get_viewport().get_texture().get_image()
	image.flip_y()
	return image


func reset_display() -> void:
	for entry in _lanterns:
		if is_instance_valid(entry.root):
			entry.root.queue_free()
	_lanterns.clear()
	_spawn_counter = 0


func _trim_oldest_if_needed() -> void:
	while _lanterns.size() > max_lanterns:
		_remove_lantern_at(0)


func _remove_lantern_at(index: int) -> void:
	if index < 0 or index >= _lanterns.size():
		return

	var entry: LanternEntry = _lanterns[index]
	if is_instance_valid(entry.root):
		entry.root.queue_free()
	_lanterns.remove_at(index)


func _refresh_lantern_layers() -> void:
	for index in range(_lanterns.size()):
		var entry: LanternEntry = _lanterns[index]
		if not is_instance_valid(entry.root):
			continue

		var target_parent: Node = latest_container if index == _lanterns.size() - 1 else history_container
		if entry.root.get_parent() != target_parent:
			entry.root.get_parent().remove_child(entry.root)
			target_parent.add_child(entry.root)

		_apply_entry_visuals(entry, index)


func _apply_entry_visuals(entry: LanternEntry, index: int) -> void:
	var count: int = maxi(1, _lanterns.size())
	var recency_ratio: float = 1.0 if count == 1 else float(index) / float(count - 1)
	var age_factor: float = clampf(entry.age / 24.0, 0.0, 1.0)
	var scale_factor: float = lerpf(oldest_scale, newest_scale, recency_ratio) * lerpf(1.0, 0.84, age_factor)
	var alpha: float = minf(lerpf(oldest_alpha, 1.0, recency_ratio), lerpf(1.0, oldest_alpha, age_factor))

	entry.root.scale = Vector2.ONE * scale_factor
	entry.root.modulate = Color(1.0, 1.0, 1.0, alpha)
	entry.root.z_index = 20 + index


func _build_lantern_node(drawing_texture: Texture2D, style_id: int, order: int) -> Node2D:
	var lantern_root := Node2D.new()
	lantern_root.name = "Lantern_%02d" % (order + 1)

	var frame_sprite := Sprite2D.new()
	frame_sprite.name = "Frame"
	frame_sprite.texture = _get_style_texture(style_id)
	frame_sprite.centered = true
	lantern_root.add_child(frame_sprite)

	if drawing_texture != null:
		var drawing_sprite := Sprite2D.new()
		drawing_sprite.name = "Drawing"
		drawing_sprite.texture = drawing_texture
		drawing_sprite.centered = true
		drawing_sprite.position = Vector2(0.0, 16.0)
		drawing_sprite.scale = Vector2.ONE * _calculate_overlay_scale(frame_sprite.texture, drawing_texture)
		drawing_sprite.modulate = Color(1.0, 1.0, 1.0, 0.92)
		drawing_sprite.z_index = 1
		lantern_root.add_child(drawing_sprite)

	return lantern_root


func _calculate_overlay_scale(frame_texture: Texture2D, drawing_texture: Texture2D) -> float:
	if frame_texture == null or drawing_texture == null:
		return 1.0

	var overlay_target: Vector2 = frame_texture.get_size() * Vector2(OVERLAY_WIDTH_RATIO, OVERLAY_HEIGHT_RATIO)
	var drawing_size: Vector2 = drawing_texture.get_size()
	if drawing_size.x <= 0.0 or drawing_size.y <= 0.0:
		return 1.0

	return min(overlay_target.x / drawing_size.x, overlay_target.y / drawing_size.y)


func _get_style_texture(style_id: int) -> Texture2D:
	var texture_index: int = clampi(style_id - 1, 0, STYLE_TEXTURES.size() - 1)
	return STYLE_TEXTURES[texture_index]