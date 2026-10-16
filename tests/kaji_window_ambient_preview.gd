class_name KajiWindowAmbientPreview extends GeneralStorePreview
## Real General shop, same in-memory progression, no save writes.
## L/R pin a passage in each window; C advances cloud checkpoints; N restores ambient.
var checkpoint: int = 0

func _ready() -> void:
	super._ready()
	await get_tree().process_frame
	hub.shop_backdrop.ambient_rng.seed = 731
	print("KAJI WINDOW BENCH: L/R pin birds / C cloud+ray phase / D dust inspection / N normal; P pause / E original")

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var backdrop: KajiStoreBackdrop = hub.shop_backdrop
	if event.keycode == KEY_L or event.keycode == KEY_R:
		backdrop.set_process(false)
		backdrop._begin_bird()
		backdrop.bird_variant = 1 if event.keycode == KEY_L else 2
		backdrop.bird_window = 0 if event.keycode == KEY_L else 1
		backdrop.bird_y = 218.0 if event.keycode == KEY_L else 254.0
		backdrop.bird_size = 30.0
		backdrop.bird_reverse = false
		backdrop.bird_elapsed = backdrop.bird_duration*0.42 if event.keycode == KEY_L else backdrop.bird_duration*0.52
		backdrop._present_bird()
		print("KAJI bird pinned window: ",backdrop.bird_window)
	elif event.keycode == KEY_C:
		backdrop.set_process(false)
		backdrop._finish_bird()
		checkpoint = (checkpoint+1)%3
		var phase: float = [3.0,6.0,12.0][checkpoint]
		(backdrop.painting.material as ShaderMaterial).set_shader_parameter("ambient_time",phase)
		print("KAJI cloud/ray checkpoint: ",phase)
	elif event.keycode == KEY_D:
		backdrop.set_process(false)
		backdrop._finish_bird()
		(backdrop.painting.material as ShaderMaterial).set_shader_parameter("ambient_time",6.0)
		print("KAJI dust inspection checkpoint: 6.0")
	elif event.keycode == KEY_N:
		backdrop._sync_ambient()
