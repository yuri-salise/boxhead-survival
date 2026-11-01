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
		
		# 3b. Test Client Touch Controls Movement (Local Player on Mobile)
		var dummy_touch = Control.new()
		dummy_touch.set_script(load("res://scripts/touch_controls.gd"))
		p1.touch_controls = dummy_touch
		dummy_touch.move_vector = Vector2(1.0, 0.0)
		p1._physics_process(0.016)
		assert(p1.velocity.x > 0.0, "Local player must move right with touch stick input")
		dummy_touch.queue_free()
		print("Local Player Touch Controls Movement: PASS")
		
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
		
		# 4b. Test Downed & Revive Movement / Shooting Unlock
		p1.is_dead = false
		p1.down()
		assert(p1.is_downed == true, "p1 must be downed after down()")
		p1.revive(40.0)
		assert(p1.is_downed == false, "p1 must be revived after revive()")
		assert(p1.current_health == 40.0, "p1 health must be restored after revive")
		p1.override_move_vec = Vector2(1.0, 0.0)
		p1.input_override_enabled = true
		p1._physics_process(0.016)
		assert(p1.velocity.x > 0.0, "Revived player must be able to move immediately")
		p1.input_override_enabled = false
		print("Squadmate Revive & Control Unlock: PASS")
		
		# 5. Test Host-Authoritative Zombie Spawning & Client Replication
		var hz = level.spawn_test_zombie_at(Vector2(500, 300), 0)
		assert(hz != null, "Host must be able to spawn zombie")
		assert(hz.has_meta("net_id"), "Spawned zombie must have net_id metadata")
		var host_z_id: int = int(hz.get_meta("net_id"))
		assert(level.zombie_container.has_node("Z_" + str(host_z_id)), "Zombie node name must be Z_<id>")
		
		# Test Client Receiving Spawn RPC
		level.rpc_spawn_zombie(999, 1, Vector2(600, 400))
		assert(level.zombie_container.has_node("Z_999"), "Client must spawn Z_999 from rpc_spawn_zombie")
		var rz = level.zombie_container.get_node("Z_999")
		assert(rz.get("is_network_puppet") == true, "Client zombie must be flagged as network puppet")
		
		# Test Realtime State Sync RPC
		level.rpc_sync_zombies([[999, 615, 420, 1.25, 30.0, 1]])
		assert(rz.get("target_sync_pos") == Vector2(615, 420), "Zombie sync pos must update")
		assert(rz.get("current_health") == 30.0, "Zombie sync health must update")
		
		# Test Zombie Death RPC
		level.rpc_zombie_died(999, 12, 180)
		assert(rz.get("is_dead") == true, "Zombie must trigger die() on rpc_zombie_died")
		assert(level.kills_count == 12, "Client kills count must sync from host")
		assert(level.score_count == 180, "Client score count must sync from host")
		print("Host-Authoritative Zombie Realtime Replication: PASS")
		
		# 6. Test Peer Disconnection Cleanup Broadcast
		var dummy_p3 = player_scene.instantiate()
		dummy_p3.peer_id = 3
		level.squad_peers[3] = dummy_p3
		level.rpc_remove_squad_peer(3)
		assert(not level.squad_peers.has(3), "Disconnected peer 3 must be cleaned up from squad_peers")
		print("Squad Peer Disconnect Broadcast Cleanup: PASS")
		
		# 7. Clean up nodes
		level.queue_free()
		p1.queue_free()
		p2.queue_free()
		
		print("ALL MULTIPLAYER GAMEPLAY TESTS PASSED!")
		get_tree().quit(0)
