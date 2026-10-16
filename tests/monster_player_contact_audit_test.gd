class_name MonsterPlayerContactAuditTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _player_body() -> Node2D:
	var source: Player = PLAYER_SCENE.instantiate() as Player
	var source_body: CollisionShape2D = source.get_node("CollisionShape2D") as CollisionShape2D
	var body: CollisionShape2D = CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.shape = source_body.shape.duplicate() as Shape2D
	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_child(body)
	add_child(player)
	source.free()
	return player

func _enemy(scene: PackedScene, player: Node2D) -> Enemy:
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy._configure_concrete_enemy()
	enemy.player_ref = player
	enemy.global_position = Vector2.ZERO
	return enemy

func test_standard_melee_archetypes_keep_the_shared_body_damage_path() -> void:
	var player: Node2D = _player_body()
	for scene: PackedScene in [WaveSpawner.TURKEY_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE, WaveSpawner.ARCHER_GOBLIN_SCENE]:
		var enemy: Enemy = _enemy(scene, player)
		player.global_position = Vector2(29, 0)
		assert(enemy._has_player_damage_contact(), "%s lost the shared body-contact fallback" % enemy.spawn_identity)
		player.global_position = Vector2(31, 0)
		assert(not enemy._has_player_damage_contact(), "%s unexpectedly has long-range body contact" % enemy.spawn_identity)
		enemy.free()
	player.free()

func test_sword_goblin_weapon_is_live_while_swinging_and_only_hits_on_overlap() -> void:
	var player: Node2D = _player_body()
	var enemy: SwordGoblin = _enemy(WaveSpawner.SWORD_GOBLIN_SCENE, player) as SwordGoblin
	# The blade is always mid-swing now, so it is live whenever it is drawn; only a real
	# overlap with the player collider actually hurts.
	enemy.blade_angle = 0.0
	enemy.blade_length = SwordGoblin.SWORD_SWING_LENGTH
	player.global_position = Vector2(300, 0)
	assert(not enemy._has_player_damage_contact(), "A player beyond the blade's reach must not be hit.")
	player.global_position = Vector2(60, 0)
	assert(enemy._has_player_damage_contact(), "The live swinging blade crossing the player collider must hit.")
	enemy.disarmed = true
	assert(not enemy._has_player_damage_contact())
	enemy.free()
	player.free()

func test_shield_clash_knocks_back_and_briefly_stuns_without_pinning_the_sword() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.hit_stagger_left = 0.0
	player.hit_knockback = Vector2.ZERO
	player.blade_freeze_left = 0.0
	player._trigger_shield_clash(player.global_position + Vector2.RIGHT * 40.0)
	assert(is_equal_approx(player.hit_stagger_left, Player.SHIELD_CLASH_STUN_DURATION), "Shield contact should briefly stun the player.")
	assert(player.hit_knockback.dot(Vector2.LEFT) > 0.0, "The player must be knocked back away from the shield.")
	assert(is_zero_approx(player.blade_freeze_left), "Shield contact must not pin or freeze the sword.")
	assert(is_zero_approx(player.clash_recovery_left), "Shield contact must not add a separate sword lockout.")
	player.free()

func test_ogre_shield_blocks_sword_contact_and_triggers_parry_state() -> void:
	var player: Node2D = _player_body()
	var ogre: Enemy = _enemy(WaveSpawner.OGRE_SCENE, player)
	ogre.shield_angle = 0.0
	var center: Vector2 = Vector2.RIGHT * ogre.elite_shield_distance
	var tangent: Vector2 = Vector2.UP * (ogre.elite_shield_half_width * 0.5)
	var sword_start: Vector2 = center - tangent
	var sword_end: Vector2 = center + tangent
	assert(ogre.is_shield_blocking(sword_start, sword_end), "A front-facing sword crossing the visible shield must be caught.")
	ogre.shield_parry(Vector2.LEFT * 200.0)
	assert(ogre.parry_flash > 0.0 and ogre.stun_left > 0.0 and ogre.clash_latched)
	assert(ogre.shield_parry_cooldown_left > 0.0)
	assert(not ogre.is_shield_blocking(sword_start, sword_end), "A shield parry latches and cannot immediately repeat.")
	ogre.free()
	player.free()
