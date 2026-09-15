class_name WeaponOrientationCheckTest extends Node
## Covers scripts/dev/weapon_orientation_check.gd (the reusable diagnostic
## tool for the "new weapon art comes out backwards" gotcha) and locks in
## that both shipped sword textures currently match this project's render
## convention (hilt/crossguard near image-top, tip near image-bottom).

func test_straight_sword_texture_matches_convention() -> void:
	var result: Dictionary = WeaponOrientationCheck.check("res://assets/Blade Dancer Sword.png")
	assert(bool(result.get("ok", false)), "the known-good reference texture must load")
	assert(bool(result.get("hilt_likely_in_top_half", false)), "Blade Dancer Sword.png is the calibration reference -- it must read as hilt-near-top")

func test_curved_sword_texture_matches_convention_after_the_flip_fix() -> void:
	var result: Dictionary = WeaponOrientationCheck.check("res://assets/generated/basic_curved_sword_frame_0.png")
	assert(bool(result.get("ok", false)), "the curved sword texture must load")
	assert(bool(result.get("hilt_likely_in_top_half", false)), "basic_curved_sword_frame_0.png was flip_y()'d to fix the 'holding the blade' bug -- this must not regress")

func test_missing_file_reports_a_clean_error_instead_of_crashing() -> void:
	var result: Dictionary = WeaponOrientationCheck.check("res://assets/generated/does_not_exist_frame_0.png")
	assert(not bool(result.get("ok", true)), "a missing file must report ok=false, not crash or silently pass")
	assert(str(result.get("error", "")).length() > 0)

func test_sword_texture_flip_y_table_has_no_unexpected_true_entries() -> void:
	# Every sword currently shipped has already-correct art (the curved
	# sword was fixed at the source PNG this round) -- if this ever flips to
	# true for an existing entry, it should be an intentional, reviewed
	# change, not an accident.
	for sword_id: String in Player.SWORD_TEXTURE_FLIP_Y:
		assert(bool(Player.SWORD_TEXTURE_FLIP_Y[sword_id]) == false, "%s should not need SWORD_TEXTURE_FLIP_Y unless its source art was never corrected" % sword_id)
