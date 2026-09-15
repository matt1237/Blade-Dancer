class_name GrappleEnemyWrapTest extends Node

func test_enemy_segment_hit_requires_crossing_and_returns_closest_contact() -> void:
	var hit: Vector2 = GrappleController.yoyo_enemy_segment_hit(Vector2(-100.0, 0.0), Vector2(100.0, 0.0), Vector2.ZERO, 14.0)
	assert(is_equal_approx(hit.x, 0.0) and is_equal_approx(hit.y, 0.0), "A crossing rope must report its closest collision contact.")
	var miss: Vector2 = GrappleController.yoyo_enemy_segment_hit(Vector2(-100.0, 30.0), Vector2(100.0, 30.0), Vector2.ZERO, 14.0)
	assert(miss == Vector2.INF, "A rope outside the collision radius must not create a wrap.")

func test_enemy_wrap_boundary_is_surface_not_center() -> void:
	var entry: Vector2 = GrappleController.yoyo_circle_tangent(Vector2.ZERO, Vector2(-100.0, 0.0), 14.0, 1.0)
	var exit: Vector2 = GrappleController.yoyo_circle_tangent(Vector2.ZERO, Vector2(100.0, 0.0), 14.0, -1.0)
	assert(is_equal_approx(entry.length(), 14.0), "Entry contact must remain on the collision boundary.")
	assert(is_equal_approx(exit.length(), 14.0), "Exit contact must remain on the collision boundary.")
	assert(absf((Vector2(-100.0, 0.0) - entry).dot(entry.normalized())) < 0.01, "Entry rope segment must be tangent to the collision circle.")
	assert(absf((Vector2(100.0, 0.0) - exit).dot(exit.normalized())) < 0.01, "Exit rope segment must be tangent to the collision circle.")

func test_wrap_acquisition_selects_short_contact_arc() -> void:
	var center: Vector2 = Vector2.ZERO
	var hand: Vector2 = Vector2(-100.0, 0.0)
	var chakram: Vector2 = Vector2(100.0, 5.0)
	var sign: float = GrappleController.yoyo_shortest_wrap_sign(center, hand, chakram, 14.0)
	var entry: Vector2 = GrappleController.yoyo_circle_tangent(center, hand, 14.0, sign)
	var exit: Vector2 = GrappleController.yoyo_circle_tangent(center, chakram, 14.0, -sign)
	var arc: float = GrappleController.yoyo_directed_arc(entry.angle(), exit.angle(), sign)
	assert(arc <= PI, "First contact must select the short physical arc, never fake a near-complete coil.")

func test_signed_winding_accumulates_and_reverse_travel_unwinds() -> void:
	var wound: float = GrappleController.yoyo_accumulated_arc(0.5, 0.5, 0.0, 0.0, 0.0, 0.4, 1.0)
	assert(is_equal_approx(wound, 0.9), "Forward tangential travel must accumulate collision-boundary rope.")
	var unwound: float = GrappleController.yoyo_accumulated_arc(wound, 0.5, 0.0, 0.0, 0.4, 0.1, 1.0)
	assert(is_equal_approx(unwound, 0.6), "Reverse tangential travel must unwind the accumulated coil.")
	var clamped: float = GrappleController.yoyo_accumulated_arc(unwound, 0.5, 0.0, 0.0, 0.1, -1.0, 1.0)
	assert(is_equal_approx(clamped, 0.5), "Unwinding cannot consume less than the live tangent-to-tangent contact arc.")

func test_enemy_collision_circle_uses_live_shape_offset_and_scale() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.position = Vector2(40.0, 50.0)
	var collision: CollisionShape2D = enemy.get_node("CollisionShape2D") as CollisionShape2D
	collision.position = Vector2(3.0, -4.0)
	collision.scale = Vector2(2.0, 1.0)
	var boundary: Dictionary = GrappleController.enemy_collision_circle(enemy)
	assert((boundary.get("center") as Vector2).is_equal_approx(Vector2(43.0, 46.0)), "CollisionShape2D offset must define the wrap center.")
	assert(is_equal_approx(boundary.get("radius") as float, 28.0), "Live collision scale must define the wrap radius.")
	enemy.free()

func test_rectangle_boundary_adapter_tracks_perimeter_not_corner_hinge() -> void:
	var bounds: Rect2 = Rect2(-40.0, -20.0, 80.0, 40.0)
	var top_right: Vector2 = GrappleController.yoyo_rect_perimeter_point(bounds, 100.0)
	assert(top_right.is_equal_approx(Vector2(40.0, 0.0)), "Rectangle boundary distance must advance around the live perimeter.")
	var bottom_left: Vector2 = GrappleController.yoyo_rect_perimeter_point(bounds, 200.0)
	assert(bottom_left.is_equal_approx(Vector2(-40.0, 20.0)), "Rectangle boundary adapter must preserve corners as perimeter transitions, not hinges.")
	var surface: Vector2 = GrappleController.yoyo_rect_surface_point(bounds, Vector2(0.0, 0.0))
	assert(surface.is_equal_approx(Vector2(0.0, -20.0)), "An interior contact must resolve to the nearest real rectangle surface.")
	var entry_parameter: float = GrappleController.yoyo_rect_perimeter_parameter(bounds, Vector2(0.0, -20.0))
	var exit_parameter: float = GrappleController.yoyo_rect_perimeter_parameter(bounds, Vector2(40.0, 0.0))
	assert(is_equal_approx(GrappleController.yoyo_rect_directed_distance(entry_parameter, exit_parameter, 1.0, 240.0), 60.0), "Rectangle winding must consume actual boundary distance.")

func test_terrain_segment_acquires_first_boundary_contact() -> void:
	var population: ArenaPopulation = ArenaPopulation.new()
	var contact: Vector2 = population._segment_rect_entry(Vector2(-100.0, 0.0), Vector2(100.0, 0.0), Rect2(-40.0, -20.0, 80.0, 40.0))
	assert(contact.is_equal_approx(Vector2(-40.0, 0.0)), "Terrain acquisition must retain the incoming boundary contact, not the rectangle center.")
	population.free()

func test_terrain_wrap_source_uses_active_collision_shape() -> void:
	var object: ArenaObject = ArenaObject.new()
	object.blocks_navigation = true
	object.footprint_size = Vector2(90.0, 54.0)
	object.position = Vector2(120.0, 80.0)
	add_child(object)
	var collision_rect: Rect2 = object.world_collision_rect()
	assert(collision_rect.size.is_equal_approx(Vector2(90.0, 54.0)), "Terrain wrap geometry must come from the active collision shape.")
	assert(collision_rect.get_center().is_equal_approx(Vector2(120.0, 80.0)), "Terrain wrap geometry must remain attached to the live body.")
	object.free()

func test_unsupported_enemy_shape_refuses_wrap_geometry() -> void:
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	add_child(enemy)
	var collision: CollisionShape2D = enemy.get_node("CollisionShape2D") as CollisionShape2D
	collision.shape = RectangleShape2D.new()
	var boundary: Dictionary = GrappleController.enemy_collision_circle(enemy)
	assert(not bool(boundary.get("supported", true)), "Unsupported enemy shapes must refuse wrap acquisition instead of using a guessed radius.")
	enemy.free()

func test_chakram_sweep_uses_combined_shape_boundaries() -> void:
	assert(Chakram.swept_circle_contact(Vector2(-100.0, 30.0), Vector2(100.0, 30.0), Vector2.ZERO, 34.0), "A Chakram sweep must include both projectile and enemy collision radii.")
	assert(not Chakram.swept_circle_contact(Vector2(-100.0, 35.0), Vector2(100.0, 35.0), Vector2.ZERO, 34.0), "A sweep outside the combined live boundary must miss.")

func test_completed_coil_reeling_consumes_boundary_arc_and_can_exit() -> void:
	var completed_arc: float = TAU + 0.4
	var one_frame: float = GrappleController.yoyo_reeling_arc(completed_arc, 120.0, 0.1, 20.0)
	assert(is_equal_approx(one_frame, completed_arc - 0.6), "Reeling must consume recovered rope from the traced enemy boundary arc.")
	var exited: float = GrappleController.yoyo_reeling_arc(0.2, 145.0, 1.0, 20.0)
	assert(is_zero_approx(exited), "A completed coil must be able to unwind fully instead of remaining at its tangent minimum.")
	var stable: float = GrappleController.yoyo_reeling_arc(0.2, 145.0, 0.0, 20.0)
	assert(is_equal_approx(stable, 0.2), "A zero-length reel step must not alter the physical wrap history.")

func test_enemy_wrap_arc_consumes_rope_and_tension_never_doubles_authority() -> void:
	var quarter_arc: float = GrappleController.yoyo_directed_arc(0.0, PI * 0.5, 1.0)
	assert(is_equal_approx(quarter_arc * 14.0, PI * 7.0), "A quarter wrap must consume radius times winding angle of rope.")
	var slack: Vector2 = GrappleController.yoyo_enemy_wrap_acceleration(Vector2.LEFT, Vector2.RIGHT, 0.0, 8.0, 1150.0, 1.0)
	assert(slack == Vector2.ZERO, "A wrapped enemy must receive no rope acceleration while the path is slack.")
	var aligned: Vector2 = GrappleController.yoyo_enemy_wrap_acceleration(Vector2.RIGHT, Vector2.RIGHT, 8.0, 8.0, 1150.0, 1.0)
	assert(is_equal_approx(aligned.length(), 1150.0), "Two aligned rope legs must share, never double, the canonical enemy force.")
	var opposed: Vector2 = GrappleController.yoyo_enemy_wrap_acceleration(Vector2.LEFT, Vector2.RIGHT, 8.0, 8.0, 1150.0, 1.0)
	assert(opposed.length() < 0.001, "Opposing rope legs must physically cancel at the wrapped body.")
