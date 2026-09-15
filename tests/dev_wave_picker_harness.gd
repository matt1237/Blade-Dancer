class_name DevWavePickerHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	await get_tree().process_frame
	await get_tree().process_frame
	main._travel_home()
	main.home_menu.call("show_tab", HomeMenu.Tab.DEV_WAVE)
