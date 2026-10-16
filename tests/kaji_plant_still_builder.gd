class_name KajiPlantStillBuilder extends RefCounted
## Offline still experiment only. Never called by the live store.
const ROOT: String = "res://assets/generated/"
const ORIGINAL: String = "res://assets/portraits/Kaji's General Store.png"
const REGION: Rect2i = Rect2i(440, 132, 156, 132)

static func build() -> void:
	var source: Image = Image.load_from_file(ORIGINAL)
	source.convert(Image.FORMAT_RGBA8)
	var generated: Image = Image.load_from_file(ROOT + "kaji_plant_clean_crop_generated.png")
	generated.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var plate: Image = source.duplicate() as Image
	var layer: Image = Image.create(REGION.size.x, REGION.size.y, false, Image.FORMAT_RGBA8)
	var mask: Image = Image.create(REGION.size.x, REGION.size.y, false, Image.FORMAT_RGBA8)
	var outline: PackedVector2Array = PackedVector2Array([Vector2(452, 176), Vector2(471, 151), Vector2(502, 138), Vector2(531, 138), Vector2(554, 145), Vector2(582, 164), Vector2(593, 192), Vector2(582, 226), Vector2(568, 239), Vector2(553, 221), Vector2(554, 203), Vector2(499, 196), Vector2(496, 244), Vector2(479, 259), Vector2(464, 236), Vector2(450, 215), Vector2(445, 194)])
	for y: int in range(REGION.size.y):
		for x: int in range(REGION.size.x):
			var point: Vector2i = REGION.position + Vector2i(x, y)
			var color: Color = source.get_pixelv(point)
			var selected: bool = Geometry2D.is_point_in_polygon(Vector2(point), outline) and color.g > color.r * 0.57 and color.g > color.b * 1.3 and not (point.y >= 201 and point.x >= 500 and point.x <= 556)
			mask.set_pixel(x, y, Color(1, 1, 1, 1) if selected else Color(0, 0, 0, 0))
	# Close tiny dark leaf/shadow holes in this provisional source matte.
	var expanded: Image = mask.duplicate() as Image
	for y: int in range(REGION.size.y):
		for x: int in range(REGION.size.x):
			var point: Vector2i = REGION.position + Vector2i(x, y)
			if not Geometry2D.is_point_in_polygon(Vector2(point), outline) or (point.y >= 201 and point.x >= 500 and point.x <= 556):
				continue
			for dy: int in range(-2, 3):
				for dx: int in range(-2, 3):
					var near: Vector2i = Vector2i(x + dx, y + dy)
					if Rect2i(Vector2i.ZERO, REGION.size).has_point(near) and mask.get_pixelv(near).a > 0.0:
						expanded.set_pixel(x, y, Color.WHITE)
	mask = expanded
	# One-pixel outward feather only. Core foliage retains exact source pixels.
	for y: int in range(REGION.size.y):
		for x: int in range(REGION.size.x):
			var alpha: float = mask.get_pixel(x, y).a
			if alpha == 0.0:
				for dy: int in range(-1, 2):
					for dx: int in range(-1, 2):
						var near: Vector2i = Vector2i(x + dx, y + dy)
						if Rect2i(Vector2i.ZERO, REGION.size).has_point(near) and mask.get_pixelv(near).a > 0.0:
							alpha = 0.45
			var point: Vector2i = REGION.position + Vector2i(x, y)
			var color: Color = source.get_pixelv(point)
			var behind: Color = generated.get_pixelv(point - Vector2i(416, 96))
			plate.set_pixelv(point, color.lerp(behind, alpha))
			color.a = alpha
			layer.set_pixel(x, y, color)
	plate.save_png(ROOT + "kaji_plant_clean_plate.png")
	layer.save_png(ROOT + "kaji_plant_leaves_still.png")
	mask.save_png(ROOT + "kaji_plant_leaf_mask.png")
	var composite: Image = plate.duplicate() as Image
	composite.blend_rect(layer, Rect2i(Vector2i.ZERO, REGION.size), REGION.position)
	composite.save_png(ROOT + "kaji_plant_still_composite.png")
	var crop: Image = source.get_region(Rect2i(416, 96, 256, 256))
	crop.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	var compare: Image = Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	compare.blit_rect(crop, Rect2i(0, 0, 512, 512), Vector2i.ZERO)
	crop = composite.get_region(Rect2i(416, 96, 256, 256))
	crop.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	compare.blit_rect(crop, Rect2i(0, 0, 512, 512), Vector2i(512, 0))
	compare.save_png(ROOT + "kaji_plant_still_detail_comparison.png")
	var outside_changes: int = 0
	var inside_changes: int = 0
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			if source.get_pixel(x, y) != composite.get_pixel(x, y):
				if REGION.has_point(Vector2i(x, y)):
					inside_changes += 1
				else:
					outside_changes += 1
	print("STILL ONLY: outside selected footprint changed pixels=", outside_changes, "; feather changed pixels=", inside_changes)
