extends GoblinBomberRig
## Real Main combat bench plus independently sliced frames for boundary inspection.
var _strip: CanvasLayer = null
var _last_pose: String = ""

func _process(delta: float) -> void:
	super._process(delta)
	for enemy: Enemy in _tracked:
		var bomber: GoblinBomber = enemy as GoblinBomber
		if not is_instance_valid(bomber) or bomber.hd_enemy_sprite == null: continue
		var frames: SpriteFrames = bomber.hd_enemy_sprite.sprite_frames
		if _strip == null:
			_strip = CanvasLayer.new()
			_strip.layer = 100
			add_child(_strip)
			for index: int in range(6):
				var sprite: Sprite2D = Sprite2D.new()
				sprite.texture = frames.get_frame_texture("bomb_windup" if index < 3 else "bomb_throw", index % 3)
				sprite.position = Vector2(120 + index * 150, 590)
				sprite.scale = Vector2.ONE * 0.5
				_strip.add_child(sprite)
		var pose: String = str(bomber.hd_enemy_sprite.animation)
		if pose != _last_pose:
			var elapsed: float = bomber.attack_bomb.elapsed if is_instance_valid(bomber.attack_bomb) else -1.0
			print("[BOMBER ANIMATION] %s frame=%d bomb_elapsed=%.3f" % [pose, bomber.hd_enemy_sprite.frame, elapsed])
			_last_pose = pose
