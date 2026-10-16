# Blade Dancer PX

A **standalone physics playground** that lives *beside* the game, not inside it.
Nothing here is loaded by `res://scenes/main.tscn` gameplay; the only entry points
are two hub buttons (PX MODE — LAB, PX PROTO — PLAY).

## The thesis

> **Real physics, no faking.**

Player, enemies and every sword/weapon stay **real collision shapes**. A blade's
*pose* comes from a **torque motor** (a PD controller), and its *interactions*
come from Godot's solver. Nothing about the blade is authored animation — we never
write a sword's `transform`/`rotation`, because that would make the body
**kinematic** (it would then pass through everything and the whole experiment
would be a lie).

## Folder map

| Path | What it is |
| --- | --- |
| `scripts/px_config.gd` | `RefCounted`. Every constant: physics layers, arena, player, hand radius, blade, motor defaults, enemies. **Single source of truth for numbers.** |
| `scripts/px_blade.gd` | `RefCounted`. Static helpers that build a physical blade: `make_blade()`, `make_grip()`, `pin()`, `tip_of()`, `pd_torque()`. |
| `scripts/px_arena.gd` | `RefCounted`. Builds the walled arena; `random_edge_point()` for spawns. |
| `scripts/px_test_dummy.gd` | `RefCounted`. Builds the stationary Test Dummy and owns its damage floor and once-per-second regeneration. |
| `scripts/px_hud.gd` | `CanvasLayer`. The on-screen readout (`set_lines()`). |
| `scripts/px_tuning_tools.gd` | `CanvasLayer`. The **Tuning Tools** overlay, arranged like the game's own: ONE bar across the top that drops the tabbed panel open (click again to hide it) — Combat Tuning (motor stiffness / damping / max torque; the **Metronome Swing** toggle with its **Arc** and **Swing Frequency**; and the hand's **Hand Min** / **Hand Max** reach), and Enemies spawn toggles including the stationary Test Dummy. |
| `scripts/px_game.gd` | `BladeDancerPX`. The **coordinator**: owns the player, the enemy list, the simulation loop and drawing. Glues the modules together; the Enemies tab can spawn a stationary **Test Dummy** (100 HP, 1 HP floor, +10 HP each second). |
| `tools/px_sword_lab.gd` / `.tscn` | `PXMotorSwordLab`. The isolated A/B rig — torque-only motion against a hard obstacle. |
| `tests/px_game_test.gd` | Suite for the playable prototype. |
| `tests/px_sword_lab_test.gd` | Suite for the lab + the hub wiring. |
| `scenes/px_game.tscn` | The playable prototype scene. |

## Protocols (please read before editing)

1. **Isolation.** PX shares **no runtime code** with production. It must not
   reference `res://scripts/`, `res://scenes/` or `AITestTools` — enforced by a
   test. It *may* re-express a game behaviour in its own code and copy the
   numbers across by hand (blade length, speeds, the metronome's arc and
   frequency); it must never **link** to production behaviour.
2. **Only the coordinator touches the tree.** Modules are small and focused; they
   receive a parent node and build their own part. If you need new shared logic,
   make a module — do not grow `px_game.gd`.
3. **Numbers live in `px_config.gd`.** Never hard-code a gameplay constant in a
   module body. Live tunables (the sliders) are the exception and live on the
   tuner.
4. **Never write a RigidBody's transform.** Move the *grip/anchor* instead and let
   the pin carry the blade. Setting a transform is "faking" (see thesis).
5. **Tests bind by preloaded path**, not by global `class_name`. The editor's
   global class cache goes stale after file moves and will otherwise produce
   phantom `Could not find type` errors in headless runs.
6. **`PX MODE` and `PX PROTO` are the only doors in.** Wiring lives in
   `scripts/main.gd` + `scripts/ui/end_run_hub.gd`. Both lift the hub's pause for
   the lifetime of the PX run (a paused tree freezes `RigidBody2D`s) and restore
   it on close.