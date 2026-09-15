# Blade Dancer Architecture Notes

For day-to-day balance and presentation tuning, start with `res://docs/tuning_guide.md`. It explains which files contain the primary editing areas and how names such as `_left`, `_duration`, and `_cooldown` work.

This document records the current boundaries so future features stay additive and reversible.

## Project guidance and asset governance

- `docs/PROJECT_ART_STYLE_GUIDE.md`: current human-readable art rules, Chasm conventions, and beginner glossary.
- `docs/DEVELOPMENT_LOG.md`: append-only dated decisions and change history.
- `docs/ASSET_MANIFEST.md`: source/generated/production asset inventory and provenance.
- `resources/styles/chasm_art_style.tres`: machine-readable Chasm art contract used by Godot.
- Keep source/reference images under `assets/source/` and generated derivatives under `assets/generated/`. Never overwrite a source asset with a generated asset.
- Treat referenced asset paths as public interfaces: move or rename them only with a Git checkpoint, reference search, import verification, and a bounded playtest.

## Data versus behavior

- `scripts/home/cooking_config.gd`: recipe IDs, ingredients, crafting times, and food effects.
- `scripts/loot/loot_config.gd`: enemy-to-item drop rules and drop chances.
- `scripts/home/item_config.gd`: item rarity and pickup presentation colors.
- `scripts/home/home_progression.gd`: persistent materials, food inventory, prepared food, timestamped crafting state, and the chest-loot gear inventory/equip state.
- `scripts/home/armory_config.gd`: chest-dropped gear slot pools, technique-rank roll rules, and coin value. It must not touch save data or player state directly — `main.gd`/`home_progression.gd` apply its rolls.
- `scripts/bonus_config.gd`: Rank 1-7 run bonus values and generated explanations. Equipped gear supplies an additive baseline rank (`HomeProgression.equipped_technique_ranks()`) applied once at run start; wave-reward picks still stack on top via the normal `apply_to_player` path.
- `scripts/parry_rules.gd`: universal parry, slide, and blade interaction rules.
- `resources/terrain/forest_terrain_config.tres`: Forest terrain tuning data.

A recipe may refer to an item by ID/name, but it must not decide which enemy drops that item. Loot may refer to an item, but it must not know what the item does when cooked.

## Runtime ownership

- `main.gd` currently coordinates the run lifecycle, save boundary, navigation, and scene-level signals.
- `player.gd` owns movement and player combat state.
- `enemy.gd` owns individual enemy combat behavior. It is a known future split point once archetypes stabilize.
- `scripts/combat/melee_engagement_director.gd` owns shared melee intent: two close-pressure roles, one attack commitment, outer-ring spacing, and role rotation. It never suppresses collision or valid damage.
- `wave_spawner.gd` owns wave timing, composition, and safe spawn placement.
- `combat_presentation_fx.gd` owns centralized combat presentation.
- `scripts/ui/` owns menu presentation and user interaction requests; it should not directly write save files.

## Save rules

Persistent changes call `Main.save_game()` through a signal or lifecycle boundary. Each save records a Unix timestamp and optional player note in `save_metadata`. Save data is version-tolerant: new fields must have defaults, and old fields should be migrated rather than discarded.

## Safe refactor rules

1. Preserve public method behavior during a move; add a compatibility wrapper if needed.
2. Move data before moving behavior.
3. Add a regression test before changing a gameplay boundary.
4. Do not split `enemy.gd` or `main.gd` during active boss tuning unless the seam is clear and tests cover it.
5. Do not delete legacy scripts just because they are currently unused; mark them as compatibility-only until a later cleanup pass confirms no external references.
6. Keep DLC/zone content in data resources or focused config files instead of adding more branches to `main.gd`.
7. Never hardcode a `z_index`/visual-layer value inside a node's own `_ready()` if that value is also meant to be assigned by a parent/config before the node enters the tree — `_ready()` runs after that assignment and will silently override it. This exact bug shipped once already (bear_trap.gd and mud_patch.gd both hardcoded `z_index = 5` in `_ready()`, permanently overriding `ArenaGenerator._configure_module()`'s config-driven value). Let the config-setting code be the only writer.
8. A test that calls `add_child()` inside `res://tests/*_test.gd` (run via the synchronous `run_tests` harness) cannot rely on that child's `_ready()` having run, and `get_tree()` is null in that context even after `add_child()`. Anything that depends on real node-lifecycle timing (deferred `_ready()`, `call_deferred`, a processed frame) needs a live `run_scene` harness (see `tests/*_live_harness.tscn`) instead, not the synchronous test runner.
9. When a physical collision boundary and its matching visual art are meant to align (e.g. `boss_arena_border.gd`'s wall collision and grass, or `arena_generator.gd`'s `_arena_boundary_rects()` used for chakram/projectile bounce), keep them computed from the exact same formula/values in one place. A one-sided offset added to only the collision (or only the visual) will desync them even though each one looks locally reasonable in isolation.
10. AI-generated weapon sprites do **not** reliably come out with hilt-near-top/tip-near-bottom orientation, even when explicitly requested — this has happened to nearly every weapon added to the project so far, and reads in-game as the player holding the blade instead of the handle. Always run `scripts/dev/weapon_orientation_check.gd` on a new weapon sprite before wiring it in; see "Adding a new weapon" below.

## Adding a new weapon

1. Generate the sprite art as usual.
2. **Before** wiring it into `Player.BLADE_PROFILES` / `equipped_sword_texture()`, check its orientation: `WeaponOrientationCheck.check("res://assets/generated/<name>_frame_0.png")` (callable from `execute_script`, or see `scripts/dev/weapon_orientation_check.gd` for the standalone logic). It reports whether the hilt/crossguard reads near the top of the image (matching `Blade Dancer Sword.png`, the calibration reference) or near the bottom (inverted).
3. If inverted, do **not** hand-edit the render code. Either:
   - Add `Player.SWORD_TEXTURE_FLIP_Y["<Sword Name>"] = true` (preferred — a one-line, easily reversible data change), or
   - Flip the source PNG itself (`Image.load_from_file(path); img.flip_y(); img.save_png(path)`) if you'd rather the art asset be self-consistent on disk.
4. Add the new sword's hit-geometry entry to `Player.BLADE_PROFILES` (hilt fixed at `t=0, offset=0`; tune mid/tip control points live via Training Tools > Combat Presets > Blade Shape once equipped).
5. Add a texture branch in `equipped_sword_texture()` and an entry in `ArmoryConfig.SLOT_ITEM_POOL["Sword"]` so it can actually drop/equip.
6. Verify live (`run_scene`, equip the sword, look at it) — the automated check catches the common case, but a quick visual pass is still worth it.

## Deferred cleanup candidates

- Replace `CookingConfig.TURKEY_MATERIAL` and `MUSHROOM_MATERIAL` with a general item catalog once more recipes exist.
- Move enemy archetype tuning from `enemy.gd` into enemy data resources after the boss and current archetypes stabilize.
- Split `main.gd` into run lifecycle, save/progression, and navigation coordinators only when tests can protect the boundaries.
- Add save schema versioning before public demo distribution.
- Replace placeholder Home compatibility scene/script after all external references are confirmed removed.
