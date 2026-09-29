@tool
class_name HealthBar
extends TextureProgressBar
## Ornate in-world health bar for Blade Dancer.
##
## Health is a CONTINUOUS value, so the fill can never be baked into sprite
## frames — a sheet would need a unique frame per percentage. Instead the bar is
## a stack of stretched child [TextureRect] layers, drawn in this order:
##   [b]Track[/b]     — dark recessed slot filling the window
##   [b]Fill[/b]      — the health sliver, width driven by value/max_value, with a
##                     travelling darker band over it (see _apply_flow)
##   [b]DrainSmear[/b]— trailing crimson chunk that shrinks after a hit
##   [b]BreathGlow[/b]— warm additive pulse while the bar is full
##   [b]Rail[/b]      — the thin gold rails stretched across the fill
##   [b]Caps[/b]      — the gold star cap bounding each end, tucked over the fill
##   [b]ImpactFlash[/b] — white-hot burst on the leading edge when health drops
##
## IMPORTANT — why the art is NOT on texture_under / texture_progress /
## texture_over: a [TextureProgressBar] raises its minimum size to those
## textures' size AND draws them at their natural pixel size instead of
## stretching them to the control. The result was that every bar was silently
## clamped to the art's width (128px) no matter what the scene asked for, and the
## gold rail (a 64px texture) stopped short of the bar's end with a hard edge.
## Drawing the layers as [TextureRect] children makes them stretch to the real
## control rect, so the frame always encapsulates the fill.
##
## The node still extends [TextureProgressBar] on purpose: the Range contract
## (value / max_value / visible / value_changed) used by every caller and test is
## unchanged.

const TRACK_TEXTURE: Texture2D = preload("res://assets/generated/health_bar_track.png")
const FILL_TEXTURE: Texture2D = preload("res://assets/generated/health_bar_fill.png")
## The bar's chrome is two pieces: the thin rail stretched across the bar and the
## gold star cap bounding each end. Both draw OVER the fill, so the rails read as
## two slim lines crossing the colour and the caps frame its ends.
##
## The rails are deliberately thin — 2px of their 16 — because the fill spans the
## bar's full height (see _window_rect): every row a rail does not cover is visible
## colour, so 20 of the 24 rows here read as fill.
const RAIL_TEXTURE: Texture2D = preload("res://assets/generated/health_bar_rail.png")
## The rail art's own height. It is drawn at that size, centred, rather than scaled
## to the bar: the pinstripe is a fixed decorative weight, not a proportional one.
const RAIL_NATURAL_HEIGHT: float = 16.0
## The end caps: a gold star with a teal gem, 48x48, facing outward to the left so
## the right-hand copy is mirrored. Drawn square at the bar's height, never larger
## than the art (upscaling painted gold only softens it).
const CAP_TEXTURE: Texture2D = preload("res://assets/generated/health_bar_cap_hd.png")
const CAP_NATURAL_SIZE: float = 48.0
## Never let the two caps close the window completely on a narrow bar.
const MIN_FILL_WINDOW: float = 12.0
const FLASH_TEXTURE: Texture2D = preload("res://assets/generated/health_bar_flash.png")
## The fill's flow: a tiny shader that multiplies a travelling darker band over the
## fill's colour, so it reads as moving rather than painted flat. See _apply_flow.
const FLOW_SHADER: Shader = preload("res://shaders/health_bar_flow.gdshader")

const ENEMY_FILL_TINT: Color = Color(0.86, 0.11, 0.09, 1.0)
const PLAYER_FILL_TINT: Color = Color(0.25, 0.7, 1.0, 1.0)

## The impact flash is a courtesy cue, not the event: it marks a hit without strobing
## a fast exchange. It was detuned hard once already — before that it was a full-white
## blob blooming past the bar — and read as too polite afterwards, so these sit between
## the two.
const FLASH_DURATION: float = 0.18
## Burst diameter as a multiple of the bar's height. 1.0 spans the whole bar, rather
## than the sliver of it the first detune left.
const FLASH_SCALE: float = 1.0
## Peak alpha the additive burst starts at before it fades out: bright, but still short
## of white so overlapping hits cannot stack into a white-out.
const FLASH_PEAK_ALPHA: float = 0.65
const DRAIN_SPEED: float = 0.9
const DRAIN_MIN_WIDTH: float = 0.6
const DRAIN_ALPHA: float = 0.55
const GLOW_PULSE_SPEED: float = 1.7
const GLOW_MIN_ALPHA: float = 0.05
const GLOW_MAX_ALPHA: float = 0.16

## Colour the (neutral) fill texture is multiplied by. Enemies are crimson; the
## player bar overrides this with the player damage-number blue.
@export var fill_tint: Color = ENEMY_FILL_TINT
## Bright impact flash at the leading edge whenever health drops.
@export var enable_impact_flash: bool = true
## Crimson trailing chunk that drains behind the fill after a hit.
@export var enable_drain_smear: bool = true
## Subtle warm glow while the bar is full ("breathing" full-health state).
@export var enable_breathing_glow: bool = true
## How many pixels each cap is pulled INWARD over the fill's ends. At 0 the gold
## stops exactly where the fill begins, so the bar's hard end is visible beside the
## cap; tucking the caps a couple of pixels over the fill puts that edge under the
## gold instead. Values are clamped so the pair can never eat the window on a
## narrow bar.
@export_range(0.0, 12.0, 0.5) var cap_overlap: float = 3.0
## Travelling darker band over the fill, so the colour reads as flowing rather than
## painted flat. Switch off for a still bar.
@export var enable_fill_flow: bool = true
## Bands that sweep across the fill per second.
@export_range(0.0, 2.0, 0.01) var fill_flow_speed: float = 0.35
## How much darker the trough of the band gets. 0 leaves a flat fill.
@export_range(0.0, 0.6, 0.01) var fill_flow_depth: float = 0.33
## How many bands span the fill's width.
@export_range(0.25, 4.0, 0.05) var fill_flow_bands: float = 1.0

var _track: TextureRect
var _fill: TextureRect
var _rail: TextureRect
var _cap_left: TextureRect
var _cap_right: TextureRect
var _flash: TextureRect
var _drain: TextureRect
var _glow: TextureRect
var _flash_tween: Tween

var _prev_ratio: float = 1.0
var _drain_ratio: float = 1.0
var _glow_phase: float = 0.0


func _ready() -> void:
	_build_layers()
	resized.connect(_layout)
	value_changed.connect(_on_value_changed)
	_prev_ratio = _current_ratio()
	_drain_ratio = _prev_ratio
	_layout()
	set_process((enable_drain_smear or enable_breathing_glow) and not Engine.is_editor_hint())


func _build_layers() -> void:
	# Deliberately clear the built-in art slots — see the class docstring. Leaving
	# them set both clamps the bar's size and stops the art from stretching.
	texture_under = null
	texture_progress = null
	texture_over = null
	nine_patch_stretch = false
	# The juice overlays must be able to draw outside the bar rect: the impact burst
	# is taller than the bar itself.
	clip_contents = false

	_track = _make_layer(TRACK_TEXTURE, "Track")
	_fill = _make_layer(FILL_TEXTURE, "Fill")
	_fill.modulate = fill_tint
	_apply_flow()

	if Engine.is_editor_hint():
		# No juice in the editor, just the static skin.
		_build_chrome()
		return

	if enable_drain_smear:
		_drain = _make_layer(FILL_TEXTURE, "DrainSmear")
		_drain.modulate = Color(0.62, 0.06, 0.05, DRAIN_ALPHA)
		_drain.visible = false
	if enable_breathing_glow:
		_glow = _make_layer(FILL_TEXTURE, "BreathGlow")
		# Tinted with the bar's own colour so a full player bar pulses blue, not white.
		_glow.modulate = Color(fill_tint.r, fill_tint.g, fill_tint.b, GLOW_MIN_ALPHA)
		var glow_mat: CanvasItemMaterial = CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glow.material = glow_mat
	_build_chrome()
	if enable_impact_flash:
		_flash = _make_layer(FLASH_TEXTURE, "ImpactFlash")
		_flash.stretch_mode = TextureRect.STRETCH_KEEP
		_flash.size = FLASH_TEXTURE.get_size()
		_flash.pivot_offset = FLASH_TEXTURE.get_size() * 0.5
		_flash.visible = false
		var flash_mat: CanvasItemMaterial = CanvasItemMaterial.new()
		flash_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_flash.material = flash_mat
		# The burst is a soft radial blob that gets minified hard (256px of texture
		# into a burst a couple of bar-heights across), so it keeps linear
		# filtering — nearest would make it sparkle.
		_flash.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## The fill layer's texture filter, stretch and tint are all set by _make_layer and
## the caller; the flow is the only thing it owns. The shader reads TIME itself, so
## there is nothing to animate in script and no per-frame cost here.
func _apply_flow() -> void:
	if _fill == null:
		return
	if not enable_fill_flow or Engine.is_editor_hint():
		_fill.material = null
		return
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLOW_SHADER
	mat.set_shader_parameter("flow_speed", fill_flow_speed)
	mat.set_shader_parameter("flow_depth", fill_flow_depth)
	mat.set_shader_parameter("flow_bands", fill_flow_bands)
	_fill.material = mat


func _make_layer(tex: Texture2D, layer_name: String) -> TextureRect:
	var layer: TextureRect = TextureRect.new()
	layer.name = layer_name
	layer.texture = tex
	# CRITICAL: without EXPAND_IGNORE_SIZE a TextureRect's minimum size is its
	# texture's size, so a layer could never be made narrower than its art — the
	# fill overflowed past the end cap and the rail could not shrink to a small
	# bar. This makes the layer stretch to whatever rect we give it.
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# SCALE, not TILE: these layers are resampled into a window narrower and taller
	# than the art, and the art is a vertical gradient. Tiling would clip it to the
	# top of the ramp and show the wrong end of the colour; scaling shows the whole
	# ramp, compressed.
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	# Linear: the window content is a smooth gradient being resampled, so nearest
	# would band it rather than sharpen it.
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


## The chrome is the top layer of the skin, so it is added last: the rail stretched
## across the bar and the two caps at its ends. Both draw OVER the fill, so the rails
## read as thin gold lines crossing the colour while the caps bound its ends. The
## right-hand cap is mirrored, because the art faces outward to the left.
func _build_chrome() -> void:
	_rail = _make_layer(RAIL_TEXTURE, "Rail")
	_cap_left = _make_layer(CAP_TEXTURE, "CapLeft")
	_cap_right = _make_layer(CAP_TEXTURE, "CapRight")
	_cap_right.flip_h = true


## Where the fill lives: the bar's FULL height between the two caps, in bar-local
## coordinates.
##
## Deliberately not the art's hollow. Every frame art leaves only about a third of
## its height hollow, so confining the fill to the hollow (as an earlier version
## did) made the health read as a thin line inside a large ornament and the bar
## looked empty. Spanning the full height lets the colour fill the chrome, with the
## thin rails crossing it as decoration, while the caps still bound its ends.
func _window_rect() -> Rect2:
	var cap: float = _cap_width()
	var window_width: float = maxf(size.x - cap * 2.0, 0.0)
	return Rect2(cap, 0.0, window_width, size.y)


## Drawn width of one cap, in bar pixels. Clamped so the two ornaments can never
## swallow the whole bar on a narrow one.
func _cap_width() -> float:
	var cap_h: float = _cap_size()
	if cap_h <= 0.0:
		return 0.0
	var art: Vector2 = CAP_TEXTURE.get_size()
	var natural: float = cap_h * (art.x / maxf(art.y, 1.0))
	var limit: float = maxf((size.x - MIN_FILL_WINDOW) * 0.5, 0.0)
	return minf(natural, limit)


## How far each cap is tucked over the window, in bar pixels: the configured
## cap_overlap, clamped so the two caps cannot cover more than 70% of the window
## between them (a narrow bar must still show colour).
func _cap_overlap(window_width: float) -> float:
	return clampf(cap_overlap, 0.0, window_width * 0.35)


## Height the caps are drawn at: the bar's own height, never more than the art
## (upscaling painted gold only softens it).
func _cap_size() -> float:
	if size.y <= 0.0:
		return 0.0
	return minf(size.y, CAP_NATURAL_SIZE)


func _layout() -> void:
	var window: Rect2 = _window_rect()
	if _track != null:
		_track.position = window.position
		_track.size = window.size
	_update_fill_rect()
	_update_drain_rect()
	if _glow != null:
		_glow.position = window.position
		_glow.size = window.size
	var cap_w: float = _cap_width()
	var art: Vector2 = CAP_TEXTURE.get_size()
	var cap_h: float = cap_w * (art.y / maxf(art.x, 1.0))
	var overlap: float = _cap_overlap(window.size.x)
	if _cap_left != null:
		_cap_left.size = Vector2(cap_w, cap_h)
		_cap_left.position = Vector2(overlap, (size.y - cap_h) * 0.5)
	if _cap_right != null:
		_cap_right.size = Vector2(cap_w, cap_h)
		_cap_right.position = Vector2(size.x - cap_w - overlap, (size.y - cap_h) * 0.5)
	if _rail != null:
		# The rail is drawn at its own weight, centred in the bar, and spans only the
		# window so it meets the caps rather than running under them.
		var rail_h: float = minf(size.y, RAIL_NATURAL_HEIGHT)
		_rail.position = Vector2(cap_w, (size.y - rail_h) * 0.5)
		_rail.size = Vector2(maxf(size.x - cap_w * 2.0, 0.0), rail_h)


func _on_value_changed(new_value: float) -> void:
	var health_ratio: float = _ratio_of(new_value)
	if health_ratio < _prev_ratio - 0.0005:
		_trigger_hit(_prev_ratio, health_ratio)
	elif health_ratio > _prev_ratio + 0.0005:
		# Healing: snap the drain marker up so a stale chunk never lingers.
		_drain_ratio = maxf(_drain_ratio, health_ratio)
	_prev_ratio = health_ratio
	_update_fill_rect()


func _trigger_hit(from_ratio: float, to_ratio: float) -> void:
	if enable_drain_smear and _drain != null:
		_drain_ratio = maxf(_drain_ratio, from_ratio)
		_update_drain_rect()
	if enable_impact_flash and _flash != null:
		_play_flash(to_ratio)


func _play_flash(edge_ratio: float) -> void:
	if _flash == null:
		return
	var window: Rect2 = _window_rect()
	var tex_size: Vector2 = FLASH_TEXTURE.get_size()
	var burst: float = maxf(window.size.y, 1.0) * FLASH_SCALE
	var s: float = burst / maxf(tex_size.x, 1.0)
	_flash.pivot_offset = tex_size * 0.5
	_flash.position = Vector2(window.position.x + edge_ratio * window.size.x, window.position.y + window.size.y * 0.5) - tex_size * 0.5
	_flash.scale = Vector2(s, s)
	_flash.visible = true
	_flash.modulate = Color(1, 1, 1, FLASH_PEAK_ALPHA)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flash_tween.tween_callback(func() -> void: _flash.visible = false)


## The fill is a stretched layer confined to the window between the fleurons: the
## gold ends always stay clear of it and the colour can never leave the frame.
func _update_fill_rect() -> void:
	if _fill == null:
		return
	var window: Rect2 = _window_rect()
	_fill.position = window.position
	_fill.size = Vector2(maxf(window.size.x * _current_ratio(), 0.0), window.size.y)


func _update_drain_rect() -> void:
	if _drain == null:
		return
	var window: Rect2 = _window_rect()
	var from_x: float = window.position.x + _prev_ratio * window.size.x
	var to_x: float = window.position.x + _drain_ratio * window.size.x
	var width: float = maxf(to_x - from_x, 0.0)
	_drain.position = Vector2(from_x, window.position.y)
	_drain.size = Vector2(width, window.size.y)
	_drain.visible = width > DRAIN_MIN_WIDTH
	if _drain.visible and window.size.x > 0.0:
		# Fade the smear out as it shrinks, so it reads as trailing loss rather
		# than a solid bar.
		var fade: float = clampf(width / (window.size.x * 0.35), 0.0, 1.0)
		_drain.modulate.a = DRAIN_ALPHA * fade


func _process(delta: float) -> void:
	var target: float = _current_ratio()
	if _drain != null and _drain_ratio > target + 0.0005:
		_drain_ratio = maxf(target, _drain_ratio - DRAIN_SPEED * delta)
		_update_drain_rect()
	if _glow != null:
		_glow_phase += delta * GLOW_PULSE_SPEED
		var full: bool = target >= 0.999
		var target_alpha: float = 0.0
		if full:
			var t: float = 0.5 + 0.5 * sin(_glow_phase)
			target_alpha = lerpf(GLOW_MIN_ALPHA, GLOW_MAX_ALPHA, t)
		_glow.modulate.a = lerpf(_glow.modulate.a, target_alpha, 0.12)


func _current_ratio() -> float:
	return _ratio_of(value)


func _ratio_of(v: float) -> float:
	if max_value <= 0.0:
		return 0.0
	return clampf(v / max_value, 0.0, 1.0)