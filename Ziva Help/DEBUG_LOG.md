# DEBUG_LOG.md — Blade Dancer

Use this file to prevent repeated debugging work. A fresh/compacted Ziva
session has zero memory of past investigations — this file is the only thing
that survives that. Keep entries even after "Fixed"; the value is in not
re-deriving the cause from scratch, not in a clean changelog.

## Format
### YYYY-MM-DD — Short issue name
**Symptom:** what the player/dev sees.
**Relevant files:** file list.
**What was tested:** test/result.
**Cause:** confirmed cause, if known.
**Fix:** what changed.
**Status:** Fixed / Partial / Unresolved.
**Do not retry:** approaches already ruled out.

---

## Current Known Issues

### 2026-09-15 — Global Preset Forest phase routing reset
**Symptom:** Night and other Forest phase tuning could appear to reset after SAVE ALL, changing global slots, loading, or advancing the day cycle.
**Relevant files:**
- `res://scripts/main.gd`
- `res://scripts/ui/forest_visual_tuner.gd`
- `res://scripts/forest_visual_settings.gd`
**What was tested:** Global Preset 2 phase isolation, menu flow, and main-scene boot. A contaminated GP2 phase bundle was detected and repaired from the preserved Forest day-preset source.
**Cause:** SAVE ALL changed the active global slot before capture, leaving live phase edits under the previous nested slot; Main's runtime phase cache was not refreshed after saving; external phase changes did not synchronize the tuner selection; applying a phase reset bypass after the tuner had applied its snapshot could also clear the saved bypass state.
**Fix:** Capture before changing the target slot, copy the live day-cycle bundle into the target slot, refresh the runtime cache after a successful save, synchronize externally advanced phases, restore bypass after phase materialization, and clear Forest dirty markers after confirmed Global SAVE ALL.
**Status:** Fixed and regression-verified.
**Do not retry:** Do not force Noon or reload legacy Forest files when reopening Training Tools. Do not treat `forest_values` or legacy `forest_visuals.cfg` as a parallel runtime authority.


### (backfilled) — Invisible mud patches / bear traps after visiting Chasm
**Symptom:**
Player movement "felt off" (slowed/rooted) in specific Forest spots with
nothing visible there — always in spots where terrain hazards spawn.

**Relevant files:**
- `res://scripts/terrain/arena_generator.gd`

**What was tested:**
Traced `set_forest_content_enabled()` and `regenerate()` — confirmed
`trap_overlay` (parent `Node2D` for every `MudPatch`/`BearTrap`) gets
`visible = false` when entering the Chasm, but `Area2D` collision/slow/root
effects are unaffected by node visibility, so gameplay-affecting hazards kept
working while invisible.

**Cause:**
`set_forest_content_enabled(true)` (re-entering Forest/Backyard after Chasm)
never restored `trap_overlay.visible = true` — it just `return`ed early. Every
mud patch/bear trap placed by a later `regenerate()` inherited the hidden
parent and rendered nothing while still fully affecting movement.

**Fix:**
`set_forest_content_enabled(true)` now explicitly restores
`trap_overlay.visible = true` and `population.visible = true`. `regenerate()`
also unconditionally re-arms both as a defensive belt-and-suspenders, so this
can't silently regress from some other code path hiding them.

**Status:** Fixed. Regression-covered by
`tests/chasm_boundary_test.gd::test_forest_generation_restores_after_leaving_chasm`
(now asserts `trap_overlay.visible` and `population.visible` are restored).

**Do not retry:** N/A.

---

### (backfilled) — `club_hit_cooldown` stale identifier parse error
**Symptom:**
Godot reported `Identifier "club_hit_cooldown" not declared in the current
scope.` after Zungar's weapon was renamed from "club" to "Executioner Sword."

**Relevant files:**
- `res://scripts/boss/zungar.gd`
- `res://scripts/boss/zungar_config.gd`

**What was tested:**
Searched for remaining `club_hit_cooldown` references after the rename;
found leftover usages that were never updated to the new
`executioner_sword_hit_cooldown` field name.

**Cause:**
Partial rename — the variable declaration was renamed but not every call
site, leaving a dangling reference to a variable that no longer existed.

**Fix:**
Renamed all remaining references to match `executioner_sword_hit_cooldown`.
Legacy `CLUB_*` constants were kept in `zungar_config.gd` as compatibility
aliases pointing at the new `EXECUTIONER_SWORD_*` constants specifically so
this class of error is less likely to recur from old tests/tools.

**Status:** Fixed.

**Do not retry:** N/A.

---

### (backfilled) — Metronome visualizer `material` shadowing engine property
**Symptom:**
Godot reported `The local variable "material" is shadowing an already-declared
property in the base class "CanvasItem".` in the metronome visualizer script.

**Relevant files:**
- `res://scripts/ui/metronome_visualizer.gd`

**What was tested:**
Confirmed `CanvasItem` already exposes a `material` property; a local
variable of the same name in the visualizer script was shadowing it.

**Cause:**
Naming collision between a locally-declared variable and the inherited
`CanvasItem.material` property.

**Fix:**
Renamed the local variable to a non-colliding name.

**Status:** Fixed.

**Do not retry:** N/A.

---

### 2026-09-11 — Invisible rock/tree colliders during the Zungar boss fight
**Symptom:**
During the Zungar fight the player and the boss collided with apparently empty
ground; Zungar got wedged and effectively stopped functioning. Earlier reported
as "rocks and trees are showing up as invisible collisions."

**Relevant files:**
- `res://scripts/terrain/arena_generator.gd` (`prepare_boss_arena()`)
- `res://scripts/terrain/arena_population.gd` (`clear_population()`)
- `res://scripts/terrain/arena_object.gd` (`_create_collision()`)

**What was tested:**
- Collision-layer trace: `ArenaObject` StaticBody2D is layer 3 (value 4);
  player mask = 4 and enemy/Zungar mask = 6 both include it, so both bodies
  collide with population props.
- Confirmed normal Forest waves render rocks/trees fine (population z_index 1,
  rock sprites z=1 over floor z=0, trees z=3) — so this is NOT a general
  invisibility bug and NOT the same as the trap-overlay bug above.
- New regression test `tests/boss_arena_population_test.gd` (2 tests) passes.

**Cause:**
`ArenaGenerator.prepare_boss_arena()` set `population.visible = false` but never
cleared the population. Hiding a parent does NOT disable child `StaticBody2D`
colliders, so every population rock/tree/log/torch stayed solid yet invisible
for the whole boss fight — invisible walls that wedged Zungar and the player.

**Fix:**
`prepare_boss_arena()` now calls `population.clear_population()` (frees the
props and their colliders). Added an explicit `ArenaGenerator.boss_arena_active`
flag (set in `prepare_boss_arena()`, cleared by the next normal `regenerate()`)
encoding the rule "boss waves contain no population props." The existing
`regenerate()` on the next wave transition restores the population afterwards.

**Status:** Fixed (regression-covered).

**Do not retry:**
- Do NOT "fix" this by only hiding the population node — that IS the bug.
- Do NOT assume it was the same cause as the trap-overlay issue; separate paths.
