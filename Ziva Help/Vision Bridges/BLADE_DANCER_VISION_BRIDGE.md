# BLADE DANCER — VISION BRIDGE PROTOCOL

Purpose:
Translate gameplay video that Ziva cannot directly inspect into a compact, structured text packet that preserves the important visual/temporal information needed for coding and tuning.

## Workflow

1. Matt uploads a gameplay clip to Codex/ChatGPT.
2. Codex inspects the clip visually and temporally.
3. Codex writes a `VIDEO_RELAY_*.md` packet.
4. Put the packet in:
   `docs/vision_bridge/`
5. Ziva reads the relay packet before touching code.
6. Ziva uses the relay as observed ground truth, then inspects only the relevant game files.

This is NOT a design document. It is a translation layer between visual gameplay and code.

---

# Relay Packet Format

## Clip
- Filename:
- Duration:
- Date:
- Feature being tested:

## Intent
What Matt intended the mechanic to do.

## What is visibly happening
Describe only observable behavior from the clip.
Avoid guessing implementation.

## Timeline
Use timestamps when they matter.

Example:
- `00:03.2` — sword contact begins.
- `00:03.5` — sustained slide becomes visible.
- `00:04.1` — enemy blade is displaced clockwise.
- `00:04.6` — contact breaks.

## Motion decomposition
When useful, describe:
- radial motion
- tangential motion
- angular/orbital motion
- acceleration/deceleration
- preserved momentum
- lost momentum
- pivot/anchor changes
- collision/contact state

## What looks correct
Behaviors that should be preserved.

## What looks wrong / unfinished
Visible problems or tuning concerns.

## Desired change
Exact behavioral target.

## Constraints
Things Ziva must NOT change.

## Likely subsystem
Best guess only:
- sword physics
- grapple
- chakram
- enemy AI
- camera
- VFX
- etc.

## Suggested investigation
Smallest likely file/system set to inspect.

## Acceptance test
A visual test Matt can perform after the change.

## Confidence
- High: clearly visible.
- Medium: likely from motion but not certain.
- Low: needs instrumentation/code confirmation.

---

# IMPORTANT RULES FOR ZIVA

Treat the relay as visual evidence, not as proof of implementation.

Do not rewrite systems merely because the relay describes a behavior.
First inspect the relevant code and determine why that behavior occurs.

Preserve anything listed under `What looks correct`.

When a relay includes timestamps, use them to understand sequence and timing.
Do not assume a still frame contains the whole behavior.

If the relay says a behavior is ambiguous, instrument/debug rather than guessing.

Do not scan unrelated project folders.

---

# SAMPLE RELAY — 2026-09-13 Experimental Bind / Chakram Clip

## Clip
- Filename: `2026-09-13 13-56-43.mp4`
- Duration: ~46.5 seconds
- Feature being tested: experimental sword bind/slide behavior, enemy weapon contact, chakram interaction

## Intent
The current build is exploring physical combat manipulation rather than fixed canned reactions:
- sword contact can remain engaged and slide
- weapon angles and contact should matter
- chakram/grapple behavior is being developed toward tethered kinetic manipulation

## What is visibly happening
- Sword contact repeatedly enters sustained sliding/contact rather than always separating immediately.
- Contact direction changes as the player moves the weapon.
- Multiple weapon-bearing enemies can engage around the player while the sword remains visually readable.
- The chakram appears as an independent moving object in the combat space rather than only as a simple instant-return projectile.
- The overall combat already reads as physics-driven interaction, but several behaviors are still clearly experimental/tuning-stage.

## Timeline notes
- `~00:02–00:09` — single-enemy blade contact demonstrates repeated contact/slide behavior.
- `~00:12 onward` — multiple enemies are spawned for stress testing.
- `~00:16–00:30` — repeated multi-enemy blade contacts; slide counters increase and weapon vectors visibly change.
- `~00:25 onward` — chakram is active while sword interactions continue.
- `~00:30–00:44` — player moves through larger combat space while multiple enemies and chakram remain active.

## What looks correct
- Sustained blade contact is visually legible.
- Sword geometry remains readable during contact.
- Player weapon movement visibly influences the contact relationship.
- Multi-enemy contact does not immediately collapse into unreadable overlap.
- The combat has a clear physical/kinetic quality worth preserving.

## What looks unfinished
- Current bind behavior appears stronger/more deterministic than the final design should be.
- Enemy responses to a bind do not yet appear to express distinct fighting styles.
- Chakram/tether states are not yet visually self-explanatory to a new viewer.
- The final max-range/orbit/burn-off/reel rules are still being developed.

## Constraints
Preserve:
- current sword readability
- sustained contact/sliding capability
- momentum-based weapon feel
- player-directed kinetic manipulation

Do not convert the system into:
- canned parry animations
- automatic win-on-bind behavior
- button-based sword minigames
- hard snapping trajectories unless physically necessary

## Acceptance test for future bind work
Spawn several weapon enemies and verify:
1. contact can enter a sustained bind
2. player can influence the blade relationship
3. enemy can sometimes win/disengage/counter
4. repeated binds do not all resolve the same way
5. the sword remains readable during multi-enemy pressure

## Confidence
High for visible contact/slide behavior.
Medium for deeper physics interpretation without code inspection.
