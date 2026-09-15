class_name WeaponOrientationCheck extends RefCounted
## Diagnoses whether a weapon sprite follows this project's render
## convention: hilt/crossguard near image-TOP, blade tip near image-BOTTOM
## (see docs/architecture.md "Adding a new weapon"). AI-generated weapon art
## does NOT reliably follow this -- it comes out backwards (mirrored
## top-to-bottom) a large fraction of the time, which renders as the player
## visibly holding the blade instead of the handle. This has bitten nearly
## every weapon sprite added to the project; run this immediately after
## generating any new weapon art, BEFORE wiring it into
## Player.BLADE_PROFILES / Player.equipped_sword_texture().
##
## Usage (e.g. from execute_script, right after generate_pixel_art):
##   var result: Dictionary = WeaponOrientationCheck.check("res://assets/generated/my_new_sword_frame_0.png")
##   print(result["verdict"])
##
## How it works: scans horizontal bands top-to-bottom, measuring each band's
## opaque-pixel width extent. A crossguard/hilt reads as a short, unusually
## WIDE blob compared to the long, gradually-tapering blade -- so the band
## with the single biggest extent spike marks the hilt. If that spike sits
## in the top half of the image, the art matches convention. If it's in the
## bottom half, the sword will render end-for-end backwards (grip far from
## the hand, tip right next to it) unless corrected -- either flip the
## source PNG (Image.load_from_file(path).flip_y() then save_png(path)), or
## set Player.SWORD_TEXTURE_FLIP_Y[sword_id] = true instead of touching the
## art at all.
static func check(path: String, band_count: int = 20) -> Dictionary:
	if not ResourceLoader.exists(path, "Texture2D"):
		return {"ok": false, "error": "could not load image at %s" % path}
	var texture: Texture2D = load(path) as Texture2D
	if texture == null:
		return {"ok": false, "error": "could not load image at %s" % path}
	var img: Image = texture.get_image()
	if img == null or img.is_empty():
		return {"ok": false, "error": "could not read image data at %s" % path}
	var w: int = img.get_width()
	var h: int = img.get_height()
	var extents: Array = []
	var best_band: int = -1
	var best_extent: float = -1.0
	for band: int in range(band_count):
		var y0: int = int(float(band) / float(band_count) * h)
		var y1: int = int(float(band + 1) / float(band_count) * h)
		var min_x: int = w
		var max_x: int = -1
		var count: int = 0
		for y: int in range(y0, maxi(y1, y0 + 1), 2):
			for x: int in range(0, w, 2):
				var c: Color = img.get_pixel(x, y)
				if c.a > 0.15:
					min_x = mini(min_x, x)
					max_x = maxi(max_x, x)
					count += 1
		var extent: float = float(max_x - min_x) if count > 0 else 0.0
		extents.append(extent)
		if extent > best_extent:
			best_extent = extent
			best_band = band
	var hilt_in_top_half: bool = best_band >= 0 and best_band < int(band_count / 2)
	return {
		"ok": true,
		"size": img.get_size(),
		"extents_per_band": extents,
		"widest_band_index": best_band,
		"widest_band_extent": best_extent,
		"hilt_likely_in_top_half": hilt_in_top_half,
		"verdict": ("MATCHES convention (hilt near top) -- safe to wire in as-is." if hilt_in_top_half
			else "INVERTED (hilt near bottom) -- set Player.SWORD_TEXTURE_FLIP_Y[sword_id] = true, or flip_y() + re-save the PNG before wiring this in."),
	}
