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
				assert(inst.current_night_factor > 0.85, "Level 5 (Last Light) must start in deep nightfall")
				assert(inst.level_controller.night_mode_active == true, "Level 5 LevelController must track night_mode_active=true")
			
			# Test gradual time-based Day -> Dusk -> Nightfall -> Dawn progression and UNTOUCHABLE achievement in Level 1
			if lvl_id == 1:
				var f0: float = inst.current_night_factor
				assert(f0 < 0.20 and inst.get_time_of_day_label() == "DAYLIGHT", "Sector 1 must start in Daylight (f0=" + str(f0) + ")")
				
				# Advance 11 seconds -> should smoothly enter Sunset/Dusk (intermediate night_factor)
				inst.advance_day_night_cycle(11.0, true)
				var f_dusk: float = inst.current_night_factor
				assert(f_dusk > f0 and f_dusk > 0.30 and f_dusk < 0.75, "Time cycle must gradually enter intermediate Dusk (f_dusk=" + str(f_dusk) + ")")
				assert(inst.get_time_of_day_label() == "DUSK", "Label must be DUSK during sunset transition")
				
				# Advance another 14 seconds -> should smoothly reach Nightfall (flashlight cone active)
				inst.advance_day_night_cycle(14.0, true)
				var f_night: float = inst.current_night_factor
				assert(f_night > f_dusk and f_night > 0.85, "Time cycle must gradually reach deep Nightfall (f_night=" + str(f_night) + ")")
				assert(inst.get_time_of_day_label() == "NIGHTFALL", "Label must be NIGHTFALL at night")
				assert(inst.horror_vignette.night_factor > 0.85, "HorrorVignette night_factor must smoothly match level cycle")
				assert(inst.arena_env.night_factor > 0.85, "ArenaEnvironment night_factor must smoothly match level cycle")
				
				# Advance 16 seconds -> should smoothly transition into Dawn
				inst.advance_day_night_cycle(16.0, true)
				var f_dawn: float = inst.current_night_factor
				assert(f_dawn < f_night and f_dawn > 0.24 and f_dawn < 0.70, "Time cycle must gradually transition into Dawn (f_dawn=" + str(f_dawn) + ")")
				assert(inst.get_time_of_day_label() == "DAWN", "Label must be DAWN during sunrise transition")
				
				inst._on_all_waves_completed()
				assert(inst.result_screen.visible == true and inst.result_screen.is_victory == true, "Completing all waves must open Victory ResultScreen")
				assert("UNTOUCHABLE" in inst.result_screen.unlock_banner.text, "Clearing without getting bit must display UNTOUCHABLE achievement")
				assert("NIGHT" in inst.result_screen.unlock_banner.text, "Experiencing Nightfall in sector must display NIGHT STALKER achievement")
			
			inst.queue_free()
		
		print("All 5 Campaign Levels, Night Mode Flashlight Cone & UNTOUCHABLE Achievement: PASS")
		print("ALL CAMPAIGN LEVEL TESTS PASSED!")
		get_tree().quit(0)
