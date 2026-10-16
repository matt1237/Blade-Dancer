class_name BDOSCollisionSwordRig extends EnemySpawnRig
## Opt-in real-game bench. In-memory settings ONLY; never saves presets.
@export var use_saved_contact_features: bool = false
@export var probe_stagger: bool = false
var _probe_clock: float = 0.0
var _previous_points: PackedVector2Array = PackedVector2Array()
var _moving_blocked_ticks: int = 0
var _stagger_travel: float = 0.0
var _minimum_clearance: float = INF
var _maximum_reach_excess: float = 0.0
var _probe_player: Player = null
var _probe_enemy: Enemy = null
var _observed_ticks: int = 0
var _blocked_ticks: int = 0
var _mismatch_ticks: int = 0
var _unresolved_ticks: int = 0
var _stagger_ticks: int = 0
var _reported_unresolved: bool = false

func _ready() -> void:
	await super._ready()
	if _main == null:
		return
	_main.set_px_mode(false)
	_probe_player = _player()
	if _probe_player == null:
		return
	_probe_player.combat_contact_settings = _probe_player.combat_contact_settings.duplicate(true)
	_probe_player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	_probe_player.set_combat_contact_setting("collision_sword_enabled", 1.0)
	# Solver-only mode isolates geometry; the saved-features variant keeps the
	# live slot's metronome, Guard, Hilt Bash and Bind values and drives real input.
	if not use_saved_contact_features:
		_probe_player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
		_probe_player.set_combat_contact_setting("charged_guard_enabled", 0.0)
		_probe_player.set_combat_contact_setting("hilt_bash_enabled", 0.0)
	_probe_player.chakram_charges = 0
	_probe_player.sword_damage = 0.0
	_probe_player.health = _probe_player.max_health
	# Solver-cost instrumentation, gated to this bench only (never a global default).
	# The player prints a [BDOS SOLVER PERF] line every 60 solves with calls/total/
	# avg/max microseconds so a solver spike can be told apart from intended hitstop.
	_probe_player.collision_sword_perf_debug = true
	# Keep enemy hits from entering Player's early-return stagger path during this
	# solver-only bench. This is test-rig invulnerability, not a gameplay change.
	_probe_player.invulnerable = 1000000.0
	_probe_player.hit_stagger_left = 0.0
	var alive: Array[Enemy] = _alive_enemies()
	if not alive.is_empty():
		_probe_enemy = alive[0]
		_probe_enemy.set_physics_process(false)
		_probe_player.set_input_mode(Player.INPUT_MODE_CONTROLLER)
		_probe_player.controller_aim_direction = _probe_player.global_position.direction_to(_probe_enemy.global_position)
		print("[BDOS BENCH] fixed target=%s; player aim driven at target" % str(_probe_enemy.spawn_identity))
	print("[BDOS BENCH] ON; saved_features=%s stagger_probe=%s; actual body shape; no PX, no saves" % [use_saved_contact_features, probe_stagger])
	print("[BDOS BENCH] preset=%d hand=%.1f..%.1f bind_retention=%.2f bind_speed=%.2f metronome=%.0f guard=%.0f bash=%.0f" % [_probe_player.combat_contact_preset, _probe_player.get_combat_hand_setting("min"), _probe_player.get_combat_hand_setting("max"), _probe_player.get_combat_hand_setting("bind_retention_strength"), _probe_player.get_combat_hand_setting("bind_sword_speed"), _probe_player.get_combat_contact_setting("authored_metronome_enabled"), _probe_player.get_combat_contact_setting("charged_guard_enabled"), _probe_player.get_combat_contact_setting("hilt_bash_enabled")])

func _process(delta: float) -> void:
	super._process(delta)
	if _probe_player == null:
		return
	_probe_clock += delta
	if use_saved_contact_features:
		# A full-strength right stick sweeps back and forth; the real aim/energy
		# path sees these events. No writes to authored energy, pose or timers.
		var aim: Vector2 = Vector2.from_angle(0.9 * sin(_probe_clock * 12.0))
		for axis: int in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
			var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			event.device = _probe_player.preferred_controller_device
			event.axis = axis as JoyAxis
			event.axis_value = aim.x if axis == JOY_AXIS_RIGHT_X else aim.y
			Input.parse_input_event(event)
	if probe_stagger and _observed_ticks == 120:
		_probe_player.invulnerable = 0.0
		_probe_player.take_damage(1.0, Vector2(-200, 0), _probe_enemy)
		print("[BDOS BENCH] real take_damage stagger injected hp=%.1f" % _probe_player.health)
	if _probe_player.hit_stagger_left > 0.0:
		_stagger_ticks += 1
	if _probe_player.collision_sword_solver == null:
		return
	var solver: BDOSSwordSolver = _probe_player.collision_sword_solver
	_observed_ticks += 1
	var points: PackedVector2Array = solver.world_points()
	if points.size() == _previous_points.size() and points.size() > 0:
		var travel: float = 0.0
		for index: int in range(points.size()):
			travel = maxf(travel, points[index].distance_to(_previous_points[index]))
		if solver.blocked and travel > 0.01:
			_moving_blocked_ticks += 1
		if _probe_player.hit_stagger_left > 0.0:
			_stagger_travel += points[0].distance_to(_previous_points[0])
	_previous_points = points
	var reach: float = maxf(_probe_player.get_combat_hand_setting("min"), _probe_player.get_combat_hand_setting("max"))
	_maximum_reach_excess = maxf(_maximum_reach_excess, solver.hilt.distance_to(_probe_player.global_position) - reach)
	if is_instance_valid(_probe_enemy):
		var shape_node: CollisionShape2D = _probe_enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D:
			var body: Dictionary = BDOSSwordSolver.circle_obstacle(_probe_enemy.get_instance_id(), "body", shape_node.shape as CircleShape2D, _probe_player._enemy_body_shape_transform(shape_node))
			for index: int in range(points.size() - 1):
				var closest: Vector2 = BDOSSwordSolver.closest_on_segment(body["start"], points[index], points[index + 1])
				_minimum_clearance = minf(_minimum_clearance, closest.distance_to(body["start"]) - float(body["radius"]) - BDOSSwordSolver.GEOMETRY_RADIUS)
	if solver.blocked:
		_blocked_ticks += 1
		if _blocked_ticks == 1:
			print("[BDOS BENCH] first real resolved block contacts=%s" % str(solver.contacts))
	if solver.unresolved_overlap or solver.unresolved_reach:
		_unresolved_ticks += 1
		if not _reported_unresolved:
			_reported_unresolved = true
			_report_unresolved_geometry(solver)
	var visible_pose: Dictionary = _probe_player._sword_transform()
	var expected_anchor: Vector2 = solver.hilt + Vector2.from_angle(solver.angle) * Player.BLADE_HILT_INSET
	if (visible_pose["start"] as Vector2).distance_to(expected_anchor) > 0.001 or _probe_player.current_blade_samples != solver.world_points():
		_mismatch_ticks += 1
	if _observed_ticks % 60 == 0:
		print("[BDOS BENCH] observations=%d blocked=%d moving_blocked=%d geometry_mismatch=%d unresolved=%d min_clearance=%.4f max_reach_excess=%.4f stagger_ticks=%d stagger_hilt_travel=%.3f" % [_observed_ticks, _blocked_ticks, _moving_blocked_ticks, _mismatch_ticks, _unresolved_ticks, _minimum_clearance, _maximum_reach_excess, _stagger_ticks, _stagger_travel])

func _report_unresolved_geometry(solver: BDOSSwordSolver) -> void:
	if _probe_player == null or _probe_enemy == null:
		return
	var shape_node: CollisionShape2D = _probe_enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or not shape_node.shape is CircleShape2D:
		return
	var circle: CircleShape2D = shape_node.shape as CircleShape2D
	var points: PackedVector2Array = solver.world_points()
	var minimum_clearance: float = INF
	for index: int in range(points.size() - 1):
		var closest: Vector2 = BDOSSwordSolver.closest_on_segment(shape_node.global_position, points[index], points[index + 1])
		minimum_clearance = minf(minimum_clearance, closest.distance_to(shape_node.global_position) - circle.radius - BDOSSwordSolver.GEOMETRY_RADIUS)
	var intent: Dictionary = _probe_player._sword_intent_transform()
	var target_angle: float = float(intent["angle"])
	var target_hilt: Vector2 = (intent["start"] as Vector2) - Vector2.from_angle(target_angle) * Player.BLADE_HILT_INSET
	var reach: float = maxf(_probe_player.get_combat_hand_setting("min"), _probe_player.get_combat_hand_setting("max"))
	print("[BDOS BENCH] first unresolved overlap=%s reach=%s min_actual_shape_clearance=%.3f hilt_to_player=%.3f max_reach=%.3f preferred_reach=%.3f" % [str(solver.unresolved_overlap), str(solver.unresolved_reach), minimum_clearance, solver.hilt.distance_to(_probe_player.global_position), reach, target_hilt.distance_to(_probe_player.global_position)])
