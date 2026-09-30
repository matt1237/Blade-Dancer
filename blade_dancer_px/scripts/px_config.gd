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
const ARENA: Rect2 = Rect2(-1280.0, -720.0, 2560.0, 1440.0)
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
## Live-tunable: PXTuningTools owns these while playing. The active game preset
## (2, Metronome V) runs min 5 / max 30; DEFAULT_HAND_MAX stays at the 40 this
## prototype was approved on.
const DEFAULT_HAND_MIN: float = 5.0
const DEFAULT_HAND_MAX: float = 40.0

# ── The sword motor ─────────────────────────────────────────────────────────
const BLADE_LENGTH: float = 84.0
const BLADE_THICKNESS: float = 12.0
## Blade inertia (RectangleShape2D 84x12, mass 1) is ~600, so a critically
## damped PD motor wants damping ~= 2*sqrt(stiffness * inertia) ~= 15000.
const DEFAULT_MOTOR_STIFFNESS: float = 90000.0
const DEFAULT_MOTOR_DAMPING: float = 15000.0
const DEFAULT_MAX_TORQUE: float = 180000.0

# ── Enemies ─────────────────────────────────────────────────────────────────
const ENEMY_RADIUS: float = 18.0
const ENEMY_MAX_HEALTH: float = 420.0
const ENEMY_SPEED: float = 74.0
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

# ── Test Dummy ────────────────────────────────────────────────────────────────
const TEST_DUMMY_MAX_HEALTH: float = 100.0
const TEST_DUMMY_MIN_HEALTH: float = 1.0
const TEST_DUMMY_REGEN_AMOUNT: float = 10.0
const TEST_DUMMY_REGEN_INTERVAL: float = 1.0
const TEST_DUMMY_NAME: String = "TEST DUMMY"
const TEST_DUMMY_COLOR: Color = Color(0.38, 0.78, 0.55)
const TEST_DUMMY_HEALTH_COLOR: Color = Color(0.35, 0.95, 0.55)
const TEST_DUMMY_SPAWN_POSITION: Vector2 = Vector2(0.0, -170.0)

# ── Metronome (Blade Dancer's Form III arc, copied AS DATA) ─────────────────
## Blade Dancer's metronome for the ACTIVE preset (2, Form III "Metronome V"):
## arc 90, frequency 0.6 Hz. Read off the live settings ONCE and copied here —
## PX must never read the game's save, only borrow its numbers.
##
## ARC IS A SINE AMPLITUDE, not a total sweep: the blade swings +/- this many
## degrees about the aim, so 90 is a 180-degree sweep end to end. Same
## convention as the game (player.gd:3349).
const METRONOME_ARC_DEGREES: float = 90.0
const METRONOME_FREQUENCY: float = 0.6