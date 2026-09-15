class_name HDEyeAtlasContractTest extends Node
## Protect the frame mapping used by the authored eye anchors.
## Visual registration review lives in hd_eye_art_review.tscn.
func test_rendered_frames_match_source_metadata() -> void:
	var scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]
	for scene: PackedScene in scenes:
		var enemy: Enemy = scene.instantiate() as Enemy
		enemy._configure_concrete_enemy()
		enemy._setup_hd_enemy_sprite()
		var frames: SpriteFrames = enemy.hd_enemy_sprite.sprite_frames
		for animation: StringName in [&"idle", &"move"]:
			var first: AtlasTexture = frames.get_frame_texture(animation, 0) as AtlasTexture
			assert(first != null)
			var path: String = first.atlas.resource_path.replace(".png", ".metadata.json")
			var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
			var regions: Array = metadata["frame_regions"] as Array
			assert(frames.get_frame_count(animation) == int(metadata["frame_count"]))
			assert(regions.size() == frames.get_frame_count(animation))
			for index: int in range(regions.size()):
				var texture: AtlasTexture = frames.get_frame_texture(animation, index) as AtlasTexture
				var region: Dictionary = regions[index] as Dictionary
				var expected: Rect2 = Rect2(float(region["x"]), float(region["y"]), float(region["w"]), float(region["h"]))
				assert(texture.region == expected, "Eye registration requires exact source frame regions: %s/%d" % [path, index])
				assert(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(expected))
		enemy.free()
