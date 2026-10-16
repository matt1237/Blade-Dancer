class_name AbilityCooldowns
extends RefCounted
## Runtime-only ability clocks. Rewind is deliberately outside snapshot history.
const TIME_ABILITY_COOLDOWN = 30.0
var remaining: Dictionary = {"rewind": 0.0, "slow": 0.0}

func left(ability: String) -> float:
	return maxf(0.0, float(remaining.get(ability, 0.0)))

func start(ability: String, duration: float = TIME_ABILITY_COOLDOWN) -> void:
	remaining[ability] = maxf(0.0, duration)

func tick(real_delta: float) -> void:
	for ability: String in remaining:
		remaining[ability] = maxf(0.0, left(ability) - maxf(0.0, real_delta))

func capture_rewindable() -> Dictionary:
	var snapshot: Dictionary = remaining.duplicate(true)
	snapshot.erase("rewind")
	return snapshot

func restore_rewindable(snapshot: Dictionary) -> void:
	# Registered abilities absent from an older sample had not been used yet.
	for ability: String in remaining.keys():
		if ability != "rewind":
			remaining[ability] = maxf(0.0, float(snapshot.get(ability, 0.0)))
	for ability: String in snapshot:
		if ability != "rewind":
			remaining[ability] = maxf(0.0, float(snapshot[ability]))
