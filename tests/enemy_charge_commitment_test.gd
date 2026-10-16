class_name EnemyChargeCommitmentTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _exercise(scene: PackedScene) -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Player = PLAYER_SCENE.instantiate() as Player
	var enemy: Enemy = scene.instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	player.position = Vector2(200.0 if enemy is Ogre else 90.0, 0.0)
	enemy.knockback = Vector2(500.0, 40.0)
	enemy.grapple_slide_velocity = Vector2(30.0, 20.0)
	enemy.stun_left = 1.0
	# The concrete AI decision starts the real windup, shedding earlier interrupts.
	enemy._run_concrete_ai(0.01)
	assert(enemy.windup > 0.0 and enemy._is_knockback_immune())
	assert(enemy.stun_left == 0.0 and enemy.knockback == Vector2.ZERO and enemy.grapple_slide_velocity == Vector2.ZERO)
	for phase: int in range(2):
		var hp: float = enemy.health
		enemy.take_damage(1.0, Vector2(400.0, 80.0), 2.0)
		assert(enemy.health == hp - 1.0 and enemy.health_bar.value == enemy.health, "Commitment must not suppress health damage.")
		# The hilt bash's second direct stun write must also be discarded.
		enemy.stun_left = 3.0
		enemy.stun_for(1.0)
		enemy.weapon_clash(Vector2.RIGHT * 500.0)
		enemy.receive_collision_sword_push(Vector2.RIGHT, 30.0)
		enemy.apply_void_pull(Vector2.UP, 500.0)
		enemy.apply_grapple_force(Vector2.RIGHT * 600.0, 1.0, 1000.0, 0.25)
		if enemy.shield_enabled:
			enemy.shield_parry(Vector2.RIGHT * 500.0)
			enemy.chakram_hit_from_behind(Vector2.RIGHT * 400.0)
			assert(enemy.parry_flash > 0.0, "Shield feedback remains visible.")
		assert(enemy.stun_left == 0.0 and enemy.knockback == Vector2.ZERO and enemy.grapple_slide_velocity == Vector2.ZERO)
		# Even directly queued old motion cannot leak through shared processing.
		enemy.knockback = Vector2.UP * 900.0
		enemy.grapple_slide_velocity = Vector2.UP * 200.0
		var warning: float = enemy.windup
		var distance: float = enemy.charge_distance_left
		enemy._physics_process(0.01)
		assert(enemy.knockback == Vector2.ZERO and enemy.grapple_slide_velocity == Vector2.ZERO)
		if phase == 0:
			assert(enemy.windup < warning and enemy.velocity == Vector2.ZERO, "Hit must not pause or shove the warning.")
			enemy._physics_process(enemy.windup + 0.001)
			assert(enemy.charge_distance_left > 0.0)
		else:
			assert(enemy.charge_distance_left < distance and enemy.velocity.dot(enemy.charge_direction) > 0.0, "Hit must not pause moving-charge AI.")
	# Real shared update exhausts travel; no saved stun springs back in recovery.
	enemy._physics_process(10.0)
	assert(enemy.charge_recovery_left > 0.0 and not enemy._is_knockback_immune())
	assert(enemy.stun_left == 0.0)
	enemy.take_damage(1.0, Vector2.RIGHT * 120.0, 0.5)
	assert(enemy.stun_left > 0.0 and enemy.knockback.x > 0.0, "Recovery must accept ordinary interrupts.")
	enemy._physics_process(0.01)
	assert(enemy.stun_left > 0.0)
	enemy.free()
	# Fresh subjects: lethal hits always stop red warning and moving charge.
	# Also cover a lethal burn tick inside shared processing (no final AI/move).
	for phase: int in range(3):
		var doomed: Enemy = scene.instantiate() as Enemy
		add_child(doomed)
		doomed.set_physics_process(false)
		doomed.player_ref = player
		doomed._begin_charge_windup(0.5)
		if phase > 0:
			doomed.windup = 0.0
			doomed._begin_predictive_charge(0.0, 100.0, 2.0, 1.0)
		doomed.velocity = Vector2.RIGHT * 200.0
		var position_before: Vector2 = doomed.position
		if phase == 2:
			doomed.burning_left = 1.0
			doomed.burning_tick = 0.0
			doomed.burning_damage_per_tick = 99999.0
			doomed._physics_process(0.01)
		else:
			doomed.take_damage(99999.0, Vector2.RIGHT * 500.0, 2.0)
			doomed._physics_process(0.01)
		assert(doomed.health == 0.0 and doomed.death_emitted and doomed.is_queued_for_deletion())
		assert(doomed.velocity == Vector2.ZERO and doomed.position == position_before)
		doomed.free()
	player.free()
	get_tree().current_scene = previous_scene

func test_turkey_charge_commitment_shared_processing() -> void:
	_exercise(WaveSpawner.TURKEY_SCENE)

func test_wolf_charge_commitment_shared_processing() -> void:
	_exercise(WaveSpawner.WOLF_SCENE)

func test_ogre_charge_commitment_shared_processing() -> void:
	_exercise(WaveSpawner.OGRE_SCENE)

func test_nonchargers_keep_stun_and_impulse_authority() -> void:
	var goblin: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	goblin._configure_concrete_enemy()
	goblin.windup = 0.5
	goblin.charge_distance_left = 100.0
	goblin.stun_left = 0.7
	goblin._add_knockback(Vector2.RIGHT * 100.0)
	goblin._suppress_charge_interrupts()
	assert(goblin.stun_left == 0.7 and goblin.knockback.x == 100.0)
	goblin.free()

func test_committed_charges_still_collide_with_terrain() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(200.0, 0.0)
	for scene: PackedScene in [WaveSpawner.TURKEY_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]:
		var wall: StaticBody2D = StaticBody2D.new()
		wall.collision_layer = PhysicsShell.WORLD_LAYER
		wall.collision_mask = 0
		wall.position = Vector2(40.0, 0.0)
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(10.0, 200.0)
		collider.shape = shape
		wall.add_child(collider)
		add_child(wall)
		var enemy: Enemy = scene.instantiate() as Enemy
		add_child(enemy)
		enemy.set_physics_process(false)
		enemy.player_ref = player
		enemy._begin_predictive_charge(0.0, 300.0, 2.0, 5.0)
		for frame: int in range(12):
			await get_tree().physics_frame
			enemy._physics_process(1.0 / 60.0)
		assert(enemy.position.x > 0.0 and enemy.position.x <= 21.1, "Charge intent must still yield to a terrain wall.")
		assert(enemy.charge_distance_left > 0.0 and enemy._is_knockback_immune())
		enemy.free()
		wall.free()
	player.free()
	get_tree().current_scene = previous_scene

func test_ogre_shield_keeps_player_clash_penalty_during_commitment() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	ogre._configure_concrete_enemy()
	ogre._begin_charge_windup(0.5)
	ogre.shield_parry(Vector2.RIGHT * 500.0)
	player.debug_print_sword_events = false
	player._trigger_shield_clash(Vector2(24.0, 0.0))
	assert(ogre.stun_left == 0.0 and ogre.knockback == Vector2.ZERO)
	assert(player.hit_stagger_left >= Player.SHIELD_CLASH_STUN_DURATION)
	assert(player.hit_knockback.length() >= Player.SHIELD_CLASH_KNOCKBACK)
	player.free()
	ogre.free()
