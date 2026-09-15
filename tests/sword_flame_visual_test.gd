class_name SwordFlameVisualTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const FLAME_ATLAS_PATH: String = "res://assets/generated/hd_weapon_flame_symmetric_atlas.png"

func test_hd_flame_atlas_and_runtime_transparency_contract() -> void:
	assert(Player.SWORD_FLAME_ATLAS != null, "The shared illustrated sword-flame atlas must load.")
	assert(Player.SWORD_FLAME_ATLAS.get_size() == Vector2(1152.0, 192.0), "Flame atlas should contain six 192px frames in one row.")
	assert(Player.SWORD_FLAME_FRAME_COUNT == 6, "Sword fire needs all six illustrated flicker frames.")
	assert(Player.SWORD_FLAME_MAX_ALPHA > 0.0 and Player.SWORD_FLAME_MAX_ALPHA < 0.8, "Sword flames must remain visibly semi-transparent at runtime.")
	var atlas_texture: Texture2D = load(FLAME_ATLAS_PATH) as Texture2D
	var image: Image = atlas_texture.get_image()
	assert(image != null and not image.is_empty(), "The illustrated sword-flame atlas must be readable.")
	assert(image.detect_alpha() != Image.ALPHA_NONE, "The sword-flame atlas needs a real alpha channel.")
	assert(image.get_pixel(0, 0).a == 0.0 and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a == 0.0, "Flame atlas corners should stay transparent.")

func test_flame_poses_follow_every_registered_blade_profile() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	for sword_id: String in Player.BLADE_PROFILES.keys():
		player.set_equipped_sword(sword_id)
		player.blade_roll = 1.0
		var samples: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
		var poses: Array[Dictionary] = player._sword_flame_poses(samples)
		var path_length: float = player._blade_path_length(samples)
		assert(not poses.is_empty(), "%s should receive shared sword-flame poses." % sword_id)
		assert(float(poses[0]["path_distance"]) >= Player.SWORD_FLAME_HILT_INSET, "%s flames must begin beyond the hand and crossguard." % sword_id)
		assert(path_length - float(poses[-1]["path_distance"]) <= Player.SWORD_FLAME_SPACING, "%s flames should reach the blade tip." % sword_id)
		for pose: Dictionary in poses:
			assert((pose["position"] as Vector2).is_finite(), "%s produced an invalid flame position." % sword_id)
			assert(is_finite(float(pose["angle"])), "%s produced an invalid flame angle." % sword_id)
	player.queue_free()

func test_curved_weapon_flames_follow_the_curved_tip() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_equipped_sword("Basic Curved Sword")
	player.blade_roll = 1.0
	var samples: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
	var poses: Array[Dictionary] = player._sword_flame_poses(samples)
	var last_flame_position: Vector2 = poses[-1]["position"] as Vector2
	assert(last_flame_position.distance_to(samples[-1]) <= Player.SWORD_FLAME_SPACING, "Curved-sword fire should finish at its actual curved tip, not a straight fallback.")
	assert(not is_zero_approx(last_flame_position.y), "Curved-sword flame path should retain the profile's perpendicular offset.")
	player.queue_free()

func test_fire_renderer_pairs_both_blade_sides_and_animated_embers() -> void:
	var player_source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(player_source.contains("for side: float in [-1.0, 1.0]"), "Every profile-driven flame pose should render a matched pair on both blade sides.")
	assert(player_source.contains("side_rotation") and player_source.contains("tangent_angle + PI"), "The opposite flame tongue must be rotated away from the second blade edge.")
	assert(player_source.contains("ember_progress") and player_source.contains("draw_circle(ember_position"), "Sword fire should include moving semi-transparent ember particles.")
