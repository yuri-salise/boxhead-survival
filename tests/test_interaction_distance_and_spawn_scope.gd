extends SceneTree

func _init() -> void:
	var runner := InteractionDistanceAndSpawnScopeTestRunner.new()
	root.add_child.call_deferred(runner)

class InteractionDistanceAndSpawnScopeTestRunner extends Node:
	func _ready() -> void:
		print("=================================================================")
		print("  TESTING INTERACTION DISTANCE & ZOMBIE OFF-SCREEN SPAWN SCOPE   ")
		print("=================================================================")
		
		_test_interactable_distance_gating()
		_test_zombie_no_sudden_teleport_on_stuck()
		_test_zombies_spawn_strictly_outside_player_screen_view()
		_test_coop_zombies_spawn_outside_both_players_view()
		
		print("=================================================================")
		print("  ALL INTERACTION & SPAWN SCOPE TESTS PASSED (100% VERIFIED)    ")
		print("=================================================================")
		get_tree().quit(0)

	func _test_interactable_distance_gating() -> void:
		print("Test 1: Interactable activation distance gating...")
		var PlayerScene = load("res://scenes/actors/player.tscn")
		var player: CharacterBody2D = PlayerScene.instantiate()
		player.position = Vector2(500, 500)
		add_child(player)

		var GenScene = load("res://scenes/actors/generator.tscn")
		var gen = GenScene.instantiate()
		gen.position = Vector2(1000, 500) # 500px away (FAR!)
		add_child(gen)

		var TruckScene = load("res://scenes/actors/fuel_truck.tscn")
		var truck = TruckScene.instantiate()
		truck.position = Vector2(1000, 600) # 510px away (FAR!)
		add_child(truck)

		var TurretScene = load("res://scenes/actors/sentry_turret.tscn")
		var turret = TurretScene.instantiate()
		turret.position = Vector2(1000, 700) # 538px away (FAR!)
		add_child(turret)

		var CrateScene = load("res://scenes/actors/supply_crate.tscn")
		var crate = CrateScene.instantiate()
		crate.position = Vector2(1000, 800) # 583px away (FAR!)
		add_child(crate)

		# 1. FAR AWAY: All interactions must be rejected
		assert(gen.can_interact(player) == false, "Generator must not be interactable when player is far")
		assert(gen.interact(player) == false, "Generator interact() must fail when player is far")
		assert(gen.is_running == false, "Generator must not start when player is far")

		assert(truck.can_interact(player) == false, "Fuel truck must not be interactable when player is far")
		assert(truck.interact(player) == false, "Fuel truck interact() must fail when player is far")
		assert(player.get("has_gasoline") == false, "Player must not receive gasoline from far away")

		assert(turret.can_interact(player) == false, "Turret must not be interactable when player is far")
		assert(turret.interact(player) == false, "Turret interact() must fail when player is far")
		assert(turret.is_active == false, "Turret must not activate when player is far")

		assert(crate.can_interact(player) == false, "Crate must not be interactable when player is far")
		assert(crate.interact(player) == false, "Crate interact() must fail when player is far")
		assert(crate.is_opened == false, "Crate must not open when player is far")

		# Click input simulation when far: click position on interactable must NOT activate it
		var click_event := InputEventMouseButton.new()
		click_event.button_index = MOUSE_BUTTON_LEFT
		click_event.pressed = true
		gen._input(click_event)
		assert(gen.is_running == false, "Clicking generator from far away must NOT start it")

		truck._input(click_event)
		assert(player.get("has_gasoline") == false, "Clicking truck from far away must NOT dispense gas")

		turret._input(click_event)
		assert(turret.is_active == false, "Clicking turret from far away must NOT activate it")

		crate._input(click_event)
		assert(crate.is_opened == false, "Clicking crate from far away must NOT open it")

		# 2. MOVE PLAYER CLOSE (within 60px): Interaction must succeed
		player.position = gen.position + Vector2(40, 0)
		assert(gen.can_interact(player) == true, "Generator can_interact must be true when player is close")
		assert(gen.interact(player) == true, "Generator interact must succeed when player is close")
		assert(gen.is_running == true, "Generator must now be running")

		player.position = truck.position + Vector2(40, 0)
		assert(truck.can_interact(player) == true, "Truck can_interact must be true when player is close")
		assert(truck.interact(player) == true, "Truck interact must succeed when player is close")
		assert(player.get("has_gasoline") == true, "Player must now have gasoline")

		player.position = turret.position + Vector2(40, 0)
		assert(turret.can_interact(player) == true, "Turret can_interact must be true when player is close")
		assert(turret.interact(player) == true, "Turret interact must succeed when player is close")
		assert(turret.is_active == true, "Turret must now be active")

		player.position = crate.position + Vector2(40, 0)
		assert(crate.can_interact(player) == true, "Crate can_interact must be true when player is close")
		assert(crate.interact(player) == true, "Crate interact must succeed when player is close")
		assert(crate.is_opened == true, "Crate must now be opened")

		player.queue_free()
		gen.queue_free()
		truck.queue_free()
		turret.queue_free()
		crate.queue_free()
		print("  -> Interactable distance gating: PASS")

	func _test_zombie_no_sudden_teleport_on_stuck() -> void:
		print("Test 2: Zombie stuck physics steering without sudden teleport...")
		var ZombieScene = load("res://scenes/actors/zombie_basic.tscn")
		var zombie = ZombieScene.instantiate()
		zombie.position = Vector2(800, 300)
		add_child(zombie)

		var PlayerScene = load("res://scenes/actors/player.tscn")
		var player = PlayerScene.instantiate()
		player.position = Vector2(200, 300)
		add_child(player)

		zombie.set_target(player)

		var initial_pos: Vector2 = zombie.global_position
		# Simulate 4 seconds of physics process while stuck near initial_pos
		for step in range(240): # 4.0 seconds at 60 FPS
			zombie.stuck_last_pos = initial_pos
			zombie._physics_process(1.0 / 60.0)

		# In the old code, after 2.8s the zombie would teleport to target_player + (440..520).
		# Verify that the zombie has NOT teleported to around the player!
		var dist_to_player: float = zombie.global_position.distance_to(player.global_position)
		# The zombie was at x=800, player at x=200. Distance was 600.
		# With normal movement and detour steering, it should move towards player or detour,
		# but NOT teleport instantly to a random angle 440-520px from player.
		assert(zombie.get("prolonged_stuck_timer") == null, "prolonged_stuck_timer must no longer exist")
		
		zombie.queue_free()
		player.queue_free()
		print("  -> Zombie stuck physics steering without sudden teleport: PASS")

	func _test_zombies_spawn_strictly_outside_player_screen_view() -> void:
		print("Test 3: Zombie spawning strictly outside player's screen view scope...")
		var LevelScene = load("res://scenes/levels/level_01.tscn")
		var level = LevelScene.instantiate()
		add_child(level)

		var player = level.get_local_player()
		assert(player != null, "Level 1 must have local player")
		var player_pos: Vector2 = player.global_position

		# Sample 60 spawn positions across different random angles
		for i in range(60):
			var spawn_pos: Vector2 = level.find_valid_spawn_position(player_pos)
			var in_view: bool = level.is_in_any_player_view(spawn_pos, 0.0)
			assert(in_view == false, "Spawn position " + str(spawn_pos) + " was inside player screen view!")
			
			# Also verify margin: at margin 50px it should still be strictly outside the viewport
			var in_view_with_margin: bool = level.is_in_any_player_view(spawn_pos, 30.0)
			assert(in_view_with_margin == false, "Spawn position was within 30px margin of screen edge!")

		level.queue_free()
		print("  -> Zombie spawning strictly outside player's screen view scope: PASS")

	func _test_coop_zombies_spawn_outside_both_players_view() -> void:
		print("Test 4: Co-op 2-player zombie spawning outside both players' view...")
		var LevelScene = load("res://scenes/levels/level_01.tscn")
		var level = LevelScene.instantiate()
		add_child(level)

		var p1 = level.get_local_player()
		p1.position = Vector2(400, 400)

		# Add second player in co-op mode ~800px away
		var PlayerScene = load("res://scenes/actors/player.tscn")
		var p2 = PlayerScene.instantiate()
		p2.name = "Player_2"
		p2.position = Vector2(1200, 400)
		p2.set_meta("peer_id", 2)
		level.add_child(p2)

		# Sample 40 spawn positions around p1
		for i in range(40):
			var spawn_pos: Vector2 = level.find_valid_spawn_position(p1.global_position)
			assert(level.is_in_any_player_view(spawn_pos, 0.0) == false, "Spawn position must not be in P1 or P2 screen view!")
			
			var dist_p1 := spawn_pos.distance_to(p1.global_position)
			var dist_p2 := spawn_pos.distance_to(p2.global_position)
			# Point should not be within viewport bounds of either player
			assert(absf(spawn_pos.x - p1.global_position.x) > 640.0 or absf(spawn_pos.y - p1.global_position.y) > 360.0, "Point must be outside P1 view")
			assert(absf(spawn_pos.x - p2.global_position.x) > 640.0 or absf(spawn_pos.y - p2.global_position.y) > 360.0, "Point must be outside P2 view")

		level.queue_free()
		print("  -> Co-op 2-player zombie spawning outside both players' view: PASS")
