# CHECKPOINT — Bind B Global Preset 2 → 3

Date: 2026-09-13  
Sword: Basic Curved Sword  
Combat preset: 2  
Form: IV — Bind B (TEST)

## Observed Feel Report

Global Preset 2 felt too frozen/glitchy. Slow motion sometimes appeared to outlast the visible slide, and binds occurred too often. The large overhead live diagnostic was readable but too visually invasive during play.

## Saved Global Preset 2 — Relevant Values

- Entry angle: 44°
- Entry contact tolerance: 24 px
- Entry cling: 2.00 s
- Entry movement multiplier: 0.40×
- Entry sword speed: 0.16×
- Entry visual duration: 1.55 s
- Capture time: 0.05 s
- Minimum pressure: 4 px/s
- Bind contact tolerance: 26 px
- Retention: 0.95×
- Bound sword speed: 0.10×
- Release grace: 0.22 s
- Maximum bind: 2.60 s
- Re-bind suppression: 0.50 s
- World speed: 0.50×
- Focus zoom: 0.15
- Focus bias: 0.80
- Focus response: 8.0×
- Beat pressure: 400 px/s
- Beat spike: 120 px/s
- Beat leverage: 0.10
- Scrape interval: 0.34 s

## Authored Global Preset 3 Comparison

Global Preset 3 was cloned from the saved Global Preset 2 and changes only these Form IV Bind B values in the shared and Basic Curved Sword dictionaries:

- World speed: **0.50 → 0.70×**
- Bound sword speed: **0.10 → 0.18×**
- Retention: **0.95 → 0.82×**
- Entry cling: **2.00 → 1.60 s**
- Entry visual duration: **1.55 → 1.20 s**
- Maximum bind: **2.60 → 1.90 s**
- Capture time: **0.05 → 0.08 s**
- Minimum pressure: **4 → 12 px/s**

Everything else is inherited unchanged from the saved Global Preset 2.

## Safety Verification

- Global Preset 2 compared equal before and after writing Preset 3.
- Active editing slot became Global Preset 3.
- Launch slot remains Global Preset 2.

## Debug Presentation Change

The invasive two-line overhead live panel was removed. Bind forms now show one small counter line in the same visual spirit as the original slide counter:

`Slides N · Binds N · Winds N · Beats success/rejected`

The top-right expandable tracker retains the detailed measurements and event history.

## Follow-up Fixes (same day)

### Longsword Bind B was stale in GP3

The initial GP3 pass only touched the Curved Sword's Form IV override. Basic Longsword's Form IV (`2:9`) override in GP3 still carried old values (`bind_capture_time: 0.05`, `bind_max_duration: 2.6`) because per-sword overrides shadow the shared values — so Longsword's Bind B would have silently stayed on the "too frozen" profile.

Fixed by rebuilding Longsword's `2:9` override in GP3 from GP2's Longsword `2:8` (Form III / Bind A) override, merged with the same tuning deltas Curved Sword received (capture time, pressure minimum, retention, bound sword speed, release grace, max duration, focus time scale, slide entry values). Longsword's own identity values (`forward_impulse`, `rotation`, `mouse_drag`, `radial_response`, `swing_commitment`, `max`) carried through unchanged. GP2 and Curved Sword's GP3 override were both re-verified unchanged after this edit.

### Training Tools sword selector didn't track the equipped sword

Root cause: `_build_combat_sword_selector()` only read `player.equipped_sword_id` once, at menu construction time. Every later `open()` call reused that stale value, so Training Tools always showed whichever sword was equipped at boot (effectively always Longsword) regardless of what was actually equipped in-game.

Fixed: `open()` now re-reads the live player's `equipped_sword_id`, reselects the dropdown, and refreshes blade-shape controls every time Training Tools opens. Covered by a new regression test: `test_training_tools_resyncs_the_sword_selector_to_the_live_equipped_sword_on_open` in `res://tests/menu_flow_test.gd`.

## Playtest Question

Does Preset 3 preserve the readable physical hinge while reducing interruption and incidental capture? Compare ten plausible contacts in GP2 and GP3 before changing more values.

## Reasoning Recommendation

**Low** for direct value comparison and feel notes. Move to **Medium** only if slide FX and slow-motion timing still disagree after these duration/speed changes, because that may indicate timer-domain synchronization rather than tuning alone.
