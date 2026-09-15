# 2026-09-13 — Hinges, Yo-yos, and Seeing the Fight

## The Day's Adventure

The session began with a sword experiment that had become mechanically interesting but operationally confusing. Form III could create genuine blade binds, yet testing it required remembering a fragile Global Preset hierarchy. We separated the experiment from that hierarchy: Form III became Bind A, and an appended save-safe Form IV became Bind B (TEST). Bind B now owns the recorded forgiving hinge and slide-entry values locally.

The bind's image sharpened into “two opposing doors on hinges.” Correct contact resists forcing one blade through the other, but opening away remains free. From that physical conversation came tangential travel, winds, guard-wrap disengagements, rollover communication, collision-gated re-entry, and leverage-based weapon beats.

In parallel, Grapple Yo-yo began turning Chakram + Grapple into a combined physics toy: outward radial motion is constrained near full extension while tangent survives into an orbit, energy burns naturally, recall hands off safely, and one static obstruction may become a wrap pivot.

A new problem then became obvious: the fight was happening too quickly to tune by eyesight alone. The overhead slide count could say that contact occurred, but not why a bind captured, why a beat failed, or what ended the exchange. That led to the in-game Combat Tracker and to the Vision Bridge protocol for translating gameplay clips into structured evidence.

Finally, we decided to preserve not just implementation state but the lived development adventure—its breakthroughs, frustrations, language, and collaborative rhythm—through this log and a permanent collaboration protocol.

## Highlights

- The hinge behavior worked in a real playtest and felt cool enough to deserve deeper tuning.
- Bind A/B became direct form choices rather than a confusing whole-game preset ritual.
- Bind B retained independently persisted local entry/bind values without renumbering old forms.
- Grapple Yo-yo produced a credible emergent orbit/recall foundation.
- The Combat Tracker made pressure, authored pressure, spikes, travel, leverage, outcomes, and release reasons readable in-game.
- The first Vision Bridge established a practical path from gameplay video to targeted code investigation.
- The collaboration itself became explicit project memory rather than remaining an unwritten property of one chat.

## Struggles

- The Global Preset 3 → Combat Preset 2 → Form III workflow was too easy to lose track of.
- Fast bind motion made visual-only tuning unreliable.
- Existing debug feedback reported “slide” but not the sequence or failed requirement.
- During implementation, an initial Bind B migration profile briefly contained inferred values beyond the recorded authored set. It was corrected with a versioned migration that recloned Bind A and overlaid only recorded values plus unchanged local baselines.
- The Combat Tracker initially overlapped the left HUD and its `+` affordance was ambiguous during automated clicking. It moved to the top-right and now uses explicit EXPAND/COLLAPSE labels.
- A stale todo reminder could not be updated because no todo-writing tool was available; implementation itself was nevertheless verified.

## What We Learned About the Game

- Bind quality cannot be represented by one “stickiness” value. Acquisition, candidate stability, crossing resistance, opening freedom, tangential travel, release, and reward are separate feel dimensions.
- Offense feels earned when a beat needs player-authored pressure, a new spike, and favorable leverage.
- Short physical memory can support expressive follow-ups without becoming a canned combo, provided a new valid swept collision is still required.
- Combined verbs are the strongest source of depth: the Chakram orbit matters because ordinary sword hits and grapple geometry can interact with it.
- Instrumentation should reveal causes, not merely name outcomes.

## What We Learned About Working Together

- Discussion mode must be explicit and persistent; generic interface banners must not force implementation.
- The best rhythm is playful exploration followed by narrow implementation and concrete verification.
- Matt's metaphors often contain the most useful mechanical specification. “Opposing doors on hinges” directly describes unilateral resistance and unconstrained opening.
- Ziva should preserve emotional resonance alongside architecture and tests.
- Affordable Low/Medium reasoning is usually enough; escalation should respond to structural uncertainty, not ambition.
- Honest encouragement matters, but so does naming onboarding, content, polish, and production risk without dampening the creative momentum.

## Resonant Moments

> “Two weapons become opposing doors on hinges.”

> “I did not press a bind button. Our blades met correctly, I held the line, and now I can work the contact.”

> “High dev hiding tricks—highding tricks.”

The day also carried a larger conviction: the project may have the ingredients for something unusually shareable if its physical identity, clarity, and emotional return-home structure survive production.

## Technical Record

- Added save-safe `Player.SwordStyle.METRONOME_BIND_B = 9`; all earlier persisted IDs remain unchanged.
- Public order is Forms I–II, Form III Bind A, Form IV Bind B (TEST), then existing internal forms displayed as V–X.
- Generalized experimental-bind capability checks and metronome visualization for A/B.
- Added Bind-B-local slide-entry overrides and one-time authored-profile migration.
- Added safe Reset B and Clone A → B controls with no reverse overwrite action.
- Left Global Preset files outside migration authority.
- Implemented Grapple Yo-yo radial constraint, tangent preservation, orbit burn, recall handoff, and static wrapping foundation.
- Added `Player.combat_debug_event` and `res://scripts/ui/combat_debug_tracker.gd`.
- Tracker records a bounded timeline of slide, candidate, stable bind, wind, beat/rejection, wrap/re-entry, and release events.
- Added `res://Ziva Help/vision bridges/BLADE_DANCER_VISION_BRIDGE.md` as the video translation protocol.
- Added this collaboration protocol and Adventure Log structure.

## Verification Snapshot

- Sword form geometry: 16/16 after Bind B additions.
- Experimental bind: 14/14.
- Combat Tracker: 3/3.
- Menu flow: 9/9.
- Metronome visualizer: 8/8.
- Global presets: 4/4.
- Grapple physics: 21/21 from the Yo-yo pass.
- Main scene and Backyard Training booted without runtime errors or configuration warnings.
- Known unrelated Home alphabetical-storage assertion remains outside this work.

## Open Threads

- Playtest Bind B with the expanded tracker and determine the dominant failure stage.
- Decide whether `WIND` should remain a threshold event or gain richer directional/endpoint semantics.
- Compare visible video timing against tracker events through a new relay packet.
- Tune beat pressure/spike/leverage only after acquisition and retention feel trustworthy.
- Keep dynamic enemy tether wrapping parked until static wrapping and orbit feel stable.
- Continue the longer-term scarf, store, rescue, and Home-as-return pipelines without losing their resonance keys.

## Tomorrow's Doorway

Enter Backyard Training, select Form IV Bind B, expand the Combat Tracker, and perform ten plausible blade contacts. Do not tune immediately. First count where the sequence most commonly stops.

## Coding Tip of the Day

**When an experimental behavior depends on many thresholds, improve observability before adding more tuning controls.** A tracker that distinguishes `SLIDE → CANDIDATE → BIND → WIND → RELEASE` reveals which stage is failing. Otherwise, changing retention to solve an acquisition problem can make the mechanic magnetic while leaving the real problem untouched.

## Reasoning Recommendation

**Medium.** The next pass combines physics feel, collision evidence, tracker semantics, and tuning, but the architecture is understood.

Escalate if the tracker and video disagree about event order, multi-enemy ownership becomes unclear, or several focused tuning hypotheses fail.
