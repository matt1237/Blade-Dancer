extends RefCounted
## PX CONFIG — every constant the prototype runs on, in one place.
##
## Nothing here touches the game. Change a number here and the whole prototype
## (game, lab, tests) follows. The values that are LIVE-tunable at runtime — the
## motor's stiffness / damping / max torque, the metronome's arc and frequency,
## and the hand's minimum and maximum reach — start from the DEFAULTS below but
## are owned while playing by PXTuningTools.
##
## Referenced by the other PX modules as:  const Cfg = preload(".../px_config.gd")

# ── Physics layers ──────────────────────────────────────────────────────────
const L_WALLS: int = 1
const L_PLAYER: int = 2
const L_ENEMY: int = 4
const L_PLAYER_SWORD: int = 8
const L_ENEMY_SWORD: int = 16

# ── Arena ───────────────────────────────────────────────────────────────────
## One screen, exactly: Blade Dancer's own gameplay arena is 1280x720
## (main.gd DEFAULT_GAMEPLAY_ARENA_RECT), the same as the base viewport, so the
## WHOLE map is visible in a single 1280x720 frame — no scrolling, no hunting for
## enemies off-screen. Centred on the origin because that is where the player
## spawns, so the arena straddles (0,0).
const ARENA: Rect2 = Rect2(-640.0, -360.0, 1280.0, 720.0)
const WALL_THICKNESS: float = 40.0

# ── Player (values matched to the real game) ────────────────────────────────
const PLAYER_RADIUS: float = 16.0
const MOVE_SPEED: float = 250.0
const DASH_SPEED: float = 500.0
const DASH_TIME: float = 0.15
const DASH_COOLDOWN: float = 0.7
const PLAYER_MAX_HEALTH: float = 100.0

# ── Hand radius (LIVE-tunable) ──────────────────────────────────────────────
## Blade Dancer's own rule: the grip orbits the body along the aim, its reach
## driven by how far the CURSOR is — cursor close hugs the body at the minimum,
## cursor far extends to the maximum, linear between. The real mechanic, and the
## game's own hand settings carry the same pair of numbers ("min" / "max").
##
## Live-tunable: PXTuningTools owns these while playing. Both numbers are read
## straight off the player's live save: GP2, Metronome_Bind form, curved sword
## (shared hand 2:9 overlaid by the "Basic Curved Sword" 2:9 override): min 5 / max 40.
const DEFAULT_HAND_MIN: float = 5.0
const DEFAULT_HAND_MAX: float = 40.0
## Spatial gearing, also copied from the same GP2 Bind hand ("scale" 4.0). Full
## hand reach is not a straight min->max lerp of cursor distance: the cursor must
## travel out to `min + (max-min)*scale` before the grip fully extends, so the
## reach eases in. This is the exact rule player.gd:_mouse_controlled_hand_radius() uses.
const REACH_SCALE: float = 4.0

# ── The sword motor ─────────────────────────────────────────────────────────
const BLADE_LENGTH: float = 84.0
const BLADE_THICKNESS: float = 12.0
## Blade inertia about the PINNED hilt (parallel-axis: I_com 600 + m*d^2 with the COM
## 42 px out) is ~2364, so a critically damped PD motor wants damping ~=
## 2*sqrt(stiffness * inertia) ~= 29000. At 15000 the loop was underdamped (~0.5),
## which let the blade overshoot every reversal; 25000 (ratio ~0.86) tracks the
## reference arc cleanly without feeling sticky.
const DEFAULT_MOTOR_STIFFNESS: float = 90000.0
const DEFAULT_MOTOR_DAMPING: float = 25000.0
const DEFAULT_MAX_TORQUE: float = 180000.0

# ── The sword BODY (LIVE-tunable) — what the object itself is like ──────────
## The blade's OWN physical properties, distinct from the MOTOR above. The motor
## is how strongly YOU control the object; these are what the object IS. None of
## them writes a pose: mass and damping only feed the solver, and the centre of
## mass only tells it where the blade balances.
##
## MASS is set once and left alone. Godot derives the blade's rotational inertia
## from mass and shape, so changing mass silently re-scales what every stiffness
## value means (the same torque turns a heavier blade more sluggishly). That is
## exactly why the tuning ladder fixes mass first and then moves only the motor.
const SWORD_MASS_DEFAULT: float = 1.0
const SWORD_MASS_MIN: float = 0.25
const SWORD_MASS_MAX: float = 8.0
## PASSIVE damping: a continuous brake on whatever rotation / translation is
## happening, whoever caused it. Unlike the motor's damping it has no idea where
## the blade is meant to point, so it also fights the swing you asked for — which
## makes it a cleanup knob, not a control knob. 0 = honestly off (the baseline).
const SWORD_ANGULAR_DAMP_DEFAULT: float = 0.0
const SWORD_LINEAR_DAMP_DEFAULT: float = 0.0
const SWORD_DAMP_MIN: float = 0.0
const SWORD_DAMP_MAX: float = 20.0
## Where the blade balances, in px from the HILT along the blade. Godot's AUTO
## centre of mass sits at the shape's centre = BLADE_LENGTH * 0.5 = 42 (mid-blade);
## this default reproduces that, and the slider overrides it. Gravity is OFF and
## the hilt is pinned, so there is no hanging weight to feel — treat this as a
## collision-response / inertia knob, NOT a "tip-heavy balance" knob.
const SWORD_COM_OFFSET_DEFAULT: float = BLADE_LENGTH * 0.5

# ── Enemies ─────────────────────────────────────────────────────────────────
const ENEMY_RADIUS: float = 18.0
const ENEMY_MAX_HEALTH: float = 420.0
const ENEMY_SPEED: float = 74.0
## Enemies are REAL rigid bodies so the blade can physically shove them — the
## target gives and the blade slides along it instead of wedging. Mass and damping
## set how much give: light enough that a swing actually knocks the body off its
## line (a measured 6 kg body only got nudged ~60 px, which read as "the sword
## sticks on the enemy"), heavy enough that it doesn't fly like a leaf. At 2.0 the
## same swing drives a body ~136 px, past the point where the sweep runs out of
## reach. Steering is applied softly so a shoved enemy eases back to its approach
## instead of snapping and bumping against the blade.
const ENEMY_MASS: float = 2.0
const ENEMY_LINEAR_DAMP: float = 1.5
const ENEMY_ANGULAR_DAMP: float = 1.5
const ENEMY_STEER_RESPONSE: float = 6.0
const ENEMY_FRICTION: float = 0.2
## Armed enemies hang back just far enough for their own blade to reach;
## unarmed ones press in to body-check you.
const ENEMY_STOP_RANGE_ARMED: float = 62.0
const ENEMY_STOP_RANGE_UNARMED: float = 22.0
const ENEMY_HAND_OFFSET: float = 20.0
const ENEMY_CONTACT_DAMAGE: float = 8.0
const CONTACT_COOLDOWN: float = 0.6
const SWING_DAMAGE: float = 34.0
const SWING_HIT_COOLDOWN: float = 0.28
const ENEMY_SWORD_DAMAGE: float = 14.0
const RESPAWN_DELAY: float = 1.1

# ── Enemy material: flesh and core (LIVE-tunable) ───────────────────────────
## An enemy is TWO zones, and only ONE is a real collider:
##   CORE  — a small SOLID body. The blade physically stops and turns on it ("bone").
##   FLESH — the ring around the core. NOT a collider: the blade passes THROUGH it,
##           but we drag (slow) it and deal the cut. That give is the "cut into
##           flesh" feel — a force the solver integrates, never a written transform.
## Radii are in px. The defaults are a MEDIUM feel: mostly cut-through, with a real
## core to catch on.
const FLESH_RADIUS_DEFAULT: float = 26.0
const BONE_CORE_RADIUS_DEFAULT: float = 10.0
## Flesh drag: how hard the swing is retarded while the blade is in the flesh ring,
## as a fraction of the torque-per-rad/s ceiling below. 0.5 = a clear bite, still
## quick through.
##
## The drag is viscous (torque ∝ spin) and the applied total is clamped in the enemy
## manager by MATERIAL_DRAG_CLAMP — which sits ABOVE the motor's torque. That is
## deliberate, and it was the fix for "maxed flesh feels like nothing": the old clamp
## (DEFAULT_MAX_TORQUE, 180k) sat BELOW the live motor (213k), so the motor always
## out-drove the drag and any bite was cancelled before it could be felt. With the
## clamp above the motor, a maxed bite genuinely hauls the blade down — while staying
## finite, so the blade never freezes (it settles into a slow crawl instead).
const FLESH_DRAG_DEFAULT: float = 0.5
const FLESH_DRAG_MAX: float = 90000.0
## The most drag the material model may apply to the blade, at any spin. Kept ABOVE
## the motor's max torque so flesh/bone can actually beat the motor and be felt; kept
## finite so the blade can always still crawl through. ~3x the motor's default.
const MATERIAL_DRAG_CLAMP: float = 540000.0
## Bone friction: how hard the blade GRIPS the core (glance ↔ catch), as a fraction
## of the ceiling below. 0 is slick (skates around the bone); 1 is a hard catch. The
## ceiling is held ABOVE flesh drag's so the core always grips harder than the flesh
## at equal slider values — bone is the catch, flesh is the slow-through.
const BONE_FRICTION_DEFAULT: float = 0.35
const BONE_FRICTION_MAX: float = 180000.0

# ── Helicopter limit (LIVE-tunable) ─────────────────────────────────────────
## The fastest the blade may TURN, in degrees per second. Above it, a brake torque
## drags the spin back to the cap — the "how much may it helicopter" knob. The
## slider's MAX is effectively no limit, so right = off, left = tightly caught.
const HELICOPTER_LIMIT_DEFAULT: float = 2000.0
const HELICOPTER_LIMIT_MIN: float = 100.0
const HELICOPTER_LIMIT_MAX: float = 2000.0
## Brake torque per radian/second of excess spin (clamped to the motor's max torque).
const HELICOPTER_BRAKE_TORQUE_PER_RAD: float = 40000.0

# ── Test Dummy ────────────────────────────────────────────────────────────────
const TEST_DUMMY_MAX_HEALTH: float = 100.0
const TEST_DUMMY_MIN_HEALTH: float = 1.0
const TEST_DUMMY_REGEN_AMOUNT: float = 10.0
const TEST_DUMMY_REGEN_INTERVAL: float = 1.0
const TEST_DUMMY_NAME: String = "TEST DUMMY"
const TEST_DUMMY_COLOR: Color = Color(0.38, 0.78, 0.55)
const TEST_DUMMY_HEALTH_COLOR: Color = Color(0.35, 0.95, 0.55)
const TEST_DUMMY_SPAWN_POSITION: Vector2 = Vector2(0.0, -170.0)

# ── Metronome (Blade Dancer's metronome arc, copied AS DATA) ─────────────────
## Blade Dancer's metronome for the player's LIVE hand: GP2, Metronome_Bind form,
## curved sword (shared hand 2:9 + its curved-sword override): arc 105,
## frequency 0.65 Hz, wind-up speeds 0.4 / 3.25 / 0.2. Read off the live save ONCE
## and copied here — PX must never read the game's save, only borrow its numbers.
##
## ARC IS A SINE AMPLITUDE, not a total sweep: the blade swings +/- this many
## degrees about the aim, so 105 is a 210-degree sweep end to end. Same
## convention as the game (player.gd:3349).
const METRONOME_ARC_DEGREES: float = 105.0
const METRONOME_FREQUENCY: float = 0.65
## Anti-windup leash. With the metronome ON the sweep may LEAD the blade by at
## most this many degrees. Free, the blade tracks the sine as before; blocked,
## the target parks just ahead of the blade so the motor pushes at a BOUNDED
## torque instead of the sine running on and dumping a huge stored error as a
## helicopter spin the moment contact breaks.
const METRONOME_MAX_LEAD_DEGREES: float = 45.0

# ── Aim feel ("Core Sword & Reach", copied AS DATA from the live GP2 Bind hand) ──
## The COMMANDED aim is what gets filtered here — never the blade. The aim POINT
## drags toward the cursor, then the aim ANGLE drags toward the aim point; both
## are just a target the motor still has to earn against real mass and contacts.
## So this is input shaping, exactly like the mouse and the metronome already are.
const AIM_INERTIA_ENABLED: bool = true
const DEFAULT_MOUSE_DRAG: float = 32.0        # aim-point inertia rate (higher = snappier)
const DEFAULT_ROTATION_SPEED: float = 10.5    # aim-angle response rate
const DEFAULT_MAX_TURN_SPEED_DEG: float = 1080.0   # 0 = unlimited

# ── Metronome wind-up ("Form II: Metronome Wind-up", copied AS DATA) ──
## The stroke's SPEED is redistributed: it opens slowly, accelerates through the
## strike, then recovers slowly, while the average stays the frequency slider's
## 0.65 Hz. Again only the target's motion — the blade still earns every degree.
## Same table as the live GP2 Bind hand: profile 1.0, fractions 0.3 / 0.2,
## speeds 0.4 (open) / 3.25 (strike) / 0.2 (recover).
const WINDUP_ENABLED: bool = true
const DEFAULT_WINDUP_PROFILE: float = 1.0
const WINDUP_FRACTION: float = 0.3
const RECOVERY_FRACTION: float = 0.2
const WINDUP_SPEED: float = 0.4
const STRIKE_SPEED: float = 3.25
const RECOVERY_SPEED: float = 0.2

# ── Late-stroke Action Commitment ("no-cancel", copied AS DATA) ──
## Inside a fraction [start, end) of each stroke the aim's authority over the swing
## is removed by `strength` (1 = fully no-cancel). Again target shaping only: it
## holds the swing's AIM, never the blade's pose, so the blade still earns every degree.
const ACTION_COMMITMENT_STRENGTH_DEFAULT: float = 0.0
const ACTION_COMMITMENT_START_DEFAULT: float = 0.60
const ACTION_COMMITMENT_END_DEFAULT: float = 0.90

# ── Authored Metronome (arc energy) & Apex Hang (copied AS DATA) ──
## Arc energy is the single authority for how wide the metronome opens: aim travel
## above the wake speed fills it, and once the idle grace passes with no movement it
## bleeds away, easing the blade back to simply pointing at your aim. Apex Hang is a
## short dwell at the top of each stroke. BOTH shape the TARGET only — the blade still
## earns every degree, so a block can still break the swing.
const ARC_ENERGY_ENABLED: bool = false
const ARC_WAKE_SPEED_DEFAULT: float = 350.0
const ARC_ENERGY_BUILD_DEFAULT: float = 0.8
const ARC_ENERGY_FADE_DEFAULT: float = 0.35
const ARC_IDLE_GRACE_DEFAULT: float = 2.0
const APEX_HANG_ENABLED: bool = false
const APEX_HANG_DURATION_DEFAULT: float = 0.14

# ── Reference-following servo ────────────────────────────────────────────────
## The rotation motor only knows the ANGLE it is chasing, so it always lags a
## moving target: it is always braking toward zero spin instead of matching the
## stroke's speed. Adding the reference's own angular velocity as a feed-forward
## term (kd * (omega_ref - omega)) lets the blade hold the intended arc and
## reverse cleanly. It is pure command shaping — the motor still earns every
## degree against real mass and contacts. OFF recovers the old plain PD motor.
const SERVO_FEEDFORWARD_ENABLED: bool = true

# ── The hilt constraint ──────────────────────────────────────────────────────
## The hilt is held to the hand point by a pin. Rigid (softness 0) the grip is
## welded to the hand; SOFT gives a finite, springy hold so a contact can shove
## the hilt off the hand and then it springs back — the "sword gives, then
## recovers" feel. This is a plain on/off toggle; the softness below is fixed.
const HILT_SPRING_ENABLED: bool = true
const HILT_SOFTNESS: float = 0.5

# ── Debug overlay ────────────────────────────────────────────────────────────
## The reference/ghost: an invisible copy of the ORIGINAL Blade Dancer target
## motion (where the hilt should be, which way the sword should point) drawn on
## top of the physical blade so you can see how closely the physics is tracking.
const SHOW_GHOST_ENABLED: bool = true
## How see-through the ghost is, in percent. The ghost is now the REAL sword art
## (same texture, scale and offset as the physical blade) drawn at the reference
## pose, so ~35% reads as a faint shadow twin of the blade. Tuned in, it hides
## UNDER the solid blade; any lag shows as a translucent offset.
const GHOST_OPACITY_PERCENT: float = 35.0