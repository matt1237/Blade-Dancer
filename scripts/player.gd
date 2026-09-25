class_name Player extends CharacterBody2D

signal combat_debug_event(event_type: String, details: Dictionary)
signal tutorial_action(event_type: String, target: Node)

# New values are appended so persisted integer IDs for every existing form remain stable.
enum SwordStyle { METRONOME, THRUST, MOULINET, MOULINET_2, MOULINET_3, MOULINET_4, THRUST_METRONOME, METRONOME_WINDUP, METRONOME_BIND, METRONOME_BIND_B }
enum AuthoredMetronomeState { INACTIVE, READY, ACTIVE, RETURNING, SHEATHED }
## The one ability a Charged Guard gesture can discharge into. NONE means the gesture
## layer is idle and the guard owns the pose; THRUST means the lunging thrust owns the
## pose instead (see the ordered override chain at _apply_charged_guard_gesture_pose).
enum ChargedGuardGesture { NONE, THRUST, WHIRLWIND }
const EXPERIMENTAL_BIND_STYLES: Array[int] = [SwordStyle.METRONOME_BIND, SwordStyle.METRONOME_BIND_B]
## Bind A (persisted ID 8) remains load-compatible but is retired from selection.
## Bind B's ID 9 is the one visible, canonical Bind Form.
## Public presentation order is intentionally independent from persisted enum IDs.
## Canonical Bind (ID 9) is Form I; the original Metronome (ID 0) now occupies
## Bind's former third public slot without moving either form's saved profile.
const STYLE_CYCLE_ORDER: Array[int] = [SwordStyle.METRONOME_BIND_B, SwordStyle.METRONOME_WINDUP, SwordStyle.METRONOME, SwordStyle.THRUST, SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3, SwordStyle.MOULINET_4, SwordStyle.THRUST_METRONOME]
const LEGACY_BIND_SLIDE_SETTING_KEYS: Array[String] = ["bind_slide_contact_tolerance", "bind_slide_angle", "bind_slide_cling", "bind_slide_friction", "bind_slide_speed", "bind_slide_duration"]
## Event types printed to the Godot console (gated by debug_print_sword_events)
## so bind/wind/beat/release activity can be read from a text log, not just a
## screenshot of the in-game HUD. SLIDE/PARRY/CLASH already have their own prints.
const BIND_LIFECYCLE_EVENT_TYPES: Array[String] = ["BIND CANDIDATE", "STABLE BIND", "WIND", "WEAPON BEAT", "BEAT REJECTED", "GUARD WRAP", "ROLLOVER DISENGAGE", "GUARD-WRAP RE-ENTRY", "ROLLOVER RE-ENTRY", "BIND RELEASE"]
const EXPERIMENTAL_BIND_SETTING_KEYS: Array[String] = ["bind_enabled", "bind_capture_time", "bind_contact_tolerance", "bind_pressure_min", "bind_retention_strength", "bind_sword_speed", "bind_release_grace", "bind_max_duration", "bind_rebind_cooldown", "bind_focus_time_scale", "bind_focus_zoom", "bind_focus_bias", "bind_focus_response", "bind_scrape_interval", "bind_disengage_min_time", "bind_disengage_min_travel", "bind_disengage_fraction_delta", "bind_disengage_endpoint", "bind_disengage_leverage", "bind_reentry_window", "bind_reentry_min_speed", "bind_reentry_inward_speed", "bind_reentry_damage", "bind_reentry_stagger", "bind_beat_pressure", "bind_beat_spike", "bind_beat_leverage", "bind_beat_stagger", "bind_beat_recoil", "bind_failed_beat_recoil", "bind_debug"]
const BIND_B_INTENDED_PROFILE: Dictionary = {
	"bind_b_authored_profile_version": 1,
	# Exact values recorded from the authored forgiving Hinge Bind session.
	"bind_enabled": 1.0, "bind_capture_time": 0.05, "bind_contact_tolerance": 24.0,
	"bind_retention_strength": 0.82, "bind_sword_speed": 0.18,
	"bind_release_grace": 0.22, "bind_max_duration": 2.60,
	"bind_slide_contact_tolerance": 24.0, "bind_slide_angle": 44.0,
	"bind_slide_cling": 1.60, "bind_slide_speed": 0.22,
	# These unchanged Preset-2 baselines are materialized locally so Bind B does
	# not inherit later Global Preset edits for entry friction/presentation.
	"bind_slide_friction": 0.45, "bind_slide_duration": 1.20
}
const CHAKRAM_SCENE: PackedScene = preload("res://scenes/chakram.tscn")
const MOON_SLASH_SCENE: PackedScene = preload("res://scenes/moon_slash.tscn")
const VOID_WELL_SCENE: PackedScene = preload("res://scenes/void_well.tscn")
const RESONANT_GLYPH_SCENE: PackedScene = preload("res://scenes/resonant_glyph.tscn")
const ICE_PATCH_SCRIPT: Script = preload("res://scripts/ice_patch.gd")
const METRONOME_VISUALIZER_SCRIPT: Script = preload("res://scripts/ui/metronome_visualizer.gd")
const BLADE_LENGTH: float = 84.0
const BLADE_HILT_INSET: float = 14.0
const CHARGED_GUARD_MIN_HAND_RADIUS: float = 18.0
## How long a detected player reversal gets a brief commitment response penalty.
## This is intentionally short: holding the mouse still never keeps the sword heavy.
const SWING_COMMITMENT_DURATION_DEFAULT: float = 0.16
const SWING_COMMITMENT_INPUT_THRESHOLD: float = 0.01
const CHARGED_GUARD_CANDIDATE_LATCH: float = 0.30
## One missed input sample may interrupt a deliberate pull; older evidence never survives.
const CHARGED_GUARD_INPUT_GRACE: float = 0.04
## How far the blade may drift from the shape it was banked in before the guard slips away. This
## is what "keep the drive steady" means in practice: the swing never stops pushing the blade, and
## only a continuing counter-drive holds it still.
const CHARGED_GUARD_POSITION_TOLERANCE_DEGREES: float = 35.0
## Top speed the locked hand repositions at once the guard is fully charged.
## Deliberately independent of the Guard Break Speed Threshold tuner: that slider
## answers "how hard is this guard to break", and tuning break difficulty must not
## also change how fast the hand repositions. 270 px/s times the 0.70
## slow-reposition scale reproduces the shipped feel.
const CHARGED_GUARD_REPOSITION_SPEED: float = 270.0
## Repositioning stays locked for the whole confirmation hold, so by the time the
## guard turns blue the hand has a full confirmation hold of frozen mouse movement
## to catch up on. Easing the reposition speed in over this window closes that gap
## smoothly instead of snapping the hand to wherever the cursor has since travelled.
const CHARGED_GUARD_REPOSITION_RAMP_TIME: float = 0.35
## Rate at which a locked guard's blade sweeps back to its safe angle when the
## metronome arc has carried it past the 90 degree limit. Applied as a limited-rate
## blend rather than a hard clamp so the sword never rotates tens of degrees in a
## single frame. Inside the safe cone this is a no-op, so it adds no lag.
const CHARGED_GUARD_BLADE_CONFORM_RATE: float = 8.0
## The blue charged state trails a continuous afterimage of the hand glow, the way
## Flow trails sprite ghosts: a fixed pool resampled on a timer, so the trail reads
## the same whether the hand is creeping or flicking.
const CHARGED_GUARD_AFTERIMAGE_COUNT: int = 5
const CHARGED_GUARD_AFTERIMAGE_INTERVAL: float = 0.05
## --- Charged Guard gestures -------------------------------------------------
## A gesture is a deliberately drawn cursor stroke that discharges the blue charged
## guard as a lunging thrust. Recognition is measured on the cursor's own SCREEN
## positions, which are the one part of the aim pipeline the camera cannot touch: the
## camera moves the world, never the pointer's place on the screen. A stroke drawn at
## the same speed therefore measures the same whatever the camera is doing, and the
## trail is drawn back through the live camera so it stays exactly where the player
## drew it.
##
## The bar is deliberately conservative, because the guard is easy to enter by
## accident: nothing a player does to reposition a held guard should ever lob them
## into a lunging attack. A stroke must be long, nearly straight, drawn inside the
## window, and brought to rest before it counts.
const CHARGED_GUARD_GESTURE_MIN_SPAN: float = 220.0
## Chord over path length: 1.0 is a perfect line, about 0.64 a semicircle, far lower a
## squiggle. Scale-free, so a bigger version of the same wiggle still fails.
const CHARGED_GUARD_GESTURE_STRAIGHTNESS: float = 0.85
## Longest a single stroke may take. A longer draw is abandoned rather than trimmed, so
## a slow drag can never be mistaken for a deliberate line.
const CHARGED_GUARD_GESTURE_WINDOW: float = 1.5
## Stillness that closes a stroke and lets it be read. This is the punctuation an
## authored stroke already ends on, and it is what keeps the gesture and the guard
## break from ever competing for the same motion.
const CHARGED_GUARD_GESTURE_SETTLE_TIME: float = 0.07
const CHARGED_GUARD_GESTURE_MOVE_EPSILON: float = 1.0
## Frame samples a single stroke may hold. The window is what really bounds this -- the
## longest window is the circle's three seconds, which at 60 Hz is 180 samples -- so this is
## headroom above that rather than a separate cap. It has to clear it: hitting the cap
## abandons the stroke, so a lower number would quietly kill exactly the slow, careful
## circles the circle window was widened to accept.
const CHARGED_GUARD_GESTURE_SAMPLE_LIMIT: int = 256
const CHARGED_GUARD_GESTURE_TRAIL_FADE: float = 0.32
const CHARGED_GUARD_GESTURE_FLASH_TIME: float = 0.30
## The trail is the feature's only feedback, so it is deliberately loud: a thick saturated
## blue ribbon, brightest at the cursor and fading back down the stroke, with sparks of the
## same shimmer falling off the drawing point. Sparks are a small fixed pool, each carrying
## its own remaining life, so they fade one at a time rather than all together.
const CHARGED_GUARD_GESTURE_TRAIL_WIDTH: float = 4.5
const CHARGED_GUARD_GESTURE_SPARK_INTERVAL: float = 0.035
const CHARGED_GUARD_GESTURE_SPARK_LIFE: float = 0.24
const CHARGED_GUARD_GESTURE_SPARK_POOL: int = 24
const CHARGED_GUARD_GESTURE_SPARK_BURST: int = 8
## The whirlwind's stroke is a circle rather than a line, so it is read by sweeping around
## the stroke's own centre of mass instead of by turning from segment to segment: wobble in a
## rough hand-drawn circle jitters the path, which barely moves the direction each point sits
## in as seen from the middle, so a loosely drawn revolution still measures a whole turn. The
## sign of that sweep is the direction the player drew, which is what decides which way the
## blade spins. Screen and world share the same y-down handedness and the camera never
## mirrors, so the sign carries over as-is.
## The bars are deliberately forgiving, because a circle is far harder to draw than a line and
## a generous shape must never be the reason the ability will not fire. The sweep floor is
## only 200 degrees: its job is to establish a direction and reject a scribble, not to prove
## the stroke closed. Closure proves that, and the two are an either/or -- a stroke that swept
## nearly the whole way around has already shown it came around, so the ends are only required
## to meet when the sweep fell short. An overshooting circle therefore still reads.
const CHARGED_GUARD_GESTURE_CIRCLE_MIN_SWEEP: float = 3.49
const CHARGED_GUARD_GESTURE_CIRCLE_CLOSURE_FREE_SWEEP: float = 5.236
const CHARGED_GUARD_GESTURE_CIRCLE_MIN_RADIUS: float = 40.0
const CHARGED_GUARD_GESTURE_CIRCLE_MAX_CLOSURE: float = 1.0
const CHARGED_GUARD_GESTURE_CIRCLE_MAX_RADIUS_SPREAD: float = 2.4
const CHARGED_GUARD_GESTURE_CIRCLE_MIN_SAMPLES: int = 8
## Circles get their own, much longer window than the line. A line is flicked in a third of a
## second; a circle drawn carefully -- as anyone who does not draw circles well will draw it
## -- takes two or three, and timing those out was the likeliest reason the ability would not
## fire at all in play.
const CHARGED_GUARD_GESTURE_CIRCLE_WINDOW: float = 3.0
## The lunging thrust the gesture discharges into. Deliberately unhurried: the wind-up
## turns the blade onto the drawn line, the drive throws it out, the hold reads at full
## reach, and the recovery settles back into ordinary metre. The body is thrown along
## the same line, so the thrust is a real committed attack rather than a pose.
const CHARGED_GUARD_THRUST_WINDUP: float = 0.08
const CHARGED_GUARD_THRUST_EXTEND: float = 0.13
const CHARGED_GUARD_THRUST_HOLD: float = 0.06
const CHARGED_GUARD_THRUST_RECOVER: float = 0.26
## Fraction of full reach the wind-up pulls the hand back before the drive.
const CHARGED_GUARD_THRUST_WINDUP_PULL: float = 0.30
## Extra hand travel at full reach, added to the live hand radius.
const CHARGED_GUARD_THRUST_REACH: float = 46.0
const CHARGED_GUARD_THRUST_LUNGE_SPEED: float = 600.0
const CHARGED_GUARD_THRUST_LUNGE_TIME: float = 0.16
## The whirlwind a drawn circle discharges into: the whole sword sweeps one full turn around
## the player -- the hilt orbiting the body at the distance the guard was already holding it,
## the blade pointing outward -- so the tip cuts a ring the whole way round and lands exactly
## back where it began. A short counter-orbit winds it up, and a settle then eases both the
## hilt and the blade into wherever the player's aim has got to by then. It moves nothing at
## all: the body is left entirely to the player, so walking, dashing and being knocked about
## mid-swing all behave exactly as they normally do.
const CHARGED_GUARD_WHIRLWIND_ANTICIPATION: float = 0.35
const CHARGED_GUARD_WHIRLWIND_WINDUP: float = 0.06
const CHARGED_GUARD_WHIRLWIND_SPIN: float = 0.34
const CHARGED_GUARD_WHIRLWIND_RECOVER: float = 0.20
## How far ahead of the outward radial the blade may lean. The lean is taken from the angle
## the blade is already holding at activation, so the first frame matches what was on screen,
## but it is capped so the blade always reads as pointing outward rather than sideways.
## 0.44 rad is 25 degrees.
const CHARGED_GUARD_WHIRLWIND_LEAD_MAX: float = 0.44
## Exits from a charged guard. A hard sideways flick breaks one, as it always has: it is the exit
## the player reaches for, and reading it as *lateral* speed -- motion across the aim rather than
## along it -- is what keeps a straight drawn stroke from ever looking like one. Running out of
## hold is the backstop, and discharging a gesture is the other deliberate way out.
## How far the flick's gearing may amplify a close-in flick. The cursor can sit nearer the body
## than the hand itself -- the hand stops at its minimum radius, the cursor does not -- so without
## a ceiling the divisor approaches zero and every movement would read as a break.
const CHARGED_GUARD_BREAK_GEARING_MAX: float = 4.0
## The hold limit's own bounds, so a slider can never be set to something that means "never",
## which would put the guard back in the state where nothing guarantees a way out of it.
const CHARGED_GUARD_HOLD_LIMIT_MIN: float = 1.0
const CHARGED_GUARD_HOLD_LIMIT_MAX: float = 15.0
## Every way out of a guard blocks a fresh one briefly. Without it, the stroke that cancelled the
## guard -- or simply still holding the shape it timed out on -- would satisfy the acquisition
## gate on the very next frame and hand the guard straight back.
const CHARGED_GUARD_REACQUIRE_BLOCK: float = 0.5
## The speed reference the charged hand's slow-reposition scaling compares against. It used to
## be the break-speed setting; it is a fixed reference now so the halting only depends on the
## sword, not on how the player has tuned the flick.
const CHARGED_GUARD_REPOSITION_SPEED_REFERENCE: float = 800.0
## Acquisition reads authored velocity against the visible blade's pommel axis, not cursor
## orbit. Only aligned, sufficiently fast motion inside the metronome turn window can bank
## travel and intent. A brief missed sample is tolerated; an abandoned pull is reset rather
## than slowly bleeding into unrelated movement. The candidate then has one short, hard
## deadline to hold its blade shape and lock.
## Acquisition diagnostics print at most this often, so a player counter-steering through a
## whole fight gets a readable trickle rather than a flood.
const CHARGED_GUARD_ACQUISITION_LOG_INTERVAL: float = 0.25
const AUTHORED_METRONOME_ACTIVITY_SPEED: float = 25.0
const AUTHORED_METRONOME_SHEATHE_FADE_RATE: float = 8.0
## Sword-trail visibility tracks arc energy while the metronome is in play, and stays
## exactly 1.0 -- today's look -- for every other sword style and whenever it is off.
const SWORD_TRAIL_MIN_VISIBILITY: float = 0.10
const SWORD_TRAIL_MAX_VISIBILITY: float = 1.15
const TEMPO_ASSIST_MAX_MULTIPLIER: float = 1.4
const TEMPO_ASSIST_INPUT_ENGAGEMENT_MIN: float = 0.08
const DIRECTIONAL_ARC_OPENING_DEGREES: float = 10.0
const STROKE_DRIVE_BUILD_PER_SECOND: float = 3.0
const STROKE_DRIVE_BUILD_PROGRESS_LIMIT: float = 0.60
const AUTHORED_STEP_DRIVE_THRESHOLD: float = 0.70
const SWORD_TEXTURE: Texture2D = preload("res://assets/Blade Dancer Sword.png")
const CURVED_SWORD_TEXTURE: Texture2D = preload("res://assets/generated/basic_curved_sword_frame_0.png")
const SWORD_FLAME_ATLAS: Texture2D = preload("res://assets/generated/hd_weapon_flame_symmetric_atlas.png")
const SWORD_FLAME_FRAME_SIZE: Vector2 = Vector2(192.0, 192.0)
const SWORD_FLAME_FRAME_COUNT: int = 6
const SWORD_FLAME_FPS: float = 12.0
const SWORD_FLAME_MAX_ALPHA: float = 0.7
const SWORD_FLAME_SPACING: float = 18.0
const SWORD_FLAME_HILT_INSET: float = 10.0
## Per-sword texture vertical orientation fix-up. This project's render
## convention expects hilt/crossguard near image-top, tip near image-bottom
## (matching Blade Dancer Sword.png). AI-generated weapon art does NOT
## reliably follow this -- verify any new weapon sprite with
## res://scripts/dev/weapon_orientation_check.gd BEFORE wiring it in. If it
## comes out inverted, set true here instead of hand-patching the PNG --
## this is the first thing to check the next time a new weapon looks like
## it's being held blade-first.
const SWORD_TEXTURE_FLIP_Y: Dictionary = {
	"Basic Longsword": false,
	"Basic Curved Sword": false, # corrected at the source PNG this round; new swords should prefer this flag instead.
}
## Per-sword hit geometry defaults. Each profile lists a hilt point (t=0.0),
## an optional interior control point, and a tip point (t=1.0), each with a
## perpendicular offset in pixels (positive = direction rotated +90 deg).
## _blade_polyline_samples() always builds a live 3-point hilt/mid/tip
## polyline from these defaults (or from a live override set via the Blade
## Shape tuning tab -- see get_blade_shape_setting()/blade_profile_settings),
## so a curved blade's reach reads correctly across its whole length. A
## straight profile (mid/tip offsets both 0) is still exactly collinear, so
## Basic Longsword's feel/hitbox is unchanged unless its sliders are touched.
const BLADE_PROFILES: Dictionary = {
	"Basic Longsword": [
		{"t": 0.0, "offset": 0.0},
		{"t": 1.0, "offset": 0.0},
	],
	"Basic Curved Sword": [
		{"t": 0.0, "offset": 0.0},
		{"t": 0.55, "offset": -10.0},
		{"t": 1.0, "offset": -24.0},
	],
}
## Edge orientation for every weapon profile. The opposite side is the spine.
## +1 preserves the current authored orientation; future weapons can override it
## without changing the shared rollover algorithm.
const BLADE_EDGE_SIDES: Dictionary = {
	"Basic Longsword": 1.0,
	"Basic Curved Sword": 1.0,
}
## Armor visual table: base item name -> idle/walk HD animation frames.
## "atlas" (with "walk_regions") slices frames out of one shared image, like
## Basic Leather Armor's original two-frame walk atlas; "walk_frames" lists
## separate whole-image textures, one per frame, like Basic Knight Armor.
const ARMOR_VISUALS: Dictionary = {
	"Basic Leather Armor": {
		"idle": "res://assets/generated/grim_pixel_knight_reference_pass_frame_0.png",
		"walk_atlas": "res://assets/generated/grim_pixel_knight_walk.png",
		"walk_regions": [Rect2(0.0, 0.0, 256.0, 256.0), Rect2(256.0, 0.0, 256.0, 256.0)],
	},
	"Basic Knight Armor": {
		"idle": "res://assets/generated/knight_armor_helm_idle_frame_0.png",
		"walk_frames": ["res://assets/generated/knight_armor_helm_walk_0_frame_0.png", "res://assets/generated/knight_armor_helm_walk_1_frame_0.png"],
	},
}
var hd_head_texture: Texture2D = null
const METAL_SCRAPE_AUDIO: AudioStream = preload("res://assets/audio/Grindstone/Metal Scraping Along Metal - Like The Sound Of Rubbbing Two Metal Knives Alon....mp3")
var hd_torso_texture: Texture2D = null
var hd_feet_texture: Texture2D = null
## Grip center measured from the new vertical sword+hand asset.
## Approximate grip and blade-tip pixels in the user-supplied sword canvas.
## These keep the visible hilt beside the player while the tip follows aim.
## Measured via farthest-point-pair + width scan: (465,846) is the sharp
## blade tip, (1075,356) is the grip center between the crossguard and pommel.
const BLADE_RADIUS: float = 16.0
const INPUT_MODE_KEYBOARD_MOUSE: String = "keyboard_mouse"
const INPUT_MODE_CONTROLLER: String = "controller"
const CONTROLLER_DASH_BUTTON = JOY_BUTTON_LEFT_SHOULDER
const CONTROLLER_CHAKRAM_BUTTON = JOY_BUTTON_RIGHT_SHOULDER
const CONTROLLER_STYLE_PREVIOUS_BUTTON = JOY_BUTTON_DPAD_LEFT
const CONTROLLER_STYLE_NEXT_BUTTON = JOY_BUTTON_DPAD_RIGHT

@export_category("Controller Input")
## Circular deadzone for both Xbox sticks.
@export_range(0.05, 0.8, 0.05) var controller_stick_deadzone: float = 0.22
## Device index is resolved from the first connected controller at runtime.
@export var preferred_controller_device: int = 0

@export_category("Player Movement")
## Top movement speed in pixels per second.
@export var move_speed: float = 250.0
## How quickly the player reaches move_speed from rest.
@export var movement_acceleration: float = 1150.0
## How quickly the player stops after releasing movement.
@export var movement_deceleration: float = 1450.0
## Extra braking when changing direction sharply.
@export var direction_change_deceleration: float = 2100.0
## Starting maximum health before bonuses and prepared food are applied.
@export var max_health: float = 100.0

@export_category("Body Pressure Slowdown")
## Movement multiplier while physically overlapping an enemy. 0.6 means 40% slower.
@export_range(0.1, 1.0, 0.05) var body_pressure_speed_multiplier: float = 0.5
## Center-to-center distance where shoulder pressure begins.
@export var body_pressure_contact_distance: float = 34.0

@export_category("Dash Speed and Cooldown")
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.1
@export var dash_cooldown: float = 3.0
@export var max_dash_charges: int = 1
## Duration of the Flash Step sketch/phase effect.
@export var flash_step_visual_duration: float = 0.28
## Number of speed-sketch lines between the old and new positions.
@export var flash_step_sketch_line_count: int = 6
## Length of each hand-drawn speed line.
@export var flash_step_sketch_line_length: float = 28.0

@export_category("Bash Dash")
## Radius around the actual dash path that counts as a body collision.
@export var bash_dash_contact_radius: float = 24.0

@export_category("HD Visual Profile")
## Strength of the small idle and movement breathing motion.
@export_range(0.0, 2.0, 0.05) var hd_breath_amount: float = 0.45
## Maximum body lean in degrees while moving.
@export var hd_move_lean_degrees: float = 15.0
## Extra squash/stretch applied during a normal dash.
@export_range(0.0, 0.3, 0.01) var hd_dash_squash: float = 0.10
## How much the HD body tilts back during hit recovery.
@export var hd_hit_recoil_degrees: float = 10.0

@export_category("Sword Speed and Damage")
## How quickly the whole sword follows the mouse direction. Higher is snappier.
@export var metronome_rotation_speed: float = 10.0
@export var thrust_rotation_speed: float = 10.0
@export var moulinet_rotation_speed: float = 10.0
## Metronome's total swing arc in degrees.
@export var metronome_arc_degrees: float = 100.0
## Metronome back-and-forth cycles per second.
@export var metronome_swing_frequency: float = 0.6
## Thrust style total arc — tight inverted piston angle.
@export var thrust_arc_degrees: float = 38.0
## Thrust cycles per second.
@export var thrust_swing_frequency: float = 0.45
## Moulinet loop spread in degrees.
@export var moulinet_arc_degrees: float = 75.0
## Moulinet twirl cycles per second.
@export var moulinet_swing_frequency: float = 0.85
## Dynamic bonus multiplier — the arc widens by this fraction at swing center.
@export var swing_phase_bonus: float = 0.12
## Contacts below this blade speed are treated as weak pushes rather than full swings.
@export var minimum_meaningful_swing_speed: float = 180.0
## Blade speed that counts as a full-power swing for damage and knockback scaling.
@export var full_swing_speed_reference: float = 1400.0
@export var sword_damage: float = 15.0
## Passive metronome contact remains useful, but is deliberately a weak baseline.
@export_range(0.1, 1.0, 0.05) var passive_sword_damage_multiplier: float = 0.30
## Maximum damage multiplier for a clearly authored sword phrase.
@export_range(1.0, 1.5, 0.05) var engaged_sword_damage_multiplier: float = 1.0
## Relative blade speed needed to reach the engaged damage ceiling.
@export var engaged_sword_speed_reference: float = 700.0
## Player-authored aim speed needed to fully engage sword damage; metronome motion is excluded.
@export var authored_engagement_speed_reference: float = 900.0
## How quickly authored engagement fades after the player stops conducting the blade.
@export var authored_engagement_memory: float = 0.45

@export_category("Boss Fire Sword")
## Seconds the sword remains ignited after crossing a boss campfire.
@export var sword_fire_duration: float = ZungarConfig.SWORD_FIRE_DURATION
## Extra damage is owned by the boss encounter and applied only to Zungar.
@export var sword_fire_bonus_damage: float = ZungarConfig.FIRE_BONUS_DAMAGE

@export_category("Sword Damage Contact Shape")
## Extra forgiveness around the visible blade when checking enemy contact.
## This is deliberately smaller than the old broad body-like radius.
@export var enemy_body_contact_radius: float = 18.0
## Fraction of the sword nearest the grip that counts as hilt/crossguard contact.
## 0.18 means the first 18% triggers Hilt Bash instead of cutting damage.
@export_range(0.05, 0.35, 0.01) var hilt_bash_blade_fraction: float = 0.18
## Maximum extra damage ratio awarded to fast, player-relative swings.
@export_range(0.0, 0.5, 0.05) var sword_speed_damage_bonus: float = 0.15
## Fraction of capped player movement speed allowed to influence hit power.
@export_range(0.0, 1.0, 0.05) var sword_movement_damage_contribution: float = 0.25
## Movement speed used for a modest lunge contribution; dash/grapple speed above this is ignored.
@export var sword_movement_speed_cap: float = 250.0

static func calculate_engaged_sword_damage_multiplier(relative_blade_speed: float, passive_multiplier: float, engaged_multiplier: float, speed_reference: float) -> float:
	var emphasis: float = clampf(maxf(0.0, relative_blade_speed) / maxf(1.0, speed_reference), 0.0, 1.0)
	return lerpf(clampf(passive_multiplier, 0.0, engaged_multiplier), maxf(passive_multiplier, engaged_multiplier), emphasis)

static func cutting_zone_damage_multiplier(whole_blade_fraction: float, cutting_zone_start: float, base_multiplier: float = 0.70, tip_multiplier: float = 1.15) -> float:
	var cutting_fraction: float = clampf(inverse_lerp(cutting_zone_start, 1.0, whole_blade_fraction), 0.0, 1.0)
	return lerpf(base_multiplier, tip_multiplier, cutting_fraction)

static func additive_sword_damage_multiplier(contact_multiplier: float, authored_multiplier: float, commitment_multiplier: float, position_multiplier: float, reentry_multiplier: float, minimum_multiplier: float = 0.20) -> float:
	var combined: float = 1.0
	for multiplier: float in [contact_multiplier, authored_multiplier, commitment_multiplier, position_multiplier, reentry_multiplier]:
		combined += multiplier - 1.0
	return maxf(minimum_multiplier, combined)

@export_category("Successful Sword Hit Feedback")
## Freeze duration for a weak flesh hit, in seconds.
@export var flesh_hitstop_min: float = 0.05
## Freeze duration for a full-quality flesh hit, in seconds.
@export var flesh_hitstop_max: float = 0.06
## Enemy interruption from a weak sword hit, in seconds.
@export var enemy_stagger_min: float = 0.12
## Enemy interruption from a full-quality sword hit, in seconds.
@export var enemy_stagger_max: float = 0.25
## Maximum number of degrees the sword kicks opposite its swing after impact.
@export var sword_hit_recoil_degrees: float = 6.0
## Degrees per second used to return the sword from hit recoil to its normal path.
@export var sword_hit_recoil_return_speed: float = 70.0
## Minimum seconds between wall-impact recoil kicks to prevent spam.
@export var wall_recoil_cooldown_duration: float = 0.3
## Impact quality required to trigger the large gold spark burst.
@export_range(0.0, 1.0, 0.05) var strong_hit_quality_threshold: float = 0.7
## Size multiplier for the gold spark burst on a strong hit.
@export var strong_hit_spark_intensity: float = 1.75

@export_category("Flesh Contact Feedback")
## Master switch for the added physical feel when the sword hits flesh.
@export var enable_flesh_hit_feedback: bool = true
## Extra hitstop range layered onto the existing sword-hit quality response.
@export var flesh_contact_hitstop_min: float = 0.1
@export var flesh_contact_hitstop_max: float = 0.13
## Tiny screen shake applied to successful flesh contacts.
@export var flesh_contact_screen_shake_strength: float = 1.1
@export var flesh_contact_screen_shake_duration: float = 0.1
## Body movement multiplier during the brief contact recovery.
@export_range(0.5, 1.0, 0.01) var flesh_contact_movement_multiplier: float = 0.8
@export var flesh_contact_movement_slow_duration: float = 0.8
## Small body recoil. This does not stun the player or slow sword abilities.
@export var flesh_contact_recoil_strength: float = 22.0

@export_category("Contact Drag (replaces the old Bite freeze)")
## Contact drag briefly slows the swing's phase-advance rate on impact, then
## recovers to full speed -- a "shhk, cutting through resistance" feel with
## no frozen angle, no stored offset, and no catch-up snap. See
## _trigger_contact_drag() and the sword_delta multiplier in _update_sword().
## How much the swing rate dips on a clean flesh hit (0.22 = 22% slower).
@export_range(0.0, 0.6, 0.01) var flesh_contact_drag_dip: float = 0.22
## Seconds for the dip to fully recover back to full swing speed.
@export var flesh_contact_drag_recovery: float = 0.08
## Hilt-bash contact drag: lighter than a flesh hit by default.
@export_range(0.0, 0.6, 0.01) var hilt_contact_drag_dip: float = 0.12
@export var hilt_contact_drag_recovery: float = 0.08
## Farmables (1-shot herbs/mushrooms/etc.) get only the faintest touch of
## drag -- they're plants, not flesh, so this stays small on purpose.
@export_range(0.0, 0.3, 0.01) var farmable_contact_drag_dip: float = 0.08
@export var farmable_contact_drag_recovery: float = 0.05
## Tiny hitstop so a farmable hit still registers as *something* landing,
## without the weight of a real flesh hit.
@export var farmable_hitstop: float = 0.02

@export_category("Sword Clashes and Parries")
## Hitstop for a normal sword-to-sword clash.
@export var clash_hit_stop: float = 0.085
## Hitstop for a successful enemy parry.
@export var parry_hit_stop: float = 0.15
## Hitstop when the sword bats a Chakram.
@export var chakram_bat_hit_stop: float = 0.03
@export var clash_recoil_strength: float = 230.0
@export var parry_recoil_strength: float = 340.0
## Extra pixel tolerance used when testing player sword against enemy weapons.
@export var parry_forgiveness: float = 20.0
## Seconds before the same overlapping weapons can produce another clash.
@export var clash_recovery_time: float = 0.7
@export var clash_flow_penalty: float = 0.0
## Time before the same enemy may receive another sword hit.
## Increasing this reduces repeated hits during one continuous swing.
@export var enemy_rehit_cooldown_duration: float = 0.3
## Universal blade-cling tuning lives in res://scripts/parry_rules.gd.

@export_category("Sword Batting Chakram")
## Contribution from sword swing direction when calculating the chakram's new direction.
@export var sword_to_chakram_weight: float = 0.8
## Contribution from the chakram's existing direction after being struck.
@export var inherited_chakram_weight: float = 0.2
@export var min_chakram_bat_speed: float = 450.0
@export var max_chakram_bat_speed: float = 700.0

@export_category("Player Hit Reaction")
@export var hit_stagger_time: float = 0.16
@export var hit_knockback_strength: float = 260.0
## Seconds after taking damage where additional damage and stagger are ignored.
@export var damage_immunity_duration: float = 0.45
## World-shake distance in pixels when taking a typical 10-damage hit.
@export var player_hit_screen_shake_strength: float = 5.0
## Duration of screen shake after the player takes damage.
@export var player_hit_screen_shake_duration: float = 0.15

@export_category("Combat Readability Aids")
## Shows the Metronome style's real swing range and current sword position.
@export var show_metronome_indicator: bool = true
## Radius of the curved Metronome base around the player.
@export var metronome_indicator_radius: float = 55.0
## Overall opacity for the complete visualizer. 0.65 means 35% transparent.
@export_range(0.0, 1.0, 0.05) var metronome_indicator_opacity: float = 0.65
## Opacity of the range arc before the overall visualizer opacity is applied.
@export_range(0.0, 1.0, 0.05) var metronome_indicator_arc_alpha: float = 0.42
## Seconds the reached side flashes whenever the sword reverses direction.
@export var metronome_reversal_pulse_duration: float = 0.18
## Shows a live aim guide while Chakram is held, then fades after throwing.
@export var show_chakram_aim_trail: bool = true
## Seconds the Chakram aim guide remains visible after throwing.
@export var chakram_aim_trail_duration: float = 0.35
## Maximum distance of the displayed Chakram aim trail.
@export var chakram_aim_trail_max_distance: float = 420.0
## Number of gold dots in the Chakram aim trail.
@export var chakram_aim_trail_dot_count: int = 12
## Radius of each gold aim dot.
@export var chakram_aim_trail_dot_radius: float = 2.0

@export_category("Debug Displays")
## Draws weapon-zone colors and the live swept collision geometry during development.
@export var debug_draw_sword_collision: bool = false
## Pommel share of the hilt-side weapon geometry for the zone audit.
@export_range(0.0, 0.2, 0.01) var debug_weapon_pommel_fraction: float = 0.10
## Pommel plus grip/guard share; the remaining geometry is the blade.
@export_range(0.1, 0.5, 0.01) var debug_weapon_grip_guard_end_fraction: float = 0.25
## Forte begins at the blade base and occupies the lower 40% of the blade.
@export_range(0.0, 1.0, 0.01) var forte_zone_start_fraction: float = 0.25
## Forte ends after 40% of the blade; the remaining blade is foible/point.
@export_range(0.0, 1.0, 0.01) var forte_zone_end_fraction: float = 0.55
## Forte contacts transfer 15% more knockback than foible contacts.
@export_range(1.0, 1.5, 0.05) var forte_knockback_multiplier: float = 1.15
## Health-damage scale across the blue cutting zone: blade base to visible tip.
@export_range(0.1, 1.0, 0.05) var cutting_zone_base_damage_multiplier: float = 0.70
@export_range(1.0, 1.5, 0.05) var cutting_zone_tip_damage_multiplier: float = 1.15
## Shows a live count above the player and prints every detected sword slide.
@export var debug_show_slide_counter: bool = true
## Shows the most recent sword interaction reason above the player.
@export var debug_show_sword_events: bool = true
## Prints PARRY/CLASH events to the Godot debugger output.
@export var debug_print_sword_events: bool = true

@export_category("Flow Visual Feedback")
## Number of recent player positions retained for the Flow trail.
@export var flow_trail_length: int = 12
## Flow percentage where yellow sparkle particles begin.
@export var flow_sparkle_threshold: float = 75.0
## Base opacity of the yellow movement trail at full Flow.
@export_range(0.0, 1.0, 0.05) var flow_trail_max_alpha: float = 0.7

var health: float = 100.0
var swing_time: float = 0.0
var sword_phase: float = 0.0
var visual_flow: float = 0.0
var p4_form_blend: float = 0.0

## RUNTIME TIMER NAMING
## Variables ending in `_left` store remaining seconds and count down to zero.
## They are live bookkeeping, not permanent tuning controls. Edit the matching
## exported `*_duration` or `*_cooldown` value above instead.

var aim_angle: float = 0.0
var virtual_aim_point: Vector2 = Vector2.ZERO
var previous_virtual_aim_point: Vector2 = Vector2.ZERO
var has_virtual_aim_sample: bool = false
var player_aim_turn_sign: float = 0.0
var authored_angular_travel_radians: float = 0.0
var authored_virtual_aim_velocity: Vector2 = Vector2.ZERO
var charged_guard_authored_aim_velocity: Vector2 = Vector2.ZERO
var charged_guard_authored_angular_travel: float = 0.0
var charged_guard_aim_turn_sign: float = 0.0
var charged_guard_mouse_motion_delta: Vector2 = Vector2.ZERO
var charged_guard_previous_control_target: Vector2 = Vector2.ZERO
var charged_guard_previous_control_mode: String = ""
var charged_guard_has_control_sample: bool = false
var authored_metronome_state: AuthoredMetronomeState = AuthoredMetronomeState.INACTIVE
var authored_metronome_active_idle_time: float = 0.0
var authored_metronome_ready_idle_time: float = 0.0
## Sole authority for how wide the metronome arc is: 0.0 points the blade
## straight at the mouse, 1.0 is the full metronome arc.
var authored_metronome_energy: float = 0.0
var authored_metronome_swing_blend: float = 1.0
var authored_metronome_sheathe_alpha: float = 1.0
var authored_sword_engagement: float = 0.0
var swing_commitment_left: float = 0.0
var swing_commitment_direction: float = 0.0
var windup_forward_step_fired: bool = false
var windup_backstep_fired: bool = false
var training_menu_input_locked: bool = false
var input_mode: String = INPUT_MODE_KEYBOARD_MOUSE
var mobile_input_enabled: bool = false
var mobile_move_input: Vector2 = Vector2.ZERO
var mobile_aim_direction: Vector2 = Vector2.UP
var mobile_recent_move_direction: Vector2 = Vector2.UP
var mobile_chakram_aim_direction: Vector2 = Vector2.ZERO
var mobile_grapple_aim_direction: Vector2 = Vector2.ZERO
var mobile_dash_held: bool = false
var mobile_chakram_held: bool = false
var mobile_grapple_held: bool = false
var mobile_grapple_was_down: bool = false
var mobile_grapple_aiming: bool = false
var controller_aim_direction: Vector2 = Vector2.RIGHT
var controller_aim_strength: float = 1.0
var metronome_reversal_flash_left: float = 0.0
var metronome_reversal_side: float = 0.0
var tempo_assist_multiplier: float = 1.0
var authored_stroke_drive: float = 0.0
var directional_arc_extension_degrees: float = 0.0
var authored_apex_hang_left: float = 0.0
var authored_apex_hang_armed_drive: float = 0.0
var charged_guard_charge: float = 0.0
var charged_guard_locked: bool = false
var charged_guard_candidate_active: bool = false
## The blade angle the guard was banked at. The metronome keeps swinging the blade while the guard
## is charged, so holding this shape is the same thing as holding the drive.
var charged_guard_candidate_angle: float = 0.0
var charged_guard_pommel_travel: float = 0.0
var charged_guard_pommel_time: float = 0.0
var charged_guard_input_gap: float = 0.0
var charged_guard_candidate_latch_left: float = 0.0
## Blue time banked toward the hold limit.
var charged_guard_hold_time: float = 0.0
var charged_guard_acquisition_log_cooldown: float = 0.0
var charged_guard_reacquire_block_left: float = 0.0
var charged_guard_recent_motion_left: float = 0.0
var charged_guard_awaken_charge: float = 0.0
var charged_guard_fully_charged: bool = false
var charged_guard_reposition_ramp: float = 0.0
var charged_guard_afterimages: Array[Vector2] = []
var charged_guard_afterimage_timer: float = 0.0
var charged_guard_lock_angle: float = 0.0
var charged_guard_initial_lock_angle: float = 0.0
var charged_guard_initial_hand_offset: Vector2 = Vector2.ZERO
var charged_guard_flash_left: float = 0.0
var charged_guard_lock_hand_offset: Vector2 = Vector2.ZERO
var charged_guard_lock_radius: float = 0.0
var charged_guard_radial_direction: Vector2 = Vector2.RIGHT
## The cursor's own motion this frame, in world units but converted with the camera's basis
## only. This is the charged guard's sole positional input: the camera leads, lags and clamps
## relative to the player, so the cursor's *world point* slides as the player walks and
## following it let player movement steer the guard.
var charged_guard_cursor_motion: Vector2 = Vector2.ZERO
var charged_guard_movement_suppression_left: float = 0.0
## The cursor's screen position this frame, captured once per frame so recognition never
## depends on when it is asked, and so the drawn path can be replayed through the live
## camera. This is the gesture layer's sole input.
var charged_guard_gesture_cursor: Vector2 = Vector2.ZERO
## Screen-space points of the stroke being drawn. Screen space is the reason no camera
## motion can draw, bend, extend or rotate a gesture.
var charged_guard_gesture_path: PackedVector2Array = PackedVector2Array()
var charged_guard_gesture_stroke_time: float = 0.0
var charged_guard_gesture_still: float = 0.0
var charged_guard_gesture_active: bool = false
## A stroke is spent once it has been read, or once it overran the window: either way it
## can never qualify, and only fresh movement starts a new one.
var charged_guard_gesture_spent: bool = false
var charged_guard_gesture_has_cursor: bool = false
var charged_guard_gesture_previous_cursor: Vector2 = Vector2.ZERO
var charged_guard_gesture_trail_left: float = 0.0
var charged_guard_gesture_flash_left: float = 0.0
## Sparks are the shimmer falling off the drawing point: screen-space positions, each
## carrying its own remaining life in z, so they fade individually instead of in lockstep.
var charged_guard_gesture_sparks: Array[Vector3] = []
var charged_guard_gesture_spark_timer: float = 0.0
var charged_guard_gesture_state: ChargedGuardGesture = ChargedGuardGesture.NONE
var charged_guard_gesture_phase_time: float = 0.0
var charged_guard_gesture_direction: Vector2 = Vector2.RIGHT
## Captured at activation so the thrust extends from the reach the player was actually
## holding, instead of breathing with the cursor during the sequence.
var charged_guard_gesture_hand_radius: float = 0.0
## The whirlwind sweeps the whole sword one turn around the player. All of it is captured at
## activation -- which way the circle was drawn, the hilt's own angle out from the body, and
## how far out it was being held -- so the sweep is a fixed shape that begins and ends exactly
## where the guard was holding the blade, rather than chasing the cursor around with it. The
## hilt's offset is kept whole rather than just its length, so the radius and the starting
## angle both come out of the one value and cannot drift apart.
var charged_guard_gesture_spin_sign: float = 1.0
var charged_guard_gesture_orbit_angle: float = 0.0
var charged_guard_gesture_spin_lead: float = 0.0
var charged_guard_gesture_hand_offset: Vector2 = Vector2.ZERO
var charged_guard_gesture_lunge_armed: bool = false
var charged_guard_gesture_lunge_left: float = 0.0
var sword_fire_left: float = 0.0
var chakram_aim_trail_left: float = 0.0
var chakram_aim_trail_start: Vector2 = Vector2.ZERO
var chakram_aim_trail_end: Vector2 = Vector2.ZERO
var sword_hit_recoil_offset: float = 0.0
var wall_recoil_cooldown: float = 0.0
var sword_slide_count: int = 0
var experimental_bind_count: int = 0
var experimental_wind_count: int = 0
var experimental_beat_count: int = 0
var experimental_rejected_beat_count: int = 0
## New players begin in the canonical public Form I. Persisted IDs stay stable:
## Bind is ID 9 even though it is presented first.
var sword_style: SwordStyle = SwordStyle.METRONOME_BIND_B
## "classic" = original procedural vector knight. "hd" = generated HD sprite body.
## Sword/chakram visuals also branch on this. Toggle from Home > Options.
var visual_style: String = "classic"
var metronome_visualizer: MetronomeVisualizer = null
var metronome_visualizer_counts: int = 2
var metronome_visualizer_beat_percent: float = 50.0
var metronome_visualizer_palette: String = "gold"
var slide_audio_player: AudioStreamPlayer = null
var slide_audio_left: float = 0.0
var hd_head_sprite: Sprite2D = null
var hd_torso_sprite: Sprite2D = null
var hd_feet_sprite: Sprite2D = null
var flow_fx: PlayerFlowFX = null
## Which gear base item is currently equipped, driving visible weapon art
## and the hit-capsule widening table above. Set by main.gd at run start
## from HomeProgression.equipped_gear_item(); armory_config.gd owns the
## list of valid base names.
var equipped_sword_id: String = "Basic Longsword"
var equipped_armor_id: String = "Basic Leather Armor"
var hd_part_time: float = 0.0
## Elbow joint angle — trails aim_angle at elbow_joint_speed, forming the second
## joint of the Elbow stance's two-joint arm (shoulder -> elbow -> sword).
var elbow_angle: float = 0.0
var dash_left: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var dash_charges: int = 1
var style_previous_was_down: bool = false
var style_next_was_down: bool = false
var dash_key_was_down: bool = false
var bash_dash_hit_ids: Dictionary[int, bool] = {}
var chakram_key_was_down: bool = false
var transition_facing_direction: float = 0.0
var invulnerable: float = 0.0
var hit_ids: Dictionary[int, bool] = {}
var enemy_rehit_cooldowns: Dictionary[int, float] = {}
var chakram: Chakram = null
var active_chakrams: Array[Chakram] = []
var previous_blade_start: Vector2 = Vector2.ZERO
var previous_blade_end: Vector2 = Vector2.ZERO
## Per-frame blade polyline (hilt..tip control points) for the equipped
## sword's BLADE_PROFILES shape. First/last sample always equal
## previous_blade_start/previous_blade_end exactly, so every existing reader
## of those two fields (trails, lighting, Flow FX, wall recoil) is unaffected.
var current_blade_samples: PackedVector2Array = PackedVector2Array()
var previous_blade_samples: PackedVector2Array = PackedVector2Array()
var blade_velocity: Vector2 = Vector2.ZERO
var blade_trail_points: Array[Vector2] = []
var hilt_trail_points: Array[Vector2] = []
var moulinet_aim_direction_sign: float = 1.0
var moulinet_aim_direction_smoothed: float = 1.0
var moulinet_continuous_angle: float = 0.0
var clash_recovery_left: float = 0.0
## Current swing phase-advance multiplier (1.0 = full speed). Dips toward 0
## on contact via _trigger_contact_drag(), then recovers back to 1.0 over
## contact_drag_recovery_rate units/sec. Replaces the old freeze-based Bite.
var contact_drag_multiplier: float = 1.0
var contact_drag_recovery_rate: float = 0.0
var flesh_contact_slow_left: float = 0.0
var sword_event_label: String = ""
var sword_event_point: Vector2 = Vector2.ZERO
var sword_event_left: float = 0.0
var blade_contact_flash_left: float = 0.0
var slide_cling_left: float = 0.0
var combat_contact_preset: int = 2
var combat_hand_settings: Dictionary = CombatSettingsConfig.built_in_hand_settings()
var combat_contact_settings: Dictionary = CombatSettingsConfig.built_in_contact_settings()
## Optional per-weapon hand tuning overrides. Keys are sword IDs, then preset:style keys.
## Missing values fall back to the shared preset/style settings above.
var combat_weapon_hand_settings: Dictionary = {}
## Per-sword-type blade shape tuning, keyed by sword base name (e.g. "Basic
## Curved Sword"). Each entry is {"mid_t":float,"mid_offset":float,"tip_offset":float}.
## Independent of combat_contact_preset -- one shape per sword, not per preset.
## See get_blade_shape_setting()/set_blade_shape_setting() and the Blade Shape
## tab in Training Tools > Combat Presets.
var blade_profile_settings: Dictionary = CombatSettingsConfig.built_in_blade_settings()
## Blade "roll": fakes the wrist rotation that keeps every weapon's edge
## leading its actual travel direction. The target is selected from measured
## blade motion, not only from the autonomous phase, so an early player-forced
## reversal cannot leave an asymmetric weapon cutting with its spine for a full
## metronome cycle. blade_roll is shared by the rendered texture and hit
## polyline, and smoothly passes through edge-on while the orientation changes.
var blade_roll: float = 1.0
var blade_roll_target: float = 1.0
var blade_travel_sign: float = 1.0
var blade_travel_sign_candidate: float = 0.0
var blade_travel_sign_candidate_left: float = 0.0
var combat_hand_radius: float = 30.0
var preset_2_slide_visual_left: float = 0.0
var preset_2_slide_distance_on_blade: float = 40.0
var preset_2_slide_contact_point: Vector2 = Vector2.ZERO
var preset_2_slide_opponent: Enemy = null

# --- Form III Experimental Bind State ---
# A candidate begins only from a real blade slide. Stable contact then earns a
# temporary bind; mouse wiggles cannot create this state without weapon geometry.
var experimental_bind_opponent: Enemy = null
var experimental_bind_candidate: bool = false
var experimental_bind_active: bool = false
var experimental_bind_contact_seen: bool = false
var experimental_bind_stable_time: float = 0.0
var experimental_bind_elapsed: float = 0.0
var experimental_bind_missing_time: float = 0.0
var experimental_bind_cooldown_left: float = 0.0
var experimental_bind_contact_point: Vector2 = Vector2.ZERO
var experimental_bind_pressure: float = 0.0
var experimental_bind_previous_pressure: float = 0.0
var experimental_bind_player_pressure: float = 0.0
var experimental_bind_previous_player_pressure: float = 0.0
var experimental_bind_tangent_speed: float = 0.0
var experimental_bind_tangent_travel: float = 0.0
var experimental_bind_leverage: float = 0.0
var experimental_bind_start_enemy_fraction: float = 0.5
var experimental_bind_enemy_fraction: float = 0.5
var experimental_bind_total_contact_time: float = 0.0
var experimental_bind_start_roll: float = 1.0
var experimental_bind_roll_crossed: bool = false
var experimental_bind_beat_consumed: bool = false
# The first validated slide owns one opponent and one side of the blade plane.
# This lets an active bind resist crossing like two hinged doors without making
# every nearby weapon globally solid or allowing several enemies to pin us.
var experimental_bind_hinge_side: float = 1.0
var experimental_bind_last_enemy_direction: Vector2 = Vector2.RIGHT
var experimental_bind_release_reason: String = ""
var experimental_bind_outcome: String = ""
var experimental_bind_wind_reported: bool = false
var experimental_reentry_opponent: Enemy = null
var experimental_reentry_time_left: float = 0.0
var experimental_reentry_total_window: float = 0.0
var experimental_reentry_release_point: Vector2 = Vector2.ZERO
var experimental_reentry_inward_direction: Vector2 = Vector2.RIGHT
var experimental_reentry_leverage: float = 0.0
var experimental_reentry_was_rollover: bool = false
var contact_spark_left: float = 0.0
var contact_spark_point: Vector2 = Vector2.ZERO
var contact_spark_count: int = 0
var contact_spark_color: Color = Color.WHITE
var contact_spark_direction: Vector2 = Vector2.RIGHT
var flow_trail_points: Array[Vector2] = []

# --- Kinetic Strike & Rebound State ---
## blade_freeze_left/frozen_blade_world_angle now serve clash/parry only --
## flesh and hilt contact use contact_drag_multiplier instead (no freeze).
var blade_freeze_left: float = 0.0
var frozen_blade_world_angle: float = 0.0
var grip_authority_left: float = 0.0
var rebound_flow_sign: float = 0.0
var hit_stagger_left: float = 0.0
var hit_knockback: Vector2 = Vector2.ZERO
var flow: float = 0.0
var flow_idle_time: float = 0.0
var health_bonus_rank: int = 0
var chakram_charge_rank: int = 0
var dash_bonus_rank: int = 0
var bash_dash_rank: int = 0
var frost_nova_rank: int = 0
var regeneration_rank: int = 0
var voltage_rank: int = 0
var flash_step_rank: int = 0
var chakram_charges: int = 1
var max_chakram_charges: int = 1
var chakram_pierce: int = 0
var chakram_explosion_level: int = 0
var frost_nova_enabled: bool = false
var frost_nova_flash: float = 0.0
var frost_nova_cooldown_left: float = 0.0
var regeneration_enabled: bool = false
var magnetic_level: int = 0
var defense_rank: int = 0
var voltage_enabled: bool = false
var burning_rank: int = 0
var moon_slash_rank: int = 0
var swing_count: int = 0
var flash_step_enabled: bool = false
var disarm_rank: int = 0
var void_dash_level: int = 0
var chain_lightning_level: int = 0
var vampirism_rank: int = 0
var adrenaline_rank: int = 0
var grapple_mastery_rank: int = 0
var resonant_glyph_rank: int = 0
var resonant_glyph_spawn_left: float = 0.0
var grapple_charges: int = 1
var grapple_max_charges: int = 1
var grapple_cooldown_left: float = 0.0
const GRAPPLE_BASE_COOLDOWN: float = 5.0
const FROST_NOVA_PATCH_DURATION: float = 5.0
## Temporary expedition preparation, separate from Rank bonuses so neither overwrites the other.
var expedition_food_health_bonus: float = 0.0
var expedition_food_regeneration: float = 0.0
var chain_lightning_timer: float = 0.0
var chain_lightning_flash: float = 0.0
var flash_step_flash: float = 0.0
var flash_step_origin: Vector2 = Vector2.ZERO
var flash_step_destination: Vector2 = Vector2.ZERO
var deflect_rank: int = 0
var deflect_charges: int = 0
var deflect_recharge_left: float = 0.0
var terrain_movement_modifiers: Dictionary[int, float] = {}
var ice_slide_modifiers: Dictionary[int, float] = {}
var terrain_dash_block_sources: Dictionary[int, bool] = {}
var terrain_root_left: float = 0.0

@onready var dash_timer: Timer = $DashCooldownTimer
@onready var health_bar: ProgressBar = $HealthBar
@onready var knight_sprite_hd: AnimatedSprite2D = $KnightSpriteHD
@onready var grapple_controller: GrappleController = $GrappleController

func _create_hd_part_sprites() -> void:
	hd_head_sprite = Sprite2D.new()
	hd_head_sprite.name = "HDHeadPart"
	hd_head_sprite.texture = hd_head_texture
	hd_head_sprite.position = Vector2(0.0, -28.0)
	hd_head_sprite.scale = Vector2(0.235, 0.235)
	hd_head_sprite.visible = false
	hd_head_sprite.z_index = 2
	add_child(hd_head_sprite)
	hd_torso_sprite = Sprite2D.new()
	hd_torso_sprite.name = "HDTorsoPart"
	hd_torso_sprite.texture = hd_torso_texture
	hd_torso_sprite.position = Vector2(0.0, 0.0)
	hd_torso_sprite.scale = Vector2(0.240, 0.240)
	hd_torso_sprite.visible = false
	hd_torso_sprite.z_index = 1
	add_child(hd_torso_sprite)
	hd_feet_sprite = Sprite2D.new()
	hd_feet_sprite.name = "HDFeeetPart"
	hd_feet_sprite.texture = hd_feet_texture
	hd_feet_sprite.position = Vector2(0.0, 22.0)
	hd_feet_sprite.scale = Vector2(0.250, 0.250)
	hd_feet_sprite.visible = false
	hd_feet_sprite.z_index = 0
	add_child(hd_feet_sprite)

signal health_changed(current: float, maximum: float)
signal style_changed(style_name: String)
signal player_died()
signal flow_changed(current: float, maximum: float)

func _ready() -> void:
	z_as_relative = false
	z_index = 2
	health = max_health
	_synchronize_rank_zero_bonus_state()
	virtual_aim_point = get_global_mouse_position()
	aim_angle = global_position.direction_to(virtual_aim_point).angle()
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false
	_setup_slide_audio_player()
	metronome_visualizer = METRONOME_VISUALIZER_SCRIPT.new() as MetronomeVisualizer
	metronome_visualizer.name = "MetronomeVisualizer"
	metronome_visualizer.position = Vector2(0.0, 24.0)
	add_child(metronome_visualizer)
	metronome_visualizer.configure(self, metronome_visualizer_beat_percent, metronome_visualizer_palette, metronome_visualizer_counts)
	_load_saved_combat_settings()
	grapple_controller.setup(self)
	flow_fx = PlayerFlowFX.new()
	flow_fx.name = "PlayerFlowFX"
	add_child(flow_fx)
	flow_fx.setup(self)
	_apply_armor_visual()
	queue_redraw()

func _load_saved_combat_settings() -> void:
	var saved: Dictionary = CombatSettingsConfig.load_all()
	if not saved.is_empty():
		if saved.has("active_preset"):
			combat_contact_preset = clampi(int(saved["active_preset"]), 1, 4)
		if saved.has("hand_settings") and saved["hand_settings"] is Dictionary:
			combat_hand_settings = (saved["hand_settings"] as Dictionary).duplicate(true)
		if saved.has("contact_settings") and saved["contact_settings"] is Dictionary:
			combat_contact_settings = (saved["contact_settings"] as Dictionary).duplicate(true)
		if saved.has("weapon_hand_settings") and saved["weapon_hand_settings"] is Dictionary:
			combat_weapon_hand_settings = (saved["weapon_hand_settings"] as Dictionary).duplicate(true)
		# Older saves predate Blade Shape tuning -- absence just means "keep
		# BLADE_PROFILES hardcoded defaults," never an error.
		if saved.has("blade_settings") and saved["blade_settings"] is Dictionary:
			blade_profile_settings = (saved["blade_settings"] as Dictionary).duplicate(true)
	var initialized_form_three: bool = ensure_experimental_form_initialized()
	if initialized_form_three:
		CombatSettingsConfig.save_all(combat_contact_preset, combat_hand_settings, combat_contact_settings, blade_profile_settings, combat_weapon_hand_settings)

## Consolidates the former Bind A/B laboratory into one shared Bind Form profile.
## Persisted IDs remain valid, but both legacy ID 8 and canonical ID 9 resolve the
## same ID-9 settings. The Curved Sword's tuned Bind-B profile is promoted first
## when importing an old save; per-weapon Bind fields are then removed so there is
## only one authority. Legacy bind_slide_* fields remain inert for file safety.
func ensure_experimental_form_initialized() -> bool:
	var changed: bool = false
	var bind_a_id: int = int(SwordStyle.METRONOME_BIND)
	var bind_id: int = int(SwordStyle.METRONOME_BIND_B)
	for preset: int in range(1, 5):
		var bind_a_key: String = "%d:%d" % [preset, bind_a_id]
		var bind_key: String = "%d:%d" % [preset, bind_id]
		var shared_bind: Dictionary = combat_hand_settings.get(bind_key, {}) as Dictionary
		if shared_bind.is_empty():
			var form_two_key: String = "%d:%d" % [preset, int(SwordStyle.METRONOME_WINDUP)]
			shared_bind = (combat_hand_settings.get(form_two_key, {}) as Dictionary).duplicate(true)
			changed = true
		var promoted: Dictionary = {}
		for preferred_sword: String in ["Basic Curved Sword", "Basic Longsword"]:
			var preferred_overrides: Dictionary = combat_weapon_hand_settings.get(preferred_sword, {}) as Dictionary
			var preferred_bind: Dictionary = preferred_overrides.get(bind_key, {}) as Dictionary
			if not preferred_bind.is_empty():
				promoted = preferred_bind
				break
		if promoted.is_empty():
			promoted = shared_bind
		if promoted.is_empty():
			var legacy_shared: Dictionary = combat_hand_settings.get(bind_a_key, {}) as Dictionary
			var fallback_form_two_key: String = "%d:%d" % [preset, int(SwordStyle.METRONOME_WINDUP)]
			var form_two_shared: Dictionary = combat_hand_settings.get(fallback_form_two_key, {}) as Dictionary
			promoted = legacy_shared.duplicate(true) if not legacy_shared.is_empty() else form_two_shared.duplicate(true)
			promoted.merge(BIND_B_INTENDED_PROFILE, true)
		for setting: String in EXPERIMENTAL_BIND_SETTING_KEYS:
			if promoted.has(setting) and shared_bind.get(setting, null) != promoted[setting]:
				shared_bind[setting] = promoted[setting]
				changed = true
		for legacy_slide: String in LEGACY_BIND_SLIDE_SETTING_KEYS:
			if shared_bind.erase(legacy_slide):
				changed = true
		combat_hand_settings[bind_key] = shared_bind
		var retired_bind: Dictionary = combat_hand_settings.get(bind_a_key, {}) as Dictionary
		for setting: String in EXPERIMENTAL_BIND_SETTING_KEYS:
			if retired_bind.erase(setting):
				changed = true
		for legacy_slide: String in LEGACY_BIND_SLIDE_SETTING_KEYS:
			if retired_bind.erase(legacy_slide):
				changed = true
		if not retired_bind.is_empty():
			combat_hand_settings[bind_a_key] = retired_bind
	for raw_sword_id: Variant in combat_weapon_hand_settings.keys():
		var sword_id: String = str(raw_sword_id)
		var weapon_values: Dictionary = combat_weapon_hand_settings.get(sword_id, {}) as Dictionary
		for preset: int in range(1, 5):
			for style_id: int in [bind_a_id, bind_id]:
				var key: String = "%d:%d" % [preset, style_id]
				var values: Dictionary = weapon_values.get(key, {}) as Dictionary
				for setting: String in EXPERIMENTAL_BIND_SETTING_KEYS:
					if values.erase(setting):
						changed = true
				for legacy_slide: String in LEGACY_BIND_SLIDE_SETTING_KEYS:
					if values.erase(legacy_slide):
						changed = true
				if not values.is_empty():
					weapon_values[key] = values
		combat_weapon_hand_settings[sword_id] = weapon_values
	return changed


func _synchronize_rank_zero_bonus_state() -> void:
	# Boolean compatibility flags are derived from ranks so stale state can never
	# leave an ability active after its rank returns to zero.
	frost_nova_enabled = frost_nova_rank > 0
	regeneration_enabled = regeneration_rank > 0
	voltage_enabled = voltage_rank > 0
	flash_step_enabled = flash_step_rank > 0
	var maximum_deflect_charges: int = BonusConfig.deflect_max_charges(deflect_rank)
	deflect_charges = clampi(deflect_charges, 0, maximum_deflect_charges)
	if deflect_rank <= 0: deflect_recharge_left = 0.0

func can_deflect_projectile() -> bool:
	return deflect_rank > 0 and deflect_charges > 0

func set_training_menu_input_locked(locked: bool) -> void:
	training_menu_input_locked = locked
	if locked:
		dash_left = 0.0
		velocity = Vector2.ZERO
	else:
		virtual_aim_point = get_global_mouse_position()
	# Mirror the physical state so closing while a control is still held cannot fire it.
	dash_key_was_down = _controller_button_pressed(CONTROLLER_DASH_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_SPACE)
	chakram_key_was_down = _controller_button_pressed(CONTROLLER_CHAKRAM_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	style_previous_was_down = _controller_button_pressed(CONTROLLER_STYLE_PREVIOUS_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_Z)
	style_next_was_down = _controller_button_pressed(CONTROLLER_STYLE_NEXT_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_X)
	if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())

func _grapple_button_pressed() -> bool:
	# RMB remains valid even if a controller profile was previously selected.
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func reset_resonant_glyph_timer() -> void:
	resonant_glyph_spawn_left = BonusConfig.resonant_glyph_cooldown(resonant_glyph_rank)

func start_resonant_glyph_wave() -> void:
	if resonant_glyph_rank <= 0:
		return
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and current_scene.has_method("try_spawn_resonant_glyph"):
		current_scene.call("try_spawn_resonant_glyph", resonant_glyph_rank)
	resonant_glyph_spawn_left = BonusConfig.resonant_glyph_cooldown(resonant_glyph_rank)

func set_mobile_controls_enabled(enabled: bool) -> void:
	mobile_input_enabled = enabled
	if enabled:
		return
	mobile_move_input = Vector2.ZERO
	mobile_dash_held = false
	mobile_chakram_held = false
	mobile_grapple_held = false
	mobile_grapple_was_down = false
	mobile_grapple_aiming = false
	dash_key_was_down = false
	chakram_key_was_down = false
	if grapple_controller != null and (grapple_controller.active or grapple_controller.firing):
		grapple_controller.release_tether()

func set_mobile_move_input(value: Vector2) -> void:
	mobile_move_input = value.limit_length(1.0)
	if mobile_move_input.length_squared() > 0.01: mobile_recent_move_direction = mobile_move_input.normalized()

func set_mobile_aim_direction(value: Vector2) -> void:
	mobile_aim_direction = value.limit_length(1.0)

func set_mobile_ability_aim(ability: String, direction: Vector2) -> void:
	if direction.length_squared() <= 0.01: return
	var normalized_direction: Vector2 = direction.normalized()
	match ability:
		"chakram": mobile_chakram_aim_direction = normalized_direction
		"grapple": mobile_grapple_aim_direction = normalized_direction

func set_mobile_ability_held(ability: String, held: bool) -> void:
	match ability:
		"dash": mobile_dash_held = held
		"chakram":
			if held and mobile_chakram_aim_direction.length_squared() <= 0.01: mobile_chakram_aim_direction = mobile_recent_move_direction if mobile_recent_move_direction.length_squared() > 0.01 else Vector2.UP
			mobile_chakram_held = held
		"grapple":
			if held and mobile_grapple_aim_direction.length_squared() <= 0.01: mobile_grapple_aim_direction = mobile_recent_move_direction if mobile_recent_move_direction.length_squared() > 0.01 else Vector2.UP
			if held and grapple_controller != null and (grapple_controller.active or grapple_controller.firing):
				# A tap while tethered is the mobile disengage gesture.
				grapple_controller.release_tether()
				mobile_grapple_held = false
				mobile_grapple_was_down = false
				mobile_grapple_aiming = false
			else:
				mobile_grapple_held = held

func get_grapple_hand_position() -> Vector2:
	# The tether is visually fired from the same grip that holds the sword.
	# Grapple forces still act on the body center so sword-form animation cannot
	# pump extra energy into the tether.
	var sword_data: Dictionary = _sword_transform()
	var sword_angle: float = float(sword_data["angle"])
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(sword_angle)
	return (sword_data["start"] as Vector2) - blade_direction * BLADE_HILT_INSET

func get_mobile_grapple_aim_point() -> Vector2:
	var aim_direction: Vector2 = mobile_grapple_aim_direction if mobile_input_enabled else _current_aim_direction()
	var grapple_range: float = grapple_controller.max_tether_length * grapple_controller.mastery_range_multiplier
	return get_grapple_hand_position() + aim_direction * grapple_range

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	if training_menu_input_locked or hit_stagger_left > 0.0:
		charged_guard_mouse_motion_delta = Vector2.ZERO
		return
	var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
	var screen_to_world: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	charged_guard_mouse_motion_delta += screen_to_world.basis_xform(mouse_motion.relative)

func _physics_process(delta: float) -> void:
	# Sustained Form III focus slows the world, but its sword/aim clock is
	# compensated back to real-time. Brief ordinary clash hitstop remains felt.
	var sword_control_delta: float = _experimental_sword_control_delta(delta)
	experimental_bind_cooldown_left = maxf(0.0, experimental_bind_cooldown_left - sword_control_delta)
	experimental_reentry_time_left = maxf(0.0, experimental_reentry_time_left - sword_control_delta)
	if experimental_reentry_time_left <= 0.0 or not is_instance_valid(experimental_reentry_opponent):
		_clear_experimental_reentry()
	experimental_bind_contact_seen = false
	if not is_experimental_bind_form() or get_combat_hand_setting("bind_enabled") < 0.5:
		_release_experimental_bind("form changed")
		_clear_experimental_reentry()
	invulnerable = maxf(0.0, invulnerable - delta)
	metronome_reversal_flash_left = maxf(0.0, metronome_reversal_flash_left - delta)
	sword_fire_left = maxf(0.0, sword_fire_left - delta)
	var active_recoil_return: float = get_combat_contact_setting("blade_recoil_return")
	var recoil_return_rate: float = sword_hit_recoil_return_speed if combat_contact_preset == 1 else active_recoil_return
	sword_hit_recoil_offset = move_toward(sword_hit_recoil_offset, 0.0, deg_to_rad(recoil_return_rate) * delta)
	wall_recoil_cooldown = maxf(0.0, wall_recoil_cooldown - delta)
	blade_freeze_left = maxf(0.0, blade_freeze_left - delta)
	grip_authority_left = maxf(0.0, grip_authority_left - delta)
	if dash_timer.is_stopped() and dash_charges < max_dash_charges:
		dash_charges += 1
		if dash_charges < max_dash_charges:
			dash_timer.start(dash_cooldown * BonusConfig.dash_cooldown_multiplier(dash_bonus_rank))
	var maximum_deflect_charges: int = BonusConfig.deflect_max_charges(deflect_rank)
	deflect_charges = clampi(deflect_charges, 0, maximum_deflect_charges)
	deflect_recharge_left -= delta
	if deflect_rank > 0 and deflect_charges < maximum_deflect_charges and deflect_recharge_left <= 0.0:
		deflect_charges += 1
		deflect_recharge_left = BonusConfig.deflect_recharge(deflect_rank)
	clash_recovery_left = maxf(0.0, clash_recovery_left - delta)
	contact_drag_multiplier = move_toward(contact_drag_multiplier, 1.0, contact_drag_recovery_rate * delta)
	flesh_contact_slow_left = maxf(0.0, flesh_contact_slow_left - delta)
	blade_contact_flash_left = maxf(0.0, blade_contact_flash_left - delta)
	chakram_aim_trail_left = maxf(0.0, chakram_aim_trail_left - delta)
	_refresh_live_blade_slide_state()
	slide_cling_left = maxf(0.0, slide_cling_left - delta)
	if slide_cling_left <= 0.0 and preset_2_slide_opponent != null:
		_end_live_blade_slide()
	slide_audio_left = maxf(0.0, slide_audio_left - delta)
	if slide_audio_left <= 0.0 and slide_audio_player != null and slide_audio_player.is_playing(): slide_audio_player.stop()
	preset_2_slide_visual_left = maxf(0.0, preset_2_slide_visual_left - delta)
	contact_spark_left = maxf(0.0, contact_spark_left - delta)
	sword_event_left = maxf(0.0, sword_event_left - delta)
	for enemy_id: int in enemy_rehit_cooldowns.keys():
		enemy_rehit_cooldowns[enemy_id] = maxf(0.0, float(enemy_rehit_cooldowns[enemy_id]) - delta)
	hit_stagger_left = maxf(0.0, hit_stagger_left - delta)
	frost_nova_flash = maxf(0.0, frost_nova_flash - delta)
	frost_nova_cooldown_left = maxf(0.0, frost_nova_cooldown_left - delta)
	flash_step_flash = maxf(0.0, flash_step_flash - delta)
	chain_lightning_flash = maxf(0.0, chain_lightning_flash - delta)
	terrain_root_left = maxf(0.0, terrain_root_left - delta)
	_update_chain_lightning(delta)
	var previous_grapple_cooldown: float = grapple_cooldown_left
	grapple_cooldown_left = maxf(0.0, grapple_cooldown_left - delta)
	grapple_max_charges = BonusConfig.grapple_max_charges(grapple_mastery_rank)
	if previous_grapple_cooldown > 0.0 and grapple_cooldown_left <= 0.0 and grapple_charges < grapple_max_charges:
		grapple_charges += 1
		if grapple_charges < grapple_max_charges:
			grapple_cooldown_left = GRAPPLE_BASE_COOLDOWN * BonusConfig.grapple_cooldown_multiplier(grapple_mastery_rank)
	grapple_charges = clampi(grapple_charges, 0, grapple_max_charges)
	resonant_glyph_spawn_left = maxf(0.0, resonant_glyph_spawn_left - delta)
	if resonant_glyph_rank > 0 and resonant_glyph_spawn_left <= 0.0:
		var current_scene: Node = get_tree().current_scene
		if current_scene != null and current_scene.has_method("try_spawn_resonant_glyph"):
			current_scene.call("try_spawn_resonant_glyph", resonant_glyph_rank)
		resonant_glyph_spawn_left = BonusConfig.resonant_glyph_cooldown(resonant_glyph_rank)
	grapple_controller.mastery_range_multiplier = BonusConfig.grapple_range_multiplier(grapple_mastery_rank)
	var grapple_can_start: bool = grapple_charges > 0 and grapple_cooldown_left <= 0.0
	var grapple_acceleration: Vector2 = Vector2.ZERO
	if mobile_input_enabled:
		var mobile_grapple_down: bool = mobile_grapple_held and not training_menu_input_locked
		var mobile_grapple_started: bool = mobile_grapple_down and not mobile_grapple_was_down
		if mobile_grapple_started:
			if grapple_controller.active or grapple_controller.firing:
				grapple_controller.release_tether()
			else:
				mobile_grapple_aiming = grapple_can_start
		if not mobile_grapple_down and mobile_grapple_was_down and mobile_grapple_aiming:
			grapple_controller.fire_at(get_mobile_grapple_aim_point())
			if grapple_controller.firing:
				grapple_charges = maxi(0, grapple_charges - 1)
				grapple_cooldown_left = GRAPPLE_BASE_COOLDOWN * BonusConfig.grapple_cooldown_multiplier(grapple_mastery_rank)
			mobile_grapple_aiming = false
		mobile_grapple_was_down = mobile_grapple_down
		# Mobile grapple fires on release and remains attached until the next tap.
		grapple_acceleration = grapple_controller.update_and_get_player_acceleration(false, get_mobile_grapple_aim_point(), delta)
	else:
		var grapple_button_down: bool = _grapple_button_pressed() and not training_menu_input_locked
		# Cooldown blocks only new shots. An already-fired tether must continue receiving
		# held input, otherwise the cooldown would immediately release it on the next frame.
		var grapple_held: bool = grapple_button_down and (grapple_can_start or grapple_controller.active or grapple_controller.firing)
		var grapple_started: bool = grapple_button_down and grapple_can_start and not grapple_controller.input_was_down
		grapple_acceleration = grapple_controller.update_and_get_player_acceleration(grapple_held, get_global_mouse_position(), delta)
		# Spend a charge only after _begin_shot() accepted a real flight. Bosses
		# may intentionally block V1 grapples; rejected/zero-distance shots must
		# not silently consume the charge and start cooldown.
		if grapple_started and (grapple_controller.firing or grapple_controller.active):
			grapple_charges = maxi(0, grapple_charges - 1)
			grapple_cooldown_left = GRAPPLE_BASE_COOLDOWN * BonusConfig.grapple_cooldown_multiplier(grapple_mastery_rank)
	flow_trail_points.push_front(global_position)
	if flow_trail_points.size() > flow_trail_length: flow_trail_points.pop_back()
	queue_redraw()
	if hit_stagger_left > 0.0:
		_release_experimental_bind("player staggered")
		hit_knockback += grapple_acceleration * delta
		velocity = hit_knockback
		hit_knockback = hit_knockback.move_toward(Vector2.ZERO, 1800.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	flow_idle_time += delta
	authored_sword_engagement = move_toward(authored_sword_engagement, 0.0, delta / maxf(0.05, authored_engagement_memory))
	var total_regeneration: float = BonusConfig.regeneration_per_second(regeneration_rank) + expedition_food_regeneration
	if total_regeneration > 0.0 and health < max_health:
		restore_health(delta * total_regeneration)
	if flow_idle_time > 5.0 and flow > 0.0:
		flow = maxf(0.0, flow - 8.0 * delta)
		flow_changed.emit(flow, 100.0)
	visual_flow = lerpf(visual_flow, flow, clampf(delta * 8.0, 0.0, 1.0))
	var blend_rate: float = clampf(get_combat_contact_setting("form_blend_smoothing"), 1.0, 30.0)
	var target_blend: float = clampf(flow / 100.0, 0.0, 1.0)
	p4_form_blend = lerpf(p4_form_blend, target_blend, clampf(delta * blend_rate, 0.0, 1.0))
	var player_position_before_movement: Vector2 = global_position
	if training_menu_input_locked:
		velocity = velocity.move_toward(Vector2.ZERO, movement_deceleration * delta)
		move_and_slide()
	else:
		# Bind is the sole player-facing sword form. Other profiles remain internal
		# for development comparisons and persisted-ID compatibility only.
		_handle_dash_input()
		_handle_chakram_input()
		_handle_movement(delta, grapple_acceleration)
	if global_position.distance_squared_to(player_position_before_movement) > 0.01:
		# Camera-follow motion can make a stationary cursor look like authored aim
		# travel in world coordinates. Don't let that move the charged hand pose.
		charged_guard_movement_suppression_left = 0.40
	else:
		charged_guard_movement_suppression_left = maxf(0.0, charged_guard_movement_suppression_left - delta)
	_update_aim(sword_control_delta)
	_update_combat_hand_radius(sword_control_delta)
	_update_authored_metronome_state(sword_control_delta)
	# The gesture layer reads the cursor's own screen position, captured once per frame.
	# Screen space is inherently camera-free: the camera moves the world, never the
	# pointer's place on the screen.
	charged_guard_gesture_cursor = get_viewport().get_mouse_position()
	_update_charged_guard_gesture(sword_control_delta)
	_update_charged_guard(sword_control_delta)
	_apply_experimental_bind_retention(sword_control_delta)
	_update_sword(sword_control_delta)
	_finish_experimental_bind_frame(sword_control_delta)
	_update_knight_sprite_hd()
	queue_redraw()

func set_input_mode(mode: String) -> void:
	input_mode = INPUT_MODE_CONTROLLER if mode == INPUT_MODE_CONTROLLER else INPUT_MODE_KEYBOARD_MOUSE
	controller_aim_direction = Vector2.RIGHT.rotated(aim_angle)
	mobile_aim_direction = controller_aim_direction
	mobile_move_input = Vector2.ZERO
	mobile_dash_held = false
	mobile_chakram_held = false
	mobile_grapple_held = false
	mobile_grapple_was_down = false
	mobile_grapple_aiming = false
	dash_key_was_down = false
	chakram_key_was_down = false
	style_previous_was_down = false
	style_next_was_down = false
	if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())

func set_visual_style(mode: String) -> void:
	visual_style = "hd" if mode == "hd" else "classic"
	if knight_sprite_hd != null: knight_sprite_hd.visible = visual_style == "hd"
	if hd_head_sprite != null: hd_head_sprite.visible = false
	if hd_torso_sprite != null: hd_torso_sprite.visible = false
	if hd_feet_sprite != null: hd_feet_sprite.visible = false

func set_equipped_sword(base_name: String) -> void:
	equipped_sword_id = base_name if BLADE_PROFILES.has(base_name) else "Basic Longsword"
	blade_roll_target = blade_roll_target_for_travel(_blade_edge_side(), blade_travel_sign)
	queue_redraw()

func equipped_sword_texture() -> Texture2D:
	return CURVED_SWORD_TEXTURE if equipped_sword_id == "Basic Curved Sword" else SWORD_TEXTURE

func set_equipped_armor(base_name: String) -> void:
	equipped_armor_id = base_name if ARMOR_VISUALS.has(base_name) else "Basic Leather Armor"
	_apply_armor_visual()

func _apply_armor_visual() -> void:
	if knight_sprite_hd == null: return
	var visual_data: Dictionary = ARMOR_VISUALS.get(equipped_armor_id, {}) as Dictionary
	if visual_data.is_empty(): return
	var idle_texture: Texture2D = load(str(visual_data["idle"])) as Texture2D
	if idle_texture == null: return
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", idle_texture)
	frames.add_animation("walking")
	frames.set_animation_speed("walking", 5.0)
	frames.set_animation_loop("walking", true)
	if visual_data.has("walk_atlas"):
		# Shared atlas image sliced into per-frame regions (original Basic
		# Leather Armor art: one 512x256 image, two 256x256 walk frames).
		var atlas: Texture2D = load(str(visual_data["walk_atlas"])) as Texture2D
		var regions: Array = visual_data.get("walk_regions", []) as Array
		if atlas != null:
			for region: Variant in regions:
				var frame: AtlasTexture = AtlasTexture.new()
				frame.atlas = atlas
				frame.region = region as Rect2
				frames.add_frame("walking", frame)
	else:
		var walk_paths: Array = visual_data.get("walk_frames", []) as Array
		for walk_path: Variant in walk_paths:
			var walk_texture: Texture2D = load(str(walk_path)) as Texture2D
			if walk_texture != null: frames.add_frame("walking", walk_texture)
	if frames.get_frame_count("walking") == 0: return
	var was_playing_walk: bool = knight_sprite_hd.sprite_frames != null and knight_sprite_hd.animation == &"walking"
	knight_sprite_hd.sprite_frames = frames
	knight_sprite_hd.play(&"walking" if was_playing_walk else &"idle")

func _update_knight_sprite_hd() -> void:
	if visual_style != "hd" or knight_sprite_hd == null: return
	var aim_direction: Vector2 = _current_aim_direction()
	var facing_left: bool = transition_facing_direction < 0.0 if not is_zero_approx(transition_facing_direction) else aim_direction.x < 0.0
	var movement_ratio: float = clampf(velocity.length() / maxf(move_speed, 1.0), 0.0, 1.0)
	var moving: bool = movement_ratio > 0.08
	var motion_rate: float = 8.0 if moving else 2.8
	hd_part_time += get_physics_process_delta_time()
	var stride_wave: float = sin(hd_part_time * motion_rate)
	var step_wave: float = absf(stride_wave)
	var idle_breath: float = sin(hd_part_time * 2.8) * (1.0 - movement_ratio) * hd_breath_amount
	var bob: float = idle_breath + step_wave * 1.5 * movement_ratio
	var velocity_direction: Vector2 = velocity.normalized() if velocity.length_squared() > 0.01 else Vector2.ZERO
	var lean_amount: float = clampf(velocity_direction.x, -1.0, 1.0) * deg_to_rad(hd_move_lean_degrees) * movement_ratio
	var dash_ratio: float = clampf(dash_left / maxf(dash_duration, 0.001), 0.0, 1.0)
	var flash_ratio: float = clampf(flash_step_flash / maxf(flash_step_visual_duration, 0.001), 0.0, 1.0)
	var dash_pose: float = maxf(dash_ratio, flash_ratio)
	var hit_ratio: float = clampf(hit_stagger_left / maxf(hit_stagger_time, 0.001), 0.0, 1.0)
	var squash: float = dash_pose * hd_dash_squash
	var recoil_tilt: float = -signf(hit_knockback.x) * deg_to_rad(hd_hit_recoil_degrees) * hit_ratio
	knight_sprite_hd.flip_h = facing_left
	knight_sprite_hd.position = Vector2(lean_amount * 4.0, bob - dash_pose * 1.0)
	knight_sprite_hd.rotation = lean_amount * 0.25 + recoil_tilt
	knight_sprite_hd.scale = Vector2(0.28 * (1.0 + squash), 0.28 * (1.0 - squash * 0.7))
	var desired_animation: StringName = &"walking" if moving else &"idle"
	if knight_sprite_hd.animation != desired_animation: knight_sprite_hd.play(desired_animation)

func _controller_device_id() -> int:
	var devices: Array[int] = Input.get_connected_joypads()
	if devices.has(preferred_controller_device): return preferred_controller_device
	if not devices.is_empty(): return devices[0]
	return preferred_controller_device

func _apply_controller_deadzone(raw_input: Vector2) -> Vector2:
	var magnitude: float = minf(raw_input.length(), 1.0)
	if magnitude <= controller_stick_deadzone: return Vector2.ZERO
	var adjusted_strength: float = (magnitude - controller_stick_deadzone) / maxf(1.0 - controller_stick_deadzone, 0.001)
	return raw_input.normalized() * adjusted_strength

func _controller_stick(horizontal_axis: JoyAxis, vertical_axis: JoyAxis) -> Vector2:
	var device_id: int = _controller_device_id()
	var raw_input: Vector2 = Vector2(Input.get_joy_axis(device_id, horizontal_axis), Input.get_joy_axis(device_id, vertical_axis))
	return _apply_controller_deadzone(raw_input)

func _controller_button_pressed(button: JoyButton) -> bool:
	return Input.is_joy_button_pressed(_controller_device_id(), button)

func _record_charged_guard_control_aim(target_relative: Vector2, control_mode: String, delta: float) -> void:
	if charged_guard_previous_control_mode != control_mode or not charged_guard_has_control_sample:
		charged_guard_previous_control_mode = control_mode
		charged_guard_previous_control_target = target_relative
		charged_guard_has_control_sample = true
		return
	var authored_relative_delta: Vector2 = target_relative - charged_guard_previous_control_target
	charged_guard_previous_control_target = target_relative
	if training_menu_input_locked or delta <= 0.0 or authored_relative_delta.length_squared() <= 0.0001:
		return
	charged_guard_authored_aim_velocity = authored_relative_delta / delta
	charged_guard_authored_angular_travel = charged_guard_angular_travel(target_relative, authored_relative_delta)
	charged_guard_aim_turn_sign = charged_guard_turn_sign(charged_guard_authored_angular_travel)

func _update_virtual_aim_point(delta: float) -> void:
	player_aim_turn_sign = 0.0
	authored_angular_travel_radians = 0.0
	authored_virtual_aim_velocity = Vector2.ZERO
	charged_guard_authored_aim_velocity = Vector2.ZERO
	charged_guard_authored_angular_travel = 0.0
	charged_guard_aim_turn_sign = 0.0
	var mouse_authored_delta: Vector2 = charged_guard_mouse_motion_delta
	charged_guard_mouse_motion_delta = Vector2.ZERO
	# Captured once per frame from the mouse-motion event itself. _input converts it with the
	# camera's basis alone, so the camera's lead, lag and arena clamp cannot reach it, and it
	# is zero on every frame the cursor did not move.
	charged_guard_cursor_motion = mouse_authored_delta
	if mobile_input_enabled:
		var old_mobile_relative: Vector2 = virtual_aim_point - global_position
		var mobile_magnitude: float = clampf(mobile_aim_direction.length(), 0.0, 1.0)
		var mobile_direction: Vector2 = mobile_aim_direction.normalized() if mobile_magnitude > 0.01 else (old_mobile_relative.normalized() if old_mobile_relative.length_squared() > 1.0 else Vector2.RIGHT.rotated(aim_angle))
		var minimum_range: float = get_combat_hand_setting("min")
		var maximum_range: float = maxf(minimum_range, get_combat_hand_setting("max"))
		var reach_scale: float = maxf(0.01, get_combat_hand_setting("scale"))
		# Spatial gearing makes full hand reach require more stick travel when raised,
		# just as desktop requires more cursor travel.
		var geared_magnitude: float = pow(mobile_magnitude, reach_scale)
		var target_relative: Vector2 = mobile_direction * lerpf(minimum_range, maximum_range, geared_magnitude)
		_record_charged_guard_control_aim(target_relative, "mobile", delta)
		var mobile_drag_rate: float = get_combat_hand_setting("mouse_drag")
		if combat_contact_preset == 4:
			var mobile_flow_ratio: float = clampf(flow / 100.0, 0.0, 1.0)
			mobile_drag_rate = lerpf(8.0, mobile_drag_rate, mobile_flow_ratio)
		var mobile_drag_weight: float = 1.0 - exp(-clampf(mobile_drag_rate, 2.0, 50.0) * delta)
		var new_mobile_relative: Vector2 = old_mobile_relative.lerp(target_relative, clampf(mobile_drag_weight, 0.0, 1.0))
		virtual_aim_point = global_position + new_mobile_relative
		var authored_relative_delta: Vector2 = new_mobile_relative - old_mobile_relative
		if has_virtual_aim_sample and delta > 0.0:
			authored_virtual_aim_velocity = authored_relative_delta / delta
		if has_virtual_aim_sample and authored_relative_delta.length_squared() > 0.0001:
			var authored_aim_speed: float = authored_relative_delta.length() / maxf(delta, 0.0001)
			authored_sword_engagement = maxf(authored_sword_engagement, clampf(authored_aim_speed / maxf(1.0, authored_engagement_speed_reference), 0.0, 1.0))
			if new_mobile_relative.length_squared() > 1.0:
				var mobile_turn_delta: float = new_mobile_relative.cross(authored_relative_delta) / new_mobile_relative.length_squared()
				authored_angular_travel_radians = mobile_turn_delta
				if absf(mobile_turn_delta) >= SWING_COMMITMENT_INPUT_THRESHOLD: player_aim_turn_sign = signf(mobile_turn_delta)
		previous_virtual_aim_point = virtual_aim_point
		has_virtual_aim_sample = true
		return
	if input_mode == INPUT_MODE_CONTROLLER:
		var old_controller_relative: Vector2 = virtual_aim_point - global_position
		var right_stick: Vector2 = _controller_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y)
		controller_aim_strength = clampf(right_stick.length(), 0.0, 1.0)
		if controller_aim_strength > 0.01:
			controller_aim_direction = right_stick.normalized()
		var controller_minimum: float = get_combat_hand_setting("min")
		var controller_maximum: float = maxf(controller_minimum, get_combat_hand_setting("max"))
		var controller_radius: float = lerpf(controller_minimum, controller_maximum, controller_aim_strength)
		var new_controller_relative: Vector2 = controller_aim_direction * controller_radius
		_record_charged_guard_control_aim(new_controller_relative, "controller", delta)
		virtual_aim_point = global_position + new_controller_relative
		var controller_relative_delta: Vector2 = new_controller_relative - old_controller_relative
		if has_virtual_aim_sample and delta > 0.0:
			authored_virtual_aim_velocity = controller_relative_delta / delta
			var controller_authored_speed: float = authored_virtual_aim_velocity.length()
			authored_sword_engagement = maxf(authored_sword_engagement, clampf(controller_authored_speed / maxf(1.0, authored_engagement_speed_reference), 0.0, 1.0))
		if has_virtual_aim_sample and new_controller_relative.length_squared() > 1.0 and controller_relative_delta.length_squared() > 0.0001:
			var controller_turn_delta: float = new_controller_relative.cross(controller_relative_delta) / new_controller_relative.length_squared()
			authored_angular_travel_radians = controller_turn_delta
			if absf(controller_turn_delta) >= SWING_COMMITMENT_INPUT_THRESHOLD:
				player_aim_turn_sign = signf(controller_turn_delta)
		previous_virtual_aim_point = virtual_aim_point
		has_virtual_aim_sample = true
		return
	charged_guard_previous_control_mode = "mouse"
	charged_guard_has_control_sample = false
	var mouse_pos: Vector2 = get_global_mouse_position()
	if virtual_aim_point == Vector2.ZERO:
		virtual_aim_point = mouse_pos
		previous_virtual_aim_point = virtual_aim_point
		has_virtual_aim_sample = true
		return
	var old_virtual_aim_point: Vector2 = virtual_aim_point
	var base_drag: float = get_combat_hand_setting("mouse_drag")
	if combat_contact_preset == 4:
		var flow_ratio: float = clampf(flow / 100.0, 0.0, 1.0)
		base_drag = lerpf(8.0, base_drag, flow_ratio)
	var drag_rate: float = clampf(base_drag, 2.0, 50.0)
	var drag_weight: float = 1.0 - exp(-drag_rate * delta)
	virtual_aim_point = virtual_aim_point.lerp(mouse_pos, clampf(drag_weight, 0.0, 1.0))
	if not training_menu_input_locked and delta > 0.0 and mouse_authored_delta.length_squared() > 0.0001:
		var guard_aim_relative: Vector2 = virtual_aim_point - global_position
		charged_guard_authored_aim_velocity = mouse_authored_delta / delta
		charged_guard_authored_angular_travel = charged_guard_angular_travel(guard_aim_relative, mouse_authored_delta)
		charged_guard_aim_turn_sign = charged_guard_turn_sign(charged_guard_authored_angular_travel)
	if has_virtual_aim_sample:
		var aim_radius: Vector2 = virtual_aim_point - global_position
		var aim_point_delta: Vector2 = virtual_aim_point - old_virtual_aim_point
		var authored_aim_speed: float = aim_point_delta.length() / maxf(delta, 0.0001)
		authored_virtual_aim_velocity = aim_point_delta / maxf(delta, 0.0001)
		authored_sword_engagement = maxf(authored_sword_engagement, clampf(authored_aim_speed / maxf(1.0, authored_engagement_speed_reference), 0.0, 1.0))
		if aim_radius.length_squared() > 1.0 and aim_point_delta.length_squared() > 0.0001:
			# World-space aim-point movement is immune to player translation. A
			# stationary mouse therefore cannot create a fake reversal event.
			var input_angle_delta: float = aim_radius.cross(aim_point_delta) / aim_radius.length_squared()
			authored_angular_travel_radians = input_angle_delta
			if absf(input_angle_delta) >= SWING_COMMITMENT_INPUT_THRESHOLD:
				player_aim_turn_sign = signf(input_angle_delta)
	previous_virtual_aim_point = virtual_aim_point
	has_virtual_aim_sample = true

func _current_aim_direction() -> Vector2:
	if mobile_input_enabled:
		var mobile_virtual_direction: Vector2 = global_position.direction_to(virtual_aim_point)
		return mobile_virtual_direction if mobile_virtual_direction != Vector2.ZERO else (mobile_aim_direction.normalized() if mobile_aim_direction.length_squared() > 0.01 else Vector2.RIGHT.rotated(aim_angle))
	if input_mode == INPUT_MODE_CONTROLLER:
		return controller_aim_direction.normalized() if controller_aim_direction.length_squared() > 0.01 else Vector2.RIGHT.rotated(aim_angle)
	var mouse_direction: Vector2 = global_position.direction_to(virtual_aim_point)
	return mouse_direction if mouse_direction != Vector2.ZERO else Vector2.RIGHT.rotated(aim_angle)

func _movement_input() -> Vector2:
	if mobile_input_enabled:
		return mobile_move_input
	if input_mode == INPUT_MODE_CONTROLLER:
		return _controller_stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	var direction: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1.0
	return direction.normalized()

func _is_touching_enemy() -> bool:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) <= body_pressure_contact_distance:
			return true
	return false

func set_terrain_movement_modifier(source_id: int, multiplier: float) -> void:
	terrain_movement_modifiers[source_id] = clampf(multiplier, 0.0, 1.0)

func set_terrain_dash_block(source_id: int, blocked: bool) -> void:
	if blocked:
		terrain_dash_block_sources[source_id] = true
		dash_left = 0.0
	else:
		terrain_dash_block_sources.erase(source_id)

func remove_terrain_effect(source_id: int) -> void:
	terrain_movement_modifiers.erase(source_id)
	terrain_dash_block_sources.erase(source_id)

func apply_terrain_root(duration: float) -> void:
	terrain_root_left = maxf(terrain_root_left, duration)
	dash_left = 0.0
	velocity = Vector2.ZERO

func set_ice_slide(source_id: int, friction_multiplier: float) -> void:
	ice_slide_modifiers[source_id] = clampf(friction_multiplier, 0.05, 1.0)

func remove_ice_slide(source_id: int) -> void:
	ice_slide_modifiers.erase(source_id)

func _ice_slide_friction_multiplier() -> float:
	var result: float = 1.0
	for modifier: float in ice_slide_modifiers.values(): result = minf(result, modifier)
	return result

func _terrain_movement_multiplier() -> float:
	var result: float = 1.0
	for modifier: float in terrain_movement_modifiers.values(): result = minf(result, modifier)
	return result

func _terrain_dash_blocked() -> bool:
	return terrain_root_left > 0.0 or not terrain_dash_block_sources.is_empty()

func _handle_movement(delta: float, grapple_acceleration: Vector2 = Vector2.ZERO) -> void:
	var dash_path_start: Vector2 = global_position
	var was_dashing: bool = dash_left > 0.0
	if terrain_root_left > 0.0:
		dash_left = 0.0
		velocity = velocity.move_toward(Vector2.ZERO, movement_deceleration * 2.0 * delta)
		move_and_slide()
		return
	if dash_left > 0.0:
		dash_path_start = global_position
		dash_left -= delta
		# A tethered dash receives one impulse when it starts. Do not overwrite
		# that velocity each frame, so rope tension can bend it into an orbit.
		if not grapple_controller.is_dash_momentum_active():
			velocity = dash_direction * dash_speed
	elif charged_guard_gesture_lunge_left > 0.0:
		# The thrust's lunge owns movement for its short drive: ordinary input is
		# suppressed so the body is genuinely thrown along the drawn line, while walls,
		# terrain and the arena clamp still resolve through move_and_slide below exactly
		# as they do for a dash.
		charged_guard_gesture_lunge_left = maxf(0.0, charged_guard_gesture_lunge_left - delta)
		velocity = charged_guard_gesture_direction * CHARGED_GUARD_THRUST_LUNGE_SPEED
	else:
		var input_direction: Vector2 = _movement_input()
		var pressure_multiplier: float = body_pressure_speed_multiplier if _is_touching_enemy() and invulnerable <= 0.0 else 1.0
		var flesh_contact_multiplier: float = flesh_contact_movement_multiplier if flesh_contact_slow_left > 0.0 else 1.0
		var slide_friction_multiplier: float = get_combat_contact_setting("slide_friction") if has_live_blade_slide_contact() else 1.0
		var target_velocity: Vector2 = input_direction * move_speed * pressure_multiplier * flesh_contact_multiplier * slide_friction_multiplier * _terrain_movement_multiplier()
		var acceleration: float = movement_acceleration
		if input_direction != Vector2.ZERO and velocity.dot(input_direction) < 0.0:
			acceleration = direction_change_deceleration
		elif input_direction == Vector2.ZERO:
			acceleration = movement_deceleration
		acceleration *= _ice_slide_friction_multiplier()
		acceleration *= grapple_controller.movement_traction_multiplier()
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	# Tension is an acceleration layered onto whatever movement and dash already
	# produced. It never removes the component tangent to the rope.
	velocity += grapple_acceleration * delta
	move_and_slide()
	if was_dashing: _check_bash_dash_contacts(dash_path_start, global_position)
	var arena_rect: Rect2 = GameplayBounds.arena_rect(get_tree().current_scene)
	global_position.x = clampf(global_position.x, arena_rect.position.x + 24.0, arena_rect.end.x - 24.0)
	global_position.y = clampf(global_position.y, arena_rect.position.y + 24.0, arena_rect.end.y - 24.0)

func _check_bash_dash_contacts(path_start: Vector2, path_end: Vector2) -> void:
	if bash_dash_rank <= 0 or path_start.distance_squared_to(path_end) < 0.01: return
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null: return
	var main_scene: Node = scene_tree.current_scene
	var bash_direction: Vector2 = path_start.direction_to(path_end)
	if bash_direction == Vector2.ZERO: bash_direction = _current_aim_direction()
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or not is_instance_valid(enemy): continue
		var enemy_id: int = enemy.get_instance_id()
		if bash_dash_hit_ids.has(enemy_id): continue
		if _distance_to_segment(enemy.global_position, path_start, path_end) > bash_dash_contact_radius: continue
		if main_scene != null and main_scene.has_method("has_terrain_line_of_sight") and not main_scene.has_terrain_line_of_sight(global_position, enemy.global_position, 2.0): continue
		if not enemy.has_method("take_damage"): continue
		bash_dash_hit_ids[enemy_id] = true
		var dash_damage: float = BonusConfig.bash_dash_damage(bash_dash_rank)
		var dash_knockback: float = BonusConfig.bash_dash_knockback(bash_dash_rank)
		var dash_stun: float = BonusConfig.bash_dash_stun(bash_dash_rank)
		enemy.call("take_damage", dash_damage, bash_direction * dash_knockback, dash_stun, 0.75)
		if main_scene != null and main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(enemy.global_position, 1.15)
		if main_scene != null and main_scene.has_method("request_screen_shake"): main_scene.request_screen_shake(3.0, 0.10, bash_direction)
		if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("enemy_hit", 0.9, 0.8)

func _fire_dash(direction: Vector2) -> void:
	if dash_charges <= 0 or _terrain_dash_blocked():
		return
	bash_dash_hit_ids.clear()
	dash_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT.rotated(aim_angle)
	if flash_step_enabled:
		flash_step_origin = global_position
		var flash_motion: Vector2 = dash_direction * dash_speed * dash_duration * BonusConfig.flash_step_distance_multiplier(flash_step_rank)
		move_and_collide(flash_motion)
		flash_step_destination = global_position
		_check_bash_dash_contacts(flash_step_origin, flash_step_destination)
		dash_left = 0.0
		flash_step_flash = flash_step_visual_duration
	else:
		dash_left = dash_duration
		if grapple_controller.active:
			velocity += dash_direction * dash_speed
	if grapple_controller.active:
		grapple_controller.notify_tethered_dash()
	dash_charges -= 1
	report_tutorial_action("dash_performed")
	if dash_timer.is_stopped(): dash_timer.start(dash_cooldown * BonusConfig.dash_cooldown_multiplier(dash_bonus_rank))
	var main_scene: Node = get_tree().current_scene
	if void_dash_level > 0:
		var void_well: VoidWell = VOID_WELL_SCENE.instantiate() as VoidWell
		get_parent().add_child(void_well)
		void_well.setup(global_position, BonusConfig.void_dash_radius(void_dash_level))
	if main_scene.has_method("play_sfx"): main_scene.play_sfx("dash", 0.8)

func _handle_dash_input() -> void:
	var down: bool = mobile_dash_held if mobile_input_enabled else (_controller_button_pressed(CONTROLLER_DASH_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_SPACE))
	if mobile_input_enabled:
		if not down and dash_key_was_down:
			var mobile_dash_direction: Vector2 = mobile_move_input.normalized() if mobile_move_input.length_squared() > 0.01 else mobile_recent_move_direction
			if mobile_dash_direction.length_squared() <= 0.01: mobile_dash_direction = Vector2.UP
			_fire_dash(mobile_dash_direction)
	else:
		if down and not dash_key_was_down:
			var direction: Vector2 = _movement_input()
			if direction == Vector2.ZERO: direction = _current_aim_direction()
			_fire_dash(direction)
	dash_key_was_down = down

func _preview_chakram_aim() -> void:
	var direction: Vector2 = mobile_chakram_aim_direction if mobile_input_enabled else _current_aim_direction()
	chakram_aim_trail_start = global_position
	var displayed_distance: float = chakram_aim_trail_max_distance
	if not mobile_input_enabled and input_mode != INPUT_MODE_CONTROLLER:
		displayed_distance = minf(global_position.distance_to(get_global_mouse_position()), chakram_aim_trail_max_distance)
	chakram_aim_trail_end = global_position + direction * displayed_distance
	chakram_aim_trail_left = chakram_aim_trail_duration

func _throw_chakram() -> void:
	if chakram_charges <= 0:
		return
	var direction: Vector2 = mobile_chakram_aim_direction if mobile_input_enabled else _current_aim_direction()
	_preview_chakram_aim()
	var thrown: Chakram = CHAKRAM_SCENE.instantiate() as Chakram
	get_parent().add_child(thrown)
	thrown.global_position = global_position + direction * 34.0
	thrown.launch(direction, self)
	report_tutorial_action("chakram_thrown", thrown)
	chakram_charges -= 1
	thrown.tree_exited.connect(_on_chakram_exited.bind(thrown))
	active_chakrams.append(thrown)
	chakram = thrown

func _handle_chakram_input() -> void:
	var down: bool = mobile_chakram_held if mobile_input_enabled else (_controller_button_pressed(CONTROLLER_CHAKRAM_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if mobile_input_enabled:
		if down and not chakram_key_was_down and chakram_charges > 0:
			_preview_chakram_aim()
		elif down and chakram_key_was_down and chakram_charges > 0:
			_preview_chakram_aim()
		elif not down and chakram_key_was_down:
			_throw_chakram()
	else:
		if down and not chakram_key_was_down:
			_preview_chakram_aim()
			_throw_chakram()
	chakram_key_was_down = down

## Compatibility notifications remain callable by existing damage/contact paths,
## but forward-step eligibility is now owned solely by Authored Step.
func notify_player_damage_dealt(_source_is_sword: bool) -> void:
	pass

func notify_sword_contact() -> void:
	pass

func _handle_style_input() -> void:
	if sword_style == SwordStyle.METRONOME_BIND:
		sword_style = SwordStyle.METRONOME_BIND_B
	var previous_down: bool = _controller_button_pressed(CONTROLLER_STYLE_PREVIOUS_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_Z)
	var next_down: bool = _controller_button_pressed(CONTROLLER_STYLE_NEXT_BUTTON) if input_mode == INPUT_MODE_CONTROLLER else Input.is_physical_key_pressed(KEY_X)
	if previous_down and not style_previous_was_down:
		var current_style_index: int = STYLE_CYCLE_ORDER.find(int(sword_style))
		var previous_style_index: int = posmod(current_style_index - 1, STYLE_CYCLE_ORDER.size())
		sword_style = STYLE_CYCLE_ORDER[previous_style_index] as SwordStyle
		if sword_style in [SwordStyle.MOULINET_3, SwordStyle.MOULINET_4]:
			moulinet_continuous_angle = sword_phase * 2.0 * moulinet_aim_direction_smoothed
		hit_ids.clear()
		style_changed.emit(_style_name())
	if next_down and not style_next_was_down:
		var current_style_index: int = STYLE_CYCLE_ORDER.find(int(sword_style))
		var next_style_index: int = posmod(current_style_index + 1, STYLE_CYCLE_ORDER.size())
		sword_style = STYLE_CYCLE_ORDER[next_style_index] as SwordStyle
		if sword_style in [SwordStyle.MOULINET_3, SwordStyle.MOULINET_4]:
			moulinet_continuous_angle = sword_phase * 2.0 * moulinet_aim_direction_smoothed
		hit_ids.clear()
		style_changed.emit(_style_name())
	style_previous_was_down = previous_down
	style_next_was_down = next_down

func is_experimental_bind_form() -> bool:
	return int(sword_style) in EXPERIMENTAL_BIND_STYLES

func experimental_overhead_debug_lines() -> PackedStringArray:
	if not is_experimental_bind_form() or get_combat_hand_setting("bind_debug") < 0.5:
		return PackedStringArray()
	return PackedStringArray([
		"Winds: %d" % experimental_wind_count,
		"Binds: %d" % experimental_bind_count,
		"Beats: %d/%d" % [experimental_beat_count, experimental_rejected_beat_count],
		"Slides: %d" % sword_slide_count
	])

func _is_windup_metronome_style() -> bool:
	return sword_style == SwordStyle.METRONOME_WINDUP or is_experimental_bind_form()

func _is_metronome_style() -> bool:
	return sword_style in [SwordStyle.METRONOME, SwordStyle.METRONOME_WINDUP] or is_experimental_bind_form()

func set_metronome_visualizer_counts(value: int) -> void:
	metronome_visualizer_counts = clampi(value, 1, 4)
	if metronome_visualizer != null:
		metronome_visualizer.set_visualizer_counts(metronome_visualizer_counts)

func set_metronome_visualizer_beat_percent(value: float) -> void:
	metronome_visualizer_beat_percent = clampf(value, 0.0, 100.0)
	if metronome_visualizer != null:
		metronome_visualizer.set_beat_percent(metronome_visualizer_beat_percent)

func set_metronome_visualizer_palette(value: String) -> void:
	metronome_visualizer_palette = value if value in ["gold", "blue", "green"] else "gold"
	if metronome_visualizer != null:
		metronome_visualizer.set_palette(metronome_visualizer_palette)

func _style_name() -> String:
	match sword_style:
		SwordStyle.METRONOME_BIND, SwordStyle.METRONOME_BIND_B: return "Form I: Bind"
		SwordStyle.METRONOME_WINDUP: return "Form II: Metronome Wind-up"
		SwordStyle.METRONOME: return "Form III: Metronome V"
		SwordStyle.THRUST: return "Form V: Thrusting A"
		SwordStyle.MOULINET: return "Form VI: Moulinet 1 (Full 8)"
		SwordStyle.MOULINET_2: return "Form VII: Moulinet 2 (Single Lobe)"
		SwordStyle.MOULINET_3: return "Form VIII: Moulinet 3 (Aim-Driven)"
		SwordStyle.MOULINET_4: return "Form IX: Flattened Infinity"
		SwordStyle.THRUST_METRONOME: return "Form X: Metronome Thrusts"
		_: return "Unknown Form"

func _is_elbow_style() -> bool:
	return false

func _current_elbow_joint_speed() -> float:
	return 10.0

func _current_elbow_pivot_distance() -> float:
	return 0.0

static func moulinet_smoothing_weight(delta: float, rate: float) -> float:
	# Preserve the original control direction: lower rate is slower, higher is
	# faster. The extended 0.05 /s low end allows very heavy reversals.
	return clampf(1.0 - exp(-maxf(rate, 0.05) * maxf(delta, 0.0)), 0.0, 1.0)

## Returns whether a newly detected player aim turn opposes the sword's
## current tangential motion. This is deliberately event-shaped: callers must
## only use it when the player actually moved their aim, never merely because
## the autonomous swing is currently traveling the other way.
static func swing_commitment_is_opposing(sword_velocity: Vector2, blade_direction: Vector2, player_velocity: Vector2, input_turn_sign: float) -> bool:
	var requested_sign: float = signf(input_turn_sign)
	if requested_sign == 0.0 or blade_direction.length_squared() < 0.001:
		return false
	var relative_velocity: Vector2 = sword_velocity - player_velocity
	if relative_velocity.length_squared() < 25.0:
		return false
	var sword_motion_sign: float = signf(blade_direction.cross(relative_velocity))
	return sword_motion_sign != 0.0 and sword_motion_sign != requested_sign

## Returns the directional aim-response multiplier for Swing Commitment.
## Matching input stays fully responsive; opposing input gets deliberately
## heavier, but never locks completely. Player translation is removed so
## walking does not masquerade as sword momentum.
static func swing_commitment_turn_scale(sword_velocity: Vector2, blade_direction: Vector2, player_velocity: Vector2, input_turn_sign: float, commitment: float) -> float:
	if not swing_commitment_is_opposing(sword_velocity, blade_direction, player_velocity, input_turn_sign):
		return 1.0
	var normalized_commitment: float = clampf(commitment, 0.0, 1.0)
	# Full commitment still permits 25% response, preserving deliberate control
	# instead of creating the same dead feeling as a hard turn lock.
	return lerpf(1.0, 0.25, normalized_commitment)

static func metronome_stroke_progress(phase: float) -> float:
	# Metronome reversals occur at PI/2 and 3*PI/2; each stroke spans PI.
	return wrapf(phase - PI * 0.5, 0.0, PI) / PI

static func _metronome_windup_raw_speed(progress: float, windup_fraction: float, recovery_fraction: float, windup_speed: float = 0.35, strike_speed: float = 2.2, recovery_speed: float = 0.35) -> float:
	var windup: float = clampf(windup_fraction, 0.05, 0.8)
	var recovery: float = clampf(recovery_fraction, 0.05, 0.8)
	if windup + recovery > 0.9:
		recovery = 0.9 - windup
	var fast_speed: float = clampf(strike_speed, 0.1, 6.0)
	var opening_speed: float = clampf(windup_speed, 0.05, 2.0)
	var closing_speed: float = clampf(recovery_speed, 0.05, 2.0)
	if progress < windup:
		var windup_t: float = clampf(progress / windup, 0.0, 1.0)
		var windup_eased: float = windup_t * windup_t * (3.0 - 2.0 * windup_t)
		return lerpf(opening_speed, fast_speed, windup_eased)
	var recovery_start: float = 1.0 - recovery
	if progress > recovery_start:
		var recovery_t: float = clampf((progress - recovery_start) / recovery, 0.0, 1.0)
		var recovery_eased: float = recovery_t * recovery_t * (3.0 - 2.0 * recovery_t)
		return lerpf(fast_speed, closing_speed, recovery_eased)
	return fast_speed

static func metronome_windup_speed_multiplier(progress: float, profile: float, windup_fraction: float, recovery_fraction: float, windup_speed: float = 0.35, strike_speed: float = 2.2, recovery_speed: float = 0.35) -> float:
	var normalized_profile: float = clampf(profile, 0.0, 1.0)
	if normalized_profile <= 0.0:
		return 1.0
	var sample_count: int = 32
	var inverse_speed_sum: float = 0.0
	for sample_index: int in range(sample_count):
		var sample_progress: float = (float(sample_index) + 0.5) / float(sample_count)
		var sample_raw: float = _metronome_windup_raw_speed(sample_progress, windup_fraction, recovery_fraction, windup_speed, strike_speed, recovery_speed)
		var sample_speed: float = lerpf(1.0, sample_raw, normalized_profile)
		inverse_speed_sum += 1.0 / maxf(sample_speed, 0.05)
	var current_raw: float = _metronome_windup_raw_speed(clampf(progress, 0.0, 0.999999), windup_fraction, recovery_fraction, windup_speed, strike_speed, recovery_speed)
	var current_speed: float = lerpf(1.0, current_raw, normalized_profile)
	# Normalize by average traversal time so the frequency slider keeps its
	# meaning even while the stroke's speed is redistributed.
	var time_normalizer: float = inverse_speed_sum / float(sample_count)
	return current_speed * time_normalizer

static func metronome_action_commitment_scale(progress: float, strength: float, start: float, end: float) -> float:
	var normalized_strength: float = clampf(strength, 0.0, 1.0)
	if normalized_strength <= 0.0:
		return 1.0
	var action_start: float = clampf(start, 0.0, 0.99)
	var action_end: float = clampf(end, action_start + 0.01, 1.0)
	var stroke_progress: float = clampf(progress, 0.0, 1.0)
	if stroke_progress < action_start or stroke_progress >= action_end:
		return 1.0
	# Strength 1.0 is the actual no-cancel setting: aim authority is removed
	# during the configured action window. Lower values provide a softer ramp.
	return 1.0 - normalized_strength

const BLADE_TRAVEL_SIGN_THRESHOLD: float = 35.0
const BLADE_TRAVEL_SIGN_CONFIRM_TIME: float = 0.025

static func blade_roll_target_for_travel(edge_side: float, travel_sign: float) -> float:
	var normalized_edge_side: float = -1.0 if edge_side < 0.0 else 1.0
	var normalized_travel_sign: float = -1.0 if travel_sign < 0.0 else 1.0
	return normalized_edge_side * normalized_travel_sign

func _blade_edge_side() -> float:
	return get_blade_shape_setting(equipped_sword_id, "edge_side")

## Uses the blade's measured tangential velocity so player-forced reversals can
## change rollover before the autonomous phase reaches its normal boundary.
func _update_blade_roll_target(relative_velocity: Vector2, blade_direction: Vector2, delta: float) -> void:
	var tangential_speed: float = blade_direction.cross(relative_velocity)
	if absf(tangential_speed) < BLADE_TRAVEL_SIGN_THRESHOLD:
		blade_travel_sign_candidate = 0.0
		blade_travel_sign_candidate_left = 0.0
		return
	var candidate_sign: float = signf(tangential_speed)
	if is_zero_approx(candidate_sign) or is_equal_approx(candidate_sign, blade_travel_sign):
		blade_travel_sign_candidate = 0.0
		blade_travel_sign_candidate_left = 0.0
		return
	if not is_equal_approx(candidate_sign, blade_travel_sign_candidate):
		blade_travel_sign_candidate = candidate_sign
		blade_travel_sign_candidate_left = BLADE_TRAVEL_SIGN_CONFIRM_TIME
		return
	blade_travel_sign_candidate_left = maxf(0.0, blade_travel_sign_candidate_left - delta)
	if blade_travel_sign_candidate_left <= 0.0:
		blade_travel_sign = candidate_sign
		blade_roll_target = blade_roll_target_for_travel(_blade_edge_side(), blade_travel_sign)
		blade_travel_sign_candidate = 0.0

## Every weapon participates in rollover. Symmetric art simply makes the state
## visually neutral; it is not excluded, so future asymmetric profiles work
## without another special case.
func _update_blade_roll(delta: float) -> void:
	var speed: float = maxf(get_combat_contact_setting("blade_roll_speed"), 0.1)
	blade_roll = move_toward(blade_roll, blade_roll_target, speed * delta)

func _update_aim(delta: float) -> void:
	_update_virtual_aim_point(delta)
	var target_angle: float = _current_aim_direction().angle()
	var max_turn_deg: float = get_combat_hand_setting("max_turn_speed")
	var rot_speed: float = _current_rotation_speed()
	if combat_contact_preset == 3:
		var flow_ratio: float = clampf(visual_flow / 100.0, 0.0, 1.0)
		var min_turn_scale: float = get_combat_contact_setting("p3_min_turn_scale")
		rot_speed *= lerpf(min_turn_scale, 1.0, flow_ratio)
		if max_turn_deg > 0.0:
			max_turn_deg *= lerpf(min_turn_scale, 1.0, flow_ratio)
	elif combat_contact_preset == 4:
		var flow_ratio: float = clampf(visual_flow / 100.0, 0.0, 1.0)
		rot_speed = lerpf(5.0, rot_speed, flow_ratio)
		if max_turn_deg > 0.0:
			max_turn_deg = lerpf(450.0, max_turn_deg, flow_ratio)
		else:
			# If max turn speed was 0 (unlimited), at 0% flow impose a deliberate 540 deg/s cap that opens to unlimited
			if flow_ratio < 0.99:
				max_turn_deg = lerpf(540.0, 1800.0, flow_ratio)
	# Grip authority burst: while recovering from a strike or rebound, turn speed surges
	if grip_authority_left > 0.0:
		var grip_mult: float = maxf(1.0, get_combat_contact_setting("grip_turn_speed_mult"))
		rot_speed *= grip_mult
		if max_turn_deg > 0.0: max_turn_deg *= grip_mult
	# First track towards target angle at the style's rotation speed
	var diff: float = angle_difference(aim_angle, target_angle)
	# Swing Commitment is an input event, not a permanent property of the
	# autonomous swing. A new player aim turn can arm a short response window;
	# holding the aim still lets the sword become completely normal again.
	swing_commitment_left = maxf(0.0, swing_commitment_left - delta)
	var sword_data: Dictionary = _sword_transform()
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(float(sword_data["angle"]))
	var swing_commitment: float = get_combat_hand_setting("swing_commitment") if _is_windup_metronome_style() else 0.0
	if swing_commitment > 0.0 and player_aim_turn_sign != 0.0 and swing_commitment_is_opposing(blade_velocity, blade_direction, velocity, player_aim_turn_sign):
		swing_commitment_left = clampf(get_combat_hand_setting("swing_commitment_duration"), 0.0, 0.5)
		swing_commitment_direction = player_aim_turn_sign
	elif player_aim_turn_sign != 0.0 and not swing_commitment_is_opposing(blade_velocity, blade_direction, velocity, player_aim_turn_sign):
		swing_commitment_left = 0.0
		swing_commitment_direction = 0.0
	if swing_commitment_left > 0.0 and signf(diff) == swing_commitment_direction:
		var commitment_scale: float = swing_commitment_turn_scale(blade_velocity, blade_direction, velocity, swing_commitment_direction, swing_commitment)
		diff *= commitment_scale
	# Late-stroke Action Commitment is separate from Swing Commitment: it can
	# remove aim authority for a configured window, making a heavy attack truly
	# non-cancelable without slowing the autonomous phase or player movement.
	if _is_windup_metronome_style():
		var action_scale: float = metronome_action_commitment_scale(metronome_stroke_progress(sword_phase), get_combat_hand_setting("action_commitment_strength"), get_combat_hand_setting("action_commitment_start"), get_combat_hand_setting("action_commitment_end"))
		diff *= action_scale
	# Rebound Flow: if the player directs their turn WITH the recoil/bounce direction, boost angular step
	if grip_authority_left > 0.0 and rebound_flow_sign != 0.0:
		if sign(diff) == rebound_flow_sign:
			var flow_boost: float = maxf(1.0, get_combat_contact_setting("rebound_flow_boost"))
			diff *= flow_boost
	var desired_step: float = diff * clampf(rot_speed * delta, 0.0, 1.0)
	# Forms V and VI own their aim-driven direction and continuous accumulator.
	if sword_style in [SwordStyle.MOULINET_3, SwordStyle.MOULINET_4]:
		if absf(diff) > 0.005:
			moulinet_aim_direction_sign = 1.0 if diff > 0.0 else -1.0
		var smoothing_rate: float = clampf(get_combat_hand_setting("moulinet_aim_smoothing"), 0.05, 30.0)
		var smoothing_weight: float = moulinet_smoothing_weight(delta, smoothing_rate)
		moulinet_aim_direction_smoothed = lerpf(moulinet_aim_direction_smoothed, moulinet_aim_direction_sign, smoothing_weight)
		var spin_speed: float = _sword_cycle_frequency() * TAU * 2.0
		moulinet_continuous_angle += spin_speed * moulinet_aim_direction_smoothed * delta
	# If max_turn_speed is configured (> 0), cap the maximum angular turn per second
	if max_turn_deg > 0.0:
		var max_step_rad: float = deg_to_rad(max_turn_deg) * delta
		desired_step = clampf(desired_step, -max_step_rad, max_step_rad)
	var charged_position_stage_enabled: bool = get_combat_contact_setting("charged_guard_position_charge_enabled") >= 0.5
	var charged_reposition_scale: float = charged_guard_slow_reposition_scale(charged_guard_authored_aim_velocity.length(), CHARGED_GUARD_REPOSITION_SPEED_REFERENCE, charged_guard_movement_suppression_left > 0.0) * charged_guard_reposition_ramp if charged_guard_fully_charged and charged_position_stage_enabled else 1.0
	if charged_guard_hand_follows_cursor(charged_guard_fully_charged, charged_position_stage_enabled, charged_guard_reposition_ramp):
		desired_step *= charged_reposition_scale
		# Converge on a bounded target instead of integrating cursor displacement, so
		# returning from any direction stays smooth. Mouse aim takes that target from the
		# cursor's own motion: its world point is dragged around by the camera's lead, lag
		# and arena clamp, which let player movement steer the guard. Mobile and controller
		# aim already arrives in hand space, so it still reads its absolute target.
		var charged_guard_hand_target: Vector2 = charged_guard_lock_hand_offset
		if mobile_input_enabled or input_mode == INPUT_MODE_CONTROLLER:
			var charged_guard_aim_relative: Vector2 = virtual_aim_point - global_position
			charged_guard_hand_target = charged_guard_clamp_hand_offset(charged_guard_aim_relative, charged_guard_lock_radius, CHARGED_GUARD_MIN_HAND_RADIUS, charged_guard_radial_direction)
		else:
			charged_guard_hand_target = charged_guard_clamp_hand_offset(charged_guard_lock_hand_offset + charged_guard_cursor_motion, charged_guard_lock_radius, CHARGED_GUARD_MIN_HAND_RADIUS, charged_guard_radial_direction)
			# The blade turns with the cursor's motion about the hand, bounded by the
			# sword's own turn cap so a fast sweep cannot snap the guard around.
			var charged_guard_blade_turn: float = charged_guard_angular_travel(charged_guard_lock_hand_offset, charged_guard_cursor_motion) * charged_reposition_scale
			if max_turn_deg > 0.0:
				var charged_guard_turn_cap: float = deg_to_rad(max_turn_deg) * delta
				charged_guard_blade_turn = clampf(charged_guard_blade_turn, -charged_guard_turn_cap, charged_guard_turn_cap)
			charged_guard_lock_angle += charged_guard_blade_turn
		charged_guard_lock_hand_offset = charged_guard_repositioned_hand_offset(charged_guard_lock_hand_offset, charged_guard_hand_target, CHARGED_GUARD_REPOSITION_SPEED * charged_reposition_scale, delta)
		if charged_guard_lock_hand_offset.length_squared() >= CHARGED_GUARD_MIN_HAND_RADIUS * CHARGED_GUARD_MIN_HAND_RADIUS:
			charged_guard_radial_direction = charged_guard_lock_hand_offset.normalized()
	aim_angle += desired_step
	# Second joint — the elbow trails the shoulder's aim at its own catch-up speed,
	# instead of snapping to it instantly like every other single-pivot style.
	elbow_angle = lerp_angle(elbow_angle, aim_angle, clampf(_current_elbow_joint_speed() * delta, 0.0, 1.0))

func _authored_metronome_mode_applies() -> bool:
	return combat_contact_preset != 4 and _is_metronome_style() and get_combat_contact_setting("authored_metronome_enabled") >= 0.5

func _authored_metronome_pauses_phase() -> bool:
	return _authored_metronome_mode_applies() and authored_metronome_energy <= 0.0

## How brightly the sword's own trails draw -- red tip and gold hilt -- as a multiplier on
## their unchanged base alphas. Outside the metronome this is exactly 1.0, so every other
## sword style keeps the trails it has always had. Inside it, arc energy is the one thing
## that drives them: a resting blade leaves a 10% trace, a fully driven one peaks 15%
## brighter than before (0.45 -> 0.5175 red, 0.55 -> 0.6325 gold), and the ramp between the
## two is linear, so nothing pops.
##
## Gated on the mode rather than on the ACTIVE enum member on purpose: energy is still zero
## on the first frame of a swing, so gating on ACTIVE would flash a full-brightness trail
## for that one frame and then drop it. The mode is already true before the swing lands.
static func sword_trail_visibility_scale(energy: float, metronome_active: bool, minimum: float = SWORD_TRAIL_MIN_VISIBILITY, maximum: float = SWORD_TRAIL_MAX_VISIBILITY) -> float:
	if not metronome_active:
		return 1.0
	return lerpf(minimum, maximum, clampf(energy, 0.0, 1.0))

func _sword_trail_visibility_scale() -> float:
	return sword_trail_visibility_scale(authored_metronome_energy, _authored_metronome_mode_applies())

## Arc energy is the single authority for how wide the metronome opens.
## Authored aim travel above the wake threshold fills it. Once the idle grace
## passes with no authored input the energy bleeds away, and the eased arc
## settles back down until the blade is simply pointing at the mouse again.
func _update_authored_metronome_state(delta: float) -> void:
	if not _authored_metronome_mode_applies():
		authored_metronome_state = AuthoredMetronomeState.INACTIVE
		authored_metronome_energy = 0.0
		authored_metronome_active_idle_time = 0.0
		authored_metronome_ready_idle_time = 0.0
		authored_metronome_swing_blend = 1.0
		authored_metronome_sheathe_alpha = 1.0
		return
	if authored_metronome_state == AuthoredMetronomeState.INACTIVE:
		authored_metronome_state = AuthoredMetronomeState.READY
		authored_metronome_energy = 0.0
		authored_metronome_active_idle_time = 0.0
		authored_metronome_ready_idle_time = 0.0
		authored_metronome_swing_blend = 0.0
		authored_metronome_sheathe_alpha = 1.0
	var aim_speed: float = charged_guard_authored_aim_velocity.length()
	# A charging, locked or blue guard owns the sword's pose, so it counts exactly like real
	# aim movement: it wakes a sheathed metronome and holds the sheathe timer at zero instead
	# of letting the blade fade out from under the guard. The timer is held at zero rather
	# than frozen mid-count because a guard is always acquired out of movement, which has
	# already zeroed it -- holding it means the full sheathe delay runs again after release
	# instead of the sword vanishing the instant the guard ends. A running gesture ability
	# is the same claim made by a thrust: the blade is out and being driven, so it must not
	# be treated as idle and fade away mid-attack.
	var keeps_sword_drawn: bool = aim_speed >= AUTHORED_METRONOME_ACTIVITY_SPEED or _charged_guard_engaged() or charged_guard_gesture_state != ChargedGuardGesture.NONE
	var wake_speed: float = maxf(AUTHORED_METRONOME_ACTIVITY_SPEED, get_combat_contact_setting("authored_metronome_wake_speed"))
	if authored_metronome_state == AuthoredMetronomeState.SHEATHED and keeps_sword_drawn:
		authored_metronome_state = AuthoredMetronomeState.READY
		authored_metronome_ready_idle_time = 0.0
	if aim_speed >= wake_speed:
		authored_metronome_active_idle_time = 0.0
		var build_rate: float = maxf(0.01, get_combat_contact_setting("authored_metronome_energy_build"))
		authored_metronome_energy = minf(1.0, authored_metronome_energy + build_rate * delta)
	else:
		authored_metronome_active_idle_time += delta
		if authored_metronome_active_idle_time >= maxf(0.05, get_combat_contact_setting("authored_metronome_idle_grace")):
			var fade_rate: float = maxf(0.01, get_combat_contact_setting("authored_metronome_energy_fade"))
			authored_metronome_energy = maxf(0.0, authored_metronome_energy - fade_rate * delta)
	if authored_metronome_energy > 0.0:
		authored_metronome_state = AuthoredMetronomeState.ACTIVE
		authored_metronome_ready_idle_time = 0.0
	elif authored_metronome_state != AuthoredMetronomeState.SHEATHED:
		authored_metronome_state = AuthoredMetronomeState.READY
		if keeps_sword_drawn:
			authored_metronome_ready_idle_time = 0.0
		else:
			authored_metronome_ready_idle_time += delta
			if authored_metronome_ready_idle_time >= maxf(0.05, get_combat_contact_setting("authored_metronome_sheathe_time")):
				authored_metronome_state = AuthoredMetronomeState.SHEATHED
	# The arc opens and closes on an eased curve, so energy swells the metronome
	# in and lets it settle out instead of snapping between the two extremes.
	authored_metronome_swing_blend = smoothstep(0.0, 1.0, authored_metronome_energy)
	var target_sheathe_alpha: float = 0.0 if authored_metronome_state == AuthoredMetronomeState.SHEATHED else 1.0
	authored_metronome_sheathe_alpha = move_toward(authored_metronome_sheathe_alpha, target_sheathe_alpha, AUTHORED_METRONOME_SHEATHE_FADE_RATE * delta)

func _style_default_swing_frequency() -> float:
	match sword_style:
		SwordStyle.THRUST: return thrust_swing_frequency
		SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3, SwordStyle.MOULINET_4: return moulinet_swing_frequency
		SwordStyle.THRUST_METRONOME: return thrust_swing_frequency
		_: return metronome_swing_frequency

func _sword_cycle_frequency() -> float:
	var base_freq: float = get_combat_hand_setting("frequency")
	var flow_ratio: float = clampf(visual_flow / 100.0, 0.0, 1.0)
	if combat_contact_preset == 3:
		# Preset 3: Dynamic single form (Metronome V) - scales speed with flow
		var min_speed_scale: float = get_combat_contact_setting("p3_min_speed_scale")
		base_freq *= lerpf(min_speed_scale, 1.0, flow_ratio)
	elif combat_contact_preset == 4:
		# Preset 4: Form Evolution - frequency scales dynamically per stage
		if flow_ratio < 0.35:
			var stage1_t: float = flow_ratio / 0.35
			base_freq = lerpf(0.40, base_freq, stage1_t)
		elif flow_ratio < 0.70:
			var stage2_t: float = (flow_ratio - 0.35) / 0.35
			base_freq = lerpf(base_freq, base_freq * 1.15, stage2_t)
		else:
			var stage3_t: float = (flow_ratio - 0.70) / 0.30
			base_freq = lerpf(base_freq * 1.15, base_freq * 1.40, stage3_t)
	return base_freq

func _style_default_rotation_speed() -> float:
	match sword_style:
		SwordStyle.THRUST: return thrust_rotation_speed
		SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3, SwordStyle.MOULINET_4: return moulinet_rotation_speed
		SwordStyle.THRUST_METRONOME: return thrust_rotation_speed
		_: return metronome_rotation_speed

func _current_rotation_speed() -> float:
	return get_combat_hand_setting("rotation")

func _style_default_arc_degrees() -> float:
	match sword_style:
		SwordStyle.THRUST: return thrust_arc_degrees
		SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3, SwordStyle.MOULINET_4: return moulinet_arc_degrees
		SwordStyle.THRUST_METRONOME: return thrust_arc_degrees
		_: return metronome_arc_degrees

func _current_sword_arc_degrees() -> float:
	var arc: float = get_combat_hand_setting("arc")
	var flow_ratio: float = clampf(visual_flow / 100.0, 0.0, 1.0)
	if combat_contact_preset == 3:
		var min_arc_scale: float = get_combat_contact_setting("p3_min_arc_scale")
		arc *= lerpf(min_arc_scale, 1.0, flow_ratio)
	var active_phase: float = sword_phase if sword_phase != 0.0 or swing_time == 0.0 else swing_time * TAU * _sword_cycle_frequency()
	var phase_arc_bonus: float = absf(cos(active_phase)) * swing_phase_bonus
	return arc * (1.0 + phase_arc_bonus)

func set_combat_contact_preset(preset: int) -> void:
	combat_contact_preset = clampi(preset, 1, 4)

func copy_preset_settings(source_preset: int, target_preset: int) -> void:
	var src_p: int = clampi(source_preset, 1, 4)
	var tgt_p: int = clampi(target_preset, 1, 4)
	if src_p == tgt_p: return

	# 1. Copy contact settings
	var src_contact_key: String = str(src_p)
	var tgt_contact_key: String = str(tgt_p)
	var source_contact: Dictionary = combat_contact_settings.get(src_contact_key, {})
	var copied_contact: Dictionary = source_contact.duplicate(true)
	# If source had no explicit overrides, populate from its resolved getters
	var saved_preset: int = combat_contact_preset
	combat_contact_preset = src_p
	for setting_name: String in [
		"slide_contact_tolerance", "slide_angle", "slide_cling", "slide_friction",
		"slide_speed", "slide_duration", "slide_travel", "slide_spread",
		"clash_player_recoil", "clash_enemy_recoil", "clash_hitstop", "clash_stagger",
		"clash_recovery", "clash_flow", "clash_contact_tolerance", "clash_angle_min",
		"clash_angle_max", "clash_cooldown", "parry_contact_tolerance", "parry_rotation_speed",
		"parry_cooldown", "parry_player_recoil", "parry_enemy_recoil", "parry_hitstop",
		"parry_stagger", "parry_recovery", "flesh_hitstop_min", "flesh_hitstop_max",
		"flesh_stagger_min", "flesh_stagger_max", "flesh_shake_strength", "flesh_shake_duration",
		"flesh_zoom", "flesh_zoom_duration", "flesh_recoil", "flesh_impact",
		"flesh_contact_drag", "flesh_contact_drag_recovery",
		"hilt_contact_drag", "hilt_contact_drag_recovery",
		"farmable_contact_drag", "farmable_contact_drag_recovery", "farmable_hitstop",
		"contact_hitstop", "contact_shake_strength", "contact_shake_duration", "contact_zoom",
		"contact_zoom_duration", "contact_impact", "slide_hitstop", "slide_shake_strength",
		"slide_shake_duration", "slide_zoom", "slide_zoom_duration", "slide_impact",
		"clash_shake_strength", "clash_shake_duration", "clash_zoom", "clash_zoom_duration",
		"clash_impact", "parry_shake_strength", "parry_shake_duration", "parry_zoom",
		"parry_zoom_duration", "parry_focus", "parry_focus_duration", "parry_impact",
		"blade_freeze_duration", "bite_velocity_transfer",
		"blade_recoil_degrees", "blade_recoil_return",
		"rebound_flow_boost", "grip_authority_duration", "grip_turn_speed_mult", "apex_hang_time", "apex_hang_duration",
		"blade_roll_speed",
		"hilt_bash_enabled", "hilt_bash_knockback", "hilt_bash_stun", "hilt_bash_damage",
		"p3_min_arc_scale", "p3_min_speed_scale", "p3_min_turn_scale",
		"p4_stage1_end", "p4_stage2_end", "form_blend_smoothing", "charged_guard_enabled"
	]:
		if not copied_contact.has(setting_name):
			copied_contact[setting_name] = get_combat_contact_setting(setting_name)
	for authored_key: String in CombatSettingsConfig.AUTHORED_METRONOME_TUNING_KEYS:
		if not copied_contact.has(authored_key):
			copied_contact[authored_key] = get_combat_contact_setting(authored_key)
	combat_contact_preset = saved_preset
	combat_contact_settings[tgt_contact_key] = copied_contact

	# 2. Copy hand settings across all sword styles
	for style_idx: int in range(SwordStyle.size()):
		var src_hand_key: String = "%d:%d" % [src_p, style_idx]
		var tgt_hand_key: String = "%d:%d" % [tgt_p, style_idx]
		var source_hand: Dictionary = combat_hand_settings.get(src_hand_key, {})
		var copied_hand: Dictionary = source_hand.duplicate(true)
		combat_contact_preset = src_p
		var saved_style: SwordStyle = sword_style
		sword_style = style_idx as SwordStyle
		for hand_key: String in [
			"min", "max", "scale", "mouse_drag", "max_turn_speed", "strike_commitment", "swing_commitment", "swing_commitment_duration", "windup_profile", "windup_fraction", "recovery_fraction", "windup_speed", "strike_speed", "recovery_speed", "forward_impulse", "forward_impulse_timing", "backstep_impulse", "backstep_impulse_timing", "action_commitment_strength", "action_commitment_start", "action_commitment_end",
			"radial_response", "rotation", "arc", "frequency", "tempo_assist_enabled", "directional_arc_opening_enabled", "authored_step_enabled", "swing_gesture_gearing_degrees", "thrusts_per_cycle", "moulinet_aim_smoothing", "slide_sparks", "clash_sparks", "parry_sparks",
			"bind_enabled", "bind_capture_time", "bind_contact_tolerance", "bind_pressure_min", "bind_retention_strength", "bind_sword_speed", "bind_release_grace", "bind_max_duration", "bind_rebind_cooldown", "bind_focus_time_scale", "bind_focus_zoom", "bind_focus_bias", "bind_focus_response", "bind_scrape_interval", "bind_disengage_min_time", "bind_disengage_min_travel", "bind_disengage_fraction_delta", "bind_disengage_endpoint", "bind_disengage_leverage", "bind_reentry_window", "bind_reentry_min_speed", "bind_reentry_inward_speed", "bind_reentry_damage", "bind_reentry_stagger", "bind_beat_pressure", "bind_beat_spike", "bind_beat_leverage", "bind_beat_stagger", "bind_beat_recoil", "bind_failed_beat_recoil", "bind_debug", "bind_slide_contact_tolerance", "bind_slide_angle", "bind_slide_cling", "bind_slide_friction", "bind_slide_speed", "bind_slide_duration"
		]:
			if hand_key in EXPERIMENTAL_BIND_SETTING_KEYS and style_idx != int(SwordStyle.METRONOME_BIND_B):
				continue
			if not copied_hand.has(hand_key):
				copied_hand[hand_key] = get_combat_hand_setting(hand_key)
		sword_style = saved_style
		combat_contact_preset = saved_preset
		combat_hand_settings[tgt_hand_key] = copied_hand

func _combat_hand_key() -> String:
	var resolved_style: int = int(SwordStyle.METRONOME_BIND_B) if sword_style == SwordStyle.METRONOME_BIND else int(sword_style)
	return "%d:%d" % [combat_contact_preset, resolved_style]

func _canonical_bind_hand_key() -> String:
	return "%d:%d" % [combat_contact_preset, int(SwordStyle.METRONOME_BIND_B)]

func _default_hand_ranges() -> Vector2:
	if combat_contact_preset >= 2 and _is_metronome_style():
		return Vector2(5.0, 70.0)
	if sword_style == SwordStyle.THRUST: return Vector2(15.0, 63.0)
	if sword_style in [SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3]: return Vector2(20.0, 50.0)
	return Vector2(30.0, 30.0)

func get_combat_hand_setting_for_sword(sword_id: String, setting: String) -> float:
	if is_experimental_bind_form() and setting in EXPERIMENTAL_BIND_SETTING_KEYS:
		return _get_shared_combat_hand_setting(setting)
	var weapon_overrides: Dictionary = combat_weapon_hand_settings.get(sword_id, {}) as Dictionary
	var values: Dictionary = weapon_overrides.get(_combat_hand_key(), {}) as Dictionary
	if values.has(setting):
		return float(values[setting])
	return _get_shared_combat_hand_setting(setting)

func set_combat_hand_setting_for_sword(sword_id: String, setting: String, value: float) -> void:
	if is_experimental_bind_form() and setting in EXPERIMENTAL_BIND_SETTING_KEYS:
		set_combat_hand_setting(setting, value)
		return
	if not combat_weapon_hand_settings.has(sword_id):
		combat_weapon_hand_settings[sword_id] = {}
	var weapon_overrides: Dictionary = combat_weapon_hand_settings[sword_id] as Dictionary
	var key: String = _combat_hand_key()
	if not weapon_overrides.has(key):
		weapon_overrides[key] = {}
	var values: Dictionary = weapon_overrides[key] as Dictionary
	values[setting] = float(clampi(roundi(value), 2, 15)) if setting == "thrusts_per_cycle" else value

func get_combat_hand_setting(setting: String) -> float:
	if is_experimental_bind_form() and setting in EXPERIMENTAL_BIND_SETTING_KEYS:
		return _get_shared_combat_hand_setting(setting)
	var weapon_overrides: Dictionary = combat_weapon_hand_settings.get(equipped_sword_id, {}) as Dictionary
	var values: Dictionary = weapon_overrides.get(_combat_hand_key(), {}) as Dictionary
	if values.has(setting):
		return float(values[setting])
	return _get_shared_combat_hand_setting(setting)

func _get_shared_combat_hand_setting(setting: String) -> float:
	var key: String = _canonical_bind_hand_key() if is_experimental_bind_form() and setting in EXPERIMENTAL_BIND_SETTING_KEYS else _combat_hand_key()
	var defaults: Vector2 = _default_hand_ranges()
	var values: Dictionary = combat_hand_settings.get(key, {})
	var distinct: bool = combat_contact_preset >= 2
	var is_metro: bool = _is_metronome_style()
	match setting:
		"min": return float(values.get("min", defaults.x))
		"max": return float(values.get("max", defaults.y))
		"scale": return float(values.get("scale", 4.0 if (distinct and is_metro) else 1.0))
		"mouse_drag": return float(values.get("mouse_drag", 20.0 if (distinct and is_metro) else 10.0))
		"max_turn_speed": return float(values.get("max_turn_speed", 0.0))
		"strike_commitment": return float(values.get("strike_commitment", 0.0))
		"swing_commitment": return float(values.get("swing_commitment", 0.0))
		"swing_commitment_duration": return float(values.get("swing_commitment_duration", SWING_COMMITMENT_DURATION_DEFAULT))
		"tempo_assist_enabled": return float(values.get("tempo_assist_enabled", 0.0))
		"directional_arc_opening_enabled": return float(values.get("directional_arc_opening_enabled", 0.0))
		"authored_step_enabled": return float(values.get("authored_step_enabled", 0.0))
		"backstep_enabled": return float(values.get("backstep_enabled", 0.0))
		"swing_gesture_gearing_degrees": return float(values.get("swing_gesture_gearing_degrees", 60.0))
		"windup_profile": return float(values.get("windup_profile", 0.0))
		"windup_fraction": return float(values.get("windup_fraction", 0.30))
		"recovery_fraction": return float(values.get("recovery_fraction", 0.20))
		"windup_speed": return float(values.get("windup_speed", 0.35))
		"strike_speed": return float(values.get("strike_speed", 2.20))
		"recovery_speed": return float(values.get("recovery_speed", 0.35))
		"forward_impulse": return float(values.get("forward_impulse", 0.0))
		"forward_impulse_timing": return float(values.get("forward_impulse_timing", 0.30))
		"backstep_impulse": return float(values.get("backstep_impulse", 0.0))
		"backstep_impulse_timing": return float(values.get("backstep_impulse_timing", 0.30))
		# Late-stroke action commitment is active for Form I Metronome. Strength 0
		# keeps gameplay neutral and preserves the old freely redirectable behavior.
		"action_commitment_strength": return float(values.get("action_commitment_strength", 0.0))
		"action_commitment_start": return float(values.get("action_commitment_start", 0.60))
		"action_commitment_end": return float(values.get("action_commitment_end", 0.90))
		"radial_response": return float(values.get("radial_response", 0.2 if (distinct and is_metro) else 1.0))
		"rotation": return float(values.get("rotation", 9.5 if (distinct and is_metro) else _style_default_rotation_speed()))
		"arc": return float(values.get("arc", 105.0 if (distinct and is_metro) else _style_default_arc_degrees()))
		"frequency": return float(values.get("frequency", 0.65 if (distinct and is_metro) else _style_default_swing_frequency()))
		"thrusts_per_cycle": return float(clampi(roundi(float(values.get("thrusts_per_cycle", 7.0))), 2, 15))
		"moulinet_aim_smoothing": return float(values.get("moulinet_aim_smoothing", 6.0))
		"slide_sparks": return float(values.get("slide_sparks", 6.0))
		"clash_sparks": return float(values.get("clash_sparks", 9.0 if distinct else 6.0))
		"parry_sparks": return float(values.get("parry_sparks", 9.0))
		# Bind values are shared by both legacy bind IDs and every weapon.
		"bind_enabled": return float(values.get("bind_enabled", 1.0))
		"bind_capture_time": return float(values.get("bind_capture_time", 0.10))
		"bind_contact_tolerance": return float(values.get("bind_contact_tolerance", 16.0))
		"bind_pressure_min": return float(values.get("bind_pressure_min", 8.0))
		"bind_retention_strength": return float(values.get("bind_retention_strength", 0.35))
		"bind_sword_speed": return float(values.get("bind_sword_speed", 1.0))
		"bind_release_grace": return float(values.get("bind_release_grace", 0.12))
		"bind_max_duration": return float(values.get("bind_max_duration", 1.40))
		"bind_rebind_cooldown": return float(values.get("bind_rebind_cooldown", 0.28))
		"bind_focus_time_scale": return float(values.get("bind_focus_time_scale", 0.60))
		"bind_focus_zoom": return float(values.get("bind_focus_zoom", 0.15))
		"bind_focus_bias": return float(values.get("bind_focus_bias", 0.60))
		"bind_focus_response": return float(values.get("bind_focus_response", 8.0))
		"bind_scrape_interval": return float(values.get("bind_scrape_interval", 0.28))
		"bind_disengage_min_time": return float(values.get("bind_disengage_min_time", 0.10))
		"bind_disengage_min_travel": return float(values.get("bind_disengage_min_travel", 14.0))
		"bind_disengage_fraction_delta": return float(values.get("bind_disengage_fraction_delta", 0.12))
		"bind_disengage_endpoint": return float(values.get("bind_disengage_endpoint", 0.18))
		"bind_disengage_leverage": return float(values.get("bind_disengage_leverage", 0.08))
		"bind_reentry_window": return float(values.get("bind_reentry_window", 0.34))
		"bind_reentry_min_speed": return float(values.get("bind_reentry_min_speed", 150.0))
		"bind_reentry_inward_speed": return float(values.get("bind_reentry_inward_speed", 55.0))
		"bind_reentry_damage": return float(values.get("bind_reentry_damage", 1.25))
		"bind_reentry_stagger": return float(values.get("bind_reentry_stagger", 1.20))
		"bind_beat_pressure": return float(values.get("bind_beat_pressure", 300.0))
		"bind_beat_spike": return float(values.get("bind_beat_spike", 120.0))
		"bind_beat_leverage": return float(values.get("bind_beat_leverage", 0.10))
		"bind_beat_stagger": return float(values.get("bind_beat_stagger", 0.28))
		"bind_beat_recoil": return float(values.get("bind_beat_recoil", 110.0))
		"bind_failed_beat_recoil": return float(values.get("bind_failed_beat_recoil", 85.0))
		"bind_debug": return float(values.get("bind_debug", 1.0))
		_: return 0.0

func set_combat_hand_setting(setting: String, value: float) -> void:
	var key: String = _canonical_bind_hand_key() if is_experimental_bind_form() and setting in EXPERIMENTAL_BIND_SETTING_KEYS else _combat_hand_key()
	if not combat_hand_settings.has(key): combat_hand_settings[key] = {}
	var values: Dictionary = combat_hand_settings[key]
	var current_minimum: float = get_combat_hand_setting("min")
	var current_maximum: float = get_combat_hand_setting("max")
	values[setting] = float(clampi(roundi(value), 2, 15)) if setting == "thrusts_per_cycle" else value
	if setting == "min" and current_maximum < value: values["max"] = value
	if setting == "max" and current_minimum > value: values["min"] = value

## Cursor distance at which the hand reaches full extension, in world px. Past this the
## hand's reach is clamped and a sideways cursor move swings the blade proportionally
## less, so this is also the point where the guard's break measure starts gearing the
## cursor's sideways speed down. Sole authority for that figure: _mouse_controlled_hand_radius
## below and the break measure must never disagree about where hand range ends.
func _cursor_hand_reach_limit() -> float:
	var minimum: float = get_combat_hand_setting("min")
	var maximum: float = maxf(get_combat_hand_setting("max"), minimum)
	var reach_scale: float = maxf(get_combat_hand_setting("scale"), 0.01)
	return maxf(minimum + (maximum - minimum) * reach_scale, minimum + 0.001)

func _mouse_controlled_hand_radius() -> float:
	var minimum: float = get_combat_hand_setting("min")
	var maximum: float = maxf(get_combat_hand_setting("max"), minimum)
	var reach_scale: float = maxf(get_combat_hand_setting("scale"), 0.01)
	if mobile_input_enabled:
		var geared_magnitude: float = pow(clampf(mobile_aim_direction.length(), 0.0, 1.0), reach_scale)
		return lerpf(minimum, maximum, geared_magnitude)
	if input_mode == INPUT_MODE_CONTROLLER:
		return lerpf(minimum, maximum, clampf(controller_aim_strength, 0.0, 1.0))
	var mouse_distance: float = global_position.distance_to(virtual_aim_point)
	var input_maximum: float = _cursor_hand_reach_limit()
	var amount: float = clampf(inverse_lerp(minimum, input_maximum, mouse_distance), 0.0, 1.0)
	return lerpf(minimum, maximum, amount)

func get_combat_contact_setting(setting: String) -> float:
	# Slide behavior has one authority: the active contact preset. Retired
	# bind_slide_* save fields are intentionally ignored.
	return _get_base_combat_contact_setting(setting)

## Training Tools' Per Preset sections edit the shared contact profile even when
## a Bind form has a local slide-entry override. Gameplay should use
## get_combat_contact_setting(); editors that explicitly expose the base preset
## use this accessor so the displayed number matches the value being edited.
func get_base_combat_contact_setting(setting: String) -> float:
	return _get_base_combat_contact_setting(setting)

func _get_base_combat_contact_setting(setting: String) -> float:
	var preset_key: String = str(combat_contact_preset)
	var values: Dictionary = combat_contact_settings.get(preset_key, {})
	if values.has(setting):
		return float(values[setting])
	var distinct: bool = combat_contact_preset >= 2
	var result: float = 0.0
	match setting:
		"slide_contact_tolerance":
			result = ParryRules.PRESET_2_SLIDE_CONTACT_TOLERANCE if distinct else ParryRules.UNIVERSAL_SLIDE_CONTACT_TOLERANCE
		"slide_angle":
			result = ParryRules.PRESET_2_SLIDE_ANGLE_DEGREES if distinct else ParryRules.UNIVERSAL_SLIDE_ANGLE_DEGREES
		"slide_cling":
			result = ParryRules.PRESET_2_SLIDE_CLING if distinct else ParryRules.SLIDE_CLING_DURATION
		"slide_friction":
			result = 0.45 if distinct else 0.70
		"slide_speed":
			result = ParryRules.PRESET_2_SLIDE_SPEED_MULTIPLIER if distinct else ParryRules.SLIDE_SWORD_SPEED_MULTIPLIER
		"slide_duration":
			result = ParryRules.PRESET_2_SLIDE_DURATION if distinct else ParryRules.SLIDE_VISUAL_DURATION
		"slide_travel":
			result = ParryRules.PRESET_2_SLIDE_TRAVEL if distinct else ParryRules.SLIDE_SPARK_TRAVEL_DISTANCE
		"slide_spread":
			result = ParryRules.PRESET_2_SLIDE_SPREAD if distinct else ParryRules.SLIDE_SPARK_SPREAD
		"clash_player_recoil":
			result = ParryRules.PRESET_2_CLASH_RECOIL if distinct else clash_recoil_strength
		"clash_enemy_recoil":
			result = ParryRules.PRESET_2_CLASH_RECOIL if distinct else ParryRules.CLASH_RECOIL_TO_ENEMY
		"clash_hitstop":
			result = ParryRules.PRESET_2_CLASH_HITSTOP if distinct else clash_hit_stop
		"clash_stagger":
			result = ParryRules.PRESET_2_CLASH_STAGGER if distinct else ParryRules.CLASH_STAGGER_DURATION
		"clash_recovery":
			result = ParryRules.PRESET_2_CLASH_RECOVERY if distinct else clash_recovery_time
		"clash_flow":
			result = ParryRules.PRESET_2_CLASH_FLOW if distinct else clash_flow_penalty
		"clash_contact_tolerance":
			result = 18.0
		"clash_angle_min":
			result = ParryRules.PRESET_2_CLASH_ANGLE_MIN if distinct else 25.0
		"clash_angle_max":
			result = ParryRules.PRESET_2_CLASH_ANGLE_MAX if distinct else 85.0
		"clash_cooldown":
			result = ParryRules.PRESET_2_CLASH_COOLDOWN if distinct else 0.35
		"parry_contact_tolerance":
			result = ParryRules.UNIVERSAL_PARRY_CONTACT_TOLERANCE
		"parry_rotation_speed":
			result = ParryRules.UNIVERSAL_BLADE_ROTATION_SPEED
		"parry_cooldown":
			result = ParryRules.UNIVERSAL_PARRY_COOLDOWN_DURATION
		"parry_player_recoil":
			result = ParryRules.PRESET_2_PARRY_PLAYER_RECOIL if distinct else parry_recoil_strength
		"parry_enemy_recoil":
			result = ParryRules.PRESET_2_PARRY_ENEMY_RECOIL if distinct else 180.0
		"parry_hitstop":
			result = ParryRules.PRESET_2_PARRY_HITSTOP if distinct else parry_hit_stop
		"parry_stagger":
			result = ParryRules.PRESET_2_PARRY_STAGGER if distinct else ParryRules.UNIVERSAL_PARRY_STAGGER_DURATION
		"parry_recovery":
			result = ParryRules.PRESET_2_PARRY_RECOVERY if distinct else clash_recovery_time * 1.4
		"flesh_hitstop_min": result = flesh_contact_hitstop_min
		"flesh_hitstop_max": result = flesh_contact_hitstop_max
		"flesh_stagger_min": result = enemy_stagger_min
		"flesh_stagger_max": result = enemy_stagger_max
		"flesh_shake_strength": result = flesh_contact_screen_shake_strength
		"flesh_shake_duration": result = flesh_contact_screen_shake_duration
		"flesh_zoom": result = 0.025
		"flesh_zoom_duration": result = 0.10
		"flesh_recoil": result = flesh_contact_recoil_strength
		"flesh_impact": result = 1.0
		"flesh_contact_drag": result = flesh_contact_drag_dip
		"flesh_contact_drag_recovery": result = flesh_contact_drag_recovery
		"hilt_contact_drag": result = hilt_contact_drag_dip
		"hilt_contact_drag_recovery": result = hilt_contact_drag_recovery
		"farmable_contact_drag": result = farmable_contact_drag_dip
		"farmable_contact_drag_recovery": result = farmable_contact_drag_recovery
		"farmable_hitstop": result = farmable_hitstop
		"contact_hitstop": result = 0.0
		"contact_shake_strength": result = 0.0
		"contact_shake_duration": result = 0.08
		"contact_zoom": result = 0.0
		"contact_zoom_duration": result = 0.08
		"contact_impact": result = 0.3
		"slide_hitstop": result = 0.0
		"slide_shake_strength": result = 0.4 if distinct else 0.0
		"slide_shake_duration": result = 0.08
		"slide_zoom": result = 0.0
		"slide_zoom_duration": result = 0.08
		"slide_impact": result = 0.35
		"clash_shake_strength": result = 9.0 if distinct else 0.0
		"clash_shake_duration": result = 0.22
		"clash_zoom": result = 0.03 if distinct else 0.0
		"clash_zoom_duration": result = 0.10
		"clash_impact": result = 1.2 if distinct else 0.8
		"parry_shake_strength": result = 4.0 if distinct else 0.0
		"parry_shake_duration": result = 0.14
		"parry_zoom": result = 0.025 if distinct else 0.0
		"parry_zoom_duration": result = 0.12
		"parry_focus": result = 1.0 if distinct else 0.0
		"parry_focus_duration": result = 0.16
		"parry_impact": result = 1.4 if distinct else 0.8
		# --- Strike Kinetics & Rebound Flow ---
		# blade_freeze_duration now only fires for clash/parry (see _trigger_clash/_trigger_parry);
		# flesh and hilt contact use contact drag instead, never a hard freeze.
		"blade_freeze_duration": result = 0.05 if distinct else 0.0
		# Still read while blade_freeze_left > 0.0 (clash/parry) to compute how much
		# real hilt/body motion carries through the blade during that freeze window.
		"bite_velocity_transfer": result = 0.85
		"blade_recoil_degrees": result = 18.0 if distinct else 0.0
		"blade_recoil_return": result = 360.0 if distinct else 0.0
		"rebound_flow_boost": result = 2.2 if distinct else 1.0
		"grip_authority_duration": result = 0.18 if distinct else 0.0
		"grip_turn_speed_mult": result = 2.5 if distinct else 1.0
		"apex_hang_time": result = 0.04 if distinct else 0.0
		"apex_hang_duration": result = 0.14
		"charged_guard_enabled": result = 0.0
		"charged_guard_position_charge_enabled": result = 0.0
		"charged_guard_gestures_enabled": result = 0.0
		"charged_guard_hold_duration": result = 0.20
		"charged_guard_awaken_duration": result = 1.0
		"charged_guard_break_speed": result = 600.0
		"charged_guard_hold_limit": result = 4.0
		"charged_guard_acquisition_window": result = 0.65
		"charged_guard_pommel_alignment": result = 0.82
		"charged_guard_pommel_speed": result = 90.0
		"charged_guard_pommel_travel": result = 14.0
		"charged_guard_pommel_intent_time": result = 0.06
		"charged_guard_near_body_radius": result = 48.0
		# The three charge boosts are opt-in and off by default. Stacked, they charge a guard in a
		# fraction of the guard's own charge time, so the charge-time slider stops describing what
		# happens; with them at zero the slider is the whole charge rate, and each boost becomes a
		# deliberate choice to make one specific situation charge faster.
		"charged_guard_near_body_rate": result = 0.0
		"charged_guard_recent_motion_rate": result = 0.0
		"charged_guard_pommel_rate": result = 0.0
		"authored_metronome_enabled": result = 0.0
		"authored_metronome_wake_speed": result = 350.0
		"authored_metronome_energy_build": result = 0.8
		"authored_metronome_energy_fade": result = 0.35
		"authored_metronome_idle_grace": result = 2.0
		"authored_metronome_sheathe_time": result = 1.0
		# Roll units/sec; going from +1 to -1 is a distance of 2.0, so 8.0
		# gives a ~0.25s flip -- snappy but visible, not a hard pop.
		"blade_roll_speed": result = 8.0
		# --- Hilt Bash & Point-Blank ---
		"hilt_bash_enabled": result = 1.0 if distinct else 0.0
		"hilt_bash_knockback": result = 340.0
		"hilt_bash_stun": result = 0.45
		"hilt_bash_damage": result = 6.0
		# --- Preset 3 Dynamic Metronome Scaling ---
		"p3_min_arc_scale": result = 0.55
		"p3_min_speed_scale": result = 0.65
		"p3_min_turn_scale": result = 0.60
		# --- Preset 4 Form Evolution Breakpoints & Smoothing ---
		"p4_stage1_end": result = 35.0
		"p4_stage2_end": result = 70.0
		"form_blend_smoothing": result = 8.0
		_:
			result = 0.0
	return result

func set_combat_contact_setting(setting: String, value: float) -> void:
	var preset_key: String = str(combat_contact_preset)
	if not combat_contact_settings.has(preset_key): combat_contact_settings[preset_key] = {}
	(combat_contact_settings[preset_key] as Dictionary)[setting] = value

func _update_combat_hand_radius(delta: float) -> void:
	var target_radius: float = _mouse_controlled_hand_radius()
	var response: float = clampf(get_combat_hand_setting("radial_response"), 0.01, 1.0)
	var response_weight: float = 1.0 - pow(1.0 - response, delta * 60.0)
	combat_hand_radius = lerpf(combat_hand_radius, target_radius, clampf(response_weight, 0.0, 1.0))

func _sword_transform() -> Dictionary:
	var base_angle: float = aim_angle
	var radius: float = combat_hand_radius
	var arc: float = _current_sword_arc_degrees()
	var raw_sine: float = sin(sword_phase if sword_phase != 0.0 or swing_time == 0.0 else swing_time * TAU * _sword_cycle_frequency())

	# --- PRESET 4: FORM EVOLUTION (Stage 1: A-Thrust -> Stage 2: Metronome V -> Stage 3: Moulinet ∞) ---
	if combat_contact_preset == 4:
		var blend_progress: float = clampf(p4_form_blend, 0.0, 1.0)
		var s1_end: float = clampf(get_combat_contact_setting("p4_stage1_end") / 100.0, 0.1, 0.5)
		var s2_end: float = clampf(get_combat_contact_setting("p4_stage2_end") / 100.0, s1_end + 0.1, 0.9)

		var t_data_thrust: Dictionary = _calculate_form_thrust(base_angle, radius, arc, raw_sine)
		var t_data_metro: Dictionary = _calculate_form_metronome(base_angle, radius, arc, raw_sine)
		var t_data_moulinet: Dictionary = _calculate_form_moulinet(base_angle, radius, arc)

		var result_start: Vector2 = Vector2.ZERO
		var result_angle: float = 0.0

		if blend_progress <= s1_end:
			# Morph from pure Thrusting A toward Metronome V
			var blend: float = blend_progress / s1_end
			result_start = (t_data_thrust["start"] as Vector2).lerp(t_data_metro["start"] as Vector2, blend)
			# Both forms are continuous offsets around the same aim angle; avoid shortest-arc branch snaps.
			result_angle = lerp_angle(float(t_data_thrust["angle"]), float(t_data_metro["angle"]), blend)
		elif blend_progress <= s2_end:
			# Morph from Metronome V toward Moulinet ∞
			var blend: float = (blend_progress - s1_end) / (s2_end - s1_end)
			result_start = (t_data_metro["start"] as Vector2).lerp(t_data_moulinet["start"] as Vector2, blend)
			result_angle = lerp_angle(float(t_data_metro["angle"]), float(t_data_moulinet["angle"]), blend)
		else:
			# High flow: Moulinet ∞ Overdrive
			result_start = (t_data_moulinet["start"] as Vector2)
			result_angle = float(t_data_moulinet["angle"])

		if blade_freeze_left > 0.0:
			result_angle = frozen_blade_world_angle
		return _apply_authored_metronome_pose({"start": result_start, "angle": result_angle, "arc_degrees": arc})

	# --- INDIVIDUAL FORMS (Presets 1, 2, 3) ---
	match sword_style:
		SwordStyle.METRONOME_WINDUP, SwordStyle.METRONOME_BIND, SwordStyle.METRONOME_BIND_B:
			var t_windup: Dictionary = _calculate_form_metronome(base_angle, radius, arc, raw_sine)
			if blade_freeze_left > 0.0:
				t_windup["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_windup)
		SwordStyle.THRUST:
			var t_thrust: Dictionary = _calculate_form_thrust(base_angle, radius, arc, raw_sine)
			if blade_freeze_left > 0.0:
				t_thrust["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_thrust)
		SwordStyle.MOULINET:
			var t_moul: Dictionary = _calculate_form_moulinet(base_angle, radius, arc)
			if blade_freeze_left > 0.0:
				t_moul["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_moul)
		SwordStyle.MOULINET_2:
			var t_moul2: Dictionary = _calculate_form_moulinet_2(base_angle, radius, arc)
			if blade_freeze_left > 0.0:
				t_moul2["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_moul2)
		SwordStyle.MOULINET_3:
			var t_moul3: Dictionary = _calculate_form_moulinet_3(base_angle, radius, arc)
			if blade_freeze_left > 0.0:
				t_moul3["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_moul3)
		SwordStyle.MOULINET_4:
			var t_moul4: Dictionary = _calculate_form_moulinet_4(base_angle, radius, arc)
			if blade_freeze_left > 0.0:
				t_moul4["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_moul4)
		SwordStyle.THRUST_METRONOME:
			var t_metro_thrust: Dictionary = _calculate_form_thrust_metronome(base_angle, radius, arc)
			if blade_freeze_left > 0.0:
				t_metro_thrust["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_metro_thrust)
		_:
			var t_metro: Dictionary = _calculate_form_metronome(base_angle, radius, arc, raw_sine)
			if blade_freeze_left > 0.0:
				t_metro["angle"] = frozen_blade_world_angle
			return _apply_authored_metronome_pose(t_metro)

func _apply_authored_metronome_pose(transform_data: Dictionary) -> Dictionary:
	if _authored_metronome_mode_applies():
		var metronome_angle: float = float(transform_data["angle"])
		transform_data["start"] = global_position + Vector2.RIGHT.rotated(aim_angle) * combat_hand_radius
		transform_data["angle"] = aim_angle + angle_difference(aim_angle, metronome_angle) * clampf(authored_metronome_swing_blend, 0.0, 1.0)
	return _apply_charged_guard_pose(transform_data)

func _apply_charged_guard_pose(transform_data: Dictionary) -> Dictionary:
	# One ordered chain owns the sword's pose: the normal aim pipeline, then the authored
	# metronome, then the charged guard, then a gesture ability. Every stage is a pure
	# no-op when it does not apply and the last stage to apply wins, so two systems can
	# never write the pose in the same frame -- not because they check each other's
	# flags, but because the chain is the only writer there is.
	if charged_guard_locked and get_combat_contact_setting("charged_guard_enabled") >= 0.5:
		transform_data["angle"] = charged_guard_lock_angle
		transform_data["start"] = global_position + charged_guard_lock_hand_offset
	return _apply_charged_guard_gesture_pose(transform_data)

## The lunging thrust's claim on the pose. By the time this runs the guard has already
## released, so it is the only stage writing: the blade lies along the drawn line and the
## hand drives out and back along it.
func _apply_charged_guard_gesture_pose(transform_data: Dictionary) -> Dictionary:
	if charged_guard_gesture_state == ChargedGuardGesture.THRUST:
		var extension: float = charged_guard_thrust_extension(charged_guard_gesture_phase_time, CHARGED_GUARD_THRUST_WINDUP, CHARGED_GUARD_THRUST_EXTEND, CHARGED_GUARD_THRUST_HOLD, CHARGED_GUARD_THRUST_RECOVER)
		transform_data["angle"] = charged_guard_gesture_direction.angle()
		transform_data["start"] = global_position + charged_guard_gesture_direction * maxf(2.0, charged_guard_gesture_hand_radius + CHARGED_GUARD_THRUST_REACH * extension)
		return transform_data
	if charged_guard_gesture_state == ChargedGuardGesture.WHIRLWIND:
		return _apply_charged_guard_whirlwind_pose(transform_data)
	return transform_data

## The whirlwind's claim on the pose: the whole sword sweeps one turn around the player,
## turning the way the circle was drawn. The hilt orbits the body at the distance the guard
## was already holding it, so the tip cuts a ring the whole way round, and the blade leads the
## sweep from the outward radial. The last of it eases both the hilt and the blade into
## wherever the player's aim has arrived by then, rather than handing control back cold -- the
## sword ends a whole turn from where it started, so an abrupt return would snap it back on
## the final frame.
func _apply_charged_guard_whirlwind_pose(transform_data: Dictionary) -> Dictionary:
	var spun: float = charged_guard_whirlwind_spin(charged_guard_gesture_phase_time, CHARGED_GUARD_WHIRLWIND_WINDUP, CHARGED_GUARD_WHIRLWIND_SPIN)
	var orbit_angle: float = charged_guard_gesture_orbit_angle + spun * charged_guard_gesture_spin_sign
	var hilt_offset: Vector2 = Vector2.RIGHT.rotated(orbit_angle) * charged_guard_gesture_hand_offset.length()
	var blade_angle: float = orbit_angle + charged_guard_gesture_spin_lead
	var recover_elapsed: float = charged_guard_gesture_phase_time - CHARGED_GUARD_WHIRLWIND_WINDUP - CHARGED_GUARD_WHIRLWIND_SPIN
	if recover_elapsed > 0.0:
		var recover_ratio: float = smoothstep(0.0, 1.0, clampf(recover_elapsed / maxf(CHARGED_GUARD_WHIRLWIND_RECOVER, 0.0001), 0.0, 1.0))
		# The hand comes home to the body as well as the blade coming home to the aim, so
		# neither of them snaps when the ability lets go of the pose.
		hilt_offset = hilt_offset.lerp((transform_data["start"] as Vector2) - global_position, recover_ratio)
		blade_angle = lerp_angle(blade_angle, float(transform_data["angle"]), recover_ratio)
	transform_data["angle"] = blade_angle
	transform_data["start"] = global_position + hilt_offset
	return transform_data

func _calculate_form_metronome(base_angle: float, radius: float, arc: float, raw_sine: float) -> Dictionary:
	# Endpoint dwell is now authored in _update_sword by holding phase after a
	# driven reversal. Geometry itself remains an unwarped sine.
	var shaped_sine: float = raw_sine
	var offset: float = shaped_sine * deg_to_rad(arc)
	# Only the destination side of the current stroke opens. Multiplying by the
	# shaped travel amount keeps the extension continuous from reversal to apex.
	if directional_arc_extension_degrees > 0.0 and not is_zero_approx(shaped_sine):
		offset += signf(shaped_sine) * absf(shaped_sine) * deg_to_rad(directional_arc_extension_degrees)
	var result_angle: float = base_angle + offset + sword_hit_recoil_offset
	return {"start": global_position + Vector2.RIGHT.rotated(base_angle) * radius, "angle": result_angle, "arc_degrees": arc}

func _form_phase() -> float:
	return sword_phase if sword_phase != 0.0 or swing_time == 0.0 else swing_time * TAU * _sword_cycle_frequency()

func _thrust_stroke_index(phase: float) -> int:
	# One complete out-and-back motion is one actual thrust stroke.
	var count: int = maxi(2, int(get_combat_hand_setting("thrusts_per_cycle")))
	return floori((phase / TAU) * float(count))

func _thrust_meridian_point(south_pole: Vector2, north_pole: Vector2, longitude: float, progress: float) -> Vector2:
	# Orthographic globe projection with the poles laid onto the aim axis.
	# Every longitude has the same two endpoints and bows most at the equator.
	var t: float = clampf(progress, 0.0, 1.0)
	var pole_axis: Vector2 = north_pole - south_pole
	var pole_distance: float = pole_axis.length()
	if pole_distance < 0.001:
		return south_pole
	var lateral_axis: Vector2 = pole_axis.normalized().orthogonal()
	var globe_radius: float = pole_distance * 0.5
	var lateral_offset: float = globe_radius * sin(longitude) * sin(PI * t)
	return south_pole.lerp(north_pole, t) + lateral_axis * lateral_offset

func _thrust_retracted_tip_progress(south_pole: Vector2, north_pole: Vector2, longitude: float) -> float:
	# Start with the hilt at the south pole and one complete sword already in
	# front of it. This keeps a rigid weapon while reserving the rest of the
	# meridian for the actual thrust.
	if south_pole.distance_to(north_pole) <= BLADE_LENGTH:
		return 0.0
	var low: float = 0.0
	var high: float = 1.0
	for _iteration: int in range(16):
		var middle: float = (low + high) * 0.5
		var point: Vector2 = _thrust_meridian_point(south_pole, north_pole, longitude, middle)
		if south_pole.distance_to(point) < BLADE_LENGTH:
			low = middle
		else:
			high = middle
	return high

func _thrust_hilt_for_tip(south_pole: Vector2, north_pole: Vector2, longitude: float, tip_progress: float, tip: Vector2) -> Vector2:
	# Find the earlier point on this same longitude one sword-length behind the
	# tip. The final normalization keeps the rendered/collision sword perfectly
	# rigid despite the finite binary-search precision.
	if south_pole.distance_to(tip) < BLADE_LENGTH:
		var initial_tangent: Vector2 = south_pole.direction_to(_thrust_meridian_point(south_pole, north_pole, longitude, 0.001))
		if initial_tangent == Vector2.ZERO:
			initial_tangent = south_pole.direction_to(north_pole)
		return tip - initial_tangent * BLADE_LENGTH
	var low: float = 0.0
	var high: float = tip_progress
	for _iteration: int in range(16):
		var middle: float = (low + high) * 0.5
		var candidate: Vector2 = _thrust_meridian_point(south_pole, north_pole, longitude, middle)
		if candidate.distance_to(tip) > BLADE_LENGTH:
			low = middle
		else:
			high = middle
	var meridian_hilt: Vector2 = _thrust_meridian_point(south_pole, north_pole, longitude, high)
	var sword_direction: Vector2 = meridian_hilt.direction_to(tip)
	return tip - sword_direction * BLADE_LENGTH

func _calculate_form_thrust(base_angle: float, radius: float, arc: float, _raw_sine: float) -> Dictionary:
	# Form II maps the player and target reach to a globe's south and north poles.
	# The distance between poles is governed directly by the player's controlled
	# hand reach radius (combat_hand_radius), ensuring distance/reach control
	# tracks mouse proximity smoothly instead of jumping all over the screen.
	var south_pole: Vector2 = global_position
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(base_angle)
	var reach_distance: float = maxf(radius + BLADE_LENGTH, BLADE_LENGTH + 4.0)
	var north_pole: Vector2 = south_pole + aim_dir * reach_distance

	var count: int = maxi(2, int(get_combat_hand_setting("thrusts_per_cycle")))
	var phase: float = _form_phase()
	var stroke_position: float = fposmod(phase / TAU, 1.0) * float(count)
	var stroke_index: int = mini(floori(stroke_position), count - 1)
	var stroke_fraction: float = fposmod(stroke_position, 1.0)
	var next_stroke_index: int = (stroke_index + 1) % count
	var lane_ratio: float = float(stroke_index) / float(count - 1)
	var next_lane_ratio: float = float(next_stroke_index) / float(count - 1)
	# Keep one longitude for the actual stab, then blend toward the next lane
	# only near full retraction. This removes one-frame lane snaps and fake
	# swept-blade velocity while preserving the shared polar endpoints.
	var lane_handoff: float = smoothstep(0.82, 1.0, stroke_fraction)
	var lane_coordinate: float = lerpf(lerpf(-1.0, 1.0, lane_ratio), lerpf(-1.0, 1.0, next_lane_ratio), lane_handoff)
	var max_longitude: float = minf(deg_to_rad(arc), PI * 0.48)
	var longitude: float = lane_coordinate * max_longitude

	var local_phase: float = stroke_fraction * TAU
	var thrust_amount: float = 0.5 * (1.0 - cos(local_phase))
	var retracted_tip_progress: float = _thrust_retracted_tip_progress(south_pole, north_pole, longitude)
	var tip_progress: float = lerpf(retracted_tip_progress, 1.0, thrust_amount)
	var tip_world: Vector2 = _thrust_meridian_point(south_pole, north_pole, longitude, tip_progress)
	# The meridian bow can otherwise push the tip farther from the player than
	# the configured hand reach. Keep the entire Form II envelope bounded while
	# preserving the authored thrust path inside that envelope.
	var maximum_tip_distance: float = radius + BLADE_LENGTH
	var tip_offset: Vector2 = south_pole.direction_to(tip_world) * maximum_tip_distance
	if south_pole.distance_to(tip_world) > maximum_tip_distance:
		tip_world = south_pole + tip_offset
	var hilt_world: Vector2 = _thrust_hilt_for_tip(south_pole, north_pole, longitude, tip_progress, tip_world)
	var blade_direction: Vector2 = hilt_world.direction_to(tip_world)
	if blade_direction == Vector2.ZERO:
		blade_direction = aim_dir
	# Recoil rotates around the tip so convergence remains exact.
	blade_direction = blade_direction.rotated(sword_hit_recoil_offset)
	hilt_world = tip_world - blade_direction * BLADE_LENGTH
	var active_blade_angle: float = blade_direction.angle()
	var anchor: Vector2 = hilt_world + blade_direction * BLADE_HILT_INSET
	return {"start": anchor, "angle": active_blade_angle, "arc_degrees": arc}

func _uses_hilt_trail() -> bool:
	return _is_moulinet_style() or _is_metronome_style()

func _is_moulinet_style() -> bool:
	return sword_style in [SwordStyle.MOULINET, SwordStyle.MOULINET_2, SwordStyle.MOULINET_3, SwordStyle.MOULINET_4]

func _calculate_form_moulinet(base_angle: float, radius: float, arc: float) -> Dictionary:
	# Form III: Moulinet 1 (Full Figure-8 Ping-Pong):
	# Completes a full figure-8 (right lobe then left lobe) with a +720° spin,
	# then smoothly reverses and completes the next figure-8 with a -720° spin.
	# Phase mapping: t = phase * 0.5 (period 4*PI), u = PI * (1 - cos(t))
	var phase: float = _form_phase()
	var t: float = fposmod(phase * 0.5, TAU)
	var u: float = PI * (1.0 - cos(t))

	# Aim center follows the true hand radius.
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(base_angle)
	var forward_dist: float = radius
	var center: Vector2 = global_position + aim_dir * forward_dist

	# Lobe dimensions: lateral width and forward height
	var spread_factor: float = clampf(arc / 75.0, 0.5, 2.0)
	var lateral_width: float = 32.0 * spread_factor
	var forward_height: float = 20.0 * spread_factor

	# 1. Hilt Lissajous position
	var local_forward: float = forward_height * sin(2.0 * u)
	var local_lateral: float = lateral_width * sin(u)
	var local_hilt: Vector2 = Vector2(local_forward, local_lateral)
	var hilt_world: Vector2 = center + local_hilt.rotated(base_angle)

	# 2. Smooth ping-pong rotation: 0 -> +720° -> 0
	var result_angle: float = base_angle + (2.0 * u) + sword_hit_recoil_offset

	# start is the rendering pivot (start = hilt + dir * BLADE_HILT_INSET)
	var anchor: Vector2 = hilt_world + Vector2.RIGHT.rotated(result_angle) * BLADE_HILT_INSET
	return {"start": anchor, "angle": result_angle, "arc_degrees": arc}

func _calculate_form_moulinet_2(base_angle: float, radius: float, arc: float) -> Dictionary:
	# Form IV: Moulinet 2 (Single-Lobe Alternating — Chat's Formula):
	# Right lobe = rotate Clockwise (+360°). Cross center.
	# Left lobe = rotate Counter-Clockwise (-360°). Cross center. Repeat.
	# Formula:
	#   hilt = (forward_height * sin(2*phi), lateral_width * sin(phi))
	#   rotation = PI * (1.0 - cos(phi))
	# Angular velocity is proportional to sin(phi) which is EXACTLY 0 at the crossover!
	# The hilt translation carries the blade through the center without any stutter.
	var phase: float = _form_phase()
	var phi: float = fposmod(phase, TAU)

	# Aim center follows player reach
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(base_angle)
	var forward_dist: float = maxf(radius + 15.0, 35.0)
	var center: Vector2 = global_position + aim_dir * forward_dist

	# Lobe dimensions
	var spread_factor: float = clampf(arc / 75.0, 0.5, 2.0)
	var lateral_width: float = 32.0 * spread_factor
	var forward_height: float = 20.0 * spread_factor

	# 1. Hilt Lissajous position
	var local_forward: float = forward_height * sin(2.0 * phi)
	var local_lateral: float = lateral_width * sin(phi)
	var local_hilt: Vector2 = Vector2(local_forward, local_lateral)
	var hilt_world: Vector2 = center + local_hilt.rotated(base_angle)

	# 2. Alternating rotation (CW on right lobe, CCW on left lobe)
	var blade_rot: float = PI * (1.0 - cos(phi))
	var result_angle: float = base_angle + blade_rot + sword_hit_recoil_offset

	var anchor: Vector2 = hilt_world + Vector2.RIGHT.rotated(result_angle) * BLADE_HILT_INSET
	return {"start": anchor, "angle": result_angle, "arc_degrees": arc}

func _calculate_form_moulinet_3(base_angle: float, radius: float, arc: float) -> Dictionary:
	# Form V: Moulinet 3 (Aim-Driven Direction):
	# Spin direction dynamically aligns with the player's mouse/stick swing:
	# - Swiping aim to the right -> spins Clockwise (+cuts).
	# - Swiping aim to the left -> spins Counter-Clockwise (+cuts).
	# Uses continuous angular integration (moulinet_continuous_angle) so reversing direction
	# smoothly decelerates and flows the other way without ANY rubber-banding or angle snapping.
	var phase: float = _form_phase()
	var phi: float = fposmod(phase, TAU)

	# Aim center follows the true hand radius.
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(base_angle)
	var forward_dist: float = radius
	var center: Vector2 = global_position + aim_dir * forward_dist

	# Lobe dimensions
	var spread_factor: float = clampf(arc / 75.0, 0.5, 2.0)
	var lateral_width: float = 32.0 * spread_factor
	var forward_height: float = 20.0 * spread_factor

	# Direction scale (-1.0 for CCW left-swing, +1.0 for CW right-swing)
	var spin_dir: float = moulinet_aim_direction_smoothed

	# 1. Hilt Lissajous position (mirrored laterally when sweeping left)
	var local_forward: float = forward_height * sin(2.0 * phi)
	var local_lateral: float = lateral_width * sin(phi) * spin_dir
	var local_hilt: Vector2 = Vector2(local_forward, local_lateral)
	var hilt_world: Vector2 = center + local_hilt.rotated(base_angle)

	# 2. Blade rotation integrated smoothly over time
	var active_rot: float = moulinet_continuous_angle
	var result_angle: float = base_angle + active_rot + sword_hit_recoil_offset

	var anchor: Vector2 = hilt_world + Vector2.RIGHT.rotated(result_angle) * BLADE_HILT_INSET
	return {"start": anchor, "angle": result_angle, "arc_degrees": arc}

func _calculate_form_moulinet_4(base_angle: float, radius: float, arc: float) -> Dictionary:
	# Form VI: a deliberately flattened infinity flourish. The hilt traces a
	# horizontal figure-eight while the blade follows the path tangent, keeping
	# the flourish readable instead of spinning independently like Form V.
	var phi: float = _form_phase()
	var spread_factor: float = clampf(arc / 75.0, 0.5, 1.5)
	var lateral_width: float = 46.0 * spread_factor
	var forward_height: float = 11.0 * spread_factor
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(base_angle)
	var center: Vector2 = global_position + aim_dir * radius
	var spin_dir: float = moulinet_aim_direction_smoothed
	var local_forward: float = forward_height * sin(2.0 * phi)
	var local_lateral: float = lateral_width * sin(phi) * spin_dir
	var local_hilt: Vector2 = center + Vector2(local_forward, local_lateral).rotated(base_angle)
	var tangent_local: Vector2 = Vector2(2.0 * forward_height * cos(2.0 * phi), lateral_width * cos(phi) * spin_dir)
	# Form VI mirrors its infinity when the player's aim sweep reverses, just like Form V.
	var tangent: Vector2 = tangent_local.rotated(base_angle)
	if tangent.length_squared() < 0.01: tangent = aim_dir
	var result_angle: float = tangent.angle() + sword_hit_recoil_offset
	var anchor: Vector2 = local_hilt + Vector2.RIGHT.rotated(result_angle) * BLADE_HILT_INSET
	return {"start": anchor, "angle": result_angle, "arc_degrees": arc}

func _calculate_form_thrust_metronome(base_angle: float, radius: float, arc: float) -> Dictionary:
	# Form VII: discrete-feeling thrust lanes inside a metronome arc. The blade
	# starts on the right, thrusts left, then thrusts right again; it retracts
	# before changing lane, so it stabs rather than sweeping between lanes.
	var phase: float = _form_phase()
	var lane_sequence: Array[float] = [1.0, -1.0, 1.0]
	var count: int = lane_sequence.size()
	var stroke_position: float = fposmod(phase / TAU, 1.0) * float(count)
	var stroke_index: int = mini(floori(stroke_position), count - 1)
	var stroke_fraction: float = fposmod(stroke_position, 1.0)
	var lane: float = lane_sequence[stroke_index]
	var next_lane: float = lane_sequence[(stroke_index + 1) % count]
	var retraction: float = smoothstep(0.68, 0.92, stroke_fraction)
	var lane_value: float = lerpf(lane, next_lane, retraction)
	var stab_progress: float = smoothstep(0.05, 0.58, stroke_fraction)
	stab_progress = 1.0 - smoothstep(0.58, 0.96, stroke_fraction) if stroke_fraction > 0.58 else stab_progress
	var result_angle: float = base_angle + lane_value * deg_to_rad(minf(arc, 48.0)) + sword_hit_recoil_offset
	var blade_dir: Vector2 = Vector2.RIGHT.rotated(result_angle)
	var minimum_hilt_distance: float = maxf(8.0, radius - 24.0)
	var maximum_hilt_distance: float = maxf(minimum_hilt_distance + 8.0, radius + 18.0)
	var hilt_distance: float = lerpf(maximum_hilt_distance, minimum_hilt_distance, stab_progress)
	var hilt_world: Vector2 = global_position + blade_dir * hilt_distance
	var anchor: Vector2 = hilt_world + blade_dir * BLADE_HILT_INSET
	return {"start": anchor, "angle": result_angle, "arc_degrees": arc}

## Default mid-point t used as the starting slider value for a sword whose
## BLADE_PROFILES entry has no interior control point (e.g. Basic Longsword).
## Never affects a straight blade's actual geometry, since its mid/tip
## offsets default to 0 regardless of where the (still-collinear) mid-point sits.
const BLADE_SHAPE_DEFAULT_MID_T: float = 0.55

## Resolves one blade-shape value for a given sword: a live tuning override
## from blade_profile_settings if one has been set via the Blade Shape tab,
## else the hardcoded BLADE_PROFILES default for that sword. key is one of
## "mid_t", "mid_offset", "tip_offset", or "edge_side".
func get_blade_shape_setting(sword_id: String, key: String) -> float:
	var overrides: Dictionary = blade_profile_settings.get(sword_id, {}) as Dictionary
	if overrides.has(key):
		return float(overrides[key])
	var profile: Array = BLADE_PROFILES.get(sword_id, BLADE_PROFILES["Basic Longsword"]) as Array
	match key:
		"mid_t":
			for point: Dictionary in profile:
				var t: float = float(point["t"])
				if t > 0.0 and t < 1.0: return t
			return BLADE_SHAPE_DEFAULT_MID_T
		"mid_offset":
			for point: Dictionary in profile:
				var t: float = float(point["t"])
				if t > 0.0 and t < 1.0: return float(point["offset"])
			return 0.0
		"tip_offset":
			return float((profile[profile.size() - 1] as Dictionary)["offset"])
		"edge_side":
			return float(BLADE_EDGE_SIDES.get(sword_id, 1.0))
		_:
			return 0.0

func set_blade_shape_setting(sword_id: String, key: String, value: float) -> void:
	if not blade_profile_settings.has(sword_id): blade_profile_settings[sword_id] = {}
	(blade_profile_settings[sword_id] as Dictionary)[key] = value

## Builds the equipped sword's hit polyline for one hilt anchor + direction,
## always as hilt -> mid-point -> tip so every sword shares one uniform,
## live-tunable 3-point shape (see get_blade_shape_setting()). A straight
## profile (mid/tip offsets both 0) is still exactly collinear -- Basic
## Longsword's feel/hitbox is unchanged unless its sliders are touched.
func _blade_polyline_samples(segment_start: Vector2, direction: Vector2) -> PackedVector2Array:
	var mid_t: float = clampf(get_blade_shape_setting(equipped_sword_id, "mid_t"), 0.01, 0.99)
	# blade_roll multiplies both offsets -- see its declaration for why: this
	# keeps the hit polyline perfectly in lockstep with the rendered art
	# through the whole roll/mirror transition, not just at the endpoints.
	var mid_offset: float = get_blade_shape_setting(equipped_sword_id, "mid_offset") * blade_roll
	var tip_offset: float = get_blade_shape_setting(equipped_sword_id, "tip_offset") * blade_roll
	var perpendicular: Vector2 = direction.rotated(PI * 0.5)
	var samples: PackedVector2Array = PackedVector2Array()
	samples.append(segment_start)
	samples.append(segment_start + direction * (BLADE_LENGTH * mid_t) + perpendicular * mid_offset)
	samples.append(segment_start + direction * BLADE_LENGTH + perpendicular * tip_offset)
	return samples

## The polyline sub-segment closest to a point, plus its index -- used so
## each enemy/object is tested against whichever part of a curved blade is
## actually nearest it, instead of one straight hilt->tip line.
func _closest_blade_segment(point: Vector2, samples: PackedVector2Array) -> Array:
	if samples.size() < 2: return [Vector2.ZERO, Vector2.ZERO, 0]
	var best_distance: float = INF
	var best_index: int = 0
	for index: int in range(samples.size() - 1):
		var distance: float = _distance_to_segment(point, samples[index], samples[index + 1])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return [samples[best_index], samples[best_index + 1], best_index]

func _distance_to_blade_polyline(point: Vector2, samples: PackedVector2Array) -> float:
	if samples.size() < 2: return INF
	var best_distance: float = INF
	for index: int in range(samples.size() - 1):
		best_distance = minf(best_distance, _distance_to_segment(point, samples[index], samples[index + 1]))
	return best_distance

func _blade_path_length(samples: PackedVector2Array) -> float:
	var total_length: float = 0.0
	for index: int in range(samples.size() - 1):
		total_length += samples[index].distance_to(samples[index + 1])
	return total_length

func _blade_path_fraction_for_segment(samples: PackedVector2Array, segment_index: int, segment_factor: float) -> float:
	## Converts a resolver-local segment factor into one whole-blade fraction.
	## Required for curved profiles: contact.blade_position is local to whichever
	## subsegment was nearest, so treating it as whole-blade position mislabels
	## mid/tip contacts as hilt hits.
	var total_length: float = _blade_path_length(samples)
	if total_length <= 0.001 or samples.size() < 2:
		return 0.0
	var clamped_index: int = clampi(segment_index, 0, samples.size() - 2)
	var path_distance: float = 0.0
	for index: int in range(clamped_index):
		path_distance += samples[index].distance_to(samples[index + 1])
	path_distance += samples[clamped_index].distance_to(samples[clamped_index + 1]) * clampf(segment_factor, 0.0, 1.0)
	return clampf(path_distance / total_length, 0.0, 1.0)

func _blade_path_pose(samples: PackedVector2Array, path_distance: float) -> Dictionary:
	if samples.size() < 2:
		return {"position": Vector2.ZERO, "angle": 0.0, "path_distance": 0.0}
	var total_length: float = _blade_path_length(samples)
	var remaining: float = clampf(path_distance, 0.0, total_length)
	for index: int in range(samples.size() - 1):
		var segment: Vector2 = samples[index + 1] - samples[index]
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue
		if remaining <= segment_length:
			return {
				"position": samples[index] + segment * (remaining / segment_length),
				"angle": segment.angle(),
				"path_distance": clampf(path_distance, 0.0, total_length),
			}
		remaining -= segment_length
	var final_segment: Vector2 = samples[samples.size() - 1] - samples[samples.size() - 2]
	return {
		"position": samples[samples.size() - 1],
		"angle": final_segment.angle(),
		"path_distance": total_length,
	}

func _sword_flame_poses(samples: PackedVector2Array) -> Array[Dictionary]:
	var poses: Array[Dictionary] = []
	var total_length: float = _blade_path_length(samples)
	if total_length <= SWORD_FLAME_HILT_INSET:
		return poses
	var path_distance: float = SWORD_FLAME_HILT_INSET
	while path_distance <= total_length:
		poses.append(_blade_path_pose(samples, path_distance))
		path_distance += SWORD_FLAME_SPACING
	var final_distance: float = float(poses[-1]["path_distance"]) if not poses.is_empty() else 0.0
	if total_length - final_distance > SWORD_FLAME_SPACING * 0.35:
		poses.append(_blade_path_pose(samples, total_length))
	return poses

func _draw_hd_sword_fire(samples: PackedVector2Array, fire_fade: float) -> void:
	var poses: Array[Dictionary] = _sword_flame_poses(samples)
	if poses.is_empty():
		return
	var animation_seconds: float = float(Time.get_ticks_msec()) * 0.001
	var flame_strength: float = clampf(fire_fade, 0.0, 1.0)
	var local_blade_path: PackedVector2Array = PackedVector2Array()
	for blade_point: Vector2 in samples:
		local_blade_path.append(blade_point - global_position)
	if local_blade_path.size() >= 2:
		draw_polyline(local_blade_path, Color(1.0, 0.42, 0.08, flame_strength * 0.42), 4.0, true)
		draw_polyline(local_blade_path, Color(1.0, 0.9, 0.43, flame_strength * 0.38), 1.6, true)
	for flame_index: int in range(poses.size()):
		var pose: Dictionary = poses[flame_index]
		var frame_offset: float = float(flame_index % SWORD_FLAME_FRAME_COUNT) / SWORD_FLAME_FPS
		var frame_index: int = int(floor((animation_seconds + frame_offset) * SWORD_FLAME_FPS)) % SWORD_FLAME_FRAME_COUNT
		var source_rect: Rect2 = Rect2(Vector2(float(frame_index) * SWORD_FLAME_FRAME_SIZE.x, 0.0), SWORD_FLAME_FRAME_SIZE)
		var flicker: float = 0.5 + 0.5 * sin(animation_seconds * 11.0 + float(flame_index) * 1.73)
		var path_ratio: float = clampf(float(pose["path_distance"]) / maxf(_blade_path_length(samples), 0.001), 0.0, 1.0)
		var flame_height: float = lerpf(25.0, 38.0, flicker) * lerpf(0.82, 1.08, path_ratio)
		var flame_width: float = lerpf(22.0, 31.0, 1.0 - flicker * 0.32)
		var flame_position: Vector2 = (pose["position"] as Vector2) - global_position
		var tangent_angle: float = float(pose["angle"])
		var normal: Vector2 = Vector2(-sin(tangent_angle), cos(tangent_angle))
		var flame_alpha: float = SWORD_FLAME_MAX_ALPHA * flame_strength * lerpf(0.83, 1.0, flicker)
		# Draw the same animated tongue away from both blade edges. Pairing the
		# frames and alpha keeps the fire approximately symmetrical even on every
		# curved BLADE_PROFILES polyline.
		for side: float in [-1.0, 1.0]:
			var side_position: Vector2 = flame_position + normal * side * 2.8
			var side_rotation: float = tangent_angle if side < 0.0 else tangent_angle + PI
			draw_set_transform(side_position, side_rotation, Vector2.ONE)
			draw_texture_rect_region(SWORD_FLAME_ATLAS, Rect2(-flame_width * 0.5, -flame_height, flame_width, flame_height), source_rect, Color(1.0, 1.0, 1.0, flame_alpha))
		# Paired drifting embers give the flames motion beyond atlas playback and
		# stay profile-driven instead of assuming a straight sword.
		if flame_index % 2 == 0:
			var ember_progress: float = fposmod(animation_seconds * 1.9 + float(flame_index) * 0.231, 1.0)
			var tangent: Vector2 = Vector2.RIGHT.rotated(tangent_angle)
			for side: float in [-1.0, 1.0]:
				var ember_position: Vector2 = flame_position + normal * side * (5.0 + ember_progress * 13.0) + Vector2.UP * ember_progress * 14.0 + tangent * sin(animation_seconds * 8.0 + float(flame_index)) * 3.0
				var ember_alpha: float = (1.0 - ember_progress) * flame_strength * 0.82
				draw_circle(ember_position, lerpf(2.2, 0.7, ember_progress), Color(1.0, 0.62, 0.12, ember_alpha))
				draw_line(ember_position, ember_position + Vector2.UP * lerpf(5.0, 2.0, ember_progress), Color(1.0, 0.25, 0.03, ember_alpha * 0.56), 1.2, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _begin_metronome_reversal_pulse(current_angle: float) -> void:
	if not _is_metronome_style(): return
	var reversal_offset: float = wrapf(current_angle - aim_angle - sword_hit_recoil_offset, -PI, PI)
	metronome_reversal_side = -1.0 if reversal_offset < 0.0 else 1.0
	metronome_reversal_flash_left = metronome_reversal_pulse_duration

## How well a pull lines up with the pull axis, which is the direction back toward the body.
## The caller passes the player's aim direction as that axis rather than the blade: the metronome
## swings the blade on its own, so a blade-relative measure moves under the player's hand.
static func charged_guard_pommel_alignment(blade_direction: Vector2, authored_aim_velocity: Vector2) -> float:
	if blade_direction.length_squared() < 0.001 or authored_aim_velocity.length_squared() < 0.001:
		return -1.0
	return authored_aim_velocity.normalized().dot(-blade_direction.normalized())

## How much of the aim's motion is lateral: across the aim's line rather than along it. A
## deliberate drawn stroke runs roughly along the pull, so this is what separates a hard sideways
## flick from a straight stroke, and what lets the flick stay a legible exit at all.
static func charged_guard_lateral_aim_speed(aim_direction: Vector2, authored_aim_velocity: Vector2) -> float:
	if aim_direction.length_squared() < 0.001:
		return authored_aim_velocity.length()
	var axis: Vector2 = aim_direction.normalized()
	return (authored_aim_velocity - axis * authored_aim_velocity.dot(axis)).length()

## Whether a flick is hard enough to break a guard, geared by how far out the cursor is being
## held. The same flick covers fewer pixels per second when the hand is drawn in, so without the
## gearing a guard was harder to leave the closer it was held. The flick is a gesture, and it has
## to mean the same thing wherever the hand happens to be.
static func charged_guard_motion_breaks(lateral_speed: float, break_speed_threshold: float, cursor_reach_limit: float, aim_distance: float) -> bool:
	if break_speed_threshold <= 0.0:
		return false
	var gearing: float = clampf(cursor_reach_limit / maxf(aim_distance, 1.0), 1.0, CHARGED_GUARD_BREAK_GEARING_MAX)
	return lateral_speed * gearing >= break_speed_threshold

static func charged_guard_angular_travel(aim_relative: Vector2, authored_relative_delta: Vector2) -> float:
	if aim_relative.length_squared() < 1.0 or authored_relative_delta.length_squared() <= 0.0001:
		return 0.0
	return aim_relative.cross(authored_relative_delta) / aim_relative.length_squared()

static func charged_guard_turn_sign(angular_travel: float) -> float:
	return signf(angular_travel) if absf(angular_travel) >= SWING_COMMITMENT_INPUT_THRESHOLD else 0.0

## Speed multiplier for the charged hand's follow. This is never a gate on whether the hand
## follows: 0.70 while the player sweeps the aim slowly, 1.0 otherwise. Player translation
## returns the full-speed 1.0 so walking is never misread as a slow aim sweep -- which is
## exactly why this value must not be compared against 1.0 to decide whether to follow.
static func charged_guard_slow_reposition_scale(authored_aim_speed: float, reference_speed: float = CHARGED_GUARD_REPOSITION_SPEED_REFERENCE, player_moved_recently: bool = false) -> float:
	if player_moved_recently:
		return 1.0
	return 0.70 if authored_aim_speed > 1.0 and authored_aim_speed < reference_speed else 1.0

## Whether the charged hand follows the cursor this frame. Kept deliberately separate from
## the scale above, because both the full-speed 1.0 and the damped 0.70 must follow -- only
## the wake-up ramp holds the hand briefly still, and only the confirm hold before the
## charged state keeps the pose frozen.
static func charged_guard_hand_follows_cursor(fully_charged: bool, position_stage_enabled: bool, reposition_ramp: float) -> bool:
	return fully_charged and position_stage_enabled and reposition_ramp > 0.0

static func charged_guard_clamp_hand_offset(hand_offset: Vector2, maximum_radius: float, minimum_radius: float = 0.0, fallback_direction: Vector2 = Vector2.RIGHT) -> Vector2:
	var max_radius: float = maxf(1.0, maximum_radius)
	var min_radius: float = clampf(minimum_radius, 0.0, max_radius)
	var current_radius: float = hand_offset.length()
	var direction: Vector2 = hand_offset.normalized() if current_radius > 0.001 else fallback_direction.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector2.RIGHT
	return direction * clampf(current_radius, min_radius, max_radius)

## Charged Guard repositions its locked hand by converging on a bounded target
## rather than accumulating raw cursor displacement. An accumulator desyncs from
## the cursor the moment the aim leaves the hand range, so re-entering from a
## different direction snapped the blade onto a stale radial direction. A
## bounded target cannot desync, and the per-step cap keeps re-entry smooth.
static func charged_guard_repositioned_hand_offset(current_offset: Vector2, target_offset: Vector2, reposition_speed: float, delta: float) -> Vector2:
	return current_offset.move_toward(target_offset, maxf(0.0, reposition_speed) * delta)

static func charged_guard_safe_blade_angle(blade_angle: float, hand_offset: Vector2, fallback_radial_direction: Vector2) -> float:
	var radial_direction: Vector2 = hand_offset.normalized() if hand_offset.length_squared() > 0.001 else fallback_radial_direction.normalized()
	if radial_direction.length_squared() < 0.001:
		radial_direction = Vector2.RIGHT
	var radial_angle: float = radial_direction.angle()
	var relative_blade_angle: float = angle_difference(radial_angle, blade_angle)
	if absf(relative_blade_angle) <= PI * 0.5:
		return blade_angle
	var safe_angle: float = radial_angle + signf(relative_blade_angle) * PI * 0.5
	return wrapf(safe_angle, -PI, PI)

## Blends the guard's blade toward that safe angle at a limited rate instead of
## hard-clamping onto it. The metronome arc (105 degrees by default, more with
## directional extension) legitimately swings the blade past the 90 degree guard
## limit, so a hard clamp could rotate the sword tens of degrees in one frame.
## Inside the safe cone the target equals the current angle, so this changes
## nothing and adds no lag to normal charged aiming.
static func charged_guard_conformed_blade_angle(blade_angle: float, hand_offset: Vector2, fallback_radial_direction: Vector2, conform_rate: float, delta: float) -> float:
	var safe_angle: float = charged_guard_safe_blade_angle(blade_angle, hand_offset, fallback_radial_direction)
	return lerp_angle(blade_angle, safe_angle, clampf(conform_rate * delta, 0.0, 1.0))

static func charged_guard_charge_multiplier(near_body: bool, recent_authored_motion: bool, pommel_pull: bool, near_body_bonus: float, recent_motion_bonus: float, pommel_pull_bonus: float) -> float:
	var multiplier: float = 1.0
	if near_body:
		multiplier += maxf(0.0, near_body_bonus)
	if recent_authored_motion:
		multiplier += maxf(0.0, recent_motion_bonus)
	if pommel_pull:
		multiplier += maxf(0.0, pommel_pull_bonus)
	return multiplier

## --- Charged Guard gesture recognition --------------------------------------

## The straight-line chord of a drawn stroke. The direction comes from the whole stroke
## rather than its last frame, so a flick at the end of a bowed line cannot bias where
## the blade ends up pointing.
static func gesture_chord(path: PackedVector2Array) -> Vector2:
	if path.size() < 2:
		return Vector2.ZERO
	return path[path.size() - 1] - path[0]

static func gesture_path_length(path: PackedVector2Array) -> float:
	var travelled: float = 0.0
	for index: int in range(path.size() - 1):
		travelled += path[index].distance_to(path[index + 1])
	return travelled

## Chord length over drawn length. Scale-free, so drawing the same shape larger or
## smaller cannot change the reading.
static func gesture_straightness(path: PackedVector2Array) -> float:
	var travelled: float = gesture_path_length(path)
	if travelled <= 0.0001:
		return 0.0
	return clampf(gesture_chord(path).length() / travelled, 0.0, 1.0)

## The whole recognition test in one place: real samples, inside the window, long enough,
## straight enough. It deliberately has no speed requirement of its own, because a stroke
## quiet enough to survive the guard break is by definition one the player drew rather
## than yanked. That leaves the break as the only thing that decides how hard the guard is
## to leave, and stops the two ever competing for the same motion.
static func gesture_stroke_qualified(path: PackedVector2Array, stroke_time: float, minimum_span: float, minimum_straightness: float, window: float) -> bool:
	if path.size() < 3:
		return false
	if stroke_time <= 0.0 or stroke_time > window:
		return false
	if gesture_chord(path).length() < minimum_span:
		return false
	return gesture_straightness(path) >= minimum_straightness

## How far around its own centre of mass a stroke travelled, in radians, signed. This is the
## circle's real measure, and it is deliberately not the sum of the turns between segments: a
## rough circle's wobble adds cancelling turns until a genuine revolution can measure under
## 270 degrees and be thrown out for not turning enough. Sweeping the direction of each point
## as seen from the stroke's middle is immune to that, so a loosely drawn circle still reads
## as a whole turn. A zig-zag or a scribble sweeps back and forth and cancels to nothing, a
## figure-eight likewise, and a straight line subtends at most half a turn -- which is why the
## roundness and closure tests do the rest of the work.
static func gesture_orbit_sweep(path: PackedVector2Array) -> float:
	if path.size() < 3:
		return 0.0
	var centroid: Vector2 = gesture_centroid(path)
	var sweep: float = 0.0
	var previous_direction: Vector2 = path[0] - centroid
	for index: int in range(1, path.size()):
		var next_direction: Vector2 = path[index] - centroid
		if previous_direction.length_squared() > 0.0001 and next_direction.length_squared() > 0.0001:
			sweep += angle_difference(previous_direction.angle(), next_direction.angle())
			previous_direction = next_direction
	return sweep

static func gesture_centroid(path: PackedVector2Array) -> Vector2:
	var centroid: Vector2 = Vector2.ZERO
	if path.is_empty():
		return centroid
	for point: Vector2 in path:
		centroid += point
	return centroid / float(path.size())

## How far the stroke's points sit from their own centre of mass, and how much that distance
## varies. Between them they separate a round stroke from an oval, a spiral or a scribble,
## without caring how big the player drew it.
static func gesture_mean_radius(path: PackedVector2Array) -> float:
	if path.size() < 2:
		return 0.0
	var centroid: Vector2 = gesture_centroid(path)
	var total: float = 0.0
	for point: Vector2 in path:
		total += point.distance_to(centroid)
	return total / float(path.size())

static func gesture_radius_spread(path: PackedVector2Array) -> float:
	if path.size() < 2:
		return 0.0
	var centroid: Vector2 = gesture_centroid(path)
	var smallest: float = INF
	var largest: float = 0.0
	for point: Vector2 in path:
		var radius: float = point.distance_to(centroid)
		smallest = minf(smallest, radius)
		largest = maxf(largest, radius)
	if smallest <= 0.0001:
		return INF
	return largest / smallest

## The circle gesture's whole test: enough samples to be a real stroke, inside the circle's
## own generous window, big enough to be deliberate, round rather than spiral, and swept one
## way the whole way. Closure and sweep are an either/or rather than both: a stroke that
## swept nearly the whole way around has already proved it came around, so only a stroke that
## fell short of that has to bring its ends back together. Shape is a hard disambiguator, so a
## closed revolution can never also pass the line gesture's straightness bar -- the two can
## never both fire, and nothing has to arbitrate between them.
static func gesture_circle_qualified(path: PackedVector2Array, stroke_time: float, minimum_sweep: float, closure_free_sweep: float, minimum_radius: float, maximum_closure: float, maximum_radius_spread: float, minimum_samples: int, window: float) -> bool:
	if path.size() < minimum_samples:
		return false
	if stroke_time <= 0.0 or stroke_time > window:
		return false
	var radius: float = gesture_mean_radius(path)
	if radius < minimum_radius:
		return false
	if gesture_radius_spread(path) > maximum_radius_spread:
		return false
	var sweep: float = absf(gesture_orbit_sweep(path))
	if sweep < minimum_sweep:
		return false
	if sweep < closure_free_sweep and gesture_chord(path).length() > radius * maximum_closure:
		return false
	return true

## Hand extension through the thrust, as a fraction of full reach: a short pull back off
## the guard, a fast drive out, a beat held at full reach, then a settle home. Pure, so
## the sequence's shape can be checked without running a player.
static func charged_guard_thrust_extension(elapsed: float, windup: float, extend: float, hold: float, recover: float) -> float:
	if elapsed <= 0.0:
		return 0.0
	if elapsed < windup:
		return lerpf(0.0, -CHARGED_GUARD_THRUST_WINDUP_PULL, elapsed / maxf(windup, 0.0001))
	var drive_time: float = elapsed - windup
	if drive_time < extend:
		var drive_ratio: float = drive_time / maxf(extend, 0.0001)
		return lerpf(-CHARGED_GUARD_THRUST_WINDUP_PULL, 1.0, 1.0 - pow(1.0 - drive_ratio, 3.0))
	var held_time: float = drive_time - extend
	if held_time < hold:
		return 1.0
	var recover_time: float = held_time - hold
	if recover_time < recover:
		return 1.0 - smoothstep(0.0, 1.0, recover_time / maxf(recover, 0.0001))
	return 0.0

static func charged_guard_thrust_total_duration() -> float:
	return CHARGED_GUARD_THRUST_WINDUP + CHARGED_GUARD_THRUST_EXTEND + CHARGED_GUARD_THRUST_HOLD + CHARGED_GUARD_THRUST_RECOVER

## Blade rotation through the whirlwind, in radians relative to the angle it started at: a
## short counter-turn to wind up, then one eased full revolution. Eased at both ends so the
## whip reads as a slash without snapping off either end of it.
static func charged_guard_whirlwind_spin(elapsed: float, windup: float, spin: float) -> float:
	if elapsed <= 0.0:
		return 0.0
	if elapsed < windup:
		return lerpf(0.0, -CHARGED_GUARD_WHIRLWIND_ANTICIPATION, elapsed / maxf(windup, 0.0001))
	var spin_ratio: float = clampf((elapsed - windup) / maxf(spin, 0.0001), 0.0, 1.0)
	return lerpf(-CHARGED_GUARD_WHIRLWIND_ANTICIPATION, TAU, smoothstep(0.0, 1.0, spin_ratio))

static func charged_guard_whirlwind_total_duration() -> float:
	return CHARGED_GUARD_WHIRLWIND_WINDUP + CHARGED_GUARD_WHIRLWIND_SPIN + CHARGED_GUARD_WHIRLWIND_RECOVER

## True only while a stroke can actually be read: the blue charged state is held, the
## feature is on, and the input is a drawn pointer rather than a stick.
func _charged_guard_gesture_armed() -> bool:
	if get_combat_contact_setting("charged_guard_gestures_enabled") < 0.5:
		return false
	if not charged_guard_locked or not charged_guard_fully_charged:
		return false
	if get_combat_contact_setting("charged_guard_position_charge_enabled") < 0.5:
		return false
	if mobile_input_enabled or input_mode == INPUT_MODE_CONTROLLER:
		return false
	if training_menu_input_locked or hit_stagger_left > 0.0:
		return false
	return true

## Sparks carry their own remaining life, so each fades on its own; the pool bounds them by
## dropping the oldest first.
func _decay_charged_guard_gesture_sparks(delta: float) -> void:
	for spark_index: int in range(charged_guard_gesture_sparks.size() - 1, -1, -1):
		var spark: Vector3 = charged_guard_gesture_sparks[spark_index]
		spark.z -= delta
		if spark.z <= 0.0:
			charged_guard_gesture_sparks.remove_at(spark_index)
		else:
			charged_guard_gesture_sparks[spark_index] = spark

func _spawn_charged_guard_gesture_sparks(origin: Vector2, count: int, spread: float) -> void:
	for _spark: int in range(count):
		var offset: Vector2 = Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		var life: float = CHARGED_GUARD_GESTURE_SPARK_LIFE * randf_range(0.6, 1.0)
		charged_guard_gesture_sparks.append(Vector3(origin.x + offset.x, origin.y + offset.y, life))
	while charged_guard_gesture_sparks.size() > CHARGED_GUARD_GESTURE_SPARK_POOL:
		charged_guard_gesture_sparks.remove_at(0)

func _clear_charged_guard_gesture_stroke() -> void:
	charged_guard_gesture_path.clear()
	charged_guard_gesture_stroke_time = 0.0
	charged_guard_gesture_still = 0.0
	charged_guard_gesture_active = false
	charged_guard_gesture_spent = false

## The gesture layer's whole lifecycle: the trail and hit-flash timers, the running ability, and
## stroke recognition while the blue guard is held. Called before _update_charged_guard on
## purpose, so a stroke that has qualified releases the guard on the frame it completes, before
## that same frame's motion can reach the acquisition gate.
func _update_charged_guard_gesture(delta: float) -> void:
	charged_guard_gesture_flash_left = maxf(0.0, charged_guard_gesture_flash_left - delta)
	charged_guard_gesture_trail_left = maxf(0.0, charged_guard_gesture_trail_left - delta)
	_decay_charged_guard_gesture_sparks(delta)
	if charged_guard_gesture_state != ChargedGuardGesture.NONE:
		if charged_guard_gesture_state == ChargedGuardGesture.WHIRLWIND:
			_advance_charged_guard_whirlwind(delta)
		else:
			_advance_charged_guard_thrust(delta)
		return
	if not _charged_guard_gesture_armed():
		_clear_charged_guard_gesture_stroke()
		return
	if not charged_guard_gesture_has_cursor:
		charged_guard_gesture_previous_cursor = charged_guard_gesture_cursor
		charged_guard_gesture_has_cursor = true
		return
	var cursor_moved: float = charged_guard_gesture_cursor.distance_to(charged_guard_gesture_previous_cursor)
	charged_guard_gesture_previous_cursor = charged_guard_gesture_cursor
	if charged_guard_gesture_active:
		charged_guard_gesture_stroke_time += delta
		if charged_guard_gesture_stroke_time > CHARGED_GUARD_GESTURE_WINDOW or charged_guard_gesture_path.size() >= CHARGED_GUARD_GESTURE_SAMPLE_LIMIT:
			# Too slow, or absurdly oversampled. Abandoned rather than trimmed, so a long
			# slow drag degrades to "no gesture" instead of hiding a shorter qualifying
			# sub-stroke inside itself.
			charged_guard_gesture_spent = true
	if cursor_moved >= CHARGED_GUARD_GESTURE_MOVE_EPSILON:
		charged_guard_gesture_still = 0.0
		if charged_guard_gesture_active and not charged_guard_gesture_spent:
			charged_guard_gesture_path.append(charged_guard_gesture_cursor)
		else:
			charged_guard_gesture_path.clear()
			charged_guard_gesture_path.append(charged_guard_gesture_cursor)
			charged_guard_gesture_stroke_time = 0.0
			charged_guard_gesture_active = true
			charged_guard_gesture_spent = false
		charged_guard_gesture_trail_left = CHARGED_GUARD_GESTURE_TRAIL_FADE
		# Sparks fall off the drawing point as the stroke is made, so the line looks like
		# it is being cut rather than merely painted.
		charged_guard_gesture_spark_timer -= delta
		if charged_guard_gesture_spark_timer <= 0.0:
			charged_guard_gesture_spark_timer = CHARGED_GUARD_GESTURE_SPARK_INTERVAL
			_spawn_charged_guard_gesture_sparks(charged_guard_gesture_cursor, 1, 5.0)
		return
	charged_guard_gesture_still += delta
	if not charged_guard_gesture_active or charged_guard_gesture_spent:
		return
	if charged_guard_gesture_still < CHARGED_GUARD_GESTURE_SETTLE_TIME:
		return
	# One reading per stroke: qualified or not, this stroke is finished.
	charged_guard_gesture_spent = true
	# The circle is read first purely because it is the more specific shape. The two can
	# never both match, so this is a courtesy rather than arbitration.
	var read_as: String = "nothing"
	if gesture_circle_qualified(charged_guard_gesture_path, charged_guard_gesture_stroke_time, CHARGED_GUARD_GESTURE_CIRCLE_MIN_SWEEP, CHARGED_GUARD_GESTURE_CIRCLE_CLOSURE_FREE_SWEEP, CHARGED_GUARD_GESTURE_CIRCLE_MIN_RADIUS, CHARGED_GUARD_GESTURE_CIRCLE_MAX_CLOSURE, CHARGED_GUARD_GESTURE_CIRCLE_MAX_RADIUS_SPREAD, CHARGED_GUARD_GESTURE_CIRCLE_MIN_SAMPLES, CHARGED_GUARD_GESTURE_CIRCLE_WINDOW):
		read_as = "whirlwind"
		_begin_charged_guard_whirlwind()
	elif gesture_stroke_qualified(charged_guard_gesture_path, charged_guard_gesture_stroke_time, CHARGED_GUARD_GESTURE_MIN_SPAN, CHARGED_GUARD_GESTURE_STRAIGHTNESS, CHARGED_GUARD_GESTURE_WINDOW):
		read_as = "thrust"
		_begin_charged_guard_thrust()
	_log_charged_guard_gesture_read(read_as)

## Editor-only, and deliberately blunt: every time a stroke is brought to rest the recogniser
## prints its own numbers, whether or not that stroke read. Tuning the bars by feel alone meant
## guessing which one was actually biting, because a rough circle that fails the bars and one
## that never settled at all look identical from the outside. This says which it was in one
## line. It is stripped from exported builds, so it can stay in place rather than being torn
## out again later.
func _log_charged_guard_gesture_read(read_as: String) -> void:
	if not OS.is_debug_build():
		return
	var radius: float = gesture_mean_radius(charged_guard_gesture_path)
	print("[gesture] read as %s | sweep %.0f deg | radius %.0f px | spread %.2f | closure %.2f | samples %d | %.2f s" % [
		read_as,
		rad_to_deg(gesture_orbit_sweep(charged_guard_gesture_path)),
		radius,
		gesture_radius_spread(charged_guard_gesture_path),
		gesture_chord(charged_guard_gesture_path).length() / maxf(radius, 0.0001),
		charged_guard_gesture_path.size(),
		charged_guard_gesture_stroke_time,
	])

## A read stroke discharges the guard. The direction comes from the stroke's chord,
## converted with the camera's basis alone, so the thrust goes exactly where the line was
## drawn however the camera was moving while it was drawn.
func _begin_charged_guard_thrust() -> void:
	var chord: Vector2 = gesture_chord(charged_guard_gesture_path)
	if chord.length_squared() > 0.0001:
		charged_guard_gesture_direction = get_viewport().get_canvas_transform().basis_xform(chord.normalized())
	if charged_guard_gesture_direction.length_squared() <= 0.0001:
		charged_guard_gesture_direction = _current_aim_direction()
	charged_guard_gesture_direction = charged_guard_gesture_direction.normalized()
	charged_guard_gesture_hand_radius = combat_hand_radius
	charged_guard_gesture_state = ChargedGuardGesture.THRUST
	charged_guard_gesture_phase_time = 0.0
	charged_guard_gesture_lunge_armed = false
	charged_guard_gesture_lunge_left = 0.0
	charged_guard_gesture_flash_left = CHARGED_GUARD_GESTURE_FLASH_TIME
	# A short burst on top of the flash, so a stroke that was read pops.
	_spawn_charged_guard_gesture_sparks(charged_guard_gesture_cursor, CHARGED_GUARD_GESTURE_SPARK_BURST, 11.0)
	# The stroke stays on screen as the trail while the thrust plays, but it can no
	# longer be read or extended.
	charged_guard_gesture_active = false
	charged_guard_gesture_spent = true
	# Activation consumes the guard: the ability owns the pose from here, and clearing the
	# guard hands its glow, ring and afterimages over cleanly.
	charged_guard_locked = false
	_clear_charged_guard_attempt()
	# The thrust is a fresh committed cut, so it must be able to connect even if the
	# metronome's current stroke has already spent its hit suppression.
	hit_ids.clear()

func _advance_charged_guard_thrust(delta: float) -> void:
	charged_guard_gesture_phase_time += delta
	if not charged_guard_gesture_lunge_armed and charged_guard_gesture_phase_time >= CHARGED_GUARD_THRUST_WINDUP:
		# The body follows the blade out rather than leading it, so the wind-up never
		# reads as walking.
		charged_guard_gesture_lunge_armed = true
		charged_guard_gesture_lunge_left = CHARGED_GUARD_THRUST_LUNGE_TIME
	if charged_guard_gesture_phase_time < charged_guard_thrust_total_duration():
		return
	# Back to ordinary play: hand the pose back and let the guard be re-acquired from
	# scratch. The cursor anchor is dropped so the first frame afterwards merely seeds
	# itself instead of reading the gap as one enormous stroke.
	charged_guard_gesture_state = ChargedGuardGesture.NONE
	charged_guard_gesture_phase_time = 0.0
	charged_guard_gesture_lunge_armed = false
	charged_guard_gesture_has_cursor = false

## A drawn circle discharges the guard into a whirlwind instead of a thrust. The whole sword
## sweeps one turn around the player, going whichever way the circle was drawn, and the
## ability claims the pose exactly as the thrust does. Nothing else about it is special: the
## blade still hits through the ordinary contact pipeline, so slides, parries, clashes and
## being interrupted all behave normally. Only the animation is forced.
func _begin_charged_guard_whirlwind() -> void:
	charged_guard_gesture_spin_sign = 1.0 if gesture_orbit_sweep(charged_guard_gesture_path) >= 0.0 else -1.0
	# The hilt sweeps from where it is now, around the body, back to where it is now: its own
	# direction out from the body is the base angle and its current distance is the radius, so
	# one whole turn lands exactly back on the offset it started from.
	charged_guard_gesture_hand_offset = charged_guard_lock_hand_offset
	charged_guard_gesture_orbit_angle = charged_guard_lock_hand_offset.angle()
	# The blade leans ahead of the outward radial in the direction of travel, so the edge
	# leads the sweep instead of dragging behind it. The lean is read off the angle the blade
	# is already holding, which makes the first frame identical to the last guard frame, then
	# capped so a blade sitting well off the radial still ends up reading as pointing outward
	# rather than sideways.
	charged_guard_gesture_spin_lead = charged_guard_gesture_spin_sign * clampf(angle_difference(charged_guard_gesture_orbit_angle, charged_guard_lock_angle) * charged_guard_gesture_spin_sign, 0.0, CHARGED_GUARD_WHIRLWIND_LEAD_MAX)
	charged_guard_gesture_state = ChargedGuardGesture.WHIRLWIND
	charged_guard_gesture_phase_time = 0.0
	charged_guard_gesture_flash_left = CHARGED_GUARD_GESTURE_FLASH_TIME
	# A short burst on top of the flash, so a stroke that was read pops.
	_spawn_charged_guard_gesture_sparks(charged_guard_gesture_cursor, CHARGED_GUARD_GESTURE_SPARK_BURST, 11.0)
	# The circle stays on screen as the trail while the spin plays, but it can no longer be
	# read or extended.
	charged_guard_gesture_active = false
	charged_guard_gesture_spent = true
	# Activation consumes the guard, exactly as the thrust does.
	charged_guard_locked = false
	_clear_charged_guard_attempt()
	# A fresh swing, so the spin's cut registers even if the metronome's current stroke has
	# already spent its repeat-hit suppression. Nothing else is cleared or bypassed.
	hit_ids.clear()

func _advance_charged_guard_whirlwind(delta: float) -> void:
	charged_guard_gesture_phase_time += delta
	if charged_guard_gesture_phase_time < charged_guard_whirlwind_total_duration():
		return
	# Back to ordinary play. Deliberately no lunge to unwind here: the whirlwind never
	# touches the body in the first place.
	charged_guard_gesture_state = ChargedGuardGesture.NONE
	charged_guard_gesture_phase_time = 0.0
	charged_guard_gesture_has_cursor = false

## True from the moment a guard acquisition starts charging until the lock releases, which
## is exactly when the guard's ring, glow and afterimages are on screen. Sole authority for
## "the guard is engaged": the draw code and the metronome sheathe timer both read this, so
## a guard can never be showing while the metronome treats the sword as put away.
func _charged_guard_engaged() -> bool:
	return charged_guard_charge > 0.0 or charged_guard_locked

func _clear_charged_guard_attempt() -> void:
	charged_guard_candidate_active = false
	charged_guard_pommel_travel = 0.0
	charged_guard_pommel_time = 0.0
	charged_guard_input_gap = 0.0
	charged_guard_candidate_latch_left = 0.0
	charged_guard_recent_motion_left = 0.0
	charged_guard_awaken_charge = 0.0
	charged_guard_fully_charged = false
	charged_guard_reposition_ramp = 0.0
	charged_guard_afterimage_timer = 0.0
	charged_guard_afterimages.clear()
	charged_guard_charge = 0.0

## Temporary debug-build acquisition trace, throttled during ordinary play but always printed
## at candidate creation, expiry and lock. All values come from the live acquisition path.
func _log_charged_guard_acquisition(alignment: float, speed: float, phase_valid: bool, travel: float, intent: float, candidate_age: float, candidate: bool, shape_valid: bool, event: String = "") -> void:
	if not OS.is_debug_build():
		return
	if event.is_empty():
		if charged_guard_acquisition_log_cooldown > 0.0 or (speed < 5.0 and not candidate and travel <= 0.0):
			return
	charged_guard_acquisition_log_cooldown = CHARGED_GUARD_ACQUISITION_LOG_INTERVAL
	print("[guard] %s | alignment %.2f speed %.0f px/s phase/window %s travel %.1f px intent %.3f s candidate_age %.3f s candidate %s shape %s%s" % ["acquiring" if event.is_empty() else event, alignment, speed, phase_valid, travel, intent, candidate_age, candidate, shape_valid, " LOCK" if event == "lock" else ""])

## Ends a held guard cleanly, and is the only way out of one. A flick, the hold limit
## running out and the feature being switched off all come through here, so no exit can leave
## the charge, the candidate latch or the banked hold time behind on the sword.
func _release_charged_guard_hold() -> void:
	charged_guard_locked = false
	charged_guard_fully_charged = false
	charged_guard_awaken_charge = 0.0
	charged_guard_hold_time = 0.0
	charged_guard_reacquire_block_left = CHARGED_GUARD_REACQUIRE_BLOCK
	_clear_charged_guard_attempt()

func _update_charged_guard(delta: float) -> void:
	charged_guard_flash_left = maxf(0.0, charged_guard_flash_left - delta)
	charged_guard_acquisition_log_cooldown = maxf(0.0, charged_guard_acquisition_log_cooldown - delta)
	charged_guard_reacquire_block_left = maxf(0.0, charged_guard_reacquire_block_left - delta)
	if charged_guard_gesture_state != ChargedGuardGesture.NONE:
		# An ability owns the sword until it finishes. The guard stays released and inert for
		# the whole sequence, so no pull or fresh acquisition can interrupt an attack that is
		# already committed.
		_clear_charged_guard_attempt()
		charged_guard_locked = false
		return
	if get_combat_contact_setting("charged_guard_enabled") < 0.5 or not _is_metronome_style():
		_release_charged_guard_hold()
		return
	var aim_direction: Vector2 = _current_aim_direction()
	if charged_guard_locked:
		# A hard sideways flick breaks a held guard: it is the exit the player reaches for, geared
		# by how far out the cursor is held so the same flick means the same thing wherever the
		# hand is. It is an exit only, never an interruption: a pull that is still charging is not
		# thrown away by a sideways jab, so a guard cannot be lost while it is being acquired.
		var aim_distance: float = (virtual_aim_point - global_position).length()
		var flick_speed: float = charged_guard_lateral_aim_speed(aim_direction, charged_guard_authored_aim_velocity)
		if charged_guard_motion_breaks(flick_speed, get_combat_contact_setting("charged_guard_break_speed"), _cursor_hand_reach_limit(), aim_distance):
			_release_charged_guard_hold()
			return
		# The guard runs out on its own. Counted from blue only, because the charge itself is
		# free -- timing that would punish the very act of building the guard -- and paused
		# while a stroke is being drawn, so a circle can never be timed out from under the
		# player's hand.
		if charged_guard_fully_charged and not charged_guard_gesture_active:
			charged_guard_hold_time += delta
			if charged_guard_hold_time >= clampf(get_combat_contact_setting("charged_guard_hold_limit"), CHARGED_GUARD_HOLD_LIMIT_MIN, CHARGED_GUARD_HOLD_LIMIT_MAX):
				_release_charged_guard_hold()
				return
		if get_combat_contact_setting("charged_guard_position_charge_enabled") < 0.5:
			charged_guard_lock_angle = charged_guard_initial_lock_angle
			charged_guard_lock_hand_offset = charged_guard_initial_hand_offset
			charged_guard_awaken_charge = 0.0
			charged_guard_fully_charged = false
			charged_guard_afterimages.clear()
			return
		if not charged_guard_fully_charged:
			var awaken_duration: float = maxf(0.05, get_combat_contact_setting("charged_guard_awaken_duration"))
			charged_guard_awaken_charge = minf(awaken_duration, charged_guard_awaken_charge + delta)
			if charged_guard_awaken_charge >= awaken_duration:
				charged_guard_fully_charged = true
				charged_guard_reposition_ramp = 0.0
				charged_guard_afterimage_timer = 0.0
				charged_guard_flash_left = 0.55
				charged_guard_afterimages.clear()
		if charged_guard_fully_charged:
			charged_guard_reposition_ramp = minf(1.0, charged_guard_reposition_ramp + delta / CHARGED_GUARD_REPOSITION_RAMP_TIME)
			# Sample the hand glow into the afterimage pool on a timer rather than
			# only while the hand slowly repositions, so the blue state always trails.
			charged_guard_afterimage_timer = maxf(0.0, charged_guard_afterimage_timer - delta)
			if charged_guard_afterimage_timer <= 0.0:
				charged_guard_afterimage_timer = CHARGED_GUARD_AFTERIMAGE_INTERVAL
				charged_guard_afterimages.push_front(charged_guard_lock_hand_offset)
				while charged_guard_afterimages.size() > CHARGED_GUARD_AFTERIMAGE_COUNT:
					charged_guard_afterimages.pop_back()
		if charged_guard_lock_hand_offset.length_squared() >= CHARGED_GUARD_MIN_HAND_RADIUS * CHARGED_GUARD_MIN_HAND_RADIUS:
			charged_guard_radial_direction = charged_guard_lock_hand_offset.normalized()
		# Conforming from the moment of lock, not only once blue, means the blade has
		# already settled by the charged transition, so nothing moves there either.
		charged_guard_lock_angle = charged_guard_conformed_blade_angle(charged_guard_lock_angle, charged_guard_lock_hand_offset, charged_guard_radial_direction, CHARGED_GUARD_BLADE_CONFORM_RATE, delta)
		return
	var current_transform: Dictionary = _sword_transform()
	var current_hilt: Vector2 = (current_transform["start"] as Vector2) - global_position
	# Acquisition follows the authored axial pull against the visible blade. The metronome
	# phase window supplies rhythm; cursor orbit direction is not an acquisition signal.
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(float(current_transform["angle"]))
	var pommel_alignment: float = charged_guard_pommel_alignment(blade_direction, charged_guard_authored_aim_velocity)
	var authored_speed: float = charged_guard_authored_aim_velocity.length()
	var deliberate_pommel_drive: bool = pommel_alignment >= get_combat_contact_setting("charged_guard_pommel_alignment") and authored_speed >= get_combat_contact_setting("charged_guard_pommel_speed")
	var phase_valid: bool = absf(cos(sword_phase)) <= get_combat_contact_setting("charged_guard_acquisition_window")
	if authored_speed >= get_combat_contact_setting("charged_guard_pommel_speed"):
		charged_guard_recent_motion_left = 0.16
	else:
		charged_guard_recent_motion_left = maxf(0.0, charged_guard_recent_motion_left - delta)
	var travel_needed: float = get_combat_contact_setting("charged_guard_pommel_travel")
	if not charged_guard_candidate_active:
		if charged_guard_reacquire_block_left > 0.0:
			charged_guard_pommel_travel = 0.0
			charged_guard_pommel_time = 0.0
			charged_guard_input_gap = 0.0
			return
		if deliberate_pommel_drive and phase_valid:
			charged_guard_input_gap = 0.0
			charged_guard_pommel_travel = minf(travel_needed, charged_guard_pommel_travel + authored_speed * pommel_alignment * delta)
			charged_guard_pommel_time += delta
		else:
			charged_guard_input_gap += delta
			if charged_guard_input_gap > CHARGED_GUARD_INPUT_GRACE:
				charged_guard_pommel_travel = 0.0
				charged_guard_pommel_time = 0.0
		var banked: bool = charged_guard_pommel_travel >= travel_needed and charged_guard_pommel_time >= get_combat_contact_setting("charged_guard_pommel_intent_time")
		if not banked:
			_log_charged_guard_acquisition(pommel_alignment, authored_speed, phase_valid, charged_guard_pommel_travel, charged_guard_pommel_time, 0.0, false, false)
			return
		charged_guard_candidate_active = true
		charged_guard_candidate_angle = float(current_transform["angle"])
		charged_guard_candidate_latch_left = CHARGED_GUARD_CANDIDATE_LATCH
		charged_guard_input_gap = 0.0
		_log_charged_guard_acquisition(pommel_alignment, authored_speed, phase_valid, charged_guard_pommel_travel, charged_guard_pommel_time, 0.0, true, true, "candidate")
		charged_guard_charge = 0.0
		return
	# The latch is a HARD total deadline, including time spent inside the angle tolerance.
	charged_guard_candidate_latch_left = maxf(0.0, charged_guard_candidate_latch_left - delta)
	var candidate_age: float = CHARGED_GUARD_CANDIDATE_LATCH - charged_guard_candidate_latch_left
	var guard_folded: bool = absf(angle_difference(charged_guard_candidate_angle, float(current_transform["angle"]))) <= deg_to_rad(CHARGED_GUARD_POSITION_TOLERANCE_DEGREES)
	if charged_guard_candidate_latch_left <= 0.0:
		_log_charged_guard_acquisition(pommel_alignment, authored_speed, phase_valid, charged_guard_pommel_travel, charged_guard_pommel_time, candidate_age, true, guard_folded, "expired")
		_clear_charged_guard_attempt()
		return
	_log_charged_guard_acquisition(pommel_alignment, authored_speed, phase_valid, charged_guard_pommel_travel, charged_guard_pommel_time, candidate_age, true, guard_folded)
	if not guard_folded:
		# Settle may resume within the deadline, but an interrupted shape earns no hold time.
		charged_guard_charge = 0.0
		return
	var hand_radius: float = current_hilt.length()
	var near_body: bool = hand_radius <= get_combat_contact_setting("charged_guard_near_body_radius")
	var recent_motion: bool = charged_guard_recent_motion_left > 0.0
	var charge_multiplier: float = charged_guard_charge_multiplier(near_body, recent_motion, deliberate_pommel_drive, get_combat_contact_setting("charged_guard_near_body_rate"), get_combat_contact_setting("charged_guard_recent_motion_rate"), get_combat_contact_setting("charged_guard_pommel_rate"))
	# The charge-time tuner cannot require a hold longer than the candidate's hard deadline.
	# Older presets with a longer value remain loadable and use this effective ceiling.
	var hold_duration: float = minf(get_combat_contact_setting("charged_guard_hold_duration"), CHARGED_GUARD_CANDIDATE_LATCH - 0.05)
	charged_guard_charge = minf(hold_duration, charged_guard_charge + delta * charge_multiplier)
	if charged_guard_charge >= hold_duration:
		_log_charged_guard_acquisition(pommel_alignment, authored_speed, phase_valid, charged_guard_pommel_travel, charged_guard_pommel_time, candidate_age, true, guard_folded, "lock")
		charged_guard_pommel_travel = 0.0
		charged_guard_pommel_time = 0.0
		var lock_angle: float = float(current_transform["angle"])
		charged_guard_locked = true
		charged_guard_candidate_active = false
		charged_guard_candidate_latch_left = 0.0
		charged_guard_lock_angle = lock_angle
		charged_guard_initial_lock_angle = lock_angle
		charged_guard_lock_hand_offset = current_hilt
		charged_guard_initial_hand_offset = current_hilt
		charged_guard_lock_radius = current_hilt.length()
		charged_guard_radial_direction = current_hilt.normalized() if current_hilt.length_squared() > 0.001 else Vector2.RIGHT
		charged_guard_flash_left = 0.18

static func authored_stroke_drive_increment(angular_travel_radians: float, gearing_degrees: float, authored_pace: float) -> float:
	var required_travel_radians: float = deg_to_rad(maxf(1.0, gearing_degrees))
	var pace_weight: float = smoothstep(TEMPO_ASSIST_INPUT_ENGAGEMENT_MIN, 1.0, clampf(authored_pace, 0.0, 1.0))
	return absf(angular_travel_radians) / required_travel_radians * pace_weight

func _update_sword(delta: float) -> void:
	if _authored_metronome_mode_applies() and authored_metronome_state == AuthoredMetronomeState.SHEATHED:
		blade_velocity = Vector2.ZERO
		previous_blade_start = Vector2.ZERO
		previous_blade_end = Vector2.ZERO
		previous_blade_samples.clear()
		current_blade_samples.clear()
		blade_trail_points.clear()
		hilt_trail_points.clear()
		return
	if blade_freeze_left > 0.0:
		# Clash/parry weapon freeze only -- flesh and hilt contact no longer use this
		# branch at all, see contact_drag_multiplier in the swing-phase advance below.
		# Player and hilt movement still matter. Real movement creates a slight tug/rip through the enemy.
		var freeze_data: Dictionary = _sword_transform()
		var f_angle: float = float(freeze_data["angle"])
		var f_dir: Vector2 = Vector2.RIGHT.rotated(f_angle)
		var f_start: Vector2 = (freeze_data["start"] as Vector2) - f_dir * BLADE_HILT_INSET
		var f_end: Vector2 = f_start + f_dir * BLADE_LENGTH

		# Compute real velocity generated by body/hilt motion during the bite, scaled by bite_velocity_transfer
		var v_transfer: float = clampf(get_combat_contact_setting("bite_velocity_transfer"), 0.0, 2.0)
		if previous_blade_end != Vector2.ZERO and delta > 0.0:
			var real_motion_vel: Vector2 = (f_end - previous_blade_end) / delta
			blade_velocity = real_motion_vel * v_transfer
		else:
			blade_velocity = Vector2.ZERO

		# Let an in-progress roll keep finishing smoothly even through a brief
		# clash/parry freeze, rather than visibly freezing mid-flip.
		_update_blade_roll_target(blade_velocity - velocity, f_dir, delta)
		_update_blade_roll(delta)
		previous_blade_samples = current_blade_samples if not current_blade_samples.is_empty() else _blade_polyline_samples(f_start, f_dir)
		current_blade_samples = _blade_polyline_samples(f_start, f_dir)
		previous_blade_start = f_start
		previous_blade_end = f_end
		return
	var previous_phase: float = sword_phase
	var swing_frequency: float = _sword_cycle_frequency()
	var slide_multiplier: float = get_combat_contact_setting("slide_speed")
	if is_experimental_bind_form() and experimental_bind_active:
		slide_multiplier = clampf(get_combat_hand_setting("bind_sword_speed"), 0.05, 1.0)
	# contact_drag_multiplier is the "shhk" of cutting through resistance: a brief
	# dip in swing-phase-advance rate on contact that recovers to 1.0 over time,
	# instead of Bite's old hard freeze + pinned angle.
	var sword_delta: float = delta * (slide_multiplier if has_live_blade_slide_contact() else 1.0) * contact_drag_multiplier
	if authored_apex_hang_left > 0.0:
		authored_apex_hang_left = maxf(0.0, authored_apex_hang_left - delta)
		sword_delta = 0.0
	if charged_guard_locked:
		sword_delta = 0.0
	if _authored_metronome_pauses_phase():
		sword_delta = 0.0
	var tempo_enabled: bool = get_combat_hand_setting("tempo_assist_enabled") >= 0.5 and _is_metronome_style()
	var autonomous_travel_sign: float = signf(cos(sword_phase))
	var stroke_progress_before_advance: float = metronome_stroke_progress(sword_phase)
	var drive_feature_enabled: bool = tempo_enabled or get_combat_hand_setting("directional_arc_opening_enabled") >= 0.5 or get_combat_hand_setting("authored_step_enabled") >= 0.5 or get_combat_contact_setting("apex_hang_time") >= 0.5
	var drive_input_aligned: bool = drive_feature_enabled and player_aim_turn_sign != 0.0 and player_aim_turn_sign == autonomous_travel_sign and authored_sword_engagement >= TEMPO_ASSIST_INPUT_ENGAGEMENT_MIN
	if drive_input_aligned and stroke_progress_before_advance <= STROKE_DRIVE_BUILD_PROGRESS_LIMIT:
		# Gesture gearing measures aligned hand travel, weighted by its authored pace.
		# A slow arc or tiny twitch adds little; a long fast straight flick adds more.
		var drive_increment: float = authored_stroke_drive_increment(authored_angular_travel_radians, get_combat_hand_setting("swing_gesture_gearing_degrees"), authored_sword_engagement)
		authored_stroke_drive = clampf(authored_stroke_drive + drive_increment, 0.0, 1.0)
	if tempo_enabled:
		tempo_assist_multiplier = lerpf(1.0, TEMPO_ASSIST_MAX_MULTIPLIER, authored_stroke_drive)
	else:
		tempo_assist_multiplier = 1.0
	if get_combat_hand_setting("directional_arc_opening_enabled") >= 0.5:
		directional_arc_extension_degrees = authored_stroke_drive * DIRECTIONAL_ARC_OPENING_DEGREES
	else:
		directional_arc_extension_degrees = 0.0
	sword_delta *= tempo_assist_multiplier
	var windup_profile: float = get_combat_hand_setting("windup_profile") if _is_windup_metronome_style() else 0.0
	if windup_profile > 0.0:
		var stroke_progress: float = metronome_stroke_progress(sword_phase)
		var windup_speed: float = metronome_windup_speed_multiplier(stroke_progress, windup_profile, get_combat_hand_setting("windup_fraction"), get_combat_hand_setting("recovery_fraction"), get_combat_hand_setting("windup_speed"), get_combat_hand_setting("strike_speed"), get_combat_hand_setting("recovery_speed"))
		sword_delta *= windup_speed
	# Form II's strike-speed burst can otherwise multiply the slide/bind slowdown
	# back above real time and swipe Form III through its opponent. During an owned
	# candidate/bind, the configured speed is an actual ceiling. The musical phase
	# remains continuous; it simply advances deliberately while the blades resist.
	if is_experimental_bind_form() and (experimental_bind_candidate or experimental_bind_active) and has_live_blade_slide_contact():
		var constrained_delta: float = delta * slide_multiplier * contact_drag_multiplier
		sword_delta = minf(sword_delta, constrained_delta)
	swing_time += sword_delta
	sword_phase = wrapf(sword_phase + sword_delta * swing_frequency * TAU, 0.0, TAU)

	var transform_data: Dictionary = _sword_transform()
	var current_angle: float = float(transform_data["angle"])

	# Keep Form I reversal timing unchanged. Form II resets once per actual stab.
	# Preset 4 uses the dominant stage's cadence (thrust in the first half of its blend).
	var thrust_cadence: bool = sword_style in [SwordStyle.THRUST, SwordStyle.THRUST_METRONOME]
	if combat_contact_preset == 4:
		var thrust_stage_end: float = clampf(get_combat_contact_setting("p4_stage1_end") / 100.0, 0.1, 0.5)
		thrust_cadence = p4_form_blend < thrust_stage_end * 0.5
	var stroke_boundaries: int = 0
	if thrust_cadence:
		stroke_boundaries = _thrust_stroke_index(previous_phase + sword_delta * swing_frequency * TAU) - _thrust_stroke_index(previous_phase)
	elif (cos(previous_phase) >= 0.0) != (cos(sword_phase) >= 0.0):
		stroke_boundaries = 1
	for _stroke_index: int in range(stroke_boundaries):
		var completed_stroke_drive: float = authored_stroke_drive
		if get_combat_contact_setting("apex_hang_time") >= 0.5 and completed_stroke_drive >= 0.5:
			# Binary Authored Apex Hang: 50% drive begins earning dwell; full drive
			# reaches 0.14 seconds. Contact freezes can still supersede this hold.
			authored_apex_hang_left = lerpf(0.0, get_combat_contact_setting("apex_hang_duration"), inverse_lerp(0.5, 1.0, completed_stroke_drive))
		# Option B: every new stroke earns acceleration, opening, and drive anew.
		tempo_assist_multiplier = 1.0
		authored_stroke_drive = 0.0
		directional_arc_extension_degrees = 0.0
		# Preserve bonuses and per-stroke hit suppression, including phase wrap.
		hit_ids.clear()
		swing_count += 1
		_begin_metronome_reversal_pulse(current_angle)
		if _is_windup_metronome_style():
			windup_forward_step_fired = false
			windup_backstep_fired = false
		if moon_slash_rank > 0:
			var slash_frequency: int = BonusConfig.moon_slash_swings(moon_slash_rank)
			if swing_count % slash_frequency == 0: _spawn_moon_slash(global_position + Vector2.RIGHT.rotated(current_angle) * 45.0, current_angle)
	if _is_windup_metronome_style():
		var previous_stroke_progress: float = metronome_stroke_progress(previous_phase)
		var current_stroke_progress: float = metronome_stroke_progress(sword_phase)
		var motion_sign: float = signf(cos(sword_phase))
		if motion_sign == 0.0: motion_sign = 1.0
		var travel_direction: Vector2 = Vector2.RIGHT.rotated(current_angle + PI * 0.5) * motion_sign
		if not windup_forward_step_fired:
			var forward_timing: float = clampf(get_combat_hand_setting("forward_impulse_timing"), 0.05, 0.95)
			var forward_impulse: float = maxf(0.0, get_combat_hand_setting("forward_impulse"))
			var authored_step_enabled: bool = get_combat_hand_setting("authored_step_enabled") >= 0.5
			var step_is_earned: bool = authored_step_enabled and authored_stroke_drive >= AUTHORED_STEP_DRIVE_THRESHOLD
			if forward_impulse > 0.0 and step_is_earned and current_stroke_progress >= forward_timing and previous_stroke_progress < forward_timing:
				var step_scale: float = authored_stroke_drive
				# Sample the live aim on the exact trigger frame. The forward step follows
				# the player's current mouse/stick location, while Backstep keeps using
				# the cutting tangent as its separate opposite-motion behavior.
				var step_direction: Vector2 = _current_aim_direction()
				velocity += step_direction * forward_impulse * step_scale
				windup_forward_step_fired = true
		if not windup_backstep_fired and get_combat_hand_setting("backstep_enabled") >= 0.5:
			var backstep_timing: float = clampf(get_combat_hand_setting("backstep_impulse_timing"), 0.05, 0.95)
			var backstep_impulse: float = maxf(0.0, get_combat_hand_setting("backstep_impulse"))
			if backstep_impulse > 0.0 and current_stroke_progress >= backstep_timing and previous_stroke_progress < backstep_timing:
				velocity -= travel_direction * backstep_impulse
				windup_backstep_fired = true
	var blade_anchor: Vector2 = transform_data["start"] as Vector2
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(current_angle)
	var current_start: Vector2 = blade_anchor - blade_direction * BLADE_HILT_INSET
	var current_end: Vector2 = current_start + blade_direction * BLADE_LENGTH
	# Wall recoil — if the blade tip is inside a wall, kick it back like a parry.
	var main_scene: Node = get_tree().current_scene
	if wall_recoil_cooldown <= 0.0 and main_scene.has_method("get_terrain_wall_collision"):
		var wall_hit: Dictionary = main_scene.get_terrain_wall_collision(blade_anchor, current_end, 2.0)
		if not wall_hit.is_empty():
			var wall_normal: Vector2 = wall_hit.get("normal", -blade_direction) as Vector2
			sword_hit_recoil_offset = sign(wall_normal.cross(blade_direction)) * deg_to_rad(sword_hit_recoil_degrees) * 0.7
			wall_recoil_cooldown = wall_recoil_cooldown_duration
			if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(wall_hit["position"] as Vector2, 1.0)
	var old_blade_end: Vector2 = previous_blade_end
	if old_blade_end != Vector2.ZERO:
		blade_velocity = (current_end - old_blade_end) / maxf(delta, 0.0001)
	_update_blade_roll_target(blade_velocity - velocity, blade_direction, delta)
	_update_blade_roll(delta)
	previous_blade_samples = current_blade_samples if not current_blade_samples.is_empty() else _blade_polyline_samples(current_start, blade_direction)
	current_blade_samples = _blade_polyline_samples(current_start, blade_direction)
	previous_blade_start = current_start
	previous_blade_end = current_end
	# The tip trail must trace the sword's actual (possibly curved) tip, not
	# the straight-line assumption current_end -- current_blade_samples' last
	# point is exactly that, for any blade shape. The hilt trail is already
	# correct as-is: every profile's t=0 point has offset 0 by construction.
	blade_trail_points.push_front(current_blade_samples[current_blade_samples.size() - 1])
	var max_trail_len: int = 42 if _is_moulinet_style() else 12
	if blade_trail_points.size() > max_trail_len: blade_trail_points.pop_back()
	if _uses_hilt_trail():
		hilt_trail_points.push_front(current_start)
		if hilt_trail_points.size() > 42: hilt_trail_points.pop_back()
	else:
		hilt_trail_points.clear()
	_check_sword_hits(current_start, current_end, delta)

func _check_sword_hits(_start: Vector2, _end: Vector2, delta: float) -> void:
	if clash_recovery_left > 0.0: return
	var main_scene: Node = get_tree().current_scene
	for campfire_node: Node in get_tree().get_nodes_in_group("zungar_campfire"):
		var campfire: BossCampfire = campfire_node as BossCampfire
		if campfire == null:
			continue
		for segment_index: int in range(current_blade_samples.size() - 1):
			if campfire.sword_crossed(current_blade_samples[segment_index], current_blade_samples[segment_index + 1]):
				sword_fire_left = sword_fire_duration
				break
	for projectile_node: Node in get_tree().get_nodes_in_group("enemy_projectiles"): 
		var projectile: EnemyProjectile = projectile_node as EnemyProjectile
		if projectile == null or not is_instance_valid(projectile): continue
		var projectile_visible: bool = not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(global_position, projectile.global_position, 2.0)
		if projectile_visible and can_deflect_projectile() and _distance_to_blade_polyline(projectile.global_position, current_blade_samples) <= BLADE_RADIUS + 14.0:
			if projectile.deflect():
				_set_sword_event("PROJECTILE", projectile.global_position)
				var projectile_main: Node = get_tree().current_scene
				if projectile_main.has_method("play_sfx"): projectile_main.play_sfx("projectile_deflect", 0.8)
				deflect_charges -= 1
	for tree_node: Node in get_tree().get_nodes_in_group("zungar_trees"):
		var tree: DestructibleTree = tree_node as DestructibleTree
		if tree == null or not is_instance_valid(tree) or tree.destroyed: continue
		if _distance_to_blade_polyline(tree.global_position, current_blade_samples) <= 24.0 and (not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(global_position, tree.global_position, 2.0)):
			var tree_id: int = tree.get_instance_id()
			if not hit_ids.has(tree_id):
				hit_ids[tree_id] = true
				tree.hit_by_sword(sword_damage)
	for obstruction_node: Node in get_tree().get_nodes_in_group("chakram_obstructions"):
		var obstruction: ArenaObject = obstruction_node as ArenaObject
		if obstruction == null or not is_instance_valid(obstruction) or obstruction.broken or not obstruction.is_visible_in_tree(): continue
		if _distance_to_blade_polyline(obstruction.global_position, current_blade_samples) <= 30.0:
			var obstruction_id: int = obstruction.get_instance_id()
			if not hit_ids.has(obstruction_id) and obstruction.hit_by_sword(sword_damage):
				hit_ids[obstruction_id] = true
				_trigger_clash(obstruction.global_position)
	for farmable_node: Node in get_tree().get_nodes_in_group("sword_farmables"):
		var farmable: ArenaObject = farmable_node as ArenaObject
		if farmable == null or not is_instance_valid(farmable) or farmable.broken or not farmable.is_visible_in_tree(): continue
		if _distance_to_blade_polyline(farmable.global_position, current_blade_samples) <= 22.0:
			var farmable_id: int = farmable.get_instance_id()
			if not hit_ids.has(farmable_id):
				hit_ids[farmable_id] = true
				if farmable.hit_by_sword(sword_damage):
					_trigger_farmable_harvest_hit(farmable.global_position)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null or not is_instance_valid(enemy): continue
		var id: int = enemy.get_instance_id()
		var enemy_visible: bool = not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(global_position, enemy.global_position, 2.0)
		if not enemy_visible: continue
		# Each enemy is tested against whichever sub-segment of the (possibly
		# curved) blade polyline is actually nearest it, not one straight
		# hilt->tip line -- see _blade_polyline_samples()/_closest_blade_segment().
		# enemy.gd's own interaction methods are untouched: they still get
		# exactly one segment per enemy per frame, same as before.
		var current_segment: Array = _closest_blade_segment(enemy.global_position, current_blade_samples)
		var seg_start: Vector2 = current_segment[0]
		var seg_end: Vector2 = current_segment[1]
		var seg_index: int = int(current_segment[2])
		var prev_seg_start: Vector2 = previous_blade_start
		var prev_seg_end: Vector2 = previous_blade_end
		if previous_blade_samples.size() == current_blade_samples.size() and seg_index + 1 < previous_blade_samples.size():
			prev_seg_start = previous_blade_samples[seg_index]
			prev_seg_end = previous_blade_samples[seg_index + 1]
		# Once a real slide has armed Form III, the weapon pair owns this contact
		# frame. Ordinary flesh/clash resolution stays suppressed while contact is
		# retained, so establishing defense never grants free offense or counters.
		var combat_enemy: Enemy = enemy as Enemy
		if combat_enemy != null and _update_experimental_bind_contact(combat_enemy, seg_start, seg_end, delta):
			continue
		if enemy.has_method("update_blade_contact"): enemy.update_blade_contact(seg_start, seg_end)
		# Mechanical slide weight follows live blade proximity. Spark/travel visuals
		# retain their authored lifetime, but movement and sword drag stop as soon as
		# this slide's blades have actually separated.
		if enemy == preset_2_slide_opponent and slide_cling_left > 0.0 and enemy.has_method("is_blade_contact"):
			if not enemy.is_blade_contact(seg_start, seg_end, get_combat_contact_setting("slide_contact_tolerance")):
				_end_live_blade_slide()
		if enemy.has_method("is_shield_blocking") and enemy.is_shield_blocking(seg_start, seg_end, parry_forgiveness):
			if enemy.has_method("shield_parry"): enemy.shield_parry(blade_velocity)
			_trigger_parry(enemy.global_position)
			continue
		if enemy.has_method("try_blade_slide") and enemy.try_blade_slide(seg_start, seg_end, blade_velocity, combat_contact_preset):
			var slide_point: Vector2 = enemy.call("get_slide_contact_global") as Vector2 if enemy.has_method("get_slide_contact_global") else enemy.global_position
			_trigger_blade_slide(slide_point, enemy)
			continue
		if enemy.has_method("is_blade_blocking") and enemy.is_blade_blocking(seg_start, seg_end, parry_forgiveness):
			var directional_parry: bool = true
			if (combat_contact_preset >= 2 or ParryRules.USE_DIRECTIONAL_PARRY_TEST) and enemy.has_method("get_blade_direction"):
				directional_parry = ParryRules.classify_weapon_interception(blade_velocity, enemy.get_blade_direction())
			if not directional_parry:
				# Check decoupled clash requirements (opposing angles, proximity tolerance, cooldown)
				var qualifies_clash: bool = true
				if combat_contact_preset >= 2 and enemy.has_method("is_blade_clashing"):
					qualifies_clash = enemy.is_blade_clashing(seg_start, seg_end)
				if qualifies_clash:
					if enemy.has_method("weapon_clash"): enemy.weapon_clash(blade_velocity, combat_contact_preset)
					_trigger_clash(enemy.global_position)
					continue
				else:
					# Glancing micro-contact: no mutual stagger shockwave lock
					_trigger_blade_contact(enemy.global_position)
					continue
			if enemy.has_method("parry_blade"): enemy.parry_blade(seg_start, seg_end, blade_velocity, combat_contact_preset)
			if disarm_rank > 0 and enemy.has_method("try_disarm"):
				enemy.try_disarm(BonusConfig.disarm_chance(disarm_rank))
			_trigger_parry(enemy.global_position)
			continue
		# Generic contact is the fallback classification, not an extra effect layered
		# under a Slide, Clash, or Parry from the same blade collision.
		if enemy.has_method("is_blade_contact") and enemy.is_blade_contact(seg_start, seg_end):
			if blade_contact_flash_left <= 0.0:
				_trigger_blade_contact(enemy.global_position)
			continue
		var contact: SwordContactData = SwordInteractionResolver.swept_contact(prev_seg_start, prev_seg_end, seg_start, seg_end, enemy.global_position, enemy_body_contact_radius, delta, velocity, sword_movement_damage_contribution, sword_movement_speed_cap)
		if contact.swept_distance > enemy_body_contact_radius: continue
		# Hilt Bash is classified by the actual contact position along the whole
		# (possibly curved) blade, not by distance from the player's body center.
		var whole_blade_fraction: float = _blade_path_fraction_for_segment(current_blade_samples, seg_index, contact.blade_position)
		var hilt_contact: bool = whole_blade_fraction <= hilt_bash_blade_fraction
		if hilt_contact:
			if get_combat_contact_setting("hilt_bash_enabled") >= 0.5:
				if float(enemy_rehit_cooldowns.get(id, 0.0)) <= 0.0:
					enemy_rehit_cooldowns[id] = enemy_rehit_cooldown_duration
					_trigger_hilt_bash(enemy, contact.contact_point)
			else:
				_set_sword_event("HILT CONTACT IGNORED", contact.contact_point, 0.18)
			continue
		# Player body overlap alone never enters this path: reaching here already
		# requires actual swept weapon geometry to touch the enemy. Do not cancel a
		# valid blade hit merely because the combatants' bodies are close together.
		if float(enemy_rehit_cooldowns.get(id, 0.0)) > 0.0:
			_set_sword_event("REHIT COOLDOWN", contact.contact_point, 0.22)
			continue
		if hit_ids.has(id):
			_set_sword_event("RECONTACT IGNORED", contact.contact_point, 0.22)
			continue
		var reentry_quality: float = _experimental_reentry_quality_for_contact(combat_enemy, contact) if combat_enemy != null else 0.0
		hit_ids[id] = true
		enemy_rehit_cooldowns[id] = enemy_rehit_cooldown_duration
		if enemy.has_method("take_damage"):
			if voltage_enabled and enemy.has_method("apply_voltage") and randf() < BonusConfig.voltage_chance(voltage_rank): enemy.apply_voltage(voltage_rank)
			if burning_rank > 0 and enemy.has_method("apply_burn"):
				var burn_chance: float = BonusConfig.burn_chance(burning_rank)
				if randf() < burn_chance: enemy.apply_burn(burning_rank)
			var commitment_req: float = get_combat_hand_setting("strike_commitment")
			var commitment_factor: float = 1.0
			if commitment_req > 0.0:
				var stroke_phase_speed: float = absf(cos(sword_phase))
				# Map commitment requirement to stroke velocity: flailing at turnaround/reversal scales damage down
				commitment_factor = lerpf(1.0, stroke_phase_speed, clampf(commitment_req, 0.0, 1.0))
			var authored_damage_multiplier: float = lerpf(passive_sword_damage_multiplier, engaged_sword_damage_multiplier, authored_sword_engagement)
			var impact_direction: Vector2 = contact.impact_normal
			var forte_knockback: float = forte_knockback_multiplier if whole_blade_fraction >= forte_zone_start_fraction and whole_blade_fraction < forte_zone_end_fraction else 1.0
			var reentry_stagger_multiplier: float = lerpf(1.0, maxf(1.0, get_combat_hand_setting("bind_reentry_stagger")), reentry_quality)
			var reentry_damage_multiplier: float = lerpf(1.0, maxf(1.0, get_combat_hand_setting("bind_reentry_damage")), reentry_quality)
			var blade_position_multiplier: float = cutting_zone_damage_multiplier(whole_blade_fraction, forte_zone_start_fraction, cutting_zone_base_damage_multiplier, cutting_zone_tip_damage_multiplier)
			var stagger_duration: float = lerpf(get_combat_contact_setting("flesh_stagger_min"), get_combat_contact_setting("flesh_stagger_max"), contact.impact_quality) * (0.6 + commitment_factor * 0.4) * reentry_stagger_multiplier
			var total_damage_multiplier: float = additive_sword_damage_multiplier(contact.damage_multiplier(), authored_damage_multiplier, commitment_factor, blade_position_multiplier, reentry_damage_multiplier)
			var dealt_damage: float = sword_damage * total_damage_multiplier
			if sword_fire_left > 0.0 and enemy.has_method("take_fire_damage"):
				enemy.take_fire_damage(dealt_damage, impact_direction * (140.0 + contact.impact_quality * 220.0) * forte_knockback, stagger_duration, contact.impact_quality)
			else:
				enemy.take_damage(dealt_damage, impact_direction * (140.0 + contact.impact_quality * 220.0) * forte_knockback, stagger_duration, contact.impact_quality)
			var typed_enemy: Enemy = enemy as Enemy
			var current_main: Node = get_tree().current_scene
			if typed_enemy != null and current_main.has_method("spawn_enemy_hit_presentation"):
				current_main.spawn_enemy_hit_presentation(typed_enemy, contact.contact_point, contact.blade_velocity, contact.blade_direction, contact.impact_quality, typed_enemy.health <= 0.0, true)
			_trigger_successful_sword_hit(contact)
			if reentry_quality > 0.0:
				_consume_experimental_reentry(contact, reentry_quality)
			notify_player_damage_dealt(true)
		gain_flow(5.0)
	for active_chakram: Chakram in active_chakrams:
		if not is_instance_valid(active_chakram): continue
		var chakram_segment: Array = _closest_blade_segment(active_chakram.global_position, current_blade_samples)
		var chakram_seg_start: Vector2 = chakram_segment[0]
		var chakram_seg_end: Vector2 = chakram_segment[1]
		var chakram_contact_distance: float = _distance_to_segment(active_chakram.global_position, chakram_seg_start, chakram_seg_end)
		if chakram_contact_distance <= BLADE_RADIUS + 24.0:
			var successful_bat: bool = active_chakram.hit_by_player_sword(chakram_seg_start, blade_velocity, sword_to_chakram_weight, inherited_chakram_weight, min_chakram_bat_speed, max_chakram_bat_speed)
			if successful_bat:
				_set_sword_event("CHAKRAM", active_chakram.global_position)
				_trigger_chakram_bat(active_chakram, active_chakram.global_position)
		elif chakram_contact_distance > BLADE_RADIUS + 34.0:
			active_chakram.release_sword_contact()

func _set_sword_event(label: String, point: Vector2, duration: float = 0.45, debug_extra: Dictionary = {}) -> void:
	sword_event_label = label
	sword_event_point = point
	sword_event_left = duration
	_emit_combat_debug_event(label, debug_extra)

func _emit_combat_debug_event(event_type: String, extra: Dictionary = {}) -> void:
	var details: Dictionary = {
		"form": _style_name(),
		"contact_time": experimental_bind_total_contact_time,
		"pressure": experimental_bind_pressure,
		"player_pressure": experimental_bind_player_pressure,
		"pressure_spike": experimental_bind_player_pressure - experimental_bind_previous_player_pressure,
		"tangent_speed": experimental_bind_tangent_speed,
		"tangent_travel": experimental_bind_tangent_travel,
		"leverage": experimental_bind_leverage,
		"player_fraction": _closest_path_fraction(experimental_bind_contact_point, current_blade_samples),
		"enemy_fraction": experimental_bind_enemy_fraction
	}
	details.merge(extra, true)
	match event_type:
		"STABLE BIND": experimental_bind_count += 1
		"WIND": experimental_wind_count += 1
		"WEAPON BEAT": experimental_beat_count += 1
		"BEAT REJECTED": experimental_rejected_beat_count += 1
	if debug_print_sword_events and event_type in BIND_LIFECYCLE_EVENT_TYPES:
		print("BIND: ", event_type, " | ", _format_combat_debug_details(details))
	combat_debug_event.emit(event_type, details)
	queue_redraw()

## Compact, grep-friendly console line for the bind lifecycle so console/log
## output can be read for tuning without needing a screenshot of the HUD.
func _format_combat_debug_details(details: Dictionary) -> String:
	var parts: PackedStringArray = []
	if details.has("reason"):
		parts.append("reason=%s" % str(details["reason"]))
	if details.has("failed_check"):
		parts.append("failed=%s" % str(details["failed_check"]))
	parts.append("P %.0f" % float(details.get("pressure", 0.0)))
	parts.append("auth %.0f" % float(details.get("player_pressure", 0.0)))
	parts.append("spike %.0f" % float(details.get("pressure_spike", 0.0)))
	parts.append("travel %.0f" % float(details.get("tangent_travel", 0.0)))
	parts.append("lev %.2f" % float(details.get("leverage", 0.0)))
	parts.append("contact %.2fs" % float(details.get("contact_time", 0.0)))
	if details.has("required_pressure"):
		parts.append("need P>=%.0f" % float(details["required_pressure"]))
	if details.has("required_spike"):
		parts.append("need spike>=%.0f" % float(details["required_spike"]))
	if details.has("required_leverage"):
		parts.append("need lev>=%.2f" % float(details["required_leverage"]))
	return " ".join(parts)

## Dips the swing's phase-advance rate on contact, then recovers back to full
## speed over recovery_time seconds. This is the "shhk, cutting through
## resistance" replacement for the old Bite freeze -- no frozen angle, no
## stored offset, no catch-up snap; the swing just keeps going, slower for
## a moment. A no-op for dip <= 0.
func _trigger_contact_drag(dip: float, recovery_time: float) -> void:
	if dip <= 0.0: return
	contact_drag_multiplier = clampf(1.0 - dip, 0.0, 1.0)
	contact_drag_recovery_rate = dip / maxf(recovery_time, 0.001)

func _trigger_hilt_bash(enemy: Node, contact_point: Vector2) -> void:
	_set_sword_event("HILT BASH", contact_point, 0.35)
	var main_scene: Node = get_tree().current_scene
	var push_direction: Vector2 = global_position.direction_to(contact_point)
	if push_direction.length_squared() < 0.001: push_direction = Vector2.UP
	var base_impulse: float = get_combat_contact_setting("hilt_bash_knockback")
	var stun_duration: float = get_combat_contact_setting("hilt_bash_stun")
	var chip_damage: float = get_combat_contact_setting("hilt_bash_damage")
	var target_impulse_multiplier: float = (enemy as Enemy).hilt_bash_impulse_multiplier if enemy is Enemy else 1.0
	var applied_impulse: float = base_impulse * target_impulse_multiplier
	if enemy.has_method("take_damage"):
		enemy.take_damage(chip_damage, push_direction * applied_impulse, stun_duration, 0.5)
		notify_player_damage_dealt(false)
	if enemy is Enemy:
		var typed_enemy: Enemy = enemy as Enemy
		typed_enemy.dizzy_stars_left = stun_duration
		typed_enemy.stun_left = maxf(typed_enemy.stun_left, stun_duration)
	# Player recoil off the hilt strike
	velocity -= push_direction * 45.0
	_trigger_contact_drag(get_combat_contact_setting("hilt_contact_drag"), get_combat_contact_setting("hilt_contact_drag_recovery"))
	# Impact Presentation
	if main_scene.has_method("spawn_impact_fx"):
		main_scene.spawn_impact_fx(contact_point, 0.8)
	if main_scene.has_method("request_screen_shake"):
		main_scene.request_screen_shake(2.5, 0.10, push_direction)
	if main_scene.has_method("play_sfx"):
		main_scene.play_sfx("flesh_hit", 1.1, 0.75)

## 1-shot farmables (herbs, mushrooms, shrubs, moon flowers) are plants, not
## flesh -- this is deliberately the barest touch of feedback so a harvest
## registers as *something* without borrowing the weight of a real hit: a
## tiny hitstop and a tiny contact-drag dip. No screen shake, no camera
## punch, no impact sparks, no player recoil, no sfx.
func _trigger_farmable_harvest_hit(hit_position: Vector2) -> void:
	_set_sword_event("HARVEST", hit_position, 0.18)
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("request_hitstop"):
		main_scene.request_hitstop(get_combat_contact_setting("farmable_hitstop"))
	_trigger_contact_drag(get_combat_contact_setting("farmable_contact_drag"), get_combat_contact_setting("farmable_contact_drag_recovery"))

func _trigger_successful_sword_hit(contact: SwordContactData) -> void:
	_set_sword_event("FLESH HIT", contact.contact_point)
	var main_scene: Node = get_tree().current_scene
	var hitstop_duration: float = lerpf(get_combat_contact_setting("flesh_hitstop_min"), get_combat_contact_setting("flesh_hitstop_max"), contact.impact_quality)
	if enable_flesh_hit_feedback:
		flesh_contact_slow_left = flesh_contact_movement_slow_duration
		velocity += contact.impact_normal * get_combat_contact_setting("flesh_recoil")
		if main_scene.has_method("request_screen_shake"):
			main_scene.request_screen_shake(get_combat_contact_setting("flesh_shake_strength") * (0.7 + contact.impact_quality * 0.3), get_combat_contact_setting("flesh_shake_duration"), contact.impact_normal)
	_trigger_contact_drag(get_combat_contact_setting("flesh_contact_drag") * (0.6 + contact.impact_quality * 0.4), get_combat_contact_setting("flesh_contact_drag_recovery"))
	if main_scene.has_method("request_hitstop"): main_scene.request_hitstop(hitstop_duration)
	if main_scene.has_method("spawn_impact_fx"):
		var spark_intensity: float = strong_hit_spark_intensity if contact.impact_quality >= strong_hit_quality_threshold else 0.65 + contact.impact_quality * 0.55
		if combat_contact_preset == 4:
			spark_intensity *= lerpf(0.75, 1.45, clampf(flow / 100.0, 0.0, 1.0))
		main_scene.spawn_impact_fx(contact.contact_point, spark_intensity)
	if main_scene.has_method("spawn_tuned_combat_presentation"):
		var flesh_imp: float = get_combat_contact_setting("flesh_impact")
		if combat_contact_preset == 4:
			flesh_imp *= lerpf(0.75, 1.45, clampf(flow / 100.0, 0.0, 1.0))
		main_scene.spawn_tuned_combat_presentation(contact.contact_point, contact.blade_velocity, flesh_imp, get_combat_contact_setting("flesh_zoom"), get_combat_contact_setting("flesh_zoom_duration"), contact.impact_quality)
	if main_scene.has_method("play_sfx"):
		var contact_pitch: float = main_scene.get_combat_hit_pitch(contact.impact_quality) if main_scene.has_method("get_combat_hit_pitch") else 1.0
		main_scene.play_sfx("flesh_hit", 0.8 + contact.impact_quality * 0.35, contact_pitch)
	var swing_direction_sign: float = sign(contact.blade_direction.cross(contact.blade_velocity))
	if swing_direction_sign == 0.0: swing_direction_sign = 1.0
	var recoil_strength: float = lerpf(0.35, 1.0, contact.impact_quality)
	var active_blade_recoil: float = get_combat_contact_setting("blade_recoil_degrees")
	var recoil_deg: float = sword_hit_recoil_degrees if combat_contact_preset == 1 else active_blade_recoil
	sword_hit_recoil_offset = -swing_direction_sign * deg_to_rad(recoil_deg) * recoil_strength
	# Grip authority and rebound flow setup:
	rebound_flow_sign = -swing_direction_sign
	var grip_duration: float = get_combat_contact_setting("grip_authority_duration")
	grip_authority_left = grip_duration
	# Flesh hits use contact drag (above), not a hard freeze -- see
	# _trigger_contact_drag(). Clash/parry still freeze via blade_freeze_left,
	# set separately in _trigger_clash()/_trigger_parry().

func _update_chain_lightning(delta: float) -> void:
	var chain_targets: Array[Chakram] = []
	for active_chakram: Chakram in active_chakrams:
		if is_instance_valid(active_chakram) and not active_chakram.grounded:
			chain_targets.append(active_chakram)
	if chain_lightning_level <= 0 or chain_targets.size() < 2:
		chain_lightning_timer = 0.0
		return
	chain_lightning_timer -= delta
	if chain_lightning_timer > 0.0: return
	chain_lightning_timer = BonusConfig.chain_lightning_interval(chain_lightning_level)
	chain_lightning_flash = 0.22
	var chain_damage: float = BonusConfig.chain_lightning_damage(chain_lightning_level)
	for index: int in range(chain_targets.size() - 1):
		var first: Chakram = chain_targets[index]
		var second: Chakram = chain_targets[index + 1]
		if not is_instance_valid(first) or not is_instance_valid(second): continue
		for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
			var enemy: Node2D = enemy_node as Node2D
			if enemy != null and _distance_to_segment(enemy.global_position, first.global_position, second.global_position) < 18.0 and enemy.has_method("take_damage"):
				enemy.take_damage(chain_damage, first.global_position.direction_to(second.global_position) * 90.0)
				notify_player_damage_dealt(false)

func _spawn_moon_slash(origin: Vector2, _angle: float) -> void:
	var slash: MoonSlash = MOON_SLASH_SCENE.instantiate() as MoonSlash
	get_parent().add_child(slash)
	var slash_damage: float = BonusConfig.moon_slash_damage(moon_slash_rank)
	var slash_size: float = 1.0 + float(maxi(0, moon_slash_rank - 1)) * 0.18
	slash.launch(origin, _current_aim_direction(), slash_damage, slash_size, self)

func _trigger_blade_contact(point: Vector2) -> void:
	blade_contact_flash_left = 0.09
	_set_sword_event("BLADE CONTACT", point, 0.18)
	var main_scene: Node = get_tree().current_scene
	var contact_direction: Vector2 = global_position.direction_to(point)
	var impact_strength: float = get_combat_contact_setting("contact_impact")
	if impact_strength > 0.0 and main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(point, impact_strength)
	if main_scene.has_method("request_hitstop"): main_scene.request_hitstop(get_combat_contact_setting("contact_hitstop"))
	if main_scene.has_method("request_screen_shake"): main_scene.request_screen_shake(get_combat_contact_setting("contact_shake_strength"), get_combat_contact_setting("contact_shake_duration"), contact_direction)
	if main_scene.has_method("spawn_tuned_combat_presentation"): main_scene.spawn_tuned_combat_presentation(point, contact_direction, impact_strength, get_combat_contact_setting("contact_zoom"), get_combat_contact_setting("contact_zoom_duration"))

func _experimental_sword_control_delta(delta: float) -> float:
	if not experimental_bind_active:
		return delta
	# CombatPresentationFX applies this exact sustained scale. Dividing only by
	# the authored bind scale keeps aim/metronome responsive while leaving brief
	# ordinary impact hitstop perceptible.
	var world_scale: float = clampf(get_combat_hand_setting("bind_focus_time_scale"), 0.2, 1.0)
	return delta / world_scale

func _begin_experimental_bind_candidate(opponent: Enemy, point: Vector2) -> void:
	if not is_experimental_bind_form() or get_combat_hand_setting("bind_enabled") < 0.5:
		return
	if opponent == null or not is_instance_valid(opponent) or experimental_bind_cooldown_left > 0.0:
		return
	# A bind has exactly one collision owner. Other armed enemies continue using
	# ordinary slide/clash behavior, but cannot replace this opponent and create a
	# multi-sword pin while the current candidate/bind is alive.
	if (experimental_bind_candidate or experimental_bind_active) and is_instance_valid(experimental_bind_opponent):
		return
	# Candidates are called only by Enemy.try_blade_slide(), after parallel,
	# moving weapon geometry has passed. No gesture or raw contact can arm one.
	experimental_bind_opponent = opponent
	experimental_bind_candidate = true
	experimental_bind_active = false
	experimental_bind_contact_seen = true
	experimental_bind_stable_time = 0.0
	experimental_bind_elapsed = 0.0
	experimental_bind_missing_time = 0.0
	experimental_bind_contact_point = point
	experimental_bind_pressure = 0.0
	experimental_bind_previous_pressure = 0.0
	experimental_bind_player_pressure = 0.0
	experimental_bind_previous_player_pressure = 0.0
	experimental_bind_tangent_speed = 0.0
	experimental_bind_tangent_travel = 0.0
	experimental_bind_leverage = 0.0
	experimental_bind_start_enemy_fraction = 0.5
	experimental_bind_enemy_fraction = 0.5
	experimental_bind_total_contact_time = 0.0
	experimental_bind_start_roll = blade_roll
	experimental_bind_roll_crossed = false
	experimental_bind_beat_consumed = false
	experimental_bind_last_enemy_direction = opponent.get_blade_direction().normalized()
	var current_angle: float = float(_sword_transform()["angle"])
	experimental_bind_hinge_side = experimental_hinge_side(current_angle, experimental_bind_last_enemy_direction.angle(), blade_velocity.dot(experimental_bind_last_enemy_direction.orthogonal()))
	experimental_bind_release_reason = ""
	experimental_bind_outcome = ""
	experimental_bind_wind_reported = false
	_emit_combat_debug_event("BIND CANDIDATE", {"required_capture": get_combat_hand_setting("bind_capture_time"), "required_pressure": get_combat_hand_setting("bind_pressure_min")})
	if experimental_reentry_opponent == opponent:
		_clear_experimental_reentry()

static func experimental_hinge_side(player_angle: float, enemy_angle: float, fallback_normal_motion: float = 0.0) -> float:
	var aligned_enemy_angle: float = enemy_angle
	if absf(wrapf(player_angle - aligned_enemy_angle, -PI, PI)) > PI * 0.5:
		aligned_enemy_angle += PI
	var relative_angle: float = wrapf(player_angle - aligned_enemy_angle, -PI, PI)
	if absf(relative_angle) > deg_to_rad(0.25):
		return signf(relative_angle)
	if not is_zero_approx(fallback_normal_motion):
		return -signf(fallback_normal_motion)
	return 1.0

static func experimental_hinge_correction(player_angle: float, enemy_angle: float, hinge_side: float, strength: float, delta: float, stable: bool) -> float:
	var clean_strength: float = clampf(strength, 0.0, 1.0)
	if clean_strength <= 0.0 or delta <= 0.0:
		return 0.0
	var aligned_enemy_angle: float = enemy_angle
	if absf(wrapf(player_angle - aligned_enemy_angle, -PI, PI)) > PI * 0.5:
		aligned_enemy_angle += PI
	var clean_side: float = -1.0 if hinge_side < 0.0 else 1.0
	var relative_angle: float = wrapf(player_angle - aligned_enemy_angle, -PI, PI)
	var side_clearance: float = relative_angle * clean_side
	var stop_clearance: float = deg_to_rad(2.5)
	# Once the player opens more than ten degrees away from the opposing blade,
	# stop helping entirely. This preserves intentional disengagement and ensures
	# the constraint cannot magnetically reacquire separated weapons.
	if side_clearance > deg_to_rad(10.0):
		return 0.0
	var desired_angle: float = aligned_enemy_angle + clean_side * stop_clearance
	var correction_rate: float
	if side_clearance < stop_clearance:
		# Crossing the owned side meets a firm unilateral stop. It is deliberately
		# stronger than parallel retention, but still eased to avoid visible snaps.
		correction_rate = lerpf(30.0, 72.0, clean_strength) if stable else lerpf(18.0, 42.0, clean_strength)
	else:
		correction_rate = (8.0 if stable else 4.0) * clean_strength
	var correction_weight: float = 1.0 - exp(-correction_rate * delta)
	return clampf(angle_difference(player_angle, desired_angle) * correction_weight, -deg_to_rad(14.0), deg_to_rad(14.0))

func _apply_experimental_bind_retention(delta: float) -> void:
	if not (experimental_bind_candidate or experimental_bind_active) or not is_instance_valid(experimental_bind_opponent):
		return
	# Once a frame has confirmed separation, release grace is memory only. Do not
	# pull the weapon back from a gap and accidentally turn retention into a magnet.
	if experimental_bind_missing_time > 0.0:
		return
	var strength: float = clampf(get_combat_hand_setting("bind_retention_strength"), 0.0, 1.0)
	if strength <= 0.0:
		return
	var sword_data: Dictionary = _sword_transform()
	var current_angle: float = float(sword_data["angle"])
	var enemy_angle: float = experimental_bind_opponent.get_blade_direction().angle()
	var correction: float = experimental_hinge_correction(current_angle, enemy_angle, experimental_bind_hinge_side, strength, delta, experimental_bind_active)
	aim_angle += correction
	elbow_angle += correction

func _closest_path_fraction(point: Vector2, samples: PackedVector2Array) -> float:
	if samples.size() < 2:
		return 0.0
	var total_length: float = maxf(_blade_path_length(samples), 0.001)
	var passed_length: float = 0.0
	var nearest_distance: float = INF
	var nearest_path_distance: float = 0.0
	for index: int in range(samples.size() - 1):
		var segment: Vector2 = samples[index + 1] - samples[index]
		var segment_length: float = segment.length()
		if segment_length <= 0.001:
			continue
		var factor: float = clampf((point - samples[index]).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var closest: Vector2 = samples[index] + segment * factor
		var distance: float = point.distance_squared_to(closest)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_path_distance = passed_length + segment_length * factor
		passed_length += segment_length
	return clampf(nearest_path_distance / total_length, 0.0, 1.0)

static func _segment_fraction(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	if segment.length_squared() <= 0.001:
		return 0.0
	return clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)

static func experimental_disengagement_qualifies(contact_time: float, tangent_travel: float, start_fraction: float, end_fraction: float, leverage: float, minimum_time: float, minimum_travel: float, minimum_fraction_delta: float, endpoint_zone: float, minimum_leverage: float) -> bool:
	if contact_time < minimum_time or tangent_travel < minimum_travel or leverage < minimum_leverage:
		return false
	var clamped_endpoint_zone: float = clampf(endpoint_zone, 0.01, 0.49)
	var exited_near_hilt: bool = end_fraction <= clamped_endpoint_zone and start_fraction - end_fraction >= minimum_fraction_delta
	var exited_near_tip: bool = end_fraction >= 1.0 - clamped_endpoint_zone and end_fraction - start_fraction >= minimum_fraction_delta
	return exited_near_hilt or exited_near_tip

static func experimental_reentry_quality(impact_speed: float, inward_speed: float, remaining_window: float, total_window: float, minimum_impact_speed: float, minimum_inward_speed: float) -> float:
	if impact_speed < minimum_impact_speed or inward_speed < minimum_inward_speed or remaining_window <= 0.0:
		return 0.0
	var speed_quality: float = clampf((impact_speed - minimum_impact_speed) / maxf(minimum_impact_speed, 1.0), 0.0, 1.0)
	var inward_quality: float = clampf((inward_speed - minimum_inward_speed) / maxf(minimum_inward_speed, 1.0), 0.0, 1.0) if minimum_inward_speed > 0.0 else 1.0
	var memory_quality: float = clampf(remaining_window / maxf(total_window, 0.001), 0.0, 1.0)
	return clampf(0.45 + speed_quality * 0.25 + inward_quality * 0.20 + memory_quality * 0.10, 0.0, 1.0)

func _update_experimental_bind_contact(enemy: Enemy, blade_start: Vector2, blade_end: Vector2, delta: float) -> bool:
	if enemy != experimental_bind_opponent or not (experimental_bind_candidate or experimental_bind_active):
		return false
	if not is_instance_valid(enemy):
		_release_experimental_bind("opponent lost")
		return false
	var tolerance: float = clampf(get_combat_hand_setting("bind_contact_tolerance"), 7.0, 30.0)
	var touching: bool = enemy.is_blade_contact(blade_start, blade_end, tolerance)
	if not touching:
		# Keep ownership only through the short configured contact-memory window.
		return experimental_bind_candidate or experimental_bind_active
	experimental_bind_contact_seen = true
	experimental_bind_missing_time = 0.0
	var enemy_segment: Dictionary = enemy._enemy_weapon_segment()
	var enemy_start: Vector2 = enemy_segment["start"] as Vector2
	var enemy_end: Vector2 = enemy_segment["end"] as Vector2
	# Enemy.get_slide_contact_global() is a deliberately cached presentation
	# point. Mechanics instead rebuild the nearest midpoint projection every
	# frame, allowing real tangential travel into either endpoint zone.
	var player_midpoint: Vector2 = (blade_start + blade_end) * 0.5
	var enemy_contact_factor: float = _segment_fraction(player_midpoint, enemy_start, enemy_end)
	var enemy_contact_point: Vector2 = enemy_start.lerp(enemy_end, enemy_contact_factor)
	var player_contact_factor: float = _segment_fraction(enemy_contact_point, blade_start, blade_end)
	var player_contact_point: Vector2 = blade_start.lerp(blade_end, player_contact_factor)
	experimental_bind_contact_point = (enemy_contact_point + player_contact_point) * 0.5
	var enemy_direction: Vector2 = enemy.get_blade_direction().normalized()
	var relative_velocity: Vector2 = blade_velocity - enemy.velocity
	var authored_blade_velocity: Vector2 = blade_velocity - velocity
	var signed_tangent_speed: float = relative_velocity.dot(enemy_direction)
	experimental_bind_previous_pressure = experimental_bind_pressure
	experimental_bind_previous_player_pressure = experimental_bind_player_pressure
	experimental_bind_pressure = absf(relative_velocity.dot(enemy_direction.orthogonal()))
	experimental_bind_player_pressure = absf(authored_blade_velocity.dot(enemy_direction.orthogonal()))
	experimental_bind_tangent_speed = absf(signed_tangent_speed)
	experimental_bind_tangent_travel += experimental_bind_tangent_speed * delta
	experimental_bind_total_contact_time += delta
	experimental_bind_last_enemy_direction = enemy_direction
	var enemy_fraction: float = _segment_fraction(experimental_bind_contact_point, enemy_start, enemy_end)
	var player_fraction: float = _closest_path_fraction(experimental_bind_contact_point, current_blade_samples)
	# Positive leverage means the player is contacting closer to their own hilt
	# than the enemy is to theirs: the physically favorable lever relationship.
	experimental_bind_leverage = clampf(enemy_fraction - player_fraction, -1.0, 1.0)
	if experimental_bind_total_contact_time <= delta * 1.5:
		experimental_bind_start_enemy_fraction = enemy_fraction
	experimental_bind_enemy_fraction = enemy_fraction
	if absf(blade_roll) <= 0.18 or signf(blade_roll) != signf(experimental_bind_start_roll):
		experimental_bind_roll_crossed = true
	experimental_bind_elapsed += delta
	if experimental_bind_active:
		slide_cling_left = maxf(slide_cling_left, 0.05)
		_update_experimental_bind_focus()
		var wind_threshold: float = maxf(2.0, get_combat_hand_setting("bind_disengage_min_travel"))
		if not experimental_bind_wind_reported and experimental_bind_tangent_travel >= wind_threshold:
			experimental_bind_wind_reported = true
			_emit_combat_debug_event("WIND", {"required_travel": wind_threshold})
		if experimental_bind_tangent_speed >= 24.0 and slide_audio_left <= 0.0:
			_play_slide_scrape_audio(experimental_bind_tangent_speed)
		if _try_experimental_weapon_beat(enemy, enemy_direction):
			return true
		if experimental_bind_elapsed >= maxf(0.2, get_combat_hand_setting("bind_max_duration")):
			_release_experimental_bind("duration limit")
			return false
		return true
	var minimum_pressure: float = maxf(0.0, get_combat_hand_setting("bind_pressure_min"))
	if experimental_bind_pressure >= minimum_pressure:
		experimental_bind_stable_time += delta
	else:
		experimental_bind_stable_time = maxf(0.0, experimental_bind_stable_time - delta * 0.5)
	var capture_time: float = clampf(get_combat_hand_setting("bind_capture_time"), 0.02, 0.40)
	if experimental_bind_stable_time >= capture_time:
		_activate_experimental_bind()
		return true
	if experimental_bind_elapsed >= maxf(0.5, capture_time * 4.0):
		_release_experimental_bind("insufficient pressure")
		return false
	return true

func _try_experimental_weapon_beat(enemy: Enemy, enemy_direction: Vector2) -> bool:
	if experimental_bind_beat_consumed or experimental_bind_elapsed < 0.04:
		return false
	# Enemy/body motion may help maintain a defensive bind, but only the player's
	# authored blade motion can earn an offensive weapon beat.
	var pressure_spike: float = experimental_bind_player_pressure - experimental_bind_previous_player_pressure
	var required_pressure: float = maxf(0.0, get_combat_hand_setting("bind_beat_pressure"))
	var required_spike: float = maxf(0.0, get_combat_hand_setting("bind_beat_spike"))
	if experimental_bind_player_pressure < required_pressure or pressure_spike < required_spike:
		return false
	experimental_bind_beat_consumed = true
	var required_leverage: float = clampf(get_combat_hand_setting("bind_beat_leverage"), -1.0, 1.0)
	var main_scene: Node = get_tree().current_scene if is_inside_tree() else null
	if experimental_bind_leverage >= required_leverage:
		var beat_stagger: float = clampf(get_combat_hand_setting("bind_beat_stagger"), 0.05, 0.80)
		var beat_recoil: float = maxf(0.0, get_combat_hand_setting("bind_beat_recoil"))
		enemy.receive_weapon_beat(blade_velocity, beat_stagger, beat_recoil)
		experimental_bind_outcome = "WEAPON BEAT"
		_set_sword_event("WEAPON BEAT", experimental_bind_contact_point, 0.40, {"required_pressure": required_pressure, "required_spike": required_spike, "required_leverage": required_leverage})
		_start_contact_sparks(experimental_bind_contact_point, int(get_combat_hand_setting("clash_sparks")), Color(1.0, 0.78, 0.22), blade_velocity)
		if main_scene != null and main_scene.has_method("spawn_impact_fx"):
			main_scene.call("spawn_impact_fx", experimental_bind_contact_point, 0.85, ImpactFX.ImpactType.CLASH)
		if main_scene != null and main_scene.has_method("play_sfx"):
			main_scene.call("play_sfx", "sword_clash", 0.90, 0.92)
		_release_experimental_bind("weapon beat")
		return true
	# High force from a poor lever relationship rebounds into the player. This is
	# the primary anti-spam consequence: no arbitrary damage, just lost position.
	var beat_normal: Vector2 = enemy_direction.orthogonal()
	var normal_sign: float = signf(blade_velocity.dot(beat_normal))
	if is_zero_approx(normal_sign):
		normal_sign = 1.0
	var failed_recoil: float = maxf(0.0, get_combat_hand_setting("bind_failed_beat_recoil"))
	velocity -= beat_normal * normal_sign * failed_recoil
	sword_hit_recoil_offset -= normal_sign * deg_to_rad(8.0)
	experimental_bind_outcome = "BEAT REJECTED"
	_set_sword_event("BEAT REJECTED", experimental_bind_contact_point, 0.40, {"required_pressure": required_pressure, "required_spike": required_spike, "required_leverage": required_leverage, "failed_check": "leverage"})
	_release_experimental_bind("bad leverage")
	return true

func _activate_experimental_bind() -> void:
	if experimental_bind_active or not is_instance_valid(experimental_bind_opponent):
		return
	experimental_bind_candidate = false
	experimental_bind_active = true
	experimental_bind_elapsed = 0.0
	_set_sword_event("STABLE BIND", experimental_bind_contact_point, 0.35)
	_update_experimental_bind_focus()

func _update_experimental_bind_focus() -> void:
	if not experimental_bind_active or not is_inside_tree():
		return
	var main_scene: Node = get_tree().current_scene
	if main_scene != null and main_scene.has_method("set_experimental_bind_focus"):
		main_scene.call("set_experimental_bind_focus", true, experimental_bind_contact_point, clampf(get_combat_hand_setting("bind_focus_time_scale"), 0.2, 1.0), clampf(get_combat_hand_setting("bind_focus_zoom"), 0.0, 0.30), clampf(get_combat_hand_setting("bind_focus_bias"), 0.0, 1.0), clampf(get_combat_hand_setting("bind_focus_response"), 1.0, 20.0))

func _finish_experimental_bind_frame(delta: float) -> void:
	if not (experimental_bind_candidate or experimental_bind_active):
		return
	if not is_instance_valid(experimental_bind_opponent):
		_release_experimental_bind("opponent lost")
		return
	if experimental_bind_contact_seen:
		return
	experimental_bind_missing_time += delta
	if experimental_bind_missing_time > clampf(get_combat_hand_setting("bind_release_grace"), 0.0, 0.35):
		_release_experimental_bind("blade separation")

func _arm_experimental_disengagement() -> bool:
	if not experimental_bind_active or not is_instance_valid(experimental_bind_opponent):
		return false
	var qualifies: bool = experimental_disengagement_qualifies(
		experimental_bind_elapsed,
		experimental_bind_tangent_travel,
		experimental_bind_start_enemy_fraction,
		experimental_bind_enemy_fraction,
		experimental_bind_leverage,
		clampf(get_combat_hand_setting("bind_disengage_min_time"), 0.02, 0.40),
		maxf(0.0, get_combat_hand_setting("bind_disengage_min_travel")),
		clampf(get_combat_hand_setting("bind_disengage_fraction_delta"), 0.0, 0.80),
		clampf(get_combat_hand_setting("bind_disengage_endpoint"), 0.01, 0.49),
		clampf(get_combat_hand_setting("bind_disengage_leverage"), -1.0, 1.0)
	)
	if not qualifies:
		return false
	experimental_reentry_opponent = experimental_bind_opponent
	experimental_reentry_total_window = clampf(get_combat_hand_setting("bind_reentry_window"), 0.10, 0.60)
	experimental_reentry_time_left = experimental_reentry_total_window
	experimental_reentry_release_point = experimental_bind_contact_point
	experimental_reentry_inward_direction = experimental_bind_contact_point.direction_to(experimental_bind_opponent.global_position)
	if experimental_reentry_inward_direction.length_squared() <= 0.001:
		experimental_reentry_inward_direction = -experimental_bind_last_enemy_direction.orthogonal()
	experimental_reentry_leverage = experimental_bind_leverage
	# Rollover does not trigger the technique. It only names/communicates a real
	# orientation change after the geometric guard wrap already qualified.
	experimental_reentry_was_rollover = experimental_bind_roll_crossed and signf(blade_roll) != signf(experimental_bind_start_roll) and absf(blade_roll) >= 0.55
	experimental_bind_outcome = "ROLLOVER DISENGAGE" if experimental_reentry_was_rollover else "GUARD WRAP"
	_set_sword_event(experimental_bind_outcome, experimental_bind_contact_point, 0.45)
	return true

func _experimental_reentry_quality_for_contact(enemy: Enemy, contact: SwordContactData) -> float:
	if not is_experimental_bind_form() or enemy != experimental_reentry_opponent or experimental_reentry_time_left <= 0.0:
		return 0.0
	var inward_speed: float = maxf(0.0, contact.blade_velocity.dot(experimental_reentry_inward_direction))
	return experimental_reentry_quality(contact.impact_speed, inward_speed, experimental_reentry_time_left, experimental_reentry_total_window, maxf(0.0, get_combat_hand_setting("bind_reentry_min_speed")), maxf(0.0, get_combat_hand_setting("bind_reentry_inward_speed")))

func _consume_experimental_reentry(contact: SwordContactData, quality: float) -> void:
	if quality <= 0.0:
		return
	experimental_bind_outcome = "ROLLOVER RE-ENTRY" if experimental_reentry_was_rollover else "GUARD-WRAP RE-ENTRY"
	_set_sword_event(experimental_bind_outcome, contact.contact_point, 0.50)
	_clear_experimental_reentry()

func _clear_experimental_reentry() -> void:
	experimental_reentry_opponent = null
	experimental_reentry_time_left = 0.0
	experimental_reentry_total_window = 0.0
	experimental_reentry_release_point = Vector2.ZERO
	experimental_reentry_inward_direction = Vector2.RIGHT
	experimental_reentry_leverage = 0.0
	experimental_reentry_was_rollover = false

func _release_experimental_bind(reason: String) -> void:
	var had_bind_state: bool = experimental_bind_candidate or experimental_bind_active
	if not had_bind_state:
		return
	var released_opponent: Enemy = experimental_bind_opponent
	if reason == "blade separation" and experimental_bind_active:
		_arm_experimental_disengagement()
	experimental_bind_release_reason = reason
	_emit_combat_debug_event("BIND RELEASE", {"reason": reason, "was_stable": experimental_bind_active})
	experimental_bind_cooldown_left = maxf(experimental_bind_cooldown_left, get_combat_hand_setting("bind_rebind_cooldown"))
	if experimental_bind_active and is_inside_tree():
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method("set_experimental_bind_focus"):
			main_scene.call("set_experimental_bind_focus", false, experimental_bind_contact_point, 1.0, 0.0, 0.0, clampf(get_combat_hand_setting("bind_focus_response"), 1.0, 20.0))
	experimental_bind_opponent = null
	experimental_bind_candidate = false
	experimental_bind_active = false
	experimental_bind_contact_seen = false
	experimental_bind_hinge_side = 1.0
	experimental_bind_stable_time = 0.0
	experimental_bind_elapsed = 0.0
	experimental_bind_missing_time = 0.0
	if released_opponent == preset_2_slide_opponent:
		_end_live_blade_slide()

func _setup_slide_audio_player() -> void:
	slide_audio_player = AudioStreamPlayer.new()
	slide_audio_player.name = "SlideAudioPlayer"
	slide_audio_player.bus = &"SFX"
	slide_audio_player.stream = METAL_SCRAPE_AUDIO
	slide_audio_player.volume_db = -2.0
	add_child(slide_audio_player)

func _play_slide_scrape_audio(relative_speed: float) -> void:
	if slide_audio_player == null or slide_audio_left > 0.0: return
	# Faster blade movement raises the pitch of the metallic friction scrape
	var speed_factor: float = clampf(relative_speed / 600.0, 0.0, 1.0)
	var base_pitch: float = lerpf(0.88, 1.18, speed_factor)
	var jitter: float = randf_range(-0.06, 0.06)
	slide_audio_player.pitch_scale = clampf(base_pitch + jitter, 0.75, 1.35)
	# Keep the imported recording strictly one-shot and bounded. During a stable
	# Form III bind the player may author sparse scrape pulses, still never a loop.
	slide_audio_left = clampf(get_combat_hand_setting("bind_scrape_interval"), 0.08, 0.60) if experimental_bind_active else 0.45
	var start_pos: float = randf_range(0.0, 0.12)
	slide_audio_player.play(start_pos)

func has_live_blade_slide_contact(opponent: Enemy = null) -> bool:
	if slide_cling_left <= 0.0 or not is_instance_valid(preset_2_slide_opponent):
		return false
	return opponent == null or opponent == preset_2_slide_opponent

func _refresh_live_blade_slide_state() -> void:
	# Bind candidate/active state has its own contact geometry and release grace.
	# Do not let the narrower ordinary-Slide tolerance pre-empt that authority.
	if preset_2_slide_opponent == experimental_bind_opponent and (experimental_bind_candidate or experimental_bind_active):
		return
	if not has_live_blade_slide_contact():
		if preset_2_slide_opponent != null:
			_end_live_blade_slide()
		return
	if current_blade_samples.size() < 2:
		return
	var current_segment: Array = _closest_blade_segment(preset_2_slide_opponent.global_position, current_blade_samples)
	var segment_start: Vector2 = current_segment[0] as Vector2
	var segment_end: Vector2 = current_segment[1] as Vector2
	if not preset_2_slide_opponent.is_blade_contact(segment_start, segment_end, get_combat_contact_setting("slide_contact_tolerance")):
		_end_live_blade_slide()

func _end_live_blade_slide() -> void:
	var released_opponent: Enemy = preset_2_slide_opponent
	slide_cling_left = 0.0
	preset_2_slide_opponent = null
	# Presentation may resolve, but it must read as a release rather than another
	# second of contact. Mechanical movement and sword drag have already ended.
	preset_2_slide_visual_left = minf(preset_2_slide_visual_left, 0.10)
	if is_instance_valid(released_opponent):
		released_opponent.end_blade_slide_contact()
	if slide_audio_player != null and slide_audio_player.is_playing():
		slide_audio_player.stop()
	slide_audio_left = 0.0

func _trigger_blade_slide(point: Vector2, opponent: Node2D = null) -> void:
	notify_sword_contact()
	var next_opponent: Enemy = opponent as Enemy
	if preset_2_slide_opponent != null and preset_2_slide_opponent != next_opponent:
		_end_live_blade_slide()
	slide_cling_left = get_combat_contact_setting("slide_cling")
	# Despite the legacy name, this is also the live mechanical slide owner used
	# to stop cling when geometry separates in any contact preset.
	preset_2_slide_opponent = next_opponent
	if combat_contact_preset >= 2:
		preset_2_slide_visual_left = get_combat_contact_setting("slide_duration")
		preset_2_slide_contact_point = point
		var transform_data: Dictionary = _sword_transform()
		var blade_anchor: Vector2 = transform_data["start"] as Vector2
		var blade_angle: float = float(transform_data["angle"])
		var blade_dir: Vector2 = Vector2.RIGHT.rotated(blade_angle)
		preset_2_slide_distance_on_blade = clampf((point - blade_anchor).dot(blade_dir), 12.0, BLADE_LENGTH)
	_set_sword_event("SLIDE", point)
	sword_slide_count += 1
	print("Sword slide detected #", sword_slide_count)
	_begin_experimental_bind_candidate(opponent as Enemy, point)
	_play_slide_scrape_audio(blade_velocity.length())
	var main_scene: Node = get_tree().current_scene
	var slide_direction: Vector2 = global_position.direction_to(point)
	if main_scene != null and main_scene.has_method("request_hitstop"): main_scene.request_hitstop(get_combat_contact_setting("slide_hitstop"))
	if main_scene != null and main_scene.has_method("request_screen_shake"): main_scene.request_screen_shake(get_combat_contact_setting("slide_shake_strength"), get_combat_contact_setting("slide_shake_duration"), slide_direction)
	if main_scene != null and main_scene.has_method("spawn_tuned_combat_presentation"): main_scene.spawn_tuned_combat_presentation(point, blade_velocity, get_combat_contact_setting("slide_impact"), get_combat_contact_setting("slide_zoom"), get_combat_contact_setting("slide_zoom_duration"))
	if combat_contact_preset == 1: velocity -= global_position.direction_to(point) * 35.0

func _start_contact_sparks(point: Vector2, count: int, color: Color, direction: Vector2 = Vector2.RIGHT) -> void:
	contact_spark_point = point
	contact_spark_count = maxi(0, count)
	contact_spark_color = color
	contact_spark_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector2.RIGHT
	contact_spark_left = 0.22 if contact_spark_count > 0 else 0.0

func _trigger_parry(point: Vector2) -> void:
	notify_sword_contact()
	_set_sword_event("PARRY", point)
	_start_contact_sparks(point, int(get_combat_hand_setting("parry_sparks")), Color(0.25, 0.85, 1.0), blade_velocity)
	if debug_print_sword_events: print("Sword event: PARRY at ", point)
	var main_scene: Node = get_tree().current_scene
	var parry_quality: float = clampf(blade_velocity.length() / maxf(full_swing_speed_reference, 1.0), 0.0, 1.0)
	var active_hitstop: float = get_combat_contact_setting("parry_hitstop")
	if main_scene.has_method("request_hitstop"): main_scene.request_hitstop(active_hitstop)
	var parry_impact: float = get_combat_contact_setting("parry_impact")
	if int(get_combat_hand_setting("parry_sparks")) > 0 and main_scene.has_method("spawn_impact_fx"):
		main_scene.spawn_impact_fx(point, parry_impact, ImpactFX.ImpactType.PARRY)
	if main_scene.has_method("request_screen_shake"):
		main_scene.request_screen_shake(get_combat_contact_setting("parry_shake_strength"), get_combat_contact_setting("parry_shake_duration"), global_position.direction_to(point))
	if main_scene.has_method("spawn_tuned_parry_focus_fx"):
		main_scene.spawn_tuned_parry_focus_fx(point, blade_velocity, parry_quality, get_combat_contact_setting("parry_focus"), get_combat_contact_setting("parry_focus_duration"), get_combat_contact_setting("parry_zoom"), get_combat_contact_setting("parry_zoom_duration"), parry_impact)
	if main_scene.has_method("play_sfx"):
		var parry_pitch: float = main_scene.get_combat_hit_pitch(parry_quality) if main_scene.has_method("get_combat_hit_pitch") else 1.0
		main_scene.play_sfx("parry", 1.25, parry_pitch)
	var active_recoil: float = get_combat_contact_setting("parry_player_recoil")
	velocity -= global_position.direction_to(point) * active_recoil
	clash_recovery_left = get_combat_contact_setting("parry_recovery")
	lose_flow(get_combat_contact_setting("clash_flow") * 0.5)
	# Weapon recoil & rebound flow on parry:
	var parry_blade_recoil: float = get_combat_contact_setting("blade_recoil_degrees")
	if parry_blade_recoil > 0.0:
		var parry_sign: float = sign(global_position.direction_to(point).cross(blade_velocity))
		if parry_sign == 0.0: parry_sign = 1.0
		sword_hit_recoil_offset = -parry_sign * deg_to_rad(parry_blade_recoil) * 0.75
		rebound_flow_sign = -parry_sign
	var grip_duration: float = get_combat_contact_setting("grip_authority_duration")
	grip_authority_left = grip_duration
	var freeze_dur: float = get_combat_contact_setting("blade_freeze_duration")
	if freeze_dur > 0.0:
		frozen_blade_world_angle = float((_sword_transform())["angle"])
		blade_freeze_left = freeze_dur

func _trigger_clash(point: Vector2) -> void:
	notify_sword_contact()
	_set_sword_event("CLASH", point)
	_start_contact_sparks(point, int(get_combat_hand_setting("clash_sparks")), Color(1.0, 0.65, 0.15), blade_velocity)
	if debug_print_sword_events: print("Sword event: CLASH at ", point)
	var main_scene: Node = get_tree().current_scene
	var active_hitstop: float = get_combat_contact_setting("clash_hitstop")
	if main_scene.has_method("request_hitstop"): main_scene.request_hitstop(active_hitstop)
	var recoil_direction: Vector2 = global_position.direction_to(point)
	var clash_impact: float = get_combat_contact_setting("clash_impact")
	if int(get_combat_hand_setting("clash_sparks")) > 0 and main_scene.has_method("spawn_impact_fx"):
		main_scene.spawn_impact_fx(point, clash_impact, ImpactFX.ImpactType.CLASH)
	if main_scene.has_method("request_screen_shake"):
		main_scene.request_screen_shake(get_combat_contact_setting("clash_shake_strength"), get_combat_contact_setting("clash_shake_duration"), recoil_direction)
	if main_scene.has_method("spawn_tuned_combat_presentation"):
		main_scene.spawn_tuned_combat_presentation(point, recoil_direction, clash_impact, get_combat_contact_setting("clash_zoom"), get_combat_contact_setting("clash_zoom_duration"), 1.0)
	if main_scene.has_method("play_sfx"): main_scene.play_sfx("sword_clash", 1.25)
	var active_recoil: float = get_combat_contact_setting("clash_player_recoil")
	velocity -= recoil_direction * active_recoil
	clash_recovery_left = get_combat_contact_setting("clash_recovery")
	lose_flow(get_combat_contact_setting("clash_flow"))
	# Weapon recoil & rebound flow on clash (Preset 1 keeps its original behavior).
	var clash_blade_recoil: float = get_combat_contact_setting("blade_recoil_degrees")
	if combat_contact_preset >= 2 and clash_blade_recoil > 0.0:
		var clash_sign: float = sign(recoil_direction.cross(blade_velocity))
		if clash_sign == 0.0: clash_sign = 1.0
		sword_hit_recoil_offset = -clash_sign * deg_to_rad(clash_blade_recoil)
		rebound_flow_sign = -clash_sign
	var grip_duration: float = get_combat_contact_setting("grip_authority_duration")
	grip_authority_left = grip_duration
	var freeze_dur: float = get_combat_contact_setting("blade_freeze_duration")
	if freeze_dur > 0.0:
		frozen_blade_world_angle = float((_sword_transform())["angle"])
		blade_freeze_left = freeze_dur

func _trigger_chakram_bat(batted_chakram: Chakram, point: Vector2) -> void:
	report_tutorial_action("chakram_batted", batted_chakram)
	var main_scene: Node = get_tree().current_scene
	var bat_quality: float = clampf((blade_velocity.length() - min_chakram_bat_speed) / maxf(1.0, max_chakram_bat_speed - min_chakram_bat_speed), 0.0, 1.0)
	if main_scene.has_method("request_hitstop"): main_scene.request_hitstop(chakram_bat_hit_stop)
	if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(point, clampf(blade_velocity.length() / 500.0, 0.8, 1.8))
	if main_scene.has_method("spawn_chakram_bat_presentation"): main_scene.spawn_chakram_bat_presentation(batted_chakram, batted_chakram.velocity, bat_quality)
	if main_scene.has_method("play_sfx"):
		var bat_pitch: float = main_scene.get_combat_hit_pitch(bat_quality) if main_scene.has_method("get_combat_hit_pitch") else 1.0
		main_scene.play_sfx("chakram_bat", clampf(blade_velocity.length() / 500.0, 0.8, 1.5), bat_pitch)

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001: return point.distance_to(start)
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * factor)

func get_flow_enemy_speed_multiplier() -> float:
	# Ordinary Flow no longer slows the world. Only the explicit Adrenaline
	# bonus grants enemy/projectile slowdown, preserving Flow as a reward without
	# making sustained successful play passively reduce the game's difficulty.
	if adrenaline_rank <= 0 or flow < BonusConfig.adrenaline_threshold(adrenaline_rank):
		return 1.0
	return 1.0 - BonusConfig.adrenaline_slow(adrenaline_rank, flow)

func gain_flow(amount: float) -> void:
	flow = clampf(flow + amount, 0.0, 100.0)
	flow_idle_time = 0.0
	flow_changed.emit(flow, 100.0)

func lose_flow(amount: float) -> void:
	flow = maxf(0.0, flow - amount)
	flow_changed.emit(flow, 100.0)

func take_damage(amount: float, knockback_force: Vector2 = Vector2.ZERO, attacker: Node2D = null) -> void:
	if invulnerable > 0.0 or health <= 0.0: return
	hit_stagger_left = hit_stagger_time
	hit_knockback = knockback_force if knockback_force != Vector2.ZERO else -_current_aim_direction() * hit_knockback_strength
	_emit_frost_nova(attacker)
	flow = maxf(0.0, flow - 20.0)
	flow_changed.emit(flow, 100.0)
	var incoming_damage: float = maxf(0.0, amount)
	var reduced_damage: float = maxf(0.0, incoming_damage - BonusConfig.defense_reduction(defense_rank))
	var mitigated_damage: float = incoming_damage - reduced_damage
	var actual_damage_received: float = minf(health, reduced_damage)
	health = maxf(0.0, health - actual_damage_received)
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("record_damage_received"): main_scene.record_damage_received(actual_damage_received)
	if actual_damage_received > 0.0 and main_scene.has_method("spawn_damage_number"):
		main_scene.spawn_damage_number(global_position, actual_damage_received, true)
	if main_scene.has_method("record_damage_mitigated"): main_scene.record_damage_mitigated(mitigated_damage)
	if main_scene.has_method("play_sfx"): main_scene.play_sfx("player_hit", 1.0)
	if main_scene.has_method("request_screen_shake"):
		var damage_shake_scale: float = clampf(reduced_damage / 10.0, 0.5, 1.5)
		main_scene.request_screen_shake(player_hit_screen_shake_strength * damage_shake_scale, player_hit_screen_shake_duration, hit_knockback)
	health_bar.value = health
	health_bar.visible = health < max_health
	health_bar.modulate = Color(1.0, 0.15, 0.1).lerp(Color(0.2, 1.0, 0.25), health / max_health)
	health_changed.emit(health, max_health)
	invulnerable = damage_immunity_duration
	if health <= 0.0:
		if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())
		player_died.emit()

func restore_health(amount: float, track_for_run: bool = true) -> float:
	if health <= 0.0 or amount <= 0.0: return 0.0
	var actual_healing: float = minf(max_health - health, amount)
	if actual_healing <= 0.0: return 0.0
	health += actual_healing
	health_bar.value = health
	health_bar.visible = health < max_health
	health_changed.emit(health, max_health)
	if track_for_run:
		var main_scene: Node = get_tree().current_scene
		if main_scene.has_method("record_damage_healed"): main_scene.record_damage_healed(actual_healing)
	return actual_healing

func heal_from_kill() -> void:
	if vampirism_rank <= 0 or health <= 0.0: return
	restore_health(float(BonusConfig.vampirism_heal(vampirism_rank)))

func collect_chakram(collected_chakram: Chakram) -> void:
	if is_instance_valid(collected_chakram):
		if grapple_controller != null: grapple_controller.release_if_target(collected_chakram)
		collected_chakram.collect()
		chakram_charges = mini(max_chakram_charges, chakram_charges + 1)

func set_transition_facing(direction: float) -> void:
	transition_facing_direction = signf(direction)
	queue_redraw()

func prepare_for_map_transition() -> void:
	if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())
	velocity = Vector2.ZERO
	hit_knockback = Vector2.ZERO
	dash_left = 0.0
	terrain_root_left = 0.0
	terrain_movement_modifiers.clear()
	terrain_dash_block_sources.clear()
	flow_trail_points.clear()
	blade_trail_points.clear()
	if flow_fx != null: flow_fx.reset()
	previous_blade_start = Vector2.ZERO
	previous_blade_end = Vector2.ZERO
	current_blade_samples = PackedVector2Array()
	previous_blade_samples = PackedVector2Array()
	blade_velocity = Vector2.ZERO
	chakram_aim_trail_left = 0.0
	hit_ids.clear()
	enemy_rehit_cooldowns.clear()
	flash_step_flash = 0.0
	queue_redraw()

func clear_active_chakrams(restore_charges: bool = true) -> void:
	if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())
	var returning_count: int = 0
	for active_chakram: Chakram in active_chakrams:
		if is_instance_valid(active_chakram):
			returning_count += 1
			active_chakram.queue_free()
	active_chakrams.clear()
	chakram = null
	if restore_charges:
		chakram_charges = mini(max_chakram_charges, chakram_charges + returning_count)

func set_expedition_food_bonuses(health_bonus: float, regeneration_per_second: float) -> void:
	var old_maximum: float = max_health
	expedition_food_health_bonus = maxf(0.0, health_bonus)
	expedition_food_regeneration = maxf(0.0, regeneration_per_second)
	max_health = BonusConfig.health_maximum(health_bonus_rank) + expedition_food_health_bonus
	if max_health > old_maximum:
		health = minf(max_health, health + (max_health - old_maximum))
	else:
		health = minf(health, max_health)
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = health < max_health
	health_changed.emit(health, max_health)

func reset_run_bonuses() -> void:
	if grapple_controller != null: grapple_controller.cancel_and_latch(_grapple_button_pressed())
	hit_ids.clear()
	enemy_rehit_cooldowns.clear()
	bash_dash_hit_ids.clear()
	health_bonus_rank = 0
	chakram_charge_rank = 0
	dash_bonus_rank = 0
	bash_dash_rank = 0
	frost_nova_rank = 0
	regeneration_rank = 0
	voltage_rank = 0
	flash_step_rank = 0
	expedition_food_health_bonus = 0.0
	expedition_food_regeneration = 0.0
	max_health = 100.0
	health = max_health
	max_dash_charges = 1
	dash_charges = 1
	chakram_charges = 1
	max_chakram_charges = 1
	chakram_pierce = 0
	chakram_explosion_level = 0
	frost_nova_enabled = false
	frost_nova_cooldown_left = 0.0
	ice_slide_modifiers.clear()
	regeneration_enabled = false
	magnetic_level = 0
	defense_rank = 0
	voltage_enabled = false
	burning_rank = 0
	deflect_rank = 0
	deflect_charges = 0
	deflect_recharge_left = 0.0
	moon_slash_rank = 0
	flash_step_enabled = false
	disarm_rank = 0
	void_dash_level = 0
	chain_lightning_level = 0
	vampirism_rank = 0
	adrenaline_rank = 0
	resonant_glyph_rank = 0
	resonant_glyph_spawn_left = 0.0
	terrain_movement_modifiers.clear()
	terrain_dash_block_sources.clear()
	terrain_root_left = 0.0
	chain_lightning_timer = 0.0
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false

func apply_bonus(bonus_id: String) -> void:
	BonusConfig.apply_to_player(self, bonus_id)

func _emit_frost_nova(attacker: Node2D = null) -> void:
	if not frost_nova_enabled or frost_nova_cooldown_left > 0.0: return
	frost_nova_cooldown_left = BonusConfig.frost_nova_cooldown(frost_nova_rank)
	frost_nova_flash = 0.5
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null: return
	var main_scene: Node = scene_tree.current_scene
	var patch: IcePatch = ICE_PATCH_SCRIPT.new() as IcePatch
	var patch_parent: Node = main_scene if main_scene != null else get_parent()
	if patch_parent != null:
		patch_parent.add_child(patch)
		patch.setup(self, global_position, BonusConfig.frost_nova_radius(frost_nova_rank), FROST_NOVA_PATCH_DURATION)
	var frozen_target: Node2D = attacker if attacker != null and is_instance_valid(attacker) else null
	if frozen_target == null or not frozen_target.has_method("stun_for"):
		var nearest_distance: float = INF
		for node: Node in scene_tree.get_nodes_in_group("enemies"):
			var candidate: Node2D = node as Node2D
			if candidate == null or not is_instance_valid(candidate) or not candidate.has_method("stun_for"): continue
			var candidate_distance: float = global_position.distance_to(candidate.global_position)
			if candidate_distance <= 72.0 and candidate_distance < nearest_distance:
				nearest_distance = candidate_distance
				frozen_target = candidate
	if frozen_target != null and frozen_target.has_method("stun_for"):
		frozen_target.call("stun_for", BonusConfig.frost_nova_stun(frost_nova_rank))
	if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("clash", 0.45)
	if main_scene != null and main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 1.25)

func report_tutorial_action(event_type: String, target: Node = null) -> void:
	tutorial_action.emit(event_type, target)

func _on_chakram_exited(exited_chakram: Chakram) -> void:
	active_chakrams.erase(exited_chakram)
	if chakram == exited_chakram:
		chakram = active_chakrams[0] if not active_chakrams.is_empty() else null

func _draw_pixel_knight() -> void:
	var aim_direction: Vector2 = _current_aim_direction()
	var facing_left: bool = transition_facing_direction < 0.0 if not is_zero_approx(transition_facing_direction) else aim_direction.x < 0.0
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing_left else Vector2.ONE
	draw_set_transform(Vector2.ZERO, 0.0, facing_scale)
	var outline: Color = Color("182033")
	var deepest_shadow: Color = Color("111827")
	var steel_dark: Color = Color("3f5268")
	var steel: Color = Color("9eb4c7")
	var steel_light: Color = Color("d7e6ec")
	var blue_cape: Color = Color("244b78")
	var blue_highlight: Color = Color("3f83b5")
	var leather: Color = Color("704153")
	var gold: Color = Color("d9a84d")
	# Wind-blown cloak: deliberately stepped rather than smooth.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, -8.0), Vector2(-25.0, -3.0), Vector2(-21.0, 3.0),
		Vector2(-27.0, 11.0), Vector2(-19.0, 14.0), Vector2(-22.0, 21.0),
		Vector2(-7.0, 17.0), Vector2(1.0, 9.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12.0, -6.0), Vector2(-21.0, -1.0), Vector2(-17.0, 3.0),
		Vector2(-23.0, 9.0), Vector2(-16.0, 10.0), Vector2(-18.0, 16.0),
		Vector2(-7.0, 13.0), Vector2(0.0, 7.0)
	]), blue_cape)
	draw_rect(Rect2(-17.0, 1.0, 6.0, 4.0), blue_highlight)
	draw_rect(Rect2(-14.0, 8.0, 5.0, 3.0), blue_highlight)
	# Back leg and boot.
	draw_rect(Rect2(-9.0, 9.0, 8.0, 14.0), outline)
	draw_rect(Rect2(-7.0, 10.0, 5.0, 11.0), steel_dark)
	draw_rect(Rect2(-10.0, 20.0, 10.0, 5.0), deepest_shadow)
	draw_rect(Rect2(-8.0, 19.0, 6.0, 3.0), leather)
	# Forward leg and boot.
	draw_rect(Rect2(2.0, 8.0, 9.0, 16.0), outline)
	draw_rect(Rect2(4.0, 9.0, 5.0, 13.0), steel)
	draw_rect(Rect2(4.0, 12.0, 5.0, 3.0), steel_light)
	draw_rect(Rect2(0.0, 21.0, 13.0, 5.0), deepest_shadow)
	draw_rect(Rect2(3.0, 20.0, 7.0, 3.0), leather)
	# Armored torso and belt.
	draw_rect(Rect2(-13.0, -8.0, 26.0, 21.0), outline)
	draw_rect(Rect2(-10.0, -6.0, 20.0, 17.0), steel_dark)
	draw_rect(Rect2(-7.0, -5.0, 14.0, 13.0), steel)
	draw_rect(Rect2(-5.0, -4.0, 6.0, 4.0), steel_light)
	draw_rect(Rect2(-10.0, 7.0, 20.0, 5.0), leather)
	draw_rect(Rect2(-5.0, 7.0, 5.0, 4.0), gold)
	# Shoulder plates and gauntleted arms.
	draw_rect(Rect2(-15.0, -8.0, 7.0, 8.0), outline)
	draw_rect(Rect2(-14.0, -7.0, 5.0, 5.0), steel)
	draw_rect(Rect2(8.0, -8.0, 8.0, 8.0), outline)
	draw_rect(Rect2(9.0, -7.0, 5.0, 5.0), steel_light)
	draw_rect(Rect2(12.0, -3.0, 5.0, 11.0), outline)
	draw_rect(Rect2(13.0, -2.0, 3.0, 8.0), steel_dark)
	# Helmet, crest, visor, and eye slit.
	draw_rect(Rect2(-12.0, -23.0, 24.0, 17.0), outline)
	draw_rect(Rect2(-9.0, -25.0, 18.0, 4.0), outline)
	draw_rect(Rect2(-9.0, -21.0, 18.0, 13.0), steel)
	draw_rect(Rect2(-6.0, -24.0, 10.0, 4.0), steel_light)
	draw_rect(Rect2(-8.0, -14.0, 17.0, 5.0), deepest_shadow)
	draw_rect(Rect2(-5.0, -13.0, 10.0, 2.0), gold)
	draw_rect(Rect2(-2.0, -13.0, 3.0, 2.0), Color("fff1a6"))
	draw_rect(Rect2(-5.0, -27.0, 4.0, 3.0), blue_cape)
	draw_rect(Rect2(-4.0, -30.0, 3.0, 4.0), blue_highlight)
	# Pixel glint and grounded shadow.
	draw_rect(Rect2(-8.0, -19.0, 3.0, 3.0), Color(1.0, 1.0, 1.0, 0.55))
	draw_rect(Rect2(-13.0, 25.0, 25.0, 3.0), Color(0.05, 0.07, 0.12, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The authored sprite visualizer replaces the old polygon arc and needle.
## These methods remain as no-op compatibility hooks for existing callers.
func _draw_metronome_indicator_base() -> void:
	return

func _draw_metronome_indicator_needle(_sword_angle: float) -> void:
	return

func _draw_chakram_aim_trail() -> void:
	var mobile_aiming: bool = mobile_input_enabled and mobile_chakram_held
	if not show_chakram_aim_trail or (not mobile_aiming and chakram_aim_trail_left <= 0.0): return
	var fade: float = 1.0 if mobile_aiming else clampf(chakram_aim_trail_left / maxf(chakram_aim_trail_duration, 0.001), 0.0, 1.0)
	var start: Vector2 = chakram_aim_trail_start - global_position
	var end: Vector2 = chakram_aim_trail_end - global_position
	var guide_color: Color = Color(1.0, 0.78, 0.22, fade * 0.95)
	var guide_shadow: Color = Color(0.08, 0.04, 0.01, fade * 0.8)
	draw_line(start, end, guide_shadow, 7.0 if mobile_aiming else 4.0, true)
	draw_line(start, end, Color(guide_color.r, guide_color.g, guide_color.b, fade * 0.62), 2.0, true)
	var dot_count: int = maxi(1, chakram_aim_trail_dot_count)
	for dot_index: int in range(dot_count):
		var ratio: float = float(dot_index + 1) / float(dot_count + 1)
		var dot_position: Vector2 = start.lerp(end, ratio)
		var dot_alpha: float = fade * (1.0 - ratio * 0.25)
		draw_circle(dot_position, chakram_aim_trail_dot_radius + (1.0 if mobile_aiming else 0.0), Color(1.0, 0.78, 0.22, dot_alpha))
	var endpoint_radius: float = chakram_aim_trail_dot_radius + 4.0 if mobile_aiming else chakram_aim_trail_dot_radius + 1.0
	draw_circle(end, endpoint_radius + 3.0, Color(0.08, 0.04, 0.01, fade * 0.8))
	draw_circle(end, endpoint_radius, Color(1.0, 0.92, 0.5, fade * 0.95))
	if mobile_aiming:
		var arrow_side: Vector2 = end.direction_to(start).orthogonal() * 7.0
		var arrow_back: Vector2 = end.direction_to(start) * 14.0
		draw_colored_polygon(PackedVector2Array([end, end + arrow_back + arrow_side, end + arrow_back - arrow_side]), Color(1.0, 0.83, 0.26, fade))

func _draw_dash_aim_preview() -> void:
	if not mobile_input_enabled or not mobile_dash_held:
		return
	var preview_direction: Vector2 = _current_aim_direction()
	var dash_distance: float = dash_speed * dash_duration
	if flash_step_enabled:
		dash_distance *= BonusConfig.flash_step_distance_multiplier(flash_step_rank)
	var dash_end: Vector2 = preview_direction * dash_distance
	var dash_color: Color = Color(0.38, 0.84, 1.0, 0.9) if dash_charges > 0 and not _terrain_dash_blocked() else Color(1.0, 0.28, 0.22, 0.9)
	draw_line(Vector2.ZERO, dash_end, Color(0.02, 0.04, 0.08, 0.82), 10.0, true)
	var segment_count: int = 7
	for segment_index: int in range(segment_count):
		var segment_start_ratio: float = float(segment_index) / float(segment_count)
		var segment_end_ratio: float = segment_start_ratio + 0.62 / float(segment_count)
		draw_line(dash_end * segment_start_ratio, dash_end * minf(segment_end_ratio, 1.0), dash_color, 4.0, true)
	draw_circle(dash_end, 14.0, Color(0.02, 0.04, 0.08, 0.82))
	draw_circle(dash_end, 9.0, dash_color)
	draw_arc(dash_end, 18.0, 0.0, TAU, 24, Color(dash_color.r, dash_color.g, dash_color.b, 0.72), 2.0, true)

func _draw_hd_slide_sparks(traveling_center: Vector2, blade_direction: Vector2, blade_normal: Vector2, slide_alpha: float, slide_progress: float, spark_count: int) -> void:
	var gold: Color = Color(1.0, 0.72, 0.16, 1.0)
	var orange: Color = Color(1.0, 0.30, 0.04, 1.0)
	# Compact grinding contact: bright, local, and readable instead of a large
	# rotating orb that can be mistaken for another gameplay object.
	draw_circle(traveling_center, 14.0 * slide_alpha, Color(1.0, 0.42, 0.05, slide_alpha * 0.12))
	draw_circle(traveling_center, 7.0 * slide_alpha, Color(1.0, 0.70, 0.18, slide_alpha * 0.34))
	draw_circle(traveling_center, 3.2 * slide_alpha, Color(1.0, 0.98, 0.82, slide_alpha))
	draw_line(traveling_center - blade_direction * 8.0, traveling_center + blade_direction * 8.0, Color(1.0, 0.86, 0.35, slide_alpha * 0.75), 2.0, true)
	# The visible sparks are regenerated from the moving slide phase. Their
	# origins stay beside the live blade rather than being tied to sword cling.
	var active_count: int = maxi(spark_count + 4, 8)
	for spark_index: int in range(active_count):
		var seed_value: float = float(spark_index) * 19.17
		var phase: float = fmod(slide_progress * 1.7 + fmod(seed_value, 1.0), 1.0)
		var side: float = -1.0 if spark_index % 2 == 0 else 1.0
		var along: float = lerpf(-18.0, 22.0, phase)
		var origin: Vector2 = traveling_center + blade_direction * along + blade_normal * side * (1.5 + fmod(seed_value, 3.0))
		var spray: Vector2 = (-blade_direction * (0.55 + fmod(seed_value, 0.25)) + blade_normal * side * (0.7 + fmod(seed_value, 0.35))).normalized()
		var length: float = (7.0 + fmod(seed_value, 8.0)) * slide_alpha
		var end_point: Vector2 = origin + spray * length
		var spark_color: Color = gold if spark_index % 3 != 0 else orange
		draw_line(origin, end_point, Color(spark_color.r, spark_color.g, spark_color.b, slide_alpha * 0.75), 2.0, true)
		draw_line(origin, origin + spray * length * 0.45, Color(1.0, 0.98, 0.82, slide_alpha * 0.9), 1.0, true)
		draw_circle(end_point, 1.2 * slide_alpha, Color(1.0, 0.78, 0.28, slide_alpha * 0.8))

func _draw_contact_spark_burst(center: Vector2, alpha: float) -> void:
	var is_parry: bool = contact_spark_color.b > contact_spark_color.r
	var cool_blue: Color = Color(0.35, 0.82, 1.0, alpha) if is_parry else Color(1.0, 0.68, 0.12, alpha)
	var edge_color: Color = Color(0.72, 0.95, 1.0, alpha * 0.9) if is_parry else Color(1.0, 0.28, 0.04, alpha * 0.85)
	var pulse: float = 0.85 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.035)
	draw_circle(center, 15.0 * pulse, Color(cool_blue.r, cool_blue.g, cool_blue.b, alpha * 0.14))
	draw_circle(center, 6.0 * pulse, Color(1.0, 0.92, 0.62, alpha * 0.45))
	draw_circle(center, 2.5 * pulse, Color.WHITE)
	var tangent: Vector2 = contact_spark_direction.orthogonal()
	for spark_index: int in range(maxi(contact_spark_count, 1)):
		var seed_value: float = float(spark_index) * 13.71
		var side: float = -1.0 if spark_index % 2 == 0 else 1.0
		var direction: Vector2 = (contact_spark_direction * (0.35 + fmod(seed_value, 0.3)) + tangent * side * (0.7 + fmod(seed_value, 0.35))).normalized()
		var origin: Vector2 = center + tangent * side * (1.0 + fmod(seed_value, 4.0))
		var length: float = 9.0 + fmod(seed_value, 8.0)
		draw_line(origin, origin + direction * length, edge_color, 2.2, true)
		draw_line(origin, origin + direction * length * 0.48, Color.WHITE, 1.1, true)

func _draw() -> void:
	var authored_metronome_sheathed: bool = _authored_metronome_mode_applies() and authored_metronome_state == AuthoredMetronomeState.SHEATHED
	if not authored_metronome_sheathed:
		_draw_metronome_indicator_base()
	_draw_chakram_aim_trail()
	_draw_dash_aim_preview()
	# The body is drawn here, ahead of the guard visuals, the sword, its fire and its
	# trails, so the weapon and everything attached to it always read on top of the player
	# instead of being cut off by their own torso. The aim previews stay underneath, where
	# they read as ground guides for where the sword is about to go.
	#
	# Body: classic draws its own procedural vector knight; HD mode uses the
	# layered head/torso/boots profile. The HD shadow is drawn underneath those layers.
	if visual_style == "hd":
		draw_set_transform(Vector2(0.0, 25.0), 0.0, Vector2(1.25, 0.38))
		draw_circle(Vector2.ZERO, 20.0, Color(0.03, 0.05, 0.08, 0.34))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_pixel_knight()
	# The guard visual starts the moment the guard itself does. Nothing is drawn while the drive is
	# still banking: the bank is deliberately invisible, and a readout appearing before the guard
	# did is exactly what made the state look like it was arriving on its own.
	if _charged_guard_engaged() and get_combat_contact_setting("charged_guard_enabled") >= 0.5:
		var guard_transform: Dictionary = _sword_transform()
		var hand_local: Vector2 = (guard_transform["start"] as Vector2) - global_position
		var charge_ratio: float = clampf(charged_guard_charge / maxf(0.01, get_combat_contact_setting("charged_guard_hold_duration")), 0.0, 1.0)
		var position_stage_enabled: bool = get_combat_contact_setting("charged_guard_position_charge_enabled") >= 0.5
		var awaken_duration: float = maxf(0.05, get_combat_contact_setting("charged_guard_awaken_duration"))
		var awaken_ratio: float = clampf(charged_guard_awaken_charge / awaken_duration, 0.0, 1.0) if position_stage_enabled else 0.0
		var show_fully_charged: bool = position_stage_enabled and charged_guard_fully_charged
		var flash_duration: float = 0.55 if show_fully_charged else 0.18
		var flash_ratio: float = clampf(charged_guard_flash_left / flash_duration, 0.0, 1.0)
		var pulse: float = 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.025)
		if show_fully_charged:
			# Each afterimage is a faded copy of the hand glow just below, tinted by
			# the shared blue<->white shimmer so the trail breathes with the state.
			var shimmer: Color = FlowColorUtils.charged_oscillating_color(float(Time.get_ticks_msec()) * 0.001)
			for image_index: int in range(charged_guard_afterimages.size()):
				var image_alpha: float = 0.34 * (1.0 - float(image_index) / float(CHARGED_GUARD_AFTERIMAGE_COUNT - 1))
				var ghost_bloom: Color = shimmer
				ghost_bloom.a = image_alpha * 0.5
				var ghost_core: Color = shimmer.lerp(FlowColorUtils.CHARGE_WHITE_TONE, 0.55)
				ghost_core.a = image_alpha
				draw_circle(charged_guard_afterimages[image_index], 11.0, ghost_bloom)
				draw_circle(charged_guard_afterimages[image_index], 4.5, ghost_core)
			# The hand glow breathes on the same shimmer as the ghosts above it, so the
			# charged state reads as one effect instead of a fixed dot sitting over a
			# shimmering trail. At the blue end these three layers are the original
			# guard glow; at the white end the bloom and mid tones lift together.
			var charged_glow: Color = shimmer
			charged_glow.a = 0.30 * pulse
			draw_circle(hand_local, 13.0 * pulse, charged_glow)
			var charged_mid: Color = shimmer.lerp(FlowColorUtils.CHARGE_WHITE_TONE, 0.35)
			charged_mid.a = 0.72 * pulse
			draw_circle(hand_local, 7.0, charged_mid)
			var charged_core: Color = FlowColorUtils.CHARGE_WHITE_TONE
			charged_core.a = 0.95
			draw_circle(hand_local, 3.0, charged_core)
		else:
			var glow_color: Color = Color(1.0, 0.78, 0.25, (0.18 + charge_ratio * 0.35) * pulse)
			if flash_ratio > 0.0:
				glow_color = Color(1.0, 0.96, 0.68, flash_ratio)
			draw_circle(hand_local, 5.0 + charge_ratio * 5.0, glow_color)
			if charged_guard_locked and position_stage_enabled:
				# The confirmation hold is drawn in the same amber as the charge it is finishing,
				# not blue. Blue is the charged state itself, so nothing blue may appear until that
				# state is actually up -- otherwise the ring reads as the state arriving early.
				var closing_radius: float = lerpf(20.0, 5.0, awaken_ratio)
				var ring_alpha: float = 0.45 + 0.50 * awaken_ratio
				draw_circle(hand_local, closing_radius, Color(1.0, 0.80, 0.32, ring_alpha), false, 2.0, true)
				draw_arc(hand_local, closing_radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * awaken_ratio, 32, Color(1.0, 0.90, 0.55, 0.95), 1.5, true)
			else:
				# The charge as the amber arc that fills around the hand while the guard builds.
				# It is the guard's own readout: it starts when the guard does, and it is never blue.
				draw_arc(hand_local, 10.0, -PI * 0.5, -PI * 0.5 + TAU * charge_ratio, 28, Color(1.0, 0.88, 0.38, 0.95), 2.0, true)
		if show_fully_charged and flash_ratio > 0.0:
			var shimmer_radius: float = lerpf(9.0, 25.0, 1.0 - flash_ratio)
			for shimmer_index: int in range(8):
				var shimmer_direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(shimmer_index) / 8.0)
				draw_line(hand_local + shimmer_direction * shimmer_radius, hand_local + shimmer_direction * (shimmer_radius + 5.0), Color(0.72, 0.93, 1.0, flash_ratio), 1.8, true)
	var flow_ratio: float = clampf(flow / 100.0, 0.0, 1.0)
	if flow_ratio > 0.0 and flow_trail_points.size() > 1:
		var trail_alpha: float = flow_ratio * flow_trail_max_alpha
		for trail_index: int in range(flow_trail_points.size() - 1):
			var trail_start: Vector2 = flow_trail_points[trail_index] - global_position
			var trail_end: Vector2 = flow_trail_points[trail_index + 1] - global_position
			var fade: float = 1.0 - float(trail_index) / float(flow_trail_points.size())
			draw_line(trail_start, trail_end, Color(1.0, 0.72, 0.08, trail_alpha * fade), 3.0 + flow_ratio * 3.0, true)
			if flow >= flow_sparkle_threshold and trail_index % 2 == 0:
				var sparkle_position: Vector2 = trail_start + Vector2(sin(float(trail_index) * 4.0 + Time.get_ticks_msec() * 0.006), cos(float(trail_index) * 3.0 + Time.get_ticks_msec() * 0.005)) * 4.0
				draw_circle(sparkle_position, 2.0 + flow_ratio * 1.5, Color(1.0, 0.92, 0.35, trail_alpha * fade))
	# Bind lifecycle diagnostics are console-only; ordinary contact labels can
	# still provide lightweight spatial feedback during development.
	if debug_show_sword_events and sword_event_left > 0.0 and sword_event_label not in BIND_LIFECYCLE_EVENT_TYPES:
		var event_alpha: float = clampf(sword_event_left / 0.45, 0.0, 1.0)
		var event_position: Vector2 = sword_event_point - global_position + Vector2(8.0, -18.0)
		draw_string(ThemeDB.fallback_font, event_position, sword_event_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color(0.8, 0.95, 1.0, event_alpha))
	if combat_contact_preset >= 2 and preset_2_slide_visual_left > 0.0:
		var slide_alpha: float = clampf(preset_2_slide_visual_left / maxf(get_combat_contact_setting("slide_duration"), 0.001), 0.0, 1.0)
		var slide_progress: float = 1.0 - slide_alpha
		var transform_data: Dictionary = _sword_transform()
		var blade_anchor_world: Vector2 = transform_data["start"] as Vector2
		var blade_direction: Vector2 = Vector2.RIGHT.rotated(float(transform_data["angle"]))
		var blade_normal: Vector2 = blade_direction.orthogonal()
		# The player-side spark emitter follows its live weapon. When the enemy
		# is still valid, blend to its live contact too so both emitters share one
		# moving crossing point instead of drifting under sword cling.
		var player_slide_center: Vector2 = blade_anchor_world + blade_direction * (preset_2_slide_distance_on_blade + lerpf(-8.0, 24.0, slide_progress))
		var traveling_center_world: Vector2 = player_slide_center
		if is_instance_valid(preset_2_slide_opponent) and preset_2_slide_opponent.has_method("get_slide_contact_global"):
			var enemy_contact_world: Vector2 = preset_2_slide_opponent.get_slide_contact_global()
			traveling_center_world = player_slide_center.lerp(enemy_contact_world, 0.5)
		var traveling_center: Vector2 = traveling_center_world - global_position

		var spark_count: int = int(get_combat_hand_setting("slide_sparks"))
		if visual_style == "hd":
			_draw_hd_slide_sparks(traveling_center, blade_direction, blade_normal, slide_alpha, slide_progress, spark_count)
		else:
			# Classic fallback keeps the original readable hot line treatment.
			var flare_pulse: float = 0.85 + sin(Time.get_ticks_msec() * 0.04) * 0.15
			draw_circle(traveling_center, 12.0 * flare_pulse, Color(1.0, 0.72, 0.18, slide_alpha * 0.4))
			draw_circle(traveling_center, 5.0 * flare_pulse, Color(1.0, 0.98, 0.9, slide_alpha * 0.95))
			for spark_index: int in range(spark_count):
				var side: float = -1.0 if spark_index % 2 == 0 else 1.0
				var spark_offset: float = (float(spark_index) - float(spark_count) * 0.5) * 3.0
				var spark_origin: Vector2 = traveling_center + blade_direction * spark_offset
				var spray_dir: Vector2 = (-blade_direction * 0.65 + blade_normal * side * 0.75).normalized()
				var spark_len: float = 10.0 + float(spark_index % 3) * 4.0 + slide_progress * 6.0
				var hot_core_color: Color = Color(1.0, 0.96, 0.82, slide_alpha)
				var outer_ember_color: Color = Color(1.0, 0.42, 0.08, slide_alpha * 0.85)
				draw_line(spark_origin, spark_origin + spray_dir * spark_len, outer_ember_color, 2.2, true)
				draw_line(spark_origin, spark_origin + spray_dir * (spark_len * 0.55), hot_core_color, 1.2, true)
	if (experimental_bind_candidate or experimental_bind_active) and is_experimental_bind_form():
		var bind_local: Vector2 = experimental_bind_contact_point - global_position
		var bind_pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.018)
		var bind_color: Color = Color(1.0, 0.82, 0.26, 0.92) if experimental_bind_active else Color(0.35, 0.84, 1.0, 0.72)
		var bind_radius: float = 7.0 + bind_pulse * (3.0 if experimental_bind_active else 1.5)
		draw_arc(bind_local, bind_radius, 0.0, TAU, 20, bind_color, 2.0, true)
		if is_instance_valid(experimental_bind_opponent):
			var bind_tangent: Vector2 = experimental_bind_opponent.get_blade_direction().normalized()
			draw_line(bind_local - bind_tangent * 15.0, bind_local + bind_tangent * 15.0, bind_color, 1.5, true)
	if contact_spark_left > 0.0 and contact_spark_count > 0:
		var burst_alpha: float = clampf(contact_spark_left / 0.22, 0.0, 1.0)
		_draw_contact_spark_burst(contact_spark_point - global_position, burst_alpha)
	# Bind lifecycle evidence is console-only; keep gameplay free of diagnostic
	# counters. The generic slide count remains available for contact testing.
	if debug_show_slide_counter:
		draw_string(ThemeDB.fallback_font, Vector2(-46.0, -52.0), "Slides: %d" % sword_slide_count, HORIZONTAL_ALIGNMENT_CENTER, 92.0, 14, Color(1.0, 0.72, 0.18, 0.95))
	if chain_lightning_flash > 0.0:
		var flying_chakrams: Array[Chakram] = []
		for active_chakram: Chakram in active_chakrams:
			if is_instance_valid(active_chakram) and not active_chakram.grounded:
				flying_chakrams.append(active_chakram)
		if flying_chakrams.size() >= 2:
			var lightning_alpha: float = chain_lightning_flash / 0.22
			for index: int in range(flying_chakrams.size() - 1):
				var first: Chakram = flying_chakrams[index]
				var second: Chakram = flying_chakrams[index + 1]
				var first_local: Vector2 = first.global_position - global_position
				var second_local: Vector2 = second.global_position - global_position
				draw_line(first_local, second_local, Color(0.4, 0.8, 1.0, lightning_alpha * 0.45), 8.0, true)
				draw_line(first_local, second_local, Color(0.75, 0.95, 1.0, lightning_alpha), 3.0, true)
	if debug_draw_sword_collision:
		# Developer zone audit: show only the live collision polyline, with no
		# obsolete straight capsule or swept-volume approximation. Yellow is the
		# pommel zone, green is grip-to-guard, and blue is blade base to tip.
		var zone_length_total: float = 0.0
		for index: int in range(current_blade_samples.size() - 1):
			zone_length_total += current_blade_samples[index].distance_to(current_blade_samples[index + 1])
		var zone_length_travelled: float = 0.0
		for index: int in range(current_blade_samples.size() - 1):
			var segment_start: Vector2 = current_blade_samples[index] - global_position
			var segment_end: Vector2 = current_blade_samples[index + 1] - global_position
			var segment_length: float = segment_start.distance_to(segment_end)
			var subsegment_count: int = 12
			for sub_index: int in range(subsegment_count):
				var local_start_ratio: float = float(sub_index) / float(subsegment_count)
				var local_end_ratio: float = float(sub_index + 1) / float(subsegment_count)
				var poly_start: Vector2 = segment_start.lerp(segment_end, local_start_ratio)
				var poly_end: Vector2 = segment_start.lerp(segment_end, local_end_ratio)
				var zone_fraction: float = (zone_length_travelled + segment_length * (local_start_ratio + local_end_ratio) * 0.5) / maxf(zone_length_total, 0.001)
				var zone_color: Color = Color(0.18, 0.55, 1.0, 0.98)
				if zone_fraction < debug_weapon_pommel_fraction:
					zone_color = Color(1.0, 0.85, 0.08, 0.98)
				elif zone_fraction < debug_weapon_grip_guard_end_fraction:
					zone_color = Color(0.20, 0.95, 0.35, 0.98)
				elif zone_fraction < forte_zone_end_fraction:
					zone_color = Color(0.95, 0.18, 0.85, 0.98)
				draw_line(poly_start, poly_end, zone_color, 5.0, true)
				if sub_index == subsegment_count - 1:
					draw_circle(poly_end, 4.0, zone_color)
			zone_length_travelled += segment_length
	if flash_step_flash > 0.0:
		var flash_alpha: float = clampf(flash_step_flash / flash_step_visual_duration, 0.0, 1.0)
		var origin_local: Vector2 = flash_step_origin - global_position
		var destination_local: Vector2 = flash_step_destination - global_position
		var sketch_color: Color = Color(0.55, 0.9, 1.0, flash_alpha * 0.8)
		# Ghost outline at the departure point.
		draw_arc(origin_local, 17.0, 0.0, TAU, 20, sketch_color, 3.0, true)
		draw_line(origin_local + Vector2(-10.0, -4.0), origin_local + Vector2(10.0, -4.0), sketch_color, 2.0, true)
		draw_line(origin_local + Vector2(-9.0, 7.0), origin_local + Vector2(9.0, 7.0), sketch_color, 2.0, true)
		# Hand-drawn speed marks connecting departure and arrival.
		for line_index: int in range(flash_step_sketch_line_count):
			var line_ratio: float = (float(line_index) + 1.0) / float(flash_step_sketch_line_count + 1)
			var line_center: Vector2 = origin_local.lerp(destination_local, line_ratio)
			var line_side: Vector2 = dash_direction.orthogonal() * (float(line_index % 3) - 1.0) * 10.0
			var line_start: Vector2 = line_center + line_side - dash_direction * (flash_step_sketch_line_length * 0.5)
			var line_end: Vector2 = line_center + line_side + dash_direction * (flash_step_sketch_line_length * 0.5)
			draw_line(line_start, line_end, Color(0.8, 0.95, 1.0, flash_alpha * 0.65), 2.0, true)
		# Arrival phase-in ring and crosshair.
		draw_arc(destination_local, 23.0 + (1.0 - flash_alpha) * 15.0, 0.0, TAU, 24, Color(0.7, 0.95, 1.0, flash_alpha * 0.85), 3.0, true)
		draw_line(destination_local - dash_direction * 22.0, destination_local + dash_direction * 22.0, Color(0.8, 1.0, 1.0, flash_alpha * 0.55), 2.0, true)
	if frost_nova_flash > 0.0:
		var progress: float = 1.0 - frost_nova_flash / 0.5
		var nova_radius: float = lerpf(18.0, BonusConfig.frost_nova_radius(frost_nova_rank), progress)
		var nova_alpha: float = clampf(frost_nova_flash / 0.5, 0.0, 1.0)
		draw_circle(Vector2.ZERO, nova_radius, Color(0.2, 0.75, 1.0, nova_alpha * 0.16))
		draw_arc(Vector2.ZERO, nova_radius, 0.0, TAU, 64, Color(0.35, 0.85, 1.0, nova_alpha * 0.9), 5.0, true)
		draw_arc(Vector2.ZERO, maxf(8.0, nova_radius - 10.0), 0.0, TAU, 64, Color(0.7, 0.95, 1.0, nova_alpha * 0.35), 2.0, true)
	# Both sword trails breathe with arc energy while the metronome is in play, and draw at
	# their historical brightness in every other style. One multiplier, one authority.
	var trail_visibility: float = _sword_trail_visibility_scale()
	var hilt_points_count: int = hilt_trail_points.size()
	for index: int in range(hilt_points_count - 1):
		var h_start: Vector2 = hilt_trail_points[index] - global_position
		var h_end: Vector2 = hilt_trail_points[index + 1] - global_position
		var h_alpha: float = 0.55 * (1.0 - float(index) / float(hilt_points_count)) * trail_visibility
		draw_line(h_start, h_end, Color(1.0, 0.65, 0.1, h_alpha), 3.0, true)
	var trail_points_count: int = blade_trail_points.size()
	for index: int in range(trail_points_count - 1):
		var trail_start: Vector2 = blade_trail_points[index] - global_position
		var trail_end: Vector2 = blade_trail_points[index + 1] - global_position
		var trail_alpha: float = 0.45 * (1.0 - float(index) / float(trail_points_count)) * trail_visibility
		var trail_thickness: float = maxf(2.0, 5.5 - float(index) * (4.0 / float(trail_points_count)))
		draw_line(trail_start, trail_end, Color(1.0, 0.16, 0.08, trail_alpha), trail_thickness, true)
	var data: Dictionary = _sword_transform()
	var start: Vector2 = (data["start"] as Vector2) - global_position
	var sword_angle: float = float(data["angle"])
	# HD uses the same proven Classic sword artwork and dimensions. The player
	# body can change visual profile without changing the weapon's readable scale.
	var texture_center: Vector2 = start + Vector2.RIGHT.rotated(sword_angle) * (BLADE_LENGTH * 0.34)
	# blade_roll (see its declaration) both mirrors and width-scales the
	# rendered blade in lockstep with the hit polyline -- a negative local-X
	# scale is a horizontal mirror, and its magnitude shrinking toward 0
	# right as it crosses zero is what sells the "rolling edge-on" look
	# instead of an instant pop.
	draw_set_transform(texture_center, sword_angle - PI * 0.5, Vector2(0.055 * blade_roll, 0.055))
	# Negative rect height flips the V axis -- the one-line fix for a sword
	# whose source art has hilt/tip reversed, no PNG editing required.
	var sword_flipped: bool = bool(SWORD_TEXTURE_FLIP_Y.get(equipped_sword_id, false))
	var sword_rect: Rect2 = Rect2(-512.0, 768.0, 1024.0, -1536.0) if sword_flipped else Rect2(-512.0, -768.0, 1024.0, 1536.0)
	if authored_metronome_sheathe_alpha > 0.01:
		draw_texture_rect(equipped_sword_texture(), sword_rect, false, Color(1.0, 1.0, 1.0, authored_metronome_sheathe_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if sword_fire_left > 0.0 and not authored_metronome_sheathed:
		var fire_fade: float = clampf(sword_fire_left / maxf(sword_fire_duration, 0.001), 0.0, 1.0)
		var flame_blade_samples: PackedVector2Array = current_blade_samples
		if flame_blade_samples.size() < 2:
			var blade_direction: Vector2 = Vector2.RIGHT.rotated(sword_angle)
			var blade_hilt: Vector2 = global_position + start - blade_direction * BLADE_HILT_INSET
			flame_blade_samples = _blade_polyline_samples(blade_hilt, blade_direction)
		_draw_hd_sword_fire(flame_blade_samples, fire_fade)
	# The gesture trail: what the player is drawing, drawn. Recognition is measured on the
	# cursor's own screen positions, so the trail comes from those same points, projected
	# back through the live camera. The stroke therefore stays exactly where the cursor
	# went -- camera lead, lag and arena clamp included -- and it lingers through the hit
	# flash so the picture of the gesture is still on screen as the thrust begins.
	if get_combat_contact_setting("charged_guard_gestures_enabled") >= 0.5 and (charged_guard_gesture_trail_left > 0.0 or not charged_guard_gesture_sparks.is_empty()):
		var trail_fade: float = clampf(charged_guard_gesture_trail_left / maxf(0.001, CHARGED_GUARD_GESTURE_TRAIL_FADE), 0.0, 1.0)
		var trail_flash: float = clampf(charged_guard_gesture_flash_left / maxf(0.001, CHARGED_GUARD_GESTURE_FLASH_TIME), 0.0, 1.0)
		var trail_shimmer: Color = FlowColorUtils.charged_oscillating_color(float(Time.get_ticks_msec()) * 0.001)
		# Biased toward the saturated blue end of the shimmer, so the stroke reads as a solid
		# blue ribbon instead of washing out, while still breathing with the hand glow.
		var trail_blue: Color = trail_shimmer.lerp(FlowColorUtils.CHARGE_BLUE_TONE, 0.35)
		var trail_lit: Color = trail_blue.lerp(FlowColorUtils.CHARGE_WHITE_TONE, trail_flash * 0.75)
		var screen_to_local: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
		var trail_count: int = charged_guard_gesture_path.size()
		if charged_guard_gesture_trail_left > 0.0 and trail_count > 1:
			for trail_index: int in range(trail_count - 1):
				# Brightest at the cursor and fading back down the stroke, so it is the head
				# of the drawn line that reads rather than its dusty beginning.
				var segment_fade: float = float(trail_index + 1) / float(trail_count)
				var trail_start: Vector2 = (screen_to_local * charged_guard_gesture_path[trail_index]) - global_position
				var trail_end: Vector2 = (screen_to_local * charged_guard_gesture_path[trail_index + 1]) - global_position
				var trail_color: Color = trail_lit
				trail_color.a = (0.55 + trail_flash * 0.4) * trail_fade * segment_fade
				draw_line(trail_start, trail_end, trail_color, CHARGED_GUARD_GESTURE_TRAIL_WIDTH + trail_flash * 3.0, true)
		if charged_guard_gesture_trail_left > 0.0 and trail_count > 0:
			# A soft glow on the drawing point itself, so the stroke has a visible head
			# instead of stopping dead where the cursor is.
			var head_position: Vector2 = (screen_to_local * charged_guard_gesture_path[trail_count - 1]) - global_position
			var head_halo: Color = trail_lit
			head_halo.a = (0.28 + trail_flash * 0.45) * trail_fade
			draw_circle(head_position, 7.0 + trail_flash * 3.0, head_halo)
			var head_core: Color = trail_lit
			head_core.a = minf(1.0, (0.55 + trail_flash * 0.45) * trail_fade)
			draw_circle(head_position, 3.0, head_core)
		for spark: Vector3 in charged_guard_gesture_sparks:
			var spark_position: Vector2 = (screen_to_local * Vector2(spark.x, spark.y)) - global_position
			var spark_life: float = clampf(spark.z / CHARGED_GUARD_GESTURE_SPARK_LIFE, 0.0, 1.0)
			# Sparks cool toward white as they die, so they read as flecks thrown off the
			# shimmer rather than as separate particles.
			var spark_color: Color = trail_blue.lerp(FlowColorUtils.CHARGE_WHITE_TONE, 0.25 + 0.6 * (1.0 - spark_life))
			spark_color.a = spark_life * 0.95
			draw_circle(spark_position, 1.4 + 1.6 * spark_life, spark_color)
	# Draw last so the gold needle remains visible over the sword and crowded combat.
	if not authored_metronome_sheathed:
		_draw_metronome_indicator_needle(sword_angle)
