class_name ShamanFreedTargetTest extends Node

func test_freed_cast_target_cancels_without_launching() -> void:
	var shaman: GoblinShaman = GoblinShaman.new()
	var ally: Ogre = Ogre.new()
	shaman._configure_concrete_enemy()
	ally._configure_concrete_enemy()
	ally.health = 20.0
	ally.max_health = 100.0
	assert(shaman.begin_cast(ally))
	ally.free()
	shaman.advance_cast(shaman.cast_duration)
	assert(not shaman.casting)
	assert(shaman.cast_target == null)
	assert(is_zero_approx(shaman.cast_elapsed))
	shaman.free()
