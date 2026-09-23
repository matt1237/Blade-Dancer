class_name GoblinChakramDamageTest extends Node

func test_new_goblin_variants_have_readable_chakram_collision_radius() -> void:
	for scene: PackedScene in [WaveSpawner.ARCHER_GOBLIN_SCENE, WaveSpawner.SWORD_GOBLIN_SCENE]:
		var enemy: Enemy = scene.instantiate() as Enemy
		var shape_node: CollisionShape2D = enemy.get_node("CollisionShape2D") as CollisionShape2D
		var shape: CircleShape2D = shape_node.shape as CircleShape2D
		assert(shape != null)
		assert(shape.radius >= 22.0, "New Goblin HD silhouette needs a Chakram-readable body radius.")
		enemy.free()

func test_chakram_swept_contact_reaches_new_goblin_visible_body_edge() -> void:
	var visible_edge_offset: float = 39.0 # 22px enemy body + 20px Chakram radius overlap.
	assert(Chakram.swept_circle_contact(Vector2(-60.0, visible_edge_offset), Vector2(60.0, visible_edge_offset), Vector2.ZERO, 42.0))
