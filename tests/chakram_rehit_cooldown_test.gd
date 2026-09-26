class_name ChakramRehitCooldownTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

## Both the sword and the Chakram now use a 0.2s per-enemy rehit cooldown.
func test_sword_rehit_cooldown_is_two_tenths() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	assert(is_equal_approx(player.enemy_rehit_cooldown_duration, 0.2), "Sword rehit cooldown must be 0.2s.")
	player.free()

## The old once-per-flight latch (each enemy hit at most once per throw) is
## replaced by a timed per-enemy cooldown so a disc that loops back can re-hit.
func test_chakram_enemy_hit_uses_a_timed_cooldown_not_a_permanent_latch() -> void:
	var chakram: Chakram = Chakram.new()
	assert(is_equal_approx(chakram.enemy_rehit_cooldown_duration, 0.2), "Chakram rehit cooldown must be 0.2s.")
	assert(chakram.hit_enemy_cooldowns is Dictionary, "Enemy hits must be tracked as timed cooldowns, not a boolean latch.")
	var source: String = FileAccess.get_file_as_string("res://scripts/chakram.gd")
	assert(not source.contains("hit_enemy_ids"), "The once-per-flight latch must be fully replaced by the rehit cooldown.")
	chakram.free()

## A live cooldown blocks an immediate re-hit; once it elapses the same enemy
## becomes hittable again (which is what stops the disc flying through).
func test_rehit_cooldown_expires_so_a_returning_disc_can_hit_again() -> void:
	var cooldowns: Dictionary = {}
	cooldowns[7] = 0.2
	Chakram.advance_enemy_rehit_cooldowns(cooldowns, 0.05)
	assert(cooldowns.has(7) and float(cooldowns[7]) > 0.0, "A live cooldown must still block an immediate re-hit.")
	Chakram.advance_enemy_rehit_cooldowns(cooldowns, 0.2)
	assert(not cooldowns.has(7), "Once elapsed, the cooldown must clear so the same enemy can be hit again.")