class_name ForestCapture extends Node
## Test-only observer. The playtest harness returns a single end-of-run frame,
## which is not enough to judge combat flow. This wrapper instances the real
## game, walks it to the Forest on its own, and snapshots the viewport into one
## contact sheet so the whole fight can be read at once.
##
## It changes NOTHING in the game — it only reads frames already being drawn.

const GAME_SCENE: PackedScene = preload("res://scenes/main.tscn")

const SHEET_COLS: int = 4
const SHEET_ROWS: int = 4
const THUMB: Vector2i = Vector2i(320, 180)
## Crop a window centred on the player so the BLADE, not the whole arena, is
## what we can actually see (the full frame is far too coarse to judge contact).
const CROP: Vector2i = Vector2i(560, 315)
const CAPTURE_INTERVAL: float = 1.4
const FIRST_CAPTURE_AT: float = 2.5
const OUT_DIR: String = "res://tests/captures"

var _game: Node = null
var _frames: Array[Image] = []
var _elapsed: float = 0.0
var _next_capture: float = FIRST_CAPTURE_AT
var _pressed_adventure: bool = false
var _pressed_forest: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dir: DirAccess = DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive("tests/captures")
	_game = GAME_SCENE.instantiate()
	add_child(_game)
	print("[CAPTURE] observer attached — driving to the Forest")


func _process(delta: float) -> void:
	_elapsed += delta
	# The game boots on the Home menu; walk it to the Forest for the player.
	if not _pressed_adventure and _elapsed >= 1.2:
		_pressed_adventure = true
		_press("AdventureButton")
	if not _pressed_forest and _elapsed >= 2.2:
		_pressed_forest = true
		_press("ForestButton")

	_next_capture -= delta
	if _next_capture <= 0.0 and _frames.size() < SHEET_COLS * SHEET_ROWS:
		_next_capture = CAPTURE_INTERVAL
		_capture()


func _press(node_name: String) -> void:
	if _game == null:
		return
	var node: Node = _game.find_child(node_name, true, false)
	if node is BaseButton:
		(node as BaseButton).emit_signal("pressed")
		print("[CAPTURE] pressed %s" % node_name)
	else:
		print("[CAPTURE] could not find %s" % node_name)


func _capture() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var tex: ViewportTexture = vp.get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img == null:
		return
	img = img.get_region(_player_crop_rect(img.get_size()))
	img.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_BILINEAR)
	_frames.append(img)
	_write_sheet()
	print("[CAPTURE] frame %d at %.1fs" % [_frames.size(), _elapsed])


func _player_crop_rect(full: Vector2i) -> Rect2i:
	var w: int = mini(CROP.x, full.x)
	var h: int = mini(CROP.y, full.y)
	var centre: Vector2 = Vector2(float(full.x) * 0.5, float(full.y) * 0.5)
	var player: Node = _game.find_child("Player", true, false) if _game != null else null
	if player is Node2D and is_instance_valid(player):
		centre = get_viewport().get_canvas_transform() * (player as Node2D).global_position
	var x: int = int(clampf(centre.x - float(w) * 0.5, 0.0, float(full.x - w)))
	var y: int = int(clampf(centre.y - float(h) * 0.5, 0.0, float(full.y - h)))
	return Rect2i(x, y, w, h)


func _write_sheet() -> void:
	var sheet: Image = Image.create_empty(SHEET_COLS * THUMB.x, SHEET_ROWS * THUMB.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.06, 1.0))
	for i: int in range(_frames.size()):
		var col: int = i % SHEET_COLS
		var row: int = floori(float(i) / float(SHEET_COLS))
		sheet.blit_rect(_frames[i], Rect2i(0, 0, THUMB.x, THUMB.y), Vector2i(col * THUMB.x, row * THUMB.y))
	sheet.save_png(OUT_DIR + "/forest_sheet.png")