# PROJECT_MAP.md — Blade Dancer

Purpose: fast index so Ziva checks here first instead of re-scanning the repo
for every task. Verified against the live codebase, not guessed. If an entry
looks wrong (files move), fix it here rather than trusting it blindly.

## Direction / Product Memory
- Collaboration protocol and command rituals: `res://Ziva Help/COLLABORATION_PROTOCOL.md` — persistent discussion-mode rules, working relationship, North Star, reasoning budget, and `/startofday` / `/checkpoint` / `/endofday` procedures.
- Adventure Log continuity: `res://Ziva Help/adventure log/ADVENTURE_LOG_INDEX.md` and `CURRENT_CONTINUITY.md` — chronological session narrative plus the shortest current handoff for a new conversation. Focused tuning snapshots live under `res://Ziva Help/adventure log/checkpoints/`; the current Bind B GP2→GP3 values are recorded there.
- Idea and resonance pipeline: `res://Ziva Help/IDEA_PIPELINE.md` — authoritative status, player fantasy, next playable milestone, safety rails, and feel questions for active and parked ideas. Update it after meaningful feature work so implementation does not lose the original reason an idea mattered.
- Grapple Yo-yo detailed parking lot: `res://Ziva Help/GRAPPLE_YOYO_PARKING_LOT.md`.

## Player
- Scene: `res://scenes/player.tscn`
- Controller: `res://scripts/player.gd` (`class_name Player`) — one large controller; dash/sword/grapple/chakram/flow state all live here
- Dash: `dash_speed` / `dash_left` / `dash_charges` fields
- Health/damage: `health` var, `take_damage()`
- Flow: `flow` var
- Animation: procedural `_draw()` — no AnimatedSprite2D on the player body itself

## Sword / Combat
- Sword state/rendering: `res://scripts/player.gd` (`BLADE_PROFILES`, `blade_angle`, `sword_phase`, `_update_sword()`)
- Swept collision: `res://scripts/sword_interaction_resolver.gd` (`SwordInteractionResolver.swept_contact`)
- Damage data: `res://scripts/sword_contact_data.gd` (`SwordContactData`)
- Parry / clash rules: `res://scripts/parry_rules.gd` (`ParryRules`); applied per-enemy via `parry_blade()` / `weapon_clash()` in `res://scripts/enemy.gd`
- Shared moving-weapon capability: `res://scripts/enemy.gd` — `moving_weapon_enabled`, `tick_moving_weapon_combat()`, `draw_moving_weapon_combat_fx()`; this is separate from enemy archetype AI and is used by goblin Duelists, Zungar, and future armed enemies
- Hitstop / impact feel: `res://scripts/combat_presentation_fx.gd`, `res://scripts/combat/melee_engagement_director.gd`
- Canonical Bind Form outcomes: `res://scripts/player.gd` — `_begin_experimental_bind_candidate()`, `_update_experimental_bind_contact()`, `_release_experimental_bind()`, `_try_experimental_weapon_beat()`, and `_arm_experimental_disengagement()`; only an existing validated parallel blade slide can arm it. Stable contact measures normal pressure, tangential travel, enemy/player hilt leverage, and real rollover state; ordinary offense is suppressed while retained. A weapon beat requires a new player-authored pressure spike plus favorable leverage and deals no health damage (`Enemy.receive_weapon_beat()`; Zungar maps it into his custom stunned state). Endpoint travel can arm guard-wrap memory; re-entry bonuses are consumed only by a later inward swept body collision. Bad-leverage beat attempts recoil the player.
- In-game combat debug tracker: `res://scripts/ui/combat_debug_tracker.gd` is created by `main.gd` in the HUD CanvasLayer. It consumes typed `Player.combat_debug_event` packets, provides compact/expanded live Bind A/B measurements, a bounded color-coded event timeline, session counts, and Pause/Clear controls. `Player.experimental_overhead_debug_lines()` draws a small vertical yellow no-background readout (Winds/Binds/Beats/Slides counts, in the old slide-counter's position) above the character. `Player._emit_combat_debug_event()` also `print()`s a compact `BIND: <TYPE> | ...` line (gated by `debug_print_sword_events`) for every bind-lifecycle event — `BIND CANDIDATE`, `STABLE BIND`, `WIND`, `WEAPON BEAT`, `BEAT REJECTED`, `GUARD WRAP`, `ROLLOVER DISENGAGE`, `GUARD-WRAP RE-ENTRY`, `ROLLOVER RE-ENTRY`, `BIND RELEASE` (with reason) — so Ziva can read a `get_godot_errors` console pull for the full bind sequence without needing a screenshot.
- Experimental bind focus: `res://scripts/combat_presentation_fx.gd::set_bind_focus()` owns sustained zoom/world scale; `res://scripts/main.gd::set_experimental_bind_focus()` owns contact framing. Player sword/aim time is compensated in `_experimental_sword_control_delta()` so its phase and metronome stay on real-time cadence.
- Combat tuning knobs: `res://scripts/combat_settings_config.gd`, `res://scripts/combat_tuning_schema.gd`; the single **SLIDE & BIND FEEL (All Weapons)** section in `res://scripts/ui/backyard_training_menu.gd` is visible for the Bind Form. Slide controls use the active contact preset; Bind controls use canonical style ID 9. Retired `bind_slide_*`, Reset-B, and Clone-A→B paths have no authority.
- Training Tools sword selector: `BackyardTrainingMenu.open()` re-reads `player.equipped_sword_id` and resyncs the dropdown + blade-shape controls every time the menu opens. Normal hand/geometry settings may remain per weapon, but Slide and Bind tuning is shared by Longsword and Curved Sword.

## Bonuses / Techniques
- Run bonuses/upgrades: `res://scripts/bonus_config.gd` (`BonusConfig`) — all 22 bonus IDs in `BONUS_IDS` (health, chakram, pierce, explosion, nova, regen, magnetic, defense, dash, bash_dash, grapple_mastery, resonant_glyph, voltage, burning, deflect, moon, flash, disarm, void, chain, vampirism, adrenaline); applied via `apply_to_player()`, tunable per-rank via the `*_BY_RANK` arrays
- Sword techniques/forms: `res://scripts/player.gd` — enum IDs remain save-stable. Retired Bind A stays `METRONOME_BIND = 8` for old files but is absent from `STYLE_CYCLE_ORDER`; old ID 8 resolves to canonical `METRONOME_BIND_B = 9`. The player-facing name is simply **Bind Form**. Cycle via `STYLE_CYCLE_ORDER` (Z/X keys or controller bumpers).
- Special-ability scenes tied to bonuses: `res://scenes/moon_slash.tscn` (`moon` bonus), `res://scenes/void_well.tscn` (`void` bonus)
- Resonant Glyph ability: `res://scripts/resonant_glyph.gd`, `res://scenes/resonant_glyph.tscn`

## Chakram
- Scene: `res://scenes/chakram.tscn`
- Script: `res://scripts/chakram.gd` (`class_name Chakram extends Area2D`)
- Deflection: `chakram.gd` + `EnemyProjectile.deflect()` in `res://scripts/enemy_projectile.gd`
- Bounce / magnetic-seek: inside `chakram.gd` (`magnetic_seek_radius`, `velocity.bounce(...)`)
- Chain lightning: **not currently implemented** despite a `chain` bonus ID existing — verify before assuming it works

## Enemies
- Shared mechanics base: `res://scripts/enemy.gd` (`class_name Enemy`); there is no enemy-type enum or type-based behavior dispatch
- Named concrete enemies: `res://scripts/enemies/{turkey,goblin,bug,wolf,ogre}.gd` with matching scenes under `res://scenes/enemies/`
- Explicit capabilities: `moving_weapon_enabled`, `shield_enabled`, `participates_in_melee_engagement`, `hilt_bash_impulse_multiplier`, and grapple weight
- Bug projectile: `res://scripts/enemy_projectile.gd`; Ogre alone enables directional shield/projectile blocking
- Zungar: `res://scripts/boss/zungar.gd`; custom boss AI, Executioner Sword capability, no Ogre shield behavior
- Grapple ability (player, not enemy): `res://scripts/grapple_controller.gd` (`GrappleController`) — `TUNING_KEYS` / `TUNING_DEFAULTS` are the sole Grapple/Yo-yo tuner registry used by UI mutation and Global Preset save/load; max-range shots; independent base reel, target-specific hand gain, shared hand-signal shaping, and Light/Medium/Heavy responses.
- Grapple target weight: `res://scripts/enemy.gd` — `GrappleWeight`, `grapple_weight`; Turkey/Bug/Goblin/Wolf Light, Ogre Medium, Zungar Heavy
- Chakram grapple contract: `res://scripts/chakram.gd` — `on_grapple_attached()`, `on_grapple_detached()`; additive lasso redirection, +5s once, countdown paused while attached

## Bosses
### Zungar
- Scene: `res://scenes/boss/zungar.tscn`
- Main AI script: `res://scripts/boss/zungar.gd`
- Tuning/config resource: `res://scripts/boss/zungar_config.gd` (`ZungarConfig`) — health, damage, cooldowns, telegraphs, summon rules, friendly-fire bark cooldown, all here
- Visuals/animation: `res://scripts/boss/zungar_visual.gd`
- Charge dirt FX: `res://scripts/boss/zungar_charge_fx.gd`
- Arena props: `res://scripts/boss/boss_campfire.gd`, `res://scripts/boss/boss_cave_backdrop.gd`, `res://scripts/boss/destructible_tree.gd`, `res://scripts/boss/boss_arena_border.gd`
- Boss dialogue UI: `res://scripts/ui/boss_dialogue_box.gd`
- Known issues: see `DEBUG_LOG.md`

## Waves / Run
- Spawner: `res://scripts/wave_spawner.gd` (`class_name WaveSpawner`) — normal wave spawning; hard-suspended during the boss wave via `normal_spawning_suspended`
- Run/score/bonus flow, save/load: `res://scripts/main.gd` (`class_name Main`)
- Upgrade selection UI: `main.gd` `_show_bonus_screen()` + `res://scripts/bonus_config.gd`

## Items / Gear
- Item definitions: `res://scripts/home/item_config.gd` (`ItemConfig`)
- Armory/gear rolling: `res://scripts/home/armory_config.gd` (`ArmoryConfig`)
- Player meta progression: `res://scripts/home/home_progression.gd` (`HomeProgression`)
- Drops: `res://scripts/loot/loot_config.gd` (`LootConfig`), `res://scripts/drop_pickup.gd`, `res://scripts/gear_drop_pickup.gd`

## World
- Terrain generation: `res://scripts/terrain/arena_generator.gd` (`ArenaGenerator`)
- Population (rocks/trees/mushrooms/plants): `res://scripts/terrain/arena_population.gd` (`ArenaPopulation`), `res://scripts/terrain/arena_object.gd`
- Hazards: `res://scripts/terrain/mud_patch.gd`, `res://scripts/terrain/bear_trap.gd`
- Wall modules: `res://scripts/terrain/terrain_module.gd`
- Day/night: `res://scripts/forest_night_lighting.gd`, `res://scripts/forest_night_math.gd`
- Chasm zone: `res://scripts/chasm_stage.gd`

## UI
- HUD/menus: `res://scripts/main.gd` + `res://scripts/ui/` (`home_menu.gd`, `pause_menu.gd`, `mobile_controls.gd`, `end_run_hub.gd`)
- Training Tools layout: `res://scripts/ui/backyard_training_menu.gd::centered_training_rect()` / `_apply_training_layout()` — 900×600 desktop target, viewport margins on smaller screens, and the toggle+panel are centered as one assembly on viewport resize. Every revised tuner must provide description / ← LEFT / → RIGHT / TIP guidance on its label, `[?]` badge, and slider hover area; Grapple guidance is centralized in `_grapple_feel_tip()`.
- Form III hinge bind: `res://scripts/player.gd::experimental_hinge_correction()` / `_apply_experimental_bind_retention()` — a validated slide owns one opponent and one blade-plane side. Candidate contact gets soft retention; stable contact strongly resists crossing while motion opening away is unconstrained. Other enemy weapons remain ordinary contacts, preventing multi-sword pinning. Form II windup acceleration cannot multiply Form III's configured contact speed above its ceiling.
- Grapple Yo-yo: `res://scripts/grapple_controller.gd` + `res://scripts/chakram.gd` — active gameplay includes direct flying-Chakram attachment, tuned slack take-up, tangential preservation, hand redirection, hang, reel return, static pivots, enemy/terrain boundary wrapping, committed coils, and collision-validated unwind. Light/Medium/Heavy target weight remains authoritative. Current defaults enable both wrap switches. Detailed authority and invariants: `res://Ziva Help/GRAPPLE_YOYO_PARKING_LOT.md`.
- Metronome visualizer: `res://scripts/ui/metronome_visualizer.gd`, `res://scripts/ui/metronome_top_bar.gd`
- Boss dialogue: `res://scripts/ui/boss_dialogue_box.gd`

## Audio / Music
- Music director: `res://scripts/audio/music_director.gd` (`MusicDirector`) — single `AudioStreamPlayer`, mode-based (COMBAT/HOME/FORGE/SILENT/BOSS)
- SFX pool: `res://scripts/audio_manager.gd` (`AudioManager`)

## Save / Meta Progression
- Save/load: `res://scripts/main.gd` — `save_game()` / `load_game()`
- Combat preset persistence: `res://scripts/combat_settings_config.gd` → `user://combat_presets_config.json`. `Player.ensure_experimental_form_initialized()` promotes the old Curved Sword style-9 Bind profile into one shared canonical style-9 profile, strips per-weapon/retired-style Bind fields, and leaves obsolete `bind_slide_*` fields inert. Both persisted Bind IDs resolve canonical style 9; only ID 9 is selectable. Global Preset 2 is the current source-of-truth launch package. Forest phase bundles are synchronized through Global Preset SAVE ALL; legacy Bind IDs remain save-compatible and no duplicate Bind authorities are active.
- Progression/crafting/farming: `res://scripts/home/home_progression.gd`
- Cooking: `res://scripts/home/cooking_config.gd`

## Do Not Scan Unless Needed
- `.godot/`, `addons/ziva_agent/`, `.ziva/`
- exports/, builds/, screenshots/, recordings/
- reference art/, raw generated art/ under `assets/generated/` (unless the task is about that specific asset)
- large audio folders under `assets/audio/`
