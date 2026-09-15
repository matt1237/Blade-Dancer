class_name GemJamLiveFacetsPreview extends Node

const GEM_JAM_SCENE: PackedScene = preload("res://scenes/minigames/gem_jam.tscn")

func _ready() -> void:
	var game: GemJamGame = GEM_JAM_SCENE.instantiate() as GemJamGame
	game.generation_seed = 16 # deterministic AMETHYST / TEARDROP showcase
	add_child(game)
	var cleared_rock: int = 0
	for index: int in range(game.material_mask.size()):
		var y: int = index >> 8
		if game.material_mask[index] == GemJamGame.Cell.ROCK and y < int(game.target_center.y + 8.0):
			game.material_mask[index] = GemJamGame.Cell.EMPTY
			cleared_rock += 1
	game.removed_rock = cleared_rock
	game.exposure_dirty = true
	game.textures_dirty = true
	game._rebuild_all_textures_full()
	game.gem_exposure_ratio()
	game._select_grind()
	# Exercise the warning presentation alongside the partially revealed facets.
	game.gem_stress = 0.88
	game.target_contact_cells = 5
	game.danger_flash = 1.0
	game.precision_chain_points = 900.0
	game.best_precision_chain = 900.0
