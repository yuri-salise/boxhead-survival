extends SceneTree

func _init():
	var runner = GameStateTestRunner.new()
	root.add_child.call_deferred(runner)

class GameStateTestRunner extends Node:
	func _ready():
		print("Testing GameState Progression, Achievements & Night Mode Persistence...")
		var GameStateScript = load("res://autoload/game_state.gd")
		assert(GameStateScript != null, "Failed to load res://autoload/game_state.gd")
		
		var gs = GameStateScript.new()
		add_child(gs)
		gs.reset_progress()
		gs.night_mode_enabled = false
		gs.save_progress()
		
		assert(gs.unlocked_level == 1, "Default unlocked level must be 1")
		assert(gs.is_level_unlocked(1) == true and gs.is_level_unlocked(2) == false, "Only Level 1 unlocked initially")
		assert(gs.has_achievement("UNTOUCHABLE") == false, "UNTOUCHABLE starts locked")
		assert(gs.has_achievement("NIGHT_STALKER") == false, "NIGHT_STALKER starts locked")
		
		# 1. Complete Level 1 without getting bit + in Night Mode
		var new_achs: Array[String] = gs.complete_level(1, 520, 3, true, true)
		assert(gs.unlocked_level == 2, "Completing Level 1 must unlock Level 2")
		assert(gs.best_score_by_level[1] == 520 and gs.best_stars_by_level[1] == 3, "Best score and stars saved")
		assert(new_achs.has("UNTOUCHABLE"), "Clearing sector without getting bit must unlock UNTOUCHABLE")
		assert(new_achs.has("NIGHT_STALKER"), "Clearing sector in Night Mode must unlock NIGHT_STALKER")
		assert(gs.has_achievement("UNTOUCHABLE") == true, "UNTOUCHABLE achievement must be marked unlocked")
		assert(gs.has_achievement("NIGHT_STALKER") == true, "NIGHT_STALKER achievement must be marked unlocked")
		print("Level 1 unlock + UNTOUCHABLE & NIGHT_STALKER achievements: PASS")
		
		# 2. Test Limb Ripper & Boss Slayer achievements
		for i in range(15):
			gs.record_limb_severed()
		assert(gs.has_achievement("LIMB_RIPPER") == true, "Severing 15 limbs must unlock LIMB_RIPPER")
		
		gs.record_special_kill("WITCH")
		assert(gs.has_achievement("BOSS_SLAYER") == false, "Killing only Witch should not unlock BOSS_SLAYER yet")
		gs.record_special_kill("TANKER")
		assert(gs.has_achievement("BOSS_SLAYER") == true, "Killing both Witch and Tanker must unlock BOSS_SLAYER")
		print("LIMB_RIPPER & BOSS_SLAYER career achievements: PASS")
		
		# 3. Test Persistence across reload
		gs.night_mode_enabled = true
		gs.save_progress()
		
		var gs_reloaded = GameStateScript.new()
		add_child(gs_reloaded)
		assert(gs_reloaded.unlocked_level == 2, "Reloaded GameState must preserve unlocked_level == 2")
		assert(gs_reloaded.has_achievement("UNTOUCHABLE") == true, "Reloaded GameState must preserve UNTOUCHABLE")
		assert(gs_reloaded.has_achievement("NIGHT_STALKER") == true, "Reloaded GameState must preserve NIGHT_STALKER")
		assert(gs_reloaded.night_mode_enabled == true, "Reloaded GameState must preserve night_mode_enabled")
		print("ConfigFile disk persistence across reload: PASS")
		
		# Clean up test state back to Level 1 unlocked for clean environment
		gs_reloaded.reset_progress()
		gs_reloaded.night_mode_enabled = false
		gs_reloaded.save_progress()
		gs.queue_free()
		gs_reloaded.queue_free()
		
		print("ALL GAME STATE & ACHIEVEMENT TESTS PASSED!")
		get_tree().quit(0)
