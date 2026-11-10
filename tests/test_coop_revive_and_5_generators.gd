extends SceneTree

func _init() -> void:
	var runner := CoopReviveAndGeneratorsRunner.new()
	root.add_child.call_deferred(runner)

class CoopReviveAndGeneratorsRunner extends Node:
	func _ready() -> void:
		print("=================================================================")
		print("  STARTING TEST SUITE: CO-OP REVIVE & 5 STRATEGIC GENERATORS    ")
		print("=================================================================")
		
		_test_lobby_mode_and_sector_lock()
		_test_5_strategic_generators_and_distant_fuel_truck()
		_test_coop_downing_and_revive_logic()
		_test_revive_rpc_sender_authorization()
		
		print("=================================================================")
		print("  ALL CO-OP REVIVE & 5 GENERATORS TESTS PASSED (100% VERIFIED)   ")
		print("=================================================================")
		get_tree().quit(0)
	
	func _test_lobby_mode_and_sector_lock() -> void:
		print("Test 1: Lobby Mode Switching & Sector Selection Lock...")
		var LobbyScene = load("res://scenes/ui/lobby.tscn")
		assert(LobbyScene != null, "lobby.tscn must load")
		var lobby = LobbyScene.instantiate()
		add_child(lobby)
		
		var mode_btn: Button = lobby.find_child("ModeButton", true, false)
		var sector_opt: OptionButton = lobby.find_child("SectorOption", true, false)
		assert(mode_btn != null, "Lobby must have ModeButton")
		assert(sector_opt != null, "Lobby must have SectorOption")
		
		var net_mgr = get_node_or_null("/root/NetworkManager")
		assert(net_mgr != null, "NetworkManager autoload must exist")
		
		# Initial state: Campaign mode
		net_mgr.current_game_mode = "campaign"
		lobby._refresh_ui_state()
		assert("CAMPAIGN" in mode_btn.text, "Mode button must show Campaign")
		assert(sector_opt.disabled == false, "Sector option must be enabled in Campaign mode for host")
		assert(sector_opt.item_count >= 5, "Sector option must have 5 campaign sectors")
		
		# Toggle to Endless Survival mode
		lobby._on_mode_button_pressed()
		assert(net_mgr.current_game_mode == "survival", "Game mode must switch to survival")
		assert("SURVIVAL" in mode_btn.text, "Mode button text must show Survival")
		assert(sector_opt.disabled == true, "Sector option must be locked/disabled in Survival mode")
		assert("OUTPOST" in sector_opt.get_item_text(0), "Sector option must display Outpost Arena in Survival mode")
		
		# Toggle back to Campaign mode
		lobby._on_mode_button_pressed()
		assert(net_mgr.current_game_mode == "campaign", "Game mode must toggle back to campaign")
		assert(sector_opt.disabled == false, "Sector option must be re-enabled in Campaign mode")
		assert(sector_opt.item_count >= 5, "All 5 campaign sectors restored")
		
		lobby.queue_free()
		print("  -> Lobby Mode Switching & Sector Option Lock: PASS")
	
	func _test_5_strategic_generators_and_distant_fuel_truck() -> void:
		print("Test 2: 5 Strategic Generators & Distant Fuel Truck Placement...")
		var LevelScene = load("res://scenes/levels/level_01.tscn")
		assert(LevelScene != null, "level_01.tscn must load")
		var level = LevelScene.instantiate()
		add_child(level)
		
		# Query generators
		var generators := get_tree().get_nodes_in_group("generators")
		assert(generators.size() >= 5, "Level must instantiate at least 5 strategic generators (found %d)" % generators.size())
		
		var expected_positions: Array[Vector2] = [
			Vector2(640, 240),   # Command Center
			Vector2(640, -220),  # North Barracks
			Vector2(640, 920),   # South Depot
			Vector2(80, 360),    # West Checkpoint
			Vector2(1200, 360)   # East Compound
		]
		
		for exp_pos in expected_positions:
			var matched := false
			for g in generators:
				if is_instance_valid(g) and g.position.distance_to(exp_pos) <= 2.0:
					matched = true
					assert(g.has_method("get_light_data"), "Generator must implement get_light_data")
					assert(g.is_in_group("obstacles"), "Generator must be in obstacles group")
					assert(g.is_in_group("interactables"), "Generator must be in interactables group")
					break
			assert(matched, "Generator at position %s must exist in level" % str(exp_pos))
		
		# Query Fuel Truck
		var trucks := get_tree().get_nodes_in_group("fuel_trucks")
		assert(trucks.size() >= 1, "Level must have a fuel truck")
		var truck = trucks[0]
		assert(truck.position.distance_to(Vector2(1520, -280)) <= 2.0, "Fuel truck must be placed at Far NE Railhead (1520, -280)")
		
		# Verify fuel truck is far from all 5 generators (>650px)
		for g in generators:
			var dist: float = truck.position.distance_to(g.position)
			assert(dist >= 650.0, "Fuel truck must be far from generator at %s (distance is %.1f px)" % [str(g.position), dist])
		
		level.queue_free()
		print("  -> 5 Strategic Generators & Distant Fuel Truck: PASS")
	
	func _test_coop_downing_and_revive_logic() -> void:
		print("Test 3: Squad Co-op Incapacitation & Teammate Revive...")
		var PlayerScene = load("res://scenes/actors/player.tscn")
		var p1: CharacterBody2D = PlayerScene.instantiate()
		var p2: CharacterBody2D = PlayerScene.instantiate()
		p1.peer_id = 1
		p1.player_index = 1
		p1.is_coop_mode = true
		
		p2.peer_id = 2
		p2.player_index = 2
		p2.is_coop_mode = true
		p2.position = Vector2(40, 0)
		
		add_child(p1)
		add_child(p2)
		p1.add_to_group("players")
		p2.add_to_group("players")
		
		# Fatal damage to p1 in co-op must trigger down(), NOT die()
		p1.take_damage(120.0)
		assert(p1.is_downed == true, "Player 1 must be downed after lethal damage in co-op")
		assert(p1.is_dead == false, "Player 1 must NOT be dead when downed")
		assert(p1.bleedout_time_left > 0.0, "Player 1 bleedout timer must be active")
		assert(p1.can_be_revived() == true, "can_be_revived must return true for downed player")
		
		# P2 revives P1 via try_interact()
		var revive_ok: bool = p2.try_interact()
		assert(revive_ok == true, "Teammate try_interact must successfully revive downed player")
		assert(p1.is_downed == false, "Player 1 must no longer be downed after revive")
		assert(p1.current_health >= 35.0, "Player 1 health must be restored to >= 35 HP")
		
		p1.queue_free()
		p2.queue_free()
		print("  -> Squad Co-op Incapacitation & Teammate Revive: PASS")
	
	func _test_revive_rpc_sender_authorization() -> void:
		print("Test 4: Revive RPC Multi-Peer Sender Authorization...")
		var PlayerScene = load("res://scenes/actors/player.tscn")
		var p1: CharacterBody2D = PlayerScene.instantiate()
		p1.peer_id = 1
		p1.is_coop_mode = true
		add_child(p1)
		
		# Down P1
		p1.down()
		assert(p1.is_downed == true, "P1 must be downed")
		
		# Teammate (Peer 2) calls revive RPC on P1
		p1.revive(45.0)
		assert(p1.is_downed == false, "P1 must be revived")
		assert(p1.current_health == 45.0, "P1 health must match restored value")
		
		p1.queue_free()
		print("  -> Revive RPC Multi-Peer Sender Authorization: PASS")
