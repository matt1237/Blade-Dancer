extends Node2D
## Dev preview for the ornate HealthBar component: renders it at several fill
## levels and triggers one hit so the impact flash + drain smear are visible.
## Not part of the game — safe to delete.

func _ready() -> void:
	_build(Vector2(280.0, 40.0), Vector2(108.8, 24.0), 55.0, false, "").scale = Vector2(5.0, 5.0)
	_build(Vector2(280.0, 220.0), Vector2(108.8, 24.0), 100.0, true, "").scale = Vector2(5.0, 5.0)
	_build(Vector2(240.0, 420.0), Vector2(108.8, 24.0), 100.0, false, "100%")
	_build(Vector2(240.0, 464.0), Vector2(108.8, 24.0), 65.0, false, "65%")
	_build(Vector2(240.0, 508.0), Vector2(108.8, 24.0), 30.0, false, "30%")
	_build(Vector2(240.0, 552.0), Vector2(108.8, 24.0), 8.0, false, "8%")
	_build(Vector2(240.0, 596.0), Vector2(108.8, 24.0), 100.0, true, "player 100%")
	_build(Vector2(240.0, 640.0), Vector2(200.0, 24.0), 100.0, false, "wider bar 200px")
	_probe()

func _probe() -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(260, 40)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.30, 0.30, 0.30)
	bg.size = Vector2(260.0, 40.0)
	vp.add_child(bg)
	var bar: HealthBar = HealthBar.new()
	bar.size = Vector2(108.8, 24.0)
	bar.position = Vector2(75.6, 8.0)
	bar.max_value = 100.0
	bar.value = 55.0
	vp.add_child(bar)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = vp.get_texture().get_image()
	print("PROBE bar.size=", bar.size, " window=", bar._window_rect(), " track=", bar._track.size, " fill=", bar._fill.size, " rail=", bar._rail.size, " cap=", bar._cap_left.size, " cap_left_x=", bar._cap_left.position.x, " cap_right_edge=", bar._cap_right.position.x + bar._cap_right.size.x, " cap_mirrored=", bar._cap_right.flip_h)
	var ramp: String = " .:-=+*#%@"
	print("PROBE bar spans x%.1f..%.1f" % [bar.position.x, bar.position.x + bar.size.x])
	for y in range(6, 39):
		var line: String = ""
		for x in range(20, 241):
			var c: Color = img.get_pixel(x, y)
			var v: float = (c.r + c.g + c.b) / 3.0 * c.a
			line += ramp[clampi(int(v * 9.999), 0, 9)]
		print("y%02d |%s|" % [y, line])
	# A still frame cannot show motion, so capture the fill twice, 2.2 seconds apart
	# (0.35 sweeps/s x 2.2s = 0.77 of a band) and print both: if the shading pattern
	# changes, the band is travelling.
	var bright_first: String = _fill_samples(img)
	await get_tree().create_timer(2.2).timeout
	await get_tree().process_frame
	var bright_second: String = _fill_samples(vp.get_texture().get_image())
	print("FLOW t0 fill luminance = ", bright_first)
	print("FLOW t2 fill luminance = ", bright_second)
	print("FLOW band travelled = ", bright_first != bright_second)
	# The impact flash only exists for FLASH_DURATION after a hit, so trigger one here
	# and read the pixels while the burst is still at its peak. The constants alone
	# cannot say whether it whites out; the reading has to come off a live frame. Run
	# this scene for ~2300ms so the final screenshot also lands inside the flash.
	bar.value = 30.0
	await get_tree().process_frame
	await get_tree().process_frame
	var hit_img: Image = vp.get_texture().get_image()
	var edge_x: int = int(bar.position.x + bar._window_rect().position.x + 0.30 * bar._window_rect().size.x)
	var at_edge: Color = hit_img.get_pixel(edge_x, 20)
	var away: Color = hit_img.get_pixel(edge_x - 14, 20)
	print("FLASH burst=%.1fpx on a %.1fpx bar, peak_alpha=%.2f, duration=%.2fs, visible=%s" % [bar._window_rect().size.y * HealthBar.FLASH_SCALE, bar._window_rect().size.y, HealthBar.FLASH_PEAK_ALPHA, HealthBar.FLASH_DURATION, str(bar._flash.visible)])
	print("FLASH luminance at the edge=%.3f (%s), 14px inside the fill=%.3f" % [(at_edge.r + at_edge.g + at_edge.b) / 3.0, str(at_edge), (away.r + away.g + away.b) / 3.0])


## Luminance across the fill, left to right, as a compact readable string.
func _fill_samples(img: Image) -> String:
	var out: String = ""
	for x in range(100, 134, 4):
		var c: Color = img.get_pixel(x, 20)
		out += "%.2f " % ((c.r + c.g + c.b) / 3.0)
	return out.strip_edges()

func _build(pos: Vector2, bar_size: Vector2, value: float, is_player: bool, label_text: String) -> HealthBar:
	var bar: HealthBar = HealthBar.new()
	bar.size = bar_size
	bar.position = pos
	bar.max_value = 100.0
	bar.value = value
	bar.fill_tint = Color(0.25, 0.7, 1.0) if is_player else Color(0.86, 0.11, 0.09)
	add_child(bar)
	var label: Label = Label.new()
	label.text = label_text
	label.position = pos + Vector2(bar_size.x + 20.0, -6.0)
	add_child(label)
	return bar