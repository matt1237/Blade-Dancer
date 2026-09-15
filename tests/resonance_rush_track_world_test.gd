class_name ResonanceRushTrackWorldTest extends Node

const PROOF_SCENE: PackedScene = preload("res://scenes/minigames/resonance_rush/rush_track_world_proof.tscn")

func _make_world() -> Dictionary:
	var world: Node2D = PROOF_SCENE.instantiate() as Node2D
	add_child(world)
	var terrain: ResonanceRushTrackWorld = world.get_node("TerrainRoot") as ResonanceRushTrackWorld
	terrain.generate_course()
	return {"world": world, "terrain": terrain}

func test_world_has_four_independent_tracks_with_correct_bounds() -> void:
	var built: Dictionary = _make_world()
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	assert(terrain.tracks.size() == 4)
	assert(terrain.start_position.is_equal_approx(Vector2(200.0, 600.0)))
	assert(terrain.course_end_position.is_equal_approx(Vector2(4200.0, 570.0)))
	built["world"].free()

func test_forced_connection_routes_through_the_loop_not_around_it() -> void:
	# The road-before, the loop's own start, and the road-after all sit at the
	# exact same coordinate — proximity alone cannot disambiguate that
	# 3-way junction, which is exactly why forced_next_chunk exists.
	var built: Dictionary = _make_world()
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	var pose: Dictionary = terrain.get_start_contact()
	var track_id: int = pose["track_id"]
	var progress: float = pose["progress"]
	var visited: Array[int] = []
	for _step: int in 200:
		var advanced: Dictionary = terrain.advance_contact(track_id, progress, 40.0)
		if advanced.get("detached", true):
			break
		track_id = advanced["track_id"]
		progress = advanced["progress"]
		if not visited.has(track_id):
			visited.append(track_id)
	assert(visited == [0, 1, 2], "Expected ForestRoadA(0) -> Loop(1) -> ForestRoadB(2), got %s" % [visited])
	built["world"].free()

func test_landing_selects_stacked_surface_correctly() -> void:
	var built: Dictionary = _make_world()
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	var world: Node2D = built["world"]
	var mountain_chunk: ResonanceRushChunk = world.get_node("TerrainRoot/MountainPlatform")
	var forest_b_chunk: ResonanceRushChunk = world.get_node("TerrainRoot/ForestRoadB")
	var mountain_track_id: int = -1
	var forest_b_track_id: int = -1
	for track: ResonanceRushTrackWorld.TrackData in terrain.tracks:
		if track.chunk == mountain_chunk:
			mountain_track_id = track.track_id
		elif track.chunk == forest_b_chunk:
			forest_b_track_id = track.track_id

	# Falling where the mountain platform exists must land on the mountain,
	# not fall through to the forest road at the same X below it.
	var mountain_mid: Vector2 = mountain_chunk.to_global(Vector2(500.0, 10.0))
	var landing_on_mountain: Dictionary = terrain.find_landing(mountain_mid + Vector2(0.0, -200.0), mountain_mid + Vector2(0.0, 5.0), Vector2(0.0, 500.0), 18.0)
	assert(landing_on_mountain.get("track_id") == mountain_track_id)

	# Falling past the mountain's right edge must land on the forest road.
	var nearest: Dictionary = terrain.find_nearest_contact(Vector2(3900.0, 600.0), 400.0)
	var above: Vector2 = Vector2(3900.0, nearest["position"].y - 500.0)
	var current: Vector2 = Vector2(3900.0, nearest["position"].y + 5.0)
	var landing_on_road: Dictionary = terrain.find_landing(above, current, Vector2(0.0, 500.0), 18.0)
	assert(landing_on_road.get("track_id") == forest_b_track_id)
	world.free()

func test_land_sail_rides_the_full_course_in_track_mode() -> void:
	var built: Dictionary = _make_world()
	var world: Node2D = built["world"]
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	var sail: ResonanceRushLandSail = world.get_node("LandSail") as ResonanceRushLandSail
	sail.terrain = terrain
	sail.begin_at(terrain.start_position)
	assert(sail.track_mode)
	var visited_loop: bool = false
	var visited_road_b: bool = false
	for _step: int in 900:
		sail.ground_speed = minf(sail.ground_speed + 900.0 / 60.0, 640.0 * 1.35)
		sail._physics_process(1.0 / 60.0)
		if sail.track_mode and sail.current_track_id == 1:
			visited_loop = true
		if sail.track_mode and sail.current_track_id == 2:
			visited_road_b = true
	assert(visited_loop, "Land Sail should have ridden across the loop track")
	assert(visited_road_b, "Land Sail should have continued onto ForestRoadB after the loop")
	world.free()

## Regression: track-mode slope physics use real energy conservation
## (½v² + g·h = const), not an instantaneous sin(angle) approximation that
## silently drains speed on a tightly curved track. With continuous throttle
## held the whole way, exit speed from the loop should be close to entry
## speed (it can end slightly higher since throttle keeps adding energy),
## never a fraction of it, and it must never go non-finite even when a loop
## is entered too slowly to complete.
func test_loop_conserves_energy_instead_of_bleeding_speed() -> void:
	var built: Dictionary = _make_world()
	var world: Node2D = built["world"]
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	var sail: ResonanceRushLandSail = world.get_node("LandSail") as ResonanceRushLandSail
	sail.terrain = terrain
	sail.begin_at(terrain.start_position)
	var entered_loop: bool = false
	var speed_entering_loop: float = 0.0
	var speed_after_loop: float = 0.0
	for _step: int in 700:
		sail.ground_speed = minf(sail.ground_speed + 900.0 / 60.0, 640.0 * 1.35)
		sail._physics_process(1.0 / 60.0)
		assert(is_finite(sail.ground_speed) and is_finite(sail.global_position.x) and is_finite(sail.global_position.y))
		if sail.current_track_id == 1 and not entered_loop:
			entered_loop = true
			speed_entering_loop = absf(sail.ground_speed)
		elif entered_loop and speed_after_loop == 0.0 and sail.current_track_id == 2:
			speed_after_loop = absf(sail.ground_speed)
	assert(entered_loop)
	assert(speed_after_loop > speed_entering_loop * 0.85, "Loop should not net-drain speed under continuous throttle (entered %.0f, exited %.0f)" % [speed_entering_loop, speed_after_loop])
	world.free()

## Regression: entering the loop too slowly with no further input must
## decelerate safely (never NaN/garbage from the energy-conservation sqrt).
func test_low_speed_loop_entry_stays_finite() -> void:
	var built: Dictionary = _make_world()
	var world: Node2D = built["world"]
	var terrain: ResonanceRushTrackWorld = built["terrain"]
	var sail: ResonanceRushLandSail = world.get_node("LandSail") as ResonanceRushLandSail
	sail.terrain = terrain
	sail.begin_at(terrain.start_position)
	sail.ground_speed = 300.0
	for _step: int in 400:
		sail._physics_process(1.0 / 60.0)
		assert(is_finite(sail.ground_speed) and is_finite(sail.global_position.x) and is_finite(sail.global_position.y))
	world.free()
