class_name GrappleCoilContactTest extends Node

func test_coil_contact_is_armed_only_for_the_wrapped_enemy_after_one_turn() -> void:
	var chakram: Chakram = Chakram.new()
	chakram.configure_yoyo_constraint(Vector2.ZERO, 80.0, 20.0, 10.0, 0.0, 42, true)
	assert(chakram.yoyo_coil_contact_armed, "A completed coil may arm one wrapped-enemy contact.")
	assert(chakram.yoyo_coil_contact_enemy_id == 42)
	chakram.clear_yoyo_constraint()
	assert(not chakram.yoyo_coil_contact_armed, "Clearing the rope must clear the earned contact exception.")
	chakram.free()
