extends SceneTree

func _init() -> void:
	var room_texture: Texture2D = load("res://assets/portraits/Blacksmith Store.png") as Texture2D
	var source: Image = room_texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var output: Image = Image.create(225, 350, false, Image.FORMAT_RGBA8)
	for y: int in range(350):
		for x: int in range(225):
			output.set_pixel(x, y, source.get_pixel(x, y))
	for y: int in range(108, 312):
		for x: int in range(40, 175):
			var color: Color = source.get_pixel(x, y)
			var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			var sign_brown: bool = color.r > color.g * 1.12 and color.g > color.b * 1.14 and color.r < 0.55 and luminance < 0.34
			var emblem_gold: bool = color.r > 0.40 and color.g > 0.27 and color.r > color.b * 1.16 and luminance < 0.50
			if sign_brown or emblem_gold:
				output.set_pixel(x, y, Color(0.78, 0.66, 0.47, 0.0))
	var error_code: Error = output.save_png("res://assets/generated/blacksmith_sign_matte_v1.png")
	print("blacksmith sign matte status=", error_code)
	quit()
