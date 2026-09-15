class_name SwordContactTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

## Body overlap alone cannot deal sword damage because the sword-hit loop first
## requires swept weapon geometry. No extra player-center exclusion should
## cancel a valid weapon hit once that geometric contact exists.
func test_sword_contact_has_no_player_center_exclusion() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	assert(player.enemy_body_contact_radius < 24.0, "Sword forgiveness should not recreate a body-sized hitbox.")
	assert(player.hilt_bash_blade_fraction > 0.0, "The hilt/pommel region must remain available for Hilt Bash.")
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(not source.contains("sword_hit_minimum_distance_from_player"), "Player-center distance must not override valid weapon geometry.")
	assert(not source.contains("BODY CONTACT IGNORED"), "Body proximity must not silently cancel a real sword contact.")
	var enemy: Enemy = Enemy.new()
	assert(enemy.weapon_origin_offset >= 14.0, "Enemy weapons should begin at the body edge instead of the center.")
	enemy.free()
	player.free()

func test_hilt_classification_uses_whole_curved_blade_position() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var samples: PackedVector2Array = PackedVector2Array([Vector2(0.0, 0.0), Vector2(42.0, 8.0), Vector2(84.0, 0.0)])
	var near_hilt_fraction: float = player._blade_path_fraction_for_segment(samples, 0, 0.2)
	var midpoint_fraction: float = player._blade_path_fraction_for_segment(samples, 1, 0.0)
	assert(near_hilt_fraction < player.hilt_bash_blade_fraction, "Contact near the grip should classify as Hilt Bash.")
	assert(midpoint_fraction > player.hilt_bash_blade_fraction, "Second-segment contact must not be misclassified as hilt contact on curved blades.")
	player.free()

## Player translation should provide only a small capped contribution to hit power.
## A dash or grapple by itself must not be mistaken for a full sword swing.
func test_player_movement_does_not_create_full_swing_power() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var movement_only_contact: SwordContactData = SwordInteractionResolver.swept_contact(Vector2(16.0, 0.0), Vector2(100.0, 0.0), Vector2(35.2, 0.0), Vector2(119.2, 0.0), Vector2(40.0, 0.0), player.enemy_body_contact_radius, 0.016, Vector2(1200.0, 0.0), player.sword_movement_damage_contribution, player.sword_movement_speed_cap)
	assert(movement_only_contact.relative_velocity.length() < 0.01, "Stationary sword geometry should have no relative swing speed.")
	assert(movement_only_contact.impact_speed < player.minimum_meaningful_swing_speed, "Movement alone must stay below full swing qualification.")
	assert(movement_only_contact.impact_speed <= player.sword_movement_speed_cap * player.sword_movement_damage_contribution + 0.01, "Movement credit must respect its cap.")
	player.free()

func test_frost_nova_scales_freeze_patch_and_cooldown() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	assert(BonusConfig.rank(player, "nova") == 0, "Frost Nova should begin unranked.")
	BonusConfig.apply_to_player(player, "nova")
	assert(BonusConfig.rank(player, "nova") == 1, "Frost Nova should apply its first rank.")
	assert(BonusConfig.frost_nova_stun(7) > BonusConfig.frost_nova_stun(1), "Higher ranks should freeze attackers longer.")
	assert(BonusConfig.frost_nova_radius(7) > BonusConfig.frost_nova_radius(1), "Higher ranks should create larger ice patches.")
	assert(BonusConfig.frost_nova_cooldown(7) < BonusConfig.frost_nova_cooldown(1), "Higher ranks should reduce Frost Nova cooldown.")
	player.free()

func test_bash_dash_is_registered_as_a_ranked_technique() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	assert(BonusConfig.rank(player, "bash_dash") == 0, "Bash Dash should begin unranked.")
	BonusConfig.apply_to_player(player, "bash_dash")
	assert(BonusConfig.rank(player, "bash_dash") == 1, "Bash Dash should apply its first rank.")
	assert(BonusConfig.bash_dash_damage(1) > 0.0, "Bash Dash rank should deal damage.")
	assert(BonusConfig.bash_dash_knockback(1) > 0.0, "Bash Dash rank should apply knockback.")
	assert(BonusConfig.bash_dash_stun(1) > 0.0, "Bash Dash rank should apply stun.")
	player.free()

func test_slide_mechanics_end_with_live_contact_while_visuals_only_tail() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	add_child(player)
	add_child(enemy)
	player.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.moving_weapon_enabled = true
	enemy.slide_flash_left = 1.2
	enemy.slide_visual_duration = 1.2
	player._trigger_blade_slide(Vector2.ZERO, enemy)
	assert(player.has_live_blade_slide_contact(enemy), "A classified Slide must begin as live mechanical contact.")
	assert(enemy.has_live_blade_slide_contact(), "The enemy must consume the player's single live Slide authority.")
	player._end_live_blade_slide()
	assert(not player.has_live_blade_slide_contact(enemy), "Player movement and blade drag must end immediately on release.")
	assert(not enemy.has_live_blade_slide_contact(), "Enemy movement friction must end with the same live state.")
	assert(player.preset_2_slide_visual_left <= 0.10, "Player Slide presentation may keep only a short release tail.")
	assert(enemy.slide_flash_left <= 0.10, "Enemy Slide presentation may keep only a short release tail.")
	player.free()
	enemy.free()
