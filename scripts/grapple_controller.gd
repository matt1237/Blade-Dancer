class_name GrappleController extends Node2D

var hd_hook_texture: Texture2D = null
var spear_tip_texture: Texture2D = null

## Lightweight live tether. Rope tension always adds acceleration; it never
## replaces velocity or removes tangential momentum.
enum TargetType { NONE, TERRAIN, ENEMY, CHAKRAM, GLYPH }
enum YoyoState { NONE, EXTENDING, ORBITING, REELING }
enum YoyoWrapPhase { FREE, WRAP_ACQUIRED, WRAPPED, RETURNING }
enum YoyoCoilPhase { NONE, TRACKING, COMMITTED, UNWINDING, DAMAGE_ARMED, HOLDING }

const MIN_ROPE_LENGTH = 42.0
const TERRAIN_RELEASE_SLIDE_DURATION = 0.25
const GRAPPLE_DASH_MOMENTUM_DURATION = 0.34
const TARGET_MASK = 2 | 16
const ROPE_SAMPLE_COUNT = 22
const HOOK_TIP_RADIUS: float = 13.0
## Visual-only scale for the flying/latched spearhead. Keep gameplay query size unchanged.
const HOOK_TIP_VISUAL_SCALE: float = 0.35
const TAUT_CLEARANCE: float = 4.0
const ENEMY_WRAP_RADIUS: float = 28.0
const ENEMY_WRAP_CLEARANCE: float = 3.0
const WRAPPED_LOCAL_SEGMENT_MIN: float = 1.0
## Full boundary wrapping is retained for possible future work but disabled by default.
## The direct Chakram yo-yo path is the normal gameplay path; the static pivot is optional.
## One canonical compatibility list for persisted Grapple tuning. The feel tuner
## intentionally exposes only the subset with clear, distinct perceptual effects.
const TUNING_DEFAULTS: Dictionary = {
	"max_tether_length": 640.0, "hook_travel_speed": 1250.0, "reel_speed": 145.0,
	"slack_take_up_speed": 145.0, "initial_slack": 0.0, "tension_ramp_distance": 8.0,
	"hand_velocity_smoothing": 16.0, "hand_velocity_cap": 1800.0,
	"body_movement_transfer": 0.15, "directional_transfer_ratio": 0.9, "radial_yank_ratio": 1.0,
	"player_hand_orbit_strength": 4.0, "player_radial_yank_strength": 2.5,
	"taut_catch_impulse_seconds": 0.12, "yoyo_catch_radial_retention": 0.0,
	"enemy_pull_strength": 1150.0,
	"chakram_tether_strength": 800.0, "wall_pull_strength": 2800.0,
	"grapple_dash_traction": 0.20, "light_yank_strength": 3.5,
	"light_slide_fraction": 0.125, "medium_reel_multiplier": 1.0,
	"medium_yank_strength": 1.25, "medium_slide_fraction": 0.06,
	"medium_player_pull_strength": 1500.0, "heavy_player_pull_strength": 2200.0,
	"chakram_yank_strength": 7.0, "yoyo_enabled": true,
	"yoyo_soft_tension_zone": 72.0, "yoyo_radial_damping": 18.0,
	"yoyo_orbit_drag": 0.35, "yoyo_orbit_slack_recovery_speed": 180.0,
	"yoyo_min_orbit_time": 1.25, "yoyo_recall_speed_threshold": 120.0,
	"yoyo_static_pivot_enabled": false,
	"yoyo_boundary_wrap_enabled": false,
	"yoyo_wrap_commit_turns": 0.45, "yoyo_coil_revolutions": 1.5,
	"yoyo_coil_tangential_speed": 760.0, "yoyo_coil_radial_speed": 220.0,
	"yoyo_coil_speed_gain": 0.35, "yoyo_coil_hold_duration": 1.0, "yoyo_unwind_speed": 420.0
}
const TUNING_KEYS: Array[String] = [
	"max_tether_length", "hook_travel_speed", "reel_speed", "slack_take_up_speed",
	"initial_slack", "tension_ramp_distance", "hand_velocity_smoothing", "hand_velocity_cap",
	"body_movement_transfer", "directional_transfer_ratio", "radial_yank_ratio", "player_hand_orbit_strength",
	"player_radial_yank_strength", "taut_catch_impulse_seconds", "yoyo_catch_radial_retention", "enemy_pull_strength",
	"chakram_tether_strength", "wall_pull_strength", "grapple_dash_traction", "light_yank_strength",
	"light_slide_fraction", "medium_reel_multiplier", "medium_yank_strength", "medium_slide_fraction",
	"medium_player_pull_strength", "heavy_player_pull_strength", "chakram_yank_strength",
	"yoyo_enabled", "yoyo_soft_tension_zone", "yoyo_radial_damping", "yoyo_orbit_drag",
	"yoyo_orbit_slack_recovery_speed", "yoyo_min_orbit_time", "yoyo_recall_speed_threshold", "yoyo_static_pivot_enabled",
	"yoyo_boundary_wrap_enabled", "yoyo_wrap_commit_turns", "yoyo_coil_revolutions",
	"yoyo_coil_tangential_speed", "yoyo_coil_radial_speed", "yoyo_coil_speed_gain",
	"yoyo_coil_hold_duration", "yoyo_unwind_speed"
]

static func default_tuning_state() -> Dictionary:
	return TUNING_DEFAULTS.duplicate(true)

@export_category("Grapple V1")
@export var max_tether_length: float = 640.0
var mastery_range_multiplier: float = 1.0
@export var hook_travel_speed: float = 1250.0
@export var reel_speed: float = 145.0
## Speed used only to close the configured attachment slack before first tension.
@export var slack_take_up_speed: float = 145.0
## Extra line granted at attachment. Zero produces an immediate, measured catch.
@export var initial_slack: float = 0.0
@export var tension_ramp_distance: float = 8.0
@export_category("Lasso Hand Physics")
## Smoothing removes one-frame animation jitter without erasing deliberate hand sweeps.
@export var hand_velocity_smoothing: float = 16.0
@export var hand_velocity_cap: float = 1800.0
## Fraction of player body velocity retained in the hand signal. Relative hand
## animation remains fully authored; this only controls walking/dash transfer.
@export_range(0.0, 1.0, 0.05) var body_movement_transfer: float = 0.15
## Fraction of the hand's movement direction transmitted to dynamic targets.
@export_range(0.0, 1.0, 0.05) var directional_transfer_ratio: float = 0.9
## Multiplier for outward-only radial hand yanks while the rope is taut.
@export var radial_yank_ratio: float = 1.0
## Tangential hand steering applied to the player while grappling an anchor.
@export var player_hand_orbit_strength: float = 4.0
## Outward hand motion briefly accelerates the player toward their anchor.
@export var player_radial_yank_strength: float = 2.5
## Duration of the one-shot hand impulse when the Chakram line first becomes taut.
@export var taut_catch_impulse_seconds: float = 0.12
## Fraction of radial velocity retained when Extending becomes Orbiting. Zero
## settles immediately into tangent; one preserves all inward/outward drift.
@export_range(0.0, 1.0, 0.05) var yoyo_catch_radial_retention: float = 0.0
@export_category("Original Reel Forces")
## Restored committed reel tuning. Hand steering/yank settings never scale these.
@export var enemy_pull_strength: float = 1150.0
@export var chakram_tether_strength: float = 800.0
@export var wall_pull_strength: float = 2800.0
@export_range(0.0, 1.0, 0.05) var grapple_dash_traction: float = 0.20

@export_category("Target Weight Hand Response")
@export var light_yank_strength: float = 3.5
@export_range(0.0, 0.25, 0.01) var light_slide_fraction: float = 0.125
@export var light_target_speed_cap: float = 820.0
## Medium preserves weight behavior without replacing the original reel control.
@export_range(0.0, 1.0, 0.05) var medium_reel_multiplier: float = 1.0
@export var medium_yank_strength: float = 1.25
@export_range(0.0, 0.15, 0.01) var medium_slide_fraction: float = 0.06
@export var medium_target_speed_cap: float = 520.0
@export var medium_player_pull_strength: float = 1500.0
## Heavy/boss: target stays stable; player moves to target.
@export var heavy_player_pull_strength: float = 2200.0
## Chakram receives the original reel plus the strongest separate hand response.
## Its own sword-hit ceiling clamps the resulting total velocity.
@export var chakram_yank_strength: float = 7.0

@export_category("Grapple Yo-yo")
@export var yoyo_enabled: bool = true
## Distance before full extension where outward radial speed starts easing off.
@export var yoyo_soft_tension_zone: float = 72.0
@export var yoyo_radial_damping: float = 18.0
## Slow energy burn only while at full extension; tangent is otherwise preserved.
@export var yoyo_orbit_drag: float = 0.35
## Removes only unused line while orbiting. It stops at the current live path,
## so recovery cannot pull the Chakram inward or behave like automatic recall.
@export var yoyo_orbit_slack_recovery_speed: float = 180.0
## Minimum authored hang window before a low-energy orbit may begin reeling.
@export var yoyo_min_orbit_time: float = 1.25
## Tangential speed above this value sustains the orbit after the hang window.
@export var yoyo_recall_speed_threshold: float = 120.0
## Enables the retained one-point static obstruction pivot.
## Disabled by default while the direct Chakram yo-yo is the active mechanic.
@export var yoyo_static_pivot_enabled: bool = false
## Enables the retained experimental enemy and collision-boundary wrap solver.
## Disabled by default; direct Chakram yo-yo remains the normal path.
@export var yoyo_boundary_wrap_enabled: bool = false
## Player-authored winding required before the rest of the coil commits.
@export_range(0.1, 1.0, 0.05) var yoyo_wrap_commit_turns: float = 0.45
## Full target-relative turns completed after player-authored commitment.
@export_range(1.0, 2.0, 0.1) var yoyo_coil_revolutions: float = 1.5
## Tangential speed is authoritative during commitment so the spiral cannot stall.
@export var yoyo_coil_tangential_speed: float = 760.0
## Independent inward cinch speed; tangent remains strong after capture radius is reached.
@export var yoyo_coil_radial_speed: float = 220.0
## Extra tangential speed gained as the spiral tightens: 0.35 ends 35% faster.
@export_range(0.0, 1.0, 0.05) var yoyo_coil_speed_gain: float = 0.35
## Time the completed coil treats its wrapped enemy as the grapple target.
@export var yoyo_coil_hold_duration: float = 1.0
## Linear speed used to reverse the authored coil after an obstruction bounce.
@export var yoyo_unwind_speed: float = 420.0

var player: Player = null
var active: bool = false
var target_type: TargetType = TargetType.NONE
var target_node: Node2D = null
var anchor_position: Vector2 = Vector2.ZERO
var rope_length: float = 0.0
var input_was_down: bool = false
var grapple_dash_momentum_left: float = 0.0
var terrain_release_slide_left: float = 0.0
var tension_ratio: float = 0.0
var firing: bool = false
var hook_position: Vector2 = Vector2.ZERO
var hook_direction: Vector2 = Vector2.RIGHT
var visual_time: float = 0.0
var shot_target_type: TargetType = TargetType.NONE
var shot_target_node: Node2D = null
var shot_target_position: Vector2 = Vector2.ZERO
var rope_taut: bool = false
var previous_hand_position: Vector2 = Vector2.ZERO
var smoothed_hand_velocity: Vector2 = Vector2.ZERO
var yoyo_state: YoyoState = YoyoState.NONE
var yoyo_catch_initialized: bool = false
var yoyo_extend_time: float = 0.0
var yoyo_orbit_time: float = 0.0
var yoyo_wrap_active: bool = false
var yoyo_wrap_phase: YoyoWrapPhase = YoyoWrapPhase.FREE
var yoyo_wrap_position: Vector2 = Vector2.ZERO
var yoyo_wrap_object: Node2D = null
var yoyo_wrap_bounds: Rect2 = Rect2()
var yoyo_rect_entry_parameter: float = 0.0
var yoyo_rect_previous_exit_parameter: float = 0.0
var yoyo_rect_arc_length: float = 0.0
var yoyo_rect_wrap_sign: float = 1.0
var yoyo_rect_entry_point: Vector2 = Vector2.ZERO
var yoyo_rect_exit_point: Vector2 = Vector2.ZERO
var yoyo_enemy_entry_point: Vector2 = Vector2.ZERO
var yoyo_enemy_entry_angle: float = 0.0
var yoyo_enemy_exit_point: Vector2 = Vector2.ZERO
var yoyo_enemy_wrap_radius: float = 0.0
var yoyo_enemy_wrap_sign: float = 0.0
## Unwrapped directed contact angle. May exceed TAU after complete coils.
var yoyo_enemy_arc_angle: float = 0.0
var yoyo_enemy_previous_entry_angle: float = 0.0
var yoyo_enemy_previous_exit_angle: float = 0.0
var yoyo_enemy_arc_initialized: bool = false
var yoyo_enemy_minimum_arc: float = 0.0
var yoyo_enemy_winding_delta: float = 0.0
var yoyo_coil_hit_consumed: bool = false
var yoyo_coil_phase: YoyoCoilPhase = YoyoCoilPhase.NONE
var yoyo_coil_progress: float = 0.0
var yoyo_coil_path_length: float = 0.0
var yoyo_coil_start_radius: float = 0.0
var yoyo_coil_start_angle: float = 0.0
var yoyo_coil_angle_travel: float = 0.0
var yoyo_coil_current_radius: float = 0.0
var yoyo_coil_hold_left: float = 0.0
var yoyo_wrapped_hold_rope_length: float = 0.0
var yoyo_coil_committed_enemy_id: int = -1
var yoyo_enemy_last_acceleration: Vector2 = Vector2.ZERO
var yoyo_debug_sample_left: float = 0.0
var yoyo_reel_shortfall: float = 0.0
var yoyo_reacquire_blocked_object: Node2D = null
var yoyo_wrap_clear_ticks: int = 0
var yoyo_wrap_uses_boundary: bool = true

func setup(owner_player: Player) -> void:
	player = owner_player
	hd_hook_texture = load("res://assets/generated/hd_resonance_claw_hook_frame_0.png") as Texture2D
	spear_tip_texture = load("res://assets/generated/grapple_spear_tip_pixel_frame_0.png") as Texture2D
	z_as_relative = false
	z_index = 4
	set_process(false)
	previous_hand_position = player.get_grapple_hand_position()
	smoothed_hand_velocity = Vector2.ZERO
	queue_redraw()

static func tension_acceleration(moving_position: Vector2, anchor: Vector2, current_rope_length: float, strength: float, ramp_dist: float = 8.0) -> Vector2:
	var distance: float = moving_position.distance_to(anchor)
	var stretch: float = distance - current_rope_length
	if stretch <= 0.0 or distance < 0.001:
		return Vector2.ZERO
	var engagement: float = 1.0 if ramp_dist <= 0.001 else clampf(stretch / ramp_dist, 0.0, 1.0)
	return moving_position.direction_to(anchor) * maxf(0.0, strength) * engagement

static func smoothed_velocity(previous_velocity: Vector2, raw_velocity: Vector2, smoothing: float, delta: float, speed_cap: float) -> Vector2:
	var capped_raw: Vector2 = raw_velocity.limit_length(maxf(0.0, speed_cap))
	var blend: float = 1.0 - exp(-maxf(0.0, smoothing) * maxf(0.0, delta))
	return previous_velocity.lerp(capped_raw, clampf(blend, 0.0, 1.0))

static func authored_hand_velocity(world_hand_velocity: Vector2, body_velocity: Vector2, movement_transfer: float) -> Vector2:
	return world_hand_velocity - body_velocity * (1.0 - clampf(movement_transfer, 0.0, 1.0))

static func target_hand_acceleration(target_position: Vector2, hand_position: Vector2, hand_velocity: Vector2, tangent_strength: float, radial_strength: float, transfer_ratio: float, is_taut: bool) -> Vector2:
	if not is_taut:
		return Vector2.ZERO
	var toward_hand: Vector2 = target_position.direction_to(hand_position)
	if toward_hand.length_squared() < 0.001:
		return Vector2.ZERO
	var radial_speed: float = hand_velocity.dot(toward_hand)
	var outward_speed: float = maxf(0.0, radial_speed)
	var tangent_velocity: Vector2 = hand_velocity - toward_hand * radial_speed
	var transfer: float = clampf(transfer_ratio, 0.0, 1.0)
	return (tangent_velocity * maxf(0.0, tangent_strength) + toward_hand * outward_speed * maxf(0.0, radial_strength)) * transfer

static func player_hand_acceleration(hand_position: Vector2, anchor: Vector2, articulated_hand_velocity: Vector2, tangent_strength: float, radial_strength: float, is_taut: bool) -> Vector2:
	if not is_taut:
		return Vector2.ZERO
	var toward_anchor: Vector2 = hand_position.direction_to(anchor)
	if toward_anchor.length_squared() < 0.001:
		return Vector2.ZERO
	var radial_speed: float = articulated_hand_velocity.dot(toward_anchor)
	var outward_speed: float = maxf(0.0, -radial_speed)
	var tangent_velocity: Vector2 = articulated_hand_velocity - toward_anchor * radial_speed
	# Tangential movement steers orbit; only motion away from the anchor tightens
	# the line and creates extra radial pull. Motion inward never pushes.
	return tangent_velocity * maxf(0.0, tangent_strength) + toward_anchor * outward_speed * maxf(0.0, radial_strength)

static func reeled_length(current_length: float, speed: float, delta: float) -> float:
	return maxf(MIN_ROPE_LENGTH, current_length - maxf(0.0, speed) * maxf(0.0, delta))

static func recovered_orbit_length(current_length: float, live_path_length: float, speed: float, delta: float) -> float:
	var clean_current: float = maxf(MIN_ROPE_LENGTH, current_length)
	var clean_path: float = maxf(MIN_ROPE_LENGTH, live_path_length)
	if clean_current <= clean_path:
		# Recovery is unilateral: a stretched line is handled by tension/constraint,
		# never by silently paying rope outward to meet the moving endpoint.
		return clean_current
	return maxf(clean_path, clean_current - maxf(0.0, speed) * maxf(0.0, delta))

static func yoyo_should_recall(orbit_time: float, minimum_orbit_time: float, tangential_speed: float, recall_speed_threshold: float) -> bool:
	return orbit_time >= maxf(0.0, minimum_orbit_time) and tangential_speed <= maxf(0.0, recall_speed_threshold)

static func aimed_endpoint(origin: Vector2, aim_point: Vector2, maximum_length: float) -> Vector2:
	## Aim position supplies direction only. Every valid shot travels the full
	## configured range unless a wall or dynamic target intercepts it first.
	var offset: Vector2 = aim_point - origin
	if offset.length_squared() < 0.001:
		return origin
	return origin + offset.normalized() * maxf(0.0, maximum_length)

static func rope_wave_amplitude(slack: float, taut_ratio: float, in_flight: bool) -> float:
	if in_flight:
		return clampf(8.0 + slack * 0.04, 8.0, 22.0)
	return clampf(slack * 0.55, 0.0, 20.0) * (1.0 - clampf(taut_ratio, 0.0, 1.0))

static func yoyo_path_length(hand: Vector2, chakram_position: Vector2, wrap_active: bool, wrap_position: Vector2) -> float:
	if not wrap_active:
		return hand.distance_to(chakram_position)
	return hand.distance_to(wrap_position) + wrap_position.distance_to(chakram_position)

static func yoyo_local_rope_length(total_rope_length: float, hand: Vector2, wrap_active: bool, wrap_position: Vector2) -> float:
	if not wrap_active:
		return maxf(MIN_ROPE_LENGTH, total_rope_length)
	return maxf(MIN_ROPE_LENGTH, total_rope_length - hand.distance_to(wrap_position))

func _yoyo_live_path_length(hand: Vector2, chakram_position: Vector2) -> float:
	if yoyo_wrap_active and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
		return hand.distance_to(yoyo_enemy_entry_point) + yoyo_enemy_arc_angle * yoyo_enemy_wrap_radius + yoyo_enemy_exit_point.distance_to(chakram_position)
	if yoyo_wrap_active and not yoyo_wrap_bounds.size.is_zero_approx():
		return hand.distance_to(yoyo_rect_entry_point) + yoyo_rect_arc_length + yoyo_rect_exit_point.distance_to(chakram_position)
	return yoyo_path_length(hand, chakram_position, yoyo_wrap_active, yoyo_wrap_position)

func _yoyo_consumed_prefix(hand: Vector2) -> float:
	if yoyo_wrap_active and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
		return hand.distance_to(yoyo_enemy_entry_point) + yoyo_enemy_arc_angle * yoyo_enemy_wrap_radius
	if yoyo_wrap_active and not yoyo_wrap_bounds.size.is_zero_approx():
		return hand.distance_to(yoyo_rect_entry_point) + yoyo_rect_arc_length
	return hand.distance_to(yoyo_wrap_position) if yoyo_wrap_active else 0.0

func _yoyo_live_local_length(total_rope_length: float, hand: Vector2) -> float:
	if yoyo_wrap_active and (is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy or not yoyo_wrap_bounds.size.is_zero_approx()):
		var consumed: float = _yoyo_consumed_prefix(hand)
		return maxf(WRAPPED_LOCAL_SEGMENT_MIN, total_rope_length - consumed)
	return yoyo_local_rope_length(total_rope_length, hand, yoyo_wrap_active, yoyo_wrap_position)

static func yoyo_rect_perimeter_length(rect: Rect2) -> float:
	return maxf(0.001, 2.0 * (rect.size.x + rect.size.y))

static func yoyo_rect_perimeter_point(rect: Rect2, distance: float) -> Vector2:
	var width: float = maxf(0.001, rect.size.x)
	var height: float = maxf(0.001, rect.size.y)
	var perimeter: float = yoyo_rect_perimeter_length(rect)
	var path: float = fposmod(distance, perimeter)
	if path <= width:
		return Vector2(rect.position.x + path, rect.position.y)
	path -= width
	if path <= height:
		return Vector2(rect.end.x, rect.position.y + path)
	path -= height
	if path <= width:
		return Vector2(rect.end.x - path, rect.end.y)
	path -= width
	return Vector2(rect.position.x, rect.end.y - minf(path, height))

static func yoyo_rect_surface_point(rect: Rect2, point: Vector2) -> Vector2:
	var clamped: Vector2 = Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
	var candidates: Array[Vector2] = [
		Vector2(clamped.x, rect.position.y), Vector2(rect.end.x, clamped.y),
		Vector2(clamped.x, rect.end.y), Vector2(rect.position.x, clamped.y)
	]
	var selected: Vector2 = candidates[0]
	var best_distance: float = selected.distance_squared_to(point)
	for candidate: Vector2 in candidates:
		var distance: float = candidate.distance_squared_to(point)
		if distance < best_distance:
			best_distance = distance
			selected = candidate
	return selected

static func yoyo_rect_perimeter_parameter(rect: Rect2, point: Vector2) -> float:
	var surface: Vector2 = yoyo_rect_surface_point(rect, point)
	var width: float = maxf(0.001, rect.size.x)
	var height: float = maxf(0.001, rect.size.y)
	var epsilon: float = 0.01
	if absf(surface.y - rect.position.y) <= epsilon:
		return clampf(surface.x - rect.position.x, 0.0, width)
	if absf(surface.x - rect.end.x) <= epsilon:
		return width + clampf(surface.y - rect.position.y, 0.0, height)
	if absf(surface.y - rect.end.y) <= epsilon:
		return width + height + clampf(rect.end.x - surface.x, 0.0, width)
	return width + height + width + clampf(rect.end.y - surface.y, 0.0, height)

static func yoyo_rect_directed_distance(from_parameter: float, to_parameter: float, winding_sign: float, perimeter: float) -> float:
	if winding_sign >= 0.0:
		return fposmod(to_parameter - from_parameter, perimeter)
	return fposmod(from_parameter - to_parameter, perimeter)

static func yoyo_rect_shortest_wrap_sign(rect: Rect2, entry_point: Vector2, exit_point: Vector2) -> float:
	var perimeter: float = yoyo_rect_perimeter_length(rect)
	var entry_parameter: float = yoyo_rect_perimeter_parameter(rect, entry_point)
	var exit_parameter: float = yoyo_rect_perimeter_parameter(rect, exit_point)
	var positive: float = yoyo_rect_directed_distance(entry_parameter, exit_parameter, 1.0, perimeter)
	var negative: float = yoyo_rect_directed_distance(entry_parameter, exit_parameter, -1.0, perimeter)
	return 1.0 if positive <= negative else -1.0

static func yoyo_wrap_corner(rect: Rect2, segment_hit: Vector2) -> Vector2:
	# Legacy single-pivot mode must at least use a corner, not an interior
	# point of a face. Full boundary mode uses both supporting corners instead.
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var selected: Vector2 = corners[0]
	for corner: Vector2 in corners:
		if corner.distance_squared_to(segment_hit) < selected.distance_squared_to(segment_hit):
			selected = corner
	return selected

static func yoyo_circle_tangent(center: Vector2, endpoint: Vector2, radius: float, side: float) -> Vector2:
	var offset: Vector2 = endpoint - center
	var distance: float = offset.length()
	var safe_radius: float = maxf(1.0, radius)
	if distance <= safe_radius + 0.001:
		return center + offset.normalized() * safe_radius if distance > 0.001 else center + Vector2.RIGHT * safe_radius
	var tangent_offset: float = acos(clampf(safe_radius / distance, -1.0, 1.0))
	return center + Vector2.RIGHT.rotated(offset.angle() + signf(side) * tangent_offset) * safe_radius

static func yoyo_directed_arc(entry_angle: float, exit_angle: float, winding_sign: float) -> float:
	if winding_sign >= 0.0:
		return fposmod(exit_angle - entry_angle, TAU)
	return fposmod(entry_angle - exit_angle, TAU)

static func yoyo_shortest_wrap_sign(center: Vector2, hand: Vector2, chakram_position: Vector2, radius: float) -> float:
	var positive_entry: Vector2 = yoyo_circle_tangent(center, hand, radius, 1.0)
	var positive_exit: Vector2 = yoyo_circle_tangent(center, chakram_position, radius, -1.0)
	var positive_arc: float = yoyo_directed_arc((positive_entry - center).angle(), (positive_exit - center).angle(), 1.0)
	var negative_entry: Vector2 = yoyo_circle_tangent(center, hand, radius, -1.0)
	var negative_exit: Vector2 = yoyo_circle_tangent(center, chakram_position, radius, 1.0)
	var negative_arc: float = yoyo_directed_arc((negative_entry - center).angle(), (negative_exit - center).angle(), -1.0)
	return 1.0 if positive_arc <= negative_arc else -1.0


static func yoyo_accumulated_arc(previous_arc: float, _minimum_arc: float, previous_entry_angle: float, entry_angle: float, previous_exit_angle: float, exit_angle: float, winding_sign: float) -> float:
	var entry_delta: float = wrapf(entry_angle - previous_entry_angle, -PI, PI)
	var exit_delta: float = wrapf(exit_angle - previous_exit_angle, -PI, PI)
	var directed_delta: float = (exit_delta - entry_delta) * signf(winding_sign)
	# Contact history is continuous across zero; a modulo minimum here would
	# invent a complete turn when the last contact unwinds across the seam.
	return maxf(0.0, previous_arc + directed_delta)

static func coil_progress(current: float, speed: float, delta: float, path_length: float, unwinding: bool) -> float:
	var step: float = maxf(0.0, speed) * maxf(0.0, delta) / maxf(1.0, path_length)
	return clampf(current - step if unwinding else current + step, 0.0, 1.0)

static func coil_position(center: Vector2, start_radius: float, capture_radius: float, start_angle: float, winding_sign: float, progress: float, revolutions: float = 1.0) -> Vector2:
	var ratio: float = clampf(progress, 0.0, 1.0)
	var radius: float = lerpf(maxf(capture_radius, start_radius), capture_radius, ratio)
	var angle: float = start_angle + signf(winding_sign) * TAU * maxf(1.0, revolutions) * ratio
	return center + Vector2.from_angle(angle) * radius

static func yoyo_enemy_wrap_acceleration(hand_direction: Vector2, chakram_direction: Vector2, path_stretch: float, ramp_distance: float, enemy_strength: float, weight_scale: float) -> Vector2:
	var engagement: float = clampf(maxf(0.0, path_stretch) / maxf(0.001, ramp_distance), 0.0, 1.0)
	return (hand_direction.normalized() + chakram_direction.normalized()) * 0.5 * maxf(0.0, enemy_strength) * maxf(0.0, weight_scale) * engagement

static func yoyo_enemy_segment_hit(start: Vector2, end: Vector2, center: Vector2, radius: float) -> Vector2:
	var segment: Vector2 = end - start
	var segment_length_squared: float = segment.length_squared()
	var along: float = 0.0
	if segment_length_squared > 0.001:
		along = clampf((center - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest: Vector2 = start + segment * along
	var safe_radius: float = maxf(1.0, radius)
	if closest.distance_to(center) > safe_radius:
		return Vector2.INF
	if start.distance_to(center) <= safe_radius or end.distance_to(center) <= safe_radius:
		return Vector2.INF
	return closest

static func enemy_collision_circle(enemy: Enemy) -> Dictionary:
	if enemy == null:
		return {"supported": false, "center": Vector2.ZERO, "radius": 0.0}
	var shape_node: CollisionShape2D = enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null or shape_node.disabled or not shape_node.shape is CircleShape2D:
		# Do not invent a radius for an unsupported enemy collider. A wrap that
		# cannot name its real boundary must refuse acquisition.
		return {"supported": false, "center": enemy.global_position, "radius": 0.0}
	var shape_scale: Vector2 = shape_node.global_transform.get_scale().abs()
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	var radius: float = circle.radius * maxf(shape_scale.x, shape_scale.y)
	return {"supported": radius > 0.0, "center": shape_node.global_position, "radius": maxf(1.0, radius)}

func _enemy_wrap_radius(enemy: Enemy) -> float:
	return enemy_collision_circle(enemy).get("radius", 0.0) as float

func _enemy_wrap_supported(enemy: Enemy) -> bool:
	return bool(enemy_collision_circle(enemy).get("supported", false))

func _enemy_wrap_center(enemy: Enemy) -> Vector2:
	return enemy_collision_circle(enemy).get("center", enemy.global_position) as Vector2

func _yoyo_enemy_obstruction_hit(start: Vector2, end: Vector2, excluded: Node2D = null) -> Dictionary:
	if player == null or not player.is_inside_tree():
		return {}
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy == excluded or not is_instance_valid(enemy) or enemy.health <= 0.0 or not _enemy_wrap_supported(enemy):
			continue
		var center: Vector2 = _enemy_wrap_center(enemy)
		var hit: Vector2 = yoyo_enemy_segment_hit(start, end, center, _enemy_wrap_radius(enemy))
		if hit == Vector2.INF:
			continue
		var outward: Vector2 = center.direction_to(hit)
		if outward == Vector2.ZERO:
			outward = start.direction_to(end)
		var surface: Vector2 = center + outward * _enemy_wrap_radius(enemy)
		return {"position": surface, "object": enemy}
	return {}

func _arena_object_from_collider(collider: Object) -> ArenaObject:
	var node: Node = collider as Node
	while node != null:
		if node is ArenaObject:
			return node as ArenaObject
		node = node.get_parent()
	return null

func _terrain_capsule_hit(start: Vector2, end: Vector2, excluded: Node2D = null) -> Dictionary:
	if player == null or not player.is_inside_tree() or start.is_equal_approx(end):
		return {}
	var excluded_rids: Array[RID] = []
	if excluded is ArenaObject:
		var excluded_object: ArenaObject = excluded as ArenaObject
		if excluded_object.body != null and is_instance_valid(excluded_object.body):
			excluded_rids.append(excluded_object.body.get_rid())
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(start, end, 4, excluded_rids)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var normal: Vector2 = hit.get("normal", Vector2.ZERO) as Vector2
	var contact: Vector2 = hit.get("position", Vector2.ZERO) as Vector2
	# A tiny outward clearance keeps the rendered/pivot line on the real rounded
	# surface instead of numerically falling back inside the collider.
	return {"position": contact + normal * 0.5, "normal": normal, "object": _arena_object_from_collider(hit.get("collider"))}

func _yoyo_obstruction_hit(start: Vector2, end: Vector2, excluded: Node2D = null) -> Dictionary:
	var terrain_hit: Dictionary = _terrain_capsule_hit(start, end, excluded)
	if not terrain_hit.is_empty():
		return terrain_hit
	var enemy_hit: Dictionary = _yoyo_enemy_obstruction_hit(start, end, excluded)
	if not enemy_hit.is_empty():
		return enemy_hit
	return {}

func _yoyo_static_obstruction_hit(start: Vector2, end: Vector2) -> Dictionary:
	return _terrain_capsule_hit(start, end)

func _clear_yoyo_wrap(reacquire_blocked_object: Node2D = null) -> void:
	yoyo_reacquire_blocked_object = reacquire_blocked_object
	yoyo_wrap_active = false
	yoyo_wrap_phase = YoyoWrapPhase.FREE
	yoyo_wrap_position = Vector2.ZERO
	yoyo_wrap_object = null
	yoyo_wrap_bounds = Rect2()
	yoyo_rect_entry_parameter = 0.0
	yoyo_rect_previous_exit_parameter = 0.0
	yoyo_rect_arc_length = 0.0
	yoyo_rect_wrap_sign = 1.0
	yoyo_rect_entry_point = Vector2.ZERO
	yoyo_rect_exit_point = Vector2.ZERO
	yoyo_enemy_entry_point = Vector2.ZERO
	yoyo_enemy_entry_angle = 0.0
	yoyo_enemy_exit_point = Vector2.ZERO
	yoyo_enemy_wrap_radius = 0.0
	yoyo_enemy_wrap_sign = 0.0
	yoyo_enemy_arc_angle = 0.0
	yoyo_enemy_previous_entry_angle = 0.0
	yoyo_enemy_previous_exit_angle = 0.0
	yoyo_enemy_arc_initialized = false
	yoyo_enemy_minimum_arc = 0.0
	yoyo_enemy_winding_delta = 0.0
	yoyo_coil_hit_consumed = false
	yoyo_coil_phase = YoyoCoilPhase.NONE
	yoyo_coil_progress = 0.0
	yoyo_coil_path_length = 0.0
	yoyo_coil_start_radius = 0.0
	yoyo_coil_start_angle = 0.0
	yoyo_coil_angle_travel = 0.0
	yoyo_coil_current_radius = 0.0
	yoyo_coil_hold_left = 0.0
	yoyo_wrapped_hold_rope_length = 0.0
	yoyo_coil_committed_enemy_id = -1
	yoyo_enemy_last_acceleration = Vector2.ZERO
	yoyo_debug_sample_left = 0.0
	yoyo_reel_shortfall = 0.0
	yoyo_wrap_clear_ticks = 0

func _update_rect_wrap(hand_position: Vector2, chakram_position: Vector2, _delta: float) -> void:
	var bounds: Rect2 = yoyo_wrap_bounds
	if is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is ArenaObject:
		bounds = (yoyo_wrap_object as ArenaObject).world_collision_rect()
		yoyo_wrap_bounds = bounds
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_clear_yoyo_wrap()
		return
	var perimeter: float = yoyo_rect_perimeter_length(bounds)
	yoyo_rect_entry_point = yoyo_rect_tangent(bounds, hand_position, yoyo_rect_wrap_sign)
	yoyo_rect_exit_point = yoyo_rect_tangent(bounds, chakram_position, -yoyo_rect_wrap_sign)
	var entry: float = yoyo_rect_perimeter_parameter(bounds, yoyo_rect_entry_point)
	var exit: float = yoyo_rect_perimeter_parameter(bounds, yoyo_rect_exit_point)
	var entry_delta: float = wrapf(entry - yoyo_rect_entry_parameter, -perimeter * 0.5, perimeter * 0.5)
	var exit_delta: float = wrapf(exit - yoyo_rect_previous_exit_parameter, -perimeter * 0.5, perimeter * 0.5)
	yoyo_rect_arc_length = maxf(0.0, yoyo_rect_arc_length + (exit_delta - entry_delta) * yoyo_rect_wrap_sign)
	yoyo_rect_entry_parameter = entry
	yoyo_rect_previous_exit_parameter = exit
	yoyo_wrap_position = yoyo_rect_exit_point
	if yoyo_rect_arc_length <= 0.03 and not yoyo_segment_crosses_rect(hand_position, chakram_position, bounds.grow(2.0)):
		_clear_yoyo_wrap(yoyo_wrap_object)

func _update_circle_contacts(hand: Vector2, endpoint: Vector2, center: Vector2, radius: float, enemy: Enemy) -> void:
	yoyo_enemy_entry_point = yoyo_circle_tangent(center, hand, radius, yoyo_enemy_wrap_sign)
	yoyo_enemy_exit_point = yoyo_circle_tangent(center, endpoint, radius, -yoyo_enemy_wrap_sign)
	var entry: float = (yoyo_enemy_entry_point - center).angle()
	var exit: float = (yoyo_enemy_exit_point - center).angle()
	var previous: float = yoyo_enemy_arc_angle
	yoyo_enemy_minimum_arc = yoyo_directed_arc(entry, exit, yoyo_enemy_wrap_sign)
	if not yoyo_enemy_arc_initialized:
		yoyo_enemy_arc_angle = yoyo_enemy_minimum_arc
		yoyo_enemy_arc_initialized = true
	else:
		yoyo_enemy_arc_angle = yoyo_accumulated_arc(previous, 0.0, yoyo_enemy_previous_entry_angle, entry, yoyo_enemy_previous_exit_angle, exit, yoyo_enemy_wrap_sign)
	yoyo_enemy_entry_angle = entry
	yoyo_enemy_previous_entry_angle = entry
	yoyo_enemy_previous_exit_angle = exit
	yoyo_enemy_winding_delta = yoyo_enemy_arc_angle - previous
	yoyo_wrap_position = yoyo_enemy_exit_point
	if yoyo_coil_phase == YoyoCoilPhase.NONE:
		yoyo_coil_phase = YoyoCoilPhase.TRACKING
	var commit_angle: float = TAU * clampf(yoyo_wrap_commit_turns, 0.1, 1.0)
	if yoyo_coil_phase == YoyoCoilPhase.TRACKING and previous < commit_angle and yoyo_enemy_arc_angle >= commit_angle:
		yoyo_coil_phase = YoyoCoilPhase.COMMITTED
		yoyo_coil_committed_enemy_id = enemy.get_instance_id()
		yoyo_coil_progress = 0.0
	if yoyo_enemy_arc_angle <= 0.03 and yoyo_enemy_segment_hit(hand, endpoint, center, radius + ENEMY_WRAP_CLEARANCE) == Vector2.INF:
		_clear_yoyo_wrap(enemy)

static func yoyo_rect_tangent(rect: Rect2, endpoint: Vector2, side: float) -> Vector2:
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	var selected: Vector2 = yoyo_rect_surface_point(rect, endpoint)
	var best: float = INF
	for corner: Vector2 in corners:
		var supported: bool = true
		for other: Vector2 in corners:
			if (corner - endpoint).cross(other - endpoint) * side < -0.001:
				supported = false
		if supported and endpoint.distance_squared_to(corner) < best:
			selected = corner
			best = endpoint.distance_squared_to(corner)
	return selected

static func yoyo_segment_crosses_rect(start: Vector2, end: Vector2, rect: Rect2) -> bool:
	var low: float = 0.0
	var high: float = 1.0
	var direction: Vector2 = end - start
	for axis: int in range(2):
		if absf(direction[axis]) < 0.00001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return false
		else:
			var first: float = (rect.position[axis] - start[axis]) / direction[axis]
			var last: float = (rect.end[axis] - start[axis]) / direction[axis]
			low = maxf(low, minf(first, last))
			high = minf(high, maxf(first, last))
			if low > high:
				return false
	return true

func _reset_yoyo_state() -> void:
	yoyo_state = YoyoState.NONE
	yoyo_catch_initialized = false
	yoyo_extend_time = 0.0
	yoyo_orbit_time = 0.0
	_clear_yoyo_wrap()

func _update_static_yoyo_wrap(hand_position: Vector2, chakram_position: Vector2, _delta: float) -> void:
	if not yoyo_static_pivot_enabled:
		_clear_yoyo_wrap()
		return
	if yoyo_wrap_active:
		if yoyo_wrap_object != null and not is_instance_valid(yoyo_wrap_object):
			_clear_yoyo_wrap()
			return
		if yoyo_wrap_object is ArenaObject and (yoyo_wrap_object as ArenaObject).broken:
			_clear_yoyo_wrap()
			return
		if _yoyo_static_obstruction_hit(hand_position, chakram_position).is_empty():
			yoyo_wrap_clear_ticks += 1
			if yoyo_wrap_clear_ticks >= 3:
				_clear_yoyo_wrap(yoyo_wrap_object)
		else:
			yoyo_wrap_clear_ticks = 0
		return
	var hit: Dictionary = _yoyo_static_obstruction_hit(hand_position, chakram_position)
	if hit.is_empty():
		return
	var candidate: Vector2 = hit["position"] as Vector2
	if hand_position.distance_to(candidate) < 18.0 or chakram_position.distance_to(candidate) < 18.0:
		return
	yoyo_wrap_active = true
	yoyo_wrap_phase = YoyoWrapPhase.WRAP_ACQUIRED
	yoyo_wrap_position = candidate
	yoyo_wrap_object = hit.get("object") as Node2D
	yoyo_wrap_bounds = Rect2()
	yoyo_wrap_clear_ticks = 0

func _update_yoyo_wrap(hand_position: Vector2, chakram_position: Vector2, _delta: float) -> void:
	if yoyo_wrap_uses_boundary != yoyo_boundary_wrap_enabled:
		_clear_yoyo_wrap()
		yoyo_wrap_uses_boundary = yoyo_boundary_wrap_enabled
	if not yoyo_boundary_wrap_enabled:
		_update_static_yoyo_wrap(hand_position, chakram_position, _delta)
		return
	if yoyo_wrap_active:
		if yoyo_wrap_phase == YoyoWrapPhase.WRAP_ACQUIRED:
			yoyo_wrap_phase = YoyoWrapPhase.WRAPPED
		if yoyo_state == YoyoState.REELING:
			yoyo_wrap_phase = YoyoWrapPhase.RETURNING
		# Terrain walls intentionally have no owner object; their world contact is
		# still valid topology and must not be mistaken for a freed dynamic body.
		if yoyo_wrap_object == null:
			if not yoyo_wrap_bounds.size.is_zero_approx():
				_update_rect_wrap(hand_position, chakram_position, _delta)
				return
			if _yoyo_obstruction_hit(hand_position, chakram_position).is_empty():
				yoyo_wrap_clear_ticks += 1
				if yoyo_wrap_clear_ticks >= 3:
					_clear_yoyo_wrap()
					return
			else:
				yoyo_wrap_clear_ticks = 0
			return
		if not is_instance_valid(yoyo_wrap_object):
			_clear_yoyo_wrap()
			return
		if yoyo_wrap_object is ArenaObject and (yoyo_wrap_object as ArenaObject).broken:
			_clear_yoyo_wrap()
			return
		if yoyo_wrap_object is Enemy:
			var wrapped_enemy: Enemy = yoyo_wrap_object as Enemy
			if wrapped_enemy.health <= 0.0 or not _enemy_wrap_supported(wrapped_enemy):
				_clear_yoyo_wrap()
				return
			var center: Vector2 = _enemy_wrap_center(wrapped_enemy)
			var radius: float = _enemy_wrap_radius(wrapped_enemy)
			yoyo_enemy_wrap_radius = radius
			_update_circle_contacts(hand_position, chakram_position, center, radius, wrapped_enemy)
			return
		# Rectangle adapters use the active collision boundary itself. The entry
		# parameter stays fixed while the exit parameter advances along the live
		# perimeter, so corners do not become frozen world-space hinges.
		if not yoyo_wrap_bounds.size.is_zero_approx():
			_update_rect_wrap(hand_position, chakram_position, _delta)
			return
		if _yoyo_obstruction_hit(hand_position, chakram_position, yoyo_wrap_object).is_empty():
			yoyo_wrap_clear_ticks += 1
			if yoyo_wrap_clear_ticks >= 3:
				_clear_yoyo_wrap(yoyo_wrap_object)
				return
		else:
			yoyo_wrap_clear_ticks = 0
		return
	if yoyo_reacquire_blocked_object != null:
		if not is_instance_valid(yoyo_reacquire_blocked_object):
			yoyo_reacquire_blocked_object = null
		elif yoyo_reacquire_blocked_object is Enemy:
			var blocked_enemy: Enemy = yoyo_reacquire_blocked_object as Enemy
			var blocked_center: Vector2 = _enemy_wrap_center(blocked_enemy)
			var blocked_clearance: float = _enemy_wrap_radius(blocked_enemy) + ENEMY_WRAP_CLEARANCE + 12.0
			if chakram_position.distance_to(blocked_center) <= blocked_clearance:
				return
			else:
				yoyo_reacquire_blocked_object = null
	var hit: Dictionary = _yoyo_obstruction_hit(hand_position, chakram_position)
	if hit.is_empty():
		return
	var candidate: Vector2 = hit["position"] as Vector2
	if hand_position.distance_to(candidate) < 18.0 or chakram_position.distance_to(candidate) < 18.0:
		return
	yoyo_wrap_active = true
	yoyo_wrap_phase = YoyoWrapPhase.WRAP_ACQUIRED
	yoyo_wrap_position = candidate
	yoyo_wrap_object = hit.get("object") as Node2D
	yoyo_wrap_bounds = hit.get("bounds", Rect2()) as Rect2
	if not yoyo_wrap_bounds.size.is_zero_approx():
		var best_length: float = INF
		for side: float in [1.0, -1.0]:
			var entry: Vector2 = yoyo_rect_tangent(yoyo_wrap_bounds, hand_position, side)
			var exit: Vector2 = yoyo_rect_tangent(yoyo_wrap_bounds, chakram_position, -side)
			var arc: float = yoyo_rect_directed_distance(yoyo_rect_perimeter_parameter(yoyo_wrap_bounds, entry), yoyo_rect_perimeter_parameter(yoyo_wrap_bounds, exit), side, yoyo_rect_perimeter_length(yoyo_wrap_bounds))
			var length: float = hand_position.distance_to(entry) + arc + exit.distance_to(chakram_position)
			if length < best_length:
				best_length = length
				yoyo_rect_wrap_sign = side
		var entry_surface: Vector2 = yoyo_rect_tangent(yoyo_wrap_bounds, hand_position, yoyo_rect_wrap_sign)
		var exit_surface: Vector2 = yoyo_rect_tangent(yoyo_wrap_bounds, chakram_position, -yoyo_rect_wrap_sign)
		yoyo_rect_entry_parameter = yoyo_rect_perimeter_parameter(yoyo_wrap_bounds, entry_surface)
		yoyo_rect_previous_exit_parameter = yoyo_rect_perimeter_parameter(yoyo_wrap_bounds, exit_surface)
		yoyo_rect_arc_length = yoyo_rect_directed_distance(yoyo_rect_entry_parameter, yoyo_rect_previous_exit_parameter, yoyo_rect_wrap_sign, yoyo_rect_perimeter_length(yoyo_wrap_bounds))
		yoyo_rect_entry_point = entry_surface
		yoyo_rect_exit_point = exit_surface
	if yoyo_wrap_object is Enemy:
		var enemy: Enemy = yoyo_wrap_object as Enemy
		yoyo_enemy_wrap_sign = yoyo_shortest_wrap_sign(_enemy_wrap_center(enemy), hand_position, chakram_position, _enemy_wrap_radius(enemy))
		_update_yoyo_wrap(hand_position, chakram_position, 0.0)

func _coil_motion_is_clear(moving_target: Node2D, wrapped_enemy: Enemy, from_position: Vector2, to_position: Vector2, moving_radius: float) -> bool:
	var main_scene: Node = player.get_tree().current_scene if player != null and player.is_inside_tree() else null
	if main_scene != null and main_scene.has_method("get_terrain_obstruction_hit") and not (main_scene.call("get_terrain_obstruction_hit", from_position, to_position, moving_radius) as Dictionary).is_empty():
		return false
	if main_scene != null and main_scene.has_method("get_terrain_wall_collision") and not (main_scene.call("get_terrain_wall_collision", from_position, to_position, moving_radius) as Dictionary).is_empty():
		return false
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var obstacle: Enemy = node as Enemy
		if obstacle == null or obstacle == moving_target or obstacle == wrapped_enemy or obstacle.health <= 0.0:
			continue
		var boundary: Dictionary = enemy_collision_circle(obstacle)
		if bool(boundary.get("supported", false)) and Chakram.swept_circle_contact(from_position, to_position, boundary.get("center") as Vector2, moving_radius + float(boundary.get("radius", 0.0))):
			return false
	return true

func _place_committed_target(moving_target: Node2D, next_position: Vector2, _delta: float) -> void:
	moving_target.global_position = next_position
	if moving_target is Chakram:
		# Position is authoritative during committed traversal; leaving derived
		# velocity active would make Chakram._physics_process move the path twice.
		(moving_target as Chakram).velocity = Vector2.ZERO
	elif moving_target is Enemy:
		var moving_enemy: Enemy = moving_target as Enemy
		moving_enemy.velocity = Vector2.ZERO
		moving_enemy.knockback = Vector2.ZERO

func _update_committed_coil(moving_target: Node2D, moving_radius: float, enemy: Enemy, delta: float) -> void:
	var center: Vector2 = _enemy_wrap_center(enemy)
	var capture_radius: float = _enemy_wrap_radius(enemy) + moving_radius + 0.5
	var total_angle: float = TAU * clampf(yoyo_coil_revolutions, 1.0, 2.0)
	if yoyo_coil_start_radius <= 0.0:
		yoyo_coil_start_radius = maxf(capture_radius, center.distance_to(moving_target.global_position))
		yoyo_coil_current_radius = yoyo_coil_start_radius
		yoyo_coil_start_angle = center.angle_to_point(moving_target.global_position)
		yoyo_coil_angle_travel = 0.0
		var average_radius: float = (yoyo_coil_start_radius + capture_radius) * 0.5
		yoyo_coil_path_length = maxf(1.0, total_angle * average_radius + yoyo_coil_start_radius - capture_radius)
	if yoyo_coil_phase == YoyoCoilPhase.HOLDING:
		# Impact begins the visible uncoil immediately. The enemy remains the live
		# grapple target and stays stunned for the complete authored hold window.
		yoyo_coil_hold_left = maxf(0.0, yoyo_coil_hold_left - maxf(0.0, delta))
		yoyo_coil_progress = coil_progress(yoyo_coil_progress, yoyo_unwind_speed, delta, yoyo_coil_path_length, true)
		var hold_unwind_position: Vector2 = coil_position(center, yoyo_coil_start_radius, capture_radius, yoyo_coil_start_angle, yoyo_enemy_wrap_sign, yoyo_coil_progress, yoyo_coil_revolutions)
		if _coil_motion_is_clear(moving_target, enemy, moving_target.global_position, hold_unwind_position, moving_radius):
			_place_committed_target(moving_target, hold_unwind_position, delta)
		if yoyo_coil_hold_left <= 0.0 and yoyo_coil_progress <= 0.0:
			yoyo_state = YoyoState.REELING
			_clear_yoyo_wrap(enemy)
		return
	if yoyo_coil_phase == YoyoCoilPhase.UNWINDING:
		yoyo_coil_progress = coil_progress(yoyo_coil_progress, yoyo_unwind_speed, delta, yoyo_coil_path_length, true)
		var unwind_position: Vector2 = coil_position(center, yoyo_coil_start_radius, capture_radius, yoyo_coil_start_angle, yoyo_enemy_wrap_sign, yoyo_coil_progress, yoyo_coil_revolutions)
		if _coil_motion_is_clear(moving_target, enemy, moving_target.global_position, unwind_position, moving_radius):
			_place_committed_target(moving_target, unwind_position, delta)
		if yoyo_coil_progress <= 0.0:
			_clear_yoyo_wrap(enemy)
		return
	if yoyo_coil_phase == YoyoCoilPhase.COMMITTED:
		var accepted_angle: float = yoyo_coil_angle_travel
		var accepted_radius: float = yoyo_coil_current_radius
		var accepted_progress: float = yoyo_coil_progress
		# Tangent and cinch have separate authorities. This guarantees one-to-two
		# readable revolutions even when the capture radius is reached early.
		var tightening_distance: float = yoyo_coil_start_radius - capture_radius
		var tightening_ratio: float = 1.0 if tightening_distance <= 0.001 else clampf((yoyo_coil_start_radius - yoyo_coil_current_radius) / tightening_distance, 0.0, 1.0)
		var authored_tangential_speed: float = maxf(0.0, yoyo_coil_tangential_speed) * (1.0 + maxf(0.0, yoyo_coil_speed_gain) * tightening_ratio)
		var angular_speed: float = authored_tangential_speed / maxf(capture_radius, yoyo_coil_current_radius)
		yoyo_coil_angle_travel = minf(total_angle, yoyo_coil_angle_travel + angular_speed * maxf(0.0, delta))
		yoyo_coil_current_radius = move_toward(yoyo_coil_current_radius, capture_radius, maxf(0.0, yoyo_coil_radial_speed) * maxf(0.0, delta))
		var angular_progress: float = clampf(yoyo_coil_angle_travel / maxf(0.001, total_angle), 0.0, 1.0)
		var radial_distance: float = yoyo_coil_start_radius - capture_radius
		var radial_progress: float = 1.0 if radial_distance <= 0.001 else clampf((yoyo_coil_start_radius - yoyo_coil_current_radius) / radial_distance, 0.0, 1.0)
		yoyo_coil_progress = minf(angular_progress, radial_progress)
		var angle: float = yoyo_coil_start_angle + signf(yoyo_enemy_wrap_sign) * yoyo_coil_angle_travel
		var inward_position: Vector2 = center + Vector2.from_angle(angle) * yoyo_coil_current_radius
		if not _coil_motion_is_clear(moving_target, enemy, moving_target.global_position, inward_position, moving_radius):
			yoyo_coil_angle_travel = accepted_angle
			yoyo_coil_current_radius = accepted_radius
			yoyo_coil_progress = accepted_progress
			yoyo_coil_phase = YoyoCoilPhase.UNWINDING
			return
		_place_committed_target(moving_target, inward_position, delta)
		if angular_progress >= 1.0 and radial_progress >= 1.0:
			yoyo_coil_progress = 1.0
			yoyo_coil_phase = YoyoCoilPhase.DAMAGE_ARMED
			if moving_target is Chakram:
				(moving_target as Chakram).velocity = moving_target.global_position.direction_to(center) * maxf(120.0, yoyo_coil_radial_speed)
			else:
				_complete_grappled_enemy_coil(enemy)

func _complete_grappled_enemy_coil(wrapped_enemy: Enemy) -> void:
	if yoyo_coil_phase != YoyoCoilPhase.DAMAGE_ARMED:
		return
	wrapped_enemy.take_damage(10.0, Vector2.ZERO, 0.18, 0.75)
	notify_yoyo_coil_hit(wrapped_enemy)

func notify_yoyo_obstruction_hit(collider: Node = null) -> void:
	if yoyo_coil_phase != YoyoCoilPhase.COMMITTED and yoyo_coil_phase != YoyoCoilPhase.DAMAGE_ARMED:
		return
	if collider != null and collider == yoyo_wrap_object:
		return
	yoyo_coil_phase = YoyoCoilPhase.UNWINDING

func _apply_enemy_grapple_response(enemy: Enemy, active_rope_length: float, hand_position: Vector2, hand_velocity: Vector2, delta: float, ramp: float) -> Vector2:
	if enemy == null or not is_instance_valid(enemy):
		return Vector2.ZERO
	var response: Vector2 = Vector2.ZERO
	match enemy.grapple_weight:
		Enemy.GrappleWeight.LIGHT:
			var light_tension: Vector2 = tension_acceleration(enemy.global_position, player.global_position, active_rope_length, enemy_pull_strength, ramp)
			var light_yank: Vector2 = target_hand_acceleration(enemy.global_position, hand_position, hand_velocity, light_yank_strength, light_yank_strength * radial_yank_ratio, directional_transfer_ratio, true)
			enemy.apply_grapple_force(light_tension, delta)
			enemy.apply_grapple_force(light_yank, delta, INF, light_slide_fraction)
		Enemy.GrappleWeight.MEDIUM:
			var medium_tension: Vector2 = tension_acceleration(enemy.global_position, player.global_position, active_rope_length, enemy_pull_strength * medium_reel_multiplier, ramp)
			var medium_yank: Vector2 = target_hand_acceleration(enemy.global_position, hand_position, hand_velocity, medium_yank_strength, medium_yank_strength * radial_yank_ratio, directional_transfer_ratio, true)
			enemy.apply_grapple_force(medium_tension, delta)
			enemy.apply_grapple_force(medium_yank, delta, INF, medium_slide_fraction)
			response = tension_acceleration(player.global_position, enemy.global_position, active_rope_length, medium_player_pull_strength, ramp)
			response += player_hand_acceleration(hand_position, enemy.global_position, hand_velocity, player_hand_orbit_strength, player_radial_yank_strength, true)
		Enemy.GrappleWeight.HEAVY:
			response = tension_acceleration(player.global_position, enemy.global_position, active_rope_length, heavy_player_pull_strength, ramp)
			response += player_hand_acceleration(hand_position, enemy.global_position, hand_velocity, player_hand_orbit_strength, player_radial_yank_strength, true)
	return response

func update_and_get_player_acceleration(held: bool, aim_point: Vector2, delta: float) -> Vector2:
	visual_time += delta
	var current_hand_position: Vector2 = player.get_grapple_hand_position() if player != null else Vector2.ZERO
	if previous_hand_position == Vector2.ZERO:
		previous_hand_position = current_hand_position
	var raw_hand_velocity: Vector2 = (current_hand_position - previous_hand_position) / maxf(delta, 0.0001)
	smoothed_hand_velocity = smoothed_velocity(smoothed_hand_velocity, raw_hand_velocity, hand_velocity_smoothing, delta, hand_velocity_cap)
	previous_hand_position = current_hand_position
	grapple_dash_momentum_left = maxf(0.0, grapple_dash_momentum_left - delta)
	terrain_release_slide_left = maxf(0.0, terrain_release_slide_left - delta)
	if held and not input_was_down:
		_begin_shot(aim_point)
	elif not held and input_was_down:
		release_tether()
	input_was_down = held
	if firing:
		_update_hook_flight(delta)
		queue_redraw()
		return Vector2.ZERO
	if not active:
		tension_ratio = 0.0
		queue_redraw()
		return Vector2.ZERO
	if target_type != TargetType.TERRAIN:
		if not is_instance_valid(target_node):
			release_tether()
			return Vector2.ZERO
		anchor_position = target_node.global_position
	var is_chakram_yoyo: bool = yoyo_enabled and target_type == TargetType.CHAKRAM and target_node is Chakram
	var is_enemy_wrap_target: bool = yoyo_enabled and yoyo_boundary_wrap_enabled and target_type == TargetType.ENEMY and target_node is Enemy
	if is_enemy_wrap_target:
		var grappled_enemy: Enemy = target_node as Enemy
		_update_yoyo_wrap(current_hand_position, grappled_enemy.global_position, delta)
		if is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy and yoyo_wrap_object != grappled_enemy and yoyo_coil_phase in [YoyoCoilPhase.COMMITTED, YoyoCoilPhase.UNWINDING, YoyoCoilPhase.DAMAGE_ARMED, YoyoCoilPhase.HOLDING]:
			var moving_boundary: Dictionary = enemy_collision_circle(grappled_enemy)
			_update_committed_coil(grappled_enemy, float(moving_boundary.get("radius", ENEMY_WRAP_RADIUS)), yoyo_wrap_object as Enemy, delta)
	var rope_was_taut: bool = rope_taut
	yoyo_reel_shortfall = 0.0
	if is_chakram_yoyo:
		var yoyo_chakram: Chakram = target_node as Chakram
		_update_yoyo_wrap(current_hand_position, yoyo_chakram.global_position, delta)
		if is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy and yoyo_coil_phase in [YoyoCoilPhase.COMMITTED, YoyoCoilPhase.UNWINDING, YoyoCoilPhase.DAMAGE_ARMED, YoyoCoilPhase.HOLDING]:
			_update_committed_coil(yoyo_chakram, yoyo_chakram.get_collision_radius(), yoyo_wrap_object as Enemy, delta)
		var pivot: Vector2 = yoyo_wrap_position if yoyo_wrap_active else current_hand_position
		var local_rope_length: float = _yoyo_live_local_length(rope_length, current_hand_position)
		var pivot_distance: float = pivot.distance_to(yoyo_chakram.global_position)
		var path_length: float = _yoyo_live_path_length(current_hand_position, yoyo_chakram.global_position)
		# Attachment slack has one visible authority. Once caught, inward travel
		# never rewrites rope_length; it is temporary geometry, not hidden ratcheting.
		if not rope_taut:
			if not yoyo_catch_initialized:
				rope_length = maxf(MIN_ROPE_LENGTH, path_length + maxf(0.0, initial_slack))
				yoyo_catch_initialized = true
				rope_taut = initial_slack <= 0.0
			else:
				rope_length = reeled_length(rope_length, slack_take_up_speed, delta)
				if rope_length <= path_length + 0.5:
					rope_taut = true
		local_rope_length = _yoyo_live_local_length(rope_length, current_hand_position)
		if yoyo_state == YoyoState.NONE:
			yoyo_state = YoyoState.EXTENDING
		if yoyo_state == YoyoState.EXTENDING:
			yoyo_extend_time += maxf(0.0, delta)
			var outward_direction: Vector2 = pivot.direction_to(yoyo_chakram.global_position)
			var outward_speed: float = yoyo_chakram.velocity.dot(outward_direction)
			var catch_orbit: bool = pivot_distance >= local_rope_length - TAUT_CLEARANCE or (outward_speed <= 20.0 and rope_taut)
			if catch_orbit:
				# Settle radial travel once at capture. This prevents inward drift from
				# manufacturing a large slack loop while preserving the full tangent.
				yoyo_chakram.velocity = Chakram.yoyo_captured_velocity(yoyo_chakram.global_position, yoyo_chakram.velocity, pivot, yoyo_catch_radial_retention)
				yoyo_state = YoyoState.ORBITING
				yoyo_orbit_time = 0.0
				rope_taut = true
		elif yoyo_state == YoyoState.ORBITING:
			yoyo_orbit_time += maxf(0.0, delta)
			# Recover only geometric slack. The live path is a hard floor, so this
			# cannot pull inward or become a second recall authority.
			rope_length = recovered_orbit_length(rope_length, path_length, yoyo_orbit_slack_recovery_speed, delta)
			local_rope_length = _yoyo_live_local_length(rope_length, current_hand_position)
			rope_taut = true
			var radial_direction: Vector2 = pivot.direction_to(yoyo_chakram.global_position)
			var radial_velocity: Vector2 = radial_direction * yoyo_chakram.velocity.dot(radial_direction)
			var tangential_speed: float = (yoyo_chakram.velocity - radial_velocity).length()
			if yoyo_coil_phase in [YoyoCoilPhase.NONE, YoyoCoilPhase.TRACKING] and yoyo_should_recall(yoyo_orbit_time, yoyo_min_orbit_time, tangential_speed, yoyo_recall_speed_threshold):
				yoyo_state = YoyoState.REELING
		elif yoyo_state == YoyoState.REELING:
			rope_taut = true
			rope_length = reeled_length(rope_length, reel_speed, delta)
			local_rope_length = _yoyo_live_local_length(rope_length, current_hand_position)
		var active_drag: float = yoyo_orbit_drag if yoyo_state == YoyoState.ORBITING else 0.0
		var coil_enemy_id: int = -1
		var coil_contact_armed: bool = false
		if not yoyo_coil_hit_consumed and yoyo_coil_phase == YoyoCoilPhase.DAMAGE_ARMED and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy and yoyo_wrap_object.get_instance_id() == yoyo_coil_committed_enemy_id:
			coil_enemy_id = yoyo_coil_committed_enemy_id
			coil_contact_armed = true
		var coil_speed_override: float = yoyo_coil_tangential_speed * (1.0 + yoyo_coil_speed_gain) if yoyo_coil_phase in [YoyoCoilPhase.COMMITTED, YoyoCoilPhase.UNWINDING, YoyoCoilPhase.DAMAGE_ARMED, YoyoCoilPhase.HOLDING] else 0.0
		if coil_speed_override > 0.0:
			# The accepted kinematic spiral is authoritative; ordinary rope projection
			# must not alter it after progress has already been counted.
			local_rope_length = maxf(local_rope_length, pivot.distance_to(yoyo_chakram.global_position) + 2.0)
		yoyo_chakram.configure_yoyo_constraint(pivot, local_rope_length, yoyo_soft_tension_zone, yoyo_radial_damping, active_drag, coil_enemy_id, coil_contact_armed, coil_speed_override)
	else:
		var current_tether_distance: float = _tether_distance()
		if not rope_taut:
			rope_length = maxf(MIN_ROPE_LENGTH, current_tether_distance)
			rope_taut = true
		else:
			# Continue reeling after the initial slack phase. The current distance is
			# only an upper bound, so the rope stays taut while reel_speed keeps
			# shortening it and increasing the pull as long as the button is held.
			var reeled_rope_length: float = reeled_length(rope_length, reel_speed, delta)
			var taut_limit: float = maxf(MIN_ROPE_LENGTH, current_tether_distance - TAUT_CLEARANCE)
			rope_length = minf(reeled_rope_length, taut_limit)
	yoyo_enemy_last_acceleration = Vector2.ZERO
	var player_acceleration: Vector2 = Vector2.ZERO
	var ramp: float = maxf(0.001, tension_ramp_distance)
	var live_hand_position: Vector2 = player.get_grapple_hand_position()
	var articulated_hand_velocity: Vector2 = authored_hand_velocity(smoothed_hand_velocity, player.velocity, body_movement_transfer)
	match target_type:
		TargetType.TERRAIN:
			player_acceleration = tension_acceleration(player.global_position, anchor_position, rope_length, wall_pull_strength, ramp)
			player_acceleration += player_hand_acceleration(live_hand_position, anchor_position, articulated_hand_velocity, player_hand_orbit_strength, player_radial_yank_strength, rope_taut)
		TargetType.ENEMY:
			player_acceleration = _apply_enemy_grapple_response(target_node as Enemy, rope_length, live_hand_position, articulated_hand_velocity, delta, ramp)
		TargetType.CHAKRAM:
			var tethered_chakram: Chakram = target_node as Chakram
			if tethered_chakram != null:
				var chakram_hand: Vector2 = live_hand_position
				var chakram_pivot: Vector2 = (yoyo_wrap_position if yoyo_wrap_active else live_hand_position) if is_chakram_yoyo else player.global_position
				var chakram_local_length: float = _yoyo_live_local_length(rope_length, live_hand_position) if is_chakram_yoyo else rope_length
				var reel_is_active: bool = not is_chakram_yoyo or yoyo_state == YoyoState.REELING
				var chakram_tension: Vector2 = tension_acceleration(tethered_chakram.global_position, chakram_pivot, chakram_local_length, chakram_tether_strength, ramp) if reel_is_active else Vector2.ZERO
				var chakram_yank: Vector2 = target_hand_acceleration(tethered_chakram.global_position, chakram_hand, articulated_hand_velocity, chakram_yank_strength, chakram_yank_strength * radial_yank_ratio, directional_transfer_ratio, rope_taut)
				# Yo-yo motion is hand-authored: tangent dominates and only deliberate
				# radial hand travel pulls the Chakram inward. The one catch-edge impulse
				# uses the full sampled hand motion from the known-good build; ongoing
				# steering keeps GP2's Body Movement Transfer filtering.
				tethered_chakram.apply_grapple_force(chakram_tension, delta)
				tethered_chakram.apply_grapple_force(chakram_yank, delta)
				if is_chakram_yoyo and rope_taut and not rope_was_taut:
					var catch_yank: Vector2 = target_hand_acceleration(tethered_chakram.global_position, chakram_hand, smoothed_hand_velocity, chakram_yank_strength, chakram_yank_strength * radial_yank_ratio, directional_transfer_ratio, true)
					tethered_chakram.apply_grapple_force(catch_yank, taut_catch_impulse_seconds)
				if is_chakram_yoyo and rope_taut and yoyo_coil_phase != YoyoCoilPhase.HOLDING and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
					var wrapped_enemy: Enemy = yoyo_wrap_object as Enemy
					var path_stretch: float = maxf(0.0, _yoyo_live_path_length(live_hand_position, tethered_chakram.global_position) - rope_length)
					var tension_demand: float = maxf(path_stretch, yoyo_reel_shortfall)
					var tension_engagement: float = clampf(tension_demand / ramp, 0.0, 1.0)
					var enemy_force_scale: float = 0.0
					var player_pull_strength: float = 0.0
					var slide_fraction: float = 0.0
					match wrapped_enemy.grapple_weight:
						Enemy.GrappleWeight.LIGHT:
							enemy_force_scale = 1.0
							slide_fraction = light_slide_fraction
						Enemy.GrappleWeight.MEDIUM:
							enemy_force_scale = medium_reel_multiplier
							player_pull_strength = medium_player_pull_strength
							slide_fraction = medium_slide_fraction
						Enemy.GrappleWeight.HEAVY:
							enemy_force_scale = 0.0
							player_pull_strength = heavy_player_pull_strength
					var hand_pull: Vector2 = wrapped_enemy.global_position.direction_to(live_hand_position)
					var chakram_pull: Vector2 = wrapped_enemy.global_position.direction_to(tethered_chakram.global_position)
					# Two rope legs share one authored Light Target Reel Force; averaging
					# prevents a wrap from silently doubling that canonical authority.
					var wrap_acceleration: Vector2 = yoyo_enemy_wrap_acceleration(hand_pull, chakram_pull, tension_demand, ramp, enemy_pull_strength, enemy_force_scale)
					yoyo_enemy_last_acceleration = wrap_acceleration
					wrapped_enemy.apply_grapple_force(wrap_acceleration, delta, INF, slide_fraction)
					if player_pull_strength > 0.0:
						player_acceleration += player.global_position.direction_to(wrapped_enemy.global_position) * player_pull_strength * tension_engagement

		TargetType.GLYPH:
			player_acceleration = tension_acceleration(player.global_position, anchor_position, rope_length, wall_pull_strength, ramp)
			player_acceleration += player_hand_acceleration(live_hand_position, anchor_position, articulated_hand_velocity, player_hand_orbit_strength, player_radial_yank_strength, rope_taut)
	# A completed wrap temporarily creates a second dynamic grapple endpoint.
	# It uses the exact same weight authority as a direct enemy hit while the
	# original Chakram/enemy target continues following its own grapple path.
	if yoyo_coil_phase == YoyoCoilPhase.HOLDING and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
		yoyo_wrapped_hold_rope_length = reeled_length(yoyo_wrapped_hold_rope_length, reel_speed, delta)
		player_acceleration += _apply_enemy_grapple_response(yoyo_wrap_object as Enemy, yoyo_wrapped_hold_rope_length, live_hand_position, articulated_hand_velocity, delta, ramp)
	var current_distance: float = _tether_distance()
	tension_ratio = clampf((current_distance - rope_length) / ramp, 0.0, 1.0)
	if is_chakram_yoyo and yoyo_wrap_active and is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
		yoyo_debug_sample_left -= maxf(0.0, delta)
		if yoyo_debug_sample_left <= 0.0:
			print("YOYO: ", yoyo_debug_status().replace("\n", " | "))
			yoyo_debug_sample_left = 0.15
	else:
		yoyo_debug_sample_left = 0.0
	queue_redraw()
	return player_acceleration

func is_yoyo_coiling_enemy(enemy: Enemy) -> bool:
	return active and target_type == TargetType.CHAKRAM and yoyo_wrap_active and enemy != null and enemy == yoyo_wrap_object

func notify_yoyo_coil_hit(enemy: Enemy) -> void:
	if not active or target_type not in [TargetType.CHAKRAM, TargetType.ENEMY] or enemy == null or enemy != yoyo_wrap_object:
		return
	if yoyo_coil_phase != YoyoCoilPhase.DAMAGE_ARMED or yoyo_coil_hit_consumed or enemy.get_instance_id() != yoyo_coil_committed_enemy_id:
		return
	yoyo_coil_hit_consumed = true
	yoyo_coil_phase = YoyoCoilPhase.HOLDING
	yoyo_coil_hold_left = maxf(0.0, yoyo_coil_hold_duration)
	yoyo_wrapped_hold_rope_length = maxf(MIN_ROPE_LENGTH, player.get_grapple_hand_position().distance_to(enemy.global_position))
	enemy.stun_for(yoyo_coil_hold_left)
	var main_scene: Node = player.get_tree().current_scene if player != null and player.is_inside_tree() else null
	if main_scene != null and main_scene.has_method("spawn_wrapped_popup"):
		main_scene.call("spawn_wrapped_popup", enemy.global_position)
	yoyo_orbit_time = 0.0
	yoyo_debug_sample_left = 0.0

func fire_at(aim_point: Vector2) -> bool:
	if active or firing:
		return false
	return _begin_shot(aim_point)

func _begin_shot(aim_point: Vector2) -> bool:
	if player == null or not player.is_inside_tree():
		return false
	var hand_position: Vector2 = player.get_grapple_hand_position()
	var aim_offset: Vector2 = aim_point - hand_position
	if aim_offset.length_squared() < 1.0:
		return false
	var ray_end: Vector2 = aimed_endpoint(hand_position, aim_point, max_tether_length * mastery_range_multiplier)
	var selected_distance: float = INF
	var selected_type: TargetType = TargetType.NONE
	var selected_node: Node2D = null
	var selected_anchor: Vector2 = Vector2.ZERO

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(hand_position, ray_end, TARGET_MASK, [player.get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var dynamic_hit: Dictionary = _find_dynamic_target_hit(hand_position, ray_end)
	if not dynamic_hit.is_empty():
		var node: Node2D = dynamic_hit["node"] as Node2D
		var hit_position: Vector2 = dynamic_hit["position"] as Vector2
		if node.is_in_group("zungar") or node.is_in_group("enemies"):
			selected_type = TargetType.ENEMY
			selected_node = node
			selected_anchor = node.global_position
			selected_distance = hand_position.distance_to(hit_position)
		elif node.is_in_group("chakram") and node is Chakram:
			selected_type = TargetType.CHAKRAM
			selected_node = node
			selected_anchor = node.global_position
			selected_distance = hand_position.distance_to(hit_position)
		elif node.is_in_group("resonant_glyph"):
			selected_type = TargetType.GLYPH
			selected_node = node
			selected_anchor = node.global_position
			selected_distance = hand_position.distance_to(hit_position)

	var main_scene: Node = player.get_tree().current_scene
	if main_scene != null and main_scene.has_method("get_terrain_wall_collision"):
		var wall_hit: Dictionary = main_scene.call("get_terrain_wall_collision", hand_position, ray_end, 0.0) as Dictionary
		if not wall_hit.is_empty():
			var wall_anchor: Vector2 = wall_hit["position"] as Vector2
			var wall_distance: float = hand_position.distance_to(wall_anchor)
			if wall_distance <= selected_distance:
				selected_type = TargetType.TERRAIN
				selected_node = null
				selected_anchor = wall_anchor
	if selected_type == TargetType.NONE:
		# In this top-down arena the ground itself is valid terrain. If the shot
		# crosses no wall or dynamic target, anchor exactly where it was aimed,
		# clamped to the configured range, so RMB always produces feedback.
		selected_type = TargetType.TERRAIN
		selected_anchor = ray_end
	_reset_yoyo_state()
	active = false
	firing = true
	target_type = TargetType.NONE
	target_node = null
	shot_target_type = selected_type
	shot_target_node = selected_node
	shot_target_position = selected_anchor
	hook_position = hand_position
	hook_direction = hand_position.direction_to(shot_target_position)
	if hook_direction == Vector2.ZERO: hook_direction = Vector2.RIGHT
	tension_ratio = 0.0
	queue_redraw()
	return true

func _resolve_target_owner(node: Node2D) -> Node2D:
	var current: Node = node
	while current != null:
		if current.is_in_group("zungar") or current.is_in_group("enemies") or current.is_in_group("chakram") or current.is_in_group("resonant_glyph"):
			return current as Node2D
		current = current.get_parent()
	return null

func _find_dynamic_target_hit(origin: Vector2, endpoint: Vector2) -> Dictionary:
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var travel: Vector2 = endpoint - origin
	var travel_length: float = travel.length()
	if travel_length < 0.001:
		return {}
	var sample_count: int = maxi(1, ceili(travel_length / maxf(HOOK_TIP_RADIUS * 0.75, 1.0)))
	var hook_shape: CircleShape2D = CircleShape2D.new()
	hook_shape.radius = HOOK_TIP_RADIUS
	var seen_targets: Dictionary[int, bool] = {}
	for sample_index: int in range(sample_count + 1):
		var sample_position: Vector2 = origin + travel * (float(sample_index) / float(sample_count))
		var shape_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
		shape_query.shape = hook_shape
		shape_query.transform = Transform2D(0.0, sample_position)
		shape_query.collision_mask = TARGET_MASK
		shape_query.collide_with_areas = true
		shape_query.collide_with_bodies = true
		shape_query.exclude = [player.get_rid()]
		for hit: Dictionary in space_state.intersect_shape(shape_query, 16):
			var collider: Object = hit.get("collider") as Object
			if not collider is Node2D:
				continue
			var target: Node2D = _resolve_target_owner(collider as Node2D)
			if target == null or seen_targets.has(target.get_instance_id()):
				continue
			seen_targets[target.get_instance_id()] = true
			return {"node": target, "position": sample_position}
	return {}

func _update_hook_flight(delta: float) -> void:
	if shot_target_type != TargetType.TERRAIN:
		if not is_instance_valid(shot_target_node):
			firing = false
			return
		shot_target_position = shot_target_node.global_position
	var previous_position: Vector2 = hook_position
	hook_position = hook_position.move_toward(shot_target_position, maxf(0.0, hook_travel_speed) * delta)
	var travel_direction: Vector2 = previous_position.direction_to(hook_position)
	if travel_direction != Vector2.ZERO: hook_direction = travel_direction
	if hook_position.distance_squared_to(shot_target_position) <= 1.0:
		firing = false
		if shot_target_type == TargetType.CHAKRAM and shot_target_node is Chakram and (shot_target_node as Chakram).grounded:
			# Downed retrieval is a separate verb: launch the disc straight home and
			# end the hook. It must never enter flying Yo-yo attachment/orbit state.
			(shot_target_node as Chakram).begin_grapple_retrieval()
			active = false
			target_type = TargetType.NONE
			target_node = null
			shot_target_type = TargetType.NONE
			shot_target_node = null
			tension_ratio = 0.0
			rope_taut = false
			_reset_yoyo_state()
			queue_redraw()
			return
		active = true
		target_type = shot_target_type
		target_node = shot_target_node
		anchor_position = shot_target_position
		hook_position = anchor_position
		if target_type == TargetType.CHAKRAM and is_instance_valid(target_node) and target_node.has_method("on_grapple_attached"):
			target_node.call("on_grapple_attached")
		if yoyo_enabled and target_type == TargetType.CHAKRAM:
			# Measured catch length plus the one visible Initial Slack authority.
			rope_length = minf(max_tether_length, _tether_distance() + maxf(0.0, initial_slack))
			rope_taut = initial_slack <= 0.0
			yoyo_catch_initialized = true
			yoyo_state = YoyoState.EXTENDING
		else:
			rope_length = minf(max_tether_length, _tether_distance())
			rope_taut = true
		shot_target_type = TargetType.NONE
		shot_target_node = null
		tension_ratio = 0.0

func release_tether() -> void:
	if active and target_type == TargetType.TERRAIN:
		terrain_release_slide_left = TERRAIN_RELEASE_SLIDE_DURATION
	if active and target_type == TargetType.CHAKRAM and is_instance_valid(target_node) and target_node.has_method("on_grapple_detached"):
		target_node.call("on_grapple_detached")
	active = false
	firing = false
	target_type = TargetType.NONE
	target_node = null
	shot_target_type = TargetType.NONE
	shot_target_node = null
	tension_ratio = 0.0
	rope_taut = false
	_reset_yoyo_state()
	queue_redraw()

func release_if_target(node: Node) -> void:
	if (active and target_node == node) or (firing and shot_target_node == node):
		release_tether()

func cancel_and_latch(physical_button_down: bool) -> void:
	if active and target_type == TargetType.CHAKRAM and is_instance_valid(target_node) and target_node.has_method("on_grapple_detached"):
		target_node.call("on_grapple_detached")
	active = false
	firing = false
	target_type = TargetType.NONE
	target_node = null
	shot_target_type = TargetType.NONE
	shot_target_node = null
	tension_ratio = 0.0
	rope_taut = false
	_reset_yoyo_state()
	input_was_down = physical_button_down
	queue_redraw()

func notify_tethered_dash() -> void:
	if active:
		grapple_dash_momentum_left = GRAPPLE_DASH_MOMENTUM_DURATION

func movement_traction_multiplier() -> float:
	if active and grapple_dash_momentum_left > 0.0:
		return grapple_dash_traction
	if active and target_type == TargetType.TERRAIN:
		return maxf(grapple_dash_traction, 0.35)
	if terrain_release_slide_left > 0.0:
		return minf(grapple_dash_traction, 0.35)
	return 1.0

func is_dash_momentum_active() -> bool:
	return active and grapple_dash_momentum_left > 0.0

func target_name() -> String:
	if firing: return "Hook in flight"
	match target_type:
		TargetType.TERRAIN: return "Terrain"
		TargetType.ENEMY: return "Enemy"
		TargetType.CHAKRAM:
			if yoyo_coil_phase not in [YoyoCoilPhase.NONE, YoyoCoilPhase.TRACKING]:
				return "Chakram Coil — %s" % str(YoyoCoilPhase.keys()[yoyo_coil_phase]).capitalize()
			match yoyo_state:
				YoyoState.EXTENDING: return "Chakram Yo-yo — Extending"
				YoyoState.ORBITING: return "Chakram Yo-yo — Orbiting%s" % (" / Wrapped" if yoyo_wrap_active else "")
				YoyoState.REELING: return "Chakram Yo-yo — Reeling%s" % (" / Wrapped" if yoyo_wrap_active else "")
				_: return "Chakram"
		TargetType.GLYPH: return "Resonant Glyph"
		_: return "None"

func yoyo_debug_status() -> String:
	if not active or target_type != TargetType.CHAKRAM or not is_instance_valid(target_node):
		return ""
	var chakram: Chakram = target_node as Chakram
	var hand: Vector2 = player.get_grapple_hand_position()
	var measured_path: float = _yoyo_live_path_length(hand, chakram.global_position)
	var local_rope: float = _yoyo_live_local_length(rope_length, hand)
	var owner_name: String = "None"
	var radial_speed: float = 0.0
	var tangent_speed: float = 0.0
	if is_instance_valid(yoyo_wrap_object):
		owner_name = yoyo_wrap_object.name
		if yoyo_wrap_object is Enemy:
			var radial_direction: Vector2 = (chakram.global_position - yoyo_wrap_object.global_position).normalized()
			radial_speed = chakram.velocity.dot(radial_direction)
			tangent_speed = chakram.velocity.dot(radial_direction.orthogonal())
	var hit_age: int = Engine.get_physics_frames() - chakram.yoyo_last_enemy_hit_frame if chakram.yoyo_last_enemy_hit_frame >= 0 else -1
	return "Wrap %s | Coil %s %.0f%% | Path %.1f / Rope %.1f | Stretch %.1f | Reel shortfall %.1f\nArc %.2f turns (minimum %.2f, delta %.3f) | Arc rope %.1f | Local %.1f\nRadial %.1f | Tangent %.1f | Correction %.1f px | Enemy accel %.1f | Hit age %d (in %.0f / out %.0f)" % [owner_name, str(YoyoCoilPhase.keys()[yoyo_coil_phase]).capitalize(), yoyo_coil_progress * 100.0, measured_path, rope_length, measured_path - rope_length, yoyo_reel_shortfall, yoyo_enemy_arc_angle / TAU, yoyo_enemy_minimum_arc / TAU, yoyo_enemy_winding_delta / TAU, yoyo_enemy_arc_angle * yoyo_enemy_wrap_radius, local_rope, radial_speed, tangent_speed, chakram.yoyo_last_constraint_correction, yoyo_enemy_last_acceleration.length(), hit_age, chakram.yoyo_last_enemy_hit_incoming.length(), chakram.yoyo_last_enemy_hit_outgoing.length()]

func _tether_distance() -> float:
	if player == null:
		return 0.0
	if target_type == TargetType.CHAKRAM and is_instance_valid(target_node):
		return _yoyo_live_path_length(player.get_grapple_hand_position(), target_node.global_position)
	if target_type == TargetType.ENEMY and is_instance_valid(target_node):
		return player.get_grapple_hand_position().distance_to(target_node.global_position)
	return player.global_position.distance_to(anchor_position)

func _rope_points(hand_local: Vector2, end_local: Vector2, amplitude: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var axis: Vector2 = end_local - hand_local
	var normal: Vector2 = axis.normalized().orthogonal() if axis.length_squared() > 0.001 else Vector2.DOWN
	var phase: float = visual_time * 9.0
	for index: int in range(ROPE_SAMPLE_COUNT + 1):
		var t: float = float(index) / float(ROPE_SAMPLE_COUNT)
		var endpoint_fade: float = sin(PI * t)
		var slither: float = sin(TAU * t + phase) + sin(TAU * 2.0 * t - phase * 0.7) * 0.22
		points.append(hand_local.lerp(end_local, t) + normal * amplitude * endpoint_fade * slither)
	return points

func _enemy_wrap_rope_points(hand_local: Vector2, end_local: Vector2, amplitude: float) -> PackedVector2Array:
	var points: PackedVector2Array = _rope_points(hand_local, to_local(yoyo_enemy_entry_point), amplitude * 0.35)
	var enemy: Enemy = yoyo_wrap_object as Enemy
	if enemy == null:
		return points
	var center: Vector2 = _enemy_wrap_center(enemy)
	var entry_angle: float = (yoyo_enemy_entry_point - center).angle()
	var arc_segments: int = maxi(4, ceili(yoyo_enemy_arc_angle * yoyo_enemy_wrap_radius / 6.0))
	for index: int in range(1, arc_segments + 1):
		var ratio: float = float(index) / float(arc_segments)
		var angle: float = entry_angle + yoyo_enemy_wrap_sign * yoyo_enemy_arc_angle * ratio
		points.append(to_local(center + Vector2.RIGHT.rotated(angle) * yoyo_enemy_wrap_radius))
	var outer_points: PackedVector2Array = _rope_points(to_local(yoyo_enemy_exit_point), end_local, amplitude)
	for index: int in range(1, outer_points.size()):
		points.append(outer_points[index])
	return points

func _draw_hook_tip(tip: Vector2, direction: Vector2, outline: Color) -> void:
	var forward: Vector2 = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	if spear_tip_texture != null:
		draw_set_transform(tip - forward * 1.0, forward.angle(), Vector2.ONE * HOOK_TIP_VISUAL_SCALE)
		draw_texture_rect(spear_tip_texture, Rect2(-48.0, -32.0, 96.0, 64.0), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	# The visual is intentionally built around the gameplay CircleShape2D radius
	# (HOOK_TIP_RADIUS). The spear's farthest point is 14 px from the hit center,
	# so the silhouette never suggests a larger target than the actual query.
	var side: Vector2 = forward.orthogonal()
	# Compact side-on spear dart: its point sits at the edge of the existing
	# 13px query radius, while the socket/collar stays inside that same footprint.
	var spear_points: PackedVector2Array = PackedVector2Array([
		tip + forward * 13.0,
		tip - forward * 5.0 + side * 6.8,
		tip - forward * 7.5,
		tip - forward * 5.0 - side * 6.8,
	])
	var bevel_points: PackedVector2Array = PackedVector2Array([
		tip + forward * 10.8,
		tip - forward * 4.0 + side * 3.3,
		tip - forward * 6.2,
		tip - forward * 4.0 - side * 3.3,
	])
	var steel: Color = Color(0.78, 0.84, 0.84, 1.0)
	draw_colored_polygon(spear_points, steel)
	draw_colored_polygon(bevel_points, Color(0.42, 0.5, 0.51, 1.0))
	# Bright upper facet and dark lower facet give it the forged spearhead shape.
	draw_colored_polygon(PackedVector2Array([spear_points[0], spear_points[1], tip - forward * 6.0]), Color(0.98, 0.9, 0.68, 0.9))
	draw_colored_polygon(PackedVector2Array([spear_points[0], tip - forward * 6.0, spear_points[3]]), Color(0.3, 0.36, 0.38, 0.95))
	draw_polyline(PackedVector2Array([spear_points[0], spear_points[1], spear_points[2], spear_points[3], spear_points[0]]), outline, 1.5, true)
	# Bronze socket and a small cyan diamond rune sit behind the blade.
	draw_line(tip - forward * 6.0 + side * 7.0, tip - forward * 6.0 - side * 7.0, Color(0.54, 0.3, 0.1, 1.0), 3.0, true)
	draw_line(tip - forward * 7.2 + side * 5.8, tip - forward * 7.2 - side * 5.8, Color(0.9, 0.62, 0.22, 1.0), 1.2, true)
	var rune_center: Vector2 = tip - forward * 1.5
	var rune: PackedVector2Array = PackedVector2Array([rune_center + forward * 2.6, rune_center + side * 2.6, rune_center - forward * 2.6, rune_center - side * 2.6])
	draw_polyline(rune, Color(0.45, 0.95, 0.92, 0.92), 1.0, true)

func _draw_mobile_aim_preview() -> void:
	if player == null or not player.is_inside_tree() or not player.mobile_input_enabled or not player.mobile_grapple_aiming:
		return
	var hand_world: Vector2 = player.get_grapple_hand_position()
	var aim_end_world: Vector2 = player.get_mobile_grapple_aim_point()
	var preview_end_world: Vector2 = aim_end_world
	var status_text: String = "MAX RANGE"
	var guide_color: Color = Color(0.35, 0.95, 0.9, 0.92)
	# Use one ray for the live status indicator. The full hook-shape sweep remains
	# reserved for the actual shot so holding the button cannot spam dozens of
	# physics queries every frame on a phone.
	var ray_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(hand_world, aim_end_world, TARGET_MASK, [player.get_rid()])
	ray_query.collide_with_areas = true
	ray_query.collide_with_bodies = true
	var physics_hit: Dictionary = player.get_world_2d().direct_space_state.intersect_ray(ray_query)
	var hit_collider: Object = null
	if not physics_hit.is_empty():
		hit_collider = physics_hit.get("collider") as Object
	var hit_node: Node2D = hit_collider as Node2D
	var dynamic_target: Node2D = null
	if hit_node != null:
		dynamic_target = _resolve_target_owner(hit_node)
	if dynamic_target != null:
		preview_end_world = physics_hit["position"] as Vector2
		if dynamic_target.is_in_group("zungar"):
			status_text = "BLOCKED"
			guide_color = Color(1.0, 0.32, 0.24, 0.95)
		else:
			status_text = "TARGET"
			guide_color = Color(0.45, 1.0, 0.6, 0.95)
	else:
		var main_scene: Node = player.get_tree().current_scene
		if main_scene != null and main_scene.has_method("get_terrain_wall_collision"):
			var wall_hit: Dictionary = main_scene.call("get_terrain_wall_collision", hand_world, aim_end_world, 0.0) as Dictionary
			if not wall_hit.is_empty():
				preview_end_world = wall_hit["position"] as Vector2
				status_text = "WALL"
				guide_color = Color(1.0, 0.78, 0.28, 0.95)
	var hand_local: Vector2 = to_local(hand_world)
	var aim_end_local: Vector2 = to_local(preview_end_world)
	var guide_shadow: Color = Color(0.02, 0.08, 0.1, 0.86)
	draw_line(hand_local, aim_end_local, guide_shadow, 9.0, true)
	var segment_count: int = 12
	for segment_index: int in range(segment_count):
		var start_ratio: float = float(segment_index) / float(segment_count)
		var end_ratio: float = start_ratio + 0.58 / float(segment_count)
		draw_line(hand_local.lerp(aim_end_local, start_ratio), hand_local.lerp(aim_end_local, minf(end_ratio, 1.0)), guide_color, 3.0, true)
	draw_circle(aim_end_local, 18.0, Color(0.02, 0.08, 0.1, 0.78))
	draw_arc(aim_end_local, 14.0, 0.0, TAU, 24, guide_color, 3.0, true)
	draw_line(aim_end_local - Vector2(8.0, 0.0), aim_end_local + Vector2(8.0, 0.0), guide_color, 2.0, true)
	draw_line(aim_end_local - Vector2(0.0, 8.0), aim_end_local + Vector2(0.0, 8.0), guide_color, 2.0, true)
	draw_string(ThemeDB.fallback_font, aim_end_local + Vector2(12.0, -12.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, guide_color)

func _draw() -> void:
	if player == null:
		return
	if not active and not firing:
		_draw_mobile_aim_preview()
		return
	var hand_world: Vector2 = player.get_grapple_hand_position()
	var hand_local: Vector2 = to_local(hand_world)
	var end_world: Vector2 = hook_position if firing else anchor_position
	var end_local: Vector2 = to_local(end_world)
	var slack: float = hand_world.distance_to(end_world) if firing else maxf(0.0, rope_length - _tether_distance())
	var amplitude: float = rope_wave_amplitude(slack, tension_ratio, firing)
	var rope_points: PackedVector2Array
	if not firing and yoyo_wrap_active and target_type == TargetType.CHAKRAM:
		if is_instance_valid(yoyo_wrap_object) and yoyo_wrap_object is Enemy:
			rope_points = _enemy_wrap_rope_points(hand_local, end_local, amplitude)
		elif not yoyo_wrap_bounds.size.is_zero_approx():
			rope_points = _rope_points(hand_local, to_local(yoyo_rect_entry_point), amplitude * 0.35)
			var perimeter: float = yoyo_rect_perimeter_length(yoyo_wrap_bounds)
			var corners: Array[float] = [0.0, yoyo_wrap_bounds.size.x, yoyo_wrap_bounds.size.x + yoyo_wrap_bounds.size.y, 2.0 * yoyo_wrap_bounds.size.x + yoyo_wrap_bounds.size.y]
			var distances: Array[float] = []
			for turn: int in range(ceili(yoyo_rect_arc_length / perimeter) + 1):
				for corner: float in corners:
					var distance: float = yoyo_rect_directed_distance(yoyo_rect_entry_parameter, corner, yoyo_rect_wrap_sign, perimeter) + float(turn) * perimeter
					if distance > 0.001 and distance < yoyo_rect_arc_length:
						distances.append(distance)
			distances.sort()
			for distance: float in distances:
				rope_points.append(to_local(yoyo_rect_perimeter_point(yoyo_wrap_bounds, yoyo_rect_entry_parameter + yoyo_rect_wrap_sign * distance)))
			rope_points.append(to_local(yoyo_rect_exit_point))
			var outer_points: PackedVector2Array = _rope_points(to_local(yoyo_rect_exit_point), end_local, amplitude)
			for index: int in range(1, outer_points.size()):
				rope_points.append(outer_points[index])
		else:
			var wrap_local: Vector2 = to_local(yoyo_wrap_position)
			rope_points = _rope_points(hand_local, wrap_local, amplitude * 0.45)
			var outer_points: PackedVector2Array = _rope_points(wrap_local, end_local, amplitude)
			for index: int in range(1, outer_points.size()):
				rope_points.append(outer_points[index])
	else:
		rope_points = _rope_points(hand_local, end_local, amplitude)
	var rope_color: Color = Color(0.42, 0.24, 0.1, 1.0).lerp(Color(0.86, 0.66, 0.3, 1.0), tension_ratio)
	var shadow_points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in rope_points: shadow_points.append(point + Vector2(2.0, 3.0))
	draw_polyline(shadow_points, Color(0.03, 0.045, 0.03, 0.62), 4.0, true)
	draw_polyline(rope_points, Color(0.18, 0.09, 0.035, 1.0), 2.8, true)
	draw_polyline(rope_points, rope_color, 1.45, true)
	# Fine alternating braid marks stay inside the thin cord silhouette.
	for index: int in range(ROPE_SAMPLE_COUNT):
		if index % 2 != 0: continue
		var start: Vector2 = rope_points[index].lerp(rope_points[index + 1], 0.22)
		var finish: Vector2 = rope_points[index].lerp(rope_points[index + 1], 0.7)
		draw_line(start, finish, Color(1.0, 0.78, 0.38, 0.62), 0.55, true)
	var spear_origin: Vector2 = yoyo_wrap_position if not firing and yoyo_wrap_active and target_type == TargetType.CHAKRAM else hand_world
	var spear_direction: Vector2 = hook_direction if firing else spear_origin.direction_to(anchor_position)
	_draw_hook_tip(end_local, spear_direction, Color(0.16, 0.2, 0.24, 1.0))
