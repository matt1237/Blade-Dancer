class_name GoblinShamanTest extends Node

func _ally(identity: StringName, hp: float = 20.0, maximum: float = 100.0) -> Enemy:
	var ally: Enemy = Enemy.new()
	ally.spawn_identity = identity
	ally.health = hp
	ally.max_health = maximum
	return ally

func test_exact_ten_ticks_cap_refresh_and_no_resurrection() -> void:
	var ally: Enemy = _ally(&"ogre")
	ally.receive_shaman_heal()
	assert(ally.health == 30.0)
	ally.tick_shaman_regeneration(0.99)
	assert(ally.health == 30.0)
	ally.tick_shaman_regeneration(0.01)
	assert(ally.health == 31.0)
	ally.tick_shaman_regeneration(9.0)
	assert(ally.health == 40.0 and ally.shaman_regen_ticks_left == 0)
	ally.tick_shaman_regeneration(50.0)
	assert(ally.health == 40.0)
	ally.receive_shaman_heal()
	ally.tick_shaman_regeneration(0.8)
	ally.receive_shaman_heal()
	assert(ally.health == 60.0 and ally.shaman_regen_ticks_left == 10)
	ally.tick_shaman_regeneration(0.2)
	assert(ally.health == 60.0)
	ally.tick_shaman_regeneration(9.8)
	assert(ally.health == 70.0)
	ally.health = 95.0
	ally.receive_shaman_heal()
	ally.tick_shaman_regeneration(10.0)
	assert(ally.health == 100.0)
	ally.health = 0.0
	ally.receive_shaman_heal()
	ally.tick_shaman_regeneration(10.0)
	assert(ally.health == 0.0 and ally.shaman_regen_ticks_left == 0)
	ally.free()

func test_filters_range_and_lowest_health_percentage() -> void:
	var shaman: GoblinShaman = GoblinShaman.new()
	shaman._configure_concrete_enemy()
	var allies: Array[Enemy] = []
	for identity: StringName in GoblinShaman.ELIGIBLE_IDENTITIES:
		var ally: Enemy = _ally(identity)
		assert(shaman.is_eligible_ally(ally))
		allies.append(ally)
	for identity: StringName in [&"turkey", &"wolf", &"bug", &"zungar", &"goblin_shaman"]:
		var excluded: Enemy = _ally(identity, 1.0)
		assert(not shaman.is_eligible_ally(excluded))
		allies.append(excluded)
	shaman.health = 1.0
	assert(not shaman.is_eligible_ally(shaman))
	var ogre: Enemy = allies[4]
	ogre.health = 30.0
	ogre.max_health = 200.0
	ogre.position = Vector2(250, 0)
	assert(shaman.select_healing_target(allies) == ogre)
	ogre.position.x = 250.01
	assert(shaman.select_healing_target(allies) != ogre)
	ogre.position.x = 0.0
	ogre.death_emitted = true
	assert(shaman.select_healing_target(allies) != ogre)
	for ally: Enemy in allies: ally.free()
	shaman.free()

func test_cast_completion_interruptions_and_multiple_shamans() -> void:
	var world: Node2D = Node2D.new()
	var first: GoblinShaman = GoblinShaman.new()
	var second: GoblinShaman = GoblinShaman.new()
	world.add_child(first)
	world.add_child(second)
	first._configure_concrete_enemy()
	second._configure_concrete_enemy()
	var ally: Enemy = _ally(&"ogre")
	assert(first.begin_cast(ally))
	assert(first.fire_timer == 5.0)
	first.advance_cast(0.59)
	assert(ally.health == 20.0)
	first.advance_cast(0.01)
	assert(ally.health == 20.0 and not first.casting)
	assert(ally.shaman_regen_ticks_left == 0)
	var first_orb: ShamanHealOrb = world.get_child(2) as ShamanHealOrb
	first_orb.advance_flight(0.01)
	first_orb.advance_flight(0.01)
	assert(ally.health == 30.0) # Duplicate advance cannot deliver twice.
	assert(not first.begin_cast(ally))
	assert(second.begin_cast(ally))
	second.advance_cast(0.6)
	assert(ally.health == 30.0)
	var second_orb: ShamanHealOrb = world.get_child(3) as ShamanHealOrb
	second_orb.advance_flight(0.01)
	assert(ally.health == 40.0 and ally.shaman_regen_ticks_left == 10)
	first.free() # The recipient, not either caster, owns regeneration.
	second.free()
	ally.tick_shaman_regeneration(10.0)
	assert(ally.health == 50.0)
	world.free()
	for reason: String in ["stun", "death", "corpse", "range"]:
		var shaman: GoblinShaman = GoblinShaman.new()
		shaman._configure_concrete_enemy()
		ally.health = 20.0
		ally.position = Vector2.ZERO
		assert(shaman.begin_cast(ally))
		match reason:
			"stun": shaman.stun_left = 0.01
			"death": shaman.death_emitted = true
			"corpse": ally.health = 0.0
			"range": ally.position.x = 251.0
		var before: float = ally.health
		shaman.advance_cast(0.6)
		assert(ally.health == before and not shaman.casting)
		shaman.free()
	ally.free()

func test_backline_retreat_and_injured_anchor() -> void:
	var shaman: GoblinShaman = GoblinShaman.new()
	var player: Player = Player.new()
	shaman.player_ref = player
	shaman._configure_concrete_enemy()
	var ally: Enemy = _ally(&"ogre")
	ally.position = Vector2(200, 0)
	shaman.position = Vector2(100, 0)
	shaman.update_backline_motion([ally])
	assert(shaman.velocity.x > 0.0)
	shaman.position = Vector2(450, 0)
	shaman.update_backline_motion([ally])
	assert(shaman.velocity.x < 0.0)
	shaman.position = Vector2(310, 0)
	shaman.update_backline_motion([ally])
	assert(shaman.velocity.is_zero_approx())
	shaman.free()
	player.free()
	ally.free()

func test_health_bar_updates_on_arrival_after_cast_animation() -> void:
	var world: Node2D = Node2D.new()
	var shaman: GoblinShaman = WaveSpawner.GOBLIN_SHAMAN_SCENE.instantiate() as GoblinShaman
	world.add_child(shaman)
	shaman._configure_concrete_enemy()
	shaman._setup_hd_enemy_sprite()
	var ally: Enemy = WaveSpawner.OGRE_SCENE.instantiate() as Enemy
	ally._configure_concrete_enemy()
	ally.health_bar = ally.get_node("HealthBar") as HealthBar
	ally.max_health = 100.0
	ally.health = 20.0
	assert(shaman.begin_cast(ally))
	shaman.advance_cast(0.3)
	shaman._update_hd_enemy_sprite()
	assert(shaman.hd_enemy_sprite.animation == &"cast" and shaman.hd_enemy_sprite.frame == 3)
	assert(ally.health == 20.0)
	shaman.advance_cast(0.3)
	assert(shaman.hd_enemy_sprite.frame == 5)
	assert(ally.health == 20.0)
	var orb: ShamanHealOrb = world.get_child(1) as ShamanHealOrb
	orb.advance_flight(0.01)
	assert(ally.health == 30.0 and ally.health_bar.value == 30.0)
	ally.tick_shaman_regeneration(1.0)
	assert(ally.health_bar.value == 31.0)
	world.free()
	ally.free()

func test_wave_seven_identity_picker_and_scroll_menu() -> void:
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.current_wave = 6
	assert(not spawner._available_enemy_scenes().has(WaveSpawner.GOBLIN_SHAMAN_SCENE))
	spawner.current_wave = 7
	assert(spawner._available_enemy_scenes().has(WaveSpawner.GOBLIN_SHAMAN_SCENE))
	assert(spawner.scene_for_name(&"shaman") == WaveSpawner.GOBLIN_SHAMAN_SCENE)
	assert(spawner._scene_balance_key(WaveSpawner.GOBLIN_SHAMAN_SCENE) == &"goblin_shaman")
	var shaman: GoblinShaman = WaveSpawner.GOBLIN_SHAMAN_SCENE.instantiate() as GoblinShaman
	shaman._configure_concrete_enemy()
	assert(shaman.collision_mask != 0 and shaman.collision_layer == 2)
	assert((shaman.get_node("CollisionShape2D") as CollisionShape2D).shape is CircleShape2D)
	assert(shaman.spawn_balance_key() == &"goblin_shaman")
	var progression: HomeProgression = HomeProgression.new()
	progression.begin_grandpa_chores()
	progression.record_grandpa_enemy_defeat(shaman.spawn_balance_key())
	assert(progression.grandpa_goblins_defeated == 1)
	shaman._setup_hd_enemy_sprite()
	assert(shaman.hd_enemy_sprite.sprite_frames.get_frame_count("idle") == 4)
	assert(shaman.hd_enemy_sprite.sprite_frames.get_frame_count("move") == 6)
	assert(shaman.hd_enemy_sprite.sprite_frames.get_frame_count("cast") == 6)
	assert(EnemySpawnRig.ENEMY_SCENES["goblin_shaman"] == WaveSpawner.GOBLIN_SHAMAN_SCENE)
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu.add_child(tabs)
	menu._build_enemy_tab(tabs)
	var scroll: ScrollContainer = tabs.get_node("Enemies") as ScrollContainer
	assert(scroll != null)
	var found: bool = false
	for child: Node in scroll.get_node("SpawnList").get_children():
		if child is Button and (child as Button).text == "Spawn Goblin Shaman":
			found = true
			assert((child as Button).pressed.get_connections().size() == 1)
	assert(found)
	menu.free()
	shaman.free()
	spawner.free()
