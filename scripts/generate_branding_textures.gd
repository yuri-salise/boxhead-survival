extends SceneTree

func _init() -> void:
	print("Generating high-resolution branding textures...")
	
	# 1. Rasterize logo SVG to PNG
	var logo_img = Image.load_from_file("res://assets/art/dead_block_logo.svg")
	if logo_img != null:
		var logo_err = logo_img.save_png("res://assets/art/dead_block_logo.png")
		print("  [OK] Saved dead_block_logo.png, err code: ", logo_err)
	else:
		printerr("  [ERROR] Failed to load dead_block_logo.svg via Image")

	# 2. Rasterize icon SVG to PNG
	var icon_img = Image.load_from_file("res://icon.svg")
	if icon_img != null:
		var icon_err = icon_img.save_png("res://assets/art/icon.png")
		print("  [OK] Saved icon.png, err code: ", icon_err)
	else:
		printerr("  [ERROR] Failed to load icon.svg via Image")

	# 3. Create 1280x720 boot_splash.png
	var splash = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	splash.fill(Color(0.05, 0.06, 0.07, 1.0))
	
	# Add subtle vignette & grid lines
	var dark_edge = Color(0.02, 0.03, 0.03, 1.0)
	var mid_color = Color(0.07, 0.08, 0.09, 1.0)
	for y in range(720):
		var dy = absf(float(y - 360) / 360.0)
		for x in range(1280):
			var dx = absf(float(x - 640) / 640.0)
			var dist = sqrt(dx * dx + dy * dy)
			var c = mid_color.lerp(dark_edge, clampf(dist * 0.9, 0.0, 1.0))
			
			# Add subtle industrial grid
			if x % 64 == 0 or y % 64 == 0:
				c = c.lerp(Color(0.09, 0.11, 0.13, 1.0), 0.3)
			splash.set_pixel(x, y, c)

	# Blit top and bottom hazard borders
	for x in range(1280):
		for y in range(12):
			var stripe = int(float(x + y) / 16.0) % 2 == 0
			var hc = Color(0.85, 0.47, 0.02, 0.8) if stripe else Color(0.08, 0.09, 0.10, 0.9)
			splash.set_pixel(x, y, hc)
			splash.set_pixel(x, 719 - y, hc)

	# Blit centered logo if available
	if logo_img != null:
		var lx = int(float(1280 - logo_img.get_width()) / 2.0)
		var ly = int(float(720 - logo_img.get_height()) / 2.0) - 20
		splash.blend_rect(logo_img, Rect2i(0, 0, logo_img.get_width(), logo_img.get_height()), Vector2i(lx, ly))

	var splash_err = splash.save_png("res://assets/art/boot_splash.png")
	print("  [OK] Saved boot_splash.png (1280x720), err code: ", splash_err)
	
	quit(0)
