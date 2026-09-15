class_name DropPickup extends Area2D

var rarity: ItemConfig.Rarity = ItemConfig.Rarity.NORMAL
var item_name: String = "Coins"
var quantity: int = 1
var zone_wave: int = 1
var lifetime: float = 18.0

func setup(item: String, amount: int, wave: int) -> void:
	item_name = item
	quantity = amount
	zone_wave = wave
	rarity = ItemConfig.rarity(item_name)
	queue_redraw()

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0] as Node2D
		if player != null and global_position.distance_to(player.global_position) < 28.0:
			var main_scene: Node = get_tree().current_scene
			if main_scene.has_method("collect_drop"): main_scene.collect_drop(item_name, quantity)
			queue_free()
	queue_redraw()

func _draw() -> void:
	var bag_color: Color = ItemConfig.bag_color(rarity)
	# Every resource shares one silhouette; color alone communicates rarity.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, -5.0), Vector2(-6.0, -10.0), Vector2(6.0, -10.0),
		Vector2(10.0, -5.0), Vector2(9.0, 9.0), Vector2(5.0, 13.0),
		Vector2(-5.0, 13.0), Vector2(-9.0, 9.0)
	]), ItemConfig.BAG_OUTLINE)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, -4.0), Vector2(-4.0, -7.0), Vector2(4.0, -7.0),
		Vector2(7.0, -4.0), Vector2(6.0, 7.0), Vector2(3.0, 10.0),
		Vector2(-3.0, 10.0), Vector2(-6.0, 7.0)
	]), bag_color)
	draw_rect(Rect2(-8.0, -6.0, 16.0, 4.0), ItemConfig.BAG_OUTLINE, true)
	draw_rect(Rect2(-5.0, -5.0, 10.0, 2.0), bag_color.lightened(0.18), true)
	draw_rect(Rect2(-3.0, 0.0, 3.0, 6.0), ItemConfig.BAG_HIGHLIGHT, true)
