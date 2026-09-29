# AGENTS.md — Blade Dancer Development Protocol

## Mission
Work on Blade Dancer efficiently, conservatively, and with minimal unnecessary repository scanning.
Prefer targeted inspection and small patches over broad rewrites.

## Golden Rules
1. Review this `AGENTS.md` before implementing changes or consulting project-specific working rules - every single time. The protocol applies to discussion as much as to implementation: on the FIRST `/discuss`-style prompt of a session, read this `AGENTS.md` and `COLLABORATION_PROTOCOL.md` in full before responding. Discussion mode is not an exemption from the protocol - it is the moment the protocol matters most, because decisions made in discussion set the course of the work that follows.
2. Ask clarifying questions whenever missing information could materially change the implementation or the direction of a discussion. Ask before implementation when scope, intended behavior, constraints, or design choices are unclear; during discussion, ask as soon as a user's preference or meaning is ambiguous. Continue independent work that does not depend on the answer, and do not guess on a consequential decision.
3. DO NOT scan the entire project unless the task genuinely requires it.
4. Before opening many files, search for the relevant symbol, scene, node, signal, class, or resource name.
5. Read PROJECT_MAP.md first for system/file locations.
6. Start with the smallest plausible set of files. Initial inspection target: 3–6 files.
7. Do not inspect binary art/audio/video assets unless the task explicitly concerns them.
8. Ignore build/export/cache/import folders.
9. Preserve working systems outside the requested scope.
10. Prefer minimal patches. Do not refactor unrelated code during a bug fix or tuning task.
11. For tuning tasks, change exposed/config values before rewriting behavior.
12. If two hypotheses fail, stop broad experimentation and summarize:
	- what was tested
	- what was ruled out
	- the next most likely cause
13. Never add a redundant feature, slider, timer/cooldown, state variable, code path, or helper for behavior an existing system already owns. Locate and extend the canonical implementation instead of creating parallel or duplicated logic/UI. If a behavior is genuinely distinct, explain its distinct lifecycle and purpose before adding a separate authority; ask if that distinction is unclear.
14. ALWAYS compare version control against current files when implementing, tuning, or bug-fixing. Before forming a hypothesis, diff the current files against the last known-good state and read the diff. See "Baseline Comparison Protocol — Git & Working-Tree First" below. A regression is found by diffing what changed, not by re-reasoning the whole subsystem.
15. Reference the LIVE PLAYER SAVE — not the packaged launch defaults — whenever testing, iterating, implementing, or discussing. See "Live Save vs. Packaged Defaults" below. The values Matt actually plays are in the live GP2 save; the packaged `res://data/default_global_preset.json` matters ONLY when packaging a build or discussing an Itch/release upload. Never cite packaged values as if they were what Matt is playing. When in doubt about a setting's current value, read the live save first.

## Baseline Comparison Protocol — Git & Working-Tree First

Before implementing, tuning, or bug-fixing anything that touches an existing
system, compare the current files against the last known-good state. The answer
to "what changed?" usually lives in version control, not in a fresh hypothesis.
This is the FIRST step of every implement / tune / fix task — not an optional
last resort.

Mandatory first steps:
1. `git status` and `git log --oneline -n 20` — know the recent commits and
   exactly what is uncommitted in the working tree.
2. `git diff <last-known-good>..HEAD -- <relevant files>` for every file the task
   touches, and `git diff -- <file>` for uncommitted work.
3. Read that diff line by line BEFORE editing anything. Compare baseline vs
   current for the exact functions/symbols involved.
4. Only once the diff is understood, form a hypothesis and patch minimally.

Rules:
- A regression — something that used to work and now does not — MUST be diffed
  against the last commit where it worked. Find the change that broke it; do not
  rebuild the system around it.
- Never rebuild, rewrite, or add parallel systems/tuners for behavior a previous
  revision already owned and that a small patch can restore.
- When a symptom "used to be fine," treat the diff between then and now as the
  primary suspect list — not the entire subsystem.
- Do not begin speculative rebuilding while a diff against the baseline is
  unexplored. Three failed hypotheses means: stop, diff, summarize (Rule 12).
- `git log -S <symbol>` / `git log -p -- <file>` locate when a specific line
  changed, even across many commits.

Incident (2026-09-28): A one-line regression (`_world_to_fx_local` converted
particles through the PARENT transform instead of the node's own transform, so
every particle drew at roughly double its world position, off-screen) presented
as "the blood is gone." It was misdiagnosed as a dead blood system: a brand-new
spray was rebuilt and two new tuners added — roughly three hours of prompting.
`git diff <baseline>..HEAD` located the offending line in minutes. Treat this as
the canonical failure mode this rule exists to prevent.

## Live Save vs. Packaged Defaults

Matt plays from his live save. That save is the source of truth for every test, tuning
pass, implementation, and discussion. The packaged file is a ship artifact only — it is
NOT what Matt experiences while iterating, and quoting it as "current" has caused repeated,
confusing mistakes.

- LIVE SAVE (what Matt is actually playing): `user://blade_dancer_global_presets.json`,
  read the slot named by `active_slot`. On this machine it resolves to
  `C:/Users/ratnu/AppData/Roaming/Godot/app_userdata/Blade Dancer/blade_dancer_global_presets.json`.
- PACKAGED LAUNCH DEFAULTS: `res://data/default_global_preset.json`. Reference this ONLY
  when packaging a build, or when discussing an Itch / release upload. In every other
  context it is the wrong file.
- Before stating any setting's current value, READ THE LIVE SAVE. If the live save and the
  packaged file disagree, the live save wins for all gameplay work (the two commonly
  diverge because the packaged file is only re-baked at release time).
- Never edit the live save by hand — it is Matt's. Read it freely.
- Adding a key or changing a value in the live save does not ship it. New defaults reach
  players only when the packaged file is re-baked, which is a deliberate, user-approved
  packaging step — not part of a normal tuning pass.

Revised 2026-09-28 after repeatedly citing `data/default_global_preset.json` for settings
that differed from Matt's live GP2 save (e.g. the blade-response block is ON and near maxed
in the live save but OFF in the packaged file).

## Efficient Investigation Protocol
For every task:

### 1. Define the target
State internally:
- desired behavior
- current incorrect behavior
- likely subsystem
- likely files

### 2. Locate before reading
Use symbol/text search first.
Examples:
- class names
- function names
- node names
- signals
- exported variables
- scene names
- resource names

Do not recursively read every script.
Also search version control for the same symbol (`git log -S <symbol>`,
`git log -p -- <file>`) and diff baseline vs current — see "Baseline Comparison
Protocol — Git & Working-Tree First".

### 3. Inspect narrowly
Open only the files directly connected to the target.
Expand outward only when a concrete dependency points there.

### 4. Form a hypothesis
Before editing, identify the most likely cause.
Avoid changing several unrelated systems at once.

### 5. Patch minimally
Make the smallest change that can prove or fix the hypothesis.

### 6. Validate
Run the narrowest useful test/check first.
Do not run expensive project-wide operations unless necessary.

### 7. Report
Summarize:
- files changed
- behavior changed
- important values changed
- anything still uncertain

## Godot-Specific Rules
- Treat `.godot/`, imported caches, exports, builds, screenshots, recordings, reference art, and generated files as non-source unless explicitly needed.
- Prefer script/resource inspection over parsing large scenes when the script reference is already known.
- Do not rewrite `.tscn` files wholesale for small changes.
- Preserve node paths, signal wiring, resource UIDs, and scene inheritance unless the task specifically requires changing them.
- Prefer `@export` variables or dedicated Resources for gameplay tuning.
- Keep boss balance/tuning values separate from core combat logic where practical.
- Do not alter global combat systems to fix one boss unless evidence shows the bug is global.
- Search for all references to a function/signal before renaming or deleting it.

## Boss-Fight Tuning Protocol
When tuning a boss:
1. Identify the boss scene and primary behavior script.
2. Identify the boss tuning/config resource or exported variables.
3. Identify only the player/combat systems directly touched by the boss.
4. Tune data first:
   - health
   - damage
   - cooldowns
   - telegraph timings
   - movement speed
   - recovery windows
   - phase thresholds
   - aggression/range values
5. Change logic only when tuning cannot produce the desired behavior.
6. Never perform a repo-wide combat rewrite for a boss-specific tuning request without explicit approval.

## Debugging Protocol
Use this order:
1. Reproduce / understand symptom.
2. Search exact relevant symbols.
3. Trace one execution path.
4. Check state/timing/signals.
5. Check collision/layers/masks if physical interaction is involved.
6. Check scene wiring/resources.
7. Patch one likely cause.
8. Re-test.
9. Only then broaden scope.

Avoid shotgun debugging.

Note: this order fits *logic* bugs well. It does not fit visual/feel work
(art, animation, effects) — see "Art & Feel Iteration" below for that case.

## Effect Validity — Not Present vs. Not Distinguishable

When an effect "isn't taking," prove it is EXECUTING before touching any value:
does the call actually fire, does the draw actually run, are the inputs sane?
Guessing at magnitude while the code never executes is the fastest way to burn a
session.

Then separate the two failure modes — they need opposite responses:
- **Not present** (the effect never happens / never draws / is culled / renders
  off-screen): a wiring, execution, or coordinate bug. Debug the PATH. Do not
  tune.
- **Not distinguishable** (the effect runs but is visually lost — too small, too
  brief, too low-contrast, overdrawn by a later stage): tune magnitude, timing,
  colour, and layer order.

Rule: if two tuning passes produce no visible change, the APPROACH is probably
wrong. Stop nudging values; escalate to a structural hypothesis, reconsider the
method, or hand back a plain "this approach isn't working, here's why." Never
spend hours tuning a system that may be fundamentally broken.

Incident (2026-09-28): "the blood is gone" was treated as a dead system and a
brand-new spray was rebuilt and tuned — but the blood was never absent; a
one-line coordinate regression drew it off-screen. That is a "not present"
class bug wearing a "not distinguishable" mask. Proving execution first would
have caught it in minutes. See "Baseline Comparison Protocol — Git &
Working-Tree First".

## Context Budget
Treat context as expensive.
- Prefer summaries over dumping entire files.
- Do not reopen unchanged files unnecessarily.
- Keep a short working set.
- Use PROJECT_MAP.md and DEBUG_LOG.md instead of rediscovering architecture every prompt.

## Blade Dancer Design Constraint
Technical changes should preserve the game's core identity:
- physical, momentum-aware sword combat
- readable, tactile impacts and parries
- high player agency and skill expression
- strong combat clarity
- minimal unnecessary complexity
- systems should earn their place through feel, gameplay, or progression

When a requested implementation conflicts with an established design rule, flag the conflict before making a large architectural change.

---

## Ziva Workflow Commitments
Agreed between the dev and Ziva after reviewing turn-time issues on this
project. These are practical process fixes, not generic advice — each one
maps to a real problem that happened on this project.

### 1. Turn scope
Large multi-feature requests (e.g. "fix the whole boss encounter: spawning,
summons, sword geometry, charge physics, animations, flame effects, and the
campfire") should be flagged and offered as a sequence of smaller turns
instead of silently executed as one mega-turn. One giant turn makes it much
harder to catch a bad direction early (e.g. rejected art, a wrong offset)
before it's buried under six other changes.

### 2. Art & feel iteration is not the same as logic debugging
For visual/animation/effect work (sprite generation, particle effects, boss
animation timing, "does this feel right"), do not write one large procedural
generator/effect and declare it done. Iterate in smaller increments with an
actual visual checkpoint (screenshot or the dev's own playtest) before
continuing. The "form one hypothesis → patch → re-test" debugging loop does
not apply here because there is no assertion for "looks good."

### 3. Generated animation atlas hygiene
AI-generated animation sheets must be visually inspected frame-by-frame before they are wired into gameplay. Generation can leave detached pixels, body/weapon fragments, or partial silhouettes at a frame's left/right edge; atlas slicing then makes those fragments look like Cauldron-style wraparound from the neighboring frame. For every generated atlas:
- verify the declared frame dimensions and grid;
- inspect every frame boundary for detached or clipped fragments;
- clean edge-bleed artifacts without erasing intentional silhouette pixels;
- confirm each sliced frame independently before declaring the animation complete.
Do not dismiss boundary fragments as harmless generation noise. This issue has appeared on Duelist/Goblin sheets and the scarf-free Leather Armor pass.

### 4. Test scope after a change
After making a change, run only the test file(s) that directly cover the
changed code first. Only broaden to a wider test sweep if there's a concrete
reason to suspect the change has wider impact. Do not re-run every
adjacent-seeming suite "just to be safe" by default — it was a real, avoidable
cost on past turns.

### 5. Never shell-patch engine files
Never use `sed`/`perl`/`awk`/raw bash text manipulation to edit `.gd`,
`.tscn`, or `.tres` files, even under time pressure or when the normal edit
tool is blocked. If an edit tool is blocked (e.g. a scene "changed on disk"
error), stop, re-sync by re-reading the file/scene tree, and either retry the
proper edit tool or ask the dev — do not reach for shell text-patching as a
workaround. This caused real damage once already: hand-tuned boss config
files got clobbered and had to be reconstructed from git history.

### 6. Visual & feel checks need an auto-spawning rig, not a manual playthrough
(Recurring agent miss.) When a visual, animation, or combat check needs "an enemy in
front of me", do not hand the task back to the dev to open the menu, pick a zone, and
hope the right enemy spawns — and do not call an art/FX change verified because unit
tests pass while nobody has seen it on screen. This project already ships harness
scenes under `res://tests/` that instance `res://scenes/main.tscn` and drive it from a
child node (`dev_wave_picker_harness.tscn`, `forest_visuals_live_harness.tscn`). Use
that pattern instead of inventing a parallel mini-scene:

- `res://tests/enemy_spawn_rig.tscn` (script `enemy_spawn_rig.gd`) is the combat bench.
  It calls Main's own `_start_backyard_run`, spawns `enemy_type` through Main's own
  `_spawn_training_enemy_at`, hides the tuner panel, and prints spawn / health / kill
  lines. Change `enemy_type` on its `EnemySpawnRig` node ("turkey", "bug", "ogre",
  "random", …) and run that scene.
- Drive the run with a single `run_scene` call and inject inputs; the live keys (] and [
  cycle the enemy type, K kills every spawn, Space lands a test hit) exist so a check
  never depends on the dev taking over.
- The rig must reproduce the REAL path — real enemy scenes, real spawn routine, real
  FX/audio calls (`present_enemy_hit`, `play_enemy_death`). A rig that fakes the subject
  proves nothing about the game.
- If `run_scene` refuses because the dev's own game is already in the Game tab, say what
  you wanted to run and why, then stop. Do not retry, and do not close their game.

The failure this prevents: a whole turn spent on "please spawn a turkey and tell me how
it looks", which is work the agent should be able to do itself in one call.

### 7. An art fix changes one property — never the design, and never deletes the old one
The hardest failure this project has produced, so it gets its own rule. Any request that
is a fix to art or feel ("sharper", "HD", "less blurry", "bigger", "cleaner", "the ends
look bad") is a **clarity** request. It authorises exactly one thing: improving the
property named, on the asset that already exists.

- **Change only what was asked.** Not the silhouette, not the palette, not the ornament,
  not the size, not the position. Do not "improve" a subject the dev already approved,
  and do not offer a redesign as a bonus. If the words are "make it HD, that's it", then
  the shape that comes out must be recognisably the same shape that went in.
- **Never delete, overwrite in place, or offer to clean up the previous version** while a
  look is still under review. The old asset file and the old constant stay on disk and
  reachable by a one-line revert until the dev says the new look is good. Cleanup of
  rejected art may only be *raised*, never performed, and only after sign-off.
- **"Same but HD" is a testable claim, so test it.** Pure interpolation-up-scaling proves
  nothing: measured on `health_bar_cap.png`, a 16px source Lanczos-resized to 64 and drawn
  back at the real 19px draw size produced an identical image (231 vs 229 distinct
  colours, no visible difference). Real clarity at a fixed draw size requires a rebuilt
  high-resolution source with hardened edges, and it must be compared against the current
  art at the *actual drawn size* — output at 8× zoom flatters everything and hides the
  problem. Look at the pixels before wiring anything in; `Image.load_from_file` + an
  `execute_script` composite is the cheap way to do that.
- **Before claiming a limit, find out whose limit it is.** If something "can't be
  done" or has a hard ceiling, check whether the constraint is the engine's, the
  scene's, or a number the agent itself wrote. On 2026-09-28 the health-bar end caps
  were explained to the dev as having a hard 16px detail ceiling — a ceiling that
  existed only because `CAP_WIDTH = 16.0`. The dev solved it in one line ("draw it
  bigger"); the agent had argued against it for two turns. A limit that is really a
  value in your own code is a choice to be offered, not physics to be explained.
- **The dev's sign-off is the completion criterion for art.** Passing unit tests is not
  "done" and is not permission to move to the next item. Do not say an art change is
  verified, improved, or fixed until the dev has looked at it and said so.
- Incident: 2026-09-28, health-bar end caps. The dev asked for the caps to stop looking
  blurry. Across three turns the agent replaced the approved cap (a four-point gold
  sparkle with a teal gem over a brown shadow star) with a generated wing ornament, then
  with a blocky arrowhead, then offered to delete the rejected files — without once
  inspecting the cap's actual pixels or comparing renders at draw size. The fix was
  eventually built from the dev's own art (exact 4× pixel duplication, 1px anti-alias,
  edge hardening) and only after dumping the source alpha map and comparing at 19px.

### Still open / not yet decided
- **Shared-file exceptions:** when a boss/feature needs a small opt-in hook
  in a shared/global file (e.g. a default-off `damages_boss_summons` flag on
  `EnemyProjectile`), is that an acceptable narrow exception, or should
  boss-specific behavior always live in boss-owned files even at the cost of
  duplication? Not yet decided — ask the dev on a case-by-case basis until
  a rule is agreed.
