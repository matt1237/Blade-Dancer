class_name CauldronCatchGame extends Control

## Cauldron Catch — a 30-second Kitchen tab arcade minigame. Catch the Wild
## Turkey Stew ingredients (Turkey, Mushroom) falling from the sky in the
## cauldron; avoid the spiky purple fruit. Reachable from Home > Kitchen.
## Runs with PROCESS_MODE_ALWAYS so it keeps animating while the Home
## screen's game tree is paused, matching the PauseMenu pattern.

signal closed(final_score: int, is_new_high_score: bool)
signal round_finished(final_score: int, is_new_high_score: bool)
signal quality_result(passed: bool, catch_rate: float)

enum FoodKind { TURKEY, MUSHROOM, BAD_FRUIT, CLOCK_SLOW, CLOCK_FAST, ANGEL_SHIELD }

const TURKEY_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_turkey_frame_0.png")
const MUSHROOM_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_mushroom_frame_0.png")
const BAD_FRUIT_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_bad_fruit_frame_0.png")
const CAULDRON_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_cauldron_frame_0.png")
const CLOCK_SLOW_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_clock_slow_frame_0.png")
const CLOCK_FAST_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_clock_fast_frame_0.png")
const ANGEL_SHIELD_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_angel_shield_frame_0.png")

@export_category("Timing")
## Total run length in seconds.
@export var run_duration: float = 30.0
## Shortest and longest gap between FOOD spawns only — power-ups run on their
## own completely separate timer below and never compete with these slots.
@export var spawn_interval_min: float = 0.45
@export var spawn_interval_max: float = 0.95

@export_category("Fall Speeds (pixels/sec)")
@export var slow_speed: float = 100.0
@export var medium_speed: float = 140.0
## Slowed 15% from the original 290 — the fastest tier was too quick to react to.
@export var fast_speed: float = 180.0
## Chance a spawned item is the bad spiky fruit rather than a good ingredient.
@export_range(0.0, 1.0, 0.05) var bad_food_chance: float = 0.3

@export_category("Cute Spin (purely visual)")
## Chance a falling food gets a slow lazy spin as it falls.
@export_range(0.0, 1.0, 0.01) var spin_chance: float = 0.45
@export var spin_speed_min_deg: float = 60.0
@export var spin_speed_max_deg: float = 160.0
## Horizontal sway for spinning objects while they fall. Kept deliberately
## small so the wave adds life without making catches feel unpredictable.
@export_range(0.0, 32.0, 1.0) var spinning_wave_amplitude: float = 20.0
@export_range(0.1, 8.0, 0.1) var spinning_wave_frequency: float = 2.4

@export_category("Power-up Spawner (fully separate from food)")
## Power-ups run on their own independent timer/roll — completely separate
## from the food spawner, so they never eat into food spawn slots and food
## keeps spawning at its normal rate no matter what. Most rolls on this timer
## produce nothing at all; only clock_drop_chance / shield_drop_chance of
## them actually spawn something.
@export var powerup_spawn_interval_min: float = 2.5
@export var powerup_spawn_interval_max: float = 4.0
## Chance one power-up roll produces a wall clock (slow/fast split 50/50).
@export_range(0.0, 1.0, 0.01) var clock_drop_chance: float = 0.15
## How long the speed buff lasts after catching a clock.
@export var clock_buff_duration: float = 3.0
## Green clock: multiplies TURKEY/MUSHROOM fall speed by this (slower) while active.
@export_range(0.1, 1.0, 0.05) var clock_slow_multiplier: float = 0.75
## Red clock: multiplies TURKEY/MUSHROOM fall speed by this (faster) while active.
@export_range(1.0, 3.0, 0.05) var clock_fast_multiplier: float = 1.25
## Chance one power-up roll produces the angel shield instead (independent of
## clock_drop_chance — the remainder of every roll is simply nothing).
@export_range(0.0, 1.0, 0.01) var shield_drop_chance: float = 0.15
## While active, nothing can break the streak — not a bad-fruit catch, not a
## missed good food.
@export var shield_duration: float = 3.0

@export_category("Scoring")
@export var catch_points: int = 20
## Each unbroken consecutive catch adds one more increment of bonus on top of
## catch_points: +5 on the 2nd catch of a streak, +10 on the 3rd, +15 on the
## 4th, and so on. Resets to 0 whenever the streak breaks.
@export var streak_bonus_increment: int = 5
@export var bad_catch_penalty: int = 50
## Catching this many bad fruits ends the run in failure.
@export var max_bad_catches: int = 3

@export_category("Cauldron Movement")
@export var cauldron_speed: float = 640.0
@export var cauldron_half_width: float = 62.0
@export var food_icon_size: float = 31.0
## Catch collision only covers this fraction of the cauldron's height,
## measured down from its rim — i.e. the top half of the pot, not its base.
@export_range(0.1, 1.0, 0.05) var cauldron_catch_depth_fraction: float = 0.5

## The playable/wrap field reaches the actual viewport edges. The previous
## inset bounds left black margins outside the clip rectangle, making a wrap
## look like it happened inside the screen instead of at the real edge.
var play_field_left: float = 0.0
var play_field_right: float = 1280.0
var spawn_area_top: float = 130.0
var play_field_bottom: float = 620.0
## Where the pot visually rests (its bottom edge). The catch collision zone
## (top half of the pot, see cauldron_catch_depth_fraction) is derived from
## this and the sprite's actual size each frame in _update_falling_foods().
var cauldron_sprite_bottom_y: float = 600.0

var is_playing: bool = false
var score: int = 0
var streak: int = 0
var bad_catches: int = 0
var good_food_spawned: int = 0
var good_food_caught: int = 0
var quality_reported: bool = false
var time_left: float = 0.0
var spawn_timer_left: float = 0.0
## Drives the power-up spawner — entirely independent of spawn_timer_left.
var powerup_spawn_timer_left: float = 0.0
var cauldron_x: float = 640.0
var high_score: int = 0
var active_foods: Array[Dictionary] = []
var cauldron_pulse_time: float = 0.0
## Currently applied to TURKEY/MUSHROOM fall speed each frame while > 0.0
## seconds remain — recomputed dynamically, never baked into a food's speed,
## so it affects everything already falling, not just new spawns.
var speed_buff_multiplier: float = 1.0
var speed_buff_time_left: float = 0.0
## While > 0.0, no event may set streak to 0 — not a bad catch, not a miss.
var streak_shield_time_left: float = 0.0
var cauldron_bubble_timer: float = 0.0

@onready var food_layer: Control = $FoodLayer
## Exactly spans the play field's horizontal wrap range (play_field_left to
## play_field_right) with clip_contents on, so anything that crosses its
## edges — the cauldron or its ghost — is visually cut off right at the
## boundary, like a curtain, instead of just appearing/disappearing.
@onready var cauldron_clip: Control = $CauldronClip
@onready var cauldron_sprite: TextureRect = $CauldronClip/Cauldron
## A second copy of the cauldron sprite, always positioned exactly one field
## width away from the real one. Because both sit inside cauldron_clip, the
## real cauldron is clipped as it exits one wall while the ghost — already
## the correct fraction of the way in from the opposite wall — is clipped
## the complementary amount, producing one continuous sprite that appears to
## slide off one edge and back in on the other (Asteroids/Pac-Man style).
@onready var cauldron_ghost: TextureRect = $CauldronClip/CauldronGhost
@onready var score_label: Label = $HUD/ScoreLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var bad_label: Label = $HUD/BadLabel
@onready var streak_label: Label = $HUD/StreakLabel
@onready var buff_label: Label = $HUD/BuffLabel
@onready var shield_label: Label = $HUD/ShieldLabel
@onready var feedback_layer: Control = $FeedbackLayer
@onready var start_overlay: Panel = $StartOverlay
@onready var start_button: Button = $StartOverlay/StartButton
@onready var end_overlay: Panel = $EndOverlay
@onready var end_title: Label = $EndOverlay/EndTitle
@onready var end_score_label: Label = $EndOverlay/EndScoreLabel
@onready var play_again_button: Button = $EndOverlay/PlayAgainButton
@onready var close_button_end: Button = $EndOverlay/CloseButton
@onready var close_button_top: Button = $CloseButtonTop

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not start_button.pressed.is_connected(start_game): start_button.pressed.connect(start_game)
	if not play_again_button.pressed.is_connected(start_game): play_again_button.pressed.connect(start_game)
	if not close_button_end.pressed.is_connected(_close): close_button_end.pressed.connect(_close)
	if not close_button_top.pressed.is_connected(_close): close_button_top.pressed.connect(_close)
	cauldron_sprite.size = Vector2(cauldron_half_width * 2.4, cauldron_half_width * 1.7)
	# Pivot at the base so the idle "simmering" squash breathes from the
	# bottom instead of visibly shifting the whole pot up and down.
	cauldron_sprite.pivot_offset = Vector2(cauldron_sprite.size.x * 0.5, cauldron_sprite.size.y)
	end_overlay.visible = false
	_update_hud()

func set_high_score(value: int) -> void:
	high_score = value

func start_game() -> void:
	for entry: Dictionary in active_foods:
		var node: Node = entry["node"]
		if is_instance_valid(node): node.queue_free()
	active_foods.clear()
	score = 0
	streak = 0
	bad_catches = 0
	good_food_spawned = 0
	good_food_caught = 0
	quality_reported = false
	time_left = run_duration
	spawn_timer_left = spawn_interval_min
	powerup_spawn_timer_left = randf_range(powerup_spawn_interval_min, powerup_spawn_interval_max)
	cauldron_x = (play_field_left + play_field_right) * 0.5
	if cauldron_ghost != null: cauldron_ghost.visible = false
	speed_buff_multiplier = 1.0
	speed_buff_time_left = 0.0
	streak_shield_time_left = 0.0
	is_playing = true
	start_overlay.visible = false
	end_overlay.visible = false
	_update_hud()
	_update_buff_label()
	_update_shield_label()

func _process(delta: float) -> void:
	# Runs regardless of is_playing so the cauldron stays cute and alive even
	# on the start/end screens, not just mid-run.
	_update_cauldron_idle_bubble(delta)
	if not is_playing: return
	_handle_cauldron_input(delta)
	_update_timer(delta)
	if not is_playing: return
	_update_spawning(delta)
	_update_powerup_spawning(delta)
	if not is_playing: return
	speed_buff_time_left = maxf(0.0, speed_buff_time_left - delta)
	_update_buff_label()
	streak_shield_time_left = maxf(0.0, streak_shield_time_left - delta)
	_update_shield_label()
	_update_falling_foods(delta)

func _update_cauldron_idle_bubble(delta: float) -> void:
	cauldron_pulse_time += delta
	# Gentle simmering breathe — gets a touch more energetic while a run is active.
	var pulse_amount: float = 0.03 if is_playing else 0.018
	cauldron_sprite.scale = Vector2(1.0, 1.0 + sin(cauldron_pulse_time * 3.4) * pulse_amount)
	cauldron_bubble_timer -= delta
	if cauldron_bubble_timer <= 0.0:
		cauldron_bubble_timer = randf_range(0.35, 0.75)
		_spawn_idle_bubble()

func _spawn_idle_bubble() -> void:
	var bubble: CauldronCatchParticle = CauldronCatchParticle.new()
	bubble.radius = randf_range(2.5, 5.0)
	bubble.particle_color = Color(0.55, 0.95, 0.4, 0.8)
	bubble.size = Vector2(bubble.radius * 2.0, bubble.radius * 2.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cauldron_global_position: Vector2 = cauldron_sprite.global_position
	var rim_x: float = cauldron_global_position.x + cauldron_sprite.size.x * randf_range(0.32, 0.68)
	var rim_y: float = cauldron_global_position.y + cauldron_sprite.size.y * 0.14
	bubble.position = Vector2(rim_x - bubble.radius, rim_y - bubble.radius)
	feedback_layer.add_child(bubble)
	var tween: Tween = create_tween()
	tween.tween_property(bubble, "position:y", bubble.position.y - 9.0, 0.55).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(bubble, "modulate:a", 0.0, 0.55).set_delay(0.2)
	tween.tween_callback(bubble.queue_free)

func _handle_cauldron_input(delta: float) -> void:
	# Deliberately A/D only — no arrow keys, no mouse follow.
	var keyboard_axis: float = 0.0
	if Input.is_physical_key_pressed(KEY_A): keyboard_axis -= 1.0
	if Input.is_physical_key_pressed(KEY_D): keyboard_axis += 1.0
	cauldron_x += keyboard_axis * cauldron_speed * delta
	# Donkey Kong-style screen wrap: moving off one edge of the play field
	# brings the cauldron back in from the opposite edge, instead of being
	# clamped at the wall. This halves the worst-case travel distance to any
	# falling food, so no spawn position can ever be truly unreachable. The
	# wrap point is the FULL field width (matching cauldron_clip's own edges
	# exactly) so the clip container's cutoff lines up with where the center
	# actually wraps, instead of stopping short of the visual wall.
	var field_width: float = play_field_right - play_field_left
	if field_width > 0.0:
		cauldron_x = play_field_left + fposmod(cauldron_x - play_field_left, field_width)
	_position_cauldron_sprite(cauldron_sprite, cauldron_x)
	_update_cauldron_ghost(field_width)

func _position_cauldron_sprite(sprite: TextureRect, world_x: float) -> void:
	# cauldron_clip's own position IS the clip boundary in the parent's local
	# space, so subtracting it converts an absolute play-field coordinate into
	# the coordinate space clip_contents actually cuts against.
	var clip_origin: Vector2 = cauldron_clip.position
	sprite.position = Vector2(world_x - sprite.size.x * 0.5, cauldron_sprite_bottom_y - sprite.size.y) - clip_origin

## Asteroids/Pac-Man-style wrap illusion: a second copy of the sprite always
## sits exactly one field-width away from the real one. Both live inside
## cauldron_clip, which clips anything outside its exact play-field bounds —
## so as the real cauldron's visible portion is cut away by one wall, the
## ghost's complementary portion is simultaneously revealed by the other
## wall, reading as one sprite continuously sliding through, never an
## unexplained jump to "the wrong side".
func _update_cauldron_ghost(field_width: float) -> void:
	if cauldron_ghost == null: return
	if field_width <= 0.0:
		cauldron_ghost.visible = false
		return
	cauldron_ghost.visible = true
	var ghost_x: float = cauldron_x - field_width if cauldron_x > (play_field_left + play_field_right) * 0.5 else cauldron_x + field_width
	_position_cauldron_sprite(cauldron_ghost, ghost_x)

func _update_timer(delta: float) -> void:
	time_left = maxf(0.0, time_left - delta)
	timer_label.text = "%d" % ceili(time_left)
	if time_left <= 0.0: _end_game(true)

func _update_spawning(delta: float) -> void:
	# The FOOD spawner — always produces Turkey/Mushroom/Bad Fruit at a
	# steady rate, completely unaffected by whether any power-up spawns.
	spawn_timer_left -= delta
	if spawn_timer_left <= 0.0:
		var kind: FoodKind = FoodKind.BAD_FRUIT if randf() < bad_food_chance else (FoodKind.TURKEY if randf() < 0.5 else FoodKind.MUSHROOM)
		_spawn_specific_food(kind)
		if kind == FoodKind.TURKEY or kind == FoodKind.MUSHROOM: good_food_spawned += 1
		spawn_timer_left = randf_range(spawn_interval_min, spawn_interval_max)

func _update_powerup_spawning(delta: float) -> void:
	# The POWER-UP spawner — entirely separate timer and roll from food
	# above. Most rolls here produce nothing at all; only clock_drop_chance /
	# shield_drop_chance of them actually spawn a clock or the angel shield.
	powerup_spawn_timer_left -= delta
	if powerup_spawn_timer_left <= 0.0:
		var roll: float = randf()
		if roll < clock_drop_chance:
			_spawn_specific_food(FoodKind.CLOCK_SLOW if randf() < 0.5 else FoodKind.CLOCK_FAST)
		elif roll < clock_drop_chance + shield_drop_chance:
			_spawn_specific_food(FoodKind.ANGEL_SHIELD)
		# else: this roll simply produces nothing — the whole point of a
		# separate timer is that "nothing" is a valid, common outcome here
		# without it ever costing a food spawn slot.
		powerup_spawn_timer_left = randf_range(powerup_spawn_interval_min, powerup_spawn_interval_max)

func _texture_for_kind(kind: FoodKind) -> Texture2D:
	match kind:
		FoodKind.TURKEY: return TURKEY_TEXTURE
		FoodKind.MUSHROOM: return MUSHROOM_TEXTURE
		FoodKind.CLOCK_SLOW: return CLOCK_SLOW_TEXTURE
		FoodKind.CLOCK_FAST: return CLOCK_FAST_TEXTURE
		FoodKind.ANGEL_SHIELD: return ANGEL_SHIELD_TEXTURE
		_: return BAD_FRUIT_TEXTURE

func _spawn_specific_food(kind: FoodKind) -> void:
	# Shared icon-creation path used by both the food spawner and the
	# power-up spawner, so every falling item behaves consistently.
	var icon: TextureRect = TextureRect.new()
	icon.texture = _texture_for_kind(kind)
	# expand_mode must be set BEFORE size — otherwise the default
	# EXPAND_KEEP_SIZE forces the minimum size to the texture's native
	# dimensions and silently clamps the size assignment below back up.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(food_icon_size, food_icon_size)
	icon.pivot_offset = icon.size * 0.5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spawn_x: float = randf_range(play_field_left + food_icon_size, play_field_right - food_icon_size)
	icon.position = Vector2(spawn_x - food_icon_size * 0.5, spawn_area_top)
	food_layer.add_child(icon)
	var speed_roll: float = randf()
	var speed: float = slow_speed
	if speed_roll > 0.66: speed = fast_speed
	elif speed_roll > 0.33: speed = medium_speed
	# Purely cosmetic: a chance to lazily spin as it falls, just for cuteness.
	var spin_deg_per_sec: float = 0.0
	var wave_phase: float = 0.0
	if randf() < spin_chance:
		spin_deg_per_sec = randf_range(spin_speed_min_deg, spin_speed_max_deg) * (1.0 if randf() < 0.5 else -1.0)
		wave_phase = randf_range(0.0, TAU)
	active_foods.append({
		"node": icon,
		"kind": kind,
		"speed": speed,
		"spin": spin_deg_per_sec,
		"wave_base_x": icon.position.x,
		"wave_phase": wave_phase,
		"wave_time": 0.0
	})

func _update_falling_foods(delta: float) -> void:
	# Catch zone is the top half of the cauldron (rim down to its midpoint),
	# not a single line — this is the actual collision area, not just where
	# the sprite happens to be drawn.
	# Food lives in the root-level FoodLayer, so collision must use the
	# cauldron's global/world coordinates rather than its local position inside
	# CauldronClip (which is only about 60px on Y).
	var catch_top: float = cauldron_sprite.global_position.y
	var catch_bottom: float = catch_top + cauldron_sprite.size.y * cauldron_catch_depth_fraction
	for index: int in range(active_foods.size() - 1, -1, -1):
		# A bad catch can end the run mid-loop (_end_game clears active_foods
		# entirely), which would invalidate the remaining indices below.
		if not is_playing or index >= active_foods.size(): break
		var entry: Dictionary = active_foods[index]
		var icon: TextureRect = entry["node"] as TextureRect
		if not is_instance_valid(icon):
			active_foods.remove_at(index)
			continue
		var previous_bottom: float = icon.position.y + icon.size.y
		var entry_kind: FoodKind = entry["kind"] as FoodKind
		var effective_speed: float = float(entry["speed"])
		# The clock buff only ever affects the two real ingredients, never
		# the bad fruit or another clock, and is recomputed live every frame
		# so it also speeds up/slows down food that was already falling.
		if speed_buff_time_left > 0.0 and (entry_kind == FoodKind.TURKEY or entry_kind == FoodKind.MUSHROOM):
			effective_speed *= speed_buff_multiplier
		icon.position.y += effective_speed * delta
		var spin_deg_per_sec: float = float(entry.get("spin", 0.0))
		if spin_deg_per_sec != 0.0:
			icon.rotation += deg_to_rad(spin_deg_per_sec) * delta
			# Spinning objects gently trace a vertical sine wave as they fall.
			# Their lane is preserved as the centerline; the small sway is only
			# visual motion and remains fair because collision uses this live X.
			var wave_time: float = float(entry.get("wave_time", 0.0)) + delta
			var wave_phase: float = float(entry.get("wave_phase", 0.0))
			var wave_base_x: float = float(entry.get("wave_base_x", icon.position.x))
			icon.position.x = wave_base_x + sin(wave_time * spinning_wave_frequency + wave_phase) * spinning_wave_amplitude
			entry["wave_time"] = wave_time
		var icon_center_x: float = icon.position.x + icon.size.x * 0.5
		var current_bottom: float = icon.position.y + icon.size.y
		var within_x: bool = absf(icon_center_x - cauldron_x) <= cauldron_half_width
		# Swept across the whole distance traveled this frame (not just the
		# final position), so a fast fall can never tunnel through the catch
		# band without registering — it always "lands" instead of skipping past.
		var crossed_catch_band: bool = within_x and current_bottom >= catch_top and previous_bottom <= catch_bottom
		if crossed_catch_band:
			_catch_food(entry_kind, icon.global_position)
			# _catch_food can end the run (clearing active_foods) when the
			# bad-catch limit is hit, which invalidates this index.
			if index < active_foods.size(): active_foods.remove_at(index)
			if is_playing and is_instance_valid(icon): _play_landing_animation(icon, catch_top)
			continue
		if current_bottom > play_field_bottom:
			_miss_food(entry_kind)
			icon.queue_free()
			if index < active_foods.size(): active_foods.remove_at(index)

func _play_landing_animation(icon: TextureRect, catch_top: float) -> void:
	# Snap into the cauldron and shrink away, so a catch reads as "landed in
	# the pot" rather than instantly vanishing or teleporting past it.
	icon.position.y = clampf(icon.position.y, catch_top, catch_top + 16.0)
	icon.pivot_offset = icon.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(icon, "scale", Vector2(0.15, 0.15), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.16)
	tween.tween_callback(icon.queue_free)
	_spawn_splash(icon.position + icon.size * 0.5)
	# is_inside_tree() avoids the engine's own "null tree" diagnostic that
	# get_tree() prints when called on a not-yet-live node (e.g. in tests).
	var main_scene: Node = get_tree().current_scene if is_inside_tree() else null
	if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("splash", 0.8, randf_range(0.92, 1.1))

func _spawn_splash(splash_center: Vector2) -> void:
	# A little "BLOO-sploosh": a handful of droplets kicking outward/up plus a
	# quick expanding ring at the rim.
	var droplet_count: int = 6
	for _index: int in range(droplet_count):
		var droplet: CauldronCatchParticle = CauldronCatchParticle.new()
		droplet.radius = randf_range(2.0, 4.0)
		droplet.particle_color = Color(0.787, 0.0, 0.787, 0.902)
		droplet.size = Vector2(droplet.radius * 2.0, droplet.radius * 2.0)
		droplet.mouse_filter = Control.MOUSE_FILTER_IGNORE
		droplet.position = splash_center - Vector2(droplet.radius, droplet.radius)
		feedback_layer.add_child(droplet)
		var angle: float = randf_range(-PI * 0.85, -PI * 0.15)
		var speed: float = randf_range(60.0, 140.0)
		var travel: Vector2 = Vector2(cos(angle), sin(angle)) * speed * 0.25 + Vector2(0.0, 30.0)
		var droplet_tween: Tween = create_tween()
		droplet_tween.set_parallel(true)
		droplet_tween.tween_property(droplet, "position", droplet.position + travel, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		droplet_tween.tween_property(droplet, "modulate:a", 0.0, 0.32).set_delay(0.08)
		droplet_tween.chain().tween_callback(droplet.queue_free)
	var ring: CauldronCatchParticle = CauldronCatchParticle.new()
	ring.radius = 4.0
	ring.particle_color = Color(0.75, 1.0, 0.55, 0.5)
	ring.size = Vector2(ring.radius * 2.0, ring.radius * 2.0)
	ring.pivot_offset = Vector2(ring.radius, ring.radius)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.position = splash_center - Vector2(ring.radius, ring.radius)
	feedback_layer.add_child(ring)
	var ring_tween: Tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.25).set_trans(Tween.TRANS_QUAD)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
	ring_tween.tween_callback(ring.queue_free)

func _catch_food(kind: FoodKind, world_position: Vector2) -> void:
	if kind == FoodKind.BAD_FRUIT:
		score = maxi(0, score - bad_catch_penalty)
		bad_catches += 1
		# The angel shield protects the streak from everything, including a
		# bad catch, for its whole duration — not just missed good food.
		if streak_shield_time_left <= 0.0: streak = 0
		_spawn_feedback("-%d" % bad_catch_penalty, Color(1.0, 0.35, 0.35), world_position)
		_update_hud()
		if bad_catches >= max_bad_catches: _end_game(false)
		return
	if kind == FoodKind.CLOCK_SLOW or kind == FoodKind.CLOCK_FAST:
		_apply_clock_buff(kind, world_position)
		return
	if kind == FoodKind.ANGEL_SHIELD:
		_apply_shield(world_position)
		return
	# Escalating streak bonus: base points on the 1st catch, +5 on the 2nd,
	# +10 on the 3rd, +15 on the 4th, and so on — using the streak value from
	# BEFORE this catch, since that's how many unbroken catches preceded it.
	var points: int = catch_points + streak_bonus_increment * streak
	good_food_caught += 1
	score += points
	streak += 1
	_spawn_feedback("+%d" % points, Color(0.6, 1.0, 0.5), world_position)
	_update_hud()

func _apply_clock_buff(kind: FoodKind, world_position: Vector2) -> void:
	# Purely a timed speed modifier — no points, no streak effect either way.
	var is_slow: bool = kind == FoodKind.CLOCK_SLOW
	speed_buff_multiplier = clock_slow_multiplier if is_slow else clock_fast_multiplier
	speed_buff_time_left = clock_buff_duration
	_spawn_feedback("SLOWED!" if is_slow else "SPED UP!", Color(0.55, 1.0, 0.6) if is_slow else Color(1.0, 0.55, 0.4), world_position)
	_update_buff_label()
	var main_scene: Node = get_tree().current_scene if is_inside_tree() else null
	if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("splash", 0.7, 0.8 if is_slow else 1.25)

func _update_buff_label() -> void:
	if buff_label == null: return
	if speed_buff_time_left <= 0.0:
		buff_label.visible = false
		return
	buff_label.visible = true
	var is_slow: bool = speed_buff_multiplier < 1.0
	buff_label.text = "%s %.1fs" % ["SLOWED" if is_slow else "SPED UP", speed_buff_time_left]
	buff_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if is_slow else Color(1.0, 0.55, 0.4))

func _apply_shield(world_position: Vector2) -> void:
	# Purely a timed streak protection — no points either way.
	streak_shield_time_left = shield_duration
	_spawn_feedback("SHIELDED!", Color(1.0, 0.95, 0.6), world_position)
	_update_shield_label()
	var main_scene: Node = get_tree().current_scene if is_inside_tree() else null
	if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("splash", 0.7, 1.05)

func _update_shield_label() -> void:
	if shield_label == null: return
	if streak_shield_time_left <= 0.0:
		shield_label.visible = false
		return
	shield_label.visible = true
	shield_label.text = "SHIELDED %.1fs" % streak_shield_time_left

func _miss_food(kind: FoodKind) -> void:
	if kind == FoodKind.BAD_FRUIT or kind == FoodKind.CLOCK_SLOW or kind == FoodKind.CLOCK_FAST or kind == FoodKind.ANGEL_SHIELD: return
	# The angel shield protects the streak from a missed good food too.
	if streak_shield_time_left > 0.0: return
	# A single miss only costs one streak step rather than wiping it out —
	# one unlucky spawn shouldn't erase a long streak entirely.
	streak = maxi(0, streak - 1)
	_update_hud()

func _spawn_feedback(text: String, color: Color, world_position: Vector2) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", color)
	label.position = world_position - global_position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_layer.add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 46.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func _update_hud() -> void:
	score_label.text = "Score: %d" % score
	bad_label.text = "Bad Caught: %d/%d" % [bad_catches, max_bad_catches]
	streak_label.text = "Streak x%d" % streak

func _end_game(completed: bool) -> void:
	is_playing = false
	for entry: Dictionary in active_foods:
		var node: Node = entry["node"]
		if is_instance_valid(node): node.queue_free()
	active_foods.clear()
	var is_new_high_score: bool = score > high_score
	if is_new_high_score: high_score = score
	var catch_rate: float = float(good_food_caught) / float(maxi(1, good_food_spawned))
	var passed: bool = completed and catch_rate >= 0.60
	if not quality_reported:
		quality_reported = true
		quality_result.emit(passed, catch_rate)
	end_title.text = "Oh, that is lovely, thank you!" if passed else "Oh dear!"
	end_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.5) if passed else Color(1.0, 0.4, 0.4))
	var high_score_text: String = "\nNEW HIGH SCORE!" if is_new_high_score else "\nHigh Score: %d" % high_score
	end_score_label.text = "Final Score: %d%s\nGood ingredients: %d%% (%d/%d)" % [score, high_score_text, roundi(catch_rate * 100.0), good_food_caught, good_food_spawned]
	end_overlay.visible = true
	round_finished.emit(score, is_new_high_score)

func _close() -> void:
	is_playing = false
	closed.emit(score, score > high_score)
	queue_free()
