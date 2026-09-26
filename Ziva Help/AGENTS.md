# AGENTS.md — Blade Dancer Development Protocol

## Mission
Work on Blade Dancer efficiently, conservatively, and with minimal unnecessary repository scanning.
Prefer targeted inspection and small patches over broad rewrites.

## Golden Rules
1. Review this `AGENTS.md` before implementing changes or consulting project-specific working rules.
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

### 4. Never shell-patch engine files
Never use `sed`/`perl`/`awk`/raw bash text manipulation to edit `.gd`,
`.tscn`, or `.tres` files, even under time pressure or when the normal edit
tool is blocked. If an edit tool is blocked (e.g. a scene "changed on disk"
error), stop, re-sync by re-reading the file/scene tree, and either retry the
proper edit tool or ask the dev — do not reach for shell text-patching as a
workaround. This caused real damage once already: hand-tuned boss config
files got clobbered and had to be reconstructed from git history.

### Still open / not yet decided
- **Shared-file exceptions:** when a boss/feature needs a small opt-in hook
  in a shared/global file (e.g. a default-off `damages_boss_summons` flag on
  `EnemyProjectile`), is that an acceptable narrow exception, or should
  boss-specific behavior always live in boss-owned files even at the cost of
  duplication? Not yet decided — ask the dev on a case-by-case basis until
  a rule is agreed.
