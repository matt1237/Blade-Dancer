class_name ArenaObject extends Node2D

const TREE_CANOPY_SCRIPT: Script = preload("res://scripts/terrain/tree_canopy_overlay.gd")
const ROCK_TEXTURE: Texture2D = preload("res://assets/generated/forest_rock_cluster_frame_0.png")
const TREE_TEXTURE: Texture2D = preload("res://assets/generated/forest_border_tree_cluster_frame_0.png")
const LOG_TEXTURE: Texture2D = preload("res://assets/generated/forest_fallen_log_horizontal_frame_0.png")
const HERB_TEXTURE: Texture2D = preload("res://assets/generated/forest_flower_patch_frame_0.png")
const MUSHROOM_TEXTURE: Texture2D = preload("res://assets/generated/cauldron_catch_mushroom_frame_0.png")
const SHRUB_TEXTURE: Texture2D = preload("res://assets/generated/forest_border_shrub_cluster_frame_0.png")
const TORCH_TEXTURE: Texture2D = preload("res://assets/generated/forest_torch_frame_0.png")
const MOON_FLOWER_TEXTURE: Texture2D = preload("res://assets/generated/forest_moon_flower_frame_0.png")
const CHEST_TEXTURE: Texture2D = preload("res://assets/generated/forest_chest_closed_frame_0.png")

enum ObjectKind { ROCK, TREE, LOG, HERB, MUSHROOM, SHRUB, TORCH, MOON_FLOWER, CHEST }

@export var object_kind: ObjectKind = ObjectKind.ROCK
@export var max_health: float = 60.0
@export var footprint_size: Vector2 = Vector2(96.0, 72.0)
@export var blocks_navigation: bool = false
@export var chakram_breakable: bool = false
@export var sword_harvestable: bool = false

var health: float = 0.0
var broken: bool = false
var hit_flash_left: float = 0.0
var body: StaticBody2D = null
var canopy_alpha: float = 1.0
var player_ref: Node2D = null
var canopy_overlay: TreeCanopyOverlay = null
var visual_sprite: Sprite2D = null
var drop_spawned: bool = false
var phase_visible: bool = true

signal object_broken(object: ArenaObject)
signal harvested(object: ArenaObject)

func _ready() -> void:
	health = max_health
	add_to_group("arena_objects")
	if chakram_breakable:
		add_to_group("chakram_obstructions")
	if sword_harvestable:
		add_to_group("sword_farmables")
	if object_kind == ObjectKind.MOON_FLOWER:
		add_to_group("night_lights")
	if object_kind == ObjectKind.TREE:
		var players: Array[Node] = get_tree().get_nodes_in_group("player")
		if not players.is_empty(): player_ref = players[0] as Node2D
	_create_visual()
	_create_collision()

func _process(delta: float) -> void:
	hit_flash_left = maxf(0.0, hit_flash_left - delta)
	if object_kind == ObjectKind.TREE and is_instance_valid(player_ref):
		var brush_center: Vector2 = global_position + Vector2(0.0, -34.0)
		var inside_brush: bool = player_ref.global_position.distance_to(brush_center) < 58.0
		canopy_alpha = move_toward(canopy_alpha, 0.34 if inside_brush else 1.0, delta * 5.0)
	_update_damage_visual()

func _create_visual() -> void:
	visual_sprite = Sprite2D.new()
	visual_sprite.name = "AuthoredVisual"
	visual_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual_sprite.texture = _texture_for_kind()
	visual_sprite.z_as_relative = false
	visual_sprite.z_index = 3 if object_kind == ObjectKind.TREE else 1
	visual_sprite.scale = _visual_size() / visual_sprite.texture.get_size() if visual_sprite.texture != null else Vector2.ONE
	add_child(visual_sprite)

func _texture_for_kind() -> Texture2D:
	match object_kind:
		ObjectKind.ROCK: return ROCK_TEXTURE
		ObjectKind.TREE: return TREE_TEXTURE
		ObjectKind.LOG: return LOG_TEXTURE
		ObjectKind.HERB: return HERB_TEXTURE
		ObjectKind.MUSHROOM: return MUSHROOM_TEXTURE
		ObjectKind.SHRUB: return SHRUB_TEXTURE
		ObjectKind.TORCH: return TORCH_TEXTURE
		ObjectKind.MOON_FLOWER: return MOON_FLOWER_TEXTURE
		ObjectKind.CHEST: return CHEST_TEXTURE
	return null

func _visual_size() -> Vector2:
	match object_kind:
		ObjectKind.ROCK: return Vector2(150.0, 108.0)
		ObjectKind.TREE: return Vector2(190.0, 230.0)
		ObjectKind.LOG: return Vector2(190.0, 72.0)
		ObjectKind.HERB: return Vector2(64.0, 64.0)
		ObjectKind.MUSHROOM: return Vector2(48.0, 48.0)
		ObjectKind.SHRUB: return Vector2(122.0, 92.0)
		ObjectKind.TORCH: return Vector2(64.0, 104.0)
		ObjectKind.MOON_FLOWER: return Vector2(72.0, 88.0)
		ObjectKind.CHEST: return Vector2(76.0, 64.0)
	return Vector2(64.0, 64.0)

func _update_damage_visual() -> void:
	if broken or visual_sprite == null: return
	visual_sprite.modulate = Color(1.25, 1.25, 1.25, canopy_alpha) if hit_flash_left > 0.0 else Color(1.0, 1.0, 1.0, canopy_alpha)

func _spawn_material_drop() -> void:
	if drop_spawned: return
	drop_spawned = true
	var main_scene: Node = get_tree().current_scene
	if object_kind == ObjectKind.CHEST:
		if main_scene != null and main_scene.has_method("spawn_chest_loot"):
			main_scene.spawn_chest_loot(global_position)
	elif main_scene != null and main_scene.has_method("spawn_terrain_drop"):
		main_scene.spawn_terrain_drop(global_position, _material_name(), _material_quantity())
	if main_scene != null and main_scene.has_method("refresh_population_navigation"):
		main_scene.refresh_population_navigation()

func _material_name() -> String:
	match object_kind:
		ObjectKind.ROCK: return "Stone"
		ObjectKind.TREE, ObjectKind.LOG, ObjectKind.TORCH: return "Wood"
		ObjectKind.HERB, ObjectKind.SHRUB: return "Forest Herb"
		ObjectKind.MUSHROOM: return "Mushroom"
		ObjectKind.MOON_FLOWER: return "Moon Petal"
	return "Stone"

func _material_quantity() -> int:
	return 2 if object_kind in [ObjectKind.ROCK, ObjectKind.TREE, ObjectKind.LOG] else 1

func _create_collision() -> void:
	if not blocks_navigation or broken:
		return
	body = StaticBody2D.new()
	body.name = "ObstructionBody"
	body.collision_layer = 4
	body.collision_mask = 0
	var shape_node: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = footprint_size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func set_phase_visible(value: bool) -> void:
	phase_visible = value
	if not broken:
		visible = phase_visible

func world_footprint() -> Rect2:
	return Rect2(global_position - footprint_size * 0.5, footprint_size)

func world_collision_rect() -> Rect2:
	if body != null and is_instance_valid(body):
		for child: Node in body.get_children():
			var collision: CollisionShape2D = child as CollisionShape2D
			if collision == null or collision.disabled or not collision.shape is RectangleShape2D:
				continue
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			var half_size: Vector2 = rectangle.size * collision.global_transform.get_scale().abs() * 0.5
			return Rect2(collision.global_position - half_size, half_size * 2.0)
	# Unsupported or shapeless objects are not valid wrap geometry.
	return Rect2()

func world_blocking_rects() -> Array[Rect2]:
	return [world_footprint()] if blocks_navigation and not broken else []

func hit_by_chakram(damage: float, _impact_velocity: Vector2 = Vector2.ZERO) -> bool:
	if broken or not chakram_breakable:
		return false
	health = maxf(0.0, health - damage)
	hit_flash_left = 0.10
	if health <= 0.0:
		broken = true
		_remove_collision()
		if visual_sprite != null: visual_sprite.visible = false
		visible = false
		_spawn_material_drop()
		object_broken.emit(self)
	_update_damage_visual()
	return true

func hit_by_sword(damage: float) -> bool:
	if broken or (not sword_harvestable and not chakram_breakable):
		return false
	health = maxf(0.0, health - damage)
	hit_flash_left = 0.10
	if health <= 0.0:
		broken = true
		_remove_collision()
		if visual_sprite != null: visual_sprite.visible = false
		visible = false
		harvested.emit(self)
		_spawn_material_drop()
		object_broken.emit(self)
	_update_damage_visual()
	return true

func _remove_collision() -> void:
	if body == null: return
	body.collision_layer = 0
	body.collision_mask = 0
	for child: Node in body.get_children():
		var shape_node: CollisionShape2D = child as CollisionShape2D
		if shape_node != null: shape_node.set_deferred("disabled", true)
	body.queue_free()
	body = null

func _draw() -> void:
	return

func _legacy_draw() -> void:
	if broken:
		_draw_broken()
		return
	var tint: Color = Color.WHITE if hit_flash_left <= 0.0 else Color(1.35, 1.35, 1.35, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match object_kind:
		ObjectKind.ROCK:
			_draw_rock(tint)
		ObjectKind.LOG:
			_draw_log(tint)
		ObjectKind.TREE:
			_draw_tree(tint)
		ObjectKind.HERB:
			_draw_herb(tint)
		ObjectKind.MUSHROOM:
			_draw_mushroom(tint)
		ObjectKind.SHRUB:
			_draw_shrub(tint)
		ObjectKind.TORCH:
			_draw_torch(tint)

func _draw_broken() -> void:
	if object_kind == ObjectKind.TREE or object_kind == ObjectKind.LOG:
		draw_line(Vector2(-44.0, 10.0), Vector2(44.0, 10.0), Color("503526"), 12.0, true)
		draw_line(Vector2(-38.0, 4.0), Vector2(40.0, 16.0), Color("93613b"), 4.0, true)
	elif object_kind == ObjectKind.ROCK:
		draw_circle(Vector2.ZERO, 25.0, Color("4b4a50"))
		draw_circle(Vector2(-13.0, -4.0), 8.0, Color("77747a"))
	else:
		draw_circle(Vector2.ZERO, 8.0, Color(0.25, 0.18, 0.12, 0.6))

func _draw_rock(tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2(-48, 16), Vector2(-38, -20), Vector2(-12, -35), Vector2(30, -28), Vector2(50, 8), Vector2(32, 28), Vector2(-24, 30)])
	draw_colored_polygon(points, Color("42434a") * tint)
	draw_polyline(points, Color("20232d"), 5.0, true)
	draw_line(Vector2(-23, -15), Vector2(18, -24), Color("77737a") * tint, 5.0, true)

func _draw_log(tint: Color) -> void:
	draw_rect(Rect2(-52, -13, 104, 26), Color("422b25") * tint, true)
	draw_rect(Rect2(-45, -8, 90, 12), Color("855536") * tint, true)
	draw_circle(Vector2(-50, 0), 14.0, Color("b07848") * tint)

func _draw_tree(tint: Color) -> void:
	draw_rect(Rect2(-9, -3, 18, 64), Color("3b2926") * tint, true)
	draw_rect(Rect2(-5, -5, 11, 60), Color("77472e") * tint, true)

func _draw_herb(tint: Color) -> void:
	for offset: float in [-7.0, 0.0, 7.0]:
		draw_line(Vector2(0, 8), Vector2(offset, -9), Color("527b42") * tint, 3.0, true)
	draw_circle(Vector2(-7, -10), 4.0, Color("a1c45a") * tint)
	draw_circle(Vector2(7, -9), 4.0, Color("8eaf4d") * tint)

func _draw_mushroom(tint: Color) -> void:
	draw_rect(Rect2(-3, -2, 6, 13), Color("e5c7a0") * tint, true)
	draw_circle(Vector2.ZERO, 12.0, Color("81474b") * tint)
	draw_circle(Vector2(-4, -4), 2.0, Color("e8bd86") * tint)
	draw_circle(Vector2(4, -2), 2.0, Color("e8bd86") * tint)

func _draw_shrub(tint: Color) -> void:
	draw_circle(Vector2(-17, 0), 18.0, Color("244832") * tint)
	draw_circle(Vector2(0, -10), 22.0, Color("315d3b") * tint)
	draw_circle(Vector2(19, 1), 17.0, Color("244832") * tint)

func _draw_torch(tint: Color) -> void:
	draw_rect(Rect2(-4, -2, 8, 36), Color("4a3024") * tint, true)
	draw_circle(Vector2(0, -12), 13.0, Color(1.0, 0.55, 0.14, 0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -9), Vector2(0, -29), Vector2(8, -9)]), Color("f5a33d") * tint)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -10), Vector2(0, -23), Vector2(4, -10)]), Color("fff0a1") * tint)
