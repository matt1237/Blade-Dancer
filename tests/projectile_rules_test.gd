class_name ProjectileRulesTest extends Node

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy_projectile.tscn")
const OGRE_SCENE: PackedScene = preload("res://scenes/enemies/ogre.tscn")
const ZUNGAR_SCENE: PackedScene = preload("res://scenes/boss/zungar.tscn")

func test_enemy_projectiles_only_support_player_deflect() -> void:
	var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
	assert(projectile.has_method("deflect"), "Player Deflect must remain supported.")
	assert(not projectile.has_method("reflect_from_shield"), "Ogre shields must not reflect hostile projectiles.")
	projectile.free()

func test_ogre_shield_rule_remains_available_for_player_attacks() -> void:
	var ogre: Ogre = OGRE_SCENE.instantiate() as Ogre
	ogre._configure_concrete_enemy()
	assert(ogre.shield_enabled, "Ogre alone must opt into shield collision.")
	assert(ogre.has_method("chakram_blocked_from_front"), "Chakram needs the Ogre shield's wall-like collision rule.")
	assert(ogre.has_method("shield_blocks_projectile"), "Player-owned ranged attacks may still query the Ogre shield.")
	ogre.free()

func test_zungar_has_no_invisible_ogre_shield_and_takes_normal_damage() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	add_child(zungar)
	zungar.set_physics_process(false)
	assert(not zungar.shield_enabled)
	assert(not zungar.chakram_blocked_from_front(zungar.global_position + Vector2.RIGHT * 24.0), "Zungar must never invisibly block Chakram hits.")
	zungar.chakram_hit_from_behind(Vector2.RIGHT)
	assert(is_zero_approx(zungar.stun_left), "Rear-shield Chakram stun belongs only to Ogre.")
	zungar.global_position = Vector2(100.0, 100.0)
	var chakram: Chakram = Chakram.new()
	add_child(chakram)
	chakram.global_position = Vector2(80.0, 100.0)
	chakram.velocity = Vector2.RIGHT * 500.0
	chakram.damage = 7.0
	var before: float = zungar.health
	chakram._hit_enemies(Vector2(70.0, 100.0), Vector2(120.0, 100.0))
	assert(zungar.health < before, "A real Chakram sweep across Zungar must deal ordinary damage.")
	assert(chakram.velocity.x < 0.0, "The damaging Chakram may rebound after impact, but not as an invisible shield block.")
	chakram.queue_free()
	zungar.queue_free()
