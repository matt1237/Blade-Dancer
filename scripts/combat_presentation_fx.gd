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
	var body_color: Color = Color.WHITE
	var radius: float = 18.0
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
@export_range(0.0, 0.2, 0.01) var enemy_deformation_max_compression: float = 0.07
@export var enemy_deformation_duration: float = 0.1
@export_range(0.0, 0.1, 0.005) var enemy_deformation_spring_overshoot: float = 0.018

@export_category("Chakram Bat Deformation")
@export var enable_chakram_bat_deformation: bool = true
@export_range(0.0, 1.0, 0.05) var chakram_stretch_min_quality: float = 0.7
@export_range(0.0, 0.3, 0.01) var chakram_max_stretch: float = 0.14
@export var chakram_stretch_duration: float = 0.085

@export_category("High Quality Blood")
@export var enable_blood_splatter: bool = true
@export_range(0.0, 1.0, 0.05) var blood_min_quality: float = 0.8
@export var blood_drop_count: int = 9
@export var blood_drop_speed: float = 150.0
@export var blood_drop_lifetime: float = 0.42
@export var blood_spread_degrees: float = 55.0
@export var blood_color: Color = Color(0.55, 0.025, 0.035, 0.95)

@export_category("High Quality Split Kill")
@export var enable_split_kill: bool = true
@export_range(0.0, 1.0, 0.05) var split_kill_min_quality: float = 0.88
@export var split_kill_duration: float = 0.55
@export var split_half_separation: float = 44.0
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

func present_enemy_hit(enemy: Enemy, contact_point: Vector2, impact_velocity: Vector2, cut_direction: Vector2, contact_quality: float, killed: bool, sword_hit: bool = true) -> void:
	if not enabled: return
	if enable_enemy_hit_deformation and contact_quality >= enemy_deformation_min_quality and enemy != null and is_instance_valid(enemy):
		var quality_range: float = maxf(0.001, 1.0 - enemy_deformation_min_quality)
		var deformation_strength: float = clampf((contact_quality - enemy_deformation_min_quality) / quality_range, 0.0, 1.0)
		enemy.play_impact_deformation(impact_velocity, enemy_deformation_duration, enemy_deformation_max_compression * deformation_strength, enemy_deformation_spring_overshoot)
	if enable_blood_splatter and contact_quality >= blood_min_quality:
		_spawn_blood(contact_point, impact_velocity, contact_quality)
	if killed and sword_hit and enable_split_kill and contact_quality >= split_kill_min_quality:
		_spawn_split_remnant(enemy.global_position, cut_direction, enemy.remnant_color, enemy.remnant_radius)

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

func _spawn_blood(contact_point: Vector2, impact_velocity: Vector2, contact_quality: float) -> void:
	var base_direction: Vector2 = impact_velocity.normalized() if impact_velocity.length_squared() > 0.001 else Vector2.RIGHT
	var scaled_count: int = maxi(1, roundi(float(blood_drop_count) * lerpf(0.7, 1.25, contact_quality)))
	for index: int in range(scaled_count):
		var drop: BloodDrop = BloodDrop.new()
		drop.world_position = contact_point + Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
		var spread_angle: float = deg_to_rad(randf_range(-blood_spread_degrees, blood_spread_degrees))
		var speed: float = blood_drop_speed * randf_range(0.45, 1.15) * lerpf(0.8, 1.2, contact_quality)
		drop.velocity = base_direction.rotated(spread_angle) * speed
		drop.radius = randf_range(1.25, 3.2) * lerpf(0.8, 1.15, contact_quality)
		drop.total_life = blood_drop_lifetime * randf_range(0.75, 1.2)
		drop.life = drop.total_life
		blood_drops.append(drop)

func _spawn_split_remnant(spawn_position: Vector2, cut_direction: Vector2, body_color: Color, radius: float) -> void:
	var remnant: SplitRemnant = SplitRemnant.new()
	remnant.world_position = spawn_position
	remnant.cut_direction = cut_direction.normalized() if cut_direction.length_squared() > 0.001 else Vector2.RIGHT
	remnant.body_color = body_color
	remnant.radius = radius
	remnant.total_life = split_kill_duration
	remnant.life = remnant.total_life
	split_remnants.append(remnant)

func _update_world_particles(delta: float) -> void:
	for index: int in range(blood_drops.size() - 1, -1, -1):
		var drop: BloodDrop = blood_drops[index]
		drop.life -= delta
		if drop.life <= 0.0:
			blood_drops.remove_at(index)
			continue
		drop.velocity += Vector2.DOWN * 180.0 * delta
		drop.velocity *= maxf(0.0, 1.0 - delta * 2.2)
		drop.world_position += drop.velocity * delta
	for index: int in range(split_remnants.size() - 1, -1, -1):
		var remnant: SplitRemnant = split_remnants[index]
		remnant.life -= delta
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
		var local_position: Vector2 = drop.world_position - global_position
		var drop_color: Color = Color(blood_color.r, blood_color.g, blood_color.b, blood_color.a * life_ratio)
		var trail_direction: Vector2 = -drop.velocity.normalized() if drop.velocity.length_squared() > 0.001 else Vector2.ZERO
		draw_line(local_position, local_position + trail_direction * drop.radius * 2.4, drop_color, drop.radius, true)
		draw_circle(local_position, drop.radius, drop_color)

func _draw_split_remnants() -> void:
	for remnant: SplitRemnant in split_remnants:
		var life_ratio: float = clampf(remnant.life / maxf(remnant.total_life, 0.001), 0.0, 1.0)
		var progress: float = 1.0 - life_ratio
		var cut_tangent: Vector2 = remnant.cut_direction
		var separation_normal: Vector2 = cut_tangent.orthogonal()
		var base_position: Vector2 = remnant.world_position - global_position + Vector2.DOWN * progress * progress * 18.0
		var separation: float = split_half_separation * sin(progress * PI * 0.5)
		var body_color: Color = Color(remnant.body_color.r, remnant.body_color.g, remnant.body_color.b, life_ratio)
		for half_index: int in range(2):
			var side: float = -1.0 if half_index == 0 else 1.0
			var half_center: Vector2 = base_position + separation_normal * separation * 0.5 * side
			var half_polygon: PackedVector2Array = PackedVector2Array()
			var start_angle: float = PI if side < 0.0 else 0.0
			for arc_index: int in range(10):
				var arc_angle: float = start_angle + float(arc_index) * PI / 9.0
				var arc_point: Vector2 = cut_tangent * cos(arc_angle) * remnant.radius + separation_normal * sin(arc_angle) * remnant.radius
				half_polygon.append(half_center + arc_point)
			draw_colored_polygon(half_polygon, body_color)
			var seam_alpha: float = life_ratio * maxf(0.0, 1.0 - progress * 3.0)
			var seam_color: Color = Color(split_cut_flash_color.r, split_cut_flash_color.g, split_cut_flash_color.b, split_cut_flash_color.a * seam_alpha)
			draw_line(half_center - cut_tangent * remnant.radius, half_center + cut_tangent * remnant.radius, seam_color, 3.0, true)

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
