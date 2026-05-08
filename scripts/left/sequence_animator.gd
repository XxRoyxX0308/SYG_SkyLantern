extends AnimatedSprite2D
class_name SequenceAnimator

const ConfigLoader = preload("res://scripts/core/config_loader.gd")
const PlaceholderFactory = preload("res://scripts/core/placeholder_factory.gd")


func apply_config(animation_config: Dictionary) -> void:
	visible = ConfigLoader.bool_from(animation_config.get("visible"), true)
	position = ConfigLoader.vector2_from(animation_config.get("position"), Vector2(1510, 710))
	scale = ConfigLoader.vector2_from(animation_config.get("scale"), Vector2.ONE)
	z_index = ConfigLoader.int_from(animation_config.get("z_index"), 1)
	var fps := ConfigLoader.float_from(animation_config.get("fps"), 3.0)
	var frame_paths := ConfigLoader.array_from(animation_config.get("frames"), [])
	var textures := []
	for path in frame_paths:
		var texture := PlaceholderFactory.load_texture(ConfigLoader.string_from(path), null)
		if texture != null:
			textures.append(texture)
	if textures.is_empty():
		textures = PlaceholderFactory.make_character_frames(4)
	var frames := SpriteFrames.new()
	frames.add_animation("loop")
	frames.set_animation_speed("loop", fps)
	frames.set_animation_loop("loop", true)
	for texture in textures:
		frames.add_frame("loop", texture)
	sprite_frames = frames
	play("loop")