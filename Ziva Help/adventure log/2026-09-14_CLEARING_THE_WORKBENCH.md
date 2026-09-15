# 2026-09-14 — Clearing the Workbench

## The Day's Adventure

The Bind experiment finally began feeling fluid, but the tuning process exposed a deeper production problem: Bind A, Bind B, shared Slide Feel, form-local Slide Entry, per-weapon overrides, combat presets, and global presets had become a maze of hidden authority. Matt spent hours adjusting controls that appeared to govern the same behavior while Bind B silently listened to another copy.

We stopped treating this as a tuning failure and cleaned the workbench. Bind A's persisted ID 8 remains load-safe but is retired from the selector. Canonical ID 9 is now the single visible **Bind Form**. Both IDs resolve the same canonical profile, and Curved Sword/Longsword use the same Slide and Bind tuning. Global Preset 3's latest Curved Sword Bind values were promoted into the shared profile, duplicate per-weapon Bind fields were removed, and GP3 was rewritten through the normal save API as the launch package.

Training Tools now presents one **SLIDE & BIND FEEL (All Weapons)** section. The old Slide Feel controls were moved under Slide Entry; duplicate form-local `bind_slide_*` controls and Reset-B / Clone-A→B actions were removed. Grapple Yo-yo's eight controls received the full meaning / left / right / tip guidance for tomorrow's tuning.

The day-cycle crisis also revealed that opening Training Tools forced Noon and re-imported saved forest values over live edits. That regression was fixed: opening menus no longer changes the phase or destroys unsaved visual tuning, and phase selection now updates the real world clock.

## Highlights

- Combat's latest run felt surprisingly fluid despite imperfect technique readability.
- GP3 debug evidence showed pressure-sensitive captures, sustained exchanges, five successful beats, and real good/bad leverage outcomes.
- Consolidated the Bind laboratory into one visible form and one authority.
- Preserved save-safe enum IDs without exposing obsolete choices.
- Repaired the Training Tools day-cycle reset and live-settings overwrite.
- Added comprehensive Yo-yo feel guidance.
- Established a hard refusal rule for duplicate authority.

## Struggles

- Duplicate Slide controls made valid tuning changes look ineffective.
- Form, sword, preset, and global-slot combinations buried the good profile in a “sea of shit.”
- Mechanical slide timers outlived geometry; generic contact presentation stacked under classified contacts.
- Opening menus destabilized day/night and live forest settings.
- Too much explanatory and mechanical complexity obscured the simple fantasy of controlling a connected blade.

## Game-Feel Learning

The resonance is not a catalogue of fencing terminology. It is: blades meet, contact gains readable weight, pushing through meets hinge resistance, and the player can work toward the hilt or open away. The latest GP3 values are a credible baseline: Capture `0.20 s`, Minimum Pressure `30 px/s`, Bound Sword Speed `0.10×`, shared Slide Speed `0.16×`. Do not add more sword footwork. Preserve fluidity and improve readability only when play evidence demands it.

Candidate travel currently often triggers Wind within one or two frames of stable capture. This may be natural entry motion rather than deliberate post-bind technique; observe before changing it. Multi-enemy parries/staggers also make learning control harder than a single-opponent test.

## Collaboration Learning

One behavior must have one authority. When a request would create duplicate controls, shadow settings, parallel saves, copied identities, or overlapping presets, Ziva must refuse outright unless Matt later sends `/password`. A warning after implementation is too late.

Matt's frustration was evidence: broken creative tools disrupt design flow, not merely convenience. Prefer consolidation, visible authority, and a short playable path over flexible laboratories.

## Memorable Language

> “My perfect sword form, nestled in a SEA OF SHIT.”

> “Sometimes I don't realize I'm spraying glue all over the place and then wondering why everything is sticky.”

> “A guy at his first night of fencing class except the graphics are bad.”

## Technical Record

- `STYLE_CYCLE_ORDER` no longer exposes `METRONOME_BIND` ID 8.
- ID 8 aliases canonical Bind ID 9 for loaded saves and direct setting resolution.
- `Player.ensure_experimental_form_initialized()` promotes old Curved Sword Bind-B values, strips duplicate Bind keys from weapon/style authorities, and leaves obsolete fields inert.
- Shared contact-preset Slide settings are the sole Slide authority.
- Training Tools now has one `SLIDE & BIND FEEL (All Weapons)` section.
- Removed duplicate form-local Slide UI and Bind A/B reset/copy actions.
- GP3 saved and launch slot confirmed as 3; canonical values confirmed across both weapons and IDs.
- Yo-yo controls now follow meaning / ← LEFT / → RIGHT / TIP convention.
- `COLLABORATION_PROTOCOL.md` contains the `/password` hard-refusal rule.
- Training Tools no longer forces Noon or reloads forest settings on open; phase selection synchronizes Main, Home, population, and persistence.

## Verification

- Menu flow: 14/14.
- Experimental Bind: 14/14.
- Sword form geometry: 14/14.
- Global presets: 4/4.
- Metronome visualizer: 8/8.
- Combat tracker: 4/4.
- Main scene booted without runtime errors.
- Live migration check confirmed both IDs and both weapons resolve Capture `0.20`, Pressure `30`, Bound Speed `0.10`, Slide Speed `0.16`.
- Rewritten GP3 contains no Bind authority under retired ID 8 or either per-weapon ID-9 override.

## Open Threads

- Tune Grapple Yo-yo using the new guidance.
- Test the Bind Form against one opponent before changing its profile.
- Decide whether Wind travel should begin at stable capture or continue counting candidate travel.
- Consider boiling off additional sword forms tomorrow; preserve enum IDs even when retiring selector entries.
- Keep dynamic enemy rope wrapping parked.

## Tomorrow's Doorway

Open Training Tools, choose the single Bind Form, and confirm that one Slide & Bind panel controls both weapons. Do one calm single-opponent exchange. Then move to Grapple Yo-yo tuning—no new sword techniques.

## Coding Tip of the Day

**Aliases are safer than renumbering, but aliases must converge on one storage key.** Keep old persisted IDs readable, remove them from public selection, and route every getter/setter to the canonical authority. Compatibility should not preserve duplicated behavior.

## Reasoning Recommendation

**Low** for Yo-yo slider tuning and form-list housekeeping. Use **Medium** only when changing physics behavior or persistence migration. Do not use High unless a focused regression survives multiple verified fixes.
