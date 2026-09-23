# Blade Dancer Tuning Guide

You should be able to tune the game by editing the clearly labeled values below. Most values are exported, so they can also be changed on the matching scene node in the Inspector.

## Start here

| What you want to change | Where to look |
|---|---|
| Player movement, dash, sword feel, hitstop | `scripts/player.gd` → exported categories near the top |
| Sword hit accuracy and body/hilt protection | `scripts/player.gd` → **Sword Damage Contact Shape** |
| Metronome visualizer and Chakram aim dots | `scripts/player.gd` → **Combat Readability Aids** |
| Enemy speed, health, attacks, charge behavior | `scripts/enemy.gd` → exported categories near the top |
| Melee pressure slots, attack rotation, outer ring, and peel radius | `scripts/combat/melee_engagement_director.gd` → exported categories near the top |
| Parry windows, blade slides, forgiveness | `scripts/parry_rules.gd` |
| Wave size, pacing, and spawn timing | `scripts/wave_spawner.gd` |
| Terrain density, safety, mud, and traps | `resources/terrain/forest_terrain_config.tres` and `scripts/terrain/terrain_config.gd` |
| Wall vs. trap render layer (which draws above/below the player) | `terrain_config.gd` → `wall_visual_z_index` (solid walls) and `trap_visual_z_index` (mud/bear trap) are separate fields on purpose — walls and traps are different things. Both must stay below the player/enemy `z_index` of `2`. Do not set the trap or wall `z_index` inside `bear_trap.gd`, `mud_patch.gd`, or `terrain_module.gd`'s own `_ready()` — that overrides the config value after it's assigned; ArenaGenerator's `_configure_module()` is the only place that should set it. |
| Forest arena border thickness (chakram/projectile bounce boundary, physical wall, and grass art) | `terrain_config.gd` → `arena_border_thickness`. All three (the physics collision in `boss_arena_border.gd`, the invisible bounce rects in `arena_generator.gd`'s `_arena_boundary_rects()`, and the grass drawing) use this one value with no per-side offset, so they always stay pixel-aligned. Do not add an offset to only one of them. |
| Bonus Rank 1–7 values | `scripts/bonus_config.gd` → arrays near the top |
| Food ingredients, effects, and cooking time | `scripts/home/cooking_config.gd` |
| Enemy material drops | `scripts/loot/loot_config.gd` |
| Campfire frequency | `scripts/main.gd` → `checkpoint_wave_interval` |
| Snack healing | `scripts/home/cooking_config.gd` → `WOLF_JERKY_HEAL_PERCENT` |
| Save note and timestamp UI | `scripts/ui/end_run_hub.gd` → Save / Load panel |
| Blood, hit sparks, hitstop presentation, and vignettes | `scripts/combat_presentation_fx.gd` |
| High-Flow focus transition | `scripts/combat_presentation_fx.gd` → **Persistent Status Vignettes**: `high_flow_threshold` is the start, `high_flow_full_intensity_flow` is the maximum, and `high_flow_vignette_max_alpha` controls opacity |
| Vignette edge thickness | `status_vignette_inner_radius` controls how much center stays clear; larger values make it more edge-only. `status_vignette_outer_radius` controls where it reaches the screen edge. |
| Home music playlist and fade length | `scripts/audio/music_director.gd` |

## How to recognize a tuning value

- `@export var`: safe to edit in the Inspector or in the scene instance.
- `const` in a section marked **PRIMARY EDITING AREA**: safe to edit in the script.
- `*_BY_RANK`: the entries are Rank 1 through Rank 7 from left to right. Rank 0 means not acquired.
- `*_duration`: the full length of an effect.
- `*_left`: the **remaining time** on an effect. It counts down to zero during play and is not normally a tuning value.
- `*_cooldown`: time between uses.
- `*_threshold`: the point at which an effect begins.
- `*_multiplier`: a percentage-style scale where `0.8` means 80% and `1.2` means 120%.
- `*_chance`: probability from `0.0` to `1.0`; `0.25` means 25%.
- Distances are normally pixels. Times are normally seconds. Speeds are normally pixels per second.

## The important distinction

For example:

```gdscript
@export var dash_cooldown: float = 3.0
var dash_left: float = 0.0
```

`dash_cooldown` is the value you tune. `dash_left` is live runtime bookkeeping: it says how much of the current cooldown is still left. Changing the bookkeeping variable will not permanently tune the game.

## Safe editing habit

1. Change one value at a time.
2. Prefer the labeled exported value or primary editing area.
3. Play for one short test.
4. If the change feels wrong, undo that one value.
5. Avoid changing variables below the exported settings unless the code comment specifically says they are tuning controls.
