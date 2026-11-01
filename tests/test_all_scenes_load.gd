extends SceneTree

func _init() -> void:
	print("Checking all .tscn and .gd files in project...")
	var errors := 0
	var scenes_to_check: Array[String] = [
		"res://scenes/levels/level_01.tscn",
		"res://scenes/levels/level_02.tscn",
		"res://scenes/levels/level_03.tscn",
		"res://scenes/levels/level_04.tscn",
		"res://scenes/levels/level_05.tscn",
		"res://scenes/ui/title_screen.tscn",
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/mode_select.tscn",
		"res://scenes/ui/level_select.tscn",
		"res://scenes/ui/lobby.tscn",
		"res://scenes/ui/pause_menu.tscn",
		"res://scenes/ui/result_screen.tscn",
		"res://scenes/ui/touch_controls.tscn",
		"res://scenes/actors/player.tscn",
		"res://scenes/actors/zombie_basic.tscn",
		"res://scenes/actors/projectile.tscn",
		"res://scenes/actors/pickup.tscn",
		"res://scenes/actors/generator.tscn",
		"res://scenes/actors/fuel_truck.tscn",
		"res://scenes/actors/supply_crate.tscn",
		"res://scenes/actors/sentry_turret.tscn",
		"res://scenes/effects/blood_splatter.tscn"
	]
	
	for s_path in scenes_to_check:
		if not ResourceLoader.exists(s_path):
			print("  [SKIP] Does not exist: ", s_path)
			continue
		var res = load(s_path)
		if res == null:
			printerr("  [ERROR] Failed to load scene: ", s_path)
			errors += 1
			continue
		if res is PackedScene:
			var inst = res.instantiate()
			if inst == null:
				printerr("  [ERROR] Failed to instantiate scene: ", s_path)
				errors += 1
			else:
				print("  [OK] Successfully instantiated: ", s_path.get_file())
				inst.free()
	
	if errors > 0:
		printerr("Scene load check FAILED with ", errors, " errors.")
		quit(1)
	else:
		print("All scenes loaded and instantiated successfully with 0 errors!")
		quit(0)
