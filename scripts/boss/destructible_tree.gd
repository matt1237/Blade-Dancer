class_name DestructibleTree extends Node2D

@export_category("Destructible Tree Tuning")
## Health required for the player to cut this tree down.
@export var max_health: float = 90.0
## Damage dealt by the thrown tree projectile.
@export var thrown_damage: float = 48.0
## Whether Zungar may grab this tree for a throw or charge collision.
@export var can_be_used_by_boss: bool = true

var health: float = 90.0
var destroyed: bool = false
var being_thrown: bool = false

signal tree_destroyed(tree: DestructibleTree)

func _ready() -> void:
	add_to_group("zungar_trees")
	health = max_health
	queue_redraw()

func hit_by_sword(damage: float) -> void:
	if destroyed or being_thrown: return
	health = maxf(0.0, health - damage)
	if health <= 0.0:
		destroyed = true
		tree_destroyed.emit(self)
		queue_redraw()
	else:
		queue_redraw()

func take_for_throw() -> bool:
	if destroyed or being_thrown or not can_be_used_by_boss: return false
	being_thrown = true
	queue_redraw()
	return true

func break_from_charge() -> void:
	if destroyed: return
	destroyed = true
	tree_destroyed.emit(self)
	queue_redraw()

func _draw() -> void:
	if destroyed:
		draw_line(Vector2(-30.0, 14.0), Vector2(32.0, 14.0), Color("523824"), 9.0, true)
		draw_line(Vector2(-26.0, 7.0), Vector2(27.0, 18.0), Color("865533"), 4.0, true)
		return
	var trunk_color: Color = Color("74452f")
	var trunk_dark: Color = Color("422c2a")
	var leaf_color: Color = Color("315c3d")
	var leaf_light: Color = Color("527a45")
	draw_rect(Rect2(-7.0, -4.0, 14.0, 52.0), trunk_dark)
	draw_rect(Rect2(-4.0, -5.0, 9.0, 50.0), trunk_color)
	draw_circle(Vector2(-17.0, -22.0), 25.0, trunk_dark)
	draw_circle(Vector2(17.0, -24.0), 28.0, trunk_dark)
	draw_circle(Vector2(0.0, -42.0), 30.0, trunk_dark)
	draw_circle(Vector2(-16.0, -24.0), 20.0, leaf_color)
	draw_circle(Vector2(16.0, -26.0), 23.0, leaf_color)
	draw_circle(Vector2(0.0, -43.0), 25.0, leaf_color)
	draw_circle(Vector2(-8.0, -49.0), 9.0, leaf_light)
	draw_circle(Vector2(17.0, -35.0), 8.0, leaf_light)
