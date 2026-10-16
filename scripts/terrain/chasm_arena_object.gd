class_name ChasmArenaObject extends ArenaObject

const GNARLED: Texture2D = preload("res://assets/generated/Gnarled Windswept Tree Asset.png")
const ANCIENT: Texture2D = preload("res://assets/generated/Windswept Ancient Fantasy Tree.png")
const IRON: Texture2D = preload("res://assets/generated/Rusty Iron Ore Rock Cluster.png")
const LOTUS: Texture2D = preload("res://assets/generated/Glowing Enchanted Lotus Plant.png")
const CRIMSON: Texture2D = preload("res://assets/generated/Magical Crimson Herb Bloom.png")
var ancient_tree: bool = false
var iron_ore: bool = true
var lotus_herb: bool = false

func _texture_for_kind() -> Texture2D:
	match object_kind:
		ObjectKind.TREE: return ANCIENT if ancient_tree else GNARLED
		ObjectKind.ROCK: return IRON if iron_ore else ROCK_TEXTURE
		ObjectKind.HERB: return LOTUS if lotus_herb else CRIMSON
	return super._texture_for_kind()

func _visual_size() -> Vector2:
	# Preserve uploaded proportions; herbs use the harvestable display envelope.
	var source: Vector2 = _texture_for_kind().get_size()
	var envelope: Vector2 = Vector2(190, 230) if object_kind == ObjectKind.TREE else Vector2(150, 108)
	if object_kind == ObjectKind.HERB: envelope = Vector2(72, 88) * 0.7
	return source * minf(envelope.x / source.x, envelope.y / source.y)

func visual_offset() -> Vector2:
	# Preserve the existing art anchor; contact offsets below account for the
	# asymmetric roots and source padding rather than moving the painting.
	return Vector2(0, -_visual_size().y * 0.5 + 12.0)

func local_visual_bounds() -> Rect2:
	return Rect2(visual_offset() - _visual_size() * 0.5, _visual_size())

func local_footprint() -> Rect2:
	# Source-image fractions measured against the solid contact silhouette, not
	# transparent margins/glow or canopy. The existing horizontal capsule is
	# shared by physical contact, grapple and its navigation AABB.
	var region: Rect2
	match object_kind:
		ObjectKind.TREE:
			region = Rect2(0.29, 0.86, 0.50, 0.12) if ancient_tree else Rect2(0.49, 0.84, 0.36, 0.12)
		ObjectKind.ROCK:
			region = Rect2(0.06, 0.65, 0.88, 0.26) if iron_ore else Rect2(0.16, 0.36, 0.68, 0.42)
		_:
			return Rect2(-Vector2(24, 24) * 0.7 * 0.5, Vector2(24, 24) * 0.7)
	var visual: Rect2 = local_visual_bounds()
	return Rect2(visual.position + region.position * visual.size, region.size * visual.size)

func _create_collision() -> void:
	footprint_size = local_footprint().size
	super._create_collision()
	if body != null: body.position = local_footprint().get_center()

func world_footprint() -> Rect2:
	# Before insertion the sampler uses local_footprint; once live the actual
	# collision shape is the authority (also used by grapple contact queries).
	if body != null and not broken: return world_collision_rect()
	var foot: Rect2 = local_footprint()
	return Rect2(global_position + foot.position, foot.size)

func _create_visual() -> void:
	super._create_visual()
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visual_sprite.position = visual_offset()

func _material_name() -> String:
	if object_kind == ObjectKind.ROCK and iron_ore: return "Iron Shard"
	if object_kind == ObjectKind.HERB:
		return "Gummy Blue Berries" if lotus_herb else "Spicy Red Berries"
	return super._material_name()
