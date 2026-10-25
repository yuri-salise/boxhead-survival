extends SceneTree

func _init():
	var runner = CampaignLevelsTestRunner.new()
	root.add_child.call_deferred(runner)

class CampaignLevelsTestRunner extends Node:
	func _ready():
		print("Testing 5-Level Campaign Scenes, Progressive Waves, Night Mode & No-Bite Achievements...")
		var expected_waves: Dictionary = {
			1: 3,
			2: 4,
			3: 4,
			4: 5,
			5: 5
		}
		
		for lvl_id in range(1, 6):
			var path := "res://scenes/levels/level_0" + str(lvl_id) + ".tscn"
			var packed = load(path)
			assert(packed != null, "Failed to load " + path)
			
			var inst = packed.instantiate()
			add_child(inst)
			assert(inst.level_id == lvl_id, "Level instance must have level_id == " + str(lvl_id))
			assert(inst.wave_director != null and inst.level_controller != null, "Level must have WaveDirector and LevelController")
			assert(inst.wave_director.get_total_waves() == expected_waves[lvl_id], "Level " + str(lvl_id) + " wave count mismatch")
			
			if lvl_id == 5:
				assert(inst.horror_vignette.night_mode_enabled == true, "Level 5 (Last Light) must enable Night Mode by default")
				assert(inst.level_controller.night_mode_active == true, "Level 5 LevelController must track night_mode_active=true")
			
			# Test completing Level 1 without getting bit shows UNTOUCHABLE achievement on ResultScreen
			if lvl_id == 1:
				inst.set_night_mode_enabled(true)
				assert(inst.horror_vignette.night_mode_enabled == true, "Night mode should toggle on in Level 1")
				inst._on_all_waves_completed()
				assert(inst.result_screen.visible == true and inst.result_screen.is_victory == true, "Completing all waves must open Victory ResultScreen")
				assert("UNTOUCHABLE" in inst.result_screen.unlock_banner.text, "Clearing without getting bit must display UNTOUCHABLE achievement")
				assert("NIGHT" in inst.result_screen.unlock_banner.text, "Clearing in Night Mode must display NIGHT STALKER achievement")
			
			inst.queue_free()
		
		print("All 5 Campaign Levels, Night Mode Flashlight Cone & UNTOUCHABLE Achievement: PASS")
		print("ALL CAMPAIGN LEVEL TESTS PASSED!")
		get_tree().quit(0)
