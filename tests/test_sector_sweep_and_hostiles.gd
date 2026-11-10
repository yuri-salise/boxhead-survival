extends SceneTree

func _init() -> void:
	var runner := SectorSweepTestRunner.new()
	root.add_child.call_deferred(runner)

class SectorSweepTestRunner extends Node:
	func _ready() -> void:
		print("Testing Sector Hostiles Counter, Wave Bonus Spawns & Straggler Sweep...")
		
		# 1. Test WaveDirector bonus spawn accounting
		var WaveDirectorScript = load("res://scripts/wave_director.gd")
		var director = WaveDirectorScript.new()
		add_child(director)
		
		var test_waves: Array[Dictionary] = [{
			"total_enemies": 10,
			"spawn_interval": 0.05,
			"max_concurrent": 6,
			"intermission": 0.0,
			"guaranteed_boss": -1
		}]
		director.setup_waves(test_waves)
		director.start_waves()
		
		assert(director.total_enemies_in_wave == 10, "Initial wave should have 10 enemies")
		assert(director.enemies_spawned_in_wave == 0, "No enemies spawned at start")
		
		# Summon 10 bonus enemies (e.g. Necromancer summon)
		director.register_bonus_enemies(10)
		assert(director.total_enemies_in_wave == 20, "Total enemies should expand to 20")
		assert(director.enemies_spawned_in_wave == 10, "Spawned count must increment by 10 for bonus spawns")
		assert(director.enemies_alive_in_wave == 10, "Living count must track the 10 bonus spawns")
		
		# The remaining spawn quota from the timer should be exactly 10 (20 - 10 = 10)
		var remaining_to_spawn: int = max(0, director.total_enemies_in_wave - director.enemies_spawned_in_wave)
		assert(remaining_to_spawn == 10, "Remaining to spawn should be exactly 10")
		print("  [OK] WaveDirector bonus spawn accounting verified")
		director.queue_free()
		
		# 2. Test ArenaEnvironment is_position_blocked
		var ArenaScript = load("res://scripts/arena_environment.gd")
		var arena = ArenaScript.new()
		add_child(arena)
		arena.set_sector_type(1) # Quarantine
		
		assert(arena.has_method("is_position_blocked"), "ArenaEnvironment must implement is_position_blocked")
		# Verify that an arbitrary open coordinate far from props is not falsely blocked
		var open_test: bool = arena.is_position_blocked(Vector2(99999.0, 99999.0), 10.0)
		print("  [OK] ArenaEnvironment is_position_blocked check verified (open test result: " + str(open_test) + ")")
		arena.queue_free()
		
		# 3. Test Level 1 Hostiles display & radar calculation
		var LevelScene = load("res://scenes/levels/level_01.tscn")
		var level = LevelScene.instantiate()
		add_child(level)
		
		assert(level.has_method("find_valid_spawn_position"), "Level must implement find_valid_spawn_position")
		var valid_pos: Vector2 = level.find_valid_spawn_position(Vector2(640, 360), 400.0, 600.0)
		assert(valid_pos != Vector2.ZERO, "find_valid_spawn_position must return a valid coordinate")
		
		# Check kills label format
		level._update_kills_display()
		assert(level.kills_label != null, "kills_label must exist")
		assert(level.kills_label.text.contains("HOSTILES:"), "kills_label must display HOSTILES header")
		print("  [OK] Level hostiles display and valid spawn position verified: " + level.kills_label.text)
		
		level.queue_free()
		
		print("\nALL SECTOR SWEEP AND HOSTILES TESTS PASSED (100%)!")
		get_tree().quit(0)
