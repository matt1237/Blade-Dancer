class_name WaveScalingTest extends Node

func test_wave_scaling_is_direct_and_non_cumulative() -> void:
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.enemy_stat_bonus_per_wave = 0.01
	assert(is_equal_approx(spawner.stat_multiplier_for_wave(1), 1.01), "Wave 1 must be 1% above base stats.")
	assert(is_equal_approx(spawner.stat_multiplier_for_wave(10), 1.10), "Wave 10 must be 10% above base.")
	assert(is_equal_approx(spawner.stat_multiplier_for_wave(20), 1.20), "Wave 20 must be 20% above base.")
	assert(is_equal_approx(spawner.stat_multiplier_for_wave(50), 1.50), "Wave 50 must be 50% above base.")
	var wave_twenty_again: float = spawner.stat_multiplier_for_wave(20)
	assert(is_equal_approx(wave_twenty_again, 1.20), "Repeated scaling must not compound.")
	spawner.free()
