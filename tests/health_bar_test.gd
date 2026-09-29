class_name HealthBarTest extends Node
## Covers the ornate HealthBar component: the Range contract every existing
## caller/test relies on, the layered nine-patch skin, and the hit juice
## (impact flash + drain smear) plus the full-health breathing glow.

func _make_bar(w: float, h: float, val: float, tint: Color = HealthBar.ENEMY_FILL_TINT) -> HealthBar:
	var bar: HealthBar = HealthBar.new()
	bar.size = Vector2(w, h)
	bar.max_value = 100.0
	bar.value = val
	bar.fill_tint = tint
	add_child(bar)
	return bar

func test_range_contract_and_enemy_tint() -> void:
	var bar: HealthBar = _make_bar(68.0, 10.0, 65.0)
	assert(bar is Range, "HealthBar must stay a Range so value/max_value/visible keep working")
	assert(is_equal_approx(bar.value, 65.0))
	assert(is_equal_approx(bar.max_value, 100.0))
	assert(bar._fill.modulate.is_equal_approx(HealthBar.ENEMY_FILL_TINT), "the enemy fill tint must reach the fill layer")
	bar.free()

func test_player_tint_overrides_enemy_red() -> void:
	var bar: HealthBar = _make_bar(76.0, 10.0, 100.0, HealthBar.PLAYER_FILL_TINT)
	assert(bar._fill.modulate.is_equal_approx(HealthBar.PLAYER_FILL_TINT), "the player bar must use the player blue")
	bar.free()

func test_skin_layers_and_chrome() -> void:
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	# The art must NOT go through the built-in slots: a TextureProgressBar clamps
	# its size to those textures and draws them unstretched.
	assert(bar.texture_under == null and bar.texture_progress == null and bar.texture_over == null, "the built-in art slots must stay empty")
	assert(bar._track != null and bar._fill != null, "track and fill layers must both exist")
	assert(bar._rail != null and bar._cap_left != null and bar._cap_right != null, "the chrome must be a rail plus a cap at each end")
	for layer: TextureRect in [bar._track, bar._fill, bar._rail, bar._cap_left, bar._cap_right]:
		assert(layer.expand_mode == TextureRect.EXPAND_IGNORE_SIZE, "every layer must ignore its texture's minimum size, or it cannot be shrunk to the window")
	assert(bar.clip_contents == false, "the impact burst must be allowed to draw outside the bar rect")
	assert(bar._rail.texture == HealthBar.RAIL_TEXTURE, "the rail layer must use the rail art")
	assert(bar._cap_left.texture == HealthBar.CAP_TEXTURE, "the left cap must use the cap art")
	assert(bar._rail.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "painted gold must be sampled smoothly, not quantised into blocks")
	# The caps bound the bar, and the right one is mirrored: the cap art faces outward
	# to the left, so the same texture at the far end would point back into the bar.
	assert(bar._cap_right.flip_h, "the right cap must mirror the left")
	# The caps are tucked a few pixels over the window, so the bar's hard end sits
	# under the gold instead of peeking out beside the cap.
	assert(bar.cap_overlap > 0.0, "the caps must overlap the fill at all")
	assert(is_equal_approx(bar._cap_left.position.x, bar.cap_overlap), "the left cap must be pulled in by cap_overlap, got %f" % bar._cap_left.position.x)
	assert(bar._cap_left.position.x + bar._cap_left.size.x > bar._window_rect().position.x, "the left cap must cover the window's first pixels, or the bar's edge shows through")
	assert(is_equal_approx(bar._cap_right.position.x + bar._cap_right.size.x, bar.size.x - bar.cap_overlap), "the right cap must be pulled in by cap_overlap too, got %f" % (bar._cap_right.position.x + bar._cap_right.size.x))
	assert(bar._cap_right.position.x < bar._window_rect().position.x + bar._window_rect().size.x, "the right cap must cover the window's last pixels")
	# A huge overlap must not eat the window.
	assert(bar._cap_overlap(20.0) <= 7.001, "the overlap must be clamped so the pair cannot swallow the window, got %f" % bar._cap_overlap(20.0))
	var window: Rect2 = bar._window_rect()
	assert(window.position.x > 0.0 and window.size.x > 0.0, "the window must sit inside the caps, got %s" % str(window))
	assert(is_equal_approx(window.position.x, bar._cap_width()), "the window must start where the left cap ends")
	assert(is_equal_approx(window.position.x + window.size.x, bar.size.x - bar._cap_width()), "the window must end where the right cap begins")
	# The rail spans that window, so it meets the caps instead of running under them.
	assert(is_equal_approx(bar._rail.position.x, window.position.x), "the rail must start where the window does")
	assert(is_equal_approx(bar._rail.size.x, window.size.x), "the rail must span the window")
	# The fill must stay inside the window, never under the gold.
	assert(is_equal_approx(bar._fill.position.x, window.position.x), "the fill must start at the window's left edge")
	assert(bar._fill.size.x <= window.size.x + 0.001, "the fill must never overrun the window")
	bar.free()

func test_cap_draws_at_the_bars_height_and_never_upscales() -> void:
	# The cap is painted gold, 48x48: on a 24px bar it draws at half size, on a short
	# bar it shrinks with the bar, and on a tall one it stops at the art rather than
	# being blown up (upscaling only softens it).
	assert(HealthBar.CAP_TEXTURE.get_size() == Vector2(48.0, 48.0), "the cap art must stay a 48x48 square, got %s" % str(HealthBar.CAP_TEXTURE.get_size()))
	assert(is_equal_approx(HealthBar.RAIL_NATURAL_HEIGHT, HealthBar.RAIL_TEXTURE.get_size().y), "RAIL_NATURAL_HEIGHT must match the rail art's height, got %f against %f" % [HealthBar.RAIL_NATURAL_HEIGHT, HealthBar.RAIL_TEXTURE.get_size().y])
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	assert(is_equal_approx(bar._cap_size(), 24.0), "on a 24px bar the cap must draw at the bar's height, got %f" % bar._cap_size())
	assert(is_equal_approx(bar._cap_width(), bar._cap_size()), "a square cap must be as wide as it is tall")
	var short: HealthBar = _make_bar(128.0, 16.0, 100.0)
	assert(is_equal_approx(short._cap_size(), 16.0), "a short bar must draw a smaller cap, got %f" % short._cap_size())
	assert(short._cap_size() < bar._cap_size(), "the cap must shrink with the bar")
	var tall: HealthBar = _make_bar(200.0, 64.0, 100.0)
	assert(is_equal_approx(tall._cap_size(), HealthBar.CAP_NATURAL_SIZE), "a tall bar must not upscale the cap past the art, got %f" % tall._cap_size())
	assert(tall._cap_width() < tall._window_rect().size.x, "the caps must not swallow a wide bar")
	tall.free()
	short.free()
	bar.free()

func test_fill_spans_the_chromes_full_height() -> void:
	# Every frame art leaves only about a third of its height hollow, so confining the
	# fill to the hollow left the health reading as a thin line inside a large
	# ornament. The fill now spans the bar's full height between the caps and the
	# chrome draws over it: the colour fills the bar, with the rails crossing it.
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	var window: Rect2 = bar._window_rect()
	assert(is_equal_approx(window.position.y, 0.0), "the fill must start at the top of the bar, got %f" % window.position.y)
	assert(is_equal_approx(window.size.y, bar.size.y), "the fill must span the bar's full height, got %f of %f" % [window.size.y, bar.size.y])
	assert(is_equal_approx(window.size.x, bar.size.x - bar._cap_width() * 2.0), "the window must span the bar between the two caps, got %f" % window.size.x)
	assert(is_equal_approx(bar._fill.size.y, window.size.y), "the fill must fill the window's height")
	# The rail is thin by design: most of its height must be open. Measured off the
	# art itself, down its transparent middle, so a future fat rail fails here rather
	# than quietly shrinking the colour.
	var img: Image = HealthBar.RAIL_TEXTURE.get_image()
	var rail_rows: int = 0
	for y in img.get_height():
		if img.get_pixel(img.get_width() / 2, y).a > 0.05:
			rail_rows += 1
	assert(float(img.get_height() - rail_rows) >= float(img.get_height()) * 0.7, "the rail must cover well under a third of its own height, leaving %d of %d rows open" % [img.get_height() - rail_rows, img.get_height()])
	assert(bar._rail.size.y < bar.size.y, "the rail must not fill the bar's whole height, or no colour shows above it")
	bar.free()

func test_narrow_bar_keeps_a_window() -> void:
	# A narrow bar must not let the two fleurons meet in the middle: the cap is
	# clamped so MIN_FILL_WINDOW of fill always survives.
	var bar: HealthBar = _make_bar(30.0, 16.0, 100.0)
	var window: Rect2 = bar._window_rect()
	assert(window.size.x >= HealthBar.MIN_FILL_WINDOW - 0.001, "a narrow bar must keep at least MIN_FILL_WINDOW of window, got %f" % window.size.x)
	assert(bar._fill.size.x > 0.0, "a full narrow bar must still show fill")
	bar.free()

func test_impact_flash_is_kept_subtle() -> void:
	# The flash is a courtesy cue, not the event: an additive blob at full white
	# blooming several times the bar height was reported as eye-straining during
	# fast exchanges.
	assert(HealthBar.FLASH_PEAK_ALPHA <= 0.75, "the impact flash must not start near full white")
	assert(HealthBar.FLASH_SCALE <= 2.0, "the burst must stay near the bar's height instead of blooming over the screen")
	var bar: HealthBar = _make_bar(68.0, 10.0, 100.0)
	bar._play_flash(0.5)
	assert(bar._flash.modulate.a <= HealthBar.FLASH_PEAK_ALPHA + 0.001, "a fresh burst must respect the peak alpha")
	bar.free()

func test_bar_keeps_its_configured_width() -> void:
	# Regression: the art textures are 128px wide, and a TextureProgressBar used to
	# raise its minimum size to match — every bar was silently forced to 128px and
	# ignored the width its scene asked for.
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	assert(is_equal_approx(bar.size.x, 128.0), "the bar must keep the width it was given, got %s" % str(bar.size))
	assert(is_equal_approx(bar._rail.size.x + bar._cap_width() * 2.0, 128.0), "the chrome must span the whole bar width")
	var wide: HealthBar = _make_bar(200.0, 24.0, 100.0)
	assert(is_equal_approx(wide.size.x, 200.0), "a wider bar must keep its width too")
	assert(is_equal_approx(wide._rail.size.x + wide._cap_width() * 2.0, 200.0), "the chrome must stretch to the wider bar")
	assert(wide._window_rect().size.x > bar._window_rect().size.x, "a wider bar must lengthen the window, not the caps")
	assert(wide._cap_width() < wide._window_rect().size.x, "the caps must not swallow a wide bar")
	wide.free()
	bar.free()

func test_fill_width_tracks_health_ratio() -> void:
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	var window: Rect2 = bar._window_rect()
	assert(is_equal_approx(bar._fill.size.x, window.size.x), "a full bar's fill must span the window, got %s" % str(bar._fill.size.x))
	bar.value = 25.0
	assert(is_equal_approx(bar._fill.size.x, window.size.x * 0.25), "the fill must be 25%% of the window, got %s" % str(bar._fill.size.x))
	assert(is_equal_approx(bar._fill.position.x, window.position.x), "the fill must stay anchored at the window's left edge")
	bar.free()

func test_health_drop_fires_flash_and_starts_drain() -> void:
	var bar: HealthBar = _make_bar(68.0, 10.0, 100.0)
	bar.value = 40.0
	assert(bar._flash.visible, "a health drop must fire the impact flash")
	assert(is_equal_approx(bar._drain_ratio, 1.0), "the drain marker must hold at the old fill edge")
	bar._process(0.05)
	assert(bar._drain.visible, "the drain smear must become visible behind the new edge")
	assert(bar._drain_ratio < 1.0, "the drain marker must decay toward the new fill value")
	bar.free()

func test_impact_flash_centres_on_the_new_fill_edge() -> void:
	var bar: HealthBar = _make_bar(128.0, 24.0, 100.0)
	bar._play_flash(0.5)
	var tex: float = HealthBar.FLASH_TEXTURE.get_size().x
	var centre: Vector2 = bar._flash.position + Vector2(tex, tex) * 0.5
	var window: Rect2 = bar._window_rect()
	var expected: Vector2 = Vector2(window.position.x + 0.5 * window.size.x, window.position.y + window.size.y * 0.5)
	assert(centre.is_equal_approx(expected), "the burst centre must land on the fill edge inside the window, got %s of %s" % [str(centre), str(expected)])
	var expected_scale: float = (window.size.y * HealthBar.FLASH_SCALE) / tex
	assert(is_equal_approx(bar._flash.scale.x, expected_scale), "the burst must scale with the window height")
	bar.free()

func test_healing_snaps_the_drain_marker_away() -> void:
	var bar: HealthBar = _make_bar(68.0, 10.0, 100.0)
	bar.value = 40.0
	bar._process(0.1)
	assert(bar._drain_ratio < 1.0, "the drain marker should be trailing after a hit")
	bar.value = 100.0
	assert(bar._drain_ratio >= 1.0 - 0.0005, "healing must snap the drain marker up so no stale chunk lingers")
	bar.free()

func test_fill_flow_is_a_subtle_travelling_band() -> void:
	# The flow is a band that travels, not a glow: it must be driven by TIME, it must
	# multiply the fill's own colour so one material serves both tints, it must stay a
	# shallow darkening rather than a black-out, and it must be switchable off.
	assert(HealthBar.FLOW_SHADER != null, "the flow shader must load")
	assert(HealthBar.FLOW_SHADER.code.contains("TIME"), "the band must read TIME, or it will not travel")
	assert(HealthBar.FLOW_SHADER.code.contains("COLOR.rgb"), "the band must multiply the fill's colour rather than replace it")
	assert(not HealthBar.FLOW_SHADER.code.contains("UV.y"), "the band must stay a straight travelling stripe, not a curled wave")
	var bar: HealthBar = _make_bar(108.8, 24.0, 100.0)
	assert(bar._fill.material is ShaderMaterial, "an enabled flow must give the fill a shader material")
	var mat: ShaderMaterial = bar._fill.material
	assert(mat.shader == HealthBar.FLOW_SHADER, "the fill must use the flow shader")
	var depth: float = float(mat.get_shader_parameter("flow_depth"))
	assert(depth > 0.0 and depth <= 0.4, "the flow must darken the colour without blacking it out, got %f" % depth)
	assert(is_equal_approx(float(mat.get_shader_parameter("flow_speed")), bar.fill_flow_speed), "the exported speed must reach the shader")
	assert(is_equal_approx(float(mat.get_shader_parameter("flow_bands")), bar.fill_flow_bands), "the exported band count must reach the shader")
	# Switching it off must leave the flat fill exactly as it was.
	var flat: HealthBar = HealthBar.new()
	flat.size = Vector2(108.8, 24.0)
	flat.enable_fill_flow = false
	add_child(flat)
	assert(flat._fill.material == null, "a disabled flow must leave a plain fill layer")
	flat.free()
	bar.free()

func test_breathing_glow_only_while_full() -> void:
	var bar: HealthBar = _make_bar(68.0, 10.0, 100.0)
	assert(bar._glow != null, "the breathing glow overlay must exist")
	for i in range(30):
		bar._process(0.05)
	assert(bar._glow.modulate.a > 0.0, "a full bar must glow")
	bar.value = 40.0
	for i in range(60):
		bar._process(0.05)
	assert(bar._glow.modulate.a < 0.02, "a damaged bar must not glow")
	bar.free()