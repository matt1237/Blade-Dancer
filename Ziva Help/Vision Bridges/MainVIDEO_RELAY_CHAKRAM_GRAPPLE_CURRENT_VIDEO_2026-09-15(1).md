# VIDEO RELAY — CHAKRAM GRAPPLE / TENSION CONSISTENCY
**Date:** 2026-09-15  
**Project:** Blade Dancer  
**Source clip:** `2026-09-15 14-38-38(1).mp4`  
**Clip duration:** ~79.7 seconds  
**Purpose:** visual relay for Astra / coding agent that cannot directly inspect the gameplay video.  
**Status:** This relay supersedes the older ~23-second enemy-wrap relay for the current stabilization task.

---

## 1. CURRENT PLAYER INTENT

The current target interaction is intentionally simpler than the earlier enemy-wrap experiment.

Desired core loop:

1. Player throws the Chakram.
2. Grapple catches the Chakram.
3. The rope becomes meaningfully connected/tensioned quickly.
4. The Chakram keeps satisfying momentum and tangential/orbiting movement.
5. It may hang/orbit briefly.
6. Reel-back then begins clearly and decisively.
7. Chakram returns to the player.

The intended feel is:

**grab disc -> rope gets tight -> disc swings / hangs briefly -> disc comes home**

The brief hang/orbit is GOOD and should remain.

The long loose/floppy period after a successful catch is BAD.

---

## 2. IMPORTANT CURRENT DESIGN DECISION

### Enemy rope wrapping is no longer required.

The previous wrap experiment may be removed, disabled, or bypassed for Chakram grappling.

The tether is allowed to visually pass across/through enemies.

Do not spend this repair pass trying to make enemies act as persistent rope pivots.

Do not preserve old wrap complexity if it is contributing to:

- rope-length calculation
- tension inconsistency
- unexpected pivots
- reel delays
- slack
- visual rope geometry
- state-machine complexity

Preserve ordinary enemy/terrain grapple behavior unless it is directly affected by shared code.

---

## 3. WHAT THE CURRENT VIDEO CLEARLY SHOWS

### A. The mechanic is working in pieces, but not consistently

Across the clip, repeated Chakram grapple attempts do not produce the same feel.

The grapple can successfully connect to the Chakram, but the post-catch behavior varies noticeably between attempts.

The issue is therefore not simply:

> "the grapple cannot catch the Chakram"

The problem is:

> "a successful catch does not reliably enter the same useful tension / hang / reel behavior."

---

### B. Loose / floppy post-catch rope is visible

Several catches leave a visibly loose or wavy tether while the Chakram continues moving without immediately feeling constrained by the connection.

The Chakram can remain in this soft, floating state longer than feels intentional.

This reads as:

- connection succeeded
- but tension authority has not clearly taken over yet

The visual problem is not that all slack must disappear instantly.

A small amount of catch softness is fine.

The problem is **prolonged ambiguity** between:

- caught
- extending
- hanging
- taut
- reeling

---

### C. Similar-looking grabs can produce different tension behavior

Repeated attempts from broadly similar gameplay situations produce different apparent rope tension and different timing before the Chakram feels meaningfully tethered.

This is the strongest consistency problem in the clip.

A player should not have to guess which version of the grapple response they are about to get.

---

### D. Enemy intersection / wrapping is unreliable

There are moments where the tether path crosses an enemy without establishing the earlier wrap/pivot behavior.

Under the OLD design this was a failure.

Under the CURRENT design decision, this is acceptable.

Do not repair the current system by rebuilding enemy-wrap detection.

The line passing through an enemy is preferable to keeping a large unstable wrap subsystem alive.

---

### E. The late successful interaction is the qualitative target

Near the end of the clip, there is an attempt where the overall interaction becomes much closer to the intended feel.

The important qualities of that successful example are:

- grapple connection reads clearly
- rope feels meaningfully connected rather than indefinitely floppy
- Chakram retains motion instead of freezing
- tangential/orbiting motion remains satisfying
- the short hang feels intentional
- transition into return/reel feels coherent
- the whole sequence reads as one continuous physical interaction

This successful late example proves the desired feel is already reachable by the current mechanical ingredients.

The task is to make that quality of interaction **repeatable**, not to invent a new mechanic.

---

## 4. TEMPORAL OBSERVATIONS

Timestamps are approximate and are provided for video navigation, not as implementation truth.

### Early portion — roughly first 20–25 seconds

Repeated throw/grapple attempts establish the main failure pattern:

- Chakram can be caught.
- Tether appears visually soft/slack after some catches.
- Catch does not always convert quickly into a strong readable tether relationship.
- The interaction can feel more like the Chakram is floating on a long loose line than hanging from a controlled tether.

### Middle portion — roughly 25–60 seconds

Repeated attempts continue to expose inconsistency.

Observed themes:

- similar catches do not always feel equivalent
- line tension can take too long to become useful
- the Chakram sometimes continues in a loose-feeling state
- enemy crossings do not reliably create wrap behavior
- this makes wrap logic a poor stabilization target

The repeated attempts are useful because they demonstrate that the problem is systemic, not a single bad throw.

### Late portion — roughly 60 seconds to end

The clip contains the clearest useful reference behavior.

At least one late interaction gives the intended combination much more successfully:

**catch -> tension -> short natural hang/orbit -> coherent return**

Use that sequence as the qualitative feel target.

Do not overfit to the exact trajectory or exact position in that attempt.

Match the relationship between:

- catch
- tension
- preserved momentum
- hang
- reel

---

## 5. USER-REPORTED TUNING CONTEXT

The following is player/developer observation supplied alongside the video and should be treated as important debugging context:

- Grappling the Chakram felt tighter previously.
- The current grapple can feel loose/floppy for too long after catching.
- Reducing the hang-time setting did not materially solve that loose period.
- The hang itself is liked and should remain.
- There is suspicion that one or more behaviors became hardcoded during recent changes.
- The current tuning surface is no longer clear enough to know which setting actually owns the resulting feel.
- The system has reached "tuning hell": changing one apparent feel variable does not reliably produce the expected gameplay result.

This strongly suggests an ownership/state problem rather than merely one incorrect numeric value.

---

## 6. DO NOT TREAT HANG TIME AS THE SAME THING AS CATCH SLACK

These are separate phases and should remain separate concepts.

### Catch / tensioning phase

Purpose:

- establish the successful grapple connection
- consume only the small intentional catch slack
- become meaningfully taut quickly and consistently

This phase should be short.

### Hang / orbit phase

Purpose:

- let the now-connected Chakram preserve satisfying tangential motion
- create the yo-yo / tetherball moment
- give the player a readable suspended/orbiting beat

This phase is intentionally enjoyable and may be configurable.

### Reel phase

Purpose:

- clearly transition from hang into return
- shorten the tether decisively
- bring Chakram home

Reducing hang duration should not be required to fix excessive catch slack.

If changing hang time currently changes little or nothing about the loose catch period, investigate why those authorities are coupled or overridden.

---

## 7. INVESTIGATE BEFORE EDITING

Before making the repair, trace the complete Chakram grapple lifecycle in the CURRENT LOCAL PROJECT.

Identify every place that can author or alter:

1. grapple attachment
2. initial `rope_length`
3. `rope_taut`
4. initial slack
5. slack take-up
6. Chakram yo-yo state
7. extending duration
8. orbit/hang start
9. orbit/hang duration
10. reel start
11. reel speed
12. radial constraint
13. tangential drag
14. Chakram velocity
15. hard positional correction
16. visual rope slack/wave amplitude
17. any global preset/config values
18. hardcoded thresholds that compete with exported tuners
19. old enemy-wrap path length / pivot calculations

The goal is to answer:

**Why can two successful Chakram catches enter visibly different tension behavior?**

Do not begin by adding another setting.

---

## 8. KNOWN CODE-SIDE RISKS TO VERIFY LOCALLY

These are diagnostic leads from the recent repository snapshot, NOT guarantees that the current local files are identical.

Verify every item against the current local project before changing it.

Recent code contained overlapping authorities including:

- an exposed minimum orbit/hang time
- an additional speed-based condition before recall
- a hardcoded extending fallback time
- a hardcoded outward-speed threshold
- a hardcoded taut-distance tolerance
- rope length being shortened during initial slack take-up
- a separate Chakram-side radial/position constraint
- extensive enemy-wrap path/pivot calculations

This combination can make a player-facing "hang time" setting fail to correspond directly to the visible behavior.

The desired outcome is fewer authorities, not another compensation layer.

---

## 9. TARGET STATE MODEL

Use the existing architecture where practical, but behavior should conceptually reduce to something this clear:

`FREE`

-> `GRABBED / TENSIONING`

-> `TAUT_HANG`

-> `REELING`

-> `RELEASED / COLLECTED`

### GRABBED / TENSIONING

- Catch has succeeded.
- Small intentional slack may exist.
- Slack is consumed promptly.
- The system reaches a meaningful constraint consistently.

### TAUT_HANG

- Rope is now genuinely engaged.
- Outward radial extension is constrained.
- Tangential motion survives.
- Chakram can swing/orbit naturally.
- Hang duration is predictable.

### REELING

- Reel transition is explicit.
- Rope begins shortening decisively.
- Chakram returns.
- No hidden state should leave it hovering indefinitely.

---

## 10. PHYSICAL FEEL REQUIREMENTS

### At tension

Decompose Chakram velocity relative to active grapple pivot:

`velocity = radial_component + tangential_component`

When rope is taut:

- outward radial motion beyond allowed length should be damped/stopped
- inward radial motion may continue
- tangential motion should be preserved

This gives the desired hanging/orbiting feel without a rubber-band snap.

### Do not solve the problem by:

- freezing the Chakram
- constantly pointing velocity directly at the player
- deleting tangential momentum
- removing the hang
- adding huge reel force to overpower bad state logic
- adding another fallback state
- adding another duplicated tuning parameter

---

## 11. TUNER CLEANUP

The player/developer should be able to understand which few values control the feel.

Prefer a small authoritative set such as:

- initial catch slack / catch softness
- slack take-up rate or catch-tightening behavior
- hang/orbit duration
- reel speed
- radial tension softness/damping
- optional orbit drag

Do not create duplicates if equivalent tuners already exist.

If hardcoded values materially determine a player-visible state transition, either:

1. derive them from an authoritative existing tuner, or
2. deliberately keep them as documented implementation constants with a clear reason.

Do not allow unnamed magic numbers to silently override player-facing controls.

---

## 12. ENEMY-WRAP CLEANUP

Enemy wrapping is no longer part of the acceptance target.

For this stabilization pass:

- disable/remove enemy-wrap acquisition for Chakram tether
- do not use enemy wrap points to alter rope length
- do not use enemy wrap state to alter active pivot
- do not use winding arc length to delay reel
- do not use wrap-specific minimum occupied rope length
- do not draw a special enemy-wrap rope path if that path can affect or misrepresent gameplay state

If fully deleting old code is risky, bypass it cleanly behind one authoritative disabled path and document it for later cleanup.

The current goal is reliability.

---

## 13. ACCEPTANCE TEST

Use repeated gameplay trials, not one successful run.

### Repeat at least several times in each case:

- short-range catch
- medium-range catch
- near-max-range catch
- Chakram moving rapidly outward
- Chakram moving mostly sideways
- Chakram moving slowly
- Chakram already beginning to come inward

### A pass requires:

1. Hook catches Chakram reliably.
2. Successful catch enters the same basic state progression each time.
3. Only small intentional initial slack exists.
4. Meaningful tension establishes promptly.
5. Rope does not remain visibly floppy for an extended period.
6. Chakram does not teleport when tension engages.
7. No violent rubber-band reversal.
8. Tangential/orbiting motion survives.
9. Hang/orbit remains visible and fun.
10. Hang-time setting predictably changes the hang phase.
11. Changing hang time is NOT required to fix catch slack.
12. Reel begins clearly when hang ends.
13. Return is decisive and coherent.
14. Repeating similar grabs produces recognizably similar feel.
15. Passing across an enemy does not create unstable wrap behavior.
16. Existing sword/Chakram interaction still works.
17. Ordinary grapple behavior is not regressed.

---

## 14. QUALITATIVE SUCCESS TARGET

Do not chase perfect mathematical rope simulation.

The target is the late successful interaction in the reference video.

The player should feel:

**"I caught it."**

then:

**"Now it is actually on my line."**

then:

**"Nice — it swings."**

then:

**"WHAMO — it is coming home."**

There should not be a long period of:

**"Did I catch this thing? Why is the rope still floating around?"**

---

## 15. MOST IMPORTANT IMPLEMENTATION RULE

### DO NOT FIX THIS BY ADDING MORE PATCHES

Diagnose why the system has inconsistent ownership.

Then consolidate.

If an old system, state, magic number, or wrap calculation no longer serves the current intended interaction, remove/bypass it rather than compensating for it elsewhere.

**Consistency and feel are the objective.**

---

## 16. REQUIRED REPORT AFTER THE PASS

Before/after editing, report:

1. Exact current Chakram grapple state lifecycle.
2. Root cause(s) of inconsistent post-catch tension.
3. Every competing/hardcoded authority found.
4. Whether hang duration was being overridden/gated by another condition.
5. What old enemy-wrap behavior was removed/bypassed.
6. What was consolidated.
7. Which small set of tuners now controls the interaction.
8. What repeated gameplay tests were performed.
9. Any remaining known edge case.

Do not report the task complete based on one good throw.

The successful late-video interaction must become the normal result, not the lucky result.
