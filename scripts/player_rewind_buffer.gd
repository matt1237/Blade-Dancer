class_name PlayerRewindBuffer extends RefCounted
## Fixed-size ring of player and ability cooldown history.
## Numeric arrays are preallocated. A small independent cooldown dictionary is copied
## at each recorded sample (~30 Hz). API index 0 is always the NEWEST sample.

var capacity: int = 0
var count: int = 0
var head: int = -1 # slot of the newest sample
var times: PackedFloat32Array = PackedFloat32Array()
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var healths: PackedFloat32Array = PackedFloat32Array()
var aim_angles: PackedFloat32Array = PackedFloat32Array()
var sword_phases: PackedFloat32Array = PackedFloat32Array()
var hand_radii: PackedFloat32Array = PackedFloat32Array()
var dash_timer_lefts: PackedFloat32Array = PackedFloat32Array()
var grapple_cooldowns: PackedFloat32Array = PackedFloat32Array()
var dash_charges: PackedInt32Array = PackedInt32Array()
var grapple_charges: PackedInt32Array = PackedInt32Array()
## Non-Rewind action abilities only; existing mouse-tool history remains unchanged.
var ability_cooldown_snapshots: Array[Dictionary] = []

func _init(slot_count: int = 91) -> void:
	capacity = maxi(2, slot_count)
	# Packed arrays are value types: resize each member directly (a loop would resize copies).
	times.resize(capacity)
	healths.resize(capacity)
	aim_angles.resize(capacity)
	sword_phases.resize(capacity)
	hand_radii.resize(capacity)
	dash_timer_lefts.resize(capacity)
	grapple_cooldowns.resize(capacity)
	positions.resize(capacity)
	velocities.resize(capacity)
	dash_charges.resize(capacity)
	grapple_charges.resize(capacity)
	ability_cooldown_snapshots.resize(capacity)

func clear() -> void:
	count = 0
	head = -1

func push(time: float, position: Vector2, velocity: Vector2, health: float, aim_angle: float, sword_phase: float, hand_radius: float, dash_charge_count: int, dash_timer_left: float, grapple_charge_count: int, grapple_cooldown: float) -> void:
	head = (head + 1) % capacity
	count = mini(count + 1, capacity)
	times[head] = time
	positions[head] = position
	velocities[head] = velocity
	healths[head] = health
	aim_angles[head] = aim_angle
	sword_phases[head] = sword_phase
	hand_radii[head] = hand_radius
	dash_charges[head] = dash_charge_count
	dash_timer_lefts[head] = dash_timer_left
	grapple_charges[head] = grapple_charge_count
	grapple_cooldowns[head] = grapple_cooldown
	ability_cooldown_snapshots[head] = {}

## Ring slot for the sample `age_index` steps older than the newest (0 = newest).
func slot(age_index: int) -> int:
	return posmod(head - clampi(age_index, 0, maxi(0, count - 1)), capacity)

## Oldest age index whose sample is no more than `seconds` older than the newest.
## A short buffer simply returns its oldest sample.
func oldest_index_within(seconds: float) -> int:
	if count <= 0:
		return -1
	var newest_time: float = times[head]
	var result: int = 0
	for age_index: int in range(count):
		if newest_time - times[slot(age_index)] > seconds + 0.0001:
			break
		result = age_index
	return result

## Interpolated position at fractional age `age` (0 = newest, count-1 = oldest).
func position_at(age: float) -> Vector2:
	var lower: int = floori(age)
	var upper: int = mini(lower + 1, count - 1)
	return positions[slot(lower)].lerp(positions[slot(upper)], age - float(lower))
