class_name TrainingDummy extends Enemy

## Immortal wooden training dummy. Regenerates health, never drops below 1 HP.
## Used in the Backyard practice zone.

const REGEN_RATE: float = 10.0
const MIN_HEALTH: float = 1.0

var hit_flash_left: float = 0.0

func _ready() -> void:
	spawn_identity = &"training_dummy"
	participates_in_melee_engagement = false
	shield_enabled = false
	max_health = 1000.0
	contact_damage = 0.0
	score_value = 0
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = true
	add_to_group("enemies")
	add_to_group("training_dummy")

func _physics_process(delta: float) -> void:
	# The practice target ignores combat knockback, but consumes the same
	# additive grapple-force channel as every other non-boss enemy.
	velocity = knockback
	knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
	move_and_slide()
	hit_flash_left = maxf(0.0, hit_flash_left - delta)
	# Regenerate health.
	if health < max_health and health > 0.0:
		health = minf(health + REGEN_RATE * delta, max_health)
		health_bar.value = health
	queue_redraw()

func take_damage(amount: float, _force: Vector2 = Vector2.ZERO, _stagger_duration: float = 0.0, _impact_quality: float = 0.0) -> void:
	if health <= 0.0: return
	health -= amount
	if health < MIN_HEALTH:
		health = MIN_HEALTH
	health_bar.value = health
	# Visual feedback — brief flash.
	hit_flash_left = 0.12

func _draw() -> void:
	var wood_color: Color = Color("b8945c")
	var dark_wood: Color = Color("6b4e2e")
	var ring_color: Color = Color("8b6914")
	var base_color: Color = Color("5a3d24")
	
	# Base post — vertical wooden beam.
	draw_rect(Rect2(-8.0, 30.0, 16.0, 50.0), base_color)
	draw_rect(Rect2(-6.0, 30.0, 12.0, 48.0), dark_wood)
	
	# Main body — tall rounded trunk.
	draw_rect(Rect2(-14.0, -38.0, 28.0, 70.0), dark_wood)
	draw_rect(Rect2(-11.0, -36.0, 22.0, 66.0), wood_color)
	
	# Wood grain lines on body.
	for grain_y: int in range(-30, 30, 10):
		draw_line(Vector2(-9.0, float(grain_y)), Vector2(9.0, float(grain_y)), Color("a07840"), 1.0)
	
	# Horizontal arm pegs — left and right.
	draw_rect(Rect2(-36.0, -16.0, 22.0, 8.0), dark_wood)
	draw_rect(Rect2(14.0, -16.0, 22.0, 8.0), dark_wood)
	draw_rect(Rect2(-34.0, -15.0, 18.0, 6.0), wood_color)
	draw_rect(Rect2(16.0, -15.0, 18.0, 6.0), wood_color)
	
	# Lower arm pegs.
	draw_rect(Rect2(-30.0, 8.0, 18.0, 7.0), dark_wood)
	draw_rect(Rect2(12.0, 8.0, 18.0, 7.0), dark_wood)
	draw_rect(Rect2(-28.0, 9.0, 14.0, 5.0), wood_color)
	draw_rect(Rect2(14.0, 9.0, 14.0, 5.0), wood_color)
	
	# Head — rounded top piece.
	draw_circle(Vector2(0.0, -42.0), 12.0, dark_wood)
	draw_circle(Vector2(0.0, -42.0), 9.0, wood_color)
	draw_circle(Vector2(0.0, -42.0), 5.0, ring_color)
	
	# Target rings on the body (classic training dummy look).
	for ring_index: int in range(3):
		var ring_y: float = -22.0 + float(ring_index) * 16.0
		draw_arc(Vector2(0.0, ring_y), 10.0, 0.0, TAU, 16, ring_color, 2.0)
	
	# Neck ring.
	draw_rect(Rect2(-13.0, -46.0, 26.0, 5.0), dark_wood)
	draw_rect(Rect2(-11.0, -45.0, 22.0, 3.0), ring_color)
	
	# Hit flash.
	if hit_flash_left > 0.0:
		draw_circle(Vector2(0.0, -10.0), 24.0, Color(1.0, 1.0, 1.0, hit_flash_left * 0.4))
