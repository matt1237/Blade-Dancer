class_name WorldTime extends RefCounted
## Single canonical world time-scale authority for World Slow (button or legacy circle).
## The PLAYER owns activation and the real-time countdown (Player._tick_world_slow);
## every enemy, enemy projectile, and the WaveSpawner multiplies its own delta by
## enemy_scale() exactly once at the top of its tick. Player-owned things never read it.
## Not saved and not rewound: the countdown is frozen while the tree is paused
## (world-rewind playback), because the player's tick does not run then.

const WORLD_SLOW_DURATION: float = 5.0
const WORLD_SLOW_SCALE: float = 0.5

static var slow_left: float = 0.0

static func enemy_scale() -> float:
	return WORLD_SLOW_SCALE if slow_left > 0.0 else 1.0

static func slow_active() -> bool:
	return slow_left > 0.0

static func begin_slow() -> void:
	slow_left = WORLD_SLOW_DURATION

## Advance by REAL (player) seconds. Returns true on the frame the slow ends.
static func tick(real_delta: float) -> bool:
	if slow_left <= 0.0:
		return false
	slow_left = maxf(0.0, slow_left - maxf(0.0, real_delta))
	return slow_left <= 0.0

static func reset() -> void:
	slow_left = 0.0
