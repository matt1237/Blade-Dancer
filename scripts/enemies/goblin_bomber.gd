class_name GoblinBomber extends Enemy

const BOMB_SCENE: PackedScene = preload("res://scenes/projectiles/bomber_bomb.tscn")
const THROW_ATLAS: Texture2D = preload("res://assets/generated/bomber_windup_throw.png")
static var _clean_throw_atlas: Texture2D = null
# A read-only link to the world-owned attack, never another attack clock.
var attack_bomb: BomberBomb = null
@export var attack_cooldown: float = 4.0
@export var preferred_min_distance: float = 240.0
@export var preferred_max_distance: float = 360.0

func _configure_concrete_enemy() -> void:
	spawn_identity = &"goblin_bomber"
	grapple_weight = GrappleWeight.LIGHT
	participates_in_melee_engagement = false
	moving_weapon_enabled = false
	spear_visual_enabled = false
	move_speed = 95.0
	score_value = ranged_score_value + 50
	loot_material_name = "Mushroom"
	loot_material_chance = LootConfig.MUSHROOM_DROP_CHANCE
	remnant_color = Color("9b743d")
	death_sound_category = "goblin_things"
	death_sound_pitch = 1.08
	fire_timer = attack_cooldown

func _run_concrete_ai(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	var target: Vector2 = player_ref.global_position
	var direction: Vector2 = global_position.direction_to(target)
	var distance: float = global_position.distance_to(target)
	if distance < preferred_min_distance:
		velocity = -direction * move_speed
	elif distance > preferred_max_distance:
		velocity = direction * move_speed
	else:
		velocity = direction.orthogonal() * engagement_orbit_sign * move_speed * 0.25
	if fire_timer <= 0.0 and _has_player_line_of_sight():
		_begin_bomb_attack()
		fire_timer = attack_cooldown

func _begin_bomb_attack() -> BomberBomb:
	var bomb: BomberBomb = BOMB_SCENE.instantiate() as BomberBomb
	# World sibling, not a child of the enemy: death never cancels an armed bomb.
	get_parent().add_child(bomb)
	bomb.arm(global_position, player_ref.global_position, player_ref as Player, self)
	attack_bomb = bomb
	bomb.attack_advanced.connect(_update_hd_enemy_sprite)
	_update_hd_enemy_sprite()
	return bomb

func _is_hd_visual() -> bool:
	return true

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/bomber_walk_padded.png", "move":"res://assets/generated/bomber_walk_padded.png", "frame_size":Vector2(256, 256), "frame_count":4, "scale":0.27}

func _add_hd_animation(frames: SpriteFrames, animation_name: String, atlas: Texture2D, _frame_size: Vector2, frame_count: int, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, true)
	for index: int in range(frame_count):
		# Inspected frame boundaries: detached neighbour scraps only in the empty
		# side margins of frames 1/2. Crop them without shifting the 256px canvas.
		var right: float = 202.0 if index == 1 or index == 2 else 216.0
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(float(index) * 256.0 + 40.0, 0.0, right - 40.0, 256.0)
		frame.margin = Rect2(40.0, 0.0, 256.0 - (right - 40.0), 0.0)
		frame.filter_clip = true
		frames.add_frame(animation_name, frame)

func _setup_hd_enemy_sprite() -> void:
	super._setup_hd_enemy_sprite()
	if _clean_throw_atlas == null:
		# Inspected six 256px frames. Remove ONLY detached neighbour scraps
		# on a private image copy; the generated atlas/base on disk stay intact.
		var image: Image = THROW_ATLAS.get_image()
		if image.is_compressed(): image.decompress()
		for rect: Rect2i in [Rect2i(190, 0, 66, 256), Rect2i(714, 0, 54, 256), Rect2i(967, 110, 57, 146), Rect2i(1024, 40, 75, 46), Rect2i(1280, 0, 60, 256)]:
			image.fill_rect(rect, Color.TRANSPARENT)
		_clean_throw_atlas = ImageTexture.create_from_image(image)
	var frames: SpriteFrames = hd_enemy_sprite.sprite_frames
	for animation_name: String in ["bomb_windup", "bomb_throw"]:
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, false)
		frames.set_animation_speed(animation_name, 3.0 / (BomberBomb.WARNING_TIME if animation_name == "bomb_windup" else BomberBomb.FLIGHT_TIME))
		var first: int = 0 if animation_name == "bomb_windup" else 3
		for index: int in range(first, first + 3):
			var frame: AtlasTexture = AtlasTexture.new()
			frame.atlas = _clean_throw_atlas
			frame.region = Rect2(index * 256, 0, 256, 256)
			frame.filter_clip = true
			frames.add_frame(animation_name, frame)

func _update_hd_enemy_sprite() -> void:
	# Retain shared facing, scale, hit reactions and locomotion lifecycle.
	super._update_hd_enemy_sprite()
	if hd_enemy_sprite == null or not is_instance_valid(attack_bomb): return
	if not attack_bomb.armed: return
	var progress: float
	var animation_name: String
	match attack_bomb.phase:
		BomberBomb.Phase.WARNING:
			animation_name = "bomb_windup"
			progress = attack_bomb.elapsed / BomberBomb.WARNING_TIME
		BomberBomb.Phase.FLIGHT:
			animation_name = "bomb_throw"
			progress = (attack_bomb.elapsed - BomberBomb.WARNING_TIME) / BomberBomb.FLIGHT_TIME
		_:
			return
	# No free-running animation timer can release early or drift after a skip.
	hd_enemy_sprite.animation = animation_name
	hd_enemy_sprite.pause()
	hd_enemy_sprite.frame = clampi(int(progress * 3.0), 0, 2)

func _draw_concrete_body() -> void:
	pass
