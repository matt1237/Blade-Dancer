class_name HDEyeArtReview extends Node2D
## Actual overlay review: all 36 registered frames. Space toggles day/night;
## F mirrors sprites (including registered points), preserving the original layout.
const Anchors = preload("res://scripts/hd_enemy_eye_anchors.gd")
const Eyes = preload("res://scripts/hd_enemy_eyes.gd")
var sprites: Array[Sprite2D] = []
var overlays: Array[Node2D] = []
var strength: float = 1.0
func _ready() -> void:
	var atlases: Array[String] = ["turkey_idle", "turkey_walk", "duelist_idle", "duelist_walk", "blue_bug_idle", "blue_bug_fly", "warg_idle", "warg_charge", "elite_idle", "elite_march"]
	for i: int in range(atlases.size()):
		var atlas: Texture2D = load("res://assets/generated/hd_enemy_%s.png" % atlases[i])
		var count: int = Anchors.FRAMES[atlases[i]].size()
		for f: int in range(count):
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = atlas
			sprite.hframes = count
			sprite.frame = f
			sprite.centered = false
			sprite.position = Vector2(10 + (i % 2) * 630 + f * (float(atlas.get_width()) / count), 12 + floori(float(i) / 2.0) * 132)
			add_child(sprite)
			var eyes: HDEnemyEyes = Eyes.new()
			eyes.source = sprite
			sprite.add_child(eyes)
			eyes.set_process(false)
			sprites.append(sprite)
			overlays.append(eyes)
	refresh()
func refresh() -> void:
	for i in range(sprites.size()):
		sprites[i].self_modulate = Color(0.38,0.38,0.45) if strength > 0 else Color.WHITE
		overlays[i].present(strength, true, true)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F:
			for sprite in sprites:
				sprite.flip_h = not sprite.flip_h
		else:
			strength = 1.0 - strength
		refresh()
