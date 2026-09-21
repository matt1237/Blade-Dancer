# Grapple Yo-yo

## Yo-yo scope cut and cleanup handoff — 2026-09-15

Dynamic enemy/obstacle tetherball wrapping is active and tuned. The active Grapple system includes direct Chakram yo-yo control, static pivots, live boundary wrapping, committed coils, collision-validated unwind, and weight-based wrapped targeting.

Authority/lifecycle: hook flight -> attachment length from current distance + `initial_slack` -> Extending -> Orbiting -> Reeling. Controller owns rope length and hand/tension forces; Chakram owns velocity and its direct radial/tangential constraint. No live gameplay run was performed by Astra; the user owns playtesting.

Audit findings:
- The wrap switches are now enabled by default and are part of current gameplay acceptance.
- Static pivot and boundary wrapping consume the canonical Grapple tuner authority.
- Enemy coil contact coupling, boundary bookkeeping, unwind, and weight-based wrapped targeting are active gameplay paths.
- The direct yo-yo path still contains the recent slack take-up and state-transition changes. They are gameplay behavior, not confirmed dead baggage, so they were not guessed away in this cleanup.

Verification: focused helper tests remain available for the parked solver; no live gameplay run. This audit does not claim that the direct yo-yo feel is solved. User should judge catch tightness, tangential control, hang, and reel behavior before any further change.

Earlier sections below are historical and are superseded where they conflict with this handoff (especially permanent retention and automatic reel-unwind claims).

## Player fantasy

Sword, Chakram, and Grapple remain useful individual toys. Grappling a flying Chakram combines two verbs into a fourth toy: a physical yo-yo whose outward motion becomes orbit, whose rope preserves momentum under a direct tether, and whose eventual reel follows that motion rather than a canned trajectory.

## Active direct yo-yo foundation

1. A grapple attached to a flying Chakram adopts the measured live hand-to-Chakram path plus the visible `Initial Attachment Slack` setting. GP2 uses `0 px` for an immediate catch. `Initial Slack Recovery` closes only configured attachment slack; no full-range or hidden slack is granted.
2. The final approach to maximum extension progressively damps outward radial velocity.
3. When extension becomes orbit, `Yo-yo Catch Radial Retention` controls the one-time radial settle. GP2 uses `0×`, removing inward/outward drift while preserving the full tangent so the catch cannot manufacture a large loose loop.
4. At the limit, outward radial velocity is removed while tangential velocity is preserved.
5. `Yo-yo Orbit Slack Recovery` shortens only unused line while Orbiting and stops at the current live rope path. It cannot pull the Chakram inward, pay line outward, restart Hang Time, or trigger recall.
6. `Yo-yo Hang Time` blocks automatic recall. Afterward, `Yo-yo Reel Energy Threshold` recalls only an orbit whose tangential speed has fallen below the configured threshold; energetic player-controlled motion remains in orbit.
7. `Taut-Catch Hand Burst` changes velocity once at first tension and never changes rope length.
8. `Body Movement Transfer` controls how much ordinary player movement enters the shared hand signal used by the Chakram and dynamic targets. Relative hand motion remains fully expressive.
9. Obstacle pivots and boundary wrapping are active parts of the shared hand-to-Chakram rope path.
10. The rope renders from hand to Chakram, and Training Tools status identifies Extending, Orbiting, and Reeling states.
11. A grapple may target a grounded Chakram. On hook arrival the disc becomes airborne in place and continues through ordinary Chakram grapple attachment. It no longer auto-returns: the grapple hand can throw it into extension, orbit, wrapping, or recall.
12. Enemy wrap now separates player-authored entry from deterministic completion: rope intersection tracks real circle contacts until `Wrap Commit Point`, then the grappled dynamic object (Chakram or enemy) follows an exact, collision-validated target-relative inward spiral for `Automated Coil Revolutions` (default `1.5`) using independent `Tangential Coil Speed` and `Radial Cinch Speed` authorities while retaining swept collision checks.
13. A committed coil collision uses the real impact bounce, then `Obstruction Unwind Speed` reverses the authored path until free. A completed coil damages once, shows `Wrapped!`, stuns the enemy with its existing stunned visual for `Completed Coil Hold` (default `1.0 s`), and immediately starts retracing the spiral outward. During that window the wrapped enemy becomes a true second grapple endpoint: it reels with the exact same Light/Medium/Heavy force authority as a direct grapple while the original grappled Chakram/enemy keeps its own behavior. Light targets reel toward the player, Medium splits response, and Heavy pulls the player toward the wrapped target. `Tightening Speed Gain` accelerates tangential travel as the radius closes.

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
- Wrap topology uses live collision boundaries and clears safely when either wrap authority is intentionally disabled.

## Collision-shape contract and warning

- In-arena wrap candidates and physical targets use only `CircleShape2D` or `CapsuleShape2D`. Forest wall modules and generated arena obstructions were migrated from rectangles to capsules.
- Arena perimeter geometry may remain rectangular or polygonal because it is a world boundary, not a wrap target. This includes standard arena bounds, Chasm perimeter segments, boss borders, and Resonance Rush ground courses.
- Static terrain acquisition now raycasts collision layer 4 and uses the real Godot circle/capsule surface contact and normal. It never converts those colliders back into rectangular wrap geometry.
- **Warning:** full perimeter winding is currently implemented only for circular enemy bodies. Static capsules intentionally remain a stable one-contact pivot even when Full Boundary Wrap is enabled; author a true stadium-perimeter solver before expecting multi-turn winding around long capsule walls.

## Retained boundary-wrap experiment

The enemy/terrain boundary-wrap implementation is active behind the canonical `yoyo_boundary_wrap_enabled` authority. Static pivot mode is active through `yoyo_static_pivot_enabled`. The solver and its focused helper tests are part of current gameplay acceptance.

## Historical enemy-wrap prototype

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
