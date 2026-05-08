extends RefCounted
class_name ShareQr

const QR_SIZE := 21
const DATA_CODEWORDS := 19
const ECC_CODEWORDS := 7
const GENERATOR := [87, 229, 146, 149, 238, 102, 21]


static func make_texture(payload: String, size: Vector2i) -> Dictionary:
	var data := payload.to_utf8_buffer()
	if data.size() > 17:
		return {
			"texture": null,
			"error": "Share link is too long for the built-in QR encoder. Shorten sharing.link_prefix or id_length."
		}
	var codewords := _build_codewords(data)
	var matrix := _build_matrix(codewords)
	var image := _render_matrix(matrix, size)
	return {
		"texture": ImageTexture.create_from_image(image),
		"error": ""
	}


static func _build_codewords(data: PackedByteArray) -> Array:
	var bits := []
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8)
	for byte in data:
		_append_bits(bits, byte, 8)
	var capacity := DATA_CODEWORDS * 8
	var terminator := min(4, capacity - bits.size())
	for _index in range(terminator):
		bits.append(0)
	while bits.size() % 8 != 0:
		bits.append(0)
	var codewords := []
	for bit_index in range(0, bits.size(), 8):
		var value := 0
		for offset in range(8):
			value = (value << 1) | bits[bit_index + offset]
		codewords.append(value)
	var pads := [0xEC, 0x11]
	var pad_index := 0
	while codewords.size() < DATA_CODEWORDS:
		codewords.append(pads[pad_index % 2])
		pad_index += 1
	var remainder := []
	remainder.resize(ECC_CODEWORDS)
	remainder.fill(0)
	for byte in codewords:
		var factor := byte ^ remainder[0]
		for idx in range(ECC_CODEWORDS - 1):
			remainder[idx] = remainder[idx + 1]
		remainder[ECC_CODEWORDS - 1] = 0
		for idx in range(ECC_CODEWORDS):
			remainder[idx] ^= _gf_multiply(GENERATOR[idx], factor)
	return codewords + remainder


static func _build_matrix(codewords: Array) -> Array:
	var modules := []
	var reserved := []
	for _row in range(QR_SIZE):
		var module_row := []
		var reserved_row := []
		for _column in range(QR_SIZE):
			module_row.append(false)
			reserved_row.append(false)
		modules.append(module_row)
		reserved.append(reserved_row)
	_draw_finder(modules, reserved, 0, 0)
	_draw_finder(modules, reserved, QR_SIZE - 7, 0)
	_draw_finder(modules, reserved, 0, QR_SIZE - 7)
	_draw_timing_patterns(modules, reserved)
	_reserve_format_areas(modules, reserved)
	_set_function_module(modules, reserved, 8, QR_SIZE - 8, true)
	_place_data(modules, reserved, codewords)
	_draw_format_bits(modules, reserved, 0)
	return modules


static func _place_data(modules: Array, reserved: Array, codewords: Array) -> void:
	var bits := []
	for byte in codewords:
		for shift in range(7, -1, -1):
			bits.append((byte >> shift) & 1)
	var bit_index := 0
	var right := QR_SIZE - 1
	var upward := true
	while right >= 1:
		if right == 6:
			right -= 1
		for row_step in range(QR_SIZE):
			var y := QR_SIZE - 1 - row_step if upward else row_step
			for x in [right, right - 1]:
				if reserved[y][x]:
					continue
				var value := false
				if bit_index < bits.size():
					value = bits[bit_index] == 1
					bit_index += 1
				if _mask(x, y):
					value = not value
				modules[y][x] = value
		upward = not upward
		right -= 2


static func _draw_finder(modules: Array, reserved: Array, start_x: int, start_y: int) -> void:
	for y in range(-1, 8):
		for x in range(-1, 8):
			var cell_x := start_x + x
			var cell_y := start_y + y
			if cell_x < 0 or cell_x >= QR_SIZE or cell_y < 0 or cell_y >= QR_SIZE:
				continue
			var is_separator := x == -1 or x == 7 or y == -1 or y == 7
			var is_border := x == 0 or x == 6 or y == 0 or y == 6
			var is_center := x >= 2 and x <= 4 and y >= 2 and y <= 4
			_set_function_module(modules, reserved, cell_x, cell_y, (not is_separator) and (is_border or is_center))


static func _draw_timing_patterns(modules: Array, reserved: Array) -> void:
	for index in range(8, QR_SIZE - 8):
		var value := index % 2 == 0
		_set_function_module(modules, reserved, index, 6, value)
		_set_function_module(modules, reserved, 6, index, value)


static func _reserve_format_areas(modules: Array, reserved: Array) -> void:
	for index in range(9):
		if index != 6:
			_set_function_module(modules, reserved, 8, index, modules[index][8])
			_set_function_module(modules, reserved, index, 8, modules[8][index])
	for index in range(8):
		_set_function_module(modules, reserved, QR_SIZE - 1 - index, 8, false)
		_set_function_module(modules, reserved, 8, QR_SIZE - 1 - index, false)


static func _draw_format_bits(modules: Array, reserved: Array, mask: int) -> void:
	var ecl_bits := 1
	var data := (ecl_bits << 3) | mask
	var remainder := data << 10
	for bit in range(14, 9, -1):
		if ((remainder >> bit) & 1) != 0:
			remainder ^= 0x537 << (bit - 10)
	var format_bits := ((data << 10) | remainder) ^ 0x5412
	for index in range(0, 6):
		_set_function_module(modules, reserved, 8, index, _get_bit(format_bits, index))
	_set_function_module(modules, reserved, 8, 7, _get_bit(format_bits, 6))
	_set_function_module(modules, reserved, 8, 8, _get_bit(format_bits, 7))
	_set_function_module(modules, reserved, 7, 8, _get_bit(format_bits, 8))
	for index in range(9, 15):
		_set_function_module(modules, reserved, 14 - index, 8, _get_bit(format_bits, index))
	for index in range(8):
		_set_function_module(modules, reserved, QR_SIZE - 1 - index, 8, _get_bit(format_bits, index))
	for index in range(8, 15):
		_set_function_module(modules, reserved, 8, QR_SIZE - 15 + index, _get_bit(format_bits, index))
	_set_function_module(modules, reserved, 8, QR_SIZE - 8, true)


static func _render_matrix(matrix: Array, size: Vector2i) -> Image:
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var quiet_zone := 4
	var module_size := maxi(1, mini(size.x, size.y) / (QR_SIZE + quiet_zone * 2))
	var render_width := module_size * (QR_SIZE + quiet_zone * 2)
	var render_height := module_size * (QR_SIZE + quiet_zone * 2)
	var offset := Vector2i((size.x - render_width) / 2, (size.y - render_height) / 2)
	for y in range(QR_SIZE):
		for x in range(QR_SIZE):
			if not matrix[y][x]:
				continue
			var rect := Rect2i(
				offset + Vector2i((x + quiet_zone) * module_size, (y + quiet_zone) * module_size),
				Vector2i(module_size, module_size)
			)
			image.fill_rect(rect, Color.BLACK)
	return image


static func _append_bits(bits: Array, value: int, count: int) -> void:
	for shift in range(count - 1, -1, -1):
		bits.append((value >> shift) & 1)


static func _gf_multiply(left: int, right: int) -> int:
	var x := left
	var y := right
	var result := 0
	while y > 0:
		if (y & 1) != 0:
			result ^= x
		y >>= 1
		x <<= 1
		if (x & 0x100) != 0:
			x ^= 0x11D
	return result


static func _mask(x: int, y: int) -> bool:
	return (x + y) % 2 == 0


static func _get_bit(value: int, bit_index: int) -> bool:
	return ((value >> bit_index) & 1) != 0


static func _set_function_module(modules: Array, reserved: Array, x: int, y: int, value: bool) -> void:
	modules[y][x] = value
	reserved[y][x] = true