# Blade Dancer — Idea & Resonance Pipeline

> We are not collecting disconnected features. We are building playable verbs that resonate with one another in octaves.

This document preserves both **what we are making** and **why it felt exciting in the first place**. A feature is not complete merely because its checklist passes: its original physical or emotional fantasy must remain recognizable in play.

## North Star

Blade Dancer should feel like a box of individually satisfying physical toys whose verbs combine naturally:

- **Sword** is a toy.
- **Chakram** is a toy.
- **Grapple** is a toy.
- **Dash** is a toy and an amplifier.
- Combining toys should create new play without requiring a canned named move.

The player should regularly discover: **“Wait—I can do that?”**

Our collaboration should leave a recognizable hallmark: ambitious human sparks translated into coherent, testable systems without sanding away their personality.

## Working Rhythm

- Default to **low or medium reasoning** so iteration remains affordable and frequent.
- Escalate only when a problem genuinely needs deeper architecture, physics analysis, or repeated debugging.
- Prototype the smallest playable expression of an idea first.
- Prefer geometry, velocity, pressure, timing, leverage, and collision history over gesture recognition or scripted outcomes.
- Tune one experiment at a time and preserve a trusted comparison profile.
- Record what changed, what was learned, and what still feels uncertain.
- A technically passing feature remains **Awaiting Resonance** until it survives a player feel test.

## Status Language

- **Spark** — exciting idea; fantasy is clearer than implementation.
- **Shaped** — rules and safety rails are understood.
- **Prototype** — playable foundation exists, but feel is unproven.
- **Mechanically Working** — intended rules function and have focused regression coverage.
- **Awaiting Resonance** — needs hands-on play to confirm the original fantasy survived.
- **Tuning** — core interaction works; values/presentation are being refined.
- **Shippable** — mechanics, presentation, persistence, and player feel are accepted.
- **Parked** — intentionally deferred without losing the idea.

---

# Active Pipeline

## 1. Bind Form — Geometric Sword Contact

**Status:** Mechanically Working → Consolidated Feel / Polish  
**Current workflow:** One visible Bind Form, one shared Slide profile, and one shared Bind profile for every weapon. Retired Bind A remains only as a save-safe ID alias. Global Preset 3 is the saved launch profile.

### Resonance Key

Two weapons become opposing doors on hinges. Their meeting is not merely a hit notification: it becomes a short physical conversation made of pressure, sliding contact, leverage, and release.

### Player Discovery

> “I did not press a bind button. Our blades met correctly, I held the line, and now I can work the contact.”

### Implemented

- [x] Former Bind A/B experiments are consolidated into one visible, shared Bind Form while persisted IDs remain load-safe.
- [x] A candidate begins only from a validated parallel blade slide.
- [x] Sustained geometry and pressure earn a stable bind.
- [x] Candidate retention helps the initial contact settle.
- [x] One opponent owns the bind, preventing multi-sword pinning.
- [x] The blade-plane hinge resists pushing through the opposing weapon.
- [x] Opening away remains controllable and cannot magnetically reacquire contact.
- [x] Stable focus, contact framing, scrape pulses, diagnostics, guard-wrap disengagement, rollover communication, collision-gated re-entry, weapon beats, and rejected-beat recoil exist.
- [x] Slide, Bind, Clash, and Parry controls have explicit left/right feel guidance.
- [x] Training Tools exposes one **Slide & Bind Feel** section; shared Slide settings and canonical Bind settings apply to both Longsword and Curved Sword.
- [x] Duplicate form-local slide overrides, Reset-B, and Clone-A→B controls are retired.
- [x] A minimizable in-game Combat Tracker records slides, candidates, stable binds, winds, beats/rejections, disengagements, re-entries, and release reasons while exposing live pressure, authored pressure, spikes, travel, leverage, and contact position for Vision Bridge tuning.

### Non-Negotiable Feeling

- Defense and offense remain separate achievements.
- Contact never grants a free counter, damage, or invulnerability.
- Normal clashes remain fast; focus follows only a stable bind.
- Techniques emerge from physical history rather than canned gestures.
- The player can understand success or failure from motion and contact—not only debug text.

### Next Playable Milestone

Preserve the consolidated GP2 feel, then test the one Bind Form against a single opponent: slide acquisition, controllable hinge resistance, travel toward the hilt, and deliberate release should read without consulting debug text.

### Questions for the Next Feel Test

- How many plausible parallel contacts out of ten become stable binds?
- Is contact too slippery, too magnetic, or too static?
- Can the player intentionally travel toward an enemy blade endpoint?
- Does pulling away release quickly enough?
- Does the constrained metronome feel loaded and deliberate, or disconnected from rhythm?
- Are successful and rejected weapon beats physically legible?

### Safety Rails

- Never allow several enemies to own one bind.
- Never make every weapon contact globally solid.
- Never solve difficulty by granting unconditional offense.
- Do not overwrite Forms I–II or the Global Preset 2 baseline.

---

## 2. Grapple Yo-yo — Chakram + Grapple

**Status:** Prototype → Awaiting Resonance  
**Detailed design and parking lot:** `res://Ziva Help/GRAPPLE_YOYO_PARKING_LOT.md`

### Resonance Key

A flying Chakram attached to the Grapple stops being “a projectile receiving pull force” and becomes a yo-yo. Outward flight turns into tension, tension turns into orbit, geometry becomes a pivot, and eventual recall follows the tether’s physical path.

### Verb Combination

`Chakram + Grapple = Yo-yo`

### Player Discovery

> “The line went taut, but the Chakram did not simply reverse—it swung. I can steer that swing.”

### Implemented Foundation

- [x] A grappled flying Chakram initializes and shortens through the canonical `initial_slack`, `slack_take_up_speed`, and `reel_speed` authorities; the retired hidden full-line override must not return.
- [x] Outward radial speed progressively burns off near maximum extension.
- [x] Full extension blocks additional outward radial motion while preserving tangential motion.
- [x] Tangential energy creates an orbit/hang before handing off to the original reel system.
- [x] A stalled or already-returning Chakram safely skips impossible extension and enters recall.
- [x] One static wall/tree/obstruction corner can become the local pivot.
- [x] Rope path length accounts for `hand → wrap → Chakram`.
- [x] Static wrapping currently uses one corner pivot. Enemy wrapping now begins with live circle tangencies and a rendered/physical boundary arc; multi-body topology remains unproven.
- [x] Rope rendering and Training Tools status communicate Extending, Orbiting, Wrapped, and Reeling.
- [x] Dedicated Grapple Yo-yo tuning controls exist.
- [x] Existing committed reel strengths and the 700 px/s Chakram ceiling remain preserved.

### Non-Negotiable Feeling

- Maximum range should create possibility, not merely stop motion.
- Tangential motion survives the catch.
- The orbit should not feel like a rubber-band bounce or scripted animation.
- Hand movement should eventually support expressive flicks and redirects.
- Recall should follow actual tether geometry.

### Next Playable Milestone

Tune extension damping, orbit energy burn, hang time, and recall threshold until the sequence reads clearly as:

`launch → extension → soft catch → orbit/hang → reel`

### Questions for the Next Feel Test

- Is it practical to grapple the flying Chakram?
- Does full extension visibly become an orbit?
- Is the catch too abrupt or too mushy?
- Does orbit last long enough for an intentional hand redirect?
- Does automatic reel begin too early or too late?
- Are static wraps stable and understandable, or do they pop unexpectedly?

### Safety Rails

- Preserve `reel_speed = 145`, `enemy_pull_strength = 1150`, and `chakram_tether_strength = 800`.
- Never exceed `Player.max_chakram_bat_speed` (currently 700).
- Inward velocity must remain free.
- Do not add canned yo-yo trajectories or a special attack button.
- Keep one static wrap anchor until its behavior is proven.

---

# Next / Parked Pipelines

## 3. Dynamic Enemy Wrap — Tetherball

**Status:** Shaped / Parked behind static-wrap validation

### Resonance Key

The rope does not treat an enemy as a target icon. It physically passes around their body, making them a temporary, weight-dependent tetherball pole. Continued winding draws the Chakram inward; unwinding can carry one spectacular ordinary Chakram hit back through the geometry.

### Player Discovery

> “I threw past that enemy, crossed the rope around them, and turned them into the pivot.”

### Intended Rules

- [ ] One dynamic enemy wrap owner initially; never an arbitrary multi-enemy knot.
- [ ] Wrapping requires real rope crossing and accumulated winding geometry.
- [ ] `Enemy.GrappleWeight` controls response:
  - Light: substantially displaced and potentially dragged into coupled motion.
  - Medium: partially displaced under tension.
  - Heavy/boss: approximates a stable pole with explicit resistance.
- [ ] Signed winding angle and target radius consume available rope naturally.
- [ ] Reverse winding or clear geometry unwraps with hysteresis.
- [ ] Ordinary swept Chakram contact and existing per-flight suppression remain authoritative.

### Safety Rails

- Rope intersection alone grants no damage.
- No automatic repeated “shredder” pulses, multiplier, counter, or invulnerability.
- Damage remains one ordinary valid Chakram hit per target per flight unless an existing system explicitly resets that rule.
- Begin with weight-scaled impulses before attempting a true shared-center-of-mass solver.

---

## 4. Toy-Combination Combat Grammar

**Status:** Spark / Ongoing North-Star Work

### Resonance Key

Depth should come from combining a small number of understandable verbs, not from accumulating isolated ability buttons.

### Current Combination Toy Matrix

- [x] **Sword + Chakram:** Pong/pinball relationship—batting and redirecting a live projectile.
- [x] **Chakram + Grapple:** Yo-yo relationship—extension, orbit, wrapping, and recall.
- [x] **Sword + Grapple:** Grapple motion can launch or exaggerate authored sword arcs.
- [x] **Dash + Grapple:** Momentum and traction modify tethered movement.
- [ ] **Dash + Sword:** Continue refining dash as an arc/velocity amplifier rather than a separate canned attack.
- [ ] **Dash + Chakram:** Explore whether body relocation and hand velocity can naturally redirect the projectile without an explicit combo rule.
- [ ] **Environment + tethered toys:** Let trustworthy geometry become temporary pivots, rails, or leverage without making every prop interactive noise.

### Safety Rails

- Every component remains useful alone.
- Combined behavior should emerge from shared physics.
- Avoid bespoke combo prompts where collision and motion can communicate the possibility.
- Dash accentuates other verbs; it should not replace them.

---

## 5. Combat Economy and First-Time Combat Teaching

**Status:** Spark / Needs Playable Prototype

### Resonance Key

The player should learn that Blade Dancer is not about pointing a sword at targets. The metronome establishes a natural rhythm, but player-authored swing, pullback, timing, and tool combinations create the meaningful consequence. Grapple and Chakram should feel like valuable extensions of the same physical language, not optional buttons that can be ignored.

### Player Discovery

> “The sword will move on its own, but I conduct it. When I add the other toys, the whole fight opens up.”

### Intended Combat Economy

- [ ] Reduce the damage of passive metronome contact so aiming alone is safe but slow and strategically weak.
- [ ] Preserve the current damage range for genuinely authored sword swing/movement, accounting for the base metronome contribution rather than accidentally double-counting it.
- [ ] Award Flow and round score for active sword movement, meaningful Chakram and Grapple use, varied valid contacts, and forward pressure.
- [ ] Add style bonuses for useful tool chains such as sword → Chakram → Grapple, without requiring a canned combo prompt.
- [ ] Give Flow a meaningful gain/loss model: active, varied play builds it; passive waiting and missed opportunities drain it.
- [ ] Ensure score rewards interaction and control rather than merely farming damage or repeatedly pressing one tool.

### Tutorial Path

Build an actual playable introduction using the existing chat boxes and in-game font. Each lesson should advance through a small observable checkpoint rather than presenting a large text explanation.

1. Establish the goal and show the player the sword's natural metronome rhythm.
2. Let a fitting test dummy demonstrate that passive metronome strikes deal low damage.
3. Ask the player to move/swing the sword with the mouse and demonstrate the higher authored-swing damage.
4. Teach throwing the Chakram at the dummy.
5. Teach grappling the flying Chakram and feeling the direct yo-yo relationship.
6. Introduce turkeys as forgiving live targets.
7. Teach cutting herbs for cooking ingredients and destroying terrain for materials.
8. Demonstrate Grapple on a wall, then on a turkey, then on the Chakram itself.
9. Return home, start turkey stew with Grandma, and send the player on the first forest adventure.

### Non-Negotiable Feeling

- Passive aiming must not be the dominant complete strategy.
- The tutorial must demonstrate the difference between passive rhythm and authored motion, not merely describe it.
- Grapple and Chakram use should create score, Flow, opportunity, or utility that players can feel and understand.
- Checkpoint tests should teach through consequence while preserving player agency.

### Safety Rails

- Do not make passive sword damage zero; the metronome should remain a readable baseline and a useful fallback.
- Do not add duplicate scoring or Flow authorities; extend the existing run/score/bonus flow in `main.gd`.
- Do not turn tutorial lessons into locked ability gates unless progression explicitly requires it.
- Keep tool rewards tied to meaningful contact, control, utility, or setup—not button frequency.

---

## 6. Assisted Physical Wrap and Leverage

**Status:** Spark / Parked behind direct Yo-yo and static-wrap validation

### Resonance Key

When a rope has genuinely earned a wrap, the game may help the motion settle into a believable playable state. The assistance protects the fantasy without pretending that impossible geometry is real.

### Intended Rules

- [ ] At roughly 80–100% wrap completion, transition into a temporary secured grapple/tether state.
- [ ] Hand-position and yank behavior should reuse the existing Grapple authorities and code rather than creating a parallel ability.
- [ ] A yank transfers force through the tether; it does not teleport the target or player.
- [ ] Light enemies can be redirected or knocked into one another, allowing emergent enemy-to-enemy “bonk” collisions.
- [ ] Mass, angle, tension, and contact determine the result; heavier targets resist or break the interaction.
- [ ] During any assisted settling phase, sweep the active Chakram/rope path against walls, enemies, and other bodies.
- [ ] If the guided path encounters blocking geometry or an unexpected physical body, cancel or redirect the assistance and return to normal Chakram simulation using the current position and velocity.

### Non-Negotiable Feeling

- Physics creates the opportunity; bounded assistance makes the earned opportunity legible and fun.
- The Chakram and rope must never visibly pass through walls or bodies that the gameplay collision does not ignore.
- Rendering and gameplay consume the same live collision geometry.
- A completed wrap creates leverage, not a canned attack animation.

### Safety Rails

- Do not command a desired orbit, snap, trajectory, or enemy position.
- Do not add automatic repeated damage, shredder pulses, or unconditional score multipliers for rope intersection.
- Keep this behind the current Yo-yo/static-wrap decision gates until the direct toy feels trustworthy.
- Use one wrap lifecycle and one authoritative Grapple/Yank path.

---

## 7. Scarf — Movement Made Visible

**Status:** Spark / Needs Resonance Clarification

### Provisional Resonance Key

The scarf should make velocity, turning, recoil, wind, and stillness visible on the character silhouette. It is not decoration pasted onto the player; it is a readable wake left by movement and a source of personality.

### Intended Player Feeling

- Motion gains flourish and continuity.
- Sudden turns, dashes, impacts, and stops have visible follow-through.
- The hero feels alive even before adding more animation complexity.

### Next Design Milestone

Write down the original scarf inspiration/reference and define whether its primary job is:

- movement readability,
- character identity,
- environmental wind communication,
- animation polish,
- or a deliberate combination of those jobs.

### Safety Rails

- Do not let it become random noodle motion.
- Avoid obscuring blade geometry or combat contact.
- Prefer physical follow-through and authored limits over constant noise.

---

## 8. General Store — Gear Finds Become Economy

**Status:** Spark / Partially Supported by Existing Home and Storage Systems

### Provisional Resonance Key

Loot should continue having meaning after the player’s immediate equipment needs are met. A General Store turns found gear into choice, circulation, and a sense that the world has a functioning local economy.

### Player Discovery

> “This duplicate is not dead inventory—I can convert it into preparation for the next expedition.”

### Intended Pipeline

- [ ] Define what gear may be sold and what remains protected.
- [ ] Establish transparent sale values tied to rarity/type without creating inventory chores.
- [ ] Connect selling to existing storage rather than creating a duplicate inventory model.
- [ ] Give the store a place/personality in Home rather than presenting a developer-style catalog.
- [ ] Decide whether the store also sells rotating gear, materials, services, or only buys initially.

### Safety Rails

- Never sell equipped, favorited, unique, or progression-critical gear accidentally.
- Avoid making optimal play require repetitive inventory cleanup.
- Preserve alphabetical/rarity storage readability.
- The store should strengthen expedition preparation, not replace finding and crafting gear.

---

## 9. Rescue the Blacksmith — Person Before Service

**Status:** Partially Implemented Progression / Needs Experiential Pass

### Resonance Key

The Forge should not simply unlock because a number increased. The player rescues a person, creates a relationship, and brings a valuable craftsperson home. Mechanical service is the consequence of a world event.

### Existing Foundation

- [x] Home communicates that the Blacksmith is rescued after Mine Wave 10.
- [x] Forge access is progression-gated.
- [x] Home already has a Forge destination/service flow.

### Next Experiential Milestone

Ensure the rescue, return home, and first service form a readable emotional chain:

`discover danger → rescue person → return together → relationship acknowledged → service earned`

### Questions

- Does the player meet or perceive the Blacksmith before the unlock message?
- Is the rescue itself memorable enough to justify the service?
- Does Home visibly change afterward?
- Does the Blacksmith feel like a character rather than a lock condition?
- Should later services emerge from relationship/progression instead of a single binary unlock?

### Safety Rails

- Person first, menu second.
- Do not reduce rescue to a silent boolean.
- Avoid withholding essential baseline maintenance behind an obscure condition.

---

## 10. Home as a Place of Return

**Status:** Mechanically Working / Ongoing Cohesion Work

### Resonance Key

Home should be where expedition results become care, preparation, relationships, and anticipation—not merely a menu displayed between runs.

### Connected Pipelines

- Storage gives materials and gear continuity.
- Kitchen turns preparation into care and sustain.
- General Store can turn surplus into agency.
- Blacksmith rescue turns progression into relationship and craft.
- Audio/day-cycle presentation should make returning feel emotionally different from combat.

### Safety Rails

- Keep destinations understandable and navigable.
- New services should belong to people and places.
- Avoid duplicating authoritative inventory, equipment, or crafting controls.

---

# Handoff and Video Feedback

When another tool can inspect a video but Ziva cannot access that chat directly, use a project file as shared memory:

`res://Ziva Help/VIDEO_FEEDBACK_<FEATURE>.md`

Recommended format:

```text
Clip/timecode:
Current profile and settings:
Player intention:
Observed result:
Desired feeling:
Visible geometry/state:
Likely cause:
Suggested experiment:
```

Codex or another assistant may write the observations into that file; Ziva can then read them from the same repository. Avoid simultaneous edits to the same gameplay scripts.

---

# Pipeline Maintenance Rules

After meaningful work on an idea:

1. Update its status.
2. Check off only behavior that was actually verified.
3. Record the next smallest playable milestone.
4. Preserve unresolved feel questions.
5. Link any detailed design, test, or video-feedback document.
6. Move abandoned approaches into History rather than silently forgetting them.
7. Do not mark an idea Shippable until both regression checks and a human feel pass agree.

## Current Recommended Session Order

1. **Bind Form:** Preserve the consolidated GP3 profile; polish only after a focused single-opponent feel test.
2. **Grapple Yo-yo:** Use the new left/right/tip guidance to tune the initial extension/orbit/recall sequence separately.
3. Validate one static wrap anchor.
4. Only then prototype one dynamic enemy wrap owner.
5. Return to progression/place pipelines when the current physics experiments have a stable stopping point.

This order is guidance, not a prison. New sparks belong here so they remain remembered without forcing every exciting thought into the current implementation session.
