extends SceneTree

func _init():
	var runner = WaveDirectorTestRunner.new()
	root.add_child.call_deferred(runner)

class WaveDirectorTestRunner extends Node:
	func _ready():
		print("Testing WaveDirector State Machine & Concurrency Controls...")
		var WaveDirectorScript = load("res://scripts/wave_director.gd")
		assert(WaveDirectorScript != null, "Failed to load res://scripts/wave_director.gd")
		
		var director = WaveDirectorScript.new()
		add_child(director)
		
		var test_waves: Array[Dictionary] = [
			{
				"total_enemies": 3,
				"spawn_interval": 0.05,
				"max_concurrent": 2,
				"intermission": 0.0,
				"guaranteed_boss": -1
			},
			{
				"total_enemies": 2,
				"spawn_interval": 0.05,
				"max_concurrent": 2,
				"intermission": 0.0,
				"guaranteed_boss": 3
			}
		]
		director.setup_waves(test_waves)
		
		var started_waves: Array[int] = []
		var spawned_types: Array[int] = []
		var completed_waves: Array[int] = []
		var all_done := [false]
		
		director.wave_started.connect(func(w_num, _tot, _enemies): started_waves.append(w_num))
		director.enemy_spawn_requested.connect(func(e_type): spawned_types.append(e_type))
		director.wave_completed.connect(func(w_num, _tot): completed_waves.append(w_num))
		director.all_waves_completed.connect(func(): all_done[0] = true)
		
		# Start Wave 1
		director.start_waves()
		assert(started_waves.size() == 1 and started_waves[0] == 1, "Wave 1 should start immediately")
		assert(director.get_current_wave_number() == 1, "Current wave number must be 1")
		assert(director.get_remaining_enemies_in_wave() == 3, "Wave 1 starts with 3 remaining enemies")
		
		# Tick spawn timer 3 times: because max_concurrent == 2, only 2 should spawn while 0 are killed!
		director._on_spawn_tick()
		director._on_spawn_tick()
		director._on_spawn_tick()
		assert(spawned_types.size() == 2, "WaveDirector must respect max_concurrent=2 cap")
		assert(director.enemies_alive_in_wave == 2, "2 enemies should be tracked as alive")
		
		# Kill 1 enemy -> frees slot for 3rd enemy in Wave 1
		director.notify_enemy_killed()
		assert(director.enemies_alive_in_wave == 1, "Alive count should drop to 1")
		assert(director.get_remaining_enemies_in_wave() == 2, "2 enemies remaining in Wave 1")
		
		director._on_spawn_tick()
		assert(spawned_types.size() == 3, "3rd enemy of Wave 1 should spawn after slot opened")
		
		# Kill remaining 2 enemies in Wave 1 -> completes Wave 1 and starts Wave 2 (intermission=0.0)
		director.notify_enemy_killed()
		director.notify_enemy_killed()
		assert(completed_waves.has(1), "Wave 1 should emit wave_completed")
		assert(started_waves.has(2), "Wave 2 should start after Wave 1 completes")
		assert(director.get_current_wave_number() == 2, "Current wave should now be 2")
		print("Wave 1 concurrency cap & transition to Wave 2: PASS")
		
		# Spawn and kill Wave 2's 2 enemies
		director._on_spawn_tick()
		director._on_spawn_tick()
		assert(spawned_types.size() == 5, "Total spawned across both waves should be 5")
		assert(spawned_types.has(3), "Wave 2 guaranteed_boss (Tank=3) must be spawned")
		
		director.notify_enemy_killed()
		director.notify_enemy_killed()
		assert(completed_waves.has(2), "Wave 2 should emit wave_completed")
		assert(all_done[0] == true, "all_waves_completed must emit after final wave is cleared")
		print("Wave 2 boss spawn & all_waves_completed signal: PASS")
		
		director.queue_free()
		print("ALL WAVE DIRECTOR TESTS PASSED!")
		get_tree().quit(0)
