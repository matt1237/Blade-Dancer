extends Node

func test_windup_release_and_locomotion_use_bomb_clock() -> void:
	var world: Node2D = Node2D.new()
	var bomber: GoblinBomber = GoblinBomber.new()
	var player: Player = Player.new()
	world.add_child(bomber)
	bomber.player_ref = player
	bomber._configure_concrete_enemy()
	bomber._setup_hd_enemy_sprite()
	bomber.velocity = Vector2(95, 0)
	var bomb: BomberBomb = bomber._begin_bomb_attack()
	var sprite: AnimatedSprite2D = bomber.hd_enemy_sprite
	assert(sprite.animation == &"bomb_windup" and sprite.frame == 0)
	assert(not sprite.is_playing())
	assert(not sprite.sprite_frames.get_animation_loop("bomb_windup"))
	assert(not sprite.sprite_frames.get_animation_loop("bomb_throw"))
	bomb.advance_attack(0.25)
	assert(sprite.animation == &"bomb_windup" and sprite.frame == 1)
	bomb.advance_attack(0.249)
	assert(bomb.phase == BomberBomb.Phase.WARNING)
	assert(sprite.animation == &"bomb_windup" and sprite.frame == 2)
	bomber.position = Vector2(30, 20)
	bomb.advance_attack(0.001)
	assert(bomb.phase == BomberBomb.Phase.FLIGHT)
	# Signal updates the visual on the SAME advance as actual release.
	assert(sprite.animation == &"bomb_throw" and sprite.frame == 0)
	assert(bomb.launch_position == bomber.position)
	var target: Vector2 = bomb.locked_target
	bomber.position += Vector2(10, 10)
	player.position += Vector2(100, 100)
	bomb.advance_attack(0.30)
	assert(sprite.animation == &"bomb_throw" and sprite.frame == 2)
	assert(bomb.launch_position == Vector2(30, 20) and bomb.locked_target == target)
	bomb.advance_attack(0.15)
	assert(bomb.phase == BomberBomb.Phase.FUSE)
	assert(sprite.animation == &"move" and sprite.is_playing())
	bomber.velocity = Vector2.ZERO
	bomber._update_hd_enemy_sprite()
	assert(sprite.animation == &"idle" and sprite.is_playing())
	assert(bomber.fire_timer == 4.0 and bomber.attack_cooldown == 4.0)
	assert(sprite.scale.is_equal_approx(Vector2.ONE * 0.27))
	world.free()
	player.free()

func test_skip_and_owner_death_do_not_hold_or_cancel_attack() -> void:
	var world: Node2D = Node2D.new()
	var bomber: GoblinBomber = GoblinBomber.new()
	var player: Player = Player.new()
	world.add_child(bomber)
	bomber.player_ref = player
	bomber._setup_hd_enemy_sprite()
	bomber.velocity = Vector2(95, 0)
	var bomb: BomberBomb = bomber._begin_bomb_attack()
	bomb.advance_attack(BomberBomb.LAND_TIME + 0.1)
	assert(bomber.hd_enemy_sprite.animation == &"move")
	bomber.free()
	assert(is_instance_valid(bomb) and bomb.get_parent() == world)
	bomb.player = null
	bomb.advance_attack(BomberBomb.FUSE_TIME)
	assert(bomb.exploded)
	world.free()
	player.free()

func test_six_frame_atlas_scraps_removed_without_resizing() -> void:
	var bomber: GoblinBomber = GoblinBomber.new()
	bomber._setup_hd_enemy_sprite()
	var frames: SpriteFrames = bomber.hd_enemy_sprite.sprite_frames
	for animation_name: String in ["bomb_windup", "bomb_throw"]:
		assert(frames.get_frame_count(animation_name) == 3)
		for index: int in range(3):
			var texture: AtlasTexture = frames.get_frame_texture(animation_name, index) as AtlasTexture
			assert(texture.get_size() == Vector2(256, 256))
	var atlas: AtlasTexture = frames.get_frame_texture("bomb_throw", 0) as AtlasTexture
	var image: Image = atlas.atlas.get_image()
	assert(image.get_size() == Vector2i(1536, 256))
	for point: Vector2i in [Vector2i(199, 65), Vector2i(715, 240), Vector2i(970, 130), Vector2i(1080, 60), Vector2i(1333, 123)]:
		assert(image.get_pixelv(point).a == 0.0)
	bomber.free()
