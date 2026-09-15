class_name GemJamResonancePreview extends Node

const GEM_JAM_SCENE: PackedScene = preload("res://scenes/minigames/gem_jam.tscn")

func _ready() -> void:
	var game: GemJamGame = GEM_JAM_SCENE.instantiate() as GemJamGame
	game.generation_seed = 16 # deterministic AMETHYST / TEARDROP showcase
	add_child(game)
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.ROCK:
			game.material_mask[index] = GemJamGame.Cell.EMPTY
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			game._remove_material_index(index)
	game.exposure_dirty = true
	game.textures_dirty = true
	game._rebuild_all_textures_full()
	game._recompute_target_cache()
	game.gem_exposure_ratio()
	game._start_resonance_challenge()
