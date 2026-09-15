class_name SwordSmithingGame extends Control

## Small procedural Sword Smithing prototype.
## The forged blade is represented by per-section half-widths. This profile is
## intentionally exposed through forged_profile_polygon() so a later weapon
## system can use the same geometry for rendering and collision generation.

signal closed()

const SECTION_COUNT: int = 20
const SOURCE_BLADE_TEXTURE: Texture2D = preload("res://assets/Longsword Smithing Template.png")
const FORGE_STATION: int = 0
const ANVIL_STATION: int = 1
const QUENCH_STATION: int = 2

@export_category("Session")
@export var session_duration: float = 120.0

@export_category("Stations")
@export var forge_rect: Rect2 = Rect2(90.0, 235.0, 330.0, 245.0)
@export var anvil_rect: Rect2 = Rect2(505.0, 300.0, 390.0, 150.0)
@export var trough_rect: Rect2 = Rect2(1010.0, 300.0, 190.0, 150.0)
@export var ideal_strike_heat_min: float = 0.48
@export var ideal_strike_heat_max: float = 0.78
@export var billet_length: float = 240.0
@export var billet_initial_length: float = 92.0
@export var billet_cold_half_width: float = 24.0
@export var billet_position: Vector2 = Vector2(700.0, 375.0)

@export_category("Heat and Cooling")
## Temperature is stored per section from 0 (cold) to 1 (dangerously hot).
@export var heat_rate: float = 0.16
@export var bellows_recharge_duration: float = 0.8
@export var bellows_pumps_per_stage: int = 2
## Each active stage drops by one after this many seconds without enough pumping.
@export var forge_stage_duration: float = 10.0
@export var forge_cooling_multiplier: float = 0.55
@export var forge_hot_multiplier: float = 0.90
@export var forge_roaring_multiplier: float = 1.25
@export var forge_scorching_multiplier: float = 1.65
@export var cooling_rate: float = 0.035
@export var ideal_heat_min: float = 0.48
@export var ideal_heat_max: float = 0.78
@export var minimum_quench_accuracy: float = 0.75

@export_category("Scoring")
@export var maximum_score: int = 10000
## Even a last-second finish retains this fraction of its time factor.
@export_range(0.0, 1.0, 0.05) var minimum_time_factor: float = 0.50
## Strikes through this count carry no efficiency penalty.
@export var efficient_strike_count: int = 30
## Multiplicative score loss for every strike beyond the efficient allowance.
@export_range(0.0, 0.1, 0.005) var extra_strike_penalty: float = 0.01
## Prevents strike inefficiency from erasing an otherwise good blade entirely.
@export_range(0.0, 1.0, 0.05) var minimum_strike_factor: float = 0.25
## A poor quench lowers score without erasing the shaping work entirely.
@export_range(0.0, 1.0, 0.05) var minimum_quench_heat_factor: float = 0.40

@export_category("Hammering")
@export var hammer_recharge_duration: float = 0.8
@export_range(0.05, 1.0, 0.05) var minimum_hammer_strength_factor: float = 0.20
@export var hammer_strength: float = 0.34
@export var hammer_radius_sections: float = 2.2
@export var length_stretch_strength: float = 0.22
## Tip/tang use a completion curve: restrained initially, increasingly strong
## near the trace so progress does not asymptotically grind to a halt.
@export var endpoint_initial_multiplier: float = 1.10
@export var endpoint_deformation_multiplier: float = 4.0
@export var endpoint_stretch_multiplier: float = 4.0
@export var endpoint_completion_curve: float = 1.65
## Must remain below the dedicated template's 0.5px tip width.
@export var minimum_metal_half_width: float = 0.25
@export var hammer_overshoot: float = 0.16

var section_half_widths: Array[float] = []
var bottom_half_widths: Array[float] = []
var section_positions: Array[float] = []
var target_positions: Array[float] = []
var section_temperatures: Array[float] = []
var target_half_widths: Array[float] = []
var billet_station: int = ANVIL_STATION
var dragging_billet: bool = false
## false = hammer the top edge; true = flip the billet and hammer the bottom edge.
var flipped: bool = false
var strike_count: int = 0
var finished: bool = false
var last_mouse_position: Vector2 = Vector2.ZERO
var source_blade_image: Image = null
var time_left: float = 0.0
var strike_flash_position: Vector2 = Vector2.ZERO
var strike_flash_time_left: float = 0.0
var strike_feedback: int = 0
var was_quenched: bool = false
var final_quench_heat_accuracy: float = 0.0
var hammer_charge: float = 1.0
var hammer_charge_was_full: bool = true
var hammer_ready_spark_time_left: float = 0.0
var hammer_fill_style: StyleBoxFlat = null
var bellows_charge: float = 1.0
var bellows_pump_count: int = 0
var forge_stage: int = 0
var forge_stage_time_left: float = 0.0
var smithing_audio_manager: AudioManager = null

@onready var timer_label: Label = $HUD/Timer
@onready var strike_count_label: Label = $HUD/StrikeCount
@onready var score_label: Label = $HUD/Score
@onready var quench_heat_label: Label = $HUD/QuenchHeat
@onready var accuracy_label: Label = $HUD/Accuracy
@onready var heat_label: Label = $HUD/Heat
@onready var quality_label: Label = $HUD/Quality
@onready var status_label: Label = $HUD/Status
@onready var finish_label: Label = $HUD/Finish
@onready var close_button: Button = $HUD/Close
@onready var reset_button: Button = $HUD/Reset
@onready var hammer_charge_bar: ProgressBar = $HUD/HammerCharge
@onready var bellows_button: Button = $HUD/Bellows
@onready var bellows_charge_bar: ProgressBar = $HUD/BellowsCharge
@onready var forge_stage_label: Label = $HUD/ForgeStage

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close)
	reset_button.pressed.connect(reset_forge)
	bellows_button.pressed.connect(_pump_bellows)
	hammer_fill_style = StyleBoxFlat.new()
	hammer_fill_style.bg_color = Color("74787d")
	hammer_fill_style.corner_radius_top_left = 5
	hammer_fill_style.corner_radius_top_right = 5
	hammer_fill_style.corner_radius_bottom_left = 5
	hammer_fill_style.corner_radius_bottom_right = 5
	hammer_charge_bar.add_theme_stylebox_override("fill", hammer_fill_style)
	smithing_audio_manager = AudioManager.new()
	smithing_audio_manager.name = "SmithingAudioManager"
	add_child(smithing_audio_manager)
	source_blade_image = SOURCE_BLADE_TEXTURE.get_image()
	reset_forge()
	queue_redraw()

func reset_forge() -> void:
	section_half_widths.clear()
	bottom_half_widths.clear()
	section_positions.clear()
	target_positions.clear()
	section_temperatures.clear()
	target_half_widths.clear()
	for section_index: int in range(SECTION_COUNT):
		section_half_widths.append(billet_cold_half_width)
		bottom_half_widths.append(billet_cold_half_width)
		var normalized: float = float(section_index) / float(SECTION_COUNT - 1)
		section_positions.append(_initial_section_position(section_index))
		target_positions.append(normalized)
		section_temperatures.append(0.0)
		target_half_widths.append(_target_width_for_section(section_index))
	if source_blade_image != null:
		target_half_widths = _build_source_blade_profile()
	billet_station = FORGE_STATION
	billet_position = forge_rect.get_center()
	dragging_billet = false
	flipped = false
	strike_count = 0
	time_left = session_duration
	strike_flash_position = Vector2.ZERO
	strike_flash_time_left = 0.0
	strike_feedback = 0
	was_quenched = false
	final_quench_heat_accuracy = 0.0
	hammer_charge = 1.0
	hammer_charge_was_full = true
	hammer_ready_spark_time_left = 0.0
	bellows_charge = 1.0
	bellows_pump_count = 0
	forge_stage = 0
	forge_stage_time_left = 0.0
	finished = false
	if finish_label != null: finish_label.visible = false
	if status_label != null: status_label.text = "Fresh billet placed over the forge hotspot."
	_update_hud()
	queue_redraw()

func _build_source_blade_profile() -> Array[float]:
	var raw_widths: Array[float] = []
	var maximum_width: float = 1.0
	# Find the real bright-metal bounds inside the template. Its outer image rows
	# are black padding; sampling those rows made both ends look blunt/cropped.
	var crop_bottom: int = source_blade_image.get_height() - 1
	var crop_top: int = 0
	for pixel_y: int in range(source_blade_image.get_height()):
		var row_has_metal: bool = false
		for pixel_x: int in range(source_blade_image.get_width()):
			var bound_pixel: Color = source_blade_image.get_pixel(pixel_x, pixel_y)
			var bound_brightness: float = (bound_pixel.r + bound_pixel.g + bound_pixel.b) / 3.0
			if bound_brightness > 0.55:
				row_has_metal = true
				break
		if row_has_metal:
			crop_bottom = mini(crop_bottom, pixel_y)
			crop_top = maxi(crop_top, pixel_y)
	for section_index: int in range(SECTION_COUNT):
		var sample_y: int = int(lerpf(float(crop_top), float(crop_bottom), float(section_index) / float(SECTION_COUNT - 1)))
		var left_pixel: int = source_blade_image.get_width()
		var right_pixel: int = -1
		for pixel_x: int in range(source_blade_image.get_width()):
			var pixel: Color = source_blade_image.get_pixel(pixel_x, sample_y)
			var brightness: float = (pixel.r + pixel.g + pixel.b) / 3.0
			if brightness > 0.55:
				left_pixel = mini(left_pixel, pixel_x)
				right_pixel = maxi(right_pixel, pixel_x)
		var raw_width: float = float(maxi(1, right_pixel - left_pixel + 1))
		raw_widths.append(raw_width)
		maximum_width = maxf(maximum_width, raw_width)
	var profile: Array[float] = []
	for raw_width: float in raw_widths:
		profile.append(lerpf(4.0, billet_cold_half_width * 0.84, raw_width / maximum_width))
	# The photographed template's single-pixel point would otherwise be widened
	# by the minimum profile width. Preserve it as an actual visible tip.
	if not profile.is_empty(): profile[0] = 0.5
	return profile

func _target_width_for_section(section_index: int) -> float:
	# One uncomplicated sword profile: narrow point, broad blade, then a
	# slightly narrower base. No guard, handle, or pommel in this prototype.
	var normalized: float = float(section_index) / float(SECTION_COUNT - 1)
	if normalized < 0.12: return lerpf(5.0, 25.0, normalized / 0.12)
	if normalized < 0.78: return 25.0
	return lerpf(25.0, 17.0, (normalized - 0.78) / 0.22)

func _process(delta: float) -> void:
	if finished: return
	time_left = maxf(0.0, time_left - delta)
	strike_flash_time_left = maxf(0.0, strike_flash_time_left - delta)
	_update_hammer_recharge(delta)
	hammer_ready_spark_time_left = maxf(0.0, hammer_ready_spark_time_left - delta)
	bellows_charge = minf(1.0, bellows_charge + delta / maxf(0.001, bellows_recharge_duration))
	_update_forge_stage_decay(delta)
	if time_left <= 0.0:
		_finish_from_timeout()
		return
	_update_billet_temperatures(delta)
	_update_hud()
	queue_redraw()

func _finish_from_timeout() -> void:
	finished = true
	if finish_label != null:
		finish_label.visible = true
		finish_label.text = "TIME!\n%s — %.1f%% accuracy\nScore: %d  |  %d strikes" % [quality_rating(), shape_accuracy() * 100.0, smithing_score(), strike_count]
	if status_label != null: status_label.text = "The workshop bell rings. Your unfinished blade is preserved."
	queue_redraw()

func _section_world_x(section_index: int) -> float:
	return billet_position.x + (section_positions[section_index] - 0.5) * billet_length

func _update_hammer_recharge(delta: float) -> void:
	var was_full_before_update: bool = hammer_charge_was_full
	hammer_charge = minf(1.0, hammer_charge + delta / maxf(0.001, hammer_recharge_duration))
	hammer_charge_was_full = hammer_charge >= 1.0
	if hammer_charge_was_full and not was_full_before_update:
		hammer_ready_spark_time_left = 0.35

func _update_billet_temperatures(delta: float) -> void:
	# Spatial overlap is authoritative, even while the tongs are still holding
	# the billet. Sweeping through the forge therefore heats each section live.
	_heat_billet(delta)

func _update_forge_stage_decay(delta: float) -> void:
	if forge_stage <= 0:
		forge_stage_time_left = 0.0
		return
	forge_stage_time_left = maxf(0.0, forge_stage_time_left - delta)
	if forge_stage_time_left <= 0.0:
		forge_stage -= 1
		forge_stage_time_left = forge_stage_duration if forge_stage > 0 else 0.0
		if status_label != null: status_label.text = "The forge settles to %s." % _forge_stage_name()

func _forge_heat_multiplier() -> float:
	match forge_stage:
		1: return forge_hot_multiplier
		2: return forge_roaring_multiplier
		3: return forge_scorching_multiplier
		_: return forge_cooling_multiplier

func _forge_stage_name() -> String:
	return ["COOLING", "HOT", "ROARING", "SCORCHING"][clampi(forge_stage, 0, 3)]

func _forge_stage_color() -> Color:
	match forge_stage:
		1: return Color("f2d46b") # Hot — yellow
		2: return Color("f29a45") # Roaring — orange
		3: return Color("ef5b4f") # Scorching — red
		_: return Color("8fc9e8") # Cooling — soft blue

func _pump_bellows() -> void:
	if finished or bellows_charge < 1.0: return
	bellows_charge = 0.0
	bellows_pump_count += 1
	if bellows_pump_count % maxi(1, bellows_pumps_per_stage) == 0:
		forge_stage = mini(3, forge_stage + 1)
	if forge_stage > 0: forge_stage_time_left = forge_stage_duration
	_play_sfx("smith_bellows", 0.9, 1.0)
	if status_label != null:
		status_label.text = "HWEUUF!  Forge: %s  (%d/%d pumps)" % [_forge_stage_name(), bellows_pump_count % maxi(1, bellows_pumps_per_stage), bellows_pumps_per_stage]
	queue_redraw()

func _heat_billet(delta: float) -> void:
	var stage_multiplier: float = _forge_heat_multiplier()
	for section_index: int in range(SECTION_COUNT):
		var section_point: Vector2 = Vector2(_section_world_x(section_index), billet_position.y)
		if forge_rect.has_point(section_point):
			var distance_from_hot_center: float = absf(section_point.x - forge_rect.get_center().x) / (forge_rect.size.x * 0.5)
			var local_heat: float = clampf(1.0 - distance_from_hot_center, 0.08, 1.0)
			section_temperatures[section_index] = clampf(section_temperatures[section_index] + heat_rate * stage_multiplier * local_heat * delta, 0.0, 1.0)
		else:
			section_temperatures[section_index] = maxf(0.0, section_temperatures[section_index] - cooling_rate * delta)

func _cool_billet(delta: float) -> void:
	for section_index: int in range(SECTION_COUNT):
		section_temperatures[section_index] = maxf(0.0, section_temperatures[section_index] - cooling_rate * delta)

func _gui_input(event: InputEvent) -> void:
	if finished: return
	if event is InputEventMouseMotion:
		last_mouse_position = event.position
		if dragging_billet: billet_position = event.position
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		last_mouse_position = event.position
		if event.pressed:
			var interaction: String = _interaction_at(event.position)
			if interaction == "tongs":
				dragging_billet = true
				accept_event()
			elif interaction == "hammer":
				_hammer_at(event.position)
				accept_event()
		else:
			if dragging_billet:
				dragging_billet = false
				_drop_billet(event.position)
				accept_event()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		# Physically turn the billet over: the former lower edge is now visibly
		# on top and becomes the edge struck by the hammer.
		var previous_top: Array[float] = section_half_widths
		section_half_widths = bottom_half_widths
		bottom_half_widths = previous_top
		flipped = not flipped
		if status_label != null: status_label.text = "Billet flipped — the opposite edge now faces the hammer."
		queue_redraw()

func _interaction_at(point: Vector2) -> String:
	if dragging_billet: return "tongs"
	var over_billet: bool = _billet_hit_test(point)
	if billet_station == ANVIL_STATION and anvil_rect.has_point(point):
		# The exposed/top edge is the hammering face. The lower half acts as a
		# deliberate tong grip so pickup and striking never compete for a click.
		if over_billet and point.y > billet_position.y + 3.0: return "tongs"
		return "hammer"
	if over_billet: return "tongs"
	return ""

func _billet_hit_test(point: Vector2) -> bool:
	var polygon: PackedVector2Array = _billet_polygon()
	return Geometry2D.is_point_in_polygon(point, polygon)

func _drop_billet(point: Vector2) -> void:
	if forge_rect.has_point(point):
		billet_station = FORGE_STATION
		billet_position = point
		if status_label != null: status_label.text = "Heating — move the billet around for an even glow."
	elif anvil_rect.has_point(point):
		billet_station = ANVIL_STATION
		billet_position = Vector2(anvil_rect.get_center().x, anvil_rect.get_center().y)
		if status_label != null: status_label.text = "On the anvil — click sections to hammer them."
	elif trough_rect.has_point(point):
		if shape_accuracy() >= minimum_quench_accuracy:
			_quench()
		else:
			billet_station = ANVIL_STATION
			billet_position = Vector2(anvil_rect.get_center().x, anvil_rect.get_center().y)
			if status_label != null: status_label.text = "The blade needs at least %.0f%% accuracy before quenching." % (minimum_quench_accuracy * 100.0)
	else:
		billet_station = ANVIL_STATION
		billet_position = Vector2(anvil_rect.get_center().x, anvil_rect.get_center().y)
		if status_label != null: status_label.text = "The billet returns to the anvil."

func _initial_section_position(section_index: int) -> float:
	var normalized: float = float(section_index) / float(SECTION_COUNT - 1)
	return 0.5 + (normalized - 0.5) * billet_initial_length / billet_length

func _section_completion(current_value: float, initial_value: float, target_value: float) -> float:
	var total_distance: float = absf(target_value - initial_value)
	if total_distance <= 0.0001: return 1.0
	var remaining_distance: float = absf(target_value - current_value)
	return clampf(1.0 - remaining_distance / total_distance, 0.0, 1.0)

func _endpoint_multiplier(completion: float, maximum_multiplier: float) -> float:
	var curved_completion: float = pow(clampf(completion, 0.0, 1.0), endpoint_completion_curve)
	return lerpf(endpoint_initial_multiplier, maximum_multiplier, curved_completion)

func _hammer_at(point: Vector2) -> void:
	var closest_section: int = 0
	var closest_distance: float = INF
	for section_index: int in range(SECTION_COUNT):
		var distance_to_section: float = absf(point.x - _section_world_x(section_index))
		if distance_to_section < closest_distance:
			closest_distance = distance_to_section
			closest_section = section_index
	# The billet is physically swapped on F, so the visible top edge is always
	# the only edge this strike may deform.
	var active_widths: Array[float] = section_half_widths
	var charge_strength: float = lerpf(minimum_hammer_strength_factor, 1.0, hammer_charge)
	var strike_heat: float = 0.0
	for section_index: int in range(SECTION_COUNT):
		var distance: float = absf(float(section_index - closest_section))
		var influence: float = exp(-distance * distance / (2.0 * hammer_radius_sections * hammer_radius_sections))
		var heat_factor: float = clampf(section_temperatures[section_index], 0.03, 1.0)
		var target_delta: float = target_half_widths[section_index] - active_widths[section_index]
		var edge_distance: int = mini(section_index, SECTION_COUNT - 1 - section_index)
		var edge_weight: float = 1.0 if edge_distance == 0 else (0.5 if edge_distance == 1 else 0.0)
		var width_completion: float = _section_completion(active_widths[section_index], billet_cold_half_width, target_half_widths[section_index])
		var position_completion: float = _section_completion(section_positions[section_index], _initial_section_position(section_index), target_positions[section_index])
		var adaptive_deformation: float = _endpoint_multiplier(width_completion, endpoint_deformation_multiplier)
		var adaptive_stretch: float = _endpoint_multiplier(position_completion, endpoint_stretch_multiplier)
		var deformation_boost: float = lerpf(1.0, adaptive_deformation, edge_weight)
		var stretch_boost: float = lerpf(1.0, adaptive_stretch, edge_weight)
		var overshoot: float = 1.0 + hammer_overshoot * sin(float(strike_count + section_index))
		var deformation_step: float = clampf(hammer_strength * charge_strength * heat_factor * influence * deformation_boost, 0.0, 1.0)
		var deformation: float = target_delta * deformation_step * overshoot
		if heat_factor > ideal_strike_heat_max:
			# Overheated metal slumps unpredictably instead of taking a clean blow.
			deformation += randf_range(-billet_cold_half_width * 0.24, billet_cold_half_width * 0.24) * influence
		active_widths[section_index] = clampf(active_widths[section_index] + deformation, minimum_metal_half_width, billet_cold_half_width * 1.6)
		if absf(active_widths[section_index] - target_half_widths[section_index]) < 0.35:
			active_widths[section_index] = target_half_widths[section_index]
		# Hot blows also stretch the billet length toward the full trace. Clamp
		# the interpolation step so the adaptive endpoint boost cannot overshoot.
		var stretch_step: float = clampf(length_stretch_strength * stretch_boost * charge_strength * heat_factor * influence, 0.0, 1.0)
		section_positions[section_index] = lerpf(section_positions[section_index], target_positions[section_index], stretch_step)
		if absf(section_positions[section_index] - target_positions[section_index]) < 0.003:
			section_positions[section_index] = target_positions[section_index]
		strike_heat += heat_factor * influence
	strike_count += 1
	hammer_charge = 0.0
	hammer_charge_was_full = false
	strike_flash_position = point
	strike_flash_time_left = 0.18
	var center_index: int = closest_section
	var center_heat: float = section_temperatures[center_index]
	if center_heat >= ideal_strike_heat_min and center_heat <= ideal_strike_heat_max:
		strike_feedback = 1
		_play_sfx("smith_ting", 0.7, 1.0)
		if status_label != null: status_label.text = "TING!  A clean strike — the hot metal yields."
	elif center_heat > ideal_strike_heat_max:
		strike_feedback = 3
		_play_sfx("smith_sizzle", 0.8, 1.0)
		if status_label != null: status_label.text = "SIZZLE!  Too hot — the metal buckles unpredictably."
	else:
		strike_feedback = 2
		_play_sfx("smith_donk", 0.7, 0.9)
		if status_label != null: status_label.text = "DONK!  Too cold — reheat this section."
	if strike_heat < 0.12 and status_label != null: status_label.text = "DONK!  That section is too cold; reheat the billet."

func _play_sfx(sound_name: String, intensity: float, pitch_scale: float) -> void:
	if smithing_audio_manager == null: return
	smithing_audio_manager.play_sfx(sound_name, intensity, pitch_scale)

func _quench() -> void:
	final_quench_heat_accuracy = quench_heat_accuracy()
	was_quenched = true
	finished = true
	billet_station = QUENCH_STATION
	_play_sfx("smith_quench", 1.0, 1.0)
	if finish_label != null:
		finish_label.visible = true
		finish_label.text = "QUENCHED!\n%s — %.1f%% shape  |  %.1f%% ideal heat\nScore: %d  |  %d strikes" % [quality_rating(), shape_accuracy() * 100.0, final_quench_heat_accuracy * 100.0, smithing_score(), strike_count]
	if status_label != null: status_label.text = "A satisfying hiss! Your forged blade is preserved."
	queue_redraw()

func shape_accuracy() -> float:
	var total_error: float = 0.0
	for section_index: int in range(SECTION_COUNT):
		total_error += absf(section_half_widths[section_index] - target_half_widths[section_index]) / billet_cold_half_width
		total_error += absf(bottom_half_widths[section_index] - target_half_widths[section_index]) / billet_cold_half_width
	var side_sample_count: float = float(SECTION_COUNT * 2)
	return clampf(1.0 - total_error / side_sample_count, 0.0, 1.0)

func time_score_factor() -> float:
	var remaining_ratio: float = clampf(time_left / maxf(0.001, session_duration), 0.0, 1.0)
	return lerpf(minimum_time_factor, 1.0, remaining_ratio)

func strike_score_factor() -> float:
	var extra_strikes: int = maxi(0, strike_count - efficient_strike_count)
	return maxf(minimum_strike_factor, 1.0 - float(extra_strikes) * extra_strike_penalty)

func quench_heat_accuracy() -> float:
	var ideal_total: float = 0.0
	for temperature: float in section_temperatures:
		if temperature >= ideal_heat_min and temperature <= ideal_heat_max:
			ideal_total += 1.0
		elif temperature < ideal_heat_min:
			ideal_total += clampf(temperature / maxf(0.001, ideal_heat_min), 0.0, 1.0)
		else:
			ideal_total += clampf((1.0 - temperature) / maxf(0.001, 1.0 - ideal_heat_max), 0.0, 1.0)
	return ideal_total / float(SECTION_COUNT)

func quench_score_factor() -> float:
	var heat_accuracy: float = final_quench_heat_accuracy if was_quenched else quench_heat_accuracy()
	return lerpf(minimum_quench_heat_factor, 1.0, heat_accuracy)

func smithing_score() -> int:
	return roundi(float(maximum_score) * shape_accuracy() * time_score_factor() * strike_score_factor() * quench_score_factor())

func quality_rating() -> String:
	var accuracy: float = shape_accuracy()
	if accuracy >= 0.98: return "MASTERWORK"
	if accuracy >= 0.90: return "EXCELLENT"
	if accuracy >= 0.75: return "DECENT"
	return "CRUDE"

func forged_profile_polygon() -> PackedVector2Array:
	# Future combat integration can consume this exact outline for both the
	# visible sword and collision geometry. No combat integration is done here.
	var polygon: PackedVector2Array = _billet_polygon()
	return polygon

func _billet_polygon() -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for section_index: int in range(SECTION_COUNT):
		polygon.append(Vector2(_section_world_x(section_index), billet_position.y - section_half_widths[section_index]))
	for section_index: int in range(SECTION_COUNT - 1, -1, -1):
		polygon.append(Vector2(_section_world_x(section_index), billet_position.y + bottom_half_widths[section_index]))
	return polygon

func _temperature_color(temperature: float) -> Color:
	if temperature < 0.18: return Color("25282b").lerp(Color("667078"), temperature / 0.18)
	if temperature < ideal_heat_min: return Color("a52d24").lerp(Color("e85b24"), (temperature - 0.18) / (ideal_heat_min - 0.18))
	if temperature < ideal_heat_max: return Color("f28a24").lerp(Color("ffc94f"), (temperature - ideal_heat_min) / (ideal_heat_max - ideal_heat_min))
	return Color("fff0a3").lerp(Color.WHITE, clampf((temperature - ideal_heat_max) / (1.0 - ideal_heat_max), 0.0, 1.0))

func _update_hud() -> void:
	if timer_label != null:
		var minutes: int = int(time_left / 60.0)
		var seconds: int = int(time_left) % 60
		timer_label.text = "TIME  %d:%02d" % [minutes, seconds]
	if hammer_charge_bar != null: hammer_charge_bar.value = hammer_charge * 100.0
	if hammer_fill_style != null:
		if hammer_charge >= 1.0:
			hammer_fill_style.bg_color = Color("55d66b")
		else:
			hammer_fill_style.bg_color = Color("74787d").lerp(Color("f1c84b"), hammer_charge)
	if bellows_charge_bar != null: bellows_charge_bar.value = bellows_charge * 100.0
	if bellows_button != null: bellows_button.disabled = bellows_charge < 1.0 or finished
	if forge_stage_label != null:
		forge_stage_label.text = "FORGE: %s" % _forge_stage_name()
		forge_stage_label.add_theme_color_override("font_color", _forge_stage_color())
		if forge_stage > 0: forge_stage_label.text += "  %.1fs" % forge_stage_time_left
	if strike_count_label != null: strike_count_label.text = "HAMMER STRIKES  %d" % strike_count
	if score_label != null: score_label.text = "PROJECTED SCORE  %d" % smithing_score()
	if quench_heat_label != null: quench_heat_label.text = "IDEAL QUENCH HEAT  %.0f%%" % (quench_heat_accuracy() * 100.0)
	if accuracy_label != null: accuracy_label.text = "SHAPE ACCURACY  %.1f%%" % (shape_accuracy() * 100.0)
	if heat_label != null: heat_label.text = "HEAT  %s" % _heat_summary()
	if quality_label != null: quality_label.text = quality_rating()

func _heat_summary() -> String:
	var total_heat: float = 0.0
	for temperature: float in section_temperatures: total_heat += temperature
	var average_heat: float = total_heat / float(SECTION_COUNT)
	if average_heat < 0.18: return "COLD"
	if average_heat < ideal_heat_min: return "HEATING"
	if average_heat < ideal_heat_max: return "IDEAL"
	return "TOO HOT"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("211b1b"))
	draw_rect(Rect2(42.0, 38.0, size.x - 84.0, size.y - 76.0), Color("3c2d28"), true)
	_draw_station(forge_rect, "FORGE / FIRE", Color("8d3024"))
	_draw_station(anvil_rect, "ANVIL", Color("48515a"))
	_draw_station(trough_rect, "QUENCH", Color("285a72"))
	_draw_billet()
	# Keep the trace above the billet so the intended sword shape remains clear.
	_draw_target()
	_draw_working_side_indicator()
	_draw_hammer_ready_sparks()
	_draw_strike_feedback()
	_draw_interaction_cursor()
	if billet_station == FORGE_STATION and not finished:
		draw_circle(billet_position, 48.0, Color(1.0, 0.35, 0.08, 0.10))

func _draw_hammer_ready_sparks() -> void:
	if hammer_ready_spark_time_left <= 0.0 or hammer_charge_bar == null: return
	var fade: float = hammer_ready_spark_time_left / 0.35
	var travel: float = 1.0 - fade
	var spark_origin: Vector2 = hammer_charge_bar.position + hammer_charge_bar.size * 0.5
	for spark_index: int in range(12):
		var angle: float = float(spark_index) * TAU / 12.0 + 0.15
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		var spark_start: Vector2 = spark_origin + direction * (12.0 + travel * 20.0)
		var spark_end: Vector2 = spark_origin + direction * (25.0 + travel * 34.0)
		draw_line(spark_start, spark_end, Color(1.0, 0.84, 0.28, fade), 3.0)
		draw_circle(spark_end, 2.5, Color(0.65, 1.0, 0.55, fade))

func _draw_working_side_indicator() -> void:
	if billet_station != ANVIL_STATION or finished: return
	var arrow_tip: Vector2 = Vector2(billet_position.x, billet_position.y - billet_cold_half_width - 12.0)
	var arrow_color: Color = Color("ffd76a")
	draw_line(arrow_tip + Vector2(0.0, -34.0), arrow_tip, arrow_color, 5.0)
	draw_colored_polygon(PackedVector2Array([
		arrow_tip,
		arrow_tip + Vector2(-10.0, -12.0),
		arrow_tip + Vector2(10.0, -12.0),
	]), arrow_color)
	draw_string(ThemeDB.fallback_font, arrow_tip + Vector2(-65.0, -42.0), "WORKING EDGE", HORIZONTAL_ALIGNMENT_CENTER, 130.0, 14, arrow_color)

func _draw_interaction_cursor() -> void:
	if last_mouse_position == Vector2.ZERO or finished: return
	var interaction: String = _interaction_at(last_mouse_position)
	if interaction.is_empty(): return
	var cursor: Vector2 = last_mouse_position + Vector2(18.0, 18.0)
	if interaction == "hammer":
		# Readable top-down hammer: steel head and wooden handle.
		draw_line(cursor + Vector2(4.0, 5.0), cursor + Vector2(22.0, 28.0), Color("9a6742"), 7.0)
		draw_rect(Rect2(cursor + Vector2(-8.0, -3.0), Vector2(28.0, 13.0)), Color("d1d7d9"), true)
		draw_rect(Rect2(cursor + Vector2(-8.0, -3.0), Vector2(28.0, 13.0)), Color("fff0bd"), false, 2.0)
		draw_string(ThemeDB.fallback_font, cursor + Vector2(-15.0, 48.0), "HAMMER", HORIZONTAL_ALIGNMENT_LEFT, 90.0, 13, Color("ffd76a"))
	else:
		# Open tong jaws point back toward the exact pickup position.
		draw_line(cursor + Vector2(8.0, 4.0), cursor + Vector2(26.0, 30.0), Color("bcc6c9"), 5.0)
		draw_line(cursor + Vector2(8.0, 18.0), cursor + Vector2(26.0, 30.0), Color("bcc6c9"), 5.0)
		draw_line(cursor + Vector2(-2.0, -2.0), cursor + Vector2(8.0, 4.0), Color("e3eaeb"), 4.0)
		draw_line(cursor + Vector2(-2.0, 24.0), cursor + Vector2(8.0, 18.0), Color("e3eaeb"), 4.0)
		draw_string(ThemeDB.fallback_font, cursor + Vector2(-10.0, 48.0), "TONGS", HORIZONTAL_ALIGNMENT_LEFT, 80.0, 13, Color("9ed6e8"))

func _draw_strike_feedback() -> void:
	if strike_flash_time_left <= 0.0: return
	var fade: float = strike_flash_time_left / 0.18
	var effect_color: Color = Color("ffd76a") if strike_feedback == 1 else Color("f06a3a")
	if strike_feedback == 1:
		for spark_index: int in range(12):
			var angle: float = float(spark_index) * TAU / 12.0
			var end_point: Vector2 = strike_flash_position + Vector2(cos(angle), sin(angle)) * (24.0 + (1.0 - fade) * 22.0)
			draw_line(strike_flash_position, end_point, Color(effect_color, fade), 3.0)
	elif strike_feedback == 3:
		draw_colored_polygon(PackedVector2Array([strike_flash_position + Vector2(-18.0, 10.0), strike_flash_position + Vector2(0.0, -30.0), strike_flash_position + Vector2(18.0, 10.0)]), Color(effect_color, fade))
	else:
		draw_circle(strike_flash_position, 20.0 + (1.0 - fade) * 8.0, Color(effect_color, fade), false, 3.0)
	# A simple top-down hammer head gives the click a readable physical action.
	draw_rect(Rect2(strike_flash_position + Vector2(-28.0, -48.0), Vector2(56.0, 14.0)), Color("c7b39b", fade), true)
	draw_line(strike_flash_position + Vector2(0.0, -34.0), strike_flash_position + Vector2(0.0, -5.0), Color("8b6244", fade), 7.0)

func _draw_station(rect: Rect2, label_text: String, station_color: Color) -> void:
	draw_rect(rect, Color("17191b"), true)
	draw_rect(rect.grow(-7.0), station_color.darkened(0.45), true)
	draw_rect(rect.grow(-7.0), station_color, false, 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, rect.position.y - 14.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 22, Color("f5d487"))
	if label_text.begins_with("FORGE"):
		var forge_center: Vector2 = rect.get_center() + Vector2(0.0, 12.0)
		var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var stage_visual: float = 0.7 + float(forge_stage) * 0.18
		draw_circle(forge_center, (108.0 + pulse * 8.0) * stage_visual, Color(1.0, 0.22, 0.04, 0.08))
		draw_circle(forge_center, 78.0 + pulse * 6.0, Color(1.0, 0.34, 0.04, 0.14))
		draw_circle(forge_center, 48.0 + pulse * 4.0, Color(1.0, 0.72, 0.12, 0.22))
		for coal_index: int in range(11):
			var coal_angle: float = float(coal_index) * TAU / 11.0
			var coal_position: Vector2 = forge_center + Vector2(cos(coal_angle) * 100.0, sin(coal_angle) * 54.0)
			draw_circle(coal_position, 9.0, Color("4b2020"))
			draw_circle(coal_position, 5.0 + pulse * 2.0, Color("df4724"))
		for flame_index: int in range(7):
			var flame_x: float = rect.position.x + 36.0 + float(flame_index) * 43.0
			var flame_height: float = (54.0 + sin(Time.get_ticks_msec() * 0.006 + flame_index * 1.7) * 14.0) * stage_visual
			var flame_base: float = rect.end.y - 32.0
			draw_colored_polygon(PackedVector2Array([Vector2(flame_x - 16.0, flame_base), Vector2(flame_x, flame_base - flame_height), Vector2(flame_x + 16.0, flame_base)]), Color("e84925"))
			draw_colored_polygon(PackedVector2Array([Vector2(flame_x - 8.0, flame_base), Vector2(flame_x, flame_base - flame_height * 0.62), Vector2(flame_x + 8.0, flame_base)]), Color("ffb52d"))
	elif label_text == "ANVIL":
		draw_rect(Rect2(rect.position + Vector2(45.0, 82.0), Vector2(rect.size.x - 90.0, 25.0)), Color("87929a"), true)
		draw_colored_polygon(PackedVector2Array([Vector2(rect.position.x + 110.0, rect.position.y + 82.0), Vector2(rect.position.x + 145.0, rect.position.y + 34.0), Vector2(rect.position.x + 245.0, rect.position.y + 34.0), Vector2(rect.position.x + 280.0, rect.position.y + 82.0)]), Color("aab2b5"))
	else:
		draw_rect(Rect2(rect.position + Vector2(25.0, 52.0), Vector2(rect.size.x - 50.0, 65.0)), Color("4da5c1"), true)
		for steam_index: int in range(4): draw_circle(rect.position + Vector2(48.0 + steam_index * 32.0, 42.0 - sin(Time.get_ticks_msec() * 0.003 + steam_index) * 8.0), 8.0, Color(0.85, 0.95, 1.0, 0.35))

func _draw_target() -> void:
	if billet_station != ANVIL_STATION or finished: return
	var target_polygon: PackedVector2Array = PackedVector2Array()
	var left: float = billet_position.x - billet_length * 0.5
	var section_spacing: float = billet_length / float(SECTION_COUNT - 1)
	# The source template runs bottom-tip to top-tang. Use exact length endpoints
	# instead of inset strip centers so neither end is visually cropped.
	for section_index: int in range(SECTION_COUNT):
		var x: float = left + float(section_index) * section_spacing
		target_polygon.append(Vector2(x, billet_position.y - target_half_widths[section_index]))
	for section_index: int in range(SECTION_COUNT - 1, -1, -1):
		var x: float = left + float(section_index) * section_spacing
		target_polygon.append(Vector2(x, billet_position.y + target_half_widths[section_index]))
	# draw_polyline does not close its final edge. Repeating the first point is
	# essential here: that final connection is the blade tip itself.
	target_polygon.append(target_polygon[0])
	draw_polyline(target_polygon, Color(0.95, 0.84, 0.46, 0.86), 4.0)

func _draw_billet() -> void:
	var polygon: PackedVector2Array = _billet_polygon()
	if polygon.size() < 3: return
	# Draw trapezoidal section strips with independent upper/lower edges.
	for section_index: int in range(SECTION_COUNT - 1):
		var left_x: float = _section_world_x(section_index)
		var right_x: float = _section_world_x(section_index + 1)
		var section_quad: PackedVector2Array = PackedVector2Array([
			Vector2(left_x, billet_position.y - section_half_widths[section_index]),
			Vector2(right_x, billet_position.y - section_half_widths[section_index + 1]),
			Vector2(right_x, billet_position.y + bottom_half_widths[section_index + 1]),
			Vector2(left_x, billet_position.y + bottom_half_widths[section_index]),
		])
		draw_colored_polygon(section_quad, _temperature_color(section_temperatures[section_index]))
	var edge_color: Color = Color("f5b95e") if flipped else Color("d8e0e0")
	draw_polyline(polygon, Color(edge_color, 0.92), 3.0)

func _close() -> void:
	closed.emit()
