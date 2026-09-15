extends Node2D

## THROWAWAY VISUAL MOCKUP — not wired into gameplay. Delete when done deciding.
## Demonstrates the Brotato-style layout: separate head / torso / feet, no arms,
## with a single hand baked directly into the sword drawing.

func _draw() -> void:
	var outline: Color = Color("1a1512")
	var hair_dark: Color = Color("3d2a1a")
	var hair_light: Color = Color("5a3d24")
	var skin: Color = Color("e8b48a")
	var scarf: Color = Color("2f6fa8")
	var scarf_dark: Color = Color("1f4d78")
	var leather: Color = Color("7a5233")
	var leather_dark: Color = Color("543a24")
	var boot: Color = Color("4a3222")
	var boot_dark: Color = Color("2e1f15")
	var wood: Color = Color("b8945c")
	var wood_dark: Color = Color("6b4e2e")

	# --- FEET (two separate stubs, floating gap below torso) ---
	draw_rect(Rect2(-13.0, 22.0, 11.0, 9.0), outline)
	draw_rect(Rect2(-11.5, 23.0, 8.0, 6.5), boot)
	draw_rect(Rect2(-11.5, 27.0, 8.0, 2.5), boot_dark)
	draw_rect(Rect2(2.0, 22.0, 11.0, 9.0), outline)
	draw_rect(Rect2(3.5, 23.0, 8.0, 6.5), boot)
	draw_rect(Rect2(3.5, 27.0, 8.0, 2.5), boot_dark)

	# --- TORSO (separate block, floating gap above feet, gap below head) ---
	draw_rect(Rect2(-16.0, -8.0, 32.0, 26.0), outline)
	draw_rect(Rect2(-13.0, -5.0, 26.0, 20.0), leather)
	draw_rect(Rect2(-13.0, 6.0, 26.0, 9.0), leather_dark)
	# Belt buckle accent.
	draw_rect(Rect2(-4.0, 8.0, 8.0, 4.0), Color("c9a24d"))
	# Scarf wrap.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14.0, -8.0), Vector2(14.0, -8.0), Vector2(10.0, 2.0),
		Vector2(0.0, 6.0), Vector2(-10.0, 2.0)
	]), scarf_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -7.0), Vector2(11.0, -7.0), Vector2(8.0, 0.0),
		Vector2(0.0, 3.0), Vector2(-8.0, 0.0)
	]), scarf)
	# Little patch details for the "ragged" look.
	draw_rect(Rect2(-11.0, 12.0, 4.0, 4.0), Color("94724a"))
	draw_rect(Rect2(6.0, 3.0, 4.0, 3.0), Color("94724a"))

	# --- HEAD (separate blob, floating gap above torso) ---
	var head_center: Vector2 = Vector2(0.0, -30.0)
	draw_circle(head_center, 15.0, outline)
	draw_circle(head_center, 12.5, skin)
	# Simple face.
	draw_circle(head_center + Vector2(-5.0, 1.0), 1.6, outline)
	draw_circle(head_center + Vector2(5.0, 1.0), 1.6, outline)
	draw_arc(head_center + Vector2(0.0, 6.0), 4.0, 0.15 * PI, 0.85 * PI, 8, outline, 1.4, true)
	# Spiky brown hair.
	var hair_points: PackedVector2Array = PackedVector2Array([
		Vector2(-14.0, -8.0), Vector2(-10.0, -20.0), Vector2(-5.0, -10.0),
		Vector2(-2.0, -22.0), Vector2(3.0, -9.0), Vector2(7.0, -21.0),
		Vector2(11.0, -8.0), Vector2(14.0, -16.0), Vector2(15.0, -2.0),
		Vector2(-15.0, -2.0)
	])
	var hair_offset: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in hair_points: hair_offset.append(point + head_center)
	draw_colored_polygon(hair_offset, hair_dark)
	draw_colored_polygon(PackedVector2Array([
		head_center + Vector2(-2.0, -22.0), head_center + Vector2(3.0, -9.0), head_center + Vector2(7.0, -21.0)
	]), hair_light)

	# --- SWORD + HAND (one unit, hand baked directly into the weapon) ---
	# Static angled pose for this mockup — in real gameplay this would ride
	# the existing sword swing transform, no separate rigging needed.
	var grip_point: Vector2 = Vector2(16.0, 4.0)
	var blade_dir: Vector2 = Vector2(0.55, -0.85).normalized()
	var blade_tip: Vector2 = grip_point + blade_dir * 46.0
	var hilt_base: Vector2 = grip_point - blade_dir * 8.0
	# Blade.
	var blade_perp: Vector2 = blade_dir.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		hilt_base + blade_perp * 3.5, blade_tip + blade_perp * 1.5, blade_tip - blade_perp * 1.5, hilt_base - blade_perp * 3.5
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		hilt_base + blade_perp * 2.2, blade_tip + blade_perp * 0.6, blade_tip - blade_perp * 0.6, hilt_base - blade_perp * 2.2
	]), wood)
	draw_line(hilt_base, blade_tip, wood_dark, 1.0, true)
	# Handle.
	draw_line(hilt_base, hilt_base - blade_dir * 10.0, outline, 6.0, true)
	draw_line(hilt_base, hilt_base - blade_dir * 10.0, wood_dark, 3.6, true)
	# Crossguard.
	draw_line(hilt_base + blade_perp * 6.0, hilt_base - blade_perp * 6.0, outline, 3.0, true)
	# Hand — baked directly onto the grip, part of the weapon unit, not the body.
	draw_circle(grip_point, 6.5, outline)
	draw_circle(grip_point, 5.0, skin)

func _ready() -> void:
	queue_redraw()
