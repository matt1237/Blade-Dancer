class_name EnemySpawnMenuTest extends Node

func test_enemies_tab_scrolls_and_contains_bomber_spawn() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu.add_child(tabs)
	menu._build_enemy_tab(tabs)
	var scroll: ScrollContainer = tabs.get_node("Enemies") as ScrollContainer
	assert(scroll != null)
	assert(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED)
	var list: VBoxContainer = scroll.get_node("SpawnList") as VBoxContainer
	var bomber_found: bool = false
	for child: Node in list.get_children():
		var button: Button = child as Button
		if button != null and button.text == "Spawn Goblin Bomber":
			bomber_found = true
			assert(button.pressed.get_connections().size() == 1)
	assert(bomber_found)
	menu.free()
