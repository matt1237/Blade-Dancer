class_name ShrineMenu extends Control
## Presentation only; callbacks use Main's canonical atomic trade path.
signal town_requested
var progression: HomeProgression
var exchange_callback: Callable
var salvage_callback: Callable
var body: VBoxContainer
var knowledge: VBoxContainer
var body_scroll: ScrollContainer
var knowledge_scroll: ScrollContainer
var balance: Label
var feedback: Label
var tabs: HBoxContainer
var back: Button
var page: String = "Exchange"
var pending_id: String = ""
var pending_item: Dictionary = {}
var pending_amount: int = 0
var amount_input: LineEdit

func _ready() -> void:
	name = "ShrinePage"
	balance = _text(self, "", 18)
	tabs = HBoxContainer.new()
	add_child(tabs)
	for title: String in ["Exchange", "Salvage", "Infuse"]:
		_button(tabs, title, select_page.bind(title))
	body_scroll = _scroll()
	body = _list(body_scroll)
	knowledge_scroll = _scroll()
	knowledge = _list(knowledge_scroll)
	feedback = _text(self, "", 14)
	back = _button(self, "← Town", func() -> void: town_requested.emit())
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree(): _clear_pending())
	fit(get_viewport_rect().size)

func _scroll() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	return scroll

func _list(parent: Node) -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	parent.add_child(list)
	return list

func _text(parent: Node, value: String, font_size: int = 16) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(96, 36)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func fit(viewport_size: Vector2) -> void:
	size = viewport_size - Vector2(32, 32)
	var width: float = minf(350, maxf(1, size.x - 32))
	balance.position = Vector2(16, 12)
	balance.size = Vector2(width, 68)
	tabs.position = Vector2(16, 90)
	tabs.size = Vector2(width, 38)
	body_scroll.position = Vector2(16, 142)
	body_scroll.size = Vector2(width, maxf(40, size.y - 252))
	var knowledge_layout_changed: bool = knowledge_scroll.visible != (size.x >= 850)
	knowledge_scroll.visible = size.x >= 850
	knowledge_scroll.position = Vector2(size.x - 246, 90)
	knowledge_scroll.size = Vector2(230, maxf(40, size.y - 200))
	feedback.position = Vector2(16, size.y - 100)
	feedback.size = Vector2(width, 56)
	back.position = Vector2(16, size.y - 42)
	back.size = Vector2(150, 38)
	if knowledge_layout_changed and progression != null and pending_id.is_empty() and pending_amount == 0: refresh()

func _clear(list: VBoxContainer) -> void:
	for child: Node in list.get_children():
		list.remove_child(child)
		child.queue_free()

func _clear_pending() -> void:
	pending_id = ""
	pending_item.clear()
	pending_amount = 0

func select_page(selected: String) -> void:
	page = selected
	_clear_pending()
	feedback.text = ""
	refresh()

static func parse_amount(text: String) -> int:
	var digits: String = text.strip_edges()
	if digits.is_empty(): return 0
	for character: String in digits:
		if character < "0" or character > "9": return 0
	while digits.length() > 1 and digits.begins_with("0"): digits = digits.substr(1)
	var maximum: String = str(HomeProgression.SHRINE_INT_MAX)
	if digits.length() > maximum.length() or (digits.length() == maximum.length() and digits > maximum): return 0
	return digits.to_int()

func _knowledge_text(skill: String) -> String:
	var rank: int = progression.learned_skill_rank(skill)
	var points: int = HomeProgression.shrine_nonnegative_int(progression.skill_knowledge.get(skill, 0))
	return "%s • %d knowledge\nLearned rank %d • %s" % [BonusConfig.display_name(skill), points, rank, "Max rank" if rank == BonusConfig.MAX_RANK else "Next: %d total" % HomeProgression.knowledge_threshold(rank + 1)]

func refresh() -> void:
	_clear(body)
	_clear(knowledge)
	if progression == null: return
	balance.text = "SHRINE\nCoins: %d   •   Resonance: %d" % [progression.material_count("Coins"), progression.resonance]
	_text(knowledge, "PERMANENT KNOWLEDGE", 20)
	_text(knowledge, "Unlock totals: 20 / 50 / 90…\nNever spent when infusing.", 14)
	for skill: String in BonusConfig.all_bonus_ids():
		if progression.skill_knowledge.has(skill): _text(knowledge, _knowledge_text(skill), 14)
	match page:
		"Exchange":
			_text(body, "Exchange Coins → Resonance\n1 Coin = 1 Resonance", 20)
			_text(body, "Choose any whole amount up to your available Coins. This exchange is one-way.", 14)
			amount_input = LineEdit.new()
			amount_input.name = "ExchangeAmount"
			amount_input.placeholder_text = "Whole Coins"
			amount_input.text = "1"
			body.add_child(amount_input)
			_button(body, "All available", func() -> void: amount_input.text = str(progression.shrine_exchange_limit()))
			var exchange: Button = _button(body, "Preview exchange", _preview_exchange)
			exchange.disabled = not exchange_callback.is_valid() or progression.shrine_exchange_limit() == 0
		"Salvage":
			_text(body, "Destroy found gear → Knowledge", 20)
			_text(body, "Every skill grants 1 knowledge per rank. Equipped, forged and player-infused gear are protected.", 14)
			var count: int = 0
			for item: Dictionary in progression.gear_inventory:
				var id: String = str(item.get("id", ""))
				var gains: Dictionary = progression.shrine_salvage_gains(id)
				if gains.is_empty(): continue
				count += 1
				_text(body, ArmoryConfig.display_label(item), 16)
				_text(body, gains_text(gains), 14)
				var select: Button = _button(body, "Salvage • " + id, _preview_salvage.bind(id))
				select.disabled = not salvage_callback.is_valid()
			if count == 0: _text(body, "No eligible found gear in storage.", 14)
		"Infuse":
			_text(body, "Infusion awaiting price approval", 20)
			_text(body, "No Resonance infusion cost exists yet. Applying skills is disabled; your knowledge and gear remain unchanged. Only blank base equipment will accept learned skills.", 14)
			var apply: Button = _button(body, "Infuse • price not set", func() -> void: pass)
			apply.disabled = true
			_text(body, "Learned skills", 18)
			for skill: String in BonusConfig.all_bonus_ids():
				if progression.learned_skill_rank(skill) > 0: _text(body, _knowledge_text(skill), 14)
	# On smaller screens, knowledge remains accessible inside the scrolling panel.
	if not knowledge_scroll.visible:
		_text(body, "PERMANENT KNOWLEDGE", 20)
		for skill: String in BonusConfig.all_bonus_ids():
			if progression.skill_knowledge.has(skill): _text(body, _knowledge_text(skill), 14)

static func gains_text(gains: Dictionary) -> String:
	var lines: Array[String] = []
	for skill: String in gains:
		lines.append("+%d %s knowledge" % [int(gains[skill]), BonusConfig.display_name(skill)])
	return "\n".join(lines)

func _preview_exchange() -> void:
	var amount: int = parse_amount(amount_input.text)
	if amount <= 0 or amount > progression.shrine_exchange_limit():
		feedback.text = "Enter a positive whole amount within available Coins."
		return
	pending_amount = amount
	pending_id = ""
	_confirmation("Exchange %d Coins for %d Resonance?\nThis cannot be reversed." % [amount, amount], "Confirm exchange")

func _preview_salvage(id: String) -> void:
	var gains: Dictionary = progression.shrine_salvage_gains(id)
	if gains.is_empty(): refresh(); return
	pending_id = id
	pending_item = progression.gear_item_by_id(id).duplicate(true)
	pending_amount = 0
	_confirmation("DESTROY %s [%s]?\n%s\nThe entire item is permanently consumed." % [ArmoryConfig.display_label(pending_item), id, gains_text(gains)], "Confirm destroy")

func _confirmation(text: String, action: String) -> void:
	_clear(body)
	_text(body, text, 18)
	var confirm: Button = _button(body, action, _commit)
	_button(body, "Cancel", func() -> void: _clear_pending(); refresh())
	confirm.grab_focus()

func _commit() -> void:
	var result: int = 0
	if not pending_id.is_empty():
		if progression.gear_item_by_id(pending_id) == pending_item and not progression.shrine_salvage_gains(pending_id).is_empty() and salvage_callback.is_valid():
			result = int(salvage_callback.call(pending_id))
	elif pending_amount > 0 and pending_amount <= progression.shrine_exchange_limit() and exchange_callback.is_valid():
		result = int(exchange_callback.call(pending_amount))
	_clear_pending()
	feedback.text = "Could not save. Nothing changed." if result < 0 else ("Confirmed." if result > 0 else "Selection changed or is protected. Nothing changed.")
	refresh()
