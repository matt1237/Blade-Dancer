class_name ShamanHealOrbTest extends Node

func _ally() -> Enemy:
	var ally: Enemy = Enemy.new()
	ally.spawn_identity = &"ogre"
	ally.max_health = 100.0
	ally.health = 20.0
	ally.position = Vector2(200.0, 0.0)
	return ally

func _orb(world: Node2D, ally: Enemy) -> ShamanHealOrb:
	var orb: ShamanHealOrb = GoblinShaman.HEAL_ORB_SCENE.instantiate() as ShamanHealOrb
	world.add_child(orb)
	orb.launch(ShamanHealOrb.TARGET_OFFSET, ally)
	return orb

func test_follows_moving_target_only_heals_on_arrival_once() -> void:
	var world: Node2D = Node2D.new()
	var ally: Enemy = _ally()
	world.add_child(ally)
	var orb: ShamanHealOrb = _orb(world, ally)
	orb.advance_flight(0.2)
	assert(orb.position.is_equal_approx(Vector2(64.0, -18.0)))
	assert(ally.health == 20.0 and ally.shaman_regen_ticks_left == 0)
	ally.position = Vector2(200.0, 100.0)
	orb.advance_flight(0.2)
	assert(orb.position.y > -18.0) # Seeks actual new position, not cast-time aim.
	assert(ally.health == 20.0)
	orb.advance_flight(0.6)
	assert(orb.delivered and ally.health == 30.0 and ally.shaman_regen_ticks_left == 10)
	orb.advance_flight(0.6)
	assert(ally.health == 30.0)
	world.free()

func test_dead_freed_or_queued_target_discards_without_retargeting() -> void:
	for reason: String in ["dead", "zero_hp", "freed", "queued"]:
		var world: Node2D = Node2D.new()
		var ally: Enemy = _ally()
		world.add_child(ally)
		var other: Enemy = _ally()
		world.add_child(other)
		var orb: ShamanHealOrb = _orb(world, ally)
		match reason:
			"dead": ally.death_emitted = true
			"zero_hp": ally.health = 0.0
			"freed": ally.free()
			"queued": ally.queue_free()
		orb.advance_flight(1.0)
		assert(orb.is_queued_for_deletion() and not orb.delivered)
		assert(other.health == 20.0 and other.shaman_regen_ticks_left == 0)
		if is_instance_valid(ally): assert(ally.shaman_regen_ticks_left == 0)
		world.free()

func test_launched_orb_survives_caster_death_and_refreshes_one_regen_slot() -> void:
	var world: Node2D = Node2D.new()
	var caster: GoblinShaman = GoblinShaman.new()
	world.add_child(caster)
	caster._configure_concrete_enemy()
	var ally: Enemy = _ally()
	world.add_child(ally)
	assert(caster.begin_cast(ally))
	caster.advance_cast(0.6)
	var orb: ShamanHealOrb = world.get_child(2) as ShamanHealOrb
	assert(orb != null and orb.get_parent() == world)
	assert(ally.health == 20.0)
	caster.free()
	orb.advance_flight(1.0)
	assert(ally.health == 30.0)
	ally.tick_shaman_regeneration(0.8)
	var second: ShamanHealOrb = _orb(world, ally)
	second.advance_flight(1.0)
	assert(ally.health == 40.0 and ally.shaman_regen_ticks_left == 10)
	ally.tick_shaman_regeneration(0.2)
	assert(ally.health == 40.0)
	ally.tick_shaman_regeneration(9.8)
	assert(ally.health == 50.0)
	world.free()

func test_timeout_cancels_and_visuals_are_real_green_particles() -> void:
	var world: Node2D = Node2D.new()
	var ally: Enemy = _ally()
	world.add_child(ally)
	ally.position.x = 10000.0
	var orb: ShamanHealOrb = _orb(world, ally)
	orb._ready()
	assert(orb.is_in_group("enemy_projectiles"))
	assert(not orb.has_method("deflect") and not orb.has_method("take_damage"))
	var sprite: Sprite2D = orb.get_node("Orb") as Sprite2D
	assert(sprite.texture != null)
	var trail: CPUParticles2D = orb.get_node("Trail") as CPUParticles2D
	assert(trail.emitting and not trail.local_coords and trail.texture != null)
	assert(trail.color_ramp.get_color(0).g > trail.color_ramp.get_color(0).r)
	orb.orb_sprite = sprite
	orb.advance_flight(0.1)
	var light: Color = sprite.modulate
	orb.advance_flight(0.2)
	assert(sprite.modulate.g < light.g and sprite.modulate.a == 1.0)
	orb.advance_flight(4.0)
	assert(orb.is_queued_for_deletion() and not orb.delivered)
	assert(ally.health == 20.0 and ally.shaman_regen_ticks_left == 0)
	world.free()
