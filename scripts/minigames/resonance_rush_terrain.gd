class_name ResonanceRushTerrain extends Node2D

## Resonance Rush — reusable, authored-style terrain chunk stitcher.
##
## The course is NOT arbitrary noise: it is a fixed macro-rhythm of named
## chunk types (rolling hill, downhill, ramps, mushroom bounce, gaps, safe
## landings...) each parameterized with a little randomized jitter for
## replay variety. Chunks are stitched end-to-end into one continuous ground
## height-field so the whole course always reads as
## drive -> launch -> aerial -> land, ascending overall from the forest
## floor into the mountains and neon sky.
##
## Ground is represented as a set of straight micro-segments (a height-field:
## one y per x) rather than a full physics collider. LandSail queries
## get_ground_info(x) every frame instead of colliding against a
## CollisionPolygon2D — this keeps slope/loop-swoop follow behavior smooth
## and predictable, and makes "gaps" trivial: a gap is just a stretch of x
## with no segment covering it.

## Authored macro-rhythm. Individual chunk shapes are parameterized (length,
## height, amplitude) with randomized jitter — not hand-authored noise, but
## not fully random structure either.
const CHUNK_SEQUENCE: Array[String] = [
	"rolling_hill", "rolling_hill", "downhill_speed", "uphill_ramp", "launch_ramp",
	"grapple_gap", "landing_platform", "mushroom_bounce", "rolling_hill", "uphill_ramp",
	"launch_ramp", "glide_gap", "landing_platform", "downhill_speed", "uphill_ramp",
	"launch_ramp", "ravine", "landing_platform", "swoop_launch", "rolling_hill",
	"uphill_ramp", "launch_ramp", "grapple_gap", "landing_platform",
]

@export_category("Course")
@export var terrain_seed: int = 1
@export var start_position: Vector2 = Vector2(200.0, 0.0)

@export_category("Decorations")
@export var mushroom_texture: Texture2D
@export var grapple_point_texture: Texture2D
@export var tree_prop_texture: Texture2D

@export_category("Ground Art")
## The ground is drawn as small textured quads (one per micro-segment) using
## these per-zone tileable strips, rather than a single flat-colored
## polygon — a flat fill reads as an ugly slab; the actual pixel art is
## what should be "masking" the driveable surface.
@export var ground_texture_forest: Texture2D
@export var ground_texture_mountains: Texture2D
@export var ground_texture_neon: Texture2D
@export var ground_fill_depth: float = 90.0

## Physics query data: {x0,y0,x1,y1,tangent,normal}. Scanned linearly each
## frame — the chunk count is small enough (a few hundred micro-segments)
## for this to be cheap at 60 fps.
var segments: Array[Dictionary] = []
## Same points grouped per solid chunk, kept separately for drawing.
var ground_polylines: Array[PackedVector2Array] = []
var gap_edges: Array[Vector2] = []
var mushroom_positions: Array[Vector2] = []
var grapple_point_positions: Array[Vector2] = []
var course_end_position: Vector2 = Vector2.ZERO
## Lowest point of any drawn ground, used as a "fell off the world" safety net.
var max_world_y: float = 0.0

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Builds the course. Call explicitly from the parent controller's _ready()
## (not from this node's own _ready()) so node ready-order never matters.
func generate_course() -> Vector2:
	rng.seed = terrain_seed
	segments.clear()
	ground_polylines.clear()
	gap_edges.clear()
	mushroom_positions.clear()
	grapple_point_positions.clear()
	for child in get_children():
		child.queue_free()
	var cursor: Vector2 = start_position
	max_world_y = start_position.y
	for chunk_name: String in CHUNK_SEQUENCE:
		var result: Dictionary = _build_chunk(chunk_name, cursor)
		if result.get("solid", false):
			var points: PackedVector2Array = result["points"]
			_append_segments(points)
			ground_polylines.append(points)
			for point: Vector2 in points:
				max_world_y = maxf(max_world_y, point.y)
		else:
			gap_edges.append(result["gap_start"])
			gap_edges.append(result["gap_end"])
		cursor = result["next_cursor"]
	course_end_position = cursor
	max_world_y += 700.0
	for spawn_position: Vector2 in mushroom_positions:
		_spawn_mushroom(spawn_position)
	for spawn_position: Vector2 in grapple_point_positions:
		_spawn_grapple_point(spawn_position)
	for points: PackedVector2Array in ground_polylines:
		_spawn_trees_along(points)
	queue_redraw()
	return start_position

## Ground height-field lookup. Returns has_ground=false inside gaps.
func get_ground_info(x: float) -> Dictionary:
	for segment: Dictionary in segments:
		if x >= segment["x0"] and x <= segment["x1"]:
			var t: float = (x - segment["x0"]) / maxf(0.001, segment["x1"] - segment["x0"])
			return {
				"has_ground": true,
				"y": lerpf(segment["y0"], segment["y1"], t),
				"tangent": segment["tangent"],
				"normal": segment["normal"],
			}
	return {"has_ground": false, "y": 0.0, "tangent": Vector2.RIGHT, "normal": Vector2.UP}

func _build_chunk(chunk_name: String, cursor: Vector2) -> Dictionary:
	match chunk_name:
		"rolling_hill": return _build_rolling_hill(cursor)
		"downhill_speed": return _build_downhill_speed(cursor)
		"uphill_ramp": return _build_uphill_ramp(cursor)
		"launch_ramp": return _build_launch_ramp(cursor)
		"mushroom_bounce": return _build_mushroom_bounce(cursor)
		"swoop_launch": return _build_swoop_launch(cursor)
		"ravine": return _build_ravine(cursor)
		"grapple_gap": return _build_grapple_gap(cursor)
		"glide_gap": return _build_glide_gap(cursor)
		"landing_platform": return _build_landing_platform(cursor)
		_: return {"points": PackedVector2Array(), "next_cursor": cursor, "solid": false, "gap_start": cursor, "gap_end": cursor}

## eased height-ramp helper. rise > 0 means climbing (world y decreases).
func _shaped_points(start: Vector2, length: float, rise: float, shape: String, subdivisions: int = 12) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(subdivisions + 1):
		var t: float = float(index) / float(subdivisions)
		var eased: float = t
		match shape:
			"ease_in": eased = t * t
			"ease_out": eased = 1.0 - (1.0 - t) * (1.0 - t)
			"smooth": eased = t * t * (3.0 - 2.0 * t)
		points.append(Vector2(start.x + length * t, start.y - rise * eased))
	return points

func _build_rolling_hill(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(520.0, 680.0)
	var bump_height: float = rng.randf_range(50.0, 95.0)
	var net_rise: float = rng.randf_range(-10.0, 25.0)
	var subdivisions: int = 16
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(subdivisions + 1):
		var t: float = float(index) / float(subdivisions)
		var bump: float = sin(t * PI) * bump_height
		points.append(Vector2(cursor.x + length * t, cursor.y - bump - net_rise * t))
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true}

func _build_downhill_speed(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(480.0, 640.0)
	var drop: float = rng.randf_range(140.0, 220.0)
	var points: PackedVector2Array = _shaped_points(cursor, length, -drop, "ease_out", 14)
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true}

func _build_uphill_ramp(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(420.0, 560.0)
	var rise: float = rng.randf_range(90.0, 170.0)
	var points: PackedVector2Array = _shaped_points(cursor, length, rise, "ease_in", 12)
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true}

func _build_launch_ramp(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(300.0, 380.0)
	var rise: float = rng.randf_range(130.0, 190.0)
	var points: PackedVector2Array = _shaped_points(cursor, length, rise, "ease_in", 10)
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true, "is_launch": true}

func _build_mushroom_bounce(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(260.0, 340.0)
	var points: PackedVector2Array = _shaped_points(cursor, length, rng.randf_range(-5.0, 15.0), "smooth", 8)
	mushroom_positions.append(points[floori(points.size() / 2.0)])
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true}

## Stand-in for a full vertical loop: a deep swoop dip immediately followed
## by a steep climb into a launch lip. Delivers the same "build energy in a
## curve, then launch" feeling without needing multi-valued (non-height-field)
## track geometry — a deliberate scope cut for this first-pass prototype.
func _build_swoop_launch(cursor: Vector2) -> Dictionary:
	var dip_length: float = rng.randf_range(280.0, 340.0)
	var dip_depth: float = rng.randf_range(120.0, 160.0)
	var climb_length: float = rng.randf_range(360.0, 440.0)
	var climb_rise: float = rng.randf_range(260.0, 320.0)
	var dip_points: PackedVector2Array = _shaped_points(cursor, dip_length, -dip_depth, "ease_in", 10)
	var climb_points: PackedVector2Array = _shaped_points(dip_points[dip_points.size() - 1], climb_length, climb_rise, "ease_in", 14)
	var combined: PackedVector2Array = dip_points.duplicate()
	for index: int in range(1, climb_points.size()):
		combined.append(climb_points[index])
	return {"points": combined, "next_cursor": combined[combined.size() - 1], "solid": true, "is_launch": true}

func _build_ravine(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(360.0, 480.0)
	var end_point: Vector2 = Vector2(cursor.x + length, cursor.y + rng.randf_range(20.0, 70.0))
	return {"points": PackedVector2Array(), "next_cursor": end_point, "solid": false, "gap_start": cursor, "gap_end": end_point}

func _build_grapple_gap(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(460.0, 640.0)
	var end_point: Vector2 = Vector2(cursor.x + length, cursor.y + rng.randf_range(0.0, 40.0))
	var anchor_height: float = rng.randf_range(150.0, 220.0)
	grapple_point_positions.append(Vector2((cursor.x + end_point.x) * 0.5, minf(cursor.y, end_point.y) - anchor_height))
	return {"points": PackedVector2Array(), "next_cursor": end_point, "solid": false, "gap_start": cursor, "gap_end": end_point}

func _build_glide_gap(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(700.0, 950.0)
	var end_point: Vector2 = Vector2(cursor.x + length, cursor.y + rng.randf_range(20.0, 90.0))
	return {"points": PackedVector2Array(), "next_cursor": end_point, "solid": false, "gap_start": cursor, "gap_end": end_point}

func _build_landing_platform(cursor: Vector2) -> Dictionary:
	var length: float = rng.randf_range(380.0, 480.0)
	var points: PackedVector2Array = PackedVector2Array([cursor, Vector2(cursor.x + length, cursor.y)])
	return {"points": points, "next_cursor": points[points.size() - 1], "solid": true, "is_safe": true}

func _append_segments(points: PackedVector2Array) -> void:
	for index: int in range(points.size() - 1):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var tangent: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(-tangent.y, tangent.x)
		if normal.y > 0.0:
			normal = -normal
		segments.append({"x0": a.x, "y0": a.y, "x1": b.x, "y1": b.y, "tangent": tangent, "normal": normal})

func _spawn_mushroom(spawn_position: Vector2) -> void:
	if mushroom_texture == null:
		return
	var area: Area2D = Area2D.new()
	area.name = "Mushroom"
	area.add_to_group("resonance_mushroom")
	area.collision_layer = 4
	area.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	area.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = mushroom_texture
	sprite.centered = true
	sprite.position = Vector2(0.0, -34.0)
	area.add_child(sprite)
	area.global_position = spawn_position
	add_child(area)

func _spawn_grapple_point(spawn_position: Vector2) -> void:
	if grapple_point_texture == null:
		return
	var node: Node2D = Node2D.new()
	node.name = "GrapplePoint"
	node.add_to_group("resonance_grapple_point")
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = grapple_point_texture
	sprite.centered = true
	node.add_child(sprite)
	node.global_position = spawn_position
	add_child(node)
	# A large finite loop count (rather than infinite) avoids Godot's Tween
	# "infinite loop detected" step warning while still pulsing effectively
	# forever for the length of a single prototype run.
	var tween: Tween = create_tween().set_loops(2000)
	tween.tween_property(sprite, "scale", Vector2(1.18, 1.18), 0.55)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.55)

func _spawn_trees_along(points: PackedVector2Array) -> void:
	if tree_prop_texture == null or points.size() < 2:
		return
	# Only decorate the low-altitude forest zone with foreground trees — this
	# is the actual "artwork instead of a flat slab" fix: real props sitting
	# ON the drivable ground, in front of the parallax, not a background poster.
	if start_position.y - points[0].y > 500.0:
		return
	var tree_count: int = rng.randi_range(0, 2)
	for _index: int in range(tree_count):
		var point: Vector2 = points[rng.randi_range(0, points.size() - 1)]
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = tree_prop_texture
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var scale_value: float = rng.randf_range(0.9, 1.4)
		sprite.scale = Vector2.ONE * scale_value
		sprite.position = point + Vector2(rng.randf_range(-30.0, 30.0), -48.0 * scale_value)
		sprite.z_index = -1
		add_child(sprite)

## Ground is drawn as small textured quads, one per micro-segment, so the
## actual pixel art forms the driveable surface instead of a flat color fill.
## Each quad stretches the SAME small tileable texture across its own short
## span, which reads as a repeating strip without needing texture-repeat
## wrap flags on the source image.
func _draw() -> void:
	for points: PackedVector2Array in ground_polylines:
		if points.size() < 2:
			continue
		var texture: Texture2D = _ground_texture_for_y(points[0].y)
		var color: Color = _zone_color_for_y(points[0].y)
		if texture != null:
			for index: int in range(points.size() - 1):
				var a: Vector2 = points[index]
				var b: Vector2 = points[index + 1]
				var quad: PackedVector2Array = PackedVector2Array([a, b, b + Vector2(0.0, ground_fill_depth), a + Vector2(0.0, ground_fill_depth)])
				var uvs: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
				draw_polygon(quad, PackedColorArray([Color.WHITE]), uvs, texture)
		# A darker solid mass beneath the textured strip gives the ground
		# real depth down to the safety-net line, without needing the
		# texture itself to stretch across an arbitrary distance.
		var fill_points: PackedVector2Array = PackedVector2Array(points)
		fill_points.append(Vector2(points[points.size() - 1].x, max_world_y))
		fill_points.append(Vector2(points[0].x, max_world_y))
		draw_colored_polygon(fill_points, Color(color.r * 0.28, color.g * 0.28, color.b * 0.28, 0.97))
		draw_polyline(points, color, 5.0, true)
	for index: int in range(0, gap_edges.size(), 2):
		draw_line(gap_edges[index], gap_edges[index] + Vector2(0.0, 44.0), Color(1.0, 0.85, 0.4, 0.85), 4.0)
		draw_line(gap_edges[index + 1], gap_edges[index + 1] + Vector2(0.0, 44.0), Color(1.0, 0.85, 0.4, 0.85), 4.0)

func _ground_texture_for_y(y: float) -> Texture2D:
	var climbed_px: float = start_position.y - y
	if climbed_px > 1400.0:
		return ground_texture_neon
	if climbed_px > 600.0:
		return ground_texture_mountains
	return ground_texture_forest

func _zone_color_for_y(y: float) -> Color:
	var climbed_px: float = start_position.y - y
	var mid_t: float = clampf(climbed_px / 600.0, 0.0, 1.0)
	var high_t: float = clampf((climbed_px - 600.0) / 800.0, 0.0, 1.0)
	var low_color: Color = Color("6fae52")
	var mid_color: Color = Color("6fc7d6")
	var high_color: Color = Color("d582e6")
	return low_color.lerp(mid_color, mid_t).lerp(high_color, high_t)
