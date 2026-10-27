extends SceneTree

func _init() -> void:
	var runner := SurvivalAndGeneratorTestRunner.new()
	root.add_child.call_deferred(runner)

class SurvivalAndGeneratorTestRunner extends Node:
	func _ready() -> void:
		print("=================================================================")
		print("  STARTING TEST SUITE: SURVIVAL MODE, HERD SWARMS & GENERATOR   ")
		print("=================================================================")
		
		_test_ambient_lights_and_horror_vignette()
		_test_generator_mechanics()
		_test_endless_survival_and_herd_swarms()
		_test_game_state_survival_persistence()
		_test_mode_select_survival_button()
		
		print("=================================================================")
		print("  ALL SURVIVAL & GENERATOR TESTS PASSED (100% VERIFIED)        ")
		print("=================================================================")
		get_tree().quit(0)

	func _test_ambient_lights_and_horror_vignette() -> void:
		print("Test 1: Ambient Obstacle Lights & Horror Vignette Visibility...")
		var ArenaEnvScript = load("res://scripts/arena_environment.gd")
		assert(ArenaEnvScript != null, "arena_environment.gd must load")
		var arena = ArenaEnvScript.new()
		add_child(arena)
		
		assert(arena.has_method("get_ambient_lights"), "arena_environment must have get_ambient_lights method")
		
		# Test Sector 1 Quarantine beacon lights
		arena.sector_type = 1 # SectorBiome.QUARANTINE
		var q_lights: Array = arena.get_ambient_lights(Vector2(640, 360), 1200.0)
		assert(q_lights is Array, "get_ambient_lights must return an Array")
		
		# Test Sector 5 Urban streetlights
		arena.sector_type = 5 # SectorBiome.URBAN
		var u_lights: Array = arena.get_ambient_lights(Vector2(640, 360), 1200.0)
		assert(u_lights is Array, "get_ambient_lights must return an Array")
		
		# Test HorrorVignette with ambient lights and witch eyes
		var VignetteScript = load("res://scripts/horror_vignette.gd")
		var vignette = VignetteScript.new()
		add_child(vignette)
		
		vignette.set_night_factor(1.0, true)
		assert(vignette.night_factor == 1.0, "night_factor must be set to 1.0")
		
		var sample_lights: Array = [
			{"world_pos": Vector2(700, 300), "radius": 175.0, "color": Color(0.85, 0.92, 1.0, 0.90)},
			{"world_pos": Vector2(400, 500), "radius": 340.0, "color": Color(1.0, 0.90, 0.50, 0.95)}
		]
		vignette.update_flashlight_transform(Vector2(640, 360), 0.0, [], Vector2(640, 360))
		vignette.update_ambient_lights(sample_lights, Vector2(640, 360))
		assert(vignette.ambient_lights.size() == 2, "vignette must store ambient lights")
		
		# Test Witch eyes tracking
		var sample_witches: Array = [
			{"pos": Vector2(850, 400), "rot": 0.5, "is_enraged": false},
			{"pos": Vector2(300, 200), "rot": -1.2, "is_enraged": true}
		]
		vignette.update_witch_eyes(sample_witches, Vector2(640, 360))
		assert(vignette.active_witches.size() == 2, "vignette must register active witches for glowing eyes")
		assert(vignette.active_witches[1]["is_enraged"] == true, "enraged witch status must be preserved")
		
		arena.queue_free()
		vignette.queue_free()
		print("  -> Ambient Obstacle Lights & Witch Eyes: PASS")

	func _test_generator_mechanics() -> void:
		print("Test 2: Emergency Generator Interaction, Solid Collider & Floodlight...")
		var GenScene = load("res://scenes/actors/generator.tscn")
		assert(GenScene != null, "generator.tscn must load")
		var gen = GenScene.instantiate()
		add_child(gen)
		
		assert(gen.is_in_group("obstacles"), "Generator must be in obstacles group")
		assert(gen.is_in_group("generators"), "Generator must be in generators group")
		assert(gen.collision_layer == 1, "Generator must have physical collision on layer 1")
		assert(gen.is_running == false, "Generator starts powered off")
		
		# Prior to start, light data is empty
		var off_light: Dictionary = gen.get_light_data()
		assert(off_light.is_empty(), "Turned-off generator must not emit light")
		
		# Start generator
		var started_emitted := [false]
		gen.generator_started.connect(func(_pos): started_emitted[0] = true)
		
		var success: bool = gen.start_generator()
		assert(success == true, "start_generator() should return true on first activation")
		assert(gen.is_running == true, "Generator is_running must be true")
		assert(started_emitted[0] == true, "generator_started signal must be emitted")
		
		var on_light: Dictionary = gen.get_light_data()
		assert(not on_light.is_empty(), "Turned-on generator must emit light data")
		assert(float(on_light["radius"]) >= 300.0, "Generator floodlight radius must be at least 300px")
		
		# Starting an already running generator returns false
		assert(gen.start_generator() == false, "start_generator() should return false when already running")
		
		gen.queue_free()
		print("  -> Generator Activation & Floodlight: PASS")

	func _test_endless_survival_and_herd_swarms() -> void:
		print("Test 3: Endless Survival Wave Progression & Herd Swarm Rushes...")
		var WaveDirScript = load("res://scripts/wave_director.gd")
		assert(WaveDirScript != null, "wave_director.gd must load")
		var director = WaveDirScript.new()
		add_child(director)
		
		director.is_endless_survival = true
		assert(director.get_total_waves() == -1, "Endless mode total waves must be -1 (endless indicator)")
		
		var herd_triggered := [false]
		var herd_count := [0]
		director.herd_swarm_triggered.connect(func(cnt, _ang):
			herd_triggered[0] = true
			herd_count[0] = cnt
		)
		
		# Test manual herd trigger
		director.trigger_herd_swarm(12, 1.57)
		assert(herd_triggered[0] == true, "trigger_herd_swarm must emit herd_swarm_triggered")
		assert(herd_count[0] == 12, "Herd count must match requested count")
		
		# Start endless waves
		director.start_waves()
		assert(director.is_wave_active == true, "Wave must be active")
		assert(director.current_wave_index == 0, "Starts at wave index 0 (Wave 1)")
		assert(director.total_enemies_in_wave >= 10, "Wave 1 in endless must have at least 10 enemies")
		
		# Complete wave 1 and verify endless transitions
		director.enemies_killed_in_wave = director.total_enemies_in_wave
		director.notify_enemy_killed()
		assert(director.is_intermission == true, "Endless waves must enter intermission after wave clear")
		assert(director.all_completed == false, "Endless mode should not set all_completed")
		
		# Trigger next wave
		director._on_intermission_finished()
		assert(director.current_wave_index == 1, "Should advance to Wave 2")
		assert(director.total_enemies_in_wave > 10, "Wave 2 must have scaled enemy count")
		
		director.queue_free()
		print("  -> Endless Survival Scaling & Herd Rushes: PASS")

	func _test_game_state_survival_persistence() -> void:
		print("Test 4: GameState Survival Records & Achievements...")
		var GameStateScript = load("res://autoload/game_state.gd")
		var gs = GameStateScript.new()
		add_child(gs)
		
		gs.survival_best_wave = 0
		gs.survival_best_score = 0
		
		var run_result: Dictionary = gs.record_survival_run(7, 850)
		assert(run_result["new_wave_record"] == true, "First run should be a new wave record")
		assert(run_result["new_score_record"] == true, "First run should be a new score record")
		assert(gs.survival_best_wave == 7, "survival_best_wave must be updated to 7")
		assert(gs.survival_best_score == 850, "survival_best_score must be updated to 850")
		
		# Lower run does not override records
		var run_lower: Dictionary = gs.record_survival_run(4, 500)
		assert(run_lower["new_wave_record"] == false, "Lower wave is not a new record")
		assert(gs.survival_best_wave == 7, "survival_best_wave must remain 7")
		
		# 10+ wave run unlocks SURVIVOR_TEN achievement
		gs.record_survival_run(10, 1500)
		assert(gs.has_achievement("SURVIVOR_TEN") == true, "Wave 10 must unlock SURVIVOR_TEN achievement")
		
		gs.queue_free()
		print("  -> GameState Survival Records & Achievements: PASS")

	func _test_mode_select_survival_button() -> void:
		print("Test 5: Mode Select UI Survival Option...")
		var ModeSelectScene = load("res://scenes/ui/mode_select.tscn")
		assert(ModeSelectScene != null, "mode_select.tscn must load")
		var mode_select = ModeSelectScene.instantiate()
		add_child(mode_select)
		
		var survival_btn: Button = mode_select.get_node_or_null("CenterContainer/ModePanel/ModeMargin/ModeVBox/SurvivalModeButton")
		assert(survival_btn != null, "mode_select.tscn must contain SurvivalModeButton")
		assert("SURVIVAL" in survival_btn.text.to_upper(), "Button text must indicate Survival Mode")
		
		mode_select.queue_free()
		print("  -> Mode Select UI Survival Option: PASS")
