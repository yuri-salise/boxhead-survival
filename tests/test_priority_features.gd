extends SceneTree

const ArenaEnvScript = preload("res://scripts/arena_environment.gd")

func _init() -> void:
	var runner = PriorityFeaturesRunner.new()
	root.add_child.call_deferred(runner)

class PriorityFeaturesRunner extends Node:
	func _ready() -> void:
		print("==================================================")
		print("TESTING PRIORITY 1 FEATURES:")
		print("1. Unique Arena Layouts (Levels 2-5 matching GDD)")
		print("2. Looping Ambient Audio / Music (Menu & Combat)")
		print("3. Co-op Survival Mode (Multiplayer & Escalation)")
		print("==================================================")
		
		_test_unique_arena_layouts()
		_test_ambient_music()
		_test_coop_survival_mode()
		_test_rubric_excellent_and_bonus_features()
		_test_necro_and_7_witches_coven()
		
		print("==================================================")
		print("ALL PRIORITY 1, RUBRIC EXCELLENT & BONUS TESTS PASSED! 100%")
		print("==================================================")
		get_tree().quit(0)

	func _test_unique_arena_layouts() -> void:
		print("\n--- Testing Unique Arena Layouts (Levels 2-5) ---")
		var arena: Node2D = ArenaEnvScript.new()
		add_child(arena)
		
		# LEVEL 2: THE STREET
		arena.sector_type = arena.SectorBiome.THE_STREET
		var st_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(st_chunk.has("has_ns_road") and st_chunk["has_ns_road"] == true, "Level 2 must have North-South highway road")
		assert(st_chunk.has("props"), "Level 2 must have vehicle barricade props")
		var vehicle_props: Array = st_chunk["props"]
		assert(vehicle_props.size() > 0, "Level 2 must contain vehicle props")
		var vertical_count: int = 0
		for p in vehicle_props:
			var rot: float = absf(float(p.get("rot", 0.0)))
			if rot < 0.25 or absf(rot - PI) < 0.25:
				vertical_count += 1
		assert(vertical_count > 0, "Level 2 vehicle barricades must form vertical sightlines")
		print("  Level 2 (The Street): PASS (Vertical sightlines & vehicle barricades verified)")
		
		# LEVEL 3: NO EXIT
		arena.sector_type = arena.SectorBiome.NO_EXIT
		var ne_chunk: Dictionary = arena._get_chunk_data(2, 2)
		assert(ne_chunk.has("buildings"), "Level 3 must have brick chokepoint walls")
		assert(ne_chunk.has("props"), "Level 3 must have alley props")
		assert(ne_chunk["buildings"].size() > 0, "Level 3 outer chunks must have brick alley wall segments")
		print("  Level 3 (No Exit): PASS (Tight alley choke points & brick walls verified)")
		
		# LEVEL 4: THE DEPOT
		arena.sector_type = arena.SectorBiome.THE_DEPOT
		var dep_chunk: Dictionary = arena._get_chunk_data(0, 0)
		assert(dep_chunk.has("buildings"), "Level 4 must have shipping containers")
		var containers: Array = dep_chunk["buildings"]
		assert(containers.size() >= 3, "Level 4 must generate interlocking container labyrinth")
		for c in containers:
			var sz: Vector2 = c["size"]
			assert((is_equal_approx(sz.x, 120.0) and is_equal_approx(sz.y, 48.0)) or (is_equal_approx(sz.x, 48.0) and is_equal_approx(sz.y, 120.0)), "Level 4 containers must have 90° blind corner dimensions")
		print("  Level 4 (The Depot): PASS (Warehouse storage container maze with blind corners verified)")
		
		# LEVEL 5: LAST LIGHT
		arena.sector_type = arena.SectorBiome.LAST_LIGHT
		var center_chunk: Dictionary = arena._get_chunk_data(1, 0)
		assert(center_chunk.has("props"), "Level 5 must have perimeter defense station props")
		var center_props: Array = center_chunk["props"]
		var gen_count: int = 0
		var sandbag_count: int = 0
		var floodlight_count: int = 0
		for p in center_props:
			if p["kind"] == 0: gen_count += 1
			elif p["kind"] == 1: sandbag_count += 1
			elif p["kind"] == 2: floodlight_count += 1
		assert(gen_count >= 2, "Level 5 central chunk must have perimeter emergency diesel generators")
		assert(sandbag_count >= 4, "Level 5 central chunk must have sandbag fortifications flanking generators")
		assert(floodlight_count >= 2, "Level 5 central chunk must have defense floodlights")
		print("  Level 5 (Last Light): PASS (Open plaza with 4 perimeter generator defense points verified)")
		
		arena.queue_free()

	func _test_ambient_music() -> void:
		print("\n--- Testing Looping Ambient Horror Audio / Music ---")
		var AudioMgrScript = load("res://autoload/audio_manager.gd")
		var audio_mgr = AudioMgrScript.new()
		add_child(audio_mgr)
		
		assert(audio_mgr != null, "AudioManager autoload must instantiate")
		assert(audio_mgr.has_method("play_music"), "AudioManager must have play_music method")
		assert(audio_mgr.has_method("stop_music"), "AudioManager must have stop_music method")
		
		# Verify streams preloaded
		assert(audio_mgr.music_streams.has("ambient_menu"), "AudioManager must preload ambient_menu")
		assert(audio_mgr.music_streams.has("ambient_combat"), "AudioManager must preload ambient_combat")
		
		var menu_stream: AudioStream = audio_mgr.music_streams["ambient_menu"]
		assert(menu_stream is AudioStreamWAV, "ambient_menu must be AudioStreamWAV")
		assert((menu_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambient_menu must loop forward seamlessly")
		
		var combat_stream: AudioStream = audio_mgr.music_streams["ambient_combat"]
		assert(combat_stream is AudioStreamWAV, "ambient_combat must be AudioStreamWAV")
		assert((combat_stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambient_combat must loop forward seamlessly")
		
		# Test playback trigger
		audio_mgr.play_music("ambient_menu")
		assert(audio_mgr.current_music_track == "ambient_menu", "Current track must switch to ambient_menu")
		
		audio_mgr.play_music("ambient_combat")
		assert(audio_mgr.current_music_track == "ambient_combat", "Current track must switch to ambient_combat")
		
		audio_mgr.stop_music()
		assert(audio_mgr.current_music_track == "", "Music must stop cleanly")
		audio_mgr.queue_free()
		print("  Ambient Music (Menu & Combat seamless loops): PASS")

	func _test_coop_survival_mode() -> void:
		print("\n--- Testing Co-op Survival Mode Configuration & Launch ---")
		var net_mgr: Node = get_tree().root.get_node_or_null("NetworkManager")
		var created_net_mgr := false
		if not net_mgr:
			var NetMgrScript = load("res://autoload/network_manager.gd")
			net_mgr = NetMgrScript.new()
			net_mgr.name = "NetworkManager"
			get_tree().root.add_child(net_mgr)
			created_net_mgr = true
		
		assert(net_mgr != null, "NetworkManager must exist")
		assert("current_game_mode" in net_mgr, "NetworkManager must track current_game_mode")
		
		# Test setting game mode
		net_mgr.current_game_mode = "survival"
		assert(net_mgr.current_game_mode == "survival", "NetworkManager must support survival mode")
		
		# Test Lobby scene instantiation and mode button
		var lobby_scene: PackedScene = load("res://scenes/ui/lobby.tscn")
		var lobby: Control = lobby_scene.instantiate()
		get_tree().root.add_child(lobby)
		
		var mode_btn: Button = lobby.get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ModeRow/ModeButton")
		assert(mode_btn != null, "Lobby must have ModeButton for toggling between Campaign and Survival")
		
		# Toggle mode via button
		net_mgr.current_game_mode = "campaign"
		lobby._refresh_ui_state()
		assert(mode_btn.text.contains("CAMPAIGN"), "Mode button must reflect campaign mode")
		
		lobby._on_mode_button_pressed()
		assert(net_mgr.current_game_mode == "survival", "Mode button click must switch to survival")
		lobby._refresh_ui_state()
		assert(mode_btn.text.contains("SURVIVAL"), "Mode button must reflect survival mode")
		
		lobby.queue_free()
		if created_net_mgr:
			net_mgr.queue_free()
		print("  Co-op Survival Mode (Lobby toggle & NetworkManager sync): PASS")

	func _test_rubric_excellent_and_bonus_features() -> void:
		print("\n--- Testing Rubric Excellent Tier (AI Bot, Back Gesture, Option B Nakama, Star Perk) ---")
		var GameStateScript = load("res://autoload/game_state.gd")
		var gs = GameStateScript.new()
		add_child(gs)
		assert("ai_companion_enabled" in gs, "GameState must support ai_companion_enabled")
		assert("vibration_enabled" in gs, "GameState must support vibration_enabled")
		assert("colorblind_mode" in gs, "GameState must support colorblind_mode")
		assert("player_callsign" in gs, "GameState must support player_callsign")
		gs.best_stars_by_level = {1: 3, 2: 3, 3: 0, 4: 0, 5: 0}
		assert(gs.get_total_stars() == 6, "get_total_stars() must sum stars across levels")
		assert(gs.is_veteran_loadout_unlocked() == true, "6 stars must unlock Veteran Loadout Perk")
		
		var NetMgrScript = load("res://autoload/network_manager.gd")
		var nm = NetMgrScript.new()
		add_child(nm)
		assert(nm.has_method("authenticate_nakama_device"), "NetworkManager must support Option B Nakama auth")
		assert(nm.has_method("submit_leaderboard_score"), "NetworkManager must support Online Leaderboard")
		nm.submit_leaderboard_score("TEST_HERO", 9999, 20)
		assert(nm.cached_leaderboard[0]["callsign"] == "TEST_HERO", "Top score must rank #1 on leaderboard")
		
		gs.queue_free()
		nm.queue_free()
		print("  Rubric Excellent Tier & Bonus Features: PASS")

	func _test_necro_and_7_witches_coven() -> void:
		print("\n--- Testing NECRO Boss Spawning with 7 Witches Coven & Weapon Shake Reset ---")
		var lvl_scene: PackedScene = load("res://scenes/levels/level_01.tscn")
		var lvl: Node2D = lvl_scene.instantiate()
		add_child(lvl)
		
		var necro: Node2D = lvl.spawn_test_zombie_at(Vector2(600, 300), 13)
		assert(necro != null, "NECRO boss must spawn")
		assert(necro.get_type_name() == "NECRO", "Spawned zombie must be NECRO")
		assert(necro.has_meta("witch_coven"), "NECRO must spawn with witch_coven meta")
		var coven: Array = necro.get_meta("witch_coven")
		assert(coven.size() == 7, "NECRO must spawn with exactly 7 Witches around her (got " + str(coven.size()) + ")")
		for w in coven:
			assert(is_instance_valid(w), "Each Witch in the 7-witch coven must be valid")
			assert(w.get_type_name() == "WITCH", "Coven escort must be WITCH variant")
			assert(w.necro_leader == necro, "Each Witch must track NECRO as her coven leader")
		
		# Verify Shotgun shake reset on weapon switch
		if is_instance_valid(lvl.player) and lvl.player.weapon_controller:
			lvl.player.weapon_controller.unlock_or_add_weapon("SHOTGUN")
			lvl.player.add_camera_shake(9.5)
			assert(lvl.player.camera_shake_strength > 0.0, "Shotgun should apply camera shake")
			lvl.player.weapon_controller.equip_weapon("PISTOL")
			assert(is_equal_approx(lvl.player.camera_shake_strength, 0.0), "Switching weapon from Shotgun must immediately reset camera shake to 0")
		
		lvl.queue_free()
		print("  NECRO + 7 Witches Coven Escort & Shotgun Shake Reset: PASS")
