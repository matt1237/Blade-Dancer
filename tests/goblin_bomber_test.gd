class_name GoblinBomberTest extends Node

class DamageSpy extends Player:
	var hits: Array[float] = []
	func take_damage(amount: float, _force: Vector2 = Vector2.ZERO, _attacker: Node2D = null) -> void:
		hits.append(amount)

class BomberSpy extends GoblinBomber:
	var attack_count: int = 0
	func _has_player_line_of_sight() -> bool:
		return true
	func _begin_bomb_attack() -> BomberBomb:
		attack_count += 1
		return null

func test_four_second_cooldown_and_distance_keeping() -> void:
	var bomber: BomberSpy = BomberSpy.new()
	var player: DamageSpy = DamageSpy.new()
	bomber._configure_concrete_enemy()
	bomber.player_ref = player
	player.position = Vector2(100, 0)
	bomber._run_concrete_ai(3.99)
	assert(bomber.velocity.x < 0.0 and bomber.attack_count == 0)
	bomber._run_concrete_ai(0.02)
	assert(bomber.attack_count == 1 and bomber.fire_timer == 4.0)
	player.position = Vector2(500, 0)
	bomber._run_concrete_ai(3.99)
	assert(bomber.velocity.x > 0.0 and bomber.attack_count == 1)
	bomber._run_concrete_ai(0.02)
	assert(bomber.attack_count == 2)
	bomber.free()
	player.free()

func test_attack_scene_has_all_animated_assets_and_cleanup_group() -> void:
	var bomb: BomberBomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
	for node_name: String in ["Bomb", "Fire", "Explosion"]:
		var sprite: AnimatedSprite2D = bomb.get_node(node_name) as AnimatedSprite2D
		assert(sprite.sprite_frames.get_frame_count(sprite.animation) == 4)
		for index: int in range(4):
			assert(sprite.sprite_frames.get_frame_texture(sprite.animation, index) != null)
	bomb._ready()
	assert(bomb.is_in_group("enemy_projectiles"))
	bomb.free()

func test_timing_locked_target_and_four_fire_ticks() -> void:
	var player: DamageSpy = DamageSpy.new()
	player.position = Vector2(80, 90)
	var bomb: BomberBomb = BomberBomb.new()
	bomb.arm(Vector2(300, 90), player.position, player)
	player.position += Vector2(100, 0)
	assert(bomb.locked_target == Vector2(80, 90))
	bomb.advance_attack(0.49)
	assert(bomb.phase == BomberBomb.Phase.WARNING and player.hits.is_empty())
	bomb.advance_attack(0.02)
	assert(bomb.phase == BomberBomb.Phase.FLIGHT)
	bomb.advance_attack(0.44)
	assert(bomb.phase == BomberBomb.Phase.FUSE)
	bomb.advance_attack(0.49)
	assert(player.hits.is_empty())
	player.position = bomb.locked_target
	bomb.advance_attack(0.01)
	assert(player.hits == [15.0])
	for tick: int in range(4):
		bomb.advance_attack(0.5)
		assert(bomb.fire_ticks == tick + 1)
	assert(player.hits == [15.0, 5.0, 5.0, 5.0, 5.0])
	assert(bomb.phase == BomberBomb.Phase.FINISHED)
	player.free()

func test_reticle_persists_until_detonation() -> void:
	var bomb: BomberBomb = BomberBomb.new()
	assert(not bomb.is_reticle_visible())
	bomb.arm(Vector2.ZERO, Vector2.ZERO, null)
	assert(bomb.is_reticle_visible())
	bomb.advance_attack(BomberBomb.WARNING_TIME)
	assert(bomb.phase == BomberBomb.Phase.FLIGHT and bomb.is_reticle_visible())
	bomb.advance_attack(BomberBomb.FLIGHT_TIME)
	assert(bomb.phase == BomberBomb.Phase.FUSE and bomb.is_reticle_visible())
	bomb.advance_attack(BomberBomb.FUSE_TIME)
	assert(bomb.phase == BomberBomb.Phase.FIRE and not bomb.is_reticle_visible())
	bomb.free()

func test_effect_scaling_preserves_bomb_icon_size() -> void:
	var bomb: BomberBomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
	bomb.bomb_sprite = bomb.get_node("Bomb") as AnimatedSprite2D
	bomb.fire_sprite = bomb.get_node("Fire") as AnimatedSprite2D
	bomb.explosion_sprite = bomb.get_node("Explosion") as AnimatedSprite2D
	bomb.arm(Vector2.ZERO, Vector2.ZERO, null)
	bomb.advance_attack(BomberBomb.EXPLODE_TIME)
	var full_scale: Vector2 = Vector2(BomberBomb.RADIUS * 2.0 / BomberBomb.FIRE_GROUND_RECT.size.x, BomberBomb.RADIUS * 2.0 / BomberBomb.FIRE_GROUND_RECT.size.y)
	assert(bomb.fire_sprite.scale.is_equal_approx(full_scale))
	var initial_position: Vector2 = bomb.fire_sprite.position
	assert(bomb.explosion_sprite.scale.is_equal_approx(Vector2.ONE * 1.15))
	assert(bomb.bomb_sprite.scale.is_equal_approx(Vector2.ONE * 0.25))
	bomb.advance_attack(0.35)
	assert(bomb.fire_sprite.scale.is_equal_approx(full_scale))
	assert(bomb.fire_sprite.position.is_equal_approx(initial_position))
	bomb.advance_attack(1.0)
	assert(bomb.fire_sprite.scale.is_equal_approx(full_scale))
	bomb.free()

func test_fire_ground_anchor_and_exact_damage_footprint() -> void:
	var bomb: BomberBomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
	bomb.bomb_sprite = bomb.get_node("Bomb") as AnimatedSprite2D
	bomb.fire_sprite = bomb.get_node("Fire") as AnimatedSprite2D
	bomb.explosion_sprite = bomb.get_node("Explosion") as AnimatedSprite2D
	var target: Vector2 = Vector2(230, 170)
	bomb.arm(Vector2(500, 100), target, null)
	bomb.advance_attack(BomberBomb.EXPLODE_TIME)
	var patch: Rect2 = BomberBomb.FIRE_GROUND_RECT
	var center: Vector2 = patch.get_center()
	var scale: Vector2 = bomb.fire_sprite.scale
	var anchor: Vector2 = bomb.fire_sprite.position
	assert(((center - BomberBomb.FIRE_FRAME_CENTER) * scale + anchor).is_zero_approx())
	var left: Vector2 = (Vector2(patch.position.x, center.y) - BomberBomb.FIRE_FRAME_CENTER) * scale + anchor
	var right: Vector2 = (Vector2(patch.end.x, center.y) - BomberBomb.FIRE_FRAME_CENTER) * scale + anchor
	assert(left.is_equal_approx(Vector2(-69, 0)))
	assert(right.is_equal_approx(Vector2(69, 0)))
	var top: Vector2 = (Vector2(center.x, patch.position.y) - BomberBomb.FIRE_FRAME_CENTER) * scale + anchor
	var bottom: Vector2 = (Vector2(center.x, patch.end.y) - BomberBomb.FIRE_FRAME_CENTER) * scale + anchor
	assert(top.is_equal_approx(Vector2(0, -69)))
	assert(bottom.is_equal_approx(Vector2(0, 69)))
	# The actual animated ground patch now shares RADIUS on BOTH axes.
	for edge: Vector2 in [Vector2(-69, 0), Vector2(69, 0), Vector2(0, -69), Vector2(0, 69)]:
		assert(bomb.contains_point(target + edge))
		assert(not bomb.contains_point(target + edge * 1.001))
	assert(bomb.global_position.is_equal_approx(target))
	assert(bomb.fire_sprite.visible)
	bomb.free()

func test_radius_and_frame_skip_do_not_drop_ticks() -> void:
	var bomb: BomberBomb = BomberBomb.new()
	bomb.arm(Vector2.ZERO, Vector2(100, 100), null)
	assert(bomb.contains_point(Vector2(169, 100)))
	assert(not bomb.contains_point(Vector2(169.01, 100)))
	var pulses: Array[float] = []
	bomb.damage_pulse.connect(func(amount: float) -> void: pulses.append(amount))
	bomb.advance_attack(10.0)
	assert(pulses == [15.0, 5.0, 5.0, 5.0, 5.0])
	bomb.advance_attack(10.0)
	assert(pulses.size() == 5)

func test_wave_six_identity_balance_and_selector() -> void:
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.current_wave = 5
	assert(not spawner._available_enemy_scenes().has(WaveSpawner.GOBLIN_BOMBER_SCENE))
	spawner.current_wave = 6
	assert(spawner._available_enemy_scenes().has(WaveSpawner.GOBLIN_BOMBER_SCENE))
	assert(spawner.scene_for_name(&"bomber") == WaveSpawner.GOBLIN_BOMBER_SCENE)
	assert(spawner._scene_balance_key(WaveSpawner.GOBLIN_BOMBER_SCENE) == &"goblin_bomber")
	var bomber: GoblinBomber = WaveSpawner.GOBLIN_BOMBER_SCENE.instantiate() as GoblinBomber
	bomber._configure_concrete_enemy()
	assert(bomber.spawn_balance_key() == &"goblin_bomber")
	assert(bomber.fire_timer == 4.0 and bomber.attack_cooldown == 4.0)
	assert(not bomber.moving_weapon_enabled and not bomber.participates_in_melee_engagement)
	bomber.free()
	spawner.free()

func test_bomb_is_world_owned_and_not_deflectable() -> void:
	var world: Node2D = Node2D.new()
	var bomber: GoblinBomber = WaveSpawner.GOBLIN_BOMBER_SCENE.instantiate() as GoblinBomber
	var player: DamageSpy = DamageSpy.new()
	world.add_child(bomber)
	bomber.player_ref = player
	var bomb: BomberBomb = bomber._begin_bomb_attack()
	assert(bomb.get_parent() == world)
	assert(not bomb.is_class("Area2D") and not bomb.has_method("deflect"))
	bomber.free()
	assert(is_instance_valid(bomb) and bomb.armed)
	bomb.advance_attack(BomberBomb.EXPLODE_TIME)
	assert(player.hits == [15.0])
	world.free()
	player.free()
