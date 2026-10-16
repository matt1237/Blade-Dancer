class_name KajiPlantBreezePreview extends Node2D
## Disposable comparison only: no progression, commerce, saves or live-shop switch.
const ORIGINAL: Texture2D = preload("res://assets/portraits/Kaji's General Store.png")
const PLATE: Texture2D = preload("res://assets/generated/kaji_plant_breeze_v2_plate.png")
const LEAVES: Texture2D = preload("res://assets/generated/kaji_plant_breeze_v2_leaves.png")
const EFFECT: Shader = preload("res://scripts/ui/kaji_plant_breeze_preview.gdshader")
var original_room: Node2D
var candidate_room: Node2D
var detail_original: Node2D
var detail_candidate: Node2D
var detail_plate: Node2D
var breeze: ShaderMaterial
@export var record_evidence: bool = false
var elapsed: float = 0.0
var status: Label

func _ready() -> void:
	breeze = ShaderMaterial.new()
	breeze.shader = EFFECT
	original_room = Node2D.new()
	candidate_room = Node2D.new()
	detail_original = Node2D.new()
	detail_candidate = Node2D.new()
	detail_plate = Node2D.new()
	for group: Node2D in [original_room, candidate_room, detail_original, detail_candidate, detail_plate]:
		add_child(group)
	_sprite(original_room, ORIGINAL, Vector2.ZERO)
	_sprite(candidate_room, PLATE, Vector2.ZERO)
	_sprite(candidate_room, LEAVES, Vector2(436, 128)).material = breeze
	_sprite(detail_original, _crop(ORIGINAL), Vector2.ZERO)
	_sprite(detail_candidate, _crop(PLATE), Vector2.ZERO)
	_sprite(detail_candidate, LEAVES, Vector2(20, 32)).material = breeze
	_sprite(detail_plate, _crop(PLATE), Vector2.ZERO)
	_label("ORIGINAL — untouched", Vector2(24, 16))
	_label("CANDIDATE — isolated leaf breeze; pot / hook fixed", Vector2(654, 16))
	_label("ORIGINAL DETAIL", Vector2(24, 358))
	_label("EXPOSED PLATE — diagnostic", Vector2(436, 358))
	_label("ANIMATED DETAIL", Vector2(848, 358))
	status = _label("", Vector2(24, 690))
	get_viewport().size_changed.connect(_fit)
	_fit()
	if record_evidence:
		_record_evidence()

func _sprite(parent: Node2D, texture: Texture2D, at: Vector2) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	parent.add_child(sprite)
	return sprite

func _crop(texture: Texture2D) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(416, 96, 256, 256)
	return atlas

func _label(text: String, at: Vector2) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = at
	add_child(label)
	return label

func _fit() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var half: Vector2 = Vector2(viewport_size.x * 0.5 - 32.0, viewport_size.y * 0.43)
	var rect: Rect2 = KajiStoreBackdrop.image_rect(half)
	original_room.position = Vector2(16, 40) + rect.position
	candidate_room.position = Vector2(viewport_size.x * 0.5 + 16, 40) + rect.position
	original_room.scale = rect.size / KajiStoreBackdrop.SOURCE_SIZE
	candidate_room.scale = original_room.scale
	var factor: float = minf((viewport_size.x / 3.0 - 36.0) / 256.0, (viewport_size.y * 0.40) / 256.0)
	for index: int in range(3):
		var detail: Node2D = [detail_original, detail_plate, detail_candidate][index] as Node2D
		detail.position = Vector2(24.0 + index * viewport_size.x / 3.0, viewport_size.y * 0.535)
		detail.scale = Vector2.ONE * factor

func _record_evidence() -> void:
	set_process(false)
	for phase: float in [0.0, 2.0, 5.0]:
		breeze.set_shader_parameter("phase_seconds", phase)
		status.text = "PREVIEW ONLY | evidence phase %.1fs | pinned matte edges / pot / hook | Live shop unchanged" % phase
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var path: String = "res://tests/kaji_plant_breeze_evidence_v3_phase_%d.png" % int(phase)
		if not FileAccess.file_exists(path):
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png(path)
			print("Kaji leaf-breeze evidence: ", path)
	elapsed = 1.0
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	# One-second initial source-exact hold; then continuously varied quiet breeze.
	var phase: float = maxf(0.0, elapsed - 1.0)
	breeze.set_shader_parameter("phase_seconds", phase)
	status.text = "PREVIEW ONLY | phase %.2fs | max 2 source px | Original/live shop unchanged | Matte fringes still under review" % phase
