extends Control

class LanternEntry:
	var root: Sprite2D
	var speed: float = 0.0
	var amplitude: float = 0.0
	var frequency: float = 0.0
	var phase: float = 0.0
	var age: float = 0.0
	var order: int = 0
	var style_id: int = 1
	var drawing_texture: Texture2D = null
	var is_featured: bool = false
	var fixed_scale: float = 1.0
	var travel_direction: Vector2 = Vector2.UP
	var drift_direction: Vector2 = Vector2.RIGHT
	var start_position: Vector2 = Vector2.ZERO
	var end_position: Vector2 = Vector2.ZERO
	var travel_distance: float = 0.0
	var total_distance: float = 0.0


# 8 款天燈外框，順序對應主選單樣式。
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

# 這段控制常駐數量、畫面外留白與畫作貼圖比例。
const TARGET_LANTERN_COUNT := 8
const OFFSCREEN_MARGIN := -100.0
const OVERLAY_WIDTH_RATIO := 0.42
const OVERLAY_HEIGHT_RATIO := 0.34

# 這段控制常駐天燈的放出節奏、移動速度、飄移幅度與透明度。
@export var ambient_spawn_interval := 1.2
@export var min_travel_speed := 28.0
@export var max_travel_speed := 48.0
@export var min_drift_amplitude := 24.0
@export var max_drift_amplitude := 88.0
@export var min_drift_frequency := 0.55
@export var max_drift_frequency := 1.35
@export var oldest_alpha := 0.32
@export var newest_alpha := 0.95

# 這段控制常駐與 feature 天燈的畫面外邊界，feature 太晚出現時可先調這裡。
@export var ambient_offscreen_margin := -100.0
@export var featured_offscreen_margin := 0.0
@export var ambient_texture_padding_ratio := 0.5
@export var featured_texture_padding_ratio := 0.18

# 這段控制每款小天燈的固定尺寸、前景天燈尺寸與飛行角度。
@export var ambient_style_scales := PackedFloat32Array([0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0])
@export var featured_lantern_scale := 4.0
@export var featured_travel_speed := 40.0
@export var featured_drift_amplitude := 20.0
@export var featured_drift_frequency := 0.42
@export_range(0.0, 360.0, 1.0) var flight_angle_degrees := 45.0

@onready var history_container: Node2D = $SkyLanternsContainer/HistoryLanterns
@onready var latest_container: Node2D = $SkyLanternsContainer/LatestLanterns
@onready var latest_front_anchor: Marker2D = $SkyLanternsContainer/LatestFrontAnchor

var _ambient_lanterns: Array = []
var _featured_lantern: LanternEntry = null
var _pending_ambient_styles: Array[int] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _spawn_counter: int = 0
var _spawn_cooldown: float = 0.0


func _ready() -> void:
	_rng.randomize()
	_reset_ambient_cycle()


# Public API
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

	var entry: LanternEntry = _create_featured_entry(drawing_texture, style_id)
	latest_container.add_child(entry.root)
	_featured_lantern = entry
	_apply_featured_visuals(entry)


func capture_view_image() -> Image:
	return get_viewport().get_texture().get_image()


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


# Update Loop
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
		if _is_entry_finished(entry):
			_respawn_ambient_entry(index)
			needs_refresh = true
			continue

		_apply_ambient_visuals(entry, index)

	return needs_refresh


func _update_featured_lantern(delta: float) -> bool:
	if _featured_lantern == null:
		return false

	var entry: LanternEntry = _featured_lantern
	if not is_instance_valid(entry.root):
		_featured_lantern = null
		return true

	_advance_entry(entry, delta)
	if _is_entry_finished(entry):
		_promote_featured_to_ambient()
		return true

	_apply_featured_visuals(entry)
	return false


# Queue Lifecycle
func _spawn_pending_ambient_if_needed() -> void:
	if _spawn_cooldown > 0.0:
		return

	if _ambient_lanterns.size() >= _desired_ambient_count():
		return

	if _pending_ambient_styles.is_empty():
		return

	var style_id: int = _pop_pending_ambient_style()
	var entry: LanternEntry = _create_ambient_entry(style_id, _ambient_lanterns.size())
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
	_configure_entry_motion(entry, false, index)
	_apply_ambient_visuals(entry, index)


# Motion
func _advance_entry(entry: LanternEntry, delta: float) -> void:
	entry.age += delta
	entry.travel_distance = minf(entry.total_distance, entry.travel_distance + entry.speed * delta)
	entry.root.position = _calculate_entry_position(entry)
	entry.root.rotation_degrees = flight_angle_degrees


func _calculate_entry_position(entry: LanternEntry) -> Vector2:
	var base_position: Vector2 = entry.start_position + entry.travel_direction * entry.travel_distance
	var drift_offset: Vector2 = entry.drift_direction * sin(entry.age * entry.frequency + entry.phase) * entry.amplitude
	return base_position + drift_offset


func _is_entry_finished(entry: LanternEntry) -> bool:
	return entry.travel_distance >= entry.total_distance


# Visuals
func _refresh_ambient_visuals() -> void:
	for index in range(_ambient_lanterns.size()):
		var entry: LanternEntry = _ambient_lanterns[index]
		if not is_instance_valid(entry.root):
			continue

		_reparent_entry(entry.root, history_container)
		_apply_ambient_visuals(entry, index)


func _apply_ambient_visuals(entry: LanternEntry, index: int) -> void:
	var alpha: float = lerpf(oldest_alpha, newest_alpha, _get_ambient_scale_ratio(entry.fixed_scale))

	entry.root.scale = Vector2.ONE
	entry.root.modulate = Color(1.0, 1.0, 1.0, alpha)
	entry.root.z_index = 10 + index


func _apply_featured_visuals(entry: LanternEntry) -> void:
	entry.root.scale = Vector2.ONE
	entry.root.modulate = Color(1.0, 1.0, 1.0, 1.0)
	entry.root.z_index = 1000


# Entry Configuration
func _create_featured_entry(drawing_texture: Texture2D, style_id: int) -> LanternEntry:
	return _create_entry(drawing_texture, style_id, true)


func _create_ambient_entry(style_id: int, ambient_index: int) -> LanternEntry:
	return _create_entry(null, style_id, false, ambient_index)


func _create_entry(drawing_texture: Texture2D, style_id: int, is_featured: bool, ambient_index: int = -1) -> LanternEntry:
	var entry := LanternEntry.new()
	entry.order = _spawn_counter
	entry.style_id = style_id
	entry.drawing_texture = drawing_texture
	entry.is_featured = is_featured
	_spawn_counter += 1
	entry.root = _build_lantern_node(entry.order)
	_configure_entry_motion(entry, is_featured, ambient_index)
	return entry


func _configure_entry_motion(entry: LanternEntry, is_featured: bool, ambient_index: int = -1) -> void:
	_reset_entry_runtime(entry)
	entry.travel_direction = _get_travel_direction()
	entry.drift_direction = _get_drift_direction(entry.travel_direction)
	if is_featured:
		_configure_featured_motion(entry)
	else:
		_configure_ambient_motion(entry, ambient_index)

	_update_entry_texture(entry)
	_configure_entry_path(entry, _get_anchor_point(is_featured, entry.drift_direction))


func _reset_entry_runtime(entry: LanternEntry) -> void:
	entry.age = 0.0
	entry.phase = _rng.randf_range(0.0, TAU)


func _configure_featured_motion(entry: LanternEntry) -> void:
	entry.fixed_scale = featured_lantern_scale
	entry.speed = featured_travel_speed
	entry.amplitude = featured_drift_amplitude
	entry.frequency = featured_drift_frequency


func _configure_ambient_motion(entry: LanternEntry, ambient_index: int) -> void:
	entry.fixed_scale = _get_ambient_scale_for_index(ambient_index)
	entry.speed = _rng.randf_range(min_travel_speed, max_travel_speed)
	entry.amplitude = _rng.randf_range(min_drift_amplitude, max_drift_amplitude)
	entry.frequency = _rng.randf_range(min_drift_frequency, max_drift_frequency)


# Queue State
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


func _pop_pending_ambient_style() -> int:
	var style_id: int = _pending_ambient_styles[0]
	_pending_ambient_styles.remove_at(0)
	return style_id


# Featured Lifecycle
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
	_reparent_entry(entry.root, history_container)
	_ambient_lanterns.append(entry)
	_configure_entry_motion(entry, false, _ambient_lanterns.size() - 1)
	_refresh_ambient_visuals()


# Path Geometry
func _dispose_lantern_root(root: Node2D) -> void:
	if not is_instance_valid(root):
		return

	_reparent_entry(root, null)
	root.queue_free()


func _reparent_entry(root: Node, target_parent: Node) -> void:
	if not is_instance_valid(root):
		return

	var current_parent: Node = root.get_parent()
	if current_parent == target_parent:
		return

	if current_parent != null:
		current_parent.remove_child(root)
	if target_parent != null:
		target_parent.add_child(root)


func _get_travel_direction() -> Vector2:
	return Vector2.UP.rotated(deg_to_rad(flight_angle_degrees)).normalized()


func _get_drift_direction(travel_direction: Vector2) -> Vector2:
	return Vector2(-travel_direction.y, travel_direction.x).normalized()


func _configure_entry_path(entry: LanternEntry, anchor_point: Vector2) -> void:
	var expanded_rect: Rect2 = _get_expanded_view_rect(entry)
	var fallback_margin: float = _get_offscreen_margin(entry)
	var backward_distance: float = _get_distance_to_rect_edge(anchor_point, -entry.travel_direction, expanded_rect, fallback_margin)
	var forward_distance: float = _get_distance_to_rect_edge(anchor_point, entry.travel_direction, expanded_rect, fallback_margin)

	entry.start_position = anchor_point - entry.travel_direction * backward_distance
	entry.end_position = anchor_point + entry.travel_direction * forward_distance
	entry.travel_distance = 0.0
	entry.total_distance = maxf(backward_distance + forward_distance, 1.0)
	entry.root.position = entry.start_position
	entry.root.rotation_degrees = flight_angle_degrees


func _get_expanded_view_rect(entry: LanternEntry) -> Rect2:
	var view_size: Vector2 = _get_view_size()
	var padding: float = _get_entry_padding(entry)
	return Rect2(Vector2(-padding, -padding), view_size + Vector2.ONE * padding * 2.0)


func _get_entry_padding(entry: LanternEntry) -> float:
	var padding: float = _get_offscreen_margin(entry) + maxf(entry.amplitude * 0.5, 12.0)
	if is_instance_valid(entry.root) and entry.root.texture != null:
		var texture_size: Vector2 = entry.root.texture.get_size()
		padding += maxf(texture_size.x, texture_size.y) * _get_texture_padding_ratio(entry)
	return padding


func _get_distance_to_rect_edge(point: Vector2, direction: Vector2, rect: Rect2, fallback_margin: float) -> float:
	var min_distance: float = 1e20
	var rect_left: float = rect.position.x
	var rect_right: float = rect.position.x + rect.size.x
	var rect_top: float = rect.position.y
	var rect_bottom: float = rect.position.y + rect.size.y

	if absf(direction.x) > 0.0001:
		var target_x: float = rect_right if direction.x > 0.0 else rect_left
		var distance_x: float = (target_x - point.x) / direction.x
		if distance_x >= 0.0:
			var hit_y: float = point.y + direction.y * distance_x
			if hit_y >= rect_top - 0.5 and hit_y <= rect_bottom + 0.5:
				min_distance = minf(min_distance, distance_x)

	if absf(direction.y) > 0.0001:
		var target_y: float = rect_bottom if direction.y > 0.0 else rect_top
		var distance_y: float = (target_y - point.y) / direction.y
		if distance_y >= 0.0:
			var hit_x: float = point.x + direction.x * distance_y
			if hit_x >= rect_left - 0.5 and hit_x <= rect_right + 0.5:
				min_distance = minf(min_distance, distance_y)

	if min_distance > 1e19:
		return fallback_margin

	return maxf(min_distance, 0.0)


func _get_offscreen_margin(entry: LanternEntry) -> float:
	return featured_offscreen_margin if entry.is_featured else ambient_offscreen_margin


func _get_texture_padding_ratio(entry: LanternEntry) -> float:
	return featured_texture_padding_ratio if entry.is_featured else ambient_texture_padding_ratio


# Anchor Selection
func _get_anchor_point(is_featured: bool, drift_direction: Vector2) -> Vector2:
	if is_featured:
		return _get_featured_anchor_point(drift_direction)

	return _get_random_anchor_point()


func _get_featured_anchor_point(drift_direction: Vector2) -> Vector2:
	var view_size: Vector2 = _get_view_size()
	var featured_anchor: Vector2 = latest_front_anchor.position + drift_direction * _rng.randf_range(-140.0, 140.0)
	return Vector2(
		clampf(featured_anchor.x, 0.0, view_size.x),
		clampf(featured_anchor.y, 0.0, view_size.y)
	)


func _get_random_anchor_point() -> Vector2:
	var view_size: Vector2 = _get_view_size()
	return Vector2(
		_get_random_anchor_coordinate(view_size.x, 180.0),
		_get_random_anchor_coordinate(view_size.y, 160.0)
	)


func _get_random_anchor_coordinate(length: float, margin: float) -> float:
	if length <= margin * 2.0:
		return length * 0.5

	return _rng.randf_range(margin, length - margin)


func _get_view_size() -> Vector2:
	return Vector2(maxf(size.x, 1920.0), maxf(size.y, 1080.0))


func _build_lantern_node(order: int) -> Sprite2D:
	var lantern_sprite := Sprite2D.new()
	lantern_sprite.name = "Lantern_%02d" % (order + 1)
	lantern_sprite.centered = true
	return lantern_sprite


# Texture Baking
func _update_entry_texture(entry: LanternEntry) -> void:
	if not is_instance_valid(entry.root):
		return

	entry.root.texture = _build_lantern_texture(entry.style_id, entry.drawing_texture, entry.fixed_scale)


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


# Scale Helpers
func _calculate_overlay_scale_from_size(frame_size: Vector2, drawing_size: Vector2) -> float:
	var overlay_target: Vector2 = frame_size * Vector2(OVERLAY_WIDTH_RATIO, OVERLAY_HEIGHT_RATIO)
	if drawing_size.x <= 0.0 or drawing_size.y <= 0.0:
		return 1.0

	return min(overlay_target.x / drawing_size.x, overlay_target.y / drawing_size.y)


func _get_ambient_scale_for_index(index: int) -> float:
	if ambient_style_scales.is_empty():
		return 1.0

	var safe_index: int = clampi(index, 0, ambient_style_scales.size() - 1)
	return maxf(ambient_style_scales[safe_index], 0.01)


func _get_ambient_scale_ratio(scale_value: float) -> float:
	if ambient_style_scales.is_empty():
		return 1.0

	var min_scale: float = ambient_style_scales[0]
	var max_scale: float = ambient_style_scales[0]
	for ambient_scale in ambient_style_scales:
		min_scale = minf(min_scale, ambient_scale)
		max_scale = maxf(max_scale, ambient_scale)

	if is_equal_approx(min_scale, max_scale):
		return 1.0

	return clampf(inverse_lerp(min_scale, max_scale, scale_value), 0.0, 1.0)


func _get_style_texture(style_id: int) -> Texture2D:
	var texture_index: int = clampi(style_id - 1, 0, STYLE_TEXTURES.size() - 1)
	return STYLE_TEXTURES[texture_index]
