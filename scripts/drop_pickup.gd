class_name DropPickup extends Area2D

var rarity: ItemConfig.Rarity = ItemConfig.Rarity.NORMAL
var item_name: String = "Coins"
var quantity: int = 1
var zone_wave: int = 1
var lifetime: float = 18.0

## World rewind (WorldRewindRecorder contract). Collect/expire retire instead of freeing while
## a world-rewind host records, so an undone pickup returns to the ground. `collected` is part
## of the recorded state: restoring to a moment before collection gives the item back to the
## world AND takes it back out of inventory (Main.uncollect_drop), so nothing duplicates.
const REWIND_GAMEPLAY_GROUPS: Array[StringName] = [&"pickups"]
var rewind_retired: bool = false
var collected: bool = false

func _ready() -> void:
	add_to_group(&"pickups")
	add_to_group(WorldRewindRecorder.REWINDABLE_GROUP)

func setup(item: String, amount: int, wave: int) -> void:
	item_name = item
	quantity = amount
	zone_wave = wave
	rarity = ItemConfig.rarity(item_name)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if rewind_retired:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		WorldRewindRecorder.retire_or_free(self, REWIND_GAMEPLAY_GROUPS)
		return
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node2D = players[0] as Node2D
		if player != null and global_position.distance_to(player.global_position) < 28.0:
			var main_scene: Node = _main_scene()
			if main_scene != null and main_scene.has_method("collect_drop"): main_scene.collect_drop(item_name, quantity)
			collected = true
			WorldRewindRecorder.retire_or_free(self, REWIND_GAMEPLAY_GROUPS)
			return
	queue_redraw()

## Main spawns drops as its own children; fall back to the running scene.
func _main_scene() -> Node:
	var parent: Node = get_parent()
	if parent != null and parent.has_method("collect_drop"): return parent
	return get_tree().current_scene if is_inside_tree() else null

func rewind_stride() -> int:
	return 4

func rewind_capture(d: PackedFloat32Array, o: int) -> void:
	d[o] = global_position.x; d[o + 1] = global_position.y; d[o + 2] = lifetime; d[o + 3] = 1.0 if collected else 0.0

func rewind_restore(d: PackedFloat32Array, o: int) -> void:
	global_position = Vector2(d[o], d[o + 1]); lifetime = d[o + 2]
	var was_collected: bool = d[o + 3] > 0.5
	if collected and not was_collected:
		# Collected after the restore instant: take it back out of inventory.
		var main_scene: Node = _main_scene()
		if main_scene != null and main_scene.has_method("uncollect_drop"): main_scene.uncollect_drop(item_name, quantity)
	collected = was_collected
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
