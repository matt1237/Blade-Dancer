class_name ZungarSwordBehaviorTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const ZUNGAR_SCENE: PackedScene = preload("res://scenes/boss/zungar.tscn")

func _make_zungar_with_player() -> Array[Node]:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(640.0, 360.0)
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	add_child(zungar)
	zungar.set_physics_process(false)
	zungar.global_position = Vector2(640.0, 360.0)
	zungar.blade_angle = 0.0
	zungar.player_ref = player
	return [player, zungar]

func test_zungar_uses_shared_moving_weapon_capability_without_goblin_ai() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	assert(zungar.spawn_identity == &"zungar", "Zungar must retain its own boss identity.")
	assert(not zungar.shield_enabled, "Zungar must not inherit Ogre's shield or Chakram blocking.")
	assert(zungar.moving_weapon_enabled, "Zungar must opt into the shared moving-weapon contact/slide/parry/clash capability.")
	assert(zungar.grapple_weight == Enemy.GrappleWeight.HEAVY, "Zungar must be a stable Heavy grapple target that pulls the player toward him.")
	assert(zungar.parry_enabled, "Zungar's shared parry behavior must be explicitly enabled.")
	assert(zungar.state == Zungar.State.INTRO, "Moving-weapon capability must not replace Zungar's custom boss state machine.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_zungar_blade_supports_contact_slide_block_and_clash() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	var crossing_start: Vector2 = Vector2(700.0, 330.0)
	var crossing_end: Vector2 = Vector2(700.0, 390.0)
	assert(zungar.is_blade_contact(crossing_start, crossing_end, 7.0), "A player blade crossing Zungar's live sword must register blade contact.")
	assert(zungar.is_blade_blocking(crossing_start, crossing_end, 22.0), "Zungar's live sword must block a crossing player blade.")
	assert(zungar.is_blade_clashing(Vector2(700.0, 330.0), Vector2(730.0, 360.0)), "A crossing-angle blade must qualify for a Zungar clash.")
	var slide_start: Vector2 = Vector2(680.0, 360.0)
	var slide_end: Vector2 = Vector2(730.0, 360.0)
	assert(zungar.try_blade_slide(slide_start, slide_end, Vector2(100.0, 0.0), 1), "A nearly parallel blade must slide along Zungar's sword like it does against a goblin.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_charge_stun_captures_live_angle_and_hand_anchor_is_inward() -> void:
	var zungar_source: String = FileAccess.get_file_as_string("res://scripts/boss/zungar.gd")
	assert(zungar_source.contains("locked_blade_angle = blade_angle"), "Charge stun must capture the live sword angle instead of reusing a stale lock.")
	assert(ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET == 14.25, "The sword hand anchor should be moved inward by 15px.")

func test_zungar_parry_and_clash_apply_recoil_and_stun() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	zungar.parry_blade(Vector2(650.0, 330.0), Vector2(650.0, 390.0), Vector2(120.0, 20.0), 1)
	assert(zungar.state == Zungar.State.STUNNED, "A parry must put Zungar into his impaired state.")
	assert(zungar.stun_left > 0.0, "A parry must apply stagger time to Zungar.")
	assert(zungar.knockback.length() > 0.0, "A parry must produce recoil on Zungar.")
	assert(is_equal_approx(zungar.blade_length, ZungarConfig.EXECUTIONER_SWORD_REACH), "Parry presentation must preserve the 90px Executioner Sword reach.")
	zungar.state = Zungar.State.CHASE
	zungar.stun_left = 0.0
	zungar.knockback = Vector2.ZERO
	zungar.clash_latched = false
	zungar.weapon_clash(Vector2(120.0, 20.0), 1)
	assert(zungar.state == Zungar.State.STUNNED, "A clash must put Zungar into his impaired state.")
	assert(zungar.stun_left > 0.0, "A clash must apply stagger time to Zungar.")
	assert(zungar.knockback.length() > 0.0, "A clash must produce recoil on Zungar.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_form_three_weapon_beat_uses_shared_displacement_without_health_damage() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	zungar.state = Zungar.State.CHASE
	var health_before: float = zungar.health
	zungar.receive_weapon_beat(Vector2(180.0, 80.0), 0.22, 90.0)
	assert(zungar.state == Zungar.State.STUNNED, "Zungar must translate shared weapon-beat impairment into his custom boss state.")
	assert(zungar.stun_left >= 0.22 and zungar.knockback.length() > 0.0, "The Executioner Sword must physically yield to a valid leveraged beat.")
	assert(is_equal_approx(zungar.health, health_before), "Weapon beats must never become free boss health damage.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_shared_weapon_timers_recover_for_custom_boss_loops() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	zungar.slide_flash_left = 0.4
	zungar.slide_visual_time = 0.0
	zungar.sword_parry_cooldown_left = 1.5
	zungar.clash_cooldown_left = 1.0
	zungar.tick_moving_weapon_combat(0.25)
	assert(is_equal_approx(zungar.slide_flash_left, 0.15), "Shared slide duration must tick in custom boss loops.")
	assert(is_equal_approx(zungar.slide_visual_time, 0.25), "Shared slide visuals must advance in custom boss loops.")
	assert(is_equal_approx(zungar.sword_parry_cooldown_left, 1.25), "Shared parry cooldown must recover in custom boss loops.")
	assert(is_equal_approx(zungar.clash_cooldown_left, 0.75), "Shared clash cooldown must recover in custom boss loops.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_normal_sword_damage_interrupts_zungar_custom_ability_state() -> void:
	var actors: Array[Node] = _make_zungar_with_player()
	var zungar: Zungar = actors[1] as Zungar
	zungar.state = Zungar.State.CHARGING
	zungar.take_damage(1.0, Vector2(80.0, 0.0), 0.35, 0.5)
	assert(zungar.state == Zungar.State.STUNNED, "Sword-hit stagger must interrupt Zungar's custom charge/jump/spear state.")
	assert(zungar.stun_left >= 0.35, "Sword-hit stagger duration must reach the shared reaction state.")
	assert(zungar.knockback.x > 0.0, "Sword-hit force must produce physical boss recoil.")
	actors[1].queue_free()
	actors[0].queue_free()

func test_training_tools_expose_a_focused_zungar_sword_spawn() -> void:
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(menu_source.contains("Spawn Zungar (Sword Test)"), "Training Tools Enemies tab must expose a focused Zungar sword-test button.")
	assert(menu_source.contains("spawn_training_zungar"), "Training Tools must call the dedicated Zungar training spawn path.")
	assert(main_source.contains("func spawn_training_zungar()"), "Main must provide a dedicated non-wave Zungar training spawn.")
	assert(main_source.contains("boss.training_mode = true"), "Training Zungar must be marked training-only.")
