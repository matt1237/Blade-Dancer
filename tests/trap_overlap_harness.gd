class_name TrapOverlapHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	await get_tree().process_frame
	await get_tree().process_frame
	var traps: Array[Node] = get_tree().get_nodes_in_group("terrain_traps")
	if traps.is_empty():
		print("TRAP OVERLAP HARNESS: no trap generated")
		return
	var trap: Node2D = traps[0] as Node2D
	main.player.global_position = trap.global_position
	main.player.set_physics_process(false)
	main.spawner.set_process(false)
	print("TRAP OVERLAP z player=", main.player.z_index, " trap=", trap.z_index, " trap_relative=", trap.z_as_relative, " parent_z=", trap.get_parent().z_index)
