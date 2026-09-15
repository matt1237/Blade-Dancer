# 2026-09-13 — Tuning the Instruments

## The Day's Adventure

The second half of the day turned from inventing the Bind experiment toward making its tuning environment trustworthy. Form IV Bind B still felt locked up: slow-motion appeared too often, contact was difficult to read, and the surrounding Slide/Clash/Parry settings complicated the diagnosis. Rather than treating Bind B as an isolated box, we clarified the real contact-classification order: an existing bind gets first ownership, then shield interception, slide qualification, blocking, clash classification, parry, and finally ordinary body contact. A bind candidate exists only downstream of a validated slide.

That mattered because Matt had deliberately tuned ordinary slides to happen more often. The intended pleasure—frequent readable slides—had accidentally become coupled to frequent slow-motion bind opportunities. The next tuning question is therefore not simply “reduce slide tolerance,” but whether common slides graduate into stable binds too easily. Acquisition, graduation, retention, release, and presentation must remain separate.

We also improved the evidence path. Bind lifecycle events now print compact, grep-friendly console lines containing pressure, authored pressure, spike, tangential travel, leverage, contact duration, thresholds, and release reasons. This means a natural or intentional playtest can be analyzed from Godot output even when direct gameplay video is unavailable.

The tuning tools themselves then exposed several workflow faults. Global Preset 3's Curved Sword tuning had not been mirrored safely into Longsword; per-weapon overrides silently shadowed shared values. Training Tools also remembered the sword equipped at construction rather than the sword currently held. Both were corrected. Finally, Bind B sliders appeared frozen because each tiny `value_changed` event immediately forced a full-panel synchronization, rewriting the active slider during its own drag. Slider callbacks now update only their own stored value and numeric label; complete synchronization is reserved for actual context changes.

## Highlights

- Recognized that abundant slides and rare binds are compatible goals; the graduation gate—not necessarily the slide gate—is the likely tuning target.
- Added console-readable bind lifecycle evidence for candidate, stable bind, wind, beat/rejection, wrap/re-entry, and release.
- Kept the lightweight overhead display vertical, yellow, translucent, and background-free: Winds, Binds, Beats, Slides.
- Rebuilt GP3 Longsword Bind B from GP2 Longsword Bind A plus the intended GP3 deltas, while preserving Longsword identity values.
- Fixed Training Tools so the sword selector reflects the weapon actually equipped when the menu opens.
- Fixed slider dragging without changing saved tuning values.
- Restored feel-based tips after an unrequested baked-number convention replaced useful sensory guidance on six new controls.

## Struggles

- Slow-motion still felt too frequent and visually locking despite the first GP3 tuning pass.
- The interaction between shared Slide/Clash/Parry settings and Bind-local entry settings was initially oversimplified.
- Per-sword override precedence created silent Longsword/Curved Sword divergence.
- The tuning selector displayed Longsword while the player visibly held a Curved Sword, disrupting design flow and risking edits to the wrong profile.
- Bind B sliders looked immovable because full UI resynchronization fought the active drag.
- Six new tooltips violated the established feel-guidance convention by repeating baked values. Matt had to challenge the change before it was properly acknowledged and corrected.
- Agent continuity itself became a concern: switching agents can reduce coherence unless the new agent reads the targeted continuity documents.

## What We Learned About the Game

- A validated slide is the entry ticket for a bind, but it should not be a near-guarantee of slow motion.
- Frequent slides can remain part of the combat identity while stable binds require sustained deliberate pressure and time.
- Contact tabs are not independent: clash/parry latches, cooldowns, angle windows, and slide precedence shape the practical bind frequency.
- The likely next experiment is to preserve generous slide geometry while increasing Bind Capture Time and Minimum Pressure, then compare slide → candidate → stable-bind conversion.
- Slow-motion amount and slow-motion frequency are different tuning problems.
- Data can reveal what the game believed happened; video or player feel remains necessary to judge whether that belief matched visible contact.

## What We Learned About Working Together

- When Matt says an established tool or convention changed, believe the report and inspect before explaining it away.
- An assistant should not make Matt litigate why an unsolicited redesign is worse.
- Existing conventions are design assets. New controls inherit their siblings' voice unless a change is explicitly discussed.
- Short reports improve iteration speed: read, hypothesis, next test, reasoning level.
- Low reasoning is appropriate for isolated UI/tuning repairs; Medium is appropriate when contact classification crosses several systems.
- A targeted `/startofday` handoff is cheaper and more coherent than asking a new agent to scan the entire help folder.

## Resonant Moments

> “More slides” must not automatically mean “more slow-mo.”

> “It throws off my design flow meter.”

> “Don’t make me have to explain to you why you’re dumb.”

The emotional truth behind the frustration: tuning tools are part of the creative instrument. When they misidentify the sword, fight the mouse, or replace feel language with numbers, they do not merely contain bugs—they break the designer's concentration.

## Technical Record

- `Player._emit_combat_debug_event()` now prints compact `BIND: <EVENT> | ...` console records when `debug_print_sword_events` is enabled.
- Logged events include candidate, stable bind, wind, successful/rejected beat, wrap/rollover, re-entry, and release reason.
- The overhead Bind readout is a four-line yellow counter without a background.
- Global Preset 3 retains the first Curved Sword tuning pass and now gives Longsword Bind B equivalent experimental deltas seeded from GP2 Longsword Bind A.
- Global Preset 2 remained unchanged; launch slot remained GP2 while active editing slot remained GP3.
- `BackyardTrainingMenu.open()` now refreshes `selected_combat_sword_id` from `Player.equipped_sword_id` and resynchronizes the selector/shape controls.
- `_hand_setting_changed()` and `_contact_setting_changed()` no longer invoke `_sync_combat_controls()` during active dragging. They update only the relevant setting and label.
- Added local label helpers and regression coverage for successive Bind B slider values.
- Replaced six baked-value Form-local slide-entry tips with established left/right feel guidance.
- Added Convention Discipline to `COLLABORATION_PROTOCOL.md`.

## Verification Snapshot

- Experimental bind tests: 14/14.
- Combat Tracker tests: 4/4.
- Global preset tests: 4/4.
- Menu flow tests: 11/11 after selector and slider regressions.
- Main scene repeatedly booted without runtime errors.
- Direct programmatic Bind B slider test confirmed slider, resolved value, and raw Curved Sword `2:9` override all retained the changed value.

## Open Threads

- Run two controlled GP3 Curved Sword tests: natural contact and intentional bind attempts.
- Pull the console log after each and compare Slides, Candidates, Stable Binds, Winds, Beats, and Release reasons.
- Determine whether slow-motion frequency comes from easy graduation or whether stable binds visually outlive real contact.
- If graduation is too permissive, test Capture Time `0.08 → 0.14 s` and Minimum Pressure `12 → 28 px/s` while preserving the intentionally generous slide settings.
- Consider richer contact-classification logging only if current lifecycle logs cannot explain the conversion pattern.
- Validate physical behavior visually through a Vision Bridge if code state and visible blade separation disagree.

## Tomorrow's Doorway

Equip the Curved Sword, load Global Preset 3, select Form IV Bind B, and perform one 30–60 second natural-contact run without forcing techniques. Stop and request: “Pull the bind log — natural run.” Then perform a separate intentional-bind run.

## Coding Tip of the Day

**Do not perform a full UI model-to-view refresh inside a continuously firing slider callback.** Write the changed value and update that control locally; reserve full synchronization for context changes. Otherwise the application fights the user's active drag and makes valid storage look broken.

## Reasoning Recommendation

**Low** for the next controlled playtest and evidence review. No code change is required to collect the first logs.

Move to **Medium** if lifecycle data cannot explain the visual lock-up, because the next step would involve timer domains and classification instrumentation across Slide, Clash, Parry, and Bind systems.
