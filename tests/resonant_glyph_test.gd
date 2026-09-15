class_name ResonantGlyphTest extends Node

const GLYPH_SCENE: PackedScene = preload("res://scenes/resonant_glyph.tscn")
const CHAKRAM_SCENE: PackedScene = preload("res://scenes/chakram.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/turkey.tscn")

func _ready() -> void:
	test_rank_progression()
	test_segment_bounce_geometry()
	test_glyph_does_not_block_movement_layers()
	test_chakram_pulse_damages_and_slows_enemies()
	print("Resonant Glyph tests passed")
	get_tree().quit()

func test_rank_progression() -> void:
	assert(BonusConfig.all_bonus_ids().has("resonant_glyph"), "Resonant Glyph must be a selectable technique.")
	assert(BonusConfig.resonant_glyph_cooldown(1) == 10.0, "Rank 1 must start with a ten-second spawn cooldown.")
	assert(BonusConfig.resonant_glyph_duration(1) == 10.0, "Rank 1 must last ten seconds.")
	assert(BonusConfig.resonant_glyph_max_active(1) == 1, "Rank 1 must allow one active glyph.")
	assert(BonusConfig.resonant_glyph_max_active(5) == 3, "Higher ranks must reach three active glyphs.")
	assert(BonusConfig.resonant_glyph_cooldown(7) < BonusConfig.resonant_glyph_cooldown(1), "Cooldown must shorten with rank.")
	assert(BonusConfig.resonant_glyph_duration(7) > BonusConfig.resonant_glyph_duration(1), "Lifetime must grow with rank.")

func test_segment_bounce_geometry() -> void:
	var glyph: ResonantGlyph = GLYPH_SCENE.instantiate() as ResonantGlyph
	glyph.global_position = Vector2(100.0, 100.0)
	var hit: Dictionary = glyph.segment_hit(Vector2(20.0, 100.0), Vector2(180.0, 100.0), 15.0)
	assert(not hit.is_empty(), "A Chakram path crossing a glyph must report a hit.")
	var normal: Vector2 = hit["normal"] as Vector2
	assert(normal.x < -0.9, "The bounce normal must face the incoming side of the glyph.")
	var miss: Dictionary = glyph.segment_hit(Vector2(20.0, 180.0), Vector2(180.0, 180.0), 15.0)
	assert(miss.is_empty(), "A path outside the glyph radius must miss.")
	glyph.free()

func test_glyph_does_not_block_movement_layers() -> void:
	var glyph: ResonantGlyph = GLYPH_SCENE.instantiate() as ResonantGlyph
	assert(glyph.collision_layer == 16, "Glyph collision must stay on the grapple/interaction layer.")
	assert(glyph.collision_mask == 0, "Glyph must not scan or physically block movement bodies.")
	glyph.free()

func test_chakram_pulse_damages_and_slows_enemies() -> void:
	var test_root: Node2D = Node2D.new()
	add_child(test_root)
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var glyph: ResonantGlyph = GLYPH_SCENE.instantiate() as ResonantGlyph
	test_root.add_child(glyph)
	glyph.global_position = Vector2(100.0, 100.0)
	glyph.setup(null, 1)
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	test_root.add_child(enemy)
	enemy.global_position = Vector2(150.0, 100.0)
	var chakram: Chakram = CHAKRAM_SCENE.instantiate() as Chakram
	test_root.add_child(chakram)
	glyph.on_chakram_hit(chakram, Vector2.RIGHT * 500.0)
	assert(is_equal_approx(enemy.health, enemy.max_health - 10.0), "A glyph pulse must deal its configured Rank 1 damage.")
	assert(is_equal_approx(float(enemy.terrain_movement_modifiers[glyph.get_instance_id()]), 0.90), "A glyph pulse must apply its configured slow.")
	assert(glyph.pulse_left > 0.0, "A Chakram strike must start the glyph soundwave visual.")
	get_tree().current_scene = previous_scene
	test_root.free()
