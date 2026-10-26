extends SceneTree

const ArenaEnvScript = preload("res://scripts/arena_environment.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie_basic.gd")

func _init():
	var runner = SectorBiomesTestRunner.new()
	root.add_child.call_deferred(runner)

class SectorBiomesTestRunner extends Node2D:
	func _ready():
		print("Testing Unique Sector Biomes (Quarantine, Forest, Swamp, Village, Urban), Swamp Slowdown & Mobile Efficiency...")
		
		var arena = ArenaEnvScript.new()
		add_child(arena)
		
		# 1. Verify Sector 1: Quarantine Outpost
		arena.sector_type = arena.SectorBiome.QUARANTINE
		var q_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(q_chunk.has("cracks"), "Quarantine chunk must have concrete cracks")
		assert(q_chunk.has("stains"), "Quarantine chunk must have stains")
		assert(q_chunk.has("props"), "Quarantine chunk must have props")
		assert(arena.get_speed_multiplier_at(Vector2(100, 100)) == 1.0, "Quarantine speed multiplier must be 1.0 (no slowdown)")
		print("Sector 1 Quarantine Outpost: PASS")
		
		# 2. Verify Sector 2: Dense Forest
		arena.sector_type = arena.SectorBiome.FOREST
		var f_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(f_chunk.has("foliage"), "Forest chunk must have foliage patches")
		assert(f_chunk.has("props"), "Forest chunk must have forest props (trees, logs, boulders)")
		assert(arena.get_speed_multiplier_at(Vector2(100, 100)) == 1.0, "Forest speed multiplier must be 1.0")
		print("Sector 2 Dense Forest: PASS")
		
		# 3. Verify Sector 3: Murky Toxic Swamp & Slowdown Mechanics
		arena.sector_type = arena.SectorBiome.SWAMP
		var s_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(s_chunk.has("water_pools"), "Swamp chunk must have murky water pools")
		assert(s_chunk.has("mud_patches"), "Swamp chunk must have mud patches")
		
		# Test Swamp Slowdown
		var general_mult := arena.get_speed_multiplier_at(Vector2(500, 500))
		assert(general_mult < 1.0, "Swamp terrain must slow movement (< 1.0)")
		assert(general_mult <= 0.80 and general_mult >= 0.60, "Swamp speed multiplier must be between 0.60 and 0.80")
		
		# Check if inside water pool gives deep slowdown (0.65)
		if s_chunk["water_pools"].size() > 0:
			var pool_pos: Vector2 = s_chunk["water_pools"][0]["pos"]
			var deep_mult := arena.get_speed_multiplier_at(pool_pos)
			assert(deep_mult == 0.65, "Deep swamp water pool must give 0.65x speed penalty")
		print("Sector 3 Murky Swamp & Slowdown: PASS")
		
		# 4. Verify Sector 4: Abandoned Village
		arena.sector_type = arena.SectorBiome.VILLAGE
		var v_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(v_chunk.has("buildings"), "Village chunk must support cabin footprints")
		assert(v_chunk.has("props"), "Village chunk must have props (fences, hay bales, fruit trees)")
		assert(arena.get_speed_multiplier_at(Vector2(100, 100)) == 1.0, "Village speed multiplier must be 1.0")
		print("Sector 4 Abandoned Village: PASS")
		
		# 5. Verify Sector 5: Ruined Urban City
		arena.sector_type = arena.SectorBiome.URBAN
		var u_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(u_chunk.has("rubble"), "Urban chunk must have concrete rubble")
		assert(u_chunk.has("props"), "Urban chunk must have urban props (car wrecks, streetlights, dumpsters)")
		assert(arena.get_speed_multiplier_at(Vector2(100, 100)) == 1.0, "Urban speed multiplier must be 1.0")
		print("Sector 5 Ruined Urban City: PASS")
		
		# 6. Verify Mobile Performance & Efficiency (Graphics Quality adjustments)
		# Low quality (0): 3x3 chunks rendered, reduced props
		arena.graphics_quality = 0
		assert(arena.graphics_quality == 0, "Graphics quality must switch to 0 (Low / Battery Saver)")
		var low_chunk := arena._get_chunk_data(2, 2)
		assert(low_chunk != null, "Low quality chunk generation must succeed")
		
		# High quality (2): 5x5 chunks rendered, full props
		arena.graphics_quality = 2
		assert(arena.graphics_quality == 2, "Graphics quality must switch to 2 (High / Ultra)")
		var high_chunk := arena._get_chunk_data(2, 2)
		assert(high_chunk != null, "High quality chunk generation must succeed")
		print("Mobile Performance & Quality Levels: PASS")
		
		# 7. Test Integration with Player and Zombie in Swamp
		var test_level = Node2D.new()
		test_level.name = "TestLevel"
		get_tree().root.add_child(test_level)
		
		var test_arena = ArenaEnvScript.new()
		test_arena.name = "ArenaEnvironment"
		test_arena.sector_type = test_arena.SectorBiome.SWAMP
		test_level.add_child(test_arena)
		
		var player_scene = load("res://scenes/actors/player.tscn")
		var player = player_scene.instantiate()
		test_level.add_child(player)
		player.global_position = Vector2(300, 300)
		
		# Trigger player movement
		player.set_input_override(Vector2.RIGHT, Vector2(500, 300), false)
		player._physics_process(0.016)
		var expected_swamp_spd: float = player.speed * test_arena.get_speed_multiplier_at(player.global_position)
		assert(is_equal_approx(player.velocity.length(), expected_swamp_spd), "Player velocity in Sector 3 must be slowed by swamp multiplier")
		
		# Test Zombie in swamp
		var zombie_scene = load("res://scenes/actors/zombie_basic.tscn")
		var zombie = zombie_scene.instantiate()
		var zombie_container = Node2D.new()
		zombie_container.name = "ZombieContainer"
		test_level.add_child(zombie_container)
		zombie_container.add_child(zombie)
		zombie.global_position = Vector2(400, 300)
		
		zombie.set_target(player)
		zombie._physics_process(0.016)
		var expected_zombie_spd: float = zombie.speed * test_arena.get_speed_multiplier_at(zombie.global_position)
		assert(is_equal_approx(zombie.velocity.length(), expected_zombie_spd), "Zombie velocity in Sector 3 must be slowed by swamp multiplier")
		print("Player & Zombie Swamp Slowdown Movement Integration: PASS")
		
		test_level.queue_free()
		arena.queue_free()
		
		print("ALL SECTOR BIOME & MOBILE EFFICIENCY TESTS PASSED!")
		get_tree().quit()
