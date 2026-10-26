extends SceneTree

func _init():
	var runner = MultiplayerGameplayTestRunner.new()
	root.add_child.call_deferred(runner)

class MultiplayerGameplayTestRunner extends Node:
	func _ready():
		print("Starting Task 15: Multiplayer Co-op Gameplay, Replication & Authority Tests...")
		
		var PlayerScript = load("res://scripts/player.gd")
		var player_scene = load("res://scenes/actors/player.tscn")
		assert(player_scene != null, "Player scene must load")
		
		# 1. Test Player Co-op identity and Camera allocation
		var p1 = player_scene.instantiate()
		p1.peer_id = 1
		p1.player_index = 1
		p1.is_coop_mode = true
		add_child(p1)
		
		var p2 = player_scene.instantiate()
		p2.peer_id = 2
		p2.player_index = 2
		p2.is_coop_mode = true
		add_child(p2)
		
		assert(p1.is_local_player() == true, "Host (peer 1) should be local player by default")
		assert(p1.player_camera != null and p1.player_camera.enabled == true, "P1 camera should be enabled for local player")
		assert(p2.player_camera != null and p2.player_camera.enabled == false, "P2 camera should be disabled for remote peer on host")
		print("Player Co-op Identity & Camera Separation: PASS")
		
		# 2. Test Client Input Transmission to Host
		# Simulate receiving client input RPC on Host
		p2.sync_input_to_host(Vector2(1.0, 0.0), Vector2(700, 360), true)
		assert(p2.input_override_enabled == true, "sync_input_to_host must activate input_override_enabled")
		assert(p2.override_move_vec == Vector2(1.0, 0.0), "override_move_vec must match client input")
		assert(p2.override_is_shooting == true, "override_is_shooting must match client shooting flag")
		print("Client Input Transmission to Host: PASS")
		
		# 3. Test Host Authoritative State Sync to Client
		# Simulate P2 receiving host state broadcast
		p2.sync_state_to_peers(Vector2(650, 360), 0.75, Vector2(140, 0), 85.0, 50.0, "SHOTGUN")
		assert(p2.global_position == Vector2(650, 360), "P2 position must update to host authoritative position")
		assert(p2.current_health == 85.0, "P2 health must sync from host")
		assert(p2.current_armor == 50.0, "P2 armor must sync from host")
		assert(p2.weapon_controller.current_weapon_id == "SHOTGUN", "P2 weapon must sync from host")
		print("Host Authoritative State Replication: PASS")
		
		# 4. Test Two-Player Survival Loop: P1 death does NOT trigger defeat if P2 is alive
		var lvl_scene = load("res://scenes/levels/level_01.tscn")
		var level = lvl_scene.instantiate()
		add_child(level)
		
		# Attach both players to level
		level.player2 = p2
		assert(level._check_all_players_dead() == false, "Match must not be lost if both are alive")
		
		# Kill Player 1
		level.player.is_dead = true
		assert(level._check_all_players_dead() == false, "Match must NOT be lost if Player 2 is still alive!")
		print("Two-Player Incapacitation / Survival Fallback: PASS")
		
		# Kill Player 2 as well -> Now match is lost
		p2.is_dead = true
		assert(level._check_all_players_dead() == true, "Match must be lost when BOTH players are dead")
		print("All Players Dead Resolution: PASS")
		
		# 5. Clean up nodes
		level.queue_free()
		p1.queue_free()
		p2.queue_free()
		
		print("ALL MULTIPLAYER GAMEPLAY TESTS PASSED!")
		get_tree().quit(0)
