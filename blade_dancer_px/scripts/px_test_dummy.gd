extends RefCounted
## PX TEST DUMMY — a stationary, regenerating damage target for the prototype.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")


static func make_entry(parent: Node, position: Vector2) -> Dictionary:
	var body := CharacterBody2D.new()
	body.name = "TestDummy"
	body.collision_layer = Cfg.L_ENEMY
	body.collision_mask = Cfg.L_WALLS | Cfg.L_PLAYER
	body.position = position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Cfg.ENEMY_RADIUS
	shape.shape = circle
	body.add_child(shape)
	parent.add_child(body)
	return {
		"body": body,
		"armed": false,
		"hp": Cfg.TEST_DUMMY_MAX_HEALTH,
		"max_hp": Cfg.TEST_DUMMY_MAX_HEALTH,
		"hit_cd": 0.0,
		"touch_cd": 0.0,
		"flash": 0.0,
		"anchor": null,
		"sword": null,
		"sword_hit_cd": 0.0,
		"test_dummy": true,
		"regen_accum": 0.0,
	}


static func apply_damage(entry: Dictionary, amount: float) -> void:
	entry["hp"] = maxf(Cfg.TEST_DUMMY_MIN_HEALTH, float(entry["hp"]) - maxf(0.0, amount))


static func tick_regeneration(entry: Dictionary, delta: float) -> void:
	entry["regen_accum"] = float(entry["regen_accum"]) + delta
	while float(entry["regen_accum"]) >= Cfg.TEST_DUMMY_REGEN_INTERVAL:
		entry["regen_accum"] = float(entry["regen_accum"]) - Cfg.TEST_DUMMY_REGEN_INTERVAL
		entry["hp"] = minf(Cfg.TEST_DUMMY_MAX_HEALTH, float(entry["hp"]) + Cfg.TEST_DUMMY_REGEN_AMOUNT)
	entry["hp"] = clampf(float(entry["hp"]), Cfg.TEST_DUMMY_MIN_HEALTH, Cfg.TEST_DUMMY_MAX_HEALTH)
