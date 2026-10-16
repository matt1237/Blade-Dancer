class_name ShamanStaffSpiralTest extends Node

func test_cast_spiral_rise_flip_transform_release_and_reset() -> void:
	var world: Node2D = Node2D.new()
	var shaman: GoblinShaman = WaveSpawner.GOBLIN_SHAMAN_SCENE.instantiate() as GoblinShaman
	world.add_child(shaman)
	shaman._configure_concrete_enemy()
	shaman._setup_hd_enemy_sprite()
	var ally: Enemy = Enemy.new()
	ally.spawn_identity = &"ogre"
	ally.max_health = 100.0
	ally.health = 20.0
	var player: Player = Player.new()
	player.position.x = 100.0
	shaman.player_ref = player
	assert(shaman.cast_duration == 0.6 and shaman.healing_cooldown == 5.0)
	assert(not shaman.staff_spiral.visible)
	assert(shaman.begin_cast(ally))
	assert(shaman.staff_spiral.visible and shaman.staff_spiral.frame == 0)
	assert(shaman.staff_spiral.position == GoblinShaman.STAFF_BASE)
	shaman.advance_cast(0.3)
	shaman._update_hd_enemy_sprite()
	assert(shaman.staff_spiral.frame == 4)
	assert(shaman.staff_spiral.position.is_equal_approx(GoblinShaman.STAFF_BASE.lerp(GoblinShaman.STAFF_CRYSTAL, 0.5)))
	player.position.x = -100.0
	shaman.rotation = 0.3
	shaman._update_hd_enemy_sprite()
	assert(shaman.staff_spiral.flip_h)
	assert(shaman.staff_spiral.position.x == -GoblinShaman.STAFF_BASE.x)
	assert(shaman.staff_spiral.global_position.is_equal_approx(shaman.hd_enemy_sprite.to_global(shaman.staff_spiral.position)))
	assert(ally.health == 20.0 and world.get_child_count() == 1)
	shaman.advance_cast(0.3)
	assert(not shaman.casting and world.get_child_count() == 2)
	assert(shaman.staff_spiral.frame == 7 and shaman.staff_spiral.visible)
	assert(shaman.staff_spiral.position.y == GoblinShaman.STAFF_CRYSTAL.y)
	assert(ally.health == 20.0) # Still launch-only; healing belongs to orb arrival.
	shaman.cast_completion_flash_left = 0.0
	shaman._update_hd_enemy_sprite()
	assert(not shaman.staff_spiral.visible)
	shaman.fire_timer = 0.0
	assert(shaman.begin_cast(ally))
	assert(shaman.staff_spiral.frame == 0 and shaman.staff_spiral.position.y == GoblinShaman.STAFF_BASE.y)
	shaman.interrupt_cast()
	assert(not shaman.staff_spiral.visible and shaman.cast_elapsed == 0.0)
	shaman.fire_timer = 0.0
	assert(shaman.begin_cast(ally))
	shaman.death_emitted = true
	shaman.advance_cast(0.1)
	assert(not shaman.staff_spiral.visible and not shaman.casting)
	world.free()
	player.free()
	ally.free()

func test_generated_frames_have_no_neighbor_bleed() -> void:
	var image: Image = GoblinShaman.STAFF_SPIRAL_ATLAS.get_image()
	if image.is_compressed(): image.decompress()
	assert(image.get_size() == Vector2i(768, 96))
	for index: int in range(8):
		var frame: Image = image.get_region(Rect2i(index * 96, 0, 96, 96))
		var bounds: Rect2i = frame.get_used_rect()
		assert(bounds.position.x >= 25 and bounds.end.x <= 75)
