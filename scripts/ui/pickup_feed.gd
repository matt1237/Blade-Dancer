class_name PickupFeed extends Control

@export_category("Pickup Feed Presentation")
## Font size in screen pixels. Increase this if the feed is hard to read.
@export var pickup_font_size: int = 14
## How long each pickup stays fully visible.
@export var pickup_visible_duration: float = 2.0
## How long each pickup takes to fade away after the visible period.
@export var pickup_fade_duration: float = 1.0
## How far a new pickup slides upward while appearing.
@export var pickup_pop_distance: float = 8.0
## Maximum number of pickup messages shown at once.
@export var maximum_visible_pickups: int = 6

var message_list: VBoxContainer = null

func _ready() -> void:
	message_list = VBoxContainer.new()
	message_list.name = "MessageList"
	message_list.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(message_list)

func show_pickup(item_name: String, quantity: int, rarity: ItemConfig.Rarity) -> void:
	var message: Label = Label.new()
	message.text = "+%d %s" % [quantity, item_name]
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	message.add_theme_font_size_override("font_size", pickup_font_size)
	message.add_theme_color_override("font_color", _rarity_text_color(rarity))
	message.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.06, 0.85))
	message.add_theme_constant_override("shadow_offset_x", 2)
	message.add_theme_constant_override("shadow_offset_y", 2)
	message.modulate.a = 0.0
	message.position.y = pickup_pop_distance
	message_list.add_child(message)
	message_list.move_child(message, 0)
	while message_list.get_child_count() > maximum_visible_pickups:
		var oldest: Node = message_list.get_child(message_list.get_child_count() - 1)
		oldest.queue_free()
	var appear_tween: Tween = create_tween()
	appear_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	appear_tween.set_parallel(true)
	appear_tween.tween_property(message, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_SINE)
	appear_tween.tween_property(message, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(pickup_visible_duration, false, false, true).timeout
	if not is_instance_valid(message): return
	var fade_tween: Tween = create_tween()
	fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_tween.tween_property(message, "modulate:a", 0.0, pickup_fade_duration).set_trans(Tween.TRANS_SINE)
	await fade_tween.finished
	if is_instance_valid(message): message.queue_free()

func _rarity_text_color(rarity: ItemConfig.Rarity) -> Color:
	match rarity:
		ItemConfig.Rarity.RARE: return Color("a9e6ae")
		ItemConfig.Rarity.VERY_RARE: return Color("a9d8ff")
		_: return Color("f1d0b0")
