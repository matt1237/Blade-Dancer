class_name HDEnemyEyesTest extends Node
const Anchors = preload("res://scripts/hd_enemy_eye_anchors.gd")
const Eyes = preload("res://scripts/hd_enemy_eyes.gd")
func test_count_and_bounds() -> void:
	assert(Anchors.FRAMES.size() == 10)
	var count: int = 0
	for key: String in Anchors.FRAMES:
		var path: String = "res://assets/generated/hd_enemy_%s" % key
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".metadata.json"))
		var image: Image = (load(path + ".png") as Texture2D).get_image()
		assert(Anchors.FRAMES[key].size() == int(meta.frame_count))
		for f in range(Anchors.FRAMES[key].size()):
			count += 1
			var region: Dictionary = meta.frame_regions[f]
			var points: Array = Anchors.FRAMES[key][f]
			assert(points.size() == (1 if key.begins_with("turkey") or (key == "blue_bug_fly" and f == 3) else 2))
			for p: Vector2 in points:
				assert(Rect2(0,0,region.w,region.h).has_point(p))
				assert(image.get_pixel(int(region.x+p.x), int(region.y+p.y)).a > 0.1, "%s %d %s" % [key,f,p])
				if key.begins_with("blue_bug"):
					assert(p.x >= 75 and p.y >= 70, "Must be head, not abdomen")
	assert(count == 36)

func test_frame_flip_transform_and_day() -> void:
	var parent: Node2D = Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(parent)
	parent.position = Vector2(80,110)
	parent.scale = Vector2(1.2,0.7)
	parent.rotation = 0.3
	var sprite: Sprite2D = Sprite2D.new()
	parent.add_child(sprite)
	sprite.texture = load("res://assets/generated/hd_enemy_turkey_idle.png")
	sprite.hframes = 4
	sprite.position = Vector2(7,-3)
	sprite.scale = Vector2(-0.4,0.6)
	sprite.rotation = -0.2
	sprite.offset = Vector2(3,5)
	var eyes: HDEnemyEyes = Eyes.new()
	eyes.source = sprite
	sprite.add_child(eyes)
	eyes.set_process(false)
	assert(eyes.z_index == 4001 and not eyes.z_as_relative)
	for f in range(4):
		sprite.frame = f
		for centered in [true,false]:
			sprite.centered = centered
			for h in [true,false]:
				for v in [true,false]:
					sprite.flip_h = h
					sprite.flip_v = v
					var result: Dictionary = Anchors.registration(sprite)
					assert(result.frame == f)
					var p: Vector2 = Anchors.FRAMES.turkey_idle[f][0]
					var expected: Vector2 = Vector2(128-p.x if h else p.x,128-p.y if v else p.y) + sprite.offset - (Vector2(64,64) if centered else Vector2.ZERO)
					assert(result.points[0].is_equal_approx(expected))
					assert(eyes.to_global(result.points[0]).is_equal_approx(sprite.to_global(expected)))
	eyes.present(0.0,true,true)
	assert(not eyes.visible)
	eyes.present(1.0,false,true)
	assert(not eyes.visible)
	eyes.present(1.0,true,false)
	assert(not eyes.visible)
	eyes.present(1.0,true,true)
	assert(eyes.visible == sprite.is_visible_in_tree())
	sprite.hide()
	eyes.present(1.0,true,true)
	assert(not eyes.visible)
	parent.free()

func test_animated_frames_use_atlas_region_not_animation_index() -> void:
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("move")
	for f: int in [2,0,1]:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = load("res://assets/generated/hd_enemy_warg_charge.png")
		atlas.region = Rect2(f*160,0,160,128)
		frames.add_frame("move",atlas)
	sprite.sprite_frames = frames
	sprite.animation = "move"
	for f in range(3):
		sprite.frame = f
		var result: Dictionary = Anchors.registration(sprite)
		assert(result.frame == [2,0,1][f])
		assert(result.points[0] == Anchors.FRAMES.warg_charge[[2,0,1][f]][0] - Vector2(80,64))
	sprite.free()
