class_name HDEnemyEyeAnchors extends RefCounted
## Manually registered from enlarged source PNGs, frame-local pixel centers.
## Order is the authored atlas frame order, NOT an interpolated head position.
## Turkey is profile (one eye). Bug points are on the small head, not its luminous abdomen.
## Blue bug fly frame 3 has its far eye occluded; deliberately only one point.
const FRAMES: Dictionary = {
	"turkey_idle": [[Vector2(30,34)], [Vector2(34,27)], [Vector2(22,46)], [Vector2(26,39)]],
	"turkey_walk": [[Vector2(25,42)], [Vector2(26,42)], [Vector2(23,42)], [Vector2(28,42)]],
	"duelist_idle": [[Vector2(70,32),Vector2(79,32)], [Vector2(71,27),Vector2(80,27)], [Vector2(68,38),Vector2(77,38)], [Vector2(69,26),Vector2(77,26)]],
	"duelist_walk": [[Vector2(73,27),Vector2(81,27)], [Vector2(70,25),Vector2(78,25)], [Vector2(74,27),Vector2(82,27)], [Vector2(75,26),Vector2(83,26)]],
	"blue_bug_idle": [[Vector2(88,75),Vector2(101,75)], [Vector2(90,75),Vector2(103,75)], [Vector2(87,75),Vector2(100,76)], [Vector2(87,75),Vector2(99,76)]],
	"blue_bug_fly": [[Vector2(79,83),Vector2(92,85)], [Vector2(88,84),Vector2(100,86)], [Vector2(80,83),Vector2(91,86)], [Vector2(88,83)]],
	"warg_idle": [[Vector2(26,57),Vector2(39,57)], [Vector2(27,72),Vector2(40,71)], [Vector2(21,69),Vector2(35,69)]],
	"warg_charge": [[Vector2(18,53),Vector2(31,53)], [Vector2(17,57),Vector2(29,57)], [Vector2(18,66),Vector2(32,66)]],
	"elite_idle": [[Vector2(79,35),Vector2(87,36)], [Vector2(77,15),Vector2(85,14)], [Vector2(79,53),Vector2(87,53)]],
	"elite_march": [[Vector2(84,28),Vector2(92,28)], [Vector2(85,24),Vector2(92,24)], [Vector2(84,27),Vector2(91,27)]]
}

static func tint(key: String) -> Color:
	if key.begins_with("duelist") or key.begins_with("elite"):
		return Color("ff4935")
	# Existing ranged bug spits blue magic and has cyan source-art eyes.
	if key.begins_with("blue_bug"):
		return Color("79edff")
	return Color("ffe177")

static func registration(sprite: Node2D) -> Dictionary:
	var texture: Texture2D
	var region: Rect2
	if sprite is AnimatedSprite2D:
		if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
			return {}
		texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	elif sprite is Sprite2D:
		texture = sprite.texture
	else:
		return {}
	if texture == null:
		return {}
	if texture is AtlasTexture:
		region = texture.region
		texture = texture.atlas
	elif sprite is Sprite2D:
		region = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture.get_size())
		region.size /= Vector2(sprite.hframes, sprite.vframes)
		region.position += Vector2(sprite.frame_coords) * region.size
	else:
		return {}
	var key: String = texture.resource_path.get_file().get_basename().trim_prefix("hd_enemy_")
	if not FRAMES.has(key):
		return {}
	var width: float = 160.0 if key.begins_with("warg") or key.begins_with("elite") else 128.0
	var index: int = int(region.position.x / width)
	if index < 0 or index >= FRAMES[key].size():
		return {}
	var points: PackedVector2Array = PackedVector2Array()
	for anchor: Vector2 in FRAMES[key][index]:
		# AtlasTexture frames can also be displayed by a static Sprite2D.
		var p: Vector2 = anchor + Vector2(index * width, 0) - region.position
		if not Rect2(Vector2.ZERO, region.size).has_point(p):
			continue
		points.append(local_point(p, region.size, sprite.centered, sprite.offset, sprite.flip_h, sprite.flip_v))
	return {"points": points, "color": tint(key), "key": key, "frame": index}

static func local_point(p: Vector2, size: Vector2, centered: bool, offset: Vector2, flip_h: bool, flip_v: bool) -> Vector2:
	return Vector2(size.x - p.x if flip_h else p.x, size.y - p.y if flip_v else p.y) + offset - (size * 0.5 if centered else Vector2.ZERO)
