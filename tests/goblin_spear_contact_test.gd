class_name GoblinSpearContactTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/enemies/goblin.tscn")

func _fixture() -> Dictionary:
	# The actual scene's collider, in the tree so parent motion invalidates its
	# global transform. Do not boot the entire Player controller for geometry tests.
	var source: Player = PLAYER_SCENE.instantiate() as Player
	var source_body: CollisionShape2D = source.get_node("CollisionShape2D") as CollisionShape2D
	var body: CollisionShape2D = CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.shape = source_body.shape.duplicate() as Shape2D
	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_child(body)
	add_child(player)
	source.free()
	var goblin: Goblin = GOBLIN_SCENE.instantiate() as Goblin
	goblin._configure_concrete_enemy()
	goblin.player_ref = player
	goblin.position = Vector2.ZERO
	goblin.blade_angle = 0.0
	goblin.blade_length = goblin.duelist_thrust_blade_length
	goblin.thrust_left = 0.2
	player.position = Vector2(90, 0)
	return {"player": player, "goblin": goblin}

func test_active_spear_hits_at_weapon_range_not_body_bump_range() -> void:
	var fixture: Dictionary = _fixture()
	var player: Node2D = fixture["player"] as Node2D
	var goblin: Goblin = fixture["goblin"] as Goblin
	assert(goblin.global_position.distance_to(player.global_position) > 30.0)
	assert(goblin._has_player_damage_contact(), "The visible thrust through the player must enter the existing damage path.")
	goblin.thrust_left = 0.0
	assert(not goblin._has_player_damage_contact(), "An idle spear is not a permanently damaging proximity aura.")
	goblin.thrust_left = 0.2
	goblin.disarmed = true
	assert(not goblin._has_player_damage_contact())
	goblin.disarmed = false
	goblin.stun_left = 0.2
	assert(not goblin._has_player_damage_contact(), "A parried/stunned spear must not keep attacking.")
	goblin.stun_left = 0.0
	goblin.health = goblin.max_health * goblin.duelist_retreat_health_percent
	assert(not goblin._has_player_damage_contact(), "Retreat must not reuse a stale thrust timer.")
	player.free()
	goblin.free()

func test_turned_away_out_of_reach_and_offset_player_collider_miss() -> void:
	var fixture: Dictionary = _fixture()
	var player: Node2D = fixture["player"] as Node2D
	var goblin: Goblin = fixture["goblin"] as Goblin
	goblin.blade_angle = PI
	assert(not goblin._has_player_damage_contact(), "Distance alone does not earn a spear hit.")
	goblin.blade_angle = 0.0
	player.position = Vector2(150, 0)
	assert(not goblin._has_player_damage_contact())
	player.position = Vector2(90, 0)
	var body: CollisionShape2D = player.get_node("CollisionShape2D") as CollisionShape2D
	body.position = Vector2(0, 40)
	assert(not goblin._has_player_damage_contact(), "Use the actual collider transform, not the sprite/root center.")
	body.position = Vector2.ZERO
	assert(goblin._has_player_damage_contact())
	body.disabled = true
	assert(not goblin._has_player_damage_contact())
	player.free()
	goblin.free()

func test_spear_head_matches_visible_tip_and_other_weapons_keep_length() -> void:
	var fixture: Dictionary = _fixture()
	var player: Node2D = fixture["player"] as Node2D
	var goblin: Goblin = fixture["goblin"] as Goblin
	var segment: Dictionary = goblin._enemy_weapon_segment()
	var expected_tip: float = goblin.weapon_origin_offset + goblin.blade_length + Enemy.SPEAR_SHAFT_EXTENSION + Enemy.SPEAR_HEAD_LENGTH
	assert(is_equal_approx((segment["end"] as Vector2).x, expected_tip))
	player.position = Vector2(expected_tip + 15.0, 0)
	assert(goblin._has_player_damage_contact(), "The rendered spearhead must not be outside its gameplay contact segment.")
	player.position.x = expected_tip + 20.0
	assert(not goblin._has_player_damage_contact(), "Do not extend damage beyond the visible spearhead and player radius.")
	var sword: Enemy = Enemy.new()
	sword.blade_length = 70.0
	var sword_segment: Dictionary = sword._enemy_weapon_segment()
	assert(is_equal_approx((sword_segment["end"] as Vector2).distance_to(sword_segment["start"] as Vector2), 70.0))
	sword.free()
	player.free()
	goblin.free()

func test_existing_body_bump_contact_is_unchanged() -> void:
	var fixture: Dictionary = _fixture()
	var player: Node2D = fixture["player"] as Node2D
	var goblin: Goblin = fixture["goblin"] as Goblin
	goblin.thrust_left = 0.0
	goblin.disarmed = true
	player.position = Vector2(29, 0)
	assert(goblin._has_player_damage_contact())
	player.position = Vector2(30, 0)
	assert(not goblin._has_player_damage_contact())
	player.free()
	goblin.free()
