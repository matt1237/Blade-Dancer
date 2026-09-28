class_name CombatPresentationFX extends Node2D

class BloodDrop extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var radius: float = 2.0
	var life: float = 0.0
	var total_life: float = 0.0

class SplitRemnant extends RefCounted:
	var world_position: Vector2 = Vector2.ZERO
	var cut_direction: Vector2 = Vector2.RIGHT
	var horizontal_cut: bool = false
	var sprite_scale: float = 1.0
	var half_textures: Array[ImageTexture] = []
	var half_offsets: Array[Vector2] = []
	var half_velocities: Array[Vector2] = []
	var half_rotation: Array[float] = []
	var half_spin: Array[float] = []
	var life: float = 0.0
	var total_life: float = 0.0

class FloatingDamageNumber extends RefCounted:
	var label: Label = null
	var world_position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var total_life: float = 0.0
	var size_scale: float = 1.0

@export_category("Master Presentation Toggle")
## Disables all centralized combat presentation effects together.
@export var enabled: bool = true

@export_category("Impact Speed Lines")
@export var enable_speed_lines: bool = true
## Number of directional streaks per impact.
@export var line_count: int = 3
## Maximum length of each streak at full impact strength.
@export var line_length: float = 28.0
## Perpendicular spread around the impact direction.
@export var line_spread: float = 24.0
## Base line width.
@export var line_width: float = 2.0
## How long the streaks remain visible.
@export var effect_duration: float = 0.09
## Minimum distance from the impact point before a streak begins.
@export var line_start_distance: float = 8.0
## Draw streaks behind the incoming attack rather than ahead of it.
@export var trail_behind_impact: bool = true
## Color of the streaks.
@export var line_color: Color = Color(1.0, 0.88, 0.42, 0.8)

@export_category("Micro Zoom")
@export var enable_micro_zoom: bool = true
## Maximum zoom added at full impact strength. 0.025 means 2.5%.
@export_range(0.0, 0.1, 0.005) var micro_zoom_amount: float = 0.025
@export var micro_zoom_duration: float = 0.1
@export_range(0.0, 2.0, 0.05) var micro_zoom_strength_scale: float = 1.0

@export_category("Impact Time Slow")
## Global cinematic slow motion after qualifying hits. Hitstop takes priority.
@export var enable_impact_time_slow: bool = true
## Engine speed while active. 0.8 means the game runs at 80% speed.
@export_range(0.1, 1.0, 0.05) var impact_time_scale: float = 0.8
## Real-world duration after hitstop finishes.
@export var impact_time_slow_duration: float = 0.12
@export var time_slow_on_medium_hits: bool = false
@export var time_slow_on_strong_hits: bool = true
@export var time_slow_on_max_hits: bool = true
@export_range(0.0, 1.0, 0.05) var medium_hit_quality_threshold: float = 0.4
@export_range(0.0, 1.0, 0.05) var strong_hit_quality_threshold: float = 0.8
@export_range(0.0, 1.0, 0.05) var max_hit_quality_threshold: float = 0.9

@export_category("Hit Sound Pitch Variation")
@export var enable_hit_pitch_variation: bool = true
@export_range(0.5, 1.5, 0.01) var hit_pitch_minimum: float = 0.94
@export_range(0.5, 1.5, 0.01) var hit_pitch_maximum: float = 1.06
## Stronger contacts bias pitch upward by this amount.
@export_range(0.0, 0.25, 0.01) var hit_quality_pitch_influence: float = 0.04

@export_category("Enemy Hit Deformation")
@export var enable_enemy_hit_deformation: bool = true
@export_range(0.0, 1.0, 0.05) var enemy_deformation_min_quality: float = 0.65
## Maximum compression along the hit direction at a perfect-quality contact.
@export_range(0.0, 0.7, 0.01) var enemy_deformation_max_compression: float = 0.35
@export_range(0.0, 3.0, 0.05) var enemy_deformation_hd_strength: float = 2.0
@export var hit_squash_strength: float = 200.0
@export var enemy_deformation_duration: float = 0.24
@export_range(0.0, 0.1, 0.005) var enemy_deformation_spring_overshoot: float = 0.018

@export_category("Chakram Bat Deformation")
@export var enable_chakram_bat_deformation: bool = true
@export_range(0.0, 1.0, 0.05) var chakram_stretch_min_quality: float = 0.7
@export_range(0.0, 0.3, 0.01) var chakram_max_stretch: float = 0.14
@export var chakram_stretch_duration: float = 0.085

@export_category("High Quality Blood")
@export var enable_blood_splatter: bool = true
@export_range(0.0, 1.0, 0.05) var blood_min_quality: float = 0.05

@export var blood_drop_count: int = 22
@export var blood_drop_speed: float = 220.0
@export var blood_drop_lifetime: float = 0.9
@export var blood_spread_degrees: float = 60.0
@export var blood_color: Color = Color(0.62, 0.02, 0.03, 0.96)

@export_category("High Quality Split Kill")
@export var enable_split_kill: bool = true
@export_range(0.0, 1.0, 0.05) var split_kill_min_quality: float = 0.88
@export var split_kill_duration: float = 0.8
@export var split_half_separation: float = 44.0
## Outward speed each half travels as the body peels apart. Small on purpose:
## the halves split and drift, they do not fly like a baseball.
@export var split_separation_speed: float = 30.0
## How strongly both halves carry the blade's own travel direction as they split.
@export var split_drift_speed: float = 72.0
## Spin rate (radians/second) of each half; the two halves spin in opposite
## directions and pivot on the cut seam, so the body reads as hinging open.
@export var split_spin_speed: float = 9.0
## Gentle downward settle applied to both halves after the initial split pop.
@export var split_gravity: float = 210.0
@export var split_cut_flash_color: Color = Color(1.0, 0.72, 0.64, 0.95)

@export_category("Special Event Blur")
## Master blur toggle. Blur remains opt-in unless blur_on_flesh_hits is enabled.
@export var enable_special_event_blur: bool = true
# Forest tuner gates optional blur without overwriting Classic/combat presets.
var forest_screen_blur_allowed: bool = false
@export var blur_on_flesh_hits: bool = true
@export var blur_duration: float = 0.1
@export_range(0.0, 8.0, 0.25) var blur_radius_pixels: float = 2.0
@export_range(0.0, 1.0, 0.05) var blur_mix: float = 0.45

@export_category("Parry Focus Vignette")
@export var enable_parry_focus_vignette: bool = true
@export_range(0.0, 1.0, 0.05) var parry_focus_min_quality: float = 0.45
@export var parry_focus_duration: float = 0.16
@export_range(0.0, 1.0, 0.01) var parry_vignette_max_alpha: float = 0.28
@export_range(0.0, 1.0, 0.05) var parry_vignette_inner_radius: float = 0.35
@export_range(0.0, 1.5, 0.05) var parry_vignette_outer_radius: float = 0.9
@export var parry_vignette_color: Color = Color(0.03, 0.035, 0.055, 1.0)
## Requests the optional blur alongside a qualifying parry.
@export var parry_focus_uses_blur: bool = true

@export_category("Floating Damage Numbers")
@export var enable_floating_damage_numbers: bool = true
@export var enemy_damage_number_color: Color = Color(1.0, 0.2, 0.24, 1.0)
@export var player_damage_number_color: Color = Color(0.25, 0.7, 1.0, 1.0)
@export var damage_number_outline_color: Color = Color(0.08, 0.05, 0.12, 1.0)
@export var damage_number_font_size: int = 25
@export var damage_number_outline_size: int = 6
@export var damage_number_lifetime: float = 0.72
@export var damage_number_rise_speed: float = 54.0
@export var damage_number_horizontal_scatter: float = 18.0
@export_range(0.0, 1.0, 0.05) var large_damage_quality_threshold: float = 0.8
@export_range(1.0, 3.0, 0.1) var large_damage_scale: float = 1.5

@export_category("Persistent Status Vignettes")
## Replaces the old rectangular low-health border with a soft radial edge tint.
@export var enable_low_health_vignette: bool = true
## Health ratio where the red danger vignette begins. 0.3 means below 30% health.
@export_range(0.05, 1.0, 0.05) var low_health_threshold: float = 0.3
@export_range(0.0, 1.0, 0.01) var low_health_vignette_max_alpha: float = 0.3
@export var low_health_vignette_color: Color = Color(0.72, 0.025, 0.035, 1.0)
## Pulses per second, kept close to the existing low-health heartbeat cadence.
@export var low_health_vignette_pulse_speed: float = 1.4
## Replaces the old rectangular high-Flow border with a soft focus edge glow.
@export var enable_high_flow_vignette: bool = true
## Flow percentage where the focus vignette first becomes visible.
## This is the minimum point of the gradual transition.
@export_range(0.0, 100.0, 1.0) var high_flow_threshold: float = 75.0
## Flow percentage where the focus vignette reaches maximum strength.
@export_range(1.0, 100.0, 1.0) var high_flow_full_intensity_flow: float = 100.0
## Maximum opacity at full Flow. 0.08 is a subtle transparent focus effect.
@export_range(0.0, 1.0, 0.01) var high_flow_vignette_max_alpha: float = 0.08
## Warm off-white focus color, intentionally softer than gold.
@export var high_flow_vignette_color: Color = Color(1.0, 0.906, 0.488, 1.0)
## Optional pulse speed. Set to 0 for a calm, steady focus effect.
@export var high_flow_vignette_pulse_speed: float = .20
## How strongly the vignette pulses. 0 means no pulse.
@export_range(0.0, 1.0, 0.05) var high_flow_vignette_pulse_amount: float = 1.4
## Clear center and outer falloff shared by both persistent status colors.
@export_range(0.0, 1.0, 0.05) var status_vignette_inner_radius: float = 0.89
@export_range(0.0, 1.5, 0.05) var status_vignette_outer_radius: float = 1.00

var effect_left: float = 0.0
var effect_direction: Vector2 = Vector2.RIGHT
var effect_strength: float = 1.0
var effect_seed: float = 0.0
var active_effect_duration: float = 0.09
var zoom_left: float = 0.0
var zoom_strength: float = 1.0
var active_zoom_amount: float = 0.025
var active_zoom_duration: float = 0.1
var zoom_position_offset: Vector2 = Vector2.ZERO
# Sustained Form III focus composes with one-shot impact zoom. The player owns
# bind qualification; this node owns only presentation and world time scale.
var bind_focus_active: bool = false
var bind_focus_world_scale: float = 1.0
var bind_focus_zoom_amount: float = 0.0
var bind_focus_zoom_current: float = 0.0
var bind_focus_response: float = 8.0
var blur_left: float = 0.0
var time_slow_left: float = 0.0
var parry_focus_left: float = 0.0
var active_parry_focus_duration: float = 0.16
var active_parry_focus_strength: float = 1.0
var pulse_time: float = 0.0
var world_root: Node2D = null
var presentation_camera: Camera2D = null
var camera_rest_zoom: Vector2 = Vector2.ONE
var classic_zoom_applied: bool = false
var player_ref: Player = null
var overlay_layer: CanvasLayer = null
var blur_rect: ColorRect = null
var blur_material: ShaderMaterial = null
var vignette_rect: ColorRect = null
var vignette_material: ShaderMaterial = null
var status_vignette_rect: ColorRect = null
var status_vignette_material: ShaderMaterial = null
var blood_drops: Array[BloodDrop] = []
var split_remnants: Array[SplitRemnant] = []
var floating_damage_numbers: Array[FloatingDamageNumber] = []

func _ready() -> void:
	world_root = get_parent() as Node2D
	presentation_camera = world_root.get_node_or_null("PresentationCamera") as Camera2D if world_root != null else null
	if presentation_camera != null:
		camera_rest_zoom = presentation_camera.zoom
	player_ref = get_parent().get_node_or_null("Player") as Player
	_setup_screen_overlay()

func set_bind_focus(active: bool, world_scale: float = 1.0, zoom_amount: float = 0.0, response: float = 8.0) -> void:
	bind_focus_active = active
	bind_focus_world_scale = clampf(world_scale, 0.2, 1.0)
	bind_focus_zoom_amount = clampf(zoom_amount, 0.0, 0.30)
	bind_focus_response = clampf(response, 1.0, 20.0)
	if not active and time_slow_left <= 0.0 and (world_root == null or not bool(world_root.get("hitstop_active"))):
		Engine.time_scale = 1.0

func trigger(impact_position: Vector2, travel_direction: Vector2, strength: float = 1.0, request_blur: bool = false, contact_quality: float = 0.0) -> void:
	trigger_tuned(impact_position, travel_direction, strength, micro_zoom_amount, micro_zoom_duration, request_blur, contact_quality)

func trigger_tuned(impact_position: Vector2, travel_direction: Vector2, strength: float, zoom_amount: float, zoom_duration: float, request_blur: bool = false, contact_quality: float = 0.0) -> void:
	if not enabled: return
	global_position = impact_position
	var normalized_direction: Vector2 = travel_direction.normalized() if travel_direction.length_squared() > 0.001 else Vector2.RIGHT
	effect_direction = -normalized_direction if trail_behind_impact else normalized_direction
	effect_strength = clampf(strength, 0.0, 2.5)
	active_effect_duration = effect_duration
	if enable_speed_lines and effect_strength > 0.0:
		effect_left = active_effect_duration
		effect_seed = randf() * TAU
	active_zoom_amount = maxf(0.0, zoom_amount)
	active_zoom_duration = maxf(0.001, zoom_duration)
	if enable_micro_zoom and active_zoom_amount > 0.0:
		zoom_left = active_zoom_duration
		zoom_strength = effect_strength * micro_zoom_strength_scale
	if enable_special_event_blur and (request_blur or blur_on_flesh_hits):
		blur_left = blur_duration
	if enable_impact_time_slow and _should_trigger_time_slow(contact_quality):
		time_slow_left = maxf(time_slow_left, impact_time_slow_duration)
	queue_redraw()

func trigger_special_event(impact_position: Vector2, travel_direction: Vector2, strength: float = 1.0) -> void:
	trigger(impact_position, travel_direction, strength, true, 1.0)

func trigger_parry_focus(impact_position: Vector2, travel_direction: Vector2, contact_quality: float) -> void:
	trigger_parry_focus_tuned(impact_position, travel_direction, contact_quality, 1.0, parry_focus_duration, micro_zoom_amount, micro_zoom_duration, 0.8 + contact_quality * 0.6)

func trigger_parry_focus_tuned(impact_position: Vector2, travel_direction: Vector2, contact_quality: float, focus_strength: float, focus_duration: float, zoom_amount: float, zoom_duration: float, impact_strength: float) -> void:
	if not enabled: return
	active_parry_focus_strength = clampf(focus_strength, 0.0, 1.0)
	active_parry_focus_duration = maxf(0.001, focus_duration)
	if enable_parry_focus_vignette and active_parry_focus_strength > 0.0 and contact_quality >= parry_focus_min_quality:
		parry_focus_left = active_parry_focus_duration
	trigger_tuned(impact_position, travel_direction, impact_strength, zoom_amount, zoom_duration, parry_focus_uses_blur and active_parry_focus_strength > 0.0, contact_quality)

func present_enemy_hit(enemy: Enemy, contact_point: Vector2, impact_velocity: Vector2, cut_direction: Vector2, contact_quality: float, killed: bool, sword_hit: bool = true, directional_presentation: bool = false) -> void:
	if not enabled: return
	var hit_squash_for_contact: float = hit_squash_strength
	if enemy != null and is_instance_valid(enemy) and enemy.player_ref != null and sword_hit:
		if enemy._is_hd_visual():
			hit_squash_for_contact = enemy.player_ref.get_combat_contact_setting("hd_hit_squash_strength")
	if enable_enemy_hit_deformation and contact_quality >= enemy_deformation_min_quality and enemy != null and is_instance_valid(enemy):
		var quality_range: float = maxf(0.001, 1.0 - enemy_deformation_min_quality)
		var deformation_strength: float = clampf((contact_quality - enemy_deformation_min_quality) / quality_range, 0.0, 1.0)
		var hd_enemy: bool = enemy._is_hd_visual() and sword_hit
		var configured_hd_squash: float = clampf(hit_squash_for_contact / 100.0, 0.0, 3.0)
		var hd_squash_multiplier: float = configured_hd_squash if hd_enemy else 1.0
		var compression_base: float = 0.23 if hd_enemy else enemy_deformation_max_compression
		var maximum_compression: float = minf(0.7, compression_base * hd_squash_multiplier)
		var spring_overshoot: float = minf(0.35, enemy_deformation_spring_overshoot * hd_squash_multiplier)
		enemy.play_impact_deformation(impact_velocity, enemy_deformation_duration, maximum_compression * deformation_strength, spring_overshoot * deformation_strength, hd_enemy)
	var contact_player: Player = null if enemy == null or not is_instance_valid(enemy) else enemy.player_ref
	var blood_chance_max: float = float(HitReaction.DEFAULTS.get("blood_chance_percent", 60.0))
	var split_chance_max: float = float(HitReaction.DEFAULTS.get("split_kill_chance_percent", 80.0))
	if contact_player != null:
		blood_chance_max = contact_player.get_combat_contact_setting("blood_chance_percent")
		split_chance_max = contact_player.get_combat_contact_setting("split_kill_chance_percent")
	# Blood is a roll, not a fixed threshold: the chance lerps up with contact
	# quality toward the max-chance slider, so weaker cuts bleed less often and a
	# 100% ceiling still will not fire on every swing.
	if enable_blood_splatter and contact_quality >= blood_min_quality and randf() < HitReaction.contact_chance(blood_chance_max, blood_min_quality, contact_quality):
		# Blood Amount / Droplet Size are per-preset tuner sliders (100% == the
		# authored baseline); fall back to the baseline when no player is present.
		var blood_amount_scale: float = 1.0
		var blood_size_scale: float = 1.0
		if contact_player != null:
			blood_amount_scale = clampf(contact_player.get_combat_contact_setting("blood_amount_percent") / 100.0, 0.0, 4.0)
			blood_size_scale = clampf(contact_player.get_combat_contact_setting("blood_drop_size_percent") / 100.0, 0.0, 4.0)
		_spawn_blood(contact_point, impact_velocity, contact_quality, directional_presentation and sword_hit, blood_amount_scale, blood_size_scale)
	if killed and sword_hit and enable_split_kill and contact_quality >= split_kill_min_quality and enemy != null and is_instance_valid(enemy) and enemy._is_hd_visual() and enemy.hd_enemy_sprite != null and enemy.hd_enemy_sprite.sprite_frames != null:
		if randf() < HitReaction.contact_chance(split_chance_max, split_kill_min_quality, contact_quality):
			var snapped_cut_direction: Vector2 = _snap_split_cut_direction(cut_direction)
			var sprite_texture: Texture2D = enemy.hd_enemy_sprite.sprite_frames.get_frame_texture(enemy.hd_enemy_sprite.animation, enemy.hd_enemy_sprite.frame)
			# Use the sprite's real WORLD transform. get_global_transform_with_canvas()
			# bakes in the camera zoom, which made the cut sprite render far larger
			# than the enemy ever was on screen (and off its position).
			var sprite_world_position: Vector2 = enemy.hd_enemy_sprite.global_position
			var sprite_scale: float = sqrt(absf(enemy.hd_enemy_sprite.global_transform.determinant()))
			if is_zero_approx(sprite_scale):
				sprite_scale = enemy.hd_enemy_base_scale
			_spawn_split_remnant(sprite_world_position, snapped_cut_direction, sprite_texture, sprite_scale, enemy.hd_enemy_sprite.flip_h, impact_velocity)
			_spawn_split_blood_pool(sprite_world_position, sprite_texture, sprite_scale)
			enemy.hd_enemy_sprite.hide()
			enemy.queue_free()

func present_chakram_bat(chakram: Chakram, launch_direction: Vector2, contact_quality: float) -> void:
	if not enabled or chakram == null or not is_instance_valid(chakram): return
	trigger(chakram.global_position, launch_direction, 0.75 + contact_quality * 0.55, false, contact_quality)
	if not enable_chakram_bat_deformation or contact_quality < chakram_stretch_min_quality: return
	var quality_range: float = maxf(0.001, 1.0 - chakram_stretch_min_quality)
	var stretch_strength: float = clampf((contact_quality - chakram_stretch_min_quality) / quality_range, 0.0, 1.0)
	chakram.play_bat_stretch(launch_direction, chakram_stretch_duration, chakram_max_stretch * stretch_strength)

func hit_pitch_scale(contact_quality: float) -> float:
	if not enabled or not enable_hit_pitch_variation: return 1.0
	var random_pitch: float = randf_range(hit_pitch_minimum, hit_pitch_maximum)
	var quality_bias: float = lerpf(-hit_quality_pitch_influence, hit_quality_pitch_influence, clampf(contact_quality, 0.0, 1.0))
	return clampf(random_pitch + quality_bias, 0.5, 1.5)

func show_damage_number(world_position: Vector2, damage: float, against_player: bool, contact_quality: float = 0.0) -> void:
	if not enabled or not enable_floating_damage_numbers or damage <= 0.0 or overlay_layer == null: return
	var number: FloatingDamageNumber = FloatingDamageNumber.new()
	number.world_position = world_position + Vector2(randf_range(-8.0, 8.0), -34.0)
	number.velocity = Vector2(randf_range(-damage_number_horizontal_scatter, damage_number_horizontal_scatter), -damage_number_rise_speed)
	number.total_life = damage_number_lifetime
	number.life = number.total_life
	number.size_scale = large_damage_scale if contact_quality >= large_damage_quality_threshold else 1.0
	var rounded_damage: int = roundi(damage)
	var number_text: String = str(rounded_damage) if is_equal_approx(damage, float(rounded_damage)) else String.num(damage, 1)
	var label: Label = Label.new()
	label.text = number_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(100.0, 50.0)
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", damage_number_font_size)
	label.add_theme_color_override("font_color", player_damage_number_color if against_player else enemy_damage_number_color)
	label.add_theme_color_override("font_outline_color", damage_number_outline_color)
	label.add_theme_constant_override("outline_size", damage_number_outline_size)
	overlay_layer.add_child(label)
	number.label = label
	floating_damage_numbers.append(number)
	_update_damage_number_label(number, 0.0)

func show_status_text(world_position: Vector2, text: String, color: Color = Color(1.0, 0.82, 0.2, 1.0)) -> void:
	if not enabled or overlay_layer == null or text.is_empty():
		return
	var number: FloatingDamageNumber = FloatingDamageNumber.new()
	number.world_position = world_position + Vector2(0.0, -46.0)
	number.velocity = Vector2(0.0, -42.0)
	number.total_life = 0.9
	number.life = number.total_life
	number.size_scale = 1.25
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(180.0, 54.0)
	label.pivot_offset = label.size * 0.5
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", damage_number_outline_color)
	label.add_theme_constant_override("outline_size", 7)
	overlay_layer.add_child(label)
	number.label = label
	floating_damage_numbers.append(number)
	_update_damage_number_label(number, 0.0)

func _should_trigger_time_slow(contact_quality: float) -> bool:
	if contact_quality >= max_hit_quality_threshold: return time_slow_on_max_hits
	if contact_quality >= strong_hit_quality_threshold: return time_slow_on_strong_hits
	if contact_quality >= medium_hit_quality_threshold: return time_slow_on_medium_hits
	return false

func _spawn_blood(contact_point: Vector2, impact_velocity: Vector2, contact_quality: float, directional_presentation: bool = false, amount_scale: float = 1.0, size_scale: float = 1.0) -> void:
	if not enable_blood_splatter:
		return
	# Spray is thrown along the blade's own travel direction (impact_velocity),
	# so a cut always flings blood the way the sword was moving. Sword hits keep
	# a tight directional jet; other impacts fan out broadly.
	var blade_travel: Vector2 = impact_velocity.normalized() if impact_velocity.length_squared() > 1.0 else Vector2.RIGHT
	var quality_scale: float = lerpf(0.7, 1.4, clampf(contact_quality, 0.0, 1.0))
	var safe_amount: float = maxf(0.0, amount_scale)
	var safe_size: float = maxf(0.0, size_scale)
	var scaled_count: int = maxi(0, roundi(float(blood_drop_count) * quality_scale * safe_amount))
	if scaled_count <= 0:
		return
	var spread: float = blood_spread_degrees * (0.4 if directional_presentation else 1.0)
	for index: int in range(scaled_count):
		var drop: BloodDrop = BloodDrop.new()
		drop.world_position = contact_point + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))
		var spread_angle: float = deg_to_rad(randf_range(-spread, spread))
		var speed: float = blood_drop_speed * randf_range(0.55, 1.3) * quality_scale
		drop.velocity = blade_travel.rotated(spread_angle) * speed
		drop.radius = randf_range(2.0, 4.6) * lerpf(0.9, 1.25, clampf(contact_quality, 0.0, 1.0)) * safe_size
		drop.total_life = blood_drop_lifetime * randf_range(0.7, 1.25)
		drop.life = drop.total_life
		blood_drops.append(drop)

func _snap_split_cut_direction(cut_direction: Vector2) -> Vector2:
	if cut_direction.length_squared() < 0.001:
		return Vector2.RIGHT
	var normalized: Vector2 = cut_direction.normalized()
	if absf(normalized.x) >= absf(normalized.y):
		return Vector2.RIGHT if normalized.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if normalized.y >= 0.0 else Vector2.UP

func _extract_frame_texture(source: Texture2D) -> ImageTexture:
	if source == null:
		return null
	if source is AtlasTexture:
		var atlas_texture: AtlasTexture = source as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		var atlas_image: Image = atlas_texture.atlas.get_image()
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region: Rect2i = Rect2i(atlas_texture.region.position, atlas_texture.region.size)
		if region.size.x <= 0 or region.size.y <= 0:
			return null
		var frame_image: Image = atlas_image.get_region(region)
		if frame_image == null or frame_image.is_empty():
			return null
		var source_size: Vector2i = Vector2i(atlas_texture.get_size())
		if source_size.x > 0 and source_size.y > 0 and Vector2i(atlas_texture.region.size) != source_size:
			var crop_x: int = maxi(0, floori(float(region.size.x - source_size.x) * 0.5))
			var crop_y: int = maxi(0, floori(float(region.size.y - source_size.y) * 0.5))
			var crop_width: int = mini(source_size.x, frame_image.get_width() - crop_x)
			var crop_height: int = mini(source_size.y, frame_image.get_height() - crop_y)
			if crop_width > 0 and crop_height > 0:
				frame_image = frame_image.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))
		return ImageTexture.create_from_image(frame_image)
	var source_image: Image = source.get_image()
	if source_image == null or source_image.is_empty():
		return null
	return ImageTexture.create_from_image(source_image)

func _split_image_halves(source_image: Image, horizontal_cut: bool) -> Array[ImageTexture]:
	var halves: Array[ImageTexture] = []
	if source_image == null or source_image.is_empty():
		return halves
	var cut_x: int = maxi(1, floori(float(source_image.get_width()) / 2.0))
	var cut_y: int = maxi(1, floori(float(source_image.get_height()) / 2.0))
	var regions: Array[Rect2i] = []
	if horizontal_cut:
		regions = [Rect2i(0, 0, source_image.get_width(), cut_y), Rect2i(0, cut_y, source_image.get_width(), source_image.get_height() - cut_y)]
	else:
		regions = [Rect2i(0, 0, cut_x, source_image.get_height()), Rect2i(cut_x, 0, source_image.get_width() - cut_x, source_image.get_height())]
	for region: Rect2i in regions:
		if region.size.x <= 0 or region.size.y <= 0:
			return []
		var half_image: Image = source_image.get_region(region)
		halves.append(ImageTexture.create_from_image(half_image))
	return halves

func _split_half_textures(source: Texture2D, horizontal_cut: bool) -> Array[ImageTexture]:
	var frame_texture: ImageTexture = _extract_frame_texture(source)
	if frame_texture == null:
		return []
	return _split_image_halves(frame_texture.get_image(), horizontal_cut)

func _spawn_split_remnant(spawn_position: Vector2, cut_direction: Vector2, source: Texture2D, sprite_scale: float, flip_h: bool, drift_velocity: Vector2 = Vector2.ZERO) -> void:
	if source == null:
		return
	var extracted_frame: ImageTexture = _extract_frame_texture(source)
	if extracted_frame == null:
		return
	var source_size: Vector2 = extracted_frame.get_size()
	if source_size.x < 2.0 or source_size.y < 2.0:
		return
	var remnant: SplitRemnant = SplitRemnant.new()
	var snapped_direction: Vector2 = _snap_split_cut_direction(cut_direction)
	var horizontal_cut: bool = absf(snapped_direction.y) > 0.5
	var frame_image: Image = extracted_frame.get_image()
	if flip_h:
		frame_image.flip_x()
	remnant.world_position = spawn_position
	remnant.cut_direction = snapped_direction
	remnant.horizontal_cut = horizontal_cut
	remnant.sprite_scale = sprite_scale
	remnant.half_textures = _split_image_halves(frame_image, horizontal_cut)
	if remnant.half_textures.size() != 2:
		return
	var extent: float = (source_size.y if horizontal_cut else source_size.x) * sprite_scale * 0.5
	var separation_normal: Vector2 = snapped_direction.orthogonal()
	if flip_h and not horizontal_cut:
		separation_normal.x *= -1.0
	# Halves fly the way the blade was travelling, plus a small outward peel and
	# a touch of lift; split_separation_speed keeps them from launching far.
	var drift: Vector2 = drift_velocity.normalized() * split_drift_speed if drift_velocity.length_squared() > 1.0 else Vector2.ZERO
	var initial_gap: Vector2 = separation_normal * extent * 0.06
	remnant.half_offsets = [-initial_gap, initial_gap]
	remnant.half_velocities = [
		-separation_normal * split_separation_speed + drift + Vector2.UP * 16.0,
		separation_normal * split_separation_speed + drift + Vector2.UP * 16.0,
	]
	remnant.half_rotation = [0.0, 0.0]
	remnant.half_spin = [-split_spin_speed, split_spin_speed]
	remnant.total_life = split_kill_duration
	remnant.life = remnant.total_life
	split_remnants.append(remnant)

func _spawn_split_blood_pool(spawn_position: Vector2, source: Texture2D, sprite_scale: float) -> void:
	if not is_inside_tree():
		return
	var decals: Node = get_tree().get_first_node_in_group("blood_decals")
	if decals == null or not decals.has_method("spawn_pool"):
		return
	var source_width: float = source.get_size().x if source != null else 64.0
	var pool_radius: float = clampf(source_width * sprite_scale * 0.45, 12.0, 70.0)
	decals.call("spawn_pool", spawn_position, pool_radius)

func _update_world_particles(delta: float) -> void:
	for index: int in range(blood_drops.size() - 1, -1, -1):
		var drop: BloodDrop = blood_drops[index]
		drop.life -= delta
		if drop.life <= 0.0:
			blood_drops.remove_at(index)
			continue
		drop.velocity += Vector2.DOWN * 640.0 * delta
		drop.velocity *= maxf(0.0, 1.0 - delta * 1.3)
		drop.world_position += drop.velocity * delta
	for index: int in range(split_remnants.size() - 1, -1, -1):
		var remnant: SplitRemnant = split_remnants[index]
		remnant.life -= delta
		for half_index: int in range(remnant.half_offsets.size()):
			var half_velocity: Vector2 = remnant.half_velocities[half_index]
			half_velocity += Vector2.DOWN * split_gravity * delta
			half_velocity *= maxf(0.0, 1.0 - delta * 1.6)
			remnant.half_velocities[half_index] = half_velocity
			remnant.half_offsets[half_index] += half_velocity * delta
			if half_index < remnant.half_rotation.size():
				remnant.half_rotation[half_index] += remnant.half_spin[half_index] * delta
		if remnant.life <= 0.0: split_remnants.remove_at(index)

func _update_damage_numbers(delta: float) -> void:
	for index: int in range(floating_damage_numbers.size() - 1, -1, -1):
		var number: FloatingDamageNumber = floating_damage_numbers[index]
		number.life -= delta
		if number.life <= 0.0 or number.label == null or not is_instance_valid(number.label):
			if number.label != null and is_instance_valid(number.label): number.label.queue_free()
			floating_damage_numbers.remove_at(index)
			continue
		number.world_position += number.velocity * delta
		number.velocity.x = move_toward(number.velocity.x, 0.0, 35.0 * delta)
		number.velocity.y = move_toward(number.velocity.y, -18.0, 42.0 * delta)
		var progress: float = 1.0 - number.life / maxf(number.total_life, 0.001)
		_update_damage_number_label(number, progress)

func _update_damage_number_label(number: FloatingDamageNumber, progress: float) -> void:
	if number.label == null: return
	# Stored positions are global world coordinates, not world_root-local points.
	# Reproject every frame so existing numbers follow camera movement and zoom.
	# With Classic's identity canvas this retains the original placement.
	var overlay_position: Vector2 = number.world_position
	if is_instance_valid(world_root):
		var viewport_position: Vector2 = world_root.get_canvas_transform() * number.world_position
		overlay_position = number.label.get_canvas_transform().affine_inverse() * viewport_position
	number.label.position = overlay_position - number.label.size * 0.5
	var pop_scale: float = 1.0
	if progress < 0.16:
		pop_scale = lerpf(0.62, 1.16, progress / 0.16)
	elif progress < 0.34:
		pop_scale = lerpf(1.16, 1.0, (progress - 0.16) / 0.18)
	var fade: float = clampf(number.life / maxf(number.total_life * 0.38, 0.001), 0.0, 1.0)
	number.label.scale = Vector2.ONE * number.size_scale * pop_scale
	number.label.modulate = Color(1.0, 1.0, 1.0, fade)
	number.label.visible = enabled and enable_floating_damage_numbers

func _process(delta: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	var bind_zoom_target: float = bind_focus_zoom_amount if bind_focus_active else 0.0
	bind_focus_zoom_current = lerpf(bind_focus_zoom_current, bind_zoom_target, 1.0 - exp(-bind_focus_response * real_delta))
	pulse_time += delta
	effect_left = maxf(0.0, effect_left - delta)
	zoom_left = maxf(0.0, zoom_left - delta)
	blur_left = maxf(0.0, blur_left - delta)
	parry_focus_left = maxf(0.0, parry_focus_left - delta)
	_update_world_particles(delta)
	_update_impact_time_slow(delta)
	_update_micro_zoom()
	_update_damage_numbers(delta)
	_update_blur()
	_update_parry_vignette()
	_update_status_vignette()
	if effect_left > 0.0 or not blood_drops.is_empty() or not split_remnants.is_empty(): queue_redraw()

func _draw() -> void:
	if not enabled: return
	if enable_speed_lines and effect_left > 0.0:
		var progress: float = 1.0 - effect_left / maxf(active_effect_duration, 0.001)
		var fade: float = 1.0 - progress
		var tangent: Vector2 = effect_direction.orthogonal()
		var current_length: float = line_length * effect_strength * (0.65 + progress * 0.35)
		for index: int in range(line_count):
			var normalized_index: float = (float(index) + 0.5) / float(maxi(1, line_count))
			var centered_offset: float = (normalized_index - 0.5) * 2.0
			var offset: float = centered_offset * line_spread + sin(effect_seed + float(index) * 2.7) * line_spread * 0.22
			var streak_center: Vector2 = tangent * offset
			var streak_start: Vector2 = streak_center + effect_direction * line_start_distance
			var streak_end: Vector2 = streak_start + effect_direction * current_length
			var streak_color: Color = Color(line_color.r, line_color.g, line_color.b, line_color.a * fade)
			draw_line(streak_start, streak_end, streak_color, line_width * effect_strength, true)
	_draw_blood_drops()
	_draw_split_remnants()

func _draw_blood_drops() -> void:
	for drop: BloodDrop in blood_drops:
		var life_ratio: float = clampf(drop.life / maxf(drop.total_life, 0.001), 0.0, 1.0)
		var local_position: Vector2 = _world_to_fx_local(drop.world_position)
		var fade: float = clampf(life_ratio * 1.7, 0.0, 1.0)
		var drop_color: Color = Color(blood_color.r, blood_color.g, blood_color.b, blood_color.a * fade)
		# Motion smear behind each droplet, so the spray reads as travelling.
		if drop.velocity.length_squared() > 1.0:
			var trail_direction: Vector2 = -drop.velocity.normalized()
			var trail_color: Color = Color(drop_color.r, drop_color.g, drop_color.b, drop_color.a * 0.7)
			draw_line(local_position, local_position + trail_direction * drop.radius * 2.6, trail_color, drop.radius * 0.9, true)
		draw_circle(local_position, drop.radius, drop_color)
		# Wet highlight core.
		var highlight: Color = Color(minf(1.0, blood_color.r + 0.28), blood_color.g + 0.02, blood_color.b + 0.02, drop_color.a)
		draw_circle(local_position, drop.radius * 0.45, highlight)

func _world_to_fx_local(world_position: Vector2) -> Vector2:
	# _draw() renders in THIS node's local space, and trigger_tuned() moves the
	# node to the impact point (global_position = impact_position). Converting via
	# the parent would drop the node's own offset, so particles would render at
	# roughly double their world position (off-screen). Convert through self.
	return to_local(world_position)

func _draw_split_remnants() -> void:
	for remnant: SplitRemnant in split_remnants:
		var life_ratio: float = clampf(remnant.life / maxf(remnant.total_life, 0.001), 0.0, 1.0)
		var base_position: Vector2 = _world_to_fx_local(remnant.world_position)
		# Hold most of the life, then dissolve in the last stretch.
		var fade_alpha: float = smoothstep(0.0, 0.5, life_ratio)
		var half_size: Vector2 = remnant.half_textures[0].get_size()
		var source_size: Vector2 = half_size * 2.0
		for half_index: int in range(remnant.half_textures.size()):
			var half_texture: ImageTexture = remnant.half_textures[half_index]
			var half_offset: Vector2 = remnant.half_offsets[half_index]
			var half_position: Vector2 = base_position + half_offset
			var half_angle: float = remnant.half_rotation[half_index] if half_index < remnant.half_rotation.size() else 0.0
			# Draw the frame so its CUT SEAM sits on the transform origin; rotating
			# then hinges each half open on the cut line rather than its own centre.
			var draw_origin: Vector2 = _split_half_draw_origin(half_texture.get_size(), remnant.horizontal_cut, half_index)
			var half_tint: Color = Color(1.0, 1.0, 1.0, fade_alpha)
			draw_set_transform(half_position, half_angle, Vector2.ONE * remnant.sprite_scale)
			draw_texture(half_texture, draw_origin, half_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var flash_alpha: float = life_ratio * maxf(0.0, 1.0 - (1.0 - life_ratio) * 4.0)
		if flash_alpha > 0.0:
			var cut_color: Color = Color(split_cut_flash_color.r, split_cut_flash_color.g, split_cut_flash_color.b, split_cut_flash_color.a * flash_alpha)
			var cut_line_start: Vector2 = Vector2(-source_size.x * 0.5, 0.0) if remnant.horizontal_cut else Vector2(0.0, -source_size.y * 0.5)
			var cut_line_end: Vector2 = Vector2(source_size.x * 0.5, 0.0) if remnant.horizontal_cut else Vector2(0.0, source_size.y * 0.5)
			draw_set_transform(base_position, 0.0, Vector2.ONE * remnant.sprite_scale)
			draw_line(cut_line_start, cut_line_end, cut_color, 2.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _split_half_draw_origin(half_size: Vector2, horizontal_cut: bool, half_index: int) -> Vector2:
	# Place the seam edge of the half at the local origin so rotation pivots there.
	if horizontal_cut:
		return Vector2(-half_size.x * 0.5, -half_size.y if half_index == 0 else 0.0)
	return Vector2(-half_size.x if half_index == 0 else 0.0, -half_size.y * 0.5)

func _setup_screen_overlay() -> void:
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 1
	add_child(overlay_layer)
	blur_rect = ColorRect.new()
	blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(blur_rect)
	blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var blur_shader: Shader = Shader.new()
	blur_shader.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius_pixels = 2.0;
uniform float blur_mix = 0.45;
void fragment() {
	vec2 offset = SCREEN_PIXEL_SIZE * radius_pixels;
	vec4 source = texture(screen_texture, SCREEN_UV);
	vec4 blurred = source * 0.28;
	blurred += texture(screen_texture, SCREEN_UV + vec2(offset.x, 0.0)) * 0.12;
	blurred += texture(screen_texture, SCREEN_UV - vec2(offset.x, 0.0)) * 0.12;
	blurred += texture(screen_texture, SCREEN_UV + vec2(0.0, offset.y)) * 0.12;
	blurred += texture(screen_texture, SCREEN_UV - vec2(0.0, offset.y)) * 0.12;
	blurred += texture(screen_texture, SCREEN_UV + offset) * 0.06;
	blurred += texture(screen_texture, SCREEN_UV - offset) * 0.06;
	blurred += texture(screen_texture, SCREEN_UV + vec2(offset.x, -offset.y)) * 0.06;
	blurred += texture(screen_texture, SCREEN_UV + vec2(-offset.x, offset.y)) * 0.06;
	COLOR = mix(source, blurred, blur_mix);
}
"""
	blur_material = ShaderMaterial.new()
	blur_material.shader = blur_shader
	blur_rect.material = blur_material
	blur_rect.visible = false
	status_vignette_rect = ColorRect.new()
	status_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(status_vignette_rect)
	status_vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var status_vignette_shader: Shader = Shader.new()
	status_vignette_shader.code = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(1.0, 0.84, 0.32, 1.0);
uniform float intensity = 0.0;
uniform float inner_radius = 0.42;
uniform float outer_radius = 0.95;
void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(inner_radius, outer_radius, length(centered_uv));
	COLOR = vec4(vignette_color.rgb, vignette_color.a * intensity * edge);
}
"""
	status_vignette_material = ShaderMaterial.new()
	status_vignette_material.shader = status_vignette_shader
	status_vignette_rect.material = status_vignette_material
	status_vignette_rect.visible = false
	vignette_rect = ColorRect.new()
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_layer.add_child(vignette_rect)
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette_shader: Shader = Shader.new()
	vignette_shader.code = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.03, 0.035, 0.055, 1.0);
uniform float intensity = 0.0;
uniform float inner_radius = 0.35;
uniform float outer_radius = 0.9;
void fragment() {
	vec2 centered_uv = (UV - vec2(0.5)) * 2.0;
	float edge = smoothstep(inner_radius, outer_radius, length(centered_uv));
	COLOR = vec4(vignette_color.rgb, vignette_color.a * intensity * edge);
}
"""
	vignette_material = ShaderMaterial.new()
	vignette_material.shader = vignette_shader
	vignette_rect.material = vignette_material
	vignette_rect.visible = false

func _update_micro_zoom() -> void:
	if world_root == null: return
	# Sustained bind focus is camera-only: unlike Classic's legacy one-shot root
	# pulse, it must never keep physics/collision children scaled for seconds.
	var camera_focus_available: bool = is_instance_valid(presentation_camera) and presentation_camera.enabled
	var zoom_scale: float = 1.0 + (bind_focus_zoom_current if camera_focus_available else 0.0)
	if enabled and enable_micro_zoom and zoom_left > 0.0:
		var zoom_progress: float = 1.0 - zoom_left / maxf(active_zoom_duration, 0.001)
		zoom_scale += active_zoom_amount * zoom_strength * sin(zoom_progress * PI)
	if is_instance_valid(presentation_camera) and presentation_camera.enabled:
		# HD presentation must never scale or translate gameplay/physics nodes.
		presentation_camera.zoom = camera_rest_zoom * zoom_scale
		return
	world_root.position -= zoom_position_offset
	world_root.scale = Vector2.ONE * zoom_scale
	var viewport_center: Vector2 = get_viewport_rect().size * 0.5
	zoom_position_offset = viewport_center * (1.0 - zoom_scale)
	world_root.position += zoom_position_offset
	classic_zoom_applied = true

func reset_micro_zoom() -> void:
	zoom_left = 0.0
	bind_focus_active = false
	bind_focus_zoom_current = 0.0
	bind_focus_zoom_amount = 0.0
	Engine.time_scale = 1.0
	if is_instance_valid(presentation_camera):
		presentation_camera.zoom = camera_rest_zoom
	if classic_zoom_applied and is_instance_valid(world_root):
		world_root.position -= zoom_position_offset
		world_root.scale = Vector2.ONE
	zoom_position_offset = Vector2.ZERO
	classic_zoom_applied = false

func _update_blur() -> void:
	if blur_rect == null or blur_material == null: return
	var is_hd_world: bool = is_instance_valid(world_root) and str(world_root.get("visual_style")) == "hd"
	var world_is_visible: bool = not is_instance_valid(world_root) or world_root.is_visible_in_tree()
	var blur_active: bool = enabled and enable_special_event_blur and blur_left > 0.0 and world_is_visible and (not is_hd_world or forest_screen_blur_allowed)
	blur_rect.visible = blur_active
	if not blur_active: return
	var blur_progress: float = 1.0 - blur_left / maxf(blur_duration, 0.001)
	var blur_fade: float = sin(blur_progress * PI)
	blur_material.set_shader_parameter("radius_pixels", blur_radius_pixels)
	blur_material.set_shader_parameter("blur_mix", blur_mix * blur_fade)

func _update_impact_time_slow(delta: float) -> void:
	if world_root != null and bool(world_root.get("hitstop_active")): return
	if enabled and enable_impact_time_slow and time_slow_left > 0.0:
		Engine.time_scale = impact_time_scale
		var real_delta: float = delta / maxf(impact_time_scale, 0.001)
		time_slow_left = maxf(0.0, time_slow_left - real_delta)
	elif bind_focus_active:
		Engine.time_scale = bind_focus_world_scale
	else:
		Engine.time_scale = 1.0

func _update_parry_vignette() -> void:
	if vignette_rect == null or vignette_material == null: return
	var vignette_active: bool = enabled and enable_parry_focus_vignette and parry_focus_left > 0.0
	vignette_rect.visible = vignette_active
	if not vignette_active: return
	var vignette_progress: float = 1.0 - parry_focus_left / maxf(active_parry_focus_duration, 0.001)
	var vignette_fade: float = sin(vignette_progress * PI)
	vignette_material.set_shader_parameter("vignette_color", parry_vignette_color)
	vignette_material.set_shader_parameter("intensity", parry_vignette_max_alpha * active_parry_focus_strength * vignette_fade)
	vignette_material.set_shader_parameter("inner_radius", parry_vignette_inner_radius)
	vignette_material.set_shader_parameter("outer_radius", maxf(parry_vignette_inner_radius + 0.01, parry_vignette_outer_radius))

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	reset_micro_zoom()

func status_vignette_state() -> Dictionary:
	var low_health_alpha: float = 0.0
	var high_flow_alpha: float = 0.0
	var danger_strength: float = 0.0
	if enabled and player_ref != null:
		if enable_low_health_vignette and player_ref.max_health > 0.0:
			var health_ratio: float = clampf(player_ref.health / player_ref.max_health, 0.0, 1.0)
			danger_strength = clampf((low_health_threshold - health_ratio) / maxf(low_health_threshold, 0.001), 0.0, 1.0)
			var danger_pulse: float = 0.78 + 0.22 * (0.5 + 0.5 * sin(pulse_time * TAU * low_health_vignette_pulse_speed))
			low_health_alpha = danger_strength * low_health_vignette_max_alpha * danger_pulse
		if enable_high_flow_vignette and player_ref.flow > high_flow_threshold:
			var flow_strength: float = clampf((player_ref.flow - high_flow_threshold) / maxf(1.0, high_flow_full_intensity_flow - high_flow_threshold), 0.0, 1.0)
			var pulse_wave: float = 0.5 + 0.5 * sin(pulse_time * TAU * high_flow_vignette_pulse_speed)
			var flow_pulse: float = 1.0 - high_flow_vignette_pulse_amount + high_flow_vignette_pulse_amount * pulse_wave
			# Danger wins when both states are active; the focus color remains subtle.
			high_flow_alpha = flow_strength * high_flow_vignette_max_alpha * flow_pulse * (1.0 - danger_strength * 0.88)
	var combined_alpha: float = minf(low_health_alpha + high_flow_alpha, maxf(low_health_vignette_max_alpha, high_flow_vignette_max_alpha))
	var red_weight: float = low_health_alpha / maxf(low_health_alpha + high_flow_alpha, 0.001)
	var combined_color: Color = high_flow_vignette_color.lerp(low_health_vignette_color, clampf(red_weight, 0.0, 1.0))
	return {"active": combined_alpha > 0.001, "intensity": combined_alpha, "color": combined_color}

func _update_status_vignette() -> void:
	if status_vignette_rect == null or status_vignette_material == null: return
	var state: Dictionary = status_vignette_state()
	status_vignette_rect.visible = bool(state["active"])
	if not status_vignette_rect.visible: return
	status_vignette_material.set_shader_parameter("vignette_color", state["color"] as Color)
	status_vignette_material.set_shader_parameter("intensity", float(state["intensity"]))
	status_vignette_material.set_shader_parameter("inner_radius", status_vignette_inner_radius)
	status_vignette_material.set_shader_parameter("outer_radius", maxf(status_vignette_inner_radius + 0.01, status_vignette_outer_radius))
