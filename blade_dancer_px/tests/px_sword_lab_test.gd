extends Node

const LAB_SCENE: PackedScene = preload("res://blade_dancer_px/tools/px_sword_lab.tscn")
const PXLab = preload("res://blade_dancer_px/tools/px_sword_lab.gd")
const HUB_SCENE: PackedScene = preload("res://scenes/ui/end_run_hub.tscn")

func test_hub_adventure_tab_exposes_px_mode_button() -> void:
	var hub: EndRunHub = HUB_SCENE.instantiate() as EndRunHub
	add_child(hub)
	await get_tree().process_frame
	var px_button: Button = hub.get_node_or_null("AdventureCard/PXModeButton") as Button
	assert(px_button != null, "The Adventure tab must expose a PX mode button.")
	assert(px_button.text.to_lower().contains("px"), "The button should be labelled PX mode.")
	var requests: Array[int] = [0]
	hub.px_mode_requested.connect(func() -> void: requests[0] += 1)
	px_button.pressed.emit()
	assert(requests[0] == 1, "Pressing PX mode must request the isolated lab.")
	hub.queue_free()
	await get_tree().process_frame

func test_lab_is_source_isolated_from_the_game() -> void:
	# The whole point of the lab is that it shares no runtime code with the
	# game. If it ever imports a production sword/reaction system, the A/B
	# result stops meaning anything.
	var source: String = FileAccess.get_file_as_string("res://blade_dancer_px/tools/px_sword_lab.gd")
	# Code references only — the lab may NAME the systems it avoids in prose.
	for forbidden: String in ["res://scripts/", "res://scenes/", "AITestTools"]:
		assert(not source.contains(forbidden), "The lab must not reference %s." % forbidden)

func test_lab_builds_a_physical_sword_pinned_to_a_static_hilt() -> void:
	var lab: PXLab = LAB_SCENE.instantiate() as PXLab
	add_child(lab)
	await get_tree().process_frame
	var anchor: StaticBody2D = lab.get_node("HandAnchor") as StaticBody2D
	var sword: RigidBody2D = lab.get_node("Sword") as RigidBody2D
	var pivot: PinJoint2D = lab.get_node("Pivot") as PinJoint2D
	var obstacle: StaticBody2D = lab.get_node("Obstacle") as StaticBody2D
	assert(anchor != null and sword != null and pivot != null and obstacle != null)
	assert(sword.get_parent() == lab, "The sword must be a sibling of the hand anchor, never its child.")
	assert(anchor.get_parent() == lab, "The hilt anchor must be a sibling of the sword.")
	assert(pivot.node_a == pivot.get_path_to(anchor), "The pin must be wired to the anchor.")
	assert(pivot.node_b == pivot.get_path_to(sword), "The pin must be wired to the sword.")
	assert(not sword.can_sleep, "A continuously-driven body must never sleep.")
	lab.queue_free()
	await get_tree().process_frame

func test_motor_turns_the_blade_while_the_pin_holds_the_hilt() -> void:
	var lab: PXLab = LAB_SCENE.instantiate() as PXLab
	add_child(lab)
	var peak_hilt_error: float = 0.0
	var peak_angle: float = 0.0
	for _i: int in range(48):
		await get_tree().physics_frame
		peak_hilt_error = maxf(peak_hilt_error, absf(lab.hilt_error))
		peak_angle = maxf(peak_angle, absf(lab.actual_angle))
	assert(peak_angle > 0.1, "The motor must actually rotate the blade (peak %.3f rad)." % peak_angle)
	assert(peak_hilt_error < 3.0, "The pin must hold the hilt in place (peak %.2f px)." % peak_hilt_error)
	lab.queue_free()
	await get_tree().process_frame