# VIDEO RELAY — Chakram Tether Wrap / Final Stabilization Pass
Date: 2026-09-15
Source: `2026-09-15 00-13-58.mp4`
Duration: ~23 seconds

## Goal

This is the final stabilization pass for the current chakram/grapple physics before moving development focus to onboarding, menus, crafting, art cohesion, and progression.

The desired behavior is intentionally game-physical rather than a perfect rope simulation:

1. Chakram travels outward under its existing motion.
2. If the tether catches an enemy, that enemy becomes a temporary rope pivot / wrap pole.
3. The tether can coil around that enemy while the chakram preserves useful tangential motion.
4. When outward radial motion is exhausted / return begins, the chakram should unwind cleanly and reel back toward the player.
5. The result should feel like a tetherball / yo-yo / ripcord interaction: outward motion, wrap, tension, then a decisive return.

Do not expand scope beyond making this behavior reliable.

---

## What the video visibly proves

The concept already works intermittently.

### Successful behavior
- The purple tether visibly changes from a simple direct player-to-chakram line into a routed path involving the enemy.
- Around the middle of the clip, the line visibly forms multi-segment / wrapped geometry around the enemy.
- The chakram can occupy a position that reads as orbiting/sweeping relative to the enemy rather than merely flying directly back to the player.
- The mechanic is visually legible when the wrap state remains stable.

### Unstable behavior
- The wrap does not remain equally stable across attempts.
- The tether path can abruptly simplify or change while the enemy still appears to be the intended active pivot.
- The active relationship sometimes appears to be reacquired after being lost.
- The resulting motion can look like snapping/chattering between valid wrap geometry and a direct tether.

The primary problem is therefore not “invent the mechanic.”
It is “make the acquired wrap/pivot state deterministic and persistent enough to be trustworthy.”

---

## Approximate visual sequence

These are observational markers, not implementation facts.

### ~6 s
The tether is taut across the enemy while the chakram is displaced to the opposite side. This establishes the basic player -> enemy -> chakram relationship visually.

### ~10 s
The tether clearly forms routed/multi-segment geometry around the enemy. This is close to the intended wrap behavior.

### ~14 s
The wrap/coiling relationship is still visible and reads like the enemy is acting as a temporary pole/pivot.

### ~18 s
The tether relationship has changed again and begins simplifying/unwinding.

### ~22 s
The system is close to a direct player/chakram relationship again.

The problem is that transitions between these states are not consistently smooth or persistent.

---

## Desired state model

Do not necessarily rename existing states. This describes intended behavior.

`FREE`
-> valid enemy wrap detected
`WRAPPED`
-> chakram travels tangentially / around pivot
`WRAPPED_TAUT`
-> outward radial extension constrained
`RETURNING_UNWIND`
-> reverse/collapse stored wrap path
`FREE`

A valid wrap should be a stored state, not something that must be rediscovered from scratch every physics frame.

---

## Critical physics rule

Relative to the active pivot:

`velocity = radial_component + tangential_component`

When the tether is taut:

- block or damp only **outward radial** motion that would exceed available rope length
- preserve useful **tangential** velocity
- do not artificially kill orbital/sweeping motion

When return begins:

- allow the existing reel system to pull inward
- unwind stored wrap points in a stable, ordered way
- do not randomly discard the current pivot/path

---

## Wrap persistence

Once an enemy is accepted as a wrap/pivot, store that fact.

Potential stored information:
- wrapped enemy reference/ID
- pivot point
- winding direction if required
- entry direction/angle if required
- wrap acquisition frame/time
- current wrap stack/path

Do not use:
`ray/segment does not intersect this exact frame -> instantly remove wrap`

Use deliberate unwrap criteria with hysteresis/tolerance so adjacent physics frames cannot rapidly toggle the state.

---

## Return behavior

The return is allowed to be more authored than the outbound physics.

Desired feel:
`throw -> wrap -> sweep/coil -> tension spent -> WHAMO -> unwind/reel home`

If wrap points exist, treat them as a temporary ordered path.

Example outbound:
`Player -> Wrap A -> Enemy Pivot -> Chakram`

Return/unwind:
`Chakram -> Enemy Pivot -> Wrap A -> Player`

Consume/remove wrap points only when the chakram/rope has genuinely cleared them.

The goal is a clean visual ripcord effect, not a perfect rope simulation.

---

## Simplification allowed

If continuously sliding a rope contact point around the enemy collider is unstable, use a stable gameplay `RopePivot` point attached to the enemy.

The visible line may later be offset to appear to touch the body surface.

Stable gameplay is more important than exact circumference simulation.

---

## Preserve

Do not damage these working systems:
- sword combat
- existing grapple radial/tangential hand manipulation
- existing chakram throw
- existing normal reel
- current player movement
- momentum feel
- ability to use enemy as a wrap/pivot
- existing successful tetherball-like moments

---

## Anti-tech-debt constraints

1. Do not create a second parallel enemy-wrap system.
2. Do not add duplicate exposed variables.
3. Before adding a setting, search for semantic overlap.
4. One authoritative parameter per gameplay concept.
5. Do not create Form/Test-specific duplicated settings.
6. Do not rewrite unrelated grapple/chakram behavior.
7. Fix state ownership/transitions before adding compensating forces.
8. Remove/deprecate replaced logic instead of leaving both implementations active.
9. Keep this final pass narrow.

---

## Diagnostic-first request

Before editing, identify and report:

1. Where enemy wrap is acquired.
2. What data/state records the active wrap.
3. What condition removes the wrap.
4. Whether wrap is recomputed every physics frame.
5. How the active pivot is chosen and whether it can change unexpectedly.
6. How total/remaining rope length is calculated while wrapped.
7. How return/reel interacts with wrap points.
8. Whether multiple overlapping implementations/settings are influencing the same behavior.

Then make the smallest coherent fix.

---

## Acceptance test

Use one stationary enemy first.

Pass only if:

1. Chakram can be thrown past enemy.
2. Tether acquires enemy as a pivot reliably.
3. Wrap remains stable through small geometry fluctuations.
4. Chakram can sweep at least roughly around enemy while tangential velocity is preserved.
5. Maximum rope length stops additional outward radial extension.
6. No visible wrap/free chatter.
7. Return begins predictably.
8. Stored wrap path unwinds coherently.
9. Chakram reaches player without an obvious snap/teleport.
10. Works clockwise and counter-clockwise.
11. Repeated attempts produce substantially the same rules.

If this works, stop. Do not broaden the feature.

---

## Confidence

HIGH:
- wrap/tetherball behavior visibly exists
- it is intermittent
- routed/multi-segment tether geometry is visible
- transition/persistence reliability is the remaining user-facing problem

MEDIUM:
- state chatter / unstable pivot ownership is the primary cause

UNKNOWN UNTIL CODE INSPECTION:
- exact state architecture
- exact collision/raycast implementation
- exact source of duplicate/overlapping logic
