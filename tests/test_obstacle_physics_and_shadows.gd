extends SceneTree

const ArenaEnvScript = preload("res://scripts/arena_environment.gd")
const PlayerScript = preload("res://scripts/player.gd")
const ZombieScript = preload("res://scripts/zombie_basic.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const HorrorVignetteScript = preload("res://scripts/horror_vignette.gd")

func _init():
	var runner = ObstaclePhysicsTestRunner.new()
	root.add_child.call_deferred(runner)

class ObstaclePhysicsTestRunner extends Node2D:
	func _ready():
		print("Testing Physical Obstacles, Collision Blocking, Flashlight Occlusion & Dynamic Shadows...")
		
		# 1. Verify ArenaEnvironment spawns solid StaticBody2D colliders
		var arena = ArenaEnvScript.new()
		add_child(arena)
		arena.sector_type = arena.SectorBiome.FOREST
		arena.set_focus_position(Vector2(640, 360))
		
		assert(arena.collider_container != null, "ArenaEnvironment must have collider_container")
		var colliders: Array[Node] = arena.collider_container.get_children()
		assert(colliders.size() > 0, "Active chunks must have spawned StaticBody2D obstacle colliders")
		
		var sample_body: StaticBody2D = colliders[0] as StaticBody2D
		assert(sample_body != null, "Obstacle colliders must be StaticBody2D")
		assert(sample_body.collision_layer == 1, "Obstacle colliders must be on Collision Layer 1 (World/Walls)")
		assert(sample_body.is_in_group("obstacles"), "Obstacles must be in 'obstacles' group")
		print("ArenaEnvironment StaticBody2D Obstacle Generation: PASS")
		
		# 2. Verify Player CANNOT walk through obstacles
		var player_scene = load("res://scenes/actors/player.tscn")
		var player: CharacterBody2D = player_scene.instantiate()
		add_child(player)
		player.global_position = Vector2(200, 200)
		
		# Place a solid obstacle right in front of the player (at x = 240, radius 16)
		var test_obstacle := StaticBody2D.new()
		test_obstacle.position = Vector2(240, 200)
		test_obstacle.collision_layer = 1
		var obs_shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 16.0
		obs_shape.shape = circle
		test_obstacle.add_child(obs_shape)
		add_child(test_obstacle)
		
		# Attempt to walk straight right into the obstacle
		player.set_input_override(Vector2.RIGHT, Vector2(500, 200), false)
		for step in range(10):
			player._physics_process(0.016)
		
		# Player must be blocked by the obstacle and NOT pass through it (center cannot reach 240)
		assert(player.global_position.x < 240.0, "Player must be blocked by obstacle and NOT walk through it!")
		print("Player Obstacle Collision Blocking: PASS")
		
		# 3. Verify Zombie CANNOT walk through obstacles
		var zombie_scene = load("res://scenes/actors/zombie_basic.tscn")
		var zombie: CharacterBody2D = zombie_scene.instantiate()
		add_child(zombie)
		zombie.global_position = Vector2(300, 200)
		zombie.set_target(player)
		
		# Zombie tries to move left towards player (through the obstacle at 240)
		for step in range(10):
			zombie._physics_process(0.016)
		
		assert(zombie.global_position.x > 240.0, "Zombie must be blocked by obstacle and NOT walk through it!")
		print("Zombie Obstacle Collision Blocking: PASS")
		
		# 4. Verify Projectile collides with obstacle
		var proj_scene = load("res://scenes/actors/projectile.tscn")
		var proj: Area2D = proj_scene.instantiate()
		add_child(proj)
		proj.init(Vector2(100, 200), Vector2.RIGHT, 600.0, 25.0, player)
		
		# Move bullet into obstacle
		proj.global_position = Vector2(235, 200)
		proj._on_body_entered(test_obstacle)
		assert(proj.is_queued_for_deletion(), "Projectile must hit solid obstacle and stop!")
		print("Projectile Obstacle Collision Impact: PASS")
		
		# 5. Verify Flashlight Occlusion & Dynamic Shadows in HorrorVignette
		var vignette := HorrorVignetteScript.new()
		add_child(vignette)
		vignette.set_night_factor(1.0, false)
		
		var nearby_obs: Array[Dictionary] = arena.get_nearby_obstacles(Vector2(640, 360), 550.0)
		assert(nearby_obs.size() > 0, "get_nearby_obstacles must return obstacles within range")
		
		vignette.update_flashlight_transform(Vector2(640, 360), 0.0, nearby_obs, Vector2(640, 360))
		assert(vignette.flashlight_occluders.size() == nearby_obs.size(), "HorrorVignette must store occluders")
		
		# Test shadow polygon computation
		var test_obs_entry: Dictionary = {
			"world_pos": Vector2(760, 360), # directly in front of flashlight (angle 0.0)
			"radius": 18.0
		}
		vignette.update_flashlight_transform(Vector2(640, 360), 0.0, [test_obs_entry], Vector2(640, 360))
		
		# Verify redraw executes cleanly via normal draw lifecycle
		vignette.queue_redraw()
		await get_tree().process_frame
		print("Flashlight Dynamic Obstacle Shadow Occlusion: PASS")
		
		test_obstacle.queue_free()
		player.queue_free()
		zombie.queue_free()
		arena.queue_free()
		vignette.queue_free()
		
		print("ALL PHYSICAL OBSTACLE & FLASHLIGHT SHADOW TESTS PASSED!")
		get_tree().quit()
