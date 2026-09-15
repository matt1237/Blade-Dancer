class_name HDEnemyEyesLiveTest extends Node
func _ready() -> void:
	call_deferred("run_suite")

func run_suite() -> void:
	var suite: Node = preload("res://tests/hd_enemy_eyes_test.gd").new()
	add_child(suite)
	suite.test_count_and_bounds()
	suite.test_frame_flip_transform_and_day()
	suite.test_animated_frames_use_atlas_region_not_animation_index()
	test_production_adapter()
	var contract: Node = preload("res://tests/hd_eye_atlas_contract_test.gd").new()
	add_child(contract)
	contract.test_rendered_frames_match_source_metadata()
	print("HD eyes: live count/bounds, transforms, visibility, animation and atlas contract completed")

class WorldFixture extends Node2D:
	var settings: ForestVisualSettings = preload("res://scripts/forest_visual_settings.gd").new()
	func get_forest_visual_settings() -> ForestVisualSettings:
		return settings

class EnemyFixture extends Enemy:
	func _ready() -> void:
		_setup_hd_enemy_sprite()
	func _physics_process(_delta: float) -> void:
		pass
	func _draw() -> void:
		pass

func test_production_adapter() -> void:
	var world: WorldFixture = WorldFixture.new()
	add_child(world)
	var night: ForestNightLighting = preload("res://scripts/forest_night_lighting.gd").new()
	world.add_child(night)
	night.set_process(false)
	night.apply_visual_settings({"night_strength": 0.8})
	night.show()
	var player: Player = Player.new()
	player.visual_style = "hd"
	var enemy: EnemyFixture = EnemyFixture.new()
	enemy.player_ref = player
	var health_bar: ProgressBar = ProgressBar.new()
	health_bar.name = "HealthBar"
	enemy.add_child(health_bar)
	world.add_child(enemy)
	var eyes: Node2D = enemy.hd_enemy_sprite.get_node("NightEyes")
	eyes._process(0.0)
	assert(eyes.visible and is_equal_approx(eyes.strength,0.8))
	enemy.death_emitted = true
	eyes._process(0.0)
	assert(not eyes.visible)
	enemy.death_emitted = false
	enemy.health = 0
	eyes._process(0.0)
	assert(not eyes.visible)
	enemy.health = 50
	enemy.hide()
	eyes._process(0.0)
	assert(not eyes.visible)
	enemy.show()
	player.visual_style = "classic"
	eyes._process(0.0)
	assert(not eyes.visible)
	player.visual_style = "hd"
	night.apply_visual_settings({"night_strength": 0.0})
	eyes._process(0.0)
	assert(not eyes.visible)
	world.free()
	player.free()
	print("HD eyes: production night adapter / HD / hidden / death guards passed")
