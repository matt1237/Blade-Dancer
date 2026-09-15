class_name GearDropPickup extends Area2D
## Chest loot pickup. Parallel to DropPickup but carries a full rolled gear
## item Dictionary (see armory_config.gd) instead of a name+quantity, since
## every gear drop is a unique instance with its own rolled technique ranks.

var item: Dictionary = {}
var lifetime: float = 24.0

func setup(gear_item: Dictionary) -> void:
	item = gear_item
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0] as Node2D
		if player != null and global_position.distance_to(player.global_position) < 30.0:
			var main_scene: Node = get_tree().current_scene
			if main_scene.has_method("collect_gear_drop"): main_scene.collect_gear_drop(item)
			queue_free()
	queue_redraw()

func _draw() -> void:
	# A brighter, gilded twin of the material drop bag so a gear find reads
	# as a step up from an ordinary resource pickup.
	var gold: Color = Color("f1c34a")
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -6.0), Vector2(-7.0, -12.0), Vector2(7.0, -12.0),
		Vector2(11.0, -6.0), Vector2(10.0, 10.0), Vector2(5.0, 15.0),
		Vector2(-5.0, 15.0), Vector2(-10.0, 10.0)
	]), Color("463420"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -4.5), Vector2(-4.5, -8.0), Vector2(4.5, -8.0),
		Vector2(8.0, -4.5), Vector2(7.0, 8.0), Vector2(3.5, 12.0),
		Vector2(-3.5, 12.0), Vector2(-7.0, 8.0)
	]), gold)
	draw_rect(Rect2(-9.0, -7.0, 18.0, 4.5), Color("2e2214"), true)
	draw_rect(Rect2(-5.5, -6.0, 11.0, 2.2), gold.lightened(0.25), true)
	draw_circle(Vector2(0.0, 1.0), 3.2, Color(1.0, 0.94, 0.72, 0.85))
