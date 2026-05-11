extends RefCounted
class_name ConfigLoader

static func load_installation_config() -> Dictionary:
	var search_paths: Array[String] = [
		"user://installation_config.json",
		"res://config/installation_config.json"
	]
	for path in search_paths:
		var data: Dictionary = _read_json_file(path)
		if not data.is_empty():
			return data
	return {}


static func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	if not (parser.data is Dictionary):
		return {}
	return parser.data


static func dictionary_from(value: Variant, default_value: Dictionary = {}) -> Dictionary:
	if value is Dictionary:
		return value
	return default_value.duplicate(true)


static func array_from(value: Variant, default_value: Array = []) -> Array:
	if value is Array:
		return value
	return default_value.duplicate(true)


static func string_from(value: Variant, default_value: String = "") -> String:
	if value is String:
		return value
	return default_value


static func float_from(value: Variant, default_value: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		return float(value)
	if value is String and value.is_valid_float():
		return value.to_float()
	return default_value


static func int_from(value: Variant, default_value: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		return int(round(value))
	if value is String and value.is_valid_int():
		return value.to_int()
	return default_value


static func bool_from(value: Variant, default_value: bool = false) -> bool:
	if value is bool:
		return value
	if value is String:
		var lower: String = value.to_lower()
		if lower == "true":
			return true
		if lower == "false":
			return false
	return default_value


static func color_from(value: Variant, default_value: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, default_value)
	return default_value


static func vector2_from(value: Variant, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector2i:
		return Vector2(value)
	if value is Array and value.size() >= 2:
		return Vector2(
			float_from(value[0], default_value.x),
			float_from(value[1], default_value.y)
		)
	return default_value


static func vector2i_from(value: Variant, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(roundi(value.x), roundi(value.y))
	if value is Array and value.size() >= 2:
		return Vector2i(
			int_from(value[0], default_value.x),
			int_from(value[1], default_value.y)
		)
	return default_value