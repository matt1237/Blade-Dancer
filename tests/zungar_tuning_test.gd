class_name ZungarTuningTest extends Node

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/goblin.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func test_charge_and_jump_damage_are_lowered_without_touching_speed() -> void:
	assert(ZungarConfig.CHARGE_DAMAGE == 20.0, "Zungar's charge should deal 20 damage, not 42.")
	assert(ZungarConfig.JUMP_SLAM_DAMAGE == 20.0, "Zungar's jump slam should deal 20 damage, not 34.")
	assert(ZungarConfig.CHARGE_SPEED == 660.0, "Charge speed must stay untouched.")
	assert(ZungarConfig.FRIENDLY_CHARGE_DAMAGE == 20.0 and ZungarConfig.FRIENDLY_JUMP_DAMAGE == 20.0, "His own attacks should not hit his allies harder than the player.")

func test_every_attack_exposes_tunable_damage_and_knockback() -> void:
	for damage: float in [ZungarConfig.CONTACT_DAMAGE, ZungarConfig.EXECUTIONER_SWORD_DAMAGE, ZungarConfig.CHARGE_DAMAGE, ZungarConfig.JUMP_SLAM_DAMAGE, ZungarConfig.SPEAR_DAMAGE]:
		assert(damage > 0.0, "Every Zungar attack needs a positive damage value in the config.")
	# Knockback used to be hardcoded inline in zungar.gd; it must live in the config.
	for knockback: float in [ZungarConfig.CONTACT_KNOCKBACK, ZungarConfig.EXECUTIONER_SWORD_KNOCKBACK, ZungarConfig.CHARGE_KNOCKBACK, ZungarConfig.JUMP_SLAM_KNOCKBACK, ZungarConfig.TREE_THROW_KNOCKBACK]:
		assert(knockback > 0.0, "Every Zungar attack should expose its knockback in the config.")

func test_attack_knockbacks_are_no_longer_hardcoded_in_the_boss_script() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/boss/zungar.gd")
	for literal: String in ["* 260.0", "* 300.0", "* 340.0", "* 360.0", "* 330.0"]:
		assert(not source.contains(literal), "Knockback literal '%s' should be a ZungarConfig constant, not inline." % literal)

func test_summon_entrance_config_matches_the_drawn_cave_mouth() -> void:
	assert(ZungarConfig.SUMMON_ENTRANCE_TRAVEL == 100.0, "Summoned allies should walk 100px out of the cave.")
	# Main draws the cave mouth around (640, 118); the entrance must line up with it.
	assert(absf(ZungarConfig.SUMMON_ENTRANCE_POSITION.x - 640.0) <= 1.0, "Cave entrance should be centred on the drawn cave mouth.")
	assert(ZungarConfig.SUMMON_ENTRANCE_POSITION.y > 60.0 and ZungarConfig.SUMMON_ENTRANCE_POSITION.y < 160.0, "Cave entrance Y should sit at the cave mouth.")

func test_summon_entrance_walk_hands_off_to_combat_ai() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(640.0, 360.0)

	var start: Vector2 = ZungarConfig.SUMMON_ENTRANCE_POSITION
	var target: Vector2 = start + Vector2(0.0, ZungarConfig.SUMMON_ENTRANCE_TRAVEL)
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.global_position = start
	enemy.entrance_walk_target = target
	enemy.entrance_walk_speed = ZungarConfig.SUMMON_ENTRANCE_SPEED
	enemy.entrance_walk_active = true

	var steps: int = 0
	while enemy.entrance_walk_active and steps < 900:
		enemy._physics_process(1.0 / 60.0)
		steps += 1

	assert(steps < 900, "The entrance walk must terminate, not run forever.")
	assert(not enemy.entrance_walk_active, "The entrance walk must hand off to normal AI once it arrives.")
	assert(enemy.global_position.distance_to(target) <= 8.0, "Allies should end up ~100px out of the cave before engaging.")
	enemy.queue_free()
	player.queue_free()
