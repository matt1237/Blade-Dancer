class_name KajiPlantBreezeTest extends Node
const REGION: Rect2i = Rect2i(436, 128, 164, 140)
const ROOT: String = "res://assets/generated/"

func test_phase_zero_exact_and_plate_only_changes_matte() -> void:
	var source: Image = Image.load_from_file("res://assets/portraits/Kaji's General Store.png")
	var plate: Image = Image.load_from_file(ROOT + "kaji_plant_breeze_v2_plate.png")
	var leaves: Image = Image.load_from_file(ROOT + "kaji_plant_breeze_v2_leaves.png")
	var matte: Image = Image.load_from_file(ROOT + "kaji_plant_breeze_v2_matte.png")
	source.convert(Image.FORMAT_RGBA8)
	plate.convert(Image.FORMAT_RGBA8)
	assert(leaves.get_size() == REGION.size)
	for y: int in range(source.get_height()):
		for x: int in range(source.get_width()):
			var p: Vector2i = Vector2i(x, y)
			var selected: bool = REGION.has_point(p) and matte.get_pixelv(p - REGION.position).a > 0.0
			if not selected:
				assert(plate.get_pixelv(p) == source.get_pixelv(p), "No plate edits outside exact matte")
			else:
				assert(leaves.get_pixelv(p - REGION.position) == source.get_pixelv(p))
	plate.blend_rect(leaves, Rect2i(Vector2i.ZERO, REGION.size), REGION.position)
	assert(source.get_data() == plate.get_data())

func test_source_anchors_and_pot_body_are_stationary() -> void:
	var leaves: Image = Image.load_from_file(ROOT + "kaji_plant_breeze_v2_leaves.png")
	for y: int in range(202, 251):
		for x: int in range(501, 556):
			assert(leaves.get_pixelv(Vector2i(x, y) - REGION.position).a == 0.0)
	for size: Vector2 in [Vector2(1280, 720), Vector2(720, 1280), Vector2(2560, 1080)]:
		var rect: Rect2 = KajiStoreBackdrop.image_rect(size)
		var factor: Vector2 = rect.size / KajiStoreBackdrop.SOURCE_SIZE
		for p: Vector2 in [Vector2(436, 128), Vector2(527, 199), Vector2(527, 246)]:
			assert(((rect.position + p * factor - rect.position) / factor).is_equal_approx(p))
	var shader: String = FileAccess.get_file_as_string("res://scripts/ui/kaji_plant_breeze_preview.gdshader")
	assert(not shader.contains("SCREEN_UV") and not shader.contains("vertex()"))
	assert(shader.contains("(1.0 - pot)"))

func test_rendered_phases_move_only_selected_foliage_and_keep_pot_fixed() -> void:
	var zero: Image = Image.load_from_file("res://tests/kaji_plant_breeze_evidence_v3_phase_0.png")
	assert(zero.get_size() == Vector2i(1920, 1080), "Evidence fixture dimensions changed; recalculate screen masks")
	var upper: Rect2i = Rect2i(1240, 122, 90, 78)
	var detail: Rect2i = Rect2i(1364, 630, 282, 242)
	var pot: Rect2i = Rect2i(1480, 785, 48, 48)
	for phase: int in [2, 5]:
		var frame: Image = Image.load_from_file("res://tests/kaji_plant_breeze_evidence_v3_phase_%d.png" % phase)
		var changed: int = 0
		for y: int in range(1015):
			for x: int in range(1920):
				var p: Vector2i = Vector2i(x, y)
				if frame.get_pixelv(p) != zero.get_pixelv(p):
					changed += 1
					assert(upper.has_point(p) or detail.has_point(p), "Motion escaped selected plant")
					assert(not pot.has_point(p), "Pot body moved")
		assert(changed > 100, "Rendered foliage must really move, not just update a uniform")

func test_preview_cannot_switch_shop_or_write_saves() -> void:
	var script: String = FileAccess.get_file_as_string("res://tests/kaji_plant_breeze_preview.gd")
	assert(not script.contains("HomeProgression") and not script.contains("user://"))
	var live: String = FileAccess.get_file_as_string("res://scripts/ui/kaji_store_backdrop.gd")
	assert(not live.contains("breeze"))
	var builder: String = FileAccess.get_file_as_string("res://tests/kaji_plant_breeze_builder.gd")
	assert(not builder.contains("save_png(ORIGINAL"))
	assert(not builder.contains("save_png(ROOT + \"kaji_plant_leaves_still"))
	assert(not builder.contains("save_png(ROOT + \"kaji_plant_clean_plate"))
