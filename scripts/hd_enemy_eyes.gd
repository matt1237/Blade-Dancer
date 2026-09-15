class_name HDEnemyEyes extends Node2D
## Presentation only. Child of the actual sprite so all parent transforms apply.
const Anchors = preload("res://scripts/hd_enemy_eye_anchors.gd")
var actor: Node2D
var source: Node2D
var night: Node2D
var strength: float = 0.0

func _init() -> void:
	name = "NightEyes"
	z_as_relative = false
	z_index = 4001
	process_priority = 101
	visible = false

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(source):
		visible = false
		return
	if not is_instance_valid(night):
		var ancestor: Node = actor.get_parent()
		while ancestor != null:
			if ancestor.has_method("get_forest_visual_settings"):
				night = ancestor.get_node_or_null("ForestNightLighting") as Node2D
				break
			ancestor = ancestor.get_parent()
	var active: bool = is_instance_valid(night) and night.is_visible_in_tree()
	var amount: float = float(night.settings.get("night_strength", 0.0)) if active else 0.0
	present(amount, actor.call("_is_hd_visual"), float(actor.get("health")) > 0.0 and not bool(actor.get("death_emitted")) and not actor.is_queued_for_deletion())

func present(amount: float, hd: bool, alive: bool) -> void:
	strength = clampf(amount, 0.0, 1.0)
	visible = hd and alive and strength > 0.0001 and is_instance_valid(source) and source.is_visible_in_tree()
	queue_redraw()

func _draw() -> void:
	if not visible or not is_instance_valid(source):
		return
	var data: Dictionary = Anchors.registration(source)
	if data.is_empty():
		return
	var color: Color = data["color"]
	for point: Vector2 in data["points"]:
		draw_circle(point, 3.0, Color(color, strength * 0.10))
		draw_circle(point, 1.8, Color(color, strength * 0.24))
		draw_circle(point, 1.35, Color(color, strength))
