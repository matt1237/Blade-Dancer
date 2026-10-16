class_name GoblinShaman extends Enemy

const ELIGIBLE_IDENTITIES: Array[StringName] = [&"goblin", &"sword_goblin", &"archer_goblin", &"goblin_bomber", &"ogre"]
const CAST_ATLAS: Texture2D = preload("res://assets/generated/shaman_cast.png")
const STAFF_SPIRAL_ATLAS: Texture2D = preload("res://assets/generated/shaman_staff_spiral.png")
# Pixel anchors in the original 192x256 artwork (centered sprite coordinates).
# The clean staff lane is shared across cast frames; the free hand still gestures.
const STAFF_BASE: Vector2 = Vector2(67, 242) - Vector2(96, 128)
const STAFF_CRYSTAL: Vector2 = Vector2(67, 50) - Vector2(96, 128)
var staff_spiral: AnimatedSprite2D = null
const HEAL_ORB_SCENE: PackedScene = preload("res://scenes/projectiles/shaman_heal_orb.tscn")
signal healing_orb_launched(orb: ShamanHealOrb)
@export var healing_range: float = 250.0
@export var healing_cooldown: float = 5.0
@export var cast_duration: float = 0.6
@export var preferred_player_distance: float = 280.0
@export var backline_offset: float = 110.0
signal healing_cast_started(target: Enemy)
signal healing_cast_completed(target: Enemy, restored: float)
signal healing_cast_interrupted
var cast_target: Enemy = null
var cast_elapsed: float = 0.0
var casting: bool = false
var cast_completion_flash_left: float = 0.0

func _configure_concrete_enemy() -> void:
	spawn_identity = &"goblin_shaman"
	grapple_weight = GrappleWeight.LIGHT
	participates_in_melee_engagement = false
	moving_weapon_enabled = false
	spear_visual_enabled = false
	move_speed = 85.0
	score_value = ranged_score_value + 60
	remnant_color = Color("87549d")
	death_sound_category = "goblin_things"
	fire_timer = 0.0

func is_eligible_ally(ally: Enemy, require_injured: bool = true) -> bool:
	return is_instance_valid(ally) and ally != self and not ally.death_emitted and not ally.is_queued_for_deletion() and ally.health > 0.0 and ally.max_health > 0.0 and ally.spawn_balance_key() in ELIGIBLE_IDENTITIES and (not require_injured or ally.health < ally.max_health)

func select_healing_target(allies: Array[Enemy], range_limit: float = -1.0) -> Enemy:
	var chosen: Enemy = null
	var lowest_ratio: float = 1.0
	var limit: float = healing_range if range_limit < 0.0 else range_limit
	for ally: Enemy in allies:
		if not is_eligible_ally(ally) or global_position.distance_to(ally.global_position) > limit: continue
		var ratio: float = ally.health / ally.max_health
		if ratio < lowest_ratio:
			lowest_ratio = ratio
			chosen = ally
	return chosen

func _allies() -> Array[Enemy]:
	var allies: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy: allies.append(node as Enemy)
	return allies

func _physics_process(delta: float) -> void:
	# Raw delta goes to super (Enemy applies WorldTime once); local clocks scale here.
	var world_delta: float = delta * WorldTime.enemy_scale()
	if staff_spiral != null: staff_spiral.speed_scale = WorldTime.enemy_scale()
	fire_timer = maxf(0.0, fire_timer - world_delta)
	cast_completion_flash_left = maxf(0.0, cast_completion_flash_left - world_delta)
	# Before shared Enemy consumes stun time, cancel even a one-frame stagger.
	if casting and (stun_left > 0.0 or death_emitted or health <= 0.0):
		interrupt_cast()
	super._physics_process(delta)
	_update_hd_enemy_sprite()

## Cast target is stored by instance id; a missing/retired target cancels the cast on restore.
func _rewind_extra_stride() -> int:
	return 6

func _rewind_capture_extra(d: PackedFloat32Array, o: int) -> void:
	d[o] = 1.0 if casting else 0.0; d[o + 1] = cast_elapsed; d[o + 2] = cast_completion_flash_left
	WorldRewindRecorder.write_id(d, o + 3, cast_target)

func _rewind_restore_extra(d: PackedFloat32Array, o: int) -> void:
	var target: Enemy = WorldRewindRecorder.read_id(d, o + 3) as Enemy
	casting = d[o] >= 0.5 and target != null and not target.rewind_retired
	cast_target = target if casting else null
	cast_elapsed = d[o + 1] if casting else 0.0
	cast_completion_flash_left = d[o + 2]
	_update_hd_enemy_sprite()

func _run_concrete_ai(delta: float) -> void:
	if casting:
		velocity = Vector2.ZERO
		advance_cast(delta)
		return
	var allies: Array[Enemy] = _allies()
	var target: Enemy = select_healing_target(allies)
	update_backline_motion(allies)
	if fire_timer <= 0.0 and target != null:
		begin_cast(target)
		velocity = Vector2.ZERO

func update_backline_motion(allies: Array[Enemy]) -> void:
	var away: Vector2 = player_ref.global_position.direction_to(global_position)
	if away.is_zero_approx(): away = Vector2.RIGHT
	var anchor: Enemy = null
	var nearest: float = INF
	var injured: Enemy = select_healing_target(allies, INF)
	if injured != null:
		anchor = injured
	else:
		for ally: Enemy in allies:
			if not is_eligible_ally(ally, false): continue
			var distance: float = global_position.distance_to(ally.global_position)
			if distance < nearest:
				nearest = distance
				anchor = ally
	var desired: Vector2 = player_ref.global_position + away * preferred_player_distance
	if anchor != null:
		var behind: Vector2 = player_ref.global_position.direction_to(anchor.global_position)
		if behind.is_zero_approx(): behind = away
		desired = anchor.global_position + behind * minf(backline_offset, healing_range * 0.7)
		# Stay behind the ally while remaining in its healing range.
		if desired.distance_to(player_ref.global_position) < preferred_player_distance:
			desired = player_ref.global_position + behind * minf(preferred_player_distance, anchor.global_position.distance_to(player_ref.global_position) + healing_range * 0.8)
	if global_position.distance_to(player_ref.global_position) < preferred_player_distance * 0.7:
		velocity = away * move_speed
	else:
		velocity = global_position.direction_to(desired) * minf(move_speed, global_position.distance_to(desired) * 2.0)

func begin_cast(target: Enemy) -> bool:
	if casting or fire_timer > 0.0 or stun_left > 0.0 or death_emitted or health <= 0.0 or is_queued_for_deletion(): return false
	if not is_eligible_ally(target) or global_position.distance_to(target.global_position) > healing_range: return false
	cast_target = target
	cast_elapsed = 0.0
	casting = true
	fire_timer = healing_cooldown
	healing_cast_started.emit(target)
	_update_hd_enemy_sprite()
	return true

func interrupt_cast() -> void:
	casting = false
	cast_target = null
	cast_elapsed = 0.0
	cast_completion_flash_left = 0.0
	_update_hd_enemy_sprite()
	healing_cast_interrupted.emit()

func advance_cast(delta: float) -> void:
	if not casting: return
	if stun_left > 0.0 or death_emitted or health <= 0.0 or not is_instance_valid(cast_target) or not is_eligible_ally(cast_target, false) or global_position.distance_to(cast_target.global_position) > healing_range:
		interrupt_cast()
		return
	cast_elapsed += maxf(0.0, delta)
	if cast_elapsed + 0.000001 < cast_duration: return
	var recipient: Enemy = cast_target
	if get_parent() == null:
		interrupt_cast()
		return
	var orb: ShamanHealOrb = HEAL_ORB_SCENE.instantiate() as ShamanHealOrb
	get_parent().add_child(orb)
	orb.launch(global_position + ShamanHealOrb.TARGET_OFFSET, recipient)
	casting = false
	cast_target = null
	cast_completion_flash_left = 0.14
	# Cast completion means launch, not healing. Only arrival delivers the heal.
	healing_cast_completed.emit(recipient, 0.0)
	healing_orb_launched.emit(orb)
	_update_hd_enemy_sprite()

func _is_hd_visual() -> bool:
	return true

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/shaman_idle.png", "move":"res://assets/generated/shaman_walk.png", "frame_size":Vector2(192, 256), "frame_count":4, "scale":0.3}

func _add_hd_animation(frames: SpriteFrames, animation_name: String, atlas: Texture2D, frame_size: Vector2, frame_count: int, speed: float) -> void:
	# All frame boundaries inspected. Mask ONLY detached neighbour fragments on
	# private image copies, retaining original generated files and body ornament.
	var image: Image = atlas.get_image()
	if image.is_compressed(): image.decompress()
	var scraps: Array[Rect2i] = []
	if animation_name == "idle":
		scraps = [Rect2i(211, 92, 7, 24), Rect2i(403, 92, 7, 24), Rect2i(595, 92, 7, 24)]
	elif animation_name == "move":
		frame_count = 6
		scraps = [Rect2i(918, 170, 5, 31), Rect2i(915, 220, 8, 25)]
	elif animation_name == "cast":
		scraps = [Rect2i(233, 130, 3, 16), Rect2i(425, 107, 2, 15), Rect2i(617, 143, 3, 13), Rect2i(617, 241, 4, 9), Rect2i(911, 17, 7, 40), Rect2i(809, 92, 7, 38)]
	for rect: Rect2i in scraps: image.fill_rect(rect, Color.TRANSPARENT)
	if animation_name == "cast":
		# Replace only the baked staff-magic lane/halo with the original clean
		# staff pixels. Keep originals on disk and the character's right-hand gesture.
		var source: Image = image.get_region(Rect2i(0, 0, 192, 256))
		for index: int in range(1, frame_count):
			image.blit_rect(source, Rect2i(0, 0, 82, 256), Vector2i(index * 192, 0))
			image.blit_rect(source, Rect2i(82, 0, 110, 80), Vector2i(index * 192 + 82, 0))
	var clean: Texture2D = ImageTexture.create_from_image(image)
	super._add_hd_animation(frames, animation_name, clean, frame_size, frame_count, speed)
	for index: int in range(frame_count):
		(frames.get_frame_texture(animation_name, index) as AtlasTexture).filter_clip = true

func _setup_hd_enemy_sprite() -> void:
	super._setup_hd_enemy_sprite()
	_add_hd_animation(hd_enemy_sprite.sprite_frames, "cast", CAST_ATLAS, Vector2(192, 256), 6, 6.0 / maxf(cast_duration, 0.01))
	hd_enemy_sprite.sprite_frames.set_animation_loop("cast", false)
	staff_spiral = AnimatedSprite2D.new()
	staff_spiral.name = "StaffSpiral"
	hd_enemy_sprite.add_child(staff_spiral)
	var frames: SpriteFrames = SpriteFrames.new()
	# Eight inspected 96x96 frames, clear lateral boundaries; clip vertical tips.
	super._add_hd_animation(frames, "spiral", STAFF_SPIRAL_ATLAS, Vector2(96, 96), 8, 8.0 / maxf(cast_duration, 0.01))
	for index: int in range(8):
		(frames.get_frame_texture("spiral", index) as AtlasTexture).filter_clip = true
	staff_spiral.sprite_frames = frames
	staff_spiral.animation = "spiral"
	staff_spiral.visible = false

func _update_staff_spiral() -> void:
	if staff_spiral == null: return
	staff_spiral.visible = hd_enemy_sprite.visible and not death_emitted and health > 0.0 and (casting or cast_completion_flash_left > 0.0)
	if not staff_spiral.visible: return
	# No second animation clock: rise, helix phase and release all read the cast.
	var progress: float = clampf(cast_elapsed / maxf(cast_duration, 0.01), 0.0, 1.0) if casting else 1.0
	var anchor: Vector2 = STAFF_BASE.lerp(STAFF_CRYSTAL, progress)
	if hd_enemy_sprite.flip_h: anchor.x = -anchor.x
	staff_spiral.position = anchor
	staff_spiral.flip_h = hd_enemy_sprite.flip_h
	staff_spiral.frame = clampi(int(progress * 8.0), 0, 7)
	# Narrow staff-local coils, not a body aura; tighten at the crystal on release.
	staff_spiral.scale = Vector2(0.8, 0.65) if casting else Vector2(0.95, 0.35)
	# Start with coils above the foot, not below it. Frame 7's sparkle
	# sits near y=8: its upper tip lands on the crystal as the cast completes.
	staff_spiral.offset = Vector2(0, lerpf(-48.0, 40.0, progress)) if casting else Vector2(0, 40)
	staff_spiral.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if casting else clampf(cast_completion_flash_left / 0.14, 0.0, 1.0))

func _update_hd_enemy_sprite() -> void:
	super._update_hd_enemy_sprite()
	if hd_enemy_sprite == null: return
	if casting or cast_completion_flash_left > 0.0:
		hd_enemy_sprite.animation = "cast"
		hd_enemy_sprite.pause()
		hd_enemy_sprite.frame = clampi(int(cast_elapsed / maxf(cast_duration, 0.01) * 6.0), 0, 5) if casting else 5
	_update_staff_spiral()

func _draw_concrete_body() -> void:
	pass
