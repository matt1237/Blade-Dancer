extends Node
## Real HomeMenu fixture, in-memory progression only; never starts Main or saves.

func _rows(menu: HomeMenu, text: String) -> Array[HBoxContainer]:
	var result: Array[HBoxContainer] = []
	for child: Node in menu.armory_lists.get_children():
		if child is HBoxContainer and (child.get_child(0) as Button).text == text:
			result.append(child as HBoxContainer)
	return result

func _assert_marker(row: HBoxContainer, equipped: bool) -> void:
	var marker: Label = row.get_node("EquippedLabel") as Label
	assert(marker.text == "Equipped", "Status must be readable text, not only color.")
	assert(marker.visible == equipped)
	assert(marker.get_theme_font_size("font_size") == 14)
	assert(marker.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert((row.get_child(0) as Button).button_pressed == equipped)

func test_equipped_markers_follow_unique_ids_refresh_and_reload() -> void:
	var menu: HomeMenu = (load("res://scenes/ui/home_menu.tscn") as PackedScene).instantiate() as HomeMenu
	add_child(menu)
	var progression: HomeProgression = HomeProgression.new()
	for slot: String in ArmoryConfig.GEAR_SLOTS:
		var base_name: String = str((ArmoryConfig.SLOT_ITEM_POOL[slot] as Array)[0])
		for suffix: String in ["a", "b"]:
			progression.add_gear_item({"id": slot + suffix, "slot": slot, "base_name": base_name, "techniques": {"defense": 1}, "value": 100})
	menu.configure(progression)
	menu.show_tab(HomeMenu.Tab.ARMORY)
	for slot: String in ArmoryConfig.GEAR_SLOTS:
		var text: String = ArmoryConfig.display_label(progression.gear_item_by_id(slot + "a"))
		var rows: Array[HBoxContainer] = _rows(menu, text)
		assert(rows.size() == 2, "Identical variants must remain separate rows.")
		_assert_marker(rows[0], false)
		_assert_marker(rows[1], false)
		(rows[0].get_child(0) as Button).emit_signal("pressed")
		assert(progression.equipped_gear_ids[slot] == slot + "a")
		rows = _rows(menu, text)
		_assert_marker(rows[0], true)
		_assert_marker(rows[1], false)
		(rows[1].get_child(0) as Button).emit_signal("pressed")
		rows = _rows(menu, text)
		_assert_marker(rows[0], false)
		_assert_marker(rows[1], true)
		# Selecting/hovering another item is not equipping it.
		(rows[0].get_child(0) as Button).emit_signal("mouse_entered")
		menu.refresh()
		rows = _rows(menu, text)
		_assert_marker(rows[0], false)
		_assert_marker(rows[1], true)
		var reloaded: HomeProgression = HomeProgression.new()
		reloaded.load_save_data(progression.to_save_data())
		progression = reloaded
		menu.configure(progression)
		rows = _rows(menu, text)
		_assert_marker(rows[0], false)
		_assert_marker(rows[1], true)
		var default_text: String = "%s  [BASE]" % progression.default_slot_label(slot)
		(_rows(menu, default_text)[0].get_child(0) as Button).emit_signal("pressed")
		rows = _rows(menu, text)
		_assert_marker(rows[0], false)
		_assert_marker(rows[1], false)
		var default_marker: Label = _rows(menu, default_text)[0].get_node("EquippedLabel") as Label
		assert(default_marker.visible == (slot != "Ring"), "Empty Ring is not an equipped item.")
	menu.queue_free()
