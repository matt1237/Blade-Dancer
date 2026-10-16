class_name KajiPlantBreezeBuilder extends RefCounted
## Offline derived experiment. No originals or earlier candidates are written.
const ROOT: String = "res://assets/generated/"
const ORIGINAL: String = "res://assets/portraits/Kaji's General Store.png"
const REGION: Rect2i = Rect2i(436, 128, 164, 140)
const DETAIL: Rect2i = Rect2i(416, 96, 256, 256)

static func build() -> void:
	# Never silently replace an inspected iteration; choose a new version first.
	for suffix: String in ["plate", "leaves", "matte", "zero", "plate_detail"]:
		if FileAccess.file_exists(ROOT + "kaji_plant_breeze_v2_%s.png" % suffix):
			push_error("Breeze v2 already exists; preserve it and increment the candidate version before rebuilding.")
			return
	var source: Image = Image.load_from_file(ORIGINAL)
	source.convert(Image.FORMAT_RGBA8)
	var old: Image = Image.load_from_file(ROOT + "kaji_plant_leaves_still.png")
	var behind: Image = Image.load_from_file(ROOT + "kaji_plant_clean_crop_generated.png")
	behind.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var plate: Image = source.duplicate() as Image
	var leaves: Image = Image.create(REGION.size.x, REGION.size.y, false, Image.FORMAT_RGBA8)
	var matte: Image = Image.create(REGION.size.x, REGION.size.y, false, Image.FORMAT_RGBA8)
	# Extend only to source-green disconnected tips missed by the old polygon.
	# Existing feather becomes opaque source pixels: phase zero is exact, not a double blend.
	for y: int in range(REGION.size.y):
		for x: int in range(REGION.size.x):
			var p: Vector2i = REGION.position + Vector2i(x, y)
			var c: Color = source.get_pixelv(p)
			var local: Vector2i = p - Vector2i(440, 132)
			var selected: bool = Rect2i(0, 0, 156, 132).has_point(local) and old.get_pixelv(local).a > 0.0
			var tip: bool = p.x >= 446 and p.x <= 594 and p.y >= 133 and p.y <= 262 and c.g > c.r * 0.70 and c.g > c.b * 1.5
			# Two dark detached top tips inspected on the exposed plate.
			if Rect2i(485, 137, 9, 7).has_point(p) or Rect2i(540, 134, 13, 8).has_point(p):
				tip = true
			# Never select pot body, hook, chains or the next lower plant.
			if p.y >= 201 and p.x >= 500 and p.x <= 556:
				tip = false
			if selected or tip:
				matte.set_pixel(x, y, Color.WHITE)
	# Source pixels only. Generated room pixels are confined to the source matte.
	for y: int in range(REGION.size.y):
		for x: int in range(REGION.size.x):
			if matte.get_pixel(x, y).a == 0.0:
				continue
			var p: Vector2i = REGION.position + Vector2i(x, y)
			leaves.set_pixel(x, y, source.get_pixelv(p))
			plate.set_pixelv(p, behind.get_pixelv(p - DETAIL.position))
	plate.save_png(ROOT + "kaji_plant_breeze_v2_plate.png")
	leaves.save_png(ROOT + "kaji_plant_breeze_v2_leaves.png")
	matte.save_png(ROOT + "kaji_plant_breeze_v2_matte.png")
	var composite: Image = plate.duplicate() as Image
	composite.blend_rect(leaves, Rect2i(Vector2i.ZERO, REGION.size), REGION.position)
	assert(composite.get_data() == source.get_data(), "Phase-zero source composite must be byte exact")
	composite.save_png(ROOT + "kaji_plant_breeze_v2_zero.png")
	var detail: Image = plate.get_region(DETAIL)
	detail.resize(768, 768, Image.INTERPOLATE_NEAREST)
	detail.save_png(ROOT + "kaji_plant_breeze_v2_plate_detail.png")
	print("BREEZE v2: byte-exact phase-zero composite; generated pixels confined to matte")
