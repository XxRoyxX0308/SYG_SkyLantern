extends Control

class LanternEntry:
	var root: Node2D
	var base_x: float = 0.0
	var base_y: float = 0.0
	var spawn_y: float = 0.0
	var baked_scale: float = 1.0
	var speed: float = 0.0
	var amplitude: float = 0.0
	var frequency: float = 0.0
	var phase: float = 0.0
	var age: float = 0.0
	var order: int = 0
	var style_id: int = 1
	var drawing_texture: Texture2D = null
	var is_featured: bool = false


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

const TARGET_LANTERN_COUNT := 8
const OFFSCREEN_MARGIN := 280.0
const OVERLAY_WIDTH_RATIO := 0.42
const OVERLAY_HEIGHT_RATIO := 0.34

@export var ambient_spawn_interval := 1.2
@export var min_vertical_speed := 28.0
@export var max_vertical_speed := 48.0
@export var min_amplitude := 24.0
@export var max_amplitude := 88.0
@export var min_frequency := 0.55
@export var max_frequency := 1.35
@export var newest_scale := 0.95
@export var oldest_scale := 0.55
@export var oldest_alpha := 0.32
@export var featured_scale := 4.0
@export var featured_end_scale := 2.0
@export var featured_vertical_speed := 40.0
@export var featured_amplitude := 20.0
@export var featured_frequency := 0.42
@export var shrink_curve_power := 1.65

@onready var history_container: Node2D = $SkyLanternsContainer/HistoryLanterns
@onready var latest_container: Node2D = $SkyLanternsContainer/LatestLanterns
@onready var drift_origin: Marker2D = $SkyLanternsContainer/DriftOrigin
@onready var latest_front_anchor: Marker2D = $SkyLanternsContainer/LatestFrontAnchor

var _ambient_lanterns: Array = []
var _featured_lantern = null
var _pending_ambient_styles: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_counter: int = 0
var _spawn_cooldown: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_reset_ambient_cycle()


func _process(delta: float) -> void:
	var needs_refresh: bool = _update_ambient_lanterns(delta)
	if _update_featured_lantern(delta):
		needs_refresh = true

	if needs_refresh:
		_refresh_ambient_visuals()

	_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
	_spawn_pending_ambient_if_needed()


func spawn_lantern(drawing_texture: Texture2D, style_id: int) -> void:
	if _featured_lantern != null:
		_promote_featured_to_ambient()

	if _ambient_lanterns.size() >= TARGET_LANTERN_COUNT:
		_remove_oldest_ambient_for_featured()

	var entry: LanternEntry = _create_entry(drawing_texture, style_id, true)
	latest_container.add_child(entry.root)
	_featured_lantern = entry
	_apply_featured_visuals(entry)


func capture_view_image() -> Image:
	var image := get_viewport().get_texture().get_image()
	return image


func reset_display() -> void:
	for entry in _ambient_lanterns:
		_dispose_lantern_root(entry.root)
	_ambient_lanterns.clear()
	if _featured_lantern != null:
		_clear_featured_lantern()
	_pending_ambient_styles.clear()
	_spawn_counter = 0
	_spawn_cooldown = 0.0
	_reset_ambient_cycle()


func _update_ambient_lanterns(delta: float) -> bool:
	var needs_refresh: bool = false
	for index in range(_ambient_lanterns.size() - 1, -1, -1):
		var entry: LanternEntry = _ambient_lanterns[index]
		if not is_instance_valid(entry.root):
			_queue_ambient_style(entry.style_id)
			_ambient_lanterns.remove_at(index)
			needs_refresh = true
			continue

		_advance_entry(entry, delta)
		_apply_ambient_visuals(entry)

		if entry.base_y < -OFFSCREEN_MARGIN:
			_respawn_ambient_entry(index)
			needs_refresh = true

	return needs_refresh


func _update_featured_lantern(delta: float) -> bool:
	if _featured_lantern == null:
		return false

	var entry: LanternEntry = _featured_lantern
	if not is_instance_valid(entry.root):
		_featured_lantern = null
		return true

	_advance_entry(entry, delta)
	_apply_featured_visuals(entry)
	if entry.base_y < -OFFSCREEN_MARGIN:
		_promote_featured_to_ambient()
		return true

	return false


func _spawn_pending_ambient_if_needed() -> void:
	if _spawn_cooldown > 0.0:
		return

	if _ambient_lanterns.size() >= _desired_ambient_count():
		return

	if _pending_ambient_styles.is_empty():
		return

	var style_id: int = _pending_ambient_styles[0]
	_pending_ambient_styles.remove_at(0)

	var entry: LanternEntry = _create_entry(null, style_id, false)
	history_container.add_child(entry.root)
	_ambient_lanterns.append(entry)
	_refresh_ambient_visuals()
	_spawn_cooldown = ambient_spawn_interval


func _remove_oldest_ambient_for_featured() -> void:
	if _ambient_lanterns.is_empty():
		return

	var removed_entry: LanternEntry = _ambient_lanterns[0]
	_dispose_lantern_root(removed_entry.root)
	_ambient_lanterns.remove_at(0)
	_refresh_ambient_visuals()


func _respawn_ambient_entry(index: int) -> void:
	if index < 0 or index >= _ambient_lanterns.size():
		return

	var entry: LanternEntry = _ambient_lanterns[index]
	_reset_entry_motion(entry, false)
	entry.root.position = Vector2(entry.base_x, entry.base_y)


func _advance_entry(entry: LanternEntry, delta: float) -> void:
	entry.age += delta
	entry.base_y -= entry.speed * delta
	if entry.is_featured:
		entry.base_x = lerpf(entry.base_x, latest_front_anchor.position.x, 0.018)

	entry.root.position = Vector2(
		entry.base_x + sin(entry.age * entry.frequency + entry.phase) * entry.amplitude,
		entry.base_y
	)


func _refresh_ambient_visuals() -> void:
	for index in range(_ambient_lanterns.size()):
		var entry: LanternEntry = _ambient_lanterns[index]
		if not is_instance_valid(entry.root):
			continue

		if entry.root.get_parent() != history_container:
			entry.root.get_parent().remove_child(entry.root)
			history_container.add_child(entry.root)

		_apply_ambient_visuals(entry)


func _apply_ambient_visuals(entry: LanternEntry) -> void:
	var travel_ratio: float = _get_travel_ratio(entry)
	var shrink_ratio: float = pow(travel_ratio, shrink_curve_power)
	var scale_factor: float = lerpf(1.0, oldest_scale / maxf(entry.baked_scale, 0.001), shrink_ratio)
	var alpha: float = lerpf(0.95, oldest_alpha, shrink_ratio)

	entry.root.scale = Vector2.ONE * scale_factor
	entry.root.modulate = Color(1.0, 1.0, 1.0, alpha)
	entry.root.z_index = 10 + int(round((1.0 - travel_ratio) * 20.0))


func _apply_featured_visuals(entry: LanternEntry) -> void:
	var travel_ratio: float = _get_travel_ratio(entry)
	var shrink_ratio: float = pow(travel_ratio, shrink_curve_power)
	entry.root.scale = Vector2.ONE * lerpf(1.0, featured_end_scale / maxf(entry.baked_scale, 0.001), shrink_ratio)
	entry.root.modulate = Color(1.0, 1.0, 1.0, lerpf(1.0, 0.86, shrink_ratio))
	entry.root.z_index = 100


func _create_entry(drawing_texture: Texture2D, style_id: int, is_featured: bool) -> LanternEntry:
	var entry := LanternEntry.new()
	entry.order = _spawn_counter
	entry.style_id = style_id
	entry.drawing_texture = drawing_texture
	entry.is_featured = is_featured
	_spawn_counter += 1
	entry.root = _build_lantern_node(entry.order)
	_update_entry_texture(entry, is_featured)
	_reset_entry_motion(entry, is_featured)
	entry.root.position = Vector2(entry.base_x, entry.base_y)
	return entry


func _reset_entry_motion(entry: LanternEntry, is_featured: bool) -> void:
	entry.age = 0.0
	entry.phase = _rng.randf_range(0.0, TAU)
	if is_featured:
		entry.base_x = _featured_spawn_x()
		entry.base_y = _spawn_y(320.0, 420.0)
		entry.spawn_y = entry.base_y
		entry.speed = featured_vertical_speed
		entry.amplitude = featured_amplitude
		entry.frequency = featured_frequency
		return

	entry.base_x = _ambient_spawn_x()
	entry.base_y = _spawn_y(50.0, 180.0)
	entry.spawn_y = entry.base_y
	entry.speed = _rng.randf_range(min_vertical_speed, max_vertical_speed)
	entry.amplitude = _rng.randf_range(min_amplitude, max_amplitude)
	entry.frequency = _rng.randf_range(min_frequency, max_frequency)


func _reset_ambient_cycle() -> void:
	_pending_ambient_styles.clear()
	for style_index in range(TARGET_LANTERN_COUNT):
		_pending_ambient_styles.append(style_index + 1)
	_pending_ambient_styles.shuffle()
	_spawn_cooldown = 0.0


func _desired_ambient_count() -> int:
	return TARGET_LANTERN_COUNT - (1 if _featured_lantern != null else 0)


func _queue_ambient_style(style_id: int) -> void:
	if style_id <= 0:
		return

	_pending_ambient_styles.append(style_id)


func _clear_featured_lantern() -> void:
	if _featured_lantern == null:
		return

	var entry: LanternEntry = _featured_lantern
	_dispose_lantern_root(entry.root)
	_featured_lantern = null


func _promote_featured_to_ambient() -> void:
	if _featured_lantern == null:
		return

	var entry: LanternEntry = _featured_lantern
	_featured_lantern = null
	if not is_instance_valid(entry.root):
		return

	entry.is_featured = false
	_update_entry_texture(entry, false)
	_reset_entry_motion(entry, false)
	entry.root.position = Vector2(entry.base_x, entry.base_y)

	var parent: Node = entry.root.get_parent()
	if parent != null:
		parent.remove_child(entry.root)
	history_container.add_child(entry.root)
	_ambient_lanterns.append(entry)
	_refresh_ambient_visuals()


func _dispose_lantern_root(root: Node2D) -> void:
	if not is_instance_valid(root):
		return

	var parent: Node = root.get_parent()
	if parent != null:
		parent.remove_child(root)
	root.queue_free()


func _get_travel_ratio(entry: LanternEntry) -> float:
	if is_equal_approx(entry.spawn_y, -OFFSCREEN_MARGIN):
		return 1.0

	return clampf(inverse_lerp(entry.spawn_y, -OFFSCREEN_MARGIN, entry.base_y), 0.0, 1.0)


func _ambient_spawn_x() -> float:
	var total_width: float = maxf(size.x, 1920.0)
	return _rng.randf_range(180.0, total_width - 180.0)


func _featured_spawn_x() -> float:
	return latest_front_anchor.position.x + _rng.randf_range(-80.0, 80.0)


func _spawn_y(min_offset: float, max_offset: float) -> float:
	var total_height: float = maxf(size.y, 1080.0)
	return total_height + _rng.randf_range(min_offset, max_offset)

func _build_lantern_node(order: int) -> Node2D:
	var lantern_sprite := Sprite2D.new()
	lantern_sprite.name = "Lantern_%02d" % (order + 1)
	lantern_sprite.centered = true
	return lantern_sprite


func _update_entry_texture(entry: LanternEntry, is_featured: bool) -> void:
	var lantern_sprite: Sprite2D = entry.root as Sprite2D
	if lantern_sprite == null:
		return

	entry.baked_scale = featured_scale if is_featured else newest_scale
	lantern_sprite.texture = _build_lantern_texture(entry.style_id, entry.drawing_texture, entry.baked_scale)


func _build_lantern_texture(style_id: int, drawing_texture: Texture2D, target_scale: float) -> Texture2D:
	var frame_texture: Texture2D = _get_style_texture(style_id)
	if frame_texture == null:
		return null

	var safe_scale: float = maxf(target_scale, 0.01)
	var base_frame_size: Vector2 = frame_texture.get_size()
	var output_size := Vector2i(
		maxi(1, int(round(base_frame_size.x * safe_scale))),
		maxi(1, int(round(base_frame_size.y * safe_scale)))
	)

	var composite_image: Image = frame_texture.get_image()
	if composite_image == null:
		return frame_texture
	composite_image.convert(Image.FORMAT_RGBA8)
	if composite_image.get_width() != output_size.x or composite_image.get_height() != output_size.y:
		composite_image.resize(output_size.x, output_size.y)

	if drawing_texture == null:
		return ImageTexture.create_from_image(composite_image)

	var drawing_image: Image = drawing_texture.get_image()
	if drawing_image == null:
		return ImageTexture.create_from_image(composite_image)
	drawing_image.convert(Image.FORMAT_RGBA8)

	var frame_size: Vector2 = Vector2(output_size)
	var overlay_scale: float = _calculate_overlay_scale_from_size(frame_size, drawing_texture.get_size())
	var drawing_size: Vector2 = drawing_texture.get_size() * overlay_scale
	var overlay_width: int = maxi(1, int(round(drawing_size.x)))
	var overlay_height: int = maxi(1, int(round(drawing_size.y)))
	drawing_image.resize(overlay_width, overlay_height)

	var overlay_position: Vector2 = frame_size * 0.5 + Vector2(0.0, 16.0) - Vector2(float(overlay_width), float(overlay_height)) * 0.5
	var max_x: float = maxf(0.0, frame_size.x - float(overlay_width))
	var max_y: float = maxf(0.0, frame_size.y - float(overlay_height))
	var overlay_position_i := Vector2i(
		int(round(clampf(overlay_position.x, 0.0, max_x))),
		int(round(clampf(overlay_position.y, 0.0, max_y)))
	)

	composite_image.blend_rect(
		drawing_image,
		Rect2i(Vector2i.ZERO, Vector2i(overlay_width, overlay_height)),
		overlay_position_i
	)

	return ImageTexture.create_from_image(composite_image)


func _calculate_overlay_scale(frame_texture: Texture2D, drawing_texture: Texture2D) -> float:
	if frame_texture == null or drawing_texture == null:
		return 1.0

	return _calculate_overlay_scale_from_size(frame_texture.get_size(), drawing_texture.get_size())


func _calculate_overlay_scale_from_size(frame_size: Vector2, drawing_size: Vector2) -> float:
	var overlay_target: Vector2 = frame_size * Vector2(OVERLAY_WIDTH_RATIO, OVERLAY_HEIGHT_RATIO)
	if drawing_size.x <= 0.0 or drawing_size.y <= 0.0:
		return 1.0

	return min(overlay_target.x / drawing_size.x, overlay_target.y / drawing_size.y)


func _get_style_texture(style_id: int) -> Texture2D:
	var texture_index: int = clampi(style_id - 1, 0, STYLE_TEXTURES.size() - 1)
	return STYLE_TEXTURES[texture_index]