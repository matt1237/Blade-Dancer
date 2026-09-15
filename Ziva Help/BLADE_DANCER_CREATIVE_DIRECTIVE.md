# Blade Dancer Creative and Technical Directive

**Status:** Active project authority  
**Owner:** Human + AI creative partnership  
**Purpose:** Keep Blade Dancer focused, distinctive, honest, and shippable.

## Core identity

Blade Dancer is not a game about pointing a sword at targets.

> **The player conducts a weapon through rhythm, timing, motion, contact, and consequence.**

The first-time experience must make that legible. If a player can play for several minutes while only pointing the metronome and never understanding that they are wielding a physical, rhythmic sword, the game has failed to communicate its core idea.

The game should demonstrate—not merely describe—that:

- sword motion is authored by the player through timing and movement;
- rhythm changes contact quality and consequence;
- parries, slides, clashes, and redirections are physical events;
- Grapple and Chakram deepen the same language of momentum and control.

## Development priorities

1. **Player comprehension and feel** — teach the sword rhythm and make it immediately satisfying.
2. **A reliable playable vertical slice** — prefer a small, coherent experience over broad unstable systems.
3. **Steam awareness** — within roughly one month, produce footage and a page that communicate the human-readable game fantasy without sounding like generic AI copy.
4. **Experimental depth** — pursue advanced physics only when it survives clear acceptance tests and improves the player-facing game.
5. **World building and tutorial presentation** — begin as soon as an experimental mechanic reaches its decision gate.

## Current decision: Chakram tetherball

Track B (tetherball wrap) is the current focused experiment. Player movement transfer is a separate known issue and is parked while Track B is isolated.

Track B must be tested with a stationary player and controlled targets first. It must use one shared wrap lifecycle and live collision geometry for every supported tether object—not an enemy-only special case.

Required lifecycle:

```text
FREE -> WRAP_ACQUIRED -> WRAPPED/PIVOTING -> RETURNING/UNWINDING -> FREE
```

Required acceptance behavior:

```text
acquire -> persist -> tangential motion -> reel -> unwind -> direct return
```

Test enemies, rocks, trees, and walls using their actual active collision shapes. A frozen world-space hinge, visual footprint, arbitrary radius, or scripted orbit is not an acceptable substitute for collision-boundary topology.

### Decision gate

Give this one bounded architecture pass. If the effect remains intermittent, chatters, hinges in empty space, or fails to return reliably across the supported object types, remove it from the player-facing combat loop and parking-lot it. Do not keep layering patches, thresholds, fallback forces, or duplicate wrap systems onto a failed foundation.

## Player movement transfer

This is a separate issue, not part of the tetherball proof.

The intended distinction is:

```text
player body movement -> legitimate rope tension / movement transfer
hand movement relative to the body -> deliberate hand steering
```

Do not globally remove movement-driven pull if it contributes to the established Grapple feel. Do not allow walking to masquerade as unlimited hand intent. Test and tune this only after the tetherball decision gate.

## Engineering conduct

The AI is authorized and expected to push back.

Do not agree with a proposal merely because it sounds plausible. For every significant change:

- distinguish observed facts from assumptions and guesses;
- inspect the current implementation before proposing a fix;
- identify hidden authorities, duplicate systems, and scope risks;
- prefer one authority per behavior;
- use small reversible changes;
- define acceptance criteria before implementation;
- verify in the running game or with targeted tests;
- report failures plainly;
- stop and recommend shelving a system when repeated patches do not improve it.

No physics behavior should be faked as physics merely to produce a favorable screenshot. Rendering and gameplay must consume the same physical geometry.

## Scope discipline

Do not expand an unstable system while its core acceptance test is failing. Do not spend the project’s time or usage budget on broad scans and speculative rewrites when a focused diagnostic will answer the question.

When an experimental feature is consuming disproportionate effort, make an explicit keep / simplify / shelve decision and move toward the player-facing slice.

## Communication standard

Be direct, calm, and specific. Avoid empty praise. The human partner supplies vision, taste, player-feel observations, and creative direction. The AI supplies implementation analysis, architecture, verification, and pushback. Neither side should pretend uncertainty is confidence.

At the start of a substantial work session, read this directive together with the collaboration protocol, current continuity record, and the relevant feature parking-lot document.
