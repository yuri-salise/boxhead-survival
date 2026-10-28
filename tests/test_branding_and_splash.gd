extends SceneTree

func _init() -> void:
	print("\n=== STARTING BRANDING & SPLASH SCREEN TEST SUITE ===")
	var errors := 0

	# 1. Test Branding Assets on disk
	print("Testing branding asset presence...")
	var required_assets: Array[String] = [
		"res://icon.svg",
		"res://assets/art/icon.png",
		"res://assets/art/dead_block_logo.svg",
		"res://assets/art/dead_block_logo.png",
		"res://assets/art/outpost_logo.svg",
		"res://assets/art/boot_splash.png"
	]
	for path in required_assets:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			printerr("  [FAIL] Missing required branding asset: ", path)
			errors += 1
		else:
			print("  [OK] Branding asset exists: ", path.get_file())

	# 2. Test icon customization (must not be default Godot robot)
	var icon_file = FileAccess.open("res://icon.svg", FileAccess.READ)
	if icon_file:
		var content = icon_file.get_as_text()
		icon_file.close()
		if content.contains("DEAD BLOCK") and not content.contains("478cbf"):
			print("  [OK] Custom Dead Block: Survival icon.svg verified")
		else:
			printerr("  [FAIL] icon.svg does not appear to contain Dead Block branding")
			errors += 1

	# 3. Test Boot Splash Image Dimensions
	var splash_global_path = ProjectSettings.globalize_path("res://assets/art/boot_splash.png")
	var splash_img = Image.load_from_file(splash_global_path)
	if splash_img != null:
		if splash_img.get_width() == 1280 and splash_img.get_height() == 720:
			print("  [OK] boot_splash.png matches design resolution 1280x720")
		else:
			printerr("  [FAIL] boot_splash.png has unexpected dimensions: ", splash_img.get_size())
			errors += 1
	else:
		printerr("  [FAIL] Failed to load boot_splash.png via Image")
		errors += 1

	# 4. Test Title Screen Scene Architecture
	print("Testing TitleScreen scene and hierarchy...")
	var title_scene_res = load("res://scenes/ui/title_screen.tscn")
	if title_scene_res == null or not (title_scene_res is PackedScene):
		printerr("  [FAIL] Could not load res://scenes/ui/title_screen.tscn")
		errors += 1
	else:
		var title_inst = title_scene_res.instantiate()
		if title_inst == null:
			printerr("  [FAIL] Could not instantiate title_screen.tscn")
			errors += 1
		else:
			# Verify nodes
			var logo_tex = title_inst.get_node_or_null("CenterContainer/MainVBox/LogoContainer/LogoTexture")
			if logo_tex is TextureRect and logo_tex.texture != null:
				print("  [OK] TitleScreen has valid LogoTexture node")
			else:
				printerr("  [FAIL] TitleScreen missing valid LogoTexture")
				errors += 1

			var studio_badge = title_inst.get_node_or_null("CenterContainer/MainVBox/StudioBadge")
			if studio_badge is TextureRect and studio_badge.texture != null:
				print("  [OK] TitleScreen has valid StudioBadge node")
			else:
				printerr("  [FAIL] TitleScreen missing valid StudioBadge")
				errors += 1

			var prompt = title_inst.get_node_or_null("CenterContainer/MainVBox/PromptContainer/PromptLabel")
			if prompt is Label and prompt.text.length() > 0:
				print("  [OK] TitleScreen has pulsing PromptLabel: '", prompt.text, "'")
			else:
				printerr("  [FAIL] TitleScreen missing PromptLabel")
				errors += 1

			var fade = title_inst.get_node_or_null("FadeOverlay")
			if fade is ColorRect:
				print("  [OK] TitleScreen has FadeOverlay for smooth transitions")
			else:
				printerr("  [FAIL] TitleScreen missing FadeOverlay")
				errors += 1

			# Verify transition state guard
			title_inst.advance_to_main_menu()
			if title_inst.is_transitioning:
				print("  [OK] advance_to_main_menu() flags is_transitioning guard correctly")
			else:
				printerr("  [FAIL] advance_to_main_menu() did not set is_transitioning")
				errors += 1

			title_inst.free()

	# 5. Test Main Menu Logo Branding
	print("Testing Main Menu Logo branding...")
	var menu_scene_res = load("res://scenes/ui/main_menu.tscn")
	if menu_scene_res is PackedScene:
		var menu_inst = menu_scene_res.instantiate()
		var menu_logo = menu_inst.get_node_or_null("MarginContainer/MainLayout/MenuColumn/TitleBox/LogoRect")
		if menu_logo is TextureRect and menu_logo.texture != null:
			print("  [OK] MainMenu contains branded LogoRect texture")
		else:
			printerr("  [FAIL] MainMenu missing LogoRect with texture")
			errors += 1
		menu_inst.free()

	# 6. Test project.godot settings
	print("Testing project.godot boot settings...")
	var main_scene = ProjectSettings.get_setting("application/run/main_scene")
	if main_scene == "res://scenes/ui/title_screen.tscn":
		print("  [OK] Boot scene is configured to title_screen.tscn")
	else:
		printerr("  [FAIL] Expected main_scene to be title_screen.tscn, got: ", main_scene)
		errors += 1

	var splash_path = ProjectSettings.get_setting("application/boot_splash/image")
	if splash_path == "res://assets/art/boot_splash.png":
		print("  [OK] Boot splash image set to res://assets/art/boot_splash.png")
	else:
		printerr("  [FAIL] Unexpected boot_splash/image: ", splash_path)
		errors += 1

	if errors > 0:
		printerr("\n=== TEST FAILED WITH ", errors, " ERRORS ===")
		quit(1)
	else:
		print("\n=== ALL BRANDING & SPLASH SCREEN TESTS PASSED (0 ERRORS) ===")
		quit(0)
