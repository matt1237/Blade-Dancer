# Grapple Yo-yo

## Player fantasy

Sword, Chakram, and Grapple remain useful individual toys. Grappling a flying Chakram combines two verbs into a fourth toy: a physical yo-yo whose outward motion becomes orbit, whose rope can redirect around geometry, and whose eventual reel follows that geometry rather than a canned trajectory.

## Implemented foundation

1. **Correction:** A grapple attached to a flying Chakram must initialize and shorten the rope through the same live Grapple tuners as every other target. It must not grant `max_tether_length * mastery_range_multiplier` as a hidden one-time override. The previous full-line behavior was an implementation mistake and is explicitly retired.
2. The final approach to maximum extension progressively damps outward radial velocity.
3. At the limit, outward radial velocity is removed while tangential velocity is preserved.
4. Full-extension tangential energy burns down gradually, creating an orbit/hang before the existing `reel_speed` and `chakram_tether_strength` take over.
5. One static obstruction or wall corner can become a local pivot. Rope length is measured as `hand -> wrap -> Chakram`, and a continuously clear direct path unwraps it with hysteresis.
6. The rope renders through the active pivot and the live Training Tools status identifies Extending, Orbiting, Wrapped, and Reeling states.

## Implementation authority contract

- `GrappleController` tuner values are the only authority for rope initialization, slack removal, shortening, tension, and Chakram redirection.
- Yo-yo state may select *which existing tuned path is active* (extending, orbiting, reeling), but may not silently replace a tuned value with a hardcoded or derived one-shot value.
- Every player-facing tuner must have a live consumer, a visible status/tooltip when relevant, and a persistence key. If a tuner has no measurable runtime effect, mark it as dead and remove or repair it before further feel tuning.
- Before implementation, record initial conditions, state transitions, tuners consumed, and invariants in this guide. After implementation, verify each listed authority against code and a focused test.

## Safety invariants

- Existing committed tuning remains unchanged: `reel_speed = 145`, `enemy_pull_strength = 1150`, `chakram_tether_strength = 800`.
- Chakram velocity remains capped by `Player.max_chakram_bat_speed` (700 in the current player tuning).
- The constraint is unilateral: inward velocity is never blocked.
- Tangential motion is not converted into a canned path.
- Wrap topology remains attached while RMB is held; only explicit body invalidation or release may remove an anchor in the current prototype.

## Implemented enemy-wrap prototype

- One living enemy can become the active dynamic wrap owner when the hand-to-Chakram segment crosses its collision circle.
- Enemy wrapping uses two live tangent contacts plus the directed collision-boundary arc between them. The rendered rope and rope-length constraint consume this same path every physics frame.
- Boundary arc length is `radius × accumulated signed angle`. Complete turns persist beyond `TAU`; forward tangential travel consumes rope and reverse travel unwinds it without commanding a canned orbit.
- The overall tether retains its 42 px safety minimum, but the final wrapped-body segment may contract to collision range so ordinary Chakram contact—not an invisible rope floor—causes reversal.
- `Enemy.GrappleWeight` scales the wrapped body's response to opposing rope pulls; no new damage or collision rule is introduced.
- A live wrap is not released by a timer or a clear direct path; it remains part of the tether topology until RMB release or explicit body invalidation.
- Enemy wrap uses the same single-owner rule as static wrapping. Single-enemy winding now unwinds to zero and releases only that wrap anchor; the Chakram tether remains active. Multiple enemy knots remain future work.

## Parked follow-ups

### Dynamic enemy wrap

- Begin with one active enemy wrap owner, never an arbitrary knot of several enemies.
- Use `Enemy.GrappleWeight` rather than enemy identity:
  - Light targets receive substantial tension displacement.
  - Medium targets partially move under tension.
  - Heavy/boss targets approximate static pivots with boss-specific resistance where needed.
- Wrapping must require real rope crossing/winding geometry and use hysteresis for unwrapping.

### Tetherball tightening

Track signed winding angle around an enemy. Consumed rope should emerge from target radius times accumulated winding angle, naturally reducing the Chakram's local orbit radius. Do not create a named shredder attack or automatic repeated damage.

### Contact rule

The Chakram continues using its ordinary swept hit and per-flight target suppression. A wrapped path may produce one spectacular ordinary hit; rope intersection alone grants no damage, multiplier, counter, or invulnerability.

### Later experiments

- Multiple static anchors as a small ordered stack, newest anchor controlling local motion.
- Reverse-order unwrapping during recall.
- Hand flicks that add or redirect tangential energy during the orbit hang.
- Light-target coupled motion approximated with weight-scaled impulses before attempting a true shared-center-of-mass solver.
