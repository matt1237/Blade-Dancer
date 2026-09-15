class_name ZungarPolishAssetGenerator extends Node

const OUTPUT_DIR = "res://assets/generated/"
const FLAME_FRAME_SIZE: int = 192
const FLAME_FRAME_COUNT: int = 6
const BONFIRE_FRAME_SIZE: int = 384
const BONFIRE_FRAME_COUNT: int = 4
const DUST_FRAME_SIZE: int = 128
const DUST_FRAME_COUNT: int = 6
const BOSS_FRAME_SIZE: int = 256

func generate_zungar_polish_assets() -> void:
	_generate_flame_atlas()
	_generate_bonfire_atlas()
	_generate_dust_atlas()
	_generate_charge_and_stun_atlases()

func _generate_flame_atlas() -> void:
	var atlas: Image = Image.create(FLAME_FRAME_SIZE * FLAME_FRAME_COUNT, FLAME_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame_index: int in range(FLAME_FRAME_COUNT):
		_paint_flame_frame(atlas, frame_index * FLAME_FRAME_SIZE, frame_index)
	_save(atlas, OUTPUT_DIR + "hd_weapon_flame_symmetric_atlas.png")

func _paint_flame_frame(image: Image, offset_x: int, frame_index: int) -> void:
	var phase: float = float(frame_index) / float(FLAME_FRAME_COUNT) * TAU
	var center: Vector2 = Vector2(float(offset_x + FLAME_FRAME_SIZE / 2), 166.0)
	_paint_soft_ellipse(image, center + Vector2(0.0, -55.0), Vector2(76.0, 94.0), Color(1.0, 0.18, 0.015, 0.12), 1.8)
	for local_y: int in range(12, 178):
		var rise: float = clampf((176.0 - float(local_y)) / 164.0, 0.0, 1.0)
		var taper: float = pow(1.0 - rise, 0.46)
		var center_wave: float = sin(float(local_y) * 0.051 + phase) * (4.0 + rise * 9.0) + sin(float(local_y) * 0.113 - phase * 0.7) * 3.2
		var flame_center_x: float = float(offset_x + FLAME_FRAME_SIZE / 2) + center_wave
		var outer_width: float = 5.0 + 48.0 * taper
		var inner_width: float = 2.0 + 28.0 * taper
		for local_x: int in range(24, 169):
			var distance_x: float = absf(float(offset_x + local_x) - flame_center_x)
			if distance_x > outer_width:
				continue
			var edge: float = 1.0 - smoothstep(outer_width * 0.62, outer_width, distance_x)
			var height_fade: float = smoothstep(0.0, 0.1, rise) * smoothstep(1.0, 0.82, rise)
			var orange: Color = Color(1.0, 0.18 + 0.38 * (1.0 - rise), 0.015, edge * height_fade * 0.9)
			_blend_pixel(image, offset_x + local_x, local_y, orange)
			if distance_x < inner_width:
				var inner_edge: float = 1.0 - smoothstep(inner_width * 0.45, inner_width, distance_x)
				var gold: Color = Color(1.0, 0.58 + 0.34 * (1.0 - rise), 0.08, inner_edge * height_fade * 0.9)
				_blend_pixel(image, offset_x + local_x, local_y, gold)
				if distance_x < inner_width * 0.38 and local_y > 70:
					var core_edge: float = 1.0 - smoothstep(0.0, inner_width * 0.38, distance_x)
					_blend_pixel(image, offset_x + local_x, local_y, Color(1.0, 0.96, 0.62, core_edge * 0.74))
	# Side licks keep each frame organic while the renderer mirrors the complete
	# tongue on both sides of every blade profile.
	var side_left: float = 57.0 + sin(phase) * 5.0
	var side_right: float = 137.0 + cos(phase * 1.3) * 5.0
	_paint_tapered_lick(image, Vector2(offset_x + side_left, 166.0), 71.0 + sin(phase) * 12.0, 21.0, phase + 0.8)
	_paint_tapered_lick(image, Vector2(offset_x + side_right, 168.0), 58.0 + cos(phase) * 10.0, 18.0, phase + 2.1)

func _paint_tapered_lick(image: Image, base: Vector2, height: float, width: float, phase: float) -> void:
	var min_y: int = maxi(0, floori(base.y - height - 3.0))
	var max_y: int = mini(image.get_height() - 1, ceili(base.y))
	for y: int in range(min_y, max_y + 1):
		var rise: float = clampf((base.y - float(y)) / height, 0.0, 1.0)
		var center_x: float = base.x + sin(rise * 5.2 + phase) * rise * 8.0
		var half_width: float = maxf(1.0, width * pow(1.0 - rise, 0.62))
		for x: int in range(maxi(0, floori(center_x - half_width - 1.0)), mini(image.get_width(), ceili(center_x + half_width + 2.0))):
			var edge: float = 1.0 - smoothstep(half_width * 0.42, half_width, absf(float(x) - center_x))
			var color: Color = Color(1.0, lerpf(0.24, 0.76, 1.0 - rise), 0.025, edge * 0.84)
			_blend_pixel(image, x, y, color)

func _generate_bonfire_atlas() -> void:
	var atlas: Image = Image.create(BONFIRE_FRAME_SIZE * BONFIRE_FRAME_COUNT, BONFIRE_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame_index: int in range(BONFIRE_FRAME_COUNT):
		_paint_bonfire_frame(atlas, frame_index * BONFIRE_FRAME_SIZE, frame_index)
	_save(atlas, OUTPUT_DIR + "hd_zungar_bonfire_atlas.png")

func _paint_bonfire_frame(image: Image, offset_x: int, frame_index: int) -> void:
	var phase: float = float(frame_index) / float(BONFIRE_FRAME_COUNT) * TAU
	var center_x: float = float(offset_x + BONFIRE_FRAME_SIZE / 2)
	_paint_soft_ellipse(image, Vector2(center_x, 326.0), Vector2(143.0, 31.0), Color(0.07, 0.035, 0.025, 0.58), 2.2)
	_paint_soft_ellipse(image, Vector2(center_x, 190.0), Vector2(137.0, 151.0), Color(1.0, 0.18, 0.015, 0.14), 2.0)
	# Large hand-painted stone ring.
	for stone_index: int in range(13):
		var angle: float = TAU * float(stone_index) / 13.0
		var stone_center: Vector2 = Vector2(center_x + cos(angle) * 111.0, 315.0 + sin(angle) * 29.0)
		var frontness: float = 0.5 + 0.5 * sin(angle)
		var stone_color: Color = Color(0.22 + frontness * 0.09, 0.19 + frontness * 0.07, 0.17 + frontness * 0.055, 0.98)
		_paint_soft_ellipse(image, stone_center, Vector2(31.0, 18.0), Color(0.045, 0.035, 0.032, 0.96), 5.0)
		_paint_soft_ellipse(image, stone_center + Vector2(0.0, -2.0), Vector2(27.0, 14.0), stone_color, 7.0)
		_paint_soft_ellipse(image, stone_center + Vector2(-7.0, -6.0), Vector2(14.0, 5.0), Color(0.48, 0.39, 0.31, 0.36), 4.0)
	# Crossed charred logs with bark highlights and glowing cuts.
	_paint_segment(image, Vector2(center_x - 77.0, 298.0), Vector2(center_x + 73.0, 255.0), 20.0, Color(0.105, 0.045, 0.027, 1.0), Color(0.42, 0.16, 0.055, 1.0))
	_paint_segment(image, Vector2(center_x - 70.0, 258.0), Vector2(center_x + 82.0, 300.0), 19.0, Color(0.09, 0.038, 0.025, 1.0), Color(0.37, 0.13, 0.04, 1.0))
	_paint_segment(image, Vector2(center_x - 48.0, 284.0), Vector2(center_x + 53.0, 282.0), 14.0, Color(0.12, 0.045, 0.018, 1.0), Color(0.58, 0.22, 0.045, 1.0))
	for ember_index: int in range(11):
		var ember_x: float = center_x - 61.0 + float(ember_index) * 12.0
		_paint_soft_ellipse(image, Vector2(ember_x, 277.0 + sin(float(ember_index) * 1.8) * 6.0), Vector2(6.0, 3.0), Color(1.0, 0.38, 0.025, 0.82), 2.0)
	# Tall layered bonfire flame.
	for y: int in range(30, 286):
		var rise: float = clampf((281.0 - float(y)) / 251.0, 0.0, 1.0)
		var taper: float = pow(1.0 - rise, 0.5)
		var wave: float = sin(float(y) * 0.036 + phase) * (7.0 + rise * 21.0) + sin(float(y) * 0.083 - phase * 0.8) * 7.0
		var flame_center_x: float = center_x + wave
		var outer_width: float = 8.0 + 86.0 * taper
		var mid_width: float = 5.0 + 58.0 * taper
		var core_width: float = 2.0 + 28.0 * taper
		for x: int in range(floori(center_x - 112.0), ceili(center_x + 113.0)):
			var distance_x: float = absf(float(x) - flame_center_x)
			if distance_x >= outer_width:
				continue
			var height_fade: float = smoothstep(0.0, 0.09, rise) * smoothstep(1.0, 0.86, rise)
			var outer_edge: float = 1.0 - smoothstep(outer_width * 0.68, outer_width, distance_x)
			_blend_pixel(image, x, y, Color(0.98, 0.09 + 0.2 * (1.0 - rise), 0.006, outer_edge * height_fade * 0.94))
			if distance_x < mid_width:
				var mid_edge: float = 1.0 - smoothstep(mid_width * 0.52, mid_width, distance_x)
				_blend_pixel(image, x, y, Color(1.0, 0.38 + 0.37 * (1.0 - rise), 0.025, mid_edge * height_fade * 0.95))
			if distance_x < core_width and y > 108:
				var core_edge: float = 1.0 - smoothstep(core_width * 0.36, core_width, distance_x)
				_blend_pixel(image, x, y, Color(1.0, 0.93, 0.48, core_edge * height_fade * 0.9))
	for lick_index: int in range(5):
		var side: float = -1.0 if lick_index % 2 == 0 else 1.0
		var lick_base: Vector2 = Vector2(center_x + side * (34.0 + float(lick_index) * 7.0), 279.0)
		_paint_tapered_lick(image, lick_base, 100.0 + float((lick_index * 23 + frame_index * 17) % 71), 29.0, phase + float(lick_index))
	for spark_index: int in range(19):
		var seed: float = float(spark_index) * 2.399 + phase
		var spark_position: Vector2 = Vector2(center_x + sin(seed * 2.1) * (35.0 + float(spark_index % 5) * 11.0), 228.0 - float((spark_index * 29 + frame_index * 37) % 184))
		var spark_size: float = 1.7 + float(spark_index % 3)
		_paint_soft_ellipse(image, spark_position, Vector2(spark_size, spark_size * 1.9), Color(1.0, 0.55, 0.08, 0.72), 1.5)

func _generate_dust_atlas() -> void:
	var atlas: Image = Image.create(DUST_FRAME_SIZE * DUST_FRAME_COUNT, DUST_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for frame_index: int in range(DUST_FRAME_COUNT):
		var progress: float = float(frame_index) / float(DUST_FRAME_COUNT - 1)
		var offset_x: int = frame_index * DUST_FRAME_SIZE
		for puff_index: int in range(7):
			var angle: float = float(puff_index) * 1.91 + progress * 0.8
			var radius: float = 6.0 + progress * (22.0 + float(puff_index % 3) * 7.0)
			var puff_center: Vector2 = Vector2(float(offset_x + 64) + cos(angle) * radius, 76.0 + sin(angle) * radius * 0.42 - progress * 17.0)
			var puff_size: float = 14.0 + progress * 20.0 + float(puff_index % 2) * 6.0
			var puff_color: Color = Color(0.34, 0.22, 0.13, (1.0 - progress * 0.82) * 0.52)
			_paint_soft_ellipse(atlas, puff_center, Vector2(puff_size, puff_size * 0.72), puff_color, 1.9)
			_paint_soft_ellipse(atlas, puff_center + Vector2(-4.0, -4.0), Vector2(puff_size * 0.52, puff_size * 0.24), Color(0.68, 0.48, 0.27, (1.0 - progress) * 0.18), 2.4)
	_save(atlas, OUTPUT_DIR + "hd_zungar_dirt_puff_atlas.png")

func _generate_charge_and_stun_atlases() -> void:
	var idle_atlas: Image = _load_image("res://assets/generated/hd_boss_zungar_idle.png")
	var charge_atlas: Image = _load_image("res://assets/generated/hd_boss_zungar_charge.png")
	assert(idle_atlas.get_width() >= 512 and idle_atlas.get_height() >= 512)
	assert(charge_atlas.get_width() >= 1536 and charge_atlas.get_height() >= 512)
	var idle: Image = _extract_resized(idle_atlas, Rect2i(0, 0, 512, 512), BOSS_FRAME_SIZE)
	var charge_frames: Array[Image] = []
	for frame_index: int in range(3):
		charge_frames.append(_extract_resized(charge_atlas, Rect2i(frame_index * 512, 0, 512, 512), BOSS_FRAME_SIZE))
	var windup: Image = Image.create(BOSS_FRAME_SIZE * 8, BOSS_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	windup.fill(Color.TRANSPARENT)
	for frame_index: int in range(8):
		var progress: float = float(frame_index) / 7.0
		var source_a: Image = idle if progress < 0.5 else charge_frames[0]
		var source_b: Image = charge_frames[0] if progress < 0.5 else charge_frames[1]
		var local_progress: float = progress * 2.0 if progress < 0.5 else (progress - 0.5) * 2.0
		var blended: Image = _interpolate_images(source_a, source_b, smoothstep(0.0, 1.0, local_progress))
		windup.blit_rect(blended, Rect2i(0, 0, BOSS_FRAME_SIZE, BOSS_FRAME_SIZE), Vector2i(frame_index * BOSS_FRAME_SIZE, 0))
	_save(windup, OUTPUT_DIR + "hd_boss_zungar_charge_windup_smooth.png")
	var travel: Image = Image.create(BOSS_FRAME_SIZE * 8, BOSS_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	travel.fill(Color.TRANSPARENT)
	var sequence: Array[int] = [0, 1, 1, 2, 2, 1, 1, 0]
	for frame_index: int in range(8):
		var next_index: int = (frame_index + 1) % 8
		var blended: Image = _interpolate_images(charge_frames[sequence[frame_index]], charge_frames[sequence[next_index]], 0.34)
		travel.blit_rect(blended, Rect2i(0, 0, BOSS_FRAME_SIZE, BOSS_FRAME_SIZE), Vector2i(frame_index * BOSS_FRAME_SIZE, 0))
	_save(travel, OUTPUT_DIR + "hd_boss_zungar_charge_travel_smooth.png")
	var stunned: Image = Image.create(BOSS_FRAME_SIZE * 6, BOSS_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	stunned.fill(Color.TRANSPARENT)
	var tilts: Array[float] = [-0.11, -0.065, 0.045, 0.095, 0.035, -0.055]
	for frame_index: int in range(6):
		var transformed: Image = _transform_character(idle, tilts[frame_index], 1.0 + sin(float(frame_index) * 1.8) * 0.025, 0.96 - cos(float(frame_index) * 1.5) * 0.025, frame_index)
		stunned.blit_rect(transformed, Rect2i(0, 0, BOSS_FRAME_SIZE, BOSS_FRAME_SIZE), Vector2i(frame_index * BOSS_FRAME_SIZE, 0))
	_save(stunned, OUTPUT_DIR + "hd_boss_zungar_stunned_smooth.png")

func _transform_character(source: Image, angle: float, scale_x: float, scale_y: float, frame_index: int) -> Image:
	var output: Image = Image.create(BOSS_FRAME_SIZE, BOSS_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var pivot: Vector2 = Vector2(128.0, 211.0)
	var cosine: float = cos(-angle)
	var sine: float = sin(-angle)
	for y: int in range(BOSS_FRAME_SIZE):
		for x: int in range(BOSS_FRAME_SIZE):
			var destination: Vector2 = Vector2(float(x), float(y)) - pivot
			var rotated: Vector2 = Vector2(destination.x * cosine - destination.y * sine, destination.x * sine + destination.y * cosine)
			var source_position: Vector2 = Vector2(rotated.x / scale_x, rotated.y / scale_y) + pivot
			var source_x: int = roundi(source_position.x)
			var source_y: int = roundi(source_position.y)
			if source_x < 0 or source_x >= BOSS_FRAME_SIZE or source_y < 0 or source_y >= BOSS_FRAME_SIZE:
				continue
			var color: Color = source.get_pixel(source_x, source_y)
			if color.a <= 0.001:
				continue
			var flash: float = 0.1 + 0.08 * (0.5 + 0.5 * sin(float(frame_index) * 2.4))
			color = color.lerp(Color(1.0, 0.78, 0.57, color.a), flash)
			output.set_pixel(x, y, color)
	# A compact ring of painted daze motes makes the state readable at combat scale.
	for mote_index: int in range(5):
		var mote_angle: float = TAU * float(mote_index) / 5.0 + float(frame_index) * 0.46
		var mote_position: Vector2 = Vector2(128.0 + cos(mote_angle) * 40.0, 58.0 + sin(mote_angle) * 12.0)
		_paint_soft_ellipse(output, mote_position, Vector2(4.0, 2.5), Color(1.0, 0.72, 0.18, 0.88), 2.4)
	return output

func _extract_resized(source: Image, region: Rect2i, target_size: int) -> Image:
	var result: Image = source.get_region(region)
	result.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return result

func _interpolate_images(first: Image, second: Image, weight: float) -> Image:
	var output: Image = Image.create(BOSS_FRAME_SIZE, BOSS_FRAME_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(BOSS_FRAME_SIZE):
		for x: int in range(BOSS_FRAME_SIZE):
			output.set_pixel(x, y, first.get_pixel(x, y).lerp(second.get_pixel(x, y), weight))
	return output

func _paint_segment(image: Image, start: Vector2, end: Vector2, radius: float, outline: Color, fill: Color) -> void:
	var min_x: int = maxi(0, floori(minf(start.x, end.x) - radius - 3.0))
	var max_x: int = mini(image.get_width() - 1, ceili(maxf(start.x, end.x) + radius + 3.0))
	var min_y: int = maxi(0, floori(minf(start.y, end.y) - radius - 3.0))
	var max_y: int = mini(image.get_height() - 1, ceili(maxf(start.y, end.y) + radius + 3.0))
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var point: Vector2 = Vector2(float(x), float(y))
			var projection: float = clampf((point - start).dot(segment) / maxf(length_squared, 0.001), 0.0, 1.0)
			var distance: float = point.distance_to(start + segment * projection)
			if distance <= radius + 2.0:
				var color: Color = outline if distance > radius - 3.0 else fill.lerp(Color(0.15, 0.055, 0.025, 1.0), clampf((distance / radius) * 0.35, 0.0, 0.35))
				_blend_pixel(image, x, y, color)

func _paint_soft_ellipse(image: Image, center: Vector2, radii: Vector2, color: Color, softness: float) -> void:
	var min_x: int = maxi(0, floori(center.x - radii.x - softness * 2.0))
	var max_x: int = mini(image.get_width() - 1, ceili(center.x + radii.x + softness * 2.0))
	var min_y: int = maxi(0, floori(center.y - radii.y - softness * 2.0))
	var max_y: int = mini(image.get_height() - 1, ceili(center.y + radii.y + softness * 2.0))
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var normalized: Vector2 = Vector2((float(x) - center.x) / maxf(radii.x, 0.001), (float(y) - center.y) / maxf(radii.y, 0.001))
			var distance: float = normalized.length()
			if distance > 1.0:
				continue
			var edge_alpha: float = 1.0 - smoothstep(maxf(0.0, 1.0 - softness / maxf(minf(radii.x, radii.y), 1.0)), 1.0, distance)
			_blend_pixel(image, x, y, Color(color.r, color.g, color.b, color.a * edge_alpha))

func _blend_pixel(image: Image, x: int, y: int, source: Color) -> void:
	if x < 0 or x >= image.get_width() or y < 0 or y >= image.get_height() or source.a <= 0.0:
		return
	var destination: Color = image.get_pixel(x, y)
	var output_alpha: float = source.a + destination.a * (1.0 - source.a)
	if output_alpha <= 0.0001:
		return
	var output_rgb: Color = Color(
		(source.r * source.a + destination.r * destination.a * (1.0 - source.a)) / output_alpha,
		(source.g * source.a + destination.g * destination.a * (1.0 - source.a)) / output_alpha,
		(source.b * source.a + destination.b * destination.a * (1.0 - source.a)) / output_alpha,
		output_alpha
	)
	image.set_pixel(x, y, output_rgb)

func _load_image(path: String) -> Image:
	var texture: Texture2D = load(path) as Texture2D
	assert(texture != null, "Could not load source art: %s" % path)
	return texture.get_image()

func _save(image: Image, path: String) -> void:
	var error: Error = image.save_png(path)
	assert(error == OK, "Could not save generated art: %s" % path)
	print("Generated ", path, " (", image.get_width(), "x", image.get_height(), ")")
