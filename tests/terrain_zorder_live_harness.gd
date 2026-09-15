class_name TerrainZorderLiveHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	await get_tree().process_frame
	await get_tree().process_frame
	var generator: ArenaGenerator = main.get_node("ArenaGenerator") as ArenaGenerator
	generator.config.guarantee_bear_trap = true
	generator.config.guarantee_mud_patch = true
	generator.generation_seed = 9001
	generator.regenerate()
	# Deferred _ready() calls on freshly instantiated trap/wall nodes need at least
	# one more real frame to settle before their live z_index can be trusted.
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Player = main.get_node("Player") as Player
	print("LIVE ZORDER player_z=", player.z_index)
	for module_node: Node in get_tree().get_nodes_in_group("terrain_modules"):
		var kind: String = "TRAP" if module_node.is_in_group("terrain_traps") else "WALL"
		print("LIVE ZORDER kind=", kind, " name=", module_node.name, " z_index=", module_node.z_index)
