extends Node2D
## Deterministic presentation-only bench using the real bomb scene and timing.
## No Main/save/PX/AI involvement. Frozen fire samples hide the burst so the
## ground base is readable; the fourth sample runs the complete attack normally.
const BOMB_SCENE: PackedScene = preload("res://scenes/projectiles/bomber_bomb.tscn")

func _ready() -> void:
	for index: int in range(4):
		var bomb: BomberBomb = BOMB_SCENE.instantiate() as BomberBomb
		add_child(bomb)
		var target: Vector2 = Vector2(150 + index * 240, 280)
		bomb.arm(target + Vector2(0, -120), target, null)
		if index < 3:
			bomb.advance_attack(0.0 if index == 0 else BomberBomb.EXPLODE_TIME + (0.6 if index == 2 else 0.0))
			bomb.process_mode = Node.PROCESS_MODE_DISABLED
			if index > 0:
				bomb.explosion_sprite.visible = false
			print("FOOTPRINT sample=", index, " center=", bomb.global_position, " scale=", bomb.fire_sprite.scale, " base_offset=", bomb.fire_sprite.position)
