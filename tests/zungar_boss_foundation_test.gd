class_name ZungarBossFoundationTest extends Node

const ZUNGAR_SCENE: PackedScene = preload("res://scenes/boss/zungar.tscn")

func test_boss_wave_and_primary_tuning_are_explicit() -> void:
	assert(ZungarConfig.BOSS_WAVE == 20, "Zungar should replace Forest Wave 20.")
	assert(ZungarConfig.MAX_HEALTH > 0.0, "Zungar needs explicit health tuning.")
	assert(ZungarConfig.SWORD_FIRE_DURATION >= 8.0 and ZungarConfig.SWORD_FIRE_DURATION <= 10.0, "Initial sword fire duration should match the encounter spec.")
	assert(ZungarConfig.CAMPFIRE_DISABLED_DURATION == 3.0, "Campfire downtime should be explicitly tunable.")

func test_zungar_scene_has_boss_collision_and_health_bar() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	assert(zungar.get_node_or_null("CollisionShape2D") != null, "Zungar needs a body collision shape.")
	assert(zungar.get_node_or_null("HealthBar") != null, "Zungar needs a visible health bar.")
	zungar.free()

func test_zungar_uses_hd_illustrated_animation_set() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	var visual: ZungarVisual = zungar.get_node_or_null("VisualRoot") as ZungarVisual
	var body_sprite: AnimatedSprite2D = zungar.get_node_or_null("VisualRoot/BodySprite") as AnimatedSprite2D
	assert(visual != null, "Zungar needs a dedicated illustrated visual controller.")
	assert(body_sprite != null and body_sprite.sprite_frames != null, "Zungar needs an illustrated AnimatedSprite2D body.")
	for animation_name: StringName in [&"idle", &"walk", &"charge", &"jump"]:
		assert(body_sprite.sprite_frames.has_animation(animation_name), "Missing Zungar animation: %s" % animation_name)
		assert(body_sprite.sprite_frames.get_frame_count(animation_name) == 3, "Each generated Zungar animation should contain its complete three-frame atlas.")
	zungar.free()

func test_executioner_sword_visual_matches_combat_segment() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	add_child(zungar)
	await get_tree().process_frame
	var visual: ZungarVisual = zungar.get_node("VisualRoot") as ZungarVisual
	var sword_sprite: Sprite2D = zungar.get_node("VisualRoot/WeaponPivot/ExecutionerSword") as Sprite2D
	var body_sprite: AnimatedSprite2D = zungar.get_node("VisualRoot/BodySprite") as AnimatedSprite2D
	assert(sword_sprite.texture != null, "Zungar's Executioner Sword needs illustrated art.")
	assert(is_equal_approx(body_sprite.scale.x, 0.186), "Zungar's illustrated body should use the new 25% smaller scale.")
	assert(is_equal_approx(zungar.weapon_origin_offset, 14.25), "Executioner Sword origin should shrink with Zungar.")
	assert(is_equal_approx(zungar.blade_length, 81.0), "Executioner Sword should be 20% larger than its post-scale size.")
	assert(is_equal_approx(zungar.blade_length, ZungarConfig.EXECUTIONER_SWORD_REACH), "Executioner Sword combat reach should use boss tuning.")
	var painted_length: float = float(sword_sprite.texture.get_width()) * sword_sprite.scale.x
	assert(is_equal_approx(painted_length, zungar.blade_length), "Painted sword length must match its combat segment.")
	assert(is_equal_approx(sword_sprite.position.x - painted_length * 0.5, zungar.weapon_origin_offset), "Painted sword hilt must begin at the weapon segment origin.")
	assert(is_equal_approx(sword_sprite.position.x + painted_length * 0.5, zungar.weapon_origin_offset + zungar.blade_length), "Painted sword tip must end at the combat segment tip.")
	assert(visual.has_required_animations(), "Zungar visual controller should validate its complete animation set.")
	zungar.queue_free()

func test_executioner_sword_preserves_slow_metronome_and_legacy_aliases() -> void:
	assert(ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET == 14.25, "Executioner Sword needs its configured close hand anchor.")
	assert(ZungarConfig.EXECUTIONER_SWORD_METRONOME_SPEED == 0.5, "Executioner Sword should retain the intentionally slow half-speed metronome.")
	assert(ZungarConfig.EXECUTIONER_SWORD_REACH == ZungarConfig.CLUB_REACH, "Legacy reach alias should remain compatible.")
	assert(ZungarConfig.EXECUTIONER_SWORD_DAMAGE == ZungarConfig.CLUB_DAMAGE, "Legacy damage alias should remain compatible.")
