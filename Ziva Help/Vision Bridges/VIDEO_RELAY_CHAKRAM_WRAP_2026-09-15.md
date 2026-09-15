# VIDEO RELAY — Chakram Enemy Wrap / Tetherball Failure
Date: 2026-09-15
Source clip: `1000012255.mp4`
Clip duration: ~23.0 seconds
Purpose: visual relay for an AI coding agent that cannot directly inspect the video.

---

## 1. Player Intent

The chakram is tethered to the player by the grapple.

When the tether path catches/wraps around an enemy, the enemy should temporarily behave like a tetherball pole / rope pivot.

Desired feel:

1. Chakram travels outward.
2. Tether catches the enemy.
3. Enemy becomes a persistent temporary pivot.
4. Chakram can coil / sweep / orbit around that enemy while tangential motion is preserved.
5. Once the outward motion/tension is spent and reel-back begins, the chakram should return decisively toward the player while unwinding the rope path.
6. The return should feel like stored wrap/tension being ripped back — not like the wrap randomly disappears.

This is intentionally game-physics, not a requirement for perfect real-world rope simulation.

---

## 2. What the Video Clearly Shows

### Working behavior
There are multiple moments where the concept visibly works:

- The purple tether path changes shape around/through the enemy instead of remaining a simple player-to-chakram line.
- The chakram temporarily moves with the enemy acting as an intermediate pivot.
- During successful moments, the motion has the desired tetherball / yo-yo character.
- The concept is visually understandable when the wrap remains stable.

### Failing behavior
The failure is intermittent rather than total:

- A wrap can appear to establish correctly and then disappear or change abruptly.
- The tether sometimes returns to a simpler direct path when the visual motion suggests the enemy should still be acting as the pivot.
- The wrap state appears capable of being reacquired after being lost.
- This produces snapping/chattering/inconsistent path behavior rather than one clean wrap -> orbit -> unwind sequence.

The important conclusion from the clip:

**The core mechanic is viable. The unreliable part is wrap-state persistence / transition handling.**

---

## 3. Temporal Observations

Approximate timing only; use as visual context, not code truth.

### ~2.0–7.0 s
- Chakram and tether interact around the upper enemy.
- Several frames visibly show the tether using the enemy as an intermediate relationship/pivot.
- The rope/path then changes abruptly rather than maintaining one obviously persistent wrap state.

### ~15.0–18.5 s
- Another useful wrap attempt occurs.
- The tether geometry again shows the desired concept intermittently.
- The path subsequently simplifies / shifts while the chakram is still moving around the enemy.

### ~19.0–22.5 s
- The same pattern repeats:
  - promising tetherball-like relationship
  - unstable persistence
  - abrupt transition back toward direct tether behavior

---

## 4. What MUST Be Preserved

Do not remove or simplify away these existing qualities:

- player-controlled chakram
- existing radial/tangential grapple manipulation
- existing reel behavior unless directly required for the fix
- ability for a chakram to use an enemy as a temporary wrap/pivot
- momentum-based movement
- tangential motion around the pivot
- the physical/kinetic feel of the current system

The successful wrap moments in the clip are the target feel.

---

## 5. What Needs to Change

Primary requirement:

**Once a valid enemy wrap is established, that wrap must become a persistent state and remain active until a deliberate unwrap condition is satisfied.**

Do not decide from scratch every physics frame whether the enemy is wrapped.

A transient frame where a ray/segment no longer intersects the enemy must not automatically destroy a valid wrap.

The system should have a clear lifecycle such as:

`FREE -> WRAP_ACQUIRED -> WRAPPED/PIVOTING -> UNWRAP_VALIDATED -> FREE`

and eventually:

`WRAPPED/PIVOTING -> RETURNING/UNWINDING -> FREE`

Exact existing architecture may differ; inspect before changing it.

---

## 6. Recommended Physical Model

This is a suggested model, not proof of current implementation.

### While wrapped
Treat the wrapped enemy as an active local pivot.

For chakram velocity relative to the active pivot:

`velocity = radial_component + tangential_component`

When the available tether length is taut:

- prevent/damp **outward radial** motion beyond allowed rope length
- preserve **tangential** motion so the chakram can sweep/orbit around the enemy

Do not kill tangential velocity merely because maximum tether length is reached.

### Wrap persistence
When a wrap is acquired, store enough state to know what happened, for example:

- wrapped target ID/reference
- wrap/pivot position
- winding direction (clockwise/counter-clockwise), if useful
- entry direction/angle, if useful
- time/frame of acquisition

Do not require the original collision condition to remain true on every frame.

### Unwrap
Use a deliberate unwrap condition with hysteresis/tolerance.

Examples of acceptable logic:
- chakram genuinely crosses back past the entry side
- line-of-sight clears in the correct geometric direction for more than a tiny tolerance
- angular clearance exceeds a threshold
- unwrap condition remains valid for more than one physics tick

Avoid:
- `no current intersection -> immediately unwrap`

That can create wrap/un-wrap chatter.

---

## 7. Return / Reel-Back Intent

When return begins, the desired feel is decisive:

**coil/wrap -> tension spent -> WHAMO -> reel back toward player**

A useful game-physics approach is to treat existing wrap points as a temporary path/stack.

Example:

`Player -> Wrap A -> Enemy/Pivot -> Chakram`

On return, collapse/unwind in reverse:

`Chakram -> Enemy/Pivot -> Wrap A -> Player`

The exact implementation does not need to be a perfect rope simulation.

The goal is:
- predictable return
- visually coherent unwinding
- no random loss of the active pivot
- preserved kinetic feel

---

## 8. Strong Simplification If Needed

If collider-surface wrapping is causing instability:

**Use one stable `RopePivot` point attached to the enemy for the gameplay constraint.**

The rendered rope can later be visually offset to appear as though it contacts the body surface.

Gameplay stability is more important than perfect circumference/surface simulation.

---

## 9. IMPORTANT ANTI-TECH-DEBT RULES

For this fix:

1. DO NOT add a parallel wrap system.
2. DO NOT add duplicate tuning variables for concepts that already have settings.
3. Before adding any exposed setting, search for semantic overlap.
4. Maintain one authoritative parameter per tunable behavior.
5. DO NOT create enemy-specific duplicate wrap logic unless genuinely required.
6. DO NOT rewrite unrelated grapple/chakram systems.
7. Prefer fixing the failing state transition over adding fallback forces/workarounds.
8. If an old variable/system is replaced, remove or explicitly deprecate it.
9. Do not add more than the minimum new tuning controls needed to validate the fix.

---

## 10. Diagnostic Request Before Editing

Before changing code, report:

1. Where wrap acquisition currently occurs.
2. Where wrap persistence is stored.
3. What exact condition currently removes/unwinds a wrap.
4. Whether wrap existence is recomputed every physics frame.
5. Whether the active pivot is stable or recalculated.
6. Whether multiple overlapping wrap implementations/settings exist.

Then make the smallest correction that produces a stable state transition.

---

## 11. Acceptance Test

Use a simple test enemy / stationary target first.

A pass requires:

1. Throw chakram past target.
2. Tether establishes target as wrap/pivot.
3. Pivot remains stable through minor frame-to-frame geometry changes.
4. Chakram can travel tangentially around target without losing the wrap.
5. Taut tether prevents additional outward radial extension.
6. No rapid `wrapped/free/wrapped/free` chatter.
7. Return begins cleanly after outward motion/tension is spent.
8. Chakram unwinds/reels back toward player coherently.
9. Repeat from both clockwise and counter-clockwise approaches.
10. Repeat at several approach angles.

Only after this passes should moving/light enemies be tested.

---

## 12. Visual Confidence

HIGH confidence:
- successful wrap moments exist
- failure is intermittent
- tether path sometimes loses/changes the apparent enemy pivot unexpectedly
- current output is not yet stable enough

MEDIUM confidence:
- the specific failure is wrap/un-wrap chatter or pivot reacquisition
- current implementation may be recomputing geometry too aggressively

UNKNOWN until code inspection:
- exact state machine
- exact raycast/collision logic
- whether duplicated settings or duplicate wrap code are contributing
