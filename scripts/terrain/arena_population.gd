class_name ArenaPopulation extends Node2D

const ArenaObjectScript: Script = preload("res://scripts/terrain/arena_object.gd")
const TUNING_PATH: String = "user://arena_population_tuning.cfg"

@export var enabled: bool = true
@export var population_seed: int = 271828
@export var spawn_clearance: float = 105.0
@export_range(0.0, 1.0, 0.05) var farmable_density: float = 0.3
@export_range(0.0, 1.0, 0.05) var big_things_density: float = 0.75
@export var tutorial_farmable_respawn_seconds: float = 4.0

var tutorial_gathering_active: bool = false

var current_time_phase: String = "Noon"
var blocking_bounds: Array[Rect2] = []

func _ready() -> void:
	_load_tuning()
	z_as_relative = false
	z_index = 1
	if enabled:
		populate()

func _load_tuning() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(TUNING_PATH) != OK: return
	farmable_density = clampf(float(config.get_value("population", "farmable_density", farmable_density)), 0.0, 1.0)
	big_things_density = clampf(float(config.get_value("population", "big_things_density", big_things_density)), 0.0, 1.0)

func _save_tuning() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("population", "farmable_density", farmable_density)
	config.set_value("population", "big_things_density", big_things_density)
	config.save(TUNING_PATH)

func clear_population() -> void:
	_clear()
	visible = false

func populate() -> void:
	visible = enabled
	_clear()
	# These are authored sockets. Density only selects a prefix, so tuning never
	# turns into independent random scatter or changes the arena's identity.
	var big_positions: Array[Vector2] = [Vector2(210, 170), Vector2(300, 205), Vector2(1030, 165), Vector2(930, 520), Vector2(190, 535), Vector2(1080, 560), Vector2(1180, 300), Vector2(100, 430)]
	var big_kinds: Array[ArenaObject.ObjectKind] = [ArenaObject.ObjectKind.ROCK, ArenaObject.ObjectKind.ROCK, ArenaObject.ObjectKind.TREE, ArenaObject.ObjectKind.LOG, ArenaObject.ObjectKind.ROCK, ArenaObject.ObjectKind.TREE, ArenaObject.ObjectKind.TORCH, ArenaObject.ObjectKind.TORCH]
	var big_count: int = clampi(roundi(float(big_positions.size()) * big_things_density), 0, big_positions.size())
	for big_index: int in range(big_count):
		var big_size: Vector2 = Vector2(26.0, 38.0) if big_kinds[big_index] == ArenaObject.ObjectKind.TORCH else Vector2(112.0, 80.0)
		_add_object(big_kinds[big_index], big_positions[big_index], big_size, true, true, false)
	var herb_positions: Array[Vector2] = [Vector2(390, 130), Vector2(470, 585), Vector2(820, 135), Vector2(770, 575), Vector2(1110, 350), Vector2(140, 350), Vector2(360, 330), Vector2(910, 365), Vector2(260, 365), Vector2(1010, 380)]
	_add_farmable_set(ArenaObject.ObjectKind.HERB, herb_positions)
	var mushroom_positions: Array[Vector2] = [Vector2(330, 470), Vector2(560, 145), Vector2(715, 570), Vector2(890, 245), Vector2(1180, 430), Vector2(110, 210), Vector2(500, 250), Vector2(760, 430), Vector2(400, 420), Vector2(970, 250)]
	_add_farmable_set(ArenaObject.ObjectKind.MUSHROOM, mushroom_positions)
	var moon_flower_positions: Array[Vector2] = [Vector2(180, 270), Vector2(1070, 280), Vector2(260, 650), Vector2(1000, 650)]
	_add_farmable_set(ArenaObject.ObjectKind.MOON_FLOWER, moon_flower_positions)
	var shrub_positions: Array[Vector2] = [Vector2(110, 105), Vector2(420, 90), Vector2(860, 85), Vector2(1170, 115), Vector2(90, 620), Vector2(620, 650), Vector2(1190, 635), Vector2(520, 95), Vector2(740, 90), Vector2(1150, 520)]
	_add_farmable_set(ArenaObject.ObjectKind.SHRUB, shrub_positions)
	_set_time_phase_visibility()

func populate_tutorial_gathering() -> void:
	enabled = true
	visible = true
	tutorial_gathering_active = true
	_clear()
	# Keep the center lane readable while introducing the existing forest
	# harvestables. Herbs and mushrooms replenish until Grandma's quest ends.
	for entry: Dictionary in [
		{"kind": ArenaObject.ObjectKind.ROCK, "position": Vector2(220, 170), "size": Vector2(112, 80)},
		{"kind": ArenaObject.ObjectKind.TREE, "position": Vector2(1050, 170), "size": Vector2(112, 80)},
		{"kind": ArenaObject.ObjectKind.ROCK, "position": Vector2(1030, 560), "size": Vector2(112, 80)},
		{"kind": ArenaObject.ObjectKind.TREE, "position": Vector2(210, 555), "size": Vector2(112, 80)},
	]:
		_add_object(entry["kind"], entry["position"], entry["size"], true, true, false)
	for farmable_position: Vector2 in [Vector2(360, 150), Vector2(470, 570), Vector2(810, 145), Vector2(900, 555), Vector2(300, 360), Vector2(980, 350)]:
		_add_tutorial_respawning_farmable(ArenaObject.ObjectKind.HERB, farmable_position)
	for farmable_position: Vector2 in [Vector2(325, 475), Vector2(555, 155), Vector2(720, 560), Vector2(920, 245), Vector2(470, 275), Vector2(840, 430)]:
		_add_tutorial_respawning_farmable(ArenaObject.ObjectKind.MUSHROOM, farmable_position)
	for shrub_position: Vector2 in [Vector2(145, 320), Vector2(1120, 360), Vector2(620, 120), Vector2(620, 620)]:
		_add_object(ArenaObject.ObjectKind.SHRUB, shrub_position, Vector2.ZERO, false, false, true)

func stop_tutorial_gathering() -> void:
	tutorial_gathering_active = false

func _add_tutorial_respawning_farmable(kind: ArenaObject.ObjectKind, object_position: Vector2) -> void:
	var object: ArenaObject = _add_object(kind, object_position, Vector2.ZERO, false, false, true)
	object.object_broken.connect(_on_tutorial_farmable_broken.bind(kind, object_position))

func _on_tutorial_farmable_broken(_object: ArenaObject, kind: ArenaObject.ObjectKind, object_position: Vector2) -> void:
	if not tutorial_gathering_active:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(maxf(0.1, tutorial_farmable_respawn_seconds))
	await timer.timeout
	if tutorial_gathering_active and is_inside_tree():
		_add_tutorial_respawning_farmable(kind, object_position)

func _add_farmable_set(kind: ArenaObject.ObjectKind, positions: Array[Vector2]) -> void:
	var count: int = clampi(roundi(float(positions.size()) * farmable_density), 0, positions.size())
	for index: int in range(count):
		_add_object(kind, positions[index], Vector2.ZERO, false, false, true)

func set_farmable_density(value: float) -> void:
	farmable_density = clampf(value, 0.0, 1.0)
	_save_tuning()
	populate()

func set_big_things_density(value: float) -> void:
	big_things_density = clampf(value, 0.0, 1.0)
	_save_tuning()
	populate()

func set_time_phase(phase: String) -> void:
	current_time_phase = phase
	_set_time_phase_visibility()

func _set_time_phase_visibility() -> void:
	var moon_visible: bool = current_time_phase in ["Dusk", "Dusk v2", "Night", "Night v2"]
	for node: Node in get_tree().get_nodes_in_group("arena_objects"):
		var object: ArenaObject = node as ArenaObject
		if object != null and object.object_kind == ArenaObject.ObjectKind.MOON_FLOWER:
			object.set_phase_visible(moon_visible)


func _add_object(kind: ArenaObject.ObjectKind, object_position: Vector2, size: Vector2, blocks: bool, chakram_breakable: bool, sword_harvestable: bool) -> ArenaObject:
	var object: ArenaObject = ArenaObjectScript.new() as ArenaObject
	object.object_kind = kind
	object.position = object_position
	object.footprint_size = size if size != Vector2.ZERO else Vector2(24, 24)
	object.blocks_navigation = blocks
	object.chakram_breakable = chakram_breakable
	object.sword_harvestable = sword_harvestable
	object.max_health = 1.0 if sword_harvestable else 90.0
	add_child(object)
	if blocks:
		blocking_bounds.append(object.world_footprint())
	return object

func _clear() -> void:
	for child: Node in get_children():
		# Population can be cleared while sword/Chakram physics still holds a
		# collider reference. Queue deletion for the safe end-of-frame boundary.
		child.queue_free()
	blocking_bounds.clear()

func get_blocking_bounds() -> Array[Rect2]:
	var current_bounds: Array[Rect2] = []
	for node: Node in get_children():
		var object: ArenaObject = node as ArenaObject
		if object != null: current_bounds.append_array(object.world_blocking_rects())
	return current_bounds

func get_obstruction_hit(start: Vector2, end: Vector2, radius: float) -> Dictionary:
	for node: Node in get_tree().get_nodes_in_group("chakram_obstructions"):
		var object: ArenaObject = node as ArenaObject
		if object == null or object.broken or not object.is_visible_in_tree(): continue
		var collision_rect: Rect2 = object.world_collision_rect()
		if collision_rect.size.x <= 0.0 or collision_rect.size.y <= 0.0:
			continue
		if _distance_to_rect(start, end, collision_rect) <= radius:
			var contact: Vector2 = _segment_rect_entry(start, end, collision_rect.grow(radius))
			if contact == Vector2.INF:
				contact = _closest_point_on_segment(collision_rect.get_center(), start, end)
			return {"object": object, "position": contact}
	return {}

func _segment_rect_entry(start: Vector2, end: Vector2, rect: Rect2) -> Vector2:
	var motion: Vector2 = end - start
	var enter_time: float = 0.0
	var exit_time: float = 1.0
	for axis: int in range(2):
		var origin: float = start.x if axis == 0 else start.y
		var delta: float = motion.x if axis == 0 else motion.y
		var minimum: float = rect.position.x if axis == 0 else rect.position.y
		var maximum: float = rect.end.x if axis == 0 else rect.end.y
		if absf(delta) < 0.0001:
			if origin < minimum or origin > maximum:
				return Vector2.INF
			continue
		var first: float = (minimum - origin) / delta
		var second: float = (maximum - origin) / delta
		if first > second:
			var held: float = first
			first = second
			second = held
		enter_time = maxf(enter_time, first)
		exit_time = minf(exit_time, second)
		if enter_time > exit_time:
			return Vector2.INF
	if enter_time < 0.0 or enter_time > 1.0:
		return Vector2.INF
	return start + motion * enter_time

func _distance_to_rect(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var swept: Rect2 = Rect2(start, end - start).abs().grow(0.01)
	if rect.intersects(swept) or rect.has_point(start) or rect.has_point(end): return 0.0
	var best: float = INF
	for edge: PackedVector2Array in [PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)]), PackedVector2Array([Vector2(rect.end.x, rect.position.y), rect.end]), PackedVector2Array([rect.end, Vector2(rect.position.x, rect.end.y)]), PackedVector2Array([Vector2(rect.position.x, rect.end.y), rect.position])]:
		best = minf(best, _segment_distance(start, end, edge[0], edge[1]))
	return best

func _segment_distance(a: Vector2, b: Vector2, c: Vector2, _d: Vector2) -> float:
	var closest: Vector2 = a
	var length_squared: float = (b - a).length_squared()
	if length_squared > 0.001:
		closest = a + (b - a) * clampf((c - a).dot(b - a) / length_squared, 0.0, 1.0)
	return closest.distance_to(c)

func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var length_squared: float = (end - start).length_squared()
	if length_squared < 0.001: return start
	return start + (end - start) * clampf((point - start).dot(end - start) / length_squared, 0.0, 1.0)
