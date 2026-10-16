class_name KajiShopPanelTest extends Node

func test_transparent_text_and_compact_button_scope() -> void:
	var menu: TownMenu = TownMenu.new()
	menu.progression = HomeProgression.new()
	add_child(menu)
	menu.open_general()
	assert(menu.general_page.get_theme_stylebox("panel") is StyleBoxEmpty)
	assert(menu.funds.get_theme_stylebox("normal") is StyleBoxEmpty)
	assert(menu.funds.get_theme_color("font_shadow_color").a > 0.0)
	assert(menu.funds.get_theme_constant("outline_size") > 0)
	assert(menu.buy_tab.size == Vector2(120,42))
	assert(menu.shop_back_button.size.x <= 150)
	menu.fit_general_page(Vector2(1280,720))
	assert((menu.general_page.get_node("KajiPortrait") as TextureRect).size == Vector2(238,280))
	var surface: StyleBoxFlat = menu.buy_tab.get_theme_stylebox("normal") as StyleBoxFlat
	assert(surface.bg_color.a < 1.0 and surface.corner_radius_top_left > 0)
	assert(menu.funds.get_theme_color("font_color") == TownMenu.SHOP_INK)
	assert((menu.buy_rows.get_child(0) as Label).get_theme_color("font_color") == TownMenu.SHOP_INK)
	assert(menu.town_page.theme == null and menu.blacksmith_page.theme == menu.general_page.theme)
	# Warm readable text, with surfaces confined to actual controls.
	assert(menu.buy_tab.get_theme_color("font_color").a == 1.0)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert(menu.buy_tab.get_theme_stylebox(state) != null)
	menu.free()

func test_responsive_lists_minimums_and_scroll() -> void:
	var preview: GeneralStorePreview = preload("res://tests/general_store_preview.tscn").instantiate() as GeneralStorePreview
	add_child(preview)
	var menu: TownMenu = preview.menu
	# Long inventories exercise the same row styles and scrollbar as production.
	for i: int in range(20):
		menu._add_trade_row(menu.buy_rows, "Turkey", true)
	menu._refresh_trade_rows()
	for viewport_size: Vector2 in [Vector2(1280,720), Vector2(960,540), Vector2(1024,768), Vector2(720,1280), Vector2(560,600), Vector2(1280,720)]:
		menu.fit_general_page(viewport_size)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(menu.general_page.size == viewport_size - Vector2(32,32))
		assert(menu.modulate.a == 1.0 and menu.general_page.modulate.a == 1.0)
		assert(menu.funds.modulate.a == 1.0 and menu.funds.get_theme_color("font_color").a == 1.0)
		assert((menu.general_page.get_node("KajiPortrait") as TextureRect).modulate.a == 1.0)
		assert(not menu.clip_contents and not preview.hub.clip_contents)
		assert(menu.general_page.size.y <= viewport_size.y - 32)
		assert(menu.buy_page.size == menu.sell_page.size)
		assert(menu.buy_tab.position.x + menu.buy_tab.size.x < menu.sell_tab.position.x)
		assert(menu.shop_back_button.position.y + menu.shop_back_button.size.y <= menu.general_page.size.y)
		var scroll: ScrollContainer = menu.buy_rows.get_parent() as ScrollContainer
		assert(scroll.size.y > 60)
		assert(menu.buy_page.size.x <= 500)
		assert(menu.buy_page.position.x + menu.buy_page.size.x <= menu.general_page.size.x)
		assert(menu.buy_tab.size.x == 120 and menu.sell_tab.size.x == 120)
		assert(menu.shop_back_button.size.x <= 150)
		var portrait: TextureRect = menu.general_page.get_node("KajiPortrait") as TextureRect
		assert(portrait.size.x >= 180 and portrait.size.y >= 180)
		if viewport_size.x >= 800:
			assert(portrait.position.x + portrait.size.x < menu.buy_page.position.x)
		else:
			assert(portrait.position.y + portrait.size.y < menu.buy_tab.position.y)
		assert(scroll.position.y + scroll.size.y <= menu.buy_page.size.y)
		assert(menu.buy_page.position.y + menu.buy_page.size.y <= menu.feedback.position.y)
		menu._select_general_page(false)
		await get_tree().process_frame
		await get_tree().process_frame
		var current_sell_scroll: ScrollContainer = menu.rows.get_parent() as ScrollContainer
		assert(current_sell_scroll.size == scroll.size)
		assert(menu.rows.size.x <= current_sell_scroll.size.x)
		assert(current_sell_scroll.position.y + current_sell_scroll.size.y <= menu.sell_page.size.y)
		menu._select_general_page(true)
		await get_tree().process_frame
		await get_tree().process_frame
		assert(menu.buy_rows.size.x <= scroll.size.x, "No horizontal row clipping")
		assert(menu.buy_rows.size.y > scroll.size.y, "Long lists must scroll")
		for row: Dictionary in menu.trade_rows:
			var trade: Button = row["trade"] as Button
			assert(trade.size.x >= trade.get_combined_minimum_size().x)
			assert(trade.size.x <= 170 and trade.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN)
			assert((row["title"] as Label).get_theme_stylebox("normal") is StyleBoxEmpty)
			assert((row["right"] as Button).size.x == 32)
			assert((row["title"] as Label).get_theme_color("font_color") == TownMenu.SHOP_INK)
			assert((row["right"] as Button).get_theme_color("font_color") == TownMenu.ARROW_YELLOW)
	assert(menu.general_page.size == Vector2(1248,688))
	menu._select_general_page(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var sell_scroll: ScrollContainer = menu.rows.get_parent() as ScrollContainer
	assert(sell_scroll.size == (menu.buy_rows.get_parent() as ScrollContainer).size)
	assert(menu.rows.size.x <= sell_scroll.size.x)
	assert(menu.sell_page.position.y + menu.sell_page.size.y <= menu.feedback.position.y)
	for row: Dictionary in menu.trade_rows:
		assert((row["trade"] as Button).modulate.a == 1.0)
		assert((row["title"] as Label).get_theme_color("font_color").a == 1.0)
	preview.free()
