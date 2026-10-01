# PX MODE — Project Memory

The durable memory for the physics-sword line of work. Read this before touching
anything under `res://blade_dancer_px/` or the PX Mode half of Training Tools.
It exists because a chat's context does not survive across days — this file does.

## The goal

Two things, in order:

1. **Learn the physical instrument from the bottom up.** Stop chasing the old
   authored sword and its expectations. Start from the raw physics sword, add one
   knob at a time, and feel each one before touching the next. Progress you can
   *feel* comes from that, not from measuring the gap back to a memory.
2. **Bring that instrument into the real game**, behind a **PX Mode** toggle, so
   the physics sword (and physical enemies) can live inside Blade Dancer while OS
   Mode stays exactly as it was.

PX itself began as a **standalone playground** beside the game (`blade_dancer_px/`,
thesis: *real physics, no faking*). It is now being **inverted**: the game
deliberately references PX scripts (`px_inworld.gd`, `PXInWorldEnemies`,
`BDPXGlobal`) while PX keeps sharing **no** production gameplay code.

## Hard rules (do not break)

- **Never write a rigid sword's transform/pose.** Motion comes from torque; contact
  comes from the solver. Setting a transform makes the body kinematic and the whole
  experiment a lie. A velocity brake is allowed; a pose write is not.
- **PX never loads production gameplay scripts/scenes.** Shared *art* may be reused.
  (The reverse direction — the game referencing PX — is the deliberate inversion.)
- **The PX mode flag lives only in the PX save** (`user://bdpx_global.json`), never
  the game's GP2 preset save.
- **PX enemies deal no damage to the real player.** They are physics targets, not a
  second combat system.
- **Corners / curved-sword physics are not ported**, by design.

## Where it lives

| Piece | Path |
| --- | --- |
| Config (all numbers) | `blade_dancer_px/scripts/px_config.gd` (`Cfg`) |
| Blade builder/helpers | `blade_dancer_px/scripts/px_blade.gd` (`PXBlade`) |
| In-game physics sword | `blade_dancer_px/scripts/px_inworld.gd` (`PXInWorld`) |
| In-game physical enemies | `blade_dancer_px/scripts/px_inworld_enemies.gd` (`PXInWorldEnemies`) |
| PX save store | `blade_dancer_px/scripts/bdpx_global.gd` (`BDPXGlobal`) |
| Standalone proto/lab | `blade_dancer_px/scripts/px_game.gd`, `tools/px_sword_lab.tscn` |
| In-game tuner (PX half) | `scripts/ui/backyard_training_menu.gd::_build_px_tuner` |
| Game-side hooks | `scripts/main.gd` — `set_px_mode`, `_enable/_disable_px_world`, `apply_px_settings` |
| README (structure/rules) | `blade_dancer_px/README.md` |

## Current status

- **Shared gateway** at the top of Training Tools: **OS MODE / PX MODE** swap which
  tab set is shown. PX Mode adds a default-off `sword_stowed` flag to `player.gd`
  so the authored sword is fully hidden/inert while PX is active.
- **Sword size** matches the game (`Vector2(0.055, 0.055)`, centre offset
  `BLADE_LENGTH * 0.34`).
- **Helicopter Limit** — angular-velocity cap (deg/s), applied as a pure torque
  brake above the cap. Right end = off.
- **Flesh / core material model** — bone core is a real collider (bonk/turn); flesh
  is a non-collider ring (drag + damage). Medium defaults: drag 0.5, friction 0.35.
- **PX enemies** spawn on a ring around the player; 0–1 switches for Chasers / Duelists
  (armed) / Dummy. One of each stays alive (respawns). The spawn ring is **190-310 px**
  — deliberately inside one 1280x720 screen (half-extents 640x360) so a RESPAWN is
  always visible and lands inside the arena walls. (Was 300-460, which could drop a
  respawn off-screen or outside the walls, reading as "it never respawned".) Verified
  end-to-end by `tests/px_inworld_respawn_test.gd`, which boots the real `main.tscn`,
  kills a chaser, and asserts a fresh one returns on-screen.
- **Global (BDPX save)** section (top of PX Motor, under the baseline button): explicit
  **Save Settings** / **Load Saved** buttons and a "Last saved" readout. Every control
  already auto-saves to `bdpx_global.json` as it moves; this makes that explicit and
  lets you revert to the saved setup. Same authority, never a second save file.
- **Metronome became its own tab, and every binary is now a 0–1 slider.** *PX Metronome*
  holds Metronome Swing / Arc / Frequency / Metronome Lead, then the ported OS shaping as
  **Stroke Timing** (Wind-up profile/shares/speeds), **Action Commitment**, **Arc Energy**
  and **Apex Hang** — each a collapsible section. The tab spells out that everything in
  it does nothing unless the swing is ON (all of it is read only inside
  `_advance_target`'s metronome branch). Every PX on/off — Metronome Swing, Servo
  Feedforward, Hilt Spring, Show Ghost, Spawn Chaser / Sword Enemy / Test Dummy — is a
  BDOS-style `HSlider` (min 0, max 1, step 1, `— OFF / ON`), **not** a toggle button;
  `_px_add_toggle` was removed. Matches the OS Combat Preset's switch sliders.
- **Sword Physics group** (top of PX Motor) — **Sword Mass / Angular Damping /
  Linear Damping / Center of Mass Offset**: the blade BODY's own properties, added as a
  **section header** (by request: a header, not a tab). **Grip / Wrist** is the header
  over the existing stiffness/damping/max-torque trio — the same three knobs, just
  framed as "how strongly YOU control the object". Body and grip sit together on purpose
  because they interact: Godot derives the blade's rotational inertia from mass and
  shape, so mass silently re-scales what every stiffness value means (which is exactly
  why the ladder fixes mass first). Damping modes are set to **REPLACE** so the slider
  value *is* the damping (0 = honestly off, instead of the project's 0.1 default adding
  in through COMBINE). Centre of mass is **CUSTOM**, in px from the hilt, default 42
  (Godot's own auto mid-blade point), clamped to the blade. Verified by
  `tests/px_sword_body_test.gd`: the values reach the rigid body, and the body stays a
  free rigid body — no freeze, no rotation lock, no pose write.
- **The OS shaping, re-implemented in BDPX (ported AS DATA, never by calling game
  code).** *Stroke Timing* (wind-up raw-speed profile + recovery shares; the time
  normalizer keeps the average tempo = Frequency), *Action Commitment* (inside a
  progress window the aim's authority over the swing is blended out), *Arc Energy*
  ("Authored Metronome" wake/sleep: aim travel above the wake speed fills the energy,
  idle past the grace bleeds it, and the arc width scales by `smoothstep(0,1,energy)`),
  and *Apex Hang* (a bounded dwell frozen at the top of each stroke, armed when the
  stroke turns over and scaled by the blade's `_apex_drive()`). All default-OFF/inert;
  all target shaping only. Verified by `tests/px_windup_test.gd`,
  `px_action_commitment_test.gd`, `px_authored_metronome_test.gd`.
- **Core Sword & Reach lives in PX now — "PX owns its aim."** Rather than reading the
  game's `player.aim_angle` (which the game had already shaped), PX runs **its own**
  two-stage aim filter in `_update_aim(delta)`: the aim POINT drags toward the cursor
  (Overall Mouse Drag), then the aim ANGLE drags toward the point (Rotation Speed),
  capped at Max Turn Speed — the same filter the lab proved in `px_game.gd`. Aim Inertia
  OFF = the cursor is the aim, instantly. Pure input shaping: it only decides where the
  motor is ASKED to point, so the blade still earns every degree. Verified by
  `tests/px_aim_reach_test.gd`.
- **Labels use the mechanism's real name** (Motor Stiffness / Motor Damping / Max
  Torque / Metronome Swing / Arc / Frequency / Metronome Lead / Helicopter Limit /
  Servo Feedforward / Hilt Spring / Show Ghost / Ghost Opacity / Hand Min / Hand Max /
  Spawn Chaser / Spawn Sword Enemy / Spawn Test Dummy / Flesh Radius / Flesh Drag /
  Core Radius / Bone Friction / Enemy Mass). The bench nickname rides in the tooltip.
- Uncommitted work is on branch `Blade-Dancer-PX`.

## The tuning ladder (how to learn it)

Always **one knob, then swing** — name the difference, don't just tune.

0. **Reset to Clean Baseline** (button, top of PX Motor) — the floor.
1. **Raw sword, Metronome Swing OFF** — just tracks your aim. The trailing lag *is*
   the physical sword. Set **Sword Mass** once here and then leave it — it re-scales
   everything below it.
2. **Motor Stiffness** — sluggish ↔ snappy.
3. **Motor Damping** — wobble ↔ syrup. Keep it near **100 × √Stiffness** for a clean
   hold; far below that the blade rings and helicopter-spins.
4. **Max Torque** — how hard it holds its line.
5. **Hilt Spring** — welded ↔ shoved-and-recovers.
6. **Metronome Swing** ON — now you can feel what changed.
7. **Flesh & Core** on the Dummy — last, because it only means something once the
   neutral sword is known.

### What Godot is doing under the sword (measured this pass)

- `inertia` is left at **0 = auto**, so Godot computes it from mass and the collision
  shape. The blade is an **84 × 12** rectangle with its collider centred mid-blade, so
  the auto centre of mass sits at **42 px from the hilt** and I_com ≈ **600**
  (m·(L²+t²)/12); about the *pinned hilt* that is ≈ **2364** (parallel axis). This is the
  number the motor actually fights.
- A **CUSTOM** centre of mass makes Godot recompute the inertia it reports about the new
  point, but it does **not** change the physical mass distribution. With gravity OFF and
  the hilt pinned there is no hanging weight, so the COM slider is a collision/inertia
  knob here, not a "tip-heavy balance" knob. (Inertia can also be set directly — 0 = auto
  — if we ever want "heavy but nimble" without moving the mass.)
- **Damping-ratio rule of thumb: ζ = c / (2·√(k·I))**. Keep ζ near 1 — at the stock
  mass that is roughly **c ≈ 100 × √k** — for a clean hold. Far below it the blade rings
  and helicopter-spins. **Raising Stiffness alone does NOT cure helicoptering** (it makes
  the ringing worse unless Damping rises with it); Stiffness sets *how hard* it corrects,
  Damping sets *how composed* the correction is, and Max Torque decides whether a real
  collision can still overpower the grip.

## UI & naming conventions (agreed 2026-10, Matt + Ziva)

Consistency is the whole point — a PX control must read exactly like an OS one.

1. **Named for the mechanism.** The primary label is the mechanism's real, traditional
   name (e.g. *Motor Damping*, *Helicopter Limit*, *Metronome Lead*). The bench
   **nickname** (e.g. *Settle*, *Wobble Brake*) now lives at the front of the tooltip's
   **WHAT IT IS** line, so the friendly word survives without a second label on the
   control. (Reversed from the brief two-name experiment at Matt's request, 2026-10.)
2. **`[?]` badge on every control**, identical to the OS one: a `Label` reading
   `[?]`, `mouse_filter = STOP`, `modulate = Color(0.45, 0.85, 1.0, 0.9)`, carrying
   the tooltip — as do the label and the slider.
3. **One tooltip builder.** PX tooltips are produced by the OS builder
   (`_form_three_feel_tip`), wrapped by `_px_control_tip` to add `WHAT IT IS` and
   `FEELS LIKE` on top. OS output keeps its exact tokens (`← LEFT:`, `→ RIGHT:`,
   `TIP:`).
4. **Grouping = OS style.** Few **tabs**, and inside each a set of **collapsible
   section headers** (`_create_section_header`), exactly like the OS Combat Preset.
   **5 PX tabs**: *PX Motor*, ***PX Metronome***, *PX Aim & Hand*, *PX Enemies*,
   *PX Flesh & Core*. The Swing/Metronome mode earns its **own tab** — it is a whole
   MODE of the sword, not a motor tweak — and that tab carries a note that
   *Arc / Frequency / Metronome Lead* are dormant unless the swing is ON. Ghost lives
   as a **section** under Motor, not its own tab. Within *PX Motor* the sections are
   **Global (BDPX save) → Sword Physics → Grip / Wrist → Safeguards → Visuals**. A whole
   *group* earns a header; a whole *object/mode* can earn a tab. This is how the panel
   survives growing to 100 sliders without becoming a maze.
5. **No toggle buttons — binaries are 0–1 sliders.** Every on/off in the PX tuner is an
   `HSlider` with **min 0, max 1, step 1** and a `— OFF / ON` label, exactly like the OS
   Combat Preset's switches (*Bone Slide*, *Blade Shell*, *Full Physical*, …). This
   replaces the earlier PX toggle buttons; the value label reads `0` / `1`, and tooltips
   phrase both ends as `OFF (0)` / `ON (1)`. Consistent with BDOS by design.

## Decisions log

- Invert PX into the game behind a PX Mode toggle; PX stays the tuning lab.
- One sword per mode; the ghost overlay is optional and PX-only.
- Flesh/core is a **material model** (drag force + damage in flesh, real collider at
  core), not an animation.
- PX Mode flag lives in the BDPX save only; `_set_px_mode` mutates that one value.
- Controls named for the mechanism (traditional name); the bench nickname moves into
  the tooltip. OS-matching grouping and `[?]` badges kept.
- Binaries are **0–1 sliders**, not toggle buttons (BDOS-consistent), and **Metronome
  owns its own tab** with its three sweep controls, plus a note that they only act while
  the swing is ON.
- The sword's own physics (**Sword Physics**: mass / angular damp / linear damp / COM)
  and the grip (**Grip / Wrist**: stiffness / damping / max torque) are **two groups of
  one tab** — headers, not tabs — because they interact through mass/inertia. Mass is
  set once; the grip trio is the daily tuning.

## Open questions

- Should the game's **own** enemies adopt the flesh/core material model? (They are
  still kinematic `CharacterBody2D`; PX enemies are the physical ones.)
- ~~If "Wobble Brake" still helicopters at a low cap, find what is feeding the spin.~~
  **Resolved 2026-10:** the spin was an **underdamped motor**, not the brake — the live
  save had `damping 2100` against `stiffness 137000` (ratio ≈ 0.06). Fix: hold
  **Damping ≈ 100 × √Stiffness** (≈36000 here). A teaching hint was added to the Motor
  Damping tooltip. Same cause read as a "broken" metronome (the sweep rang instead of
  tracking).
- Optional: a continuous metronome **blend** slider (1 = pure your-aim, 0 = full
  swing) if the on/off toggle proves too coarse.
- **Center of Mass Offset** is exposed but its payoff is bounded by gravity being OFF and
  the hilt being pinned. If it proves inert in play, the next lever is a raw **Inertia**
  knob (Godot's `inertia`, 0 = auto) — the more direct "how reluctant is this blade to
  change its spin" control. Decide after Matt playtests the COM slider.