class_name WavePacingTest extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func test_wave_one_gives_thirty_seconds_to_learn_the_rhythm() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	assert(spawner.wave_duration_start == 30.0, "Wave 1 should last 30 seconds.")
	spawner.current_wave = 1
	spawner._start_wave()
	assert(spawner.current_wave == 2 and spawner.wave_duration == 35.0, "Later waves should continue the existing five-second duration progression.")
	main.free()
