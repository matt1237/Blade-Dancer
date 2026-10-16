class_name WorldRewindRecorder extends RefCounted
## Stage 1 full-world rewind: preallocated per-entity rings of fixed-stride float state,
## recorded on the SAME clock and ring slots as PlayerRewindBuffer (the Player passes its own
## head slot each push), so one slot index addresses both buffers at the same instant.
##
## Rewindable nodes join REWINDABLE_GROUP and implement:
##   rewind_stride() -> int
##   rewind_capture(data: PackedFloat32Array, offset: int)   # writes stride floats, offset 0/1 = global_position
##   rewind_restore(data: PackedFloat32Array, offset: int)
##   rewind_retired: bool
## Recording overwrites preallocated slots only: a Track's arrays are sized once when the entity
## is first seen (one allocation per entity lifetime, never per frame).
const REWINDABLE_GROUP: StringName = &"rewindable"
const RETIRED_GROUP: StringName = &"rewind_retired"
const HOST_GROUP: StringName = &"world_rewind_host"
const RETIRE_META: StringName = &"rewind_retire_time"
const GROUPS_META: StringName = &"rewind_retired_groups"
## Retired entities are kept this long past the rewind window before the real free.
const RETIRE_MARGIN: float = 0.75
## Shared clock for retire timestamps (advances only while recording, i.e. never while paused).
static var clock: float = 0.0

## Instance ids are 64-bit; three 22/22/20-bit chunks are each exact in a float32.
## `node` is deliberately untyped: callers pass references (thrower, source enemy, heal target)
## whose object may already be freed, and a typed Object parameter rejects a freed instance
## before is_instance_valid can run. A freed/null reference is written as id 0.
static func write_id(d: PackedFloat32Array, o: int, node: Variant) -> void:
	var id: int = (node as Object).get_instance_id() if is_instance_valid(node) else 0
	d[o] = float(id & 0x3FFFFF); d[o + 1] = float((id >> 22) & 0x3FFFFF); d[o + 2] = float((id >> 44) & 0xFFFFF)

static func read_id(d: PackedFloat32Array, o: int) -> Object:
	var id: int = int(d[o]) | (int(d[o + 1]) << 22) | (int(d[o + 2]) << 44)
	if id == 0:
		return null
	var node: Object = instance_from_id(id)
	return node if is_instance_valid(node) else null

class Track extends RefCounted:
	var node_id: int = 0
	var stride: int = 0
	var data: PackedFloat32Array = PackedFloat32Array()
	var stamps: PackedInt32Array = PackedInt32Array()
	var alive: PackedByteArray = PackedByteArray()
	func _init(id: int, entity_stride: int, capacity: int) -> void:
		node_id = id
		stride = entity_stride
		data.resize(capacity * entity_stride)
		stamps.resize(capacity)
		stamps.fill(-1)
		alive.resize(capacity)

## Stage 2: long-lived world state (Main run counters, WaveSpawner clocks) joins this group with
## the same rewind_stride/capture/restore contract. Recorded on the same slots, restored at the
## target instant, but NEVER hidden, retired or freed (no rewind_retired needed).
const PERSISTENT_GROUP: StringName = &"rewind_persistent"

var capacity: int = 0
var serials: PackedInt32Array = PackedInt32Array()
var serial_counter: int = 0
var tracks: Dictionary[int, Track] = {}
var persistent_tracks: Dictionary[int, Track] = {}
## Wave-boundary barrier (record clock). World rewind never targets a sample at or before it.
var barrier_time: float = -INF
var retire_window: float = 4.0
var last_record_usec: int = 0

func _init(slot_count: int = 122, window_seconds: float = 4.0) -> void:
	capacity = maxi(2, slot_count)
	retire_window = window_seconds
	serials.resize(capacity)
	serials.fill(-1)

## Forget every recorded sample (tracks are kept, their stamps no longer match).
func invalidate() -> void:
	serials.fill(-1)

func clear() -> void:
	invalidate()
	tracks.clear()
	persistent_tracks.clear()

## Wave start/clear, boss start/clear, Zungar defeat, bonus screen: the world cannot be
## rewound to (or past) this record-clock instant.
## Stores the newest recorded sample's time (the Player buffer head); that sample and older are
## barred, since the head was captured before the boundary event fired.
func mark_barrier(buffer: PlayerRewindBuffer) -> void:
	if buffer != null and buffer.count > 0:
		barrier_time = maxf(barrier_time, buffer.times[buffer.head])

## Youngest-first clamp of `target_age` so the target sample is strictly after the barrier.
## Returns -1 when fewer than 2 samples remain after the barrier (world rewind refused).
func clamp_age_to_barrier(buffer: PlayerRewindBuffer, target_age: int) -> int:
	var age: int = target_age
	while age >= 0 and buffer.times[buffer.slot(age)] <= barrier_time:
		age -= 1
	return age if age >= 1 else -1

func _valid(track: Track, slot: int) -> bool:
	return slot >= 0 and serials[slot] >= 0 and track.stamps[slot] == serials[slot]

## True when the entity was recorded and alive at that slot.
func alive_at(node: Node, slot: int) -> bool:
	var track: Track = tracks.get(node.get_instance_id()) as Track
	return track != null and _valid(track, slot) and track.alive[slot] == 1

func has_sample(node: Node, slot: int) -> bool:
	var track: Track = tracks.get(node.get_instance_id()) as Track
	return track != null and _valid(track, slot)

## One sample of every rewindable entity into `slot` (the Player buffer's new head).
func record(tree: SceneTree, time: float, slot: int) -> void:
	if tree == null or slot < 0:
		return
	var started: int = Time.get_ticks_usec()
	clock = time
	serial_counter += 1
	serials[slot] = serial_counter
	for node: Node in tree.get_nodes_in_group(REWINDABLE_GROUP):
		if node.is_queued_for_deletion():
			continue
		var id: int = node.get_instance_id()
		var track: Track = tracks.get(id) as Track
		if track == null:
			track = Track.new(id, int(node.call("rewind_stride")), capacity)
			tracks[id] = track
		track.stamps[slot] = serial_counter
		if bool(node.get("rewind_retired")):
			track.alive[slot] = 0
			if time - float(node.get_meta(RETIRE_META, time)) > retire_window + RETIRE_MARGIN:
				tracks.erase(id)
				node.queue_free()
			continue
		track.alive[slot] = 1
		node.call("rewind_capture", track.data, slot * track.stride)
	for node: Node in tree.get_nodes_in_group(PERSISTENT_GROUP):
		var pid: int = node.get_instance_id()
		var ptrack: Track = persistent_tracks.get(pid) as Track
		if ptrack == null:
			ptrack = Track.new(pid, int(node.call("rewind_stride")), capacity)
			persistent_tracks[pid] = ptrack
		ptrack.stamps[slot] = serial_counter
		node.call("rewind_capture", ptrack.data, slot * ptrack.stride)
	if serial_counter % 30 == 0:
		_prune_freed_tracks()
	last_record_usec = Time.get_ticks_usec() - started

## Drops tracks whose node was freed by a non-retiring path (about once a second).
func _prune_freed_tracks() -> void:
	var stale: PackedInt64Array = PackedInt64Array()
	for id: int in tracks:
		if not is_instance_valid(instance_from_id(id)):
			stale.append(id)
	for id: int in stale:
		tracks.erase(id)
	stale.clear()
	for id: int in persistent_tracks:
		if not is_instance_valid(instance_from_id(id)):
			stale.append(id)
	for id: int in stale:
		persistent_tracks.erase(id)

## While not recording (toggle off), still free retired entities once their window lapses.
func sweep_retired(tree: SceneTree, time: float) -> void:
	if tree == null:
		return
	clock = time
	for node: Node in tree.get_nodes_in_group(RETIRED_GROUP):
		if not node.is_queued_for_deletion() and time - float(node.get_meta(RETIRE_META, time)) > retire_window + RETIRE_MARGIN:
			tracks.erase(node.get_instance_id())
			node.queue_free()

## Playback frame: positions interpolated between two slots; entities not alive at the
## displayed instant are hidden (the dead reappear, the not-yet-spawned vanish).
func apply_playback(lower_slot: int, upper_slot: int, weight: float) -> void:
	if lower_slot < 0 or serials[lower_slot] < 0:
		return
	for id: int in tracks:
		var track: Track = tracks[id]
		var node: Node2D = instance_from_id(id) as Node2D
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		# Static props (map-generated, never move) restore only at the end; skipping them here
		# keeps playback cheap and leaves their own visibility rules (e.g. phase hiding) alone.
		if node.has_meta(&"rewind_never_spawned_mid_window"):
			continue
		var shown: bool = _valid(track, lower_slot) and track.alive[lower_slot] == 1
		node.visible = shown
		if not shown:
			continue
		var base: int = lower_slot * track.stride
		var position: Vector2 = Vector2(track.data[base], track.data[base + 1])
		if _valid(track, upper_slot) and track.alive[upper_slot] == 1:
			var upper: int = upper_slot * track.stride
			position = position.lerp(Vector2(track.data[upper], track.data[upper + 1]), weight)
		node.global_position = position

## Final restore at `slot`: revive retired entities alive then, restore full state, free
## entities that did not exist yet. Returns [restored, revived, removed].
func restore(tree: SceneTree, slot: int) -> Vector3i:
	var restored: int = 0
	var revived: int = 0
	var removed: int = 0
	var stale: PackedInt64Array = PackedInt64Array()
	# The world was not being recorded at that instant (e.g. toggle just turned on): never
	# guess -- leave the world untouched rather than deleting everything as "not yet spawned".
	if slot < 0 or serials[slot] < 0:
		return Vector3i.ZERO
	# Persistent world state (run counters, spawner clocks): restore only, never free/hide.
	for id: int in persistent_tracks:
		var ptrack: Track = persistent_tracks[id]
		var host: Object = instance_from_id(id)
		if host != null and is_instance_valid(host) and _valid(ptrack, slot):
			host.call("rewind_restore", ptrack.data, slot * ptrack.stride)
	for id: int in tracks:
		var track: Track = tracks[id]
		var node: Node2D = instance_from_id(id) as Node2D
		if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
			stale.append(id)
			continue
		if not _valid(track, slot):
			# Spawned after the restore instant -- unless the node opts out (arena props are
			# generated with the map, never mid-window; a missing sample just means "unchanged").
			stale.append(id)
			if not bool(node.get_meta(&"rewind_never_spawned_mid_window", false)):
				node.queue_free()
				removed += 1
			continue
		if track.alive[slot] == 1:
			if bool(node.get("rewind_retired")):
				revive(node)
				revived += 1
			node.call("rewind_restore", track.data, slot * track.stride)
			if not node.has_meta(&"rewind_never_spawned_mid_window"):
				node.visible = true # props manage their own visibility in rewind_restore
			restored += 1
		else:
			node.visible = false
	for id: int in stale:
		tracks.erase(id)
	# Rewindable nodes created after the last sample have no track at all: also too new.
	if tree != null:
		for node: Node in tree.get_nodes_in_group(REWINDABLE_GROUP):
			if not tracks.has(node.get_instance_id()) and not node.is_queued_for_deletion() and not bool(node.get_meta(&"rewind_never_spawned_mid_window", false)):
				node.queue_free()
				removed += 1
	return Vector3i(restored, revived, removed)

## Whether death/free paths should retire instead of freeing (a world-rewind host is live).
static func retire_enabled(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var host: Node = node.get_tree().get_first_node_in_group(HOST_GROUP)
	if host == null:
		return false
	return not host.has_method("world_rewind_retire_enabled") or bool(host.call("world_rewind_retire_enabled"))

## Hide + disable (PROCESS_MODE_DISABLED also removes CollisionObject2D from physics via its
## disable_mode) and leave the gameplay groups, keeping the node for a possible revive.
static func retire(node: Node, gameplay_groups: Array[StringName]) -> void:
	var held: Array[StringName] = []
	for group_name: StringName in gameplay_groups:
		if node.is_in_group(group_name):
			held.append(group_name)
			node.remove_from_group(group_name)
	node.set_meta(GROUPS_META, held)
	node.set_meta(RETIRE_META, clock)
	node.set("rewind_retired", true)
	node.add_to_group(RETIRED_GROUP)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)

static func revive(node: Node) -> void:
	node.set("rewind_retired", false)
	node.remove_from_group(RETIRED_GROUP)
	for group_name: StringName in node.get_meta(GROUPS_META, [] as Array[StringName]):
		node.add_to_group(group_name)
	node.remove_meta(GROUPS_META)
	node.remove_meta(RETIRE_META)
	node.process_mode = Node.PROCESS_MODE_INHERIT
	# A retire in the same frame queued a deferred DISABLED; queue INHERIT after it (FIFO).
	node.set_deferred("process_mode", Node.PROCESS_MODE_INHERIT)
	if node is CanvasItem:
		(node as CanvasItem).visible = true

## Retire when a host is live, otherwise the original queue_free().
static func retire_or_free(node: Node, gameplay_groups: Array[StringName]) -> void:
	if bool(node.get("rewind_retired")):
		return
	if retire_enabled(node):
		retire(node, gameplay_groups)
	else:
		node.queue_free()
