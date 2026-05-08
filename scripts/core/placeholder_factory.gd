extends RefCounted
class_name PlaceholderFactory


static func load_texture(path: String, fallback: Texture2D = null) -> Texture2D:
	if not path.is_empty():
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return fallback


static func make_background_texture(size: Vector2i, palette_index: int = 0) -> Texture2D:
	var palettes := [
		{
			"top": "#10213f",
			"bottom": "#41679a",
			"accent": "#ffd36a",
			"mist": "#edf7ff",
			"ridge": "#26395d",
			"hill": "#182742"
		},
		{
			"top": "#2a2049",
			"bottom": "#965f7f",
			"accent": "#ffe6a8",
			"mist": "#fff4f8",
			"ridge": "#3d2b56",
			"hill": "#241734"
		},
		{
			"top": "#0f3044",
			"bottom": "#2b7c8d",
			"accent": "#ffcb7d",
			"mist": "#effdfc",
			"ridge": "#1d4f62",
			"hill": "#12303c"
		}
	]
	var palette := palettes[wrapi(palette_index, 0, palettes.size())]
	var sun_x := int(size.x * (0.18 + 0.24 * float(palette_index % 3)))
	var sun_y := int(size.y * (0.18 + 0.06 * float(palette_index % 2)))
	var svg := """
<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%%" stop-color="%s"/>
      <stop offset="100%%" stop-color="%s"/>
    </linearGradient>
  </defs>
  <rect width="100%%" height="100%%" fill="url(#sky)"/>
  <circle cx="%d" cy="%d" r="%d" fill="%s" fill-opacity="0.22"/>
  <ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="%s" fill-opacity="0.12"/>
  <ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="%s" fill-opacity="0.18"/>
  <path d="M0 %d C %d %d, %d %d, %d %d L %d %d L 0 %d Z" fill="%s" fill-opacity="0.45"/>
  <path d="M0 %d C %d %d, %d %d, %d %d L %d %d L 0 %d Z" fill="%s" fill-opacity="0.72"/>
</svg>
""" % [
		size.x,
		size.y,
		size.x,
		size.y,
		palette["top"],
		palette["bottom"],
		sun_x,
		sun_y,
		int(size.y * 0.12),
		palette["accent"],
		int(size.x * 0.70),
		int(size.y * 0.22),
		int(size.x * 0.18),
		int(size.y * 0.07),
		palette["mist"],
		int(size.x * 0.35),
		int(size.y * 0.28),
		int(size.x * 0.16),
		int(size.y * 0.06),
		palette["mist"],
		int(size.y * 0.66),
		int(size.x * 0.16),
		int(size.y * 0.57),
		int(size.x * 0.48),
		int(size.y * 0.75),
		int(size.x * 0.84),
		int(size.y * 0.62),
		size.x,
		size.y,
		size.y,
		palette["ridge"],
		int(size.y * 0.78),
		int(size.x * 0.20),
		int(size.y * 0.70),
		int(size.x * 0.50),
		int(size.y * 0.90),
		int(size.x * 0.88),
		int(size.y * 0.74),
		size.x,
		size.y,
		size.y,
		palette["hill"]
	]
	return _texture_from_svg(svg, size)


static func make_character_frames(frame_count: int = 4, size: Vector2i = Vector2i(360, 360)) -> Array:
	var textures := []
	for frame_index in range(max(frame_count, 1)):
		textures.append(_texture_from_svg(_character_svg(size, frame_index), size))
	return textures


static func make_lantern_texture(size: Vector2i = Vector2i(512, 768), accent: String = "#ffd27a") -> Texture2D:
	return _texture_from_svg(_lantern_svg(size, accent), size)


static func compose_user_lantern(drawing_image: Image, size: Vector2i = Vector2i(512, 768)) -> Texture2D:
	var base_image := _image_from_svg(_lantern_svg(size, "#ffd27a"), size)
	if drawing_image == null or drawing_image.is_empty() or drawing_image.is_invisible():
		return ImageTexture.create_from_image(base_image)
	var working := drawing_image.get_region(drawing_image.get_used_rect())
	if working.is_empty():
		working = drawing_image
	if working.get_format() != Image.FORMAT_RGBA8:
		working.convert(Image.FORMAT_RGBA8)
	var panel_rect := Rect2i(
		int(size.x * 0.28),
		int(size.y * 0.28),
		int(size.x * 0.44),
		int(size.y * 0.34)
	)
	var target_size := _fit_size(working.get_size(), panel_rect.size)
	working.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	var panel_image := Image.create_empty(panel_rect.size.x, panel_rect.size.y, false, Image.FORMAT_RGBA8)
	panel_image.fill(Color(1.0, 1.0, 1.0, 0.0))
	var draw_position := Vector2i(
		(panel_rect.size.x - target_size.x) / 2,
		(panel_rect.size.y - target_size.y) / 2
	)
	panel_image.blit_rect(working, Rect2i(Vector2i.ZERO, working.get_size()), draw_position)
	base_image.blend_rect(panel_image, Rect2i(Vector2i.ZERO, panel_image.get_size()), panel_rect.position)
	return ImageTexture.create_from_image(base_image)


static func _texture_from_svg(svg: String, size: Vector2i) -> Texture2D:
	var image := _image_from_svg(svg, size)
	return ImageTexture.create_from_image(image)


static func _image_from_svg(svg: String, size: Vector2i) -> Image:
	var image := Image.new()
	var error := image.load_svg_from_string(svg, 1.0)
	if error != OK:
		image = Image.create_empty(max(size.x, 1), max(size.y, 1), false, Image.FORMAT_RGBA8)
		image.fill(Color(0.20, 0.24, 0.32, 1.0))
		return image
	if image.get_size() != size:
		image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return image


static func _fit_size(source_size: Vector2i, bounds: Vector2i) -> Vector2i:
	var width := max(source_size.x, 1)
	var height := max(source_size.y, 1)
	var scale := min(float(bounds.x) / float(width), float(bounds.y) / float(height))
	return Vector2i(
		max(1, int(round(width * scale))),
		max(1, int(round(height * scale)))
	)


static func _character_svg(size: Vector2i, frame_index: int) -> String:
	var bob := [-6, -12, -4, 6][frame_index % 4]
	var sway := [-14, -6, 8, 16][frame_index % 4]
	return """
<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">
  <ellipse cx="%d" cy="%d" rx="78" ry="24" fill="#88c9ff" fill-opacity="0.16"/>
  <ellipse cx="%d" cy="%d" rx="96" ry="108" fill="#f7f3df"/>
  <ellipse cx="%d" cy="%d" rx="68" ry="80" fill="#fff8ec"/>
  <circle cx="%d" cy="%d" r="12" fill="#28394f"/>
  <circle cx="%d" cy="%d" r="12" fill="#28394f"/>
  <path d="M %d %d Q %d %d, %d %d" stroke="#28394f" stroke-width="8" fill="none" stroke-linecap="round"/>
  <path d="M %d %d Q %d %d, %d %d" stroke="#ffb65c" stroke-width="18" fill="none" stroke-linecap="round"/>
  <circle cx="%d" cy="%d" r="16" fill="#ffcf7b"/>
  <circle cx="%d" cy="%d" r="16" fill="#ffcf7b"/>
</svg>
""" % [
		size.x,
		size.y,
		size.x,
		size.y,
		int(size.x * 0.50),
		int(size.y * 0.82),
		int(size.x * 0.50),
		int(size.y * 0.46 + bob),
		int(size.x * 0.50),
		int(size.y * 0.42 + bob),
		int(size.x * 0.42),
		int(size.y * 0.40 + bob),
		int(size.x * 0.58),
		int(size.y * 0.40 + bob),
		int(size.x * 0.44),
		int(size.y * 0.52 + bob),
		int(size.x * 0.50),
		int(size.y * 0.56 + bob),
		int(size.x * 0.56),
		int(size.y * 0.52 + bob),
		int(size.x * 0.35 + sway),
		int(size.y * 0.48 + bob),
		int(size.x * 0.50),
		int(size.y * 0.70 + bob),
		int(size.x * 0.65 - sway),
		int(size.y * 0.48 + bob),
		int(size.x * 0.32 + sway),
		int(size.y * 0.50 + bob),
		int(size.x * 0.68 - sway),
		int(size.y * 0.50 + bob)
	]


static func _lantern_svg(size: Vector2i, accent: String) -> String:
	return """
<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">
  <defs>
    <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%%" stop-color="#fff4d2"/>
      <stop offset="100%%" stop-color="%s"/>
    </linearGradient>
  </defs>
  <ellipse cx="%d" cy="%d" rx="%d" ry="%d" fill="#ffd98c" fill-opacity="0.24"/>
  <rect x="%d" y="%d" width="%d" height="%d" rx="44" fill="url(#body)"/>
  <rect x="%d" y="%d" width="%d" height="%d" rx="22" fill="#fff9ea" fill-opacity="0.88"/>
  <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#ebb761" stroke-width="12" stroke-linecap="round"/>
  <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#ebb761" stroke-width="12" stroke-linecap="round"/>
  <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#ebb761" stroke-width="8" stroke-linecap="round"/>
  <line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#ebb761" stroke-width="8" stroke-linecap="round"/>
  <circle cx="%d" cy="%d" r="12" fill="#d48f31"/>
</svg>
""" % [
		size.x,
		size.y,
		size.x,
		size.y,
		accent,
		int(size.x * 0.50),
		int(size.y * 0.72),
		int(size.x * 0.23),
		int(size.y * 0.22),
		int(size.x * 0.24),
		int(size.y * 0.16),
		int(size.x * 0.52),
		int(size.y * 0.58),
		int(size.x * 0.28),
		int(size.y * 0.28),
		int(size.x * 0.44),
		int(size.y * 0.34),
		int(size.x * 0.34),
		int(size.y * 0.12),
		int(size.x * 0.50),
		int(size.y * 0.04),
		int(size.x * 0.66),
		int(size.y * 0.12),
		int(size.x * 0.34),
		int(size.y * 0.74),
		int(size.x * 0.50),
		int(size.y * 0.92),
		int(size.x * 0.66),
		int(size.y * 0.74),
		int(size.x * 0.38),
		int(size.y * 0.16),
		int(size.x * 0.38),
		int(size.y * 0.74),
		int(size.x * 0.62),
		int(size.y * 0.16),
		int(size.x * 0.62),
		int(size.y * 0.74),
		int(size.x * 0.50),
		int(size.y * 0.95)
	]