class_name TownMenu extends Panel

signal adventure_requested
signal shop_presentation_changed(active: bool)
signal blacksmith_presentation_changed(active: bool)
signal shrine_presentation_changed(active: bool)
const SHRINE_MENU_SCRIPT: Script = preload("res://scripts/ui/shrine_menu.gd")
var shrine_page: ShrineMenu

func shrine_is_open() -> bool:
	return is_instance_valid(shrine_page) and shrine_page.visible and is_visible_in_tree()

func open_shrine() -> void:
	town_page.hide()
	general_page.hide()
	blacksmith_page.hide()
	shrine_page.progression = progression
	shrine_page.show()
	shrine_page.select_page("Exchange")
	_sync_shop_presentation()


func shop_is_open() -> bool:
	var general_open: bool = is_instance_valid(general_page) and general_page.visible
	return general_open and is_visible_in_tree()

func blacksmith_store_is_open() -> bool:
	return is_instance_valid(blacksmith_page) and blacksmith_page.visible and is_visible_in_tree()

func _sync_shop_presentation() -> void:
	if shop_is_open() or blacksmith_store_is_open() or shrine_is_open(): add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else: remove_theme_stylebox_override("panel")
	shop_presentation_changed.emit(shop_is_open())
	blacksmith_presentation_changed.emit(blacksmith_store_is_open())
	shrine_presentation_changed.emit(shrine_is_open())
const KAJI_PORTRAIT: Texture2D = preload("res://assets/portraits/Kaji.png")
const JIMBO_PORTRAIT: Texture2D = preload("res://assets/portraits/Jimbo.png")
var progression: HomeProgression = null
var sell_callback: Callable
var buy_callback: Callable
var smith_sell_callback: Callable
var smith_buy_callback: Callable
var smith_active: bool = false
var merchant_buy_pages: Dictionary = {false: true, true: true}
var buy_notice: Label
var buy_rows: VBoxContainer
var buy_page: Control
var sell_page: Control
var buy_tab: Button
var sell_tab: Button
var selected_buy_page: bool = true
var quantities: Dictionary = {}
var trade_rows: Array[Dictionary] = []
var inventory_view: Dictionary = {}
const ARROW_YELLOW: Color = Color("ffd94d")
# Retained for comparison with the rejected paper treatment; not applied.
const SHOP_PAPER: Color = Color(1.0, 0.98, 0.93, 0.25)
const SHOP_INK: Color = Color("f8eed8")
var shop_title: Label
var greeting: Label
var shop_back_button: Button
var town_page: Control
var general_page: Control
var blacksmith_page: Control
var jimbo_portrait: TextureRect
var blacksmith_back_button: Button
var blacksmith_title: Label
var blacksmith_greeting: Label
var blacksmith_notice: Label
var funds: Label
var feedback: Label
var rows: VBoxContainer
var refresh_wait: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	town_page = Control.new()
	add_child(town_page)
	_label(town_page, "TOWN", Vector2(24, 18), Vector2(704, 38), 26)
	_button(town_page, "General", Vector2(200, 110), Vector2(352, 64), open_general)
	_button(town_page, "Blacksmiths", Vector2(200, 190), Vector2(352, 64), open_blacksmiths)
	_button(town_page, "Shrine", Vector2(200, 270), Vector2(352, 64), open_shrine)
	_button(town_page, "Back to Adventure", Vector2(200, 350), Vector2(352, 50), func() -> void: adventure_requested.emit())
	general_page = Panel.new()
	# Only actual buttons have a surface. Text and the page leave the room clear.
	var shop_theme: Theme = Theme.new()
	shop_theme.set_color("font_color", "Label", SHOP_INK)
	shop_theme.set_stylebox("normal", "Label", StyleBoxEmpty.new())
	shop_theme.set_color("font_shadow_color", "Label", Color("20170f"))
	shop_theme.set_constant("shadow_offset_x", "Label", 1)
	shop_theme.set_constant("shadow_offset_y", "Label", 2)
	shop_theme.set_color("font_outline_color", "Label", Color("20170f"))
	shop_theme.set_constant("outline_size", "Label", 3)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var control_style: StyleBoxFlat = StyleBoxFlat.new()
		control_style.bg_color = Color("66513c") if state == "hover" else (Color("765c3c") if state == "pressed" else Color("45382c"))
		control_style.bg_color.a = 0.82
		control_style.set_corner_radius_all(6)
		shop_theme.set_stylebox(state, "Button", control_style)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		shop_theme.set_color(state, "Button", Color("f8eed8"))
	general_page.theme = shop_theme
	(general_page as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	general_page.size = Vector2(514, 480)
	general_page.visibility_changed.connect(_sync_shop_presentation)
	visibility_changed.connect(_sync_shop_presentation)
	general_page.name = "GeneralPage"
	add_child(general_page)
	shop_title = _label(general_page, "KAJI — GENERAL", Vector2(20, 12), Vector2(300, 32), 26)
	var portrait: TextureRect = TextureRect.new()
	portrait.name = "KajiPortrait"
	portrait.position = Vector2(20, 48)
	portrait.size = Vector2(238, 280)
	portrait.texture = KAJI_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	general_page.add_child(portrait)
	funds = _label(general_page, "", Vector2(100, 48), Vector2(394, 44), 16)
	greeting = _label(general_page, "Welcome! Got anything to trade?", Vector2(20, 348), Vector2(238, 44), 16)
	buy_tab = _button(general_page, "Buy", Vector2(20, 116), Vector2(233, 42), _select_general_page.bind(true))
	buy_tab.name = "BuyTab"
	buy_tab.toggle_mode = true
	sell_tab = _button(general_page, "Sell", Vector2(261, 116), Vector2(233, 42), _select_general_page.bind(false))
	sell_tab.name = "SellTab"
	sell_tab.toggle_mode = true
	buy_page = Control.new()
	buy_page.name = "BuyPage"
	buy_page.position = Vector2(20, 160)
	buy_page.size = Vector2(474, 228)
	general_page.add_child(buy_page)
	sell_page = Control.new()
	sell_page.name = "SellPage"
	sell_page.position = buy_page.position
	sell_page.size = buy_page.size
	general_page.add_child(sell_page)
	buy_notice = _label(buy_page, "Restocks 1 every 40 min, max 5", Vector2.ZERO, Vector2(474, 24), 16)
	buy_notice.tooltip_text = "Discovered common goods restock offline too. No extra stock is banked at max 5. Permanent recipes/upgrades never restock."
	buy_rows = _goods_list(buy_page, Vector2(0, 28), Vector2(474, 200))
	_label(sell_page, "Choose quantity with yellow arrows", Vector2.ZERO, Vector2(474, 24), 16)
	rows = _goods_list(sell_page, Vector2(0, 28), Vector2(474, 200))
	_select_general_page(selected_buy_page)
	feedback = _label(general_page, "", Vector2(20, 390), Vector2(474, 40), 13)
	shop_back_button = _button(general_page, "← Town", Vector2(20, 434), Vector2(150, 38), open_town)
	shop_back_button.tooltip_text = "Back to Town"
	fit_general_page(get_viewport_rect().size)
	blacksmith_page = Panel.new()
	blacksmith_page.theme = shop_theme
	(blacksmith_page as Panel).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	blacksmith_page.name = "BlacksmithPage"
	add_child(blacksmith_page)
	blacksmith_title = _label(blacksmith_page, "JIMBO — BLACKSMITH", Vector2(20, 12), Vector2(300, 32), 26)
	jimbo_portrait = TextureRect.new()
	jimbo_portrait.name = "JimboPortrait"
	jimbo_portrait.texture = JIMBO_PORTRAIT
	jimbo_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	jimbo_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	jimbo_portrait.position = Vector2(24, 84)
	jimbo_portrait.size = Vector2(200, 240)
	blacksmith_page.add_child(jimbo_portrait)
	blacksmith_greeting = _label(blacksmith_page, "The forge is warm.", Vector2(20, 348), Vector2(238, 48), 16)
	blacksmith_notice = _label(blacksmith_page, "Found / forged gear only. Equipped gear is reserved.\nSkill infusions do not increase prices.", Vector2(20, 396), Vector2(238, 40), 13)
	blacksmith_page.visibility_changed.connect(_sync_shop_presentation)
	blacksmith_back_button = _button(blacksmith_page, "← Town", Vector2(20, 434), Vector2(150, 38), open_town)
	blacksmith_back_button.tooltip_text = "Back to Town"
	fit_blacksmith_page(get_viewport_rect().size)
	shrine_page = SHRINE_MENU_SCRIPT.new() as ShrineMenu
	shrine_page.theme = shop_theme
	add_child(shrine_page)
	shrine_page.town_requested.connect(open_town)
	shrine_page.visibility_changed.connect(_sync_shop_presentation)
	open_town()

func fit_general_page(viewport_size: Vector2) -> void:
	_fit_trade_page(viewport_size, general_page, shop_title, greeting, general_page.get_node("KajiPortrait") as TextureRect, shop_back_button)

func _fit_trade_page(viewport_size: Vector2, host: Control, title: Label, hello: Label, portrait: TextureRect, back: Button) -> void:
	# Keep responsive bounds, but never stretch button surfaces across the room.
	var dimensions: Vector2 = Vector2(maxf(1.0, viewport_size.x - 32.0), maxf(1.0, viewport_size.y - 32.0))
	host.size = dimensions
	var narrow: bool = viewport_size.x < 800.0
	var content_width: float = minf(500.0, maxf(1.0, dimensions.x - (40.0 if narrow else 300.0)))
	var content_x: float = 20.0 if narrow else dimensions.x - content_width - 20.0
	var tab_y: float = 286.0 if narrow else 82.0
	portrait.position = Vector2(20, 90 if narrow else 68)
	portrait.size = Vector2(180, 180) if narrow else Vector2(238, 280)
	title.size = Vector2(minf(300.0, dimensions.x - 40.0), 32)
	funds.position = Vector2(content_x, 48 if narrow else 12)
	funds.size = Vector2(content_width, 48)
	hello.position = Vector2(220, 148) if narrow else Vector2(20, 348)
	hello.size = Vector2(maxf(1.0, dimensions.x - 240.0), 64) if narrow else Vector2(238, 48)
	buy_tab.position = Vector2(content_x, tab_y)
	sell_tab.position = Vector2(content_x + 128.0, tab_y)
	buy_tab.size = Vector2(120, 42)
	sell_tab.size = Vector2(120, 42)
	for page: Control in [buy_page, sell_page]:
		page.position = Vector2(content_x, tab_y + 50.0)
		page.size = Vector2(content_width, maxf(29.0, dimensions.y - 90.0 - page.position.y))
		for child: Node in page.get_children():
			if child is Label: (child as Label).size.x = content_width
			elif child is ScrollContainer: (child as ScrollContainer).size = Vector2(content_width, page.size.y - 28.0)
	feedback.position = Vector2(content_x, dimensions.y - 86.0)
	feedback.size = Vector2(content_width, 40)
	back.position = Vector2(20, dimensions.y - 42.0)
	back.size = Vector2(150, 38)

func fit_blacksmith_page(viewport_size: Vector2) -> void:
	_fit_trade_page(viewport_size, blacksmith_page, blacksmith_title, blacksmith_greeting, jimbo_portrait, blacksmith_back_button)
	blacksmith_notice.visible = viewport_size.x >= 800.0
	# Both hosts resize, but the shared trade panel must use its active host last.
	if not smith_active: fit_general_page(viewport_size)

func _select_general_page(buying: bool) -> void:
	selected_buy_page = buying
	merchant_buy_pages[smith_active] = buying
	buy_page.visible = buying
	sell_page.visible = not buying
	buy_tab.set_pressed_no_signal(buying)
	sell_tab.set_pressed_no_signal(not buying)

func _goods_list(parent: Control, pos: Vector2, dimensions: Vector2) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.position = pos
	scroll.size = dimensions
	parent.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.size = dimensions
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	if parent != general_page and parent != blacksmith_page and parent != buy_page and parent != sell_page:
		label.add_theme_color_override("font_color", Color("f1cf78") if font_size >= 26 else Color("d7eab5"))
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func open_town() -> void:
	if is_instance_valid(shrine_page): shrine_page.hide()
	town_page.visible = true
	general_page.visible = false
	blacksmith_page.visible = false
	blacksmith_presentation_changed.emit(false)
	_sync_shop_presentation()

func _activate_merchant(smith: bool) -> void:
	if is_instance_valid(shrine_page): shrine_page.hide()
	smith_active = smith
	buy_notice.text = "Permanent unlocks never restock" if smith else "Restocks 1 every 40 min, max 5"
	var host: Control = blacksmith_page if smith else general_page
	# One trade UI/controller, shared by mutually exclusive merchant pages.
	for control: Control in [buy_tab, sell_tab, buy_page, sell_page, funds, feedback]:
		if control.get_parent() != host:
			control.get_parent().remove_child(control)
			host.add_child(control)
	_select_general_page(bool(merchant_buy_pages[smith]))
	if smith: fit_blacksmith_page(get_viewport_rect().size)
	else: fit_general_page(get_viewport_rect().size)
	inventory_view.clear()
	_update_funds()
	_rebuild_rows()

func open_blacksmiths() -> void:
	_activate_merchant(true)
	feedback.text = "Wood, stone, ore and found / forged weapons or armor. No infusion markup."
	town_page.visible = false
	general_page.visible = false
	blacksmith_page.visible = true
	blacksmith_presentation_changed.emit(true)
	_sync_shop_presentation()

func open_general() -> void:
	_activate_merchant(false)
	town_page.visible = false
	blacksmith_page.visible = false
	blacksmith_presentation_changed.emit(false)
	general_page.visible = true
	feedback.text = "Trade plants, meat and meals using Coins. No gear or smithing supplies."
	_update_funds()
	_rebuild_rows()
	_sync_shop_presentation()

func _process(delta: float) -> void:
	if progression == null or not is_visible_in_tree() or not (general_page.visible or blacksmith_page.visible): return
	refresh_wait -= delta
	if refresh_wait > 0.0: return
	refresh_wait = 1.0
	_update_funds()
	var current_view: Dictionary = _inventory_view()
	if current_view != inventory_view: _rebuild_rows()
	else: _refresh_trade_rows()

func _update_funds() -> void:
	if progression == null: return
	progression.update_kaji()
	progression.update_jimbo()
	var wallet: float = progression.jimbo_gold if smith_active else progression.kaji_gold
	var seconds: int = ceili(maxf(0.0, 500.0 - wallet) / HomeProgression.KAJI_GOLD_PER_SECOND)
	var minutes: int = ceili(float(seconds) / 60.0)
	var refill: String = "Full" if seconds == 0 else "Full in %dh %02dm" % [floori(float(minutes) / 60.0), minutes % 60]
	funds.text = "Your gold: %d   •   %s: %d / 500\n125 gold/hour • %s" % [progression.material_count("Coins"), "Jimbo" if smith_active else "Kaji", floori(wallet), refill]

func _inventory_view() -> Dictionary:
	if progression == null: return {}
	if smith_active: return {"materials": progression.materials.duplicate(), "gear": progression.gear_inventory.duplicate(true), "equipped": progression.equipped_gear_ids.duplicate(), "stock": progression.jimbo_stock.duplicate(), "recipes": progression.owned_forge_recipes.duplicate(), "slots": progression.forge_slot_count}
	return {"materials": progression.materials.duplicate(), "food": progression.food_inventory.duplicate(), "stock": progression.kaji_stock.duplicate(), "prepared": progression.prepared_food_id}

func _rebuild_rows() -> void:
	trade_rows.clear()
	for list: VBoxContainer in [rows, buy_rows]:
		for child: Node in list.get_children():
			list.remove_child(child)
			child.queue_free()
	if progression == null: return
	inventory_view = _inventory_view()
	var ids: Array[String] = HomeProgression.MATERIAL_NAMES.duplicate()
	ids.append_array(CookingConfig.recipe_ids())
	if smith_active:
		var permanent_header: Label = Label.new()
		permanent_header.text = "PERMANENT RECIPES & UPGRADES — buy once"
		permanent_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		buy_rows.add_child(permanent_header)
		for offer_id: String in ArmoryConfig.FORGE_PERMANENT_OFFERS:
			_add_trade_row(buy_rows, offer_id, true)
		var stock_header: Label = Label.new()
		stock_header.text = "SUPPLIES & GEAR — restocks, max 5"
		buy_rows.add_child(stock_header)
		for item_id: String in progression.jimbo_stock:
			if progression.blacksmith_price(item_id, true) > 0: _add_trade_row(buy_rows, item_id, true)
		for item: Dictionary in progression.gear_inventory:
			var item_id: String = str(item.get("id", ""))
			if progression.blacksmith_sellable_count(item_id) > 0: _add_trade_row(rows, item_id, false)
	for item_id: String in ids:
		if smith_active:
			if ItemConfig.blacksmith_sale_price(item_id) > 0 and progression.blacksmith_sellable_count(item_id) > 0: _add_trade_row(rows, item_id, false)
		else:
			if progression.discovered_items.has(item_id) and ItemConfig.general_purchase_price(item_id) > 0: _add_trade_row(buy_rows, item_id, true)
			if progression.general_sellable_count(item_id) > 0: _add_trade_row(rows, item_id, false)
	for list: VBoxContainer in [rows, buy_rows]:
		if list.get_child_count() == 0:
			var empty: Label = Label.new()
			empty.text = ("No smithing goods discovered yet." if list == buy_rows else "No tradable gear or supplies. Equipped gear is reserved.") if smith_active else ("No common goods discovered yet." if list == buy_rows else "No tradable goods. Prepared servings are reserved.")
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(empty)
	_refresh_trade_rows()

func _add_trade_row(list: VBoxContainer, item_id: String, buying: bool) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	list.add_child(row)
	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.tooltip_text = "Found / forged gear; base ranks only, no skill infusion markup." if smith_active and ItemConfig.blacksmith_sale_price(item_id) == 0 else ItemConfig.general_category(item_id)
	row.add_child(title)
	var actions: HBoxContainer = HBoxContainer.new()
	row.add_child(actions)
	var left: Button = _quantity_arrow(actions, "◀")
	var trade: Button = Button.new()
	trade.custom_minimum_size = Vector2(150, 32)
	trade.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	actions.add_child(trade)
	var right: Button = _quantity_arrow(actions, "▶")
	left.pressed.connect(_change_quantity.bind(item_id, buying, -1))
	right.pressed.connect(_change_quantity.bind(item_id, buying, 1))
	trade.pressed.connect(_trade_selected.bind(item_id, buying))
	trade_rows.append({"id": item_id, "buying": buying, "title": title, "left": left, "right": right, "trade": trade})

func _quantity_arrow(parent: Node, text: String) -> Button:
	var arrow: Button = Button.new()
	arrow.text = text
	arrow.custom_minimum_size = Vector2(32, 32)
	arrow.add_theme_font_size_override("font_size", 18)
	for theme_key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		arrow.add_theme_color_override(theme_key, ARROW_YELLOW)
	arrow.add_theme_color_override("font_disabled_color", Color("9a853f"))
	arrow.tooltip_text = "Choose quantity (limited by stock and available gold)."
	parent.add_child(arrow)
	return arrow

func _quantity_key(item_id: String, buying: bool) -> String:
	return ("jimbo:" if smith_active else "kaji:") + ("buy:" if buying else "sell:") + item_id

func _is_permanent(item_id: String, buying: bool) -> bool:
	return smith_active and buying and ArmoryConfig.FORGE_PERMANENT_OFFERS.has(item_id)

func _trade_price(item_id: String, buying: bool) -> int:
	if _is_permanent(item_id, buying): return int(ArmoryConfig.FORGE_PERMANENT_OFFERS[item_id]["coins"])
	if smith_active: return progression.blacksmith_price(item_id, buying)
	return ItemConfig.general_purchase_price(item_id) if buying else ItemConfig.general_sale_price(item_id)

func _trade_available(item_id: String, buying: bool) -> int:
	if smith_active: return progression.blacksmith_stock_count(item_id) if buying else progression.blacksmith_sellable_count(item_id)
	return progression.general_stock_count(item_id) if buying else progression.general_sellable_count(item_id)

func _trade_callback(buying: bool) -> Callable:
	if smith_active: return smith_buy_callback if buying else smith_sell_callback
	return buy_callback if buying else sell_callback

func _quantity_limit(item_id: String, buying: bool) -> int:
	if _is_permanent(item_id, buying): return 1 if progression.can_buy_forge_offer(item_id) else 0
	if smith_active:
		if buying: return progression.blacksmith_buyable_count(item_id)
		var smith_price: int = _trade_price(item_id, false)
		return mini(_trade_available(item_id, false), floori(progression.jimbo_gold / float(smith_price))) if smith_price > 0 else 0
	if buying: return progression.general_buyable_count(item_id)
	var price: int = ItemConfig.general_sale_price(item_id)
	return mini(progression.general_sellable_count(item_id), floori(progression.kaji_gold / float(price))) if price > 0 else 0

func _selected_quantity(item_id: String, buying: bool) -> int:
	var key: String = _quantity_key(item_id, buying)
	var limit: int = _quantity_limit(item_id, buying)
	var chosen: int = clampi(int(quantities.get(key, 1)), 1, limit) if limit > 0 else 0
	quantities[key] = chosen
	return chosen

func _change_quantity(item_id: String, buying: bool, change: int) -> void:
	var chosen: int = _selected_quantity(item_id, buying)
	quantities[_quantity_key(item_id, buying)] = clampi(chosen + change, 1, _quantity_limit(item_id, buying)) if _quantity_limit(item_id, buying) > 0 else 0
	_refresh_trade_rows()

func _refresh_trade_rows() -> void:
	for row: Dictionary in trade_rows:
		var item_id: String = row["id"]
		var buying: bool = row["buying"]
		if _is_permanent(item_id, buying):
			var offer: Dictionary = ArmoryConfig.FORGE_PERMANENT_OFFERS[item_id]
			var owned: bool = progression.owns_forge_offer(item_id)
			(row["title"] as Label).text = "%s • %s%s" % [offer["name"], ArmoryConfig.forge_offer_cost_label(item_id), " • Stone owned: %d" % progression.material_count("Stone") if offer.has("stone") else ""]
			(row["title"] as Label).tooltip_text = "Permanent unlock. Never restocks; not an inventory item. Forge equipment will be blank, with no skills."
			(row["left"] as Button).hide()
			(row["right"] as Button).hide()
			(row["trade"] as Button).text = "Owned" if owned else "Buy • " + ArmoryConfig.forge_offer_cost_label(item_id)
			(row["trade"] as Button).disabled = owned or not progression.can_buy_forge_offer(item_id) or not _trade_callback(buying).is_valid()
			continue
		var chosen: int = _selected_quantity(item_id, buying)
		var limit: int = _quantity_limit(item_id, buying)
		var price: int = _trade_price(item_id, buying)
		var available: int = _trade_available(item_id, buying)
		var item_name: String = progression.blacksmith_label(item_id, buying) if smith_active else (CookingConfig.recipe_name(item_id) if CookingConfig.recipe_ids().has(item_id) else item_id)
		(row["title"] as Label).text = "%s • %s %d • %d gold each" % [item_name, "Stock" if buying else "Stored", available, price]
		(row["left"] as Button).disabled = chosen <= 1
		(row["right"] as Button).disabled = chosen >= limit
		var trade: Button = row["trade"] as Button
		trade.disabled = limit <= 0 or not _trade_callback(buying).is_valid()
		trade.text = "%s %d • %d gold" % ["Buy" if buying else "Sell", chosen, chosen * price]

func _trade_selected(item_id: String, buying: bool) -> void:
	_update_funds()
	_execute_trade(item_id, _selected_quantity(item_id, buying), buying)

func _sell(item_id: String, requested: int) -> void:
	_execute_trade(item_id, requested, false)

func _execute_trade(item_id: String, requested: int, buying: bool) -> void:
	var callback: Callable = _trade_callback(buying)
	if not callback.is_valid() or requested <= 0: return
	# Capture price before a unique sold item leaves canonical inventory.
	var price: int = _trade_price(item_id, buying)
	var traded: int = int(callback.call(item_id, requested))
	if traded < 0:
		feedback.text = "Could not save. Trade cancelled; your goods and gold are unchanged."
	elif traded == 0:
		feedback.text = "Not enough gold, out of stock, or item is reserved."
	elif _is_permanent(item_id, buying):
		feedback.text = "%s — Owned. Paid %s." % [ArmoryConfig.FORGE_PERMANENT_OFFERS[item_id]["name"], ArmoryConfig.forge_offer_cost_label(item_id)]
	else:
		feedback.text = "%s %d for %d gold.%s" % ["Bought" if buying else "Sold", traded, traded * price, " Unpaid goods stayed in storage." if traded < requested and not buying else ""]
	_rebuild_rows()
	_update_funds()
