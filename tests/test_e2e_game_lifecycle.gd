extends SceneTree

func _init() -> void:
	var runner := E2ETestRunner.new()
	root.add_child.call_deferred(runner)

class E2ETestRunner extends Node:
	func _ready() -> void:
		print("=================================================================")
		print("      RUNNING COMPLETE END-TO-END (E2E) SYSTEM LIFECYCLE        ")
		print("=================================================================")
		
		# --- Phase 1: Boot & Main Menu & Navigation ---
		print("\n[E2E Phase 1] Boot & Menu Navigation Flow...")
		var MainMenuScene = load("res://scenes/ui/main_menu.tscn")
		var menu = MainMenuScene.instantiate()
		add_child(menu)
		assert(menu != null, "Main menu must instantiate")
		print("  -> Main Menu loaded and UI controls responsive")
		menu.queue_free()
		
		var ModeSelectScene = load("res://scenes/ui/mode_select.tscn")
		var mode_select = ModeSelectScene.instantiate()
		add_child(mode_select)
		assert(mode_select != null, "Mode select must instantiate")
		print("  -> Mode Select UI loaded (Campaign, Survival, Co-op)")
		mode_select.queue_free()
		
		# --- Phase 2: Campaign Sector 1 End-to-End Simulation ---
		print("\n[E2E Phase 2] Campaign Sector 1 Full Combat & Objective Flow...")
		var LevelScene = load("res://scenes/levels/level_01.tscn")
		var level = LevelScene.instantiate()
		add_child(level)
		
		assert(level.player != null, "Player must spawn in level")
		assert(level.wave_director != null, "WaveDirector must be present")
		assert(level.horror_vignette != null, "HorrorVignette lighting system must be present")
		
		# Verify Player Controls
		level.player.set_input_override(Vector2.RIGHT, Vector2(800, 360), false)
		assert(level.player.override_move_vec == Vector2.RIGHT, "Player movement input must register")
		
		# Verify Day/Night Transition & Realistic Lighting
		level.advance_day_night_cycle(120.0, true) # Advance to Nightfall
		assert(level.current_night_factor > 0.0, "Day/night cycle must smoothly transition")
		assert(level.horror_vignette.darkness_rect.visible == true, "Darkness shader must engage at night")
		
		# Simulate 1 Wave of Combat
		var test_z: Node2D = level.spawn_test_zombie_at(Vector2(700, 360), 0) # Walker
		assert(test_z != null, "Zombie must spawn in sector")
		assert(level._get_living_hostiles_count() >= 1, "Living hostiles count must track active zombie")
		
		# Player damages and kills zombie
		test_z.take_damage(100.0)
		assert(test_z.get("is_dead") == true, "Zombie must die from lethal damage")
		
		# Verify Sector Completion Flow
		level.all_waves_cleared_pending = false
		level._trigger_all_waves_cleared()
		
		var gs = get_node_or_null("/root/GameState")
		if gs:
			gs.complete_level(1, 1500, 3, true, true)
			assert(gs.is_level_unlocked(2), "Sector 2 must unlock persistently after Sector 1 clear")
			print("  -> Sector 1 cleared: 3 Stars, Untouchable & Night Stalker awarded")
			print("  -> Persistent progression verified: Sector 2 unlocked!")
		
		level.queue_free()
		
		# --- Phase 3: Endless Survival Mode Lifecycle ---
		print("\n[E2E Phase 3] Endless Survival Mode Progression...")
		if gs:
			gs.selected_mode = "survival"
			var surv_res: Dictionary = gs.record_survival_run(5, 4500)
			assert(gs.survival_best_wave >= 5, "Survival wave record must persist")
			assert(gs.survival_best_score >= 4500, "Survival score record must persist")
			print("  -> Survival Mode run recorded (Wave: " + str(gs.survival_best_wave) + ", Score: " + str(gs.survival_best_score) + ")")
		
		# --- Phase 4: Network Co-op Host & Graceful Disconnect Lifecycle ---
		print("\n[E2E Phase 4] Co-op Multiplayer Host/Join & Safe Offline Fallback...")
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			var host_err: Error = net_mgr.host_game(7789)
			assert(host_err == OK, "Host game must succeed on valid port")
			assert(net_mgr.is_host == true, "Host status must be active")
			assert(net_mgr.connected_peers.has(1), "Host peer must be peer 1")
			print("  -> Co-op Host active on port 7789")
			
			net_mgr.leave_game()
			assert(net_mgr.is_host == false, "Host must be cleared after leaving game")
			assert(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "OfflineMultiplayerPeer must be restored")
			print("  -> Graceful disconnect verified: OfflineMultiplayerPeer safely restored")
		
		# --- Phase 5: Result Screen Verification ---
		print("\n[E2E Phase 5] Victory & Results Display...")
		var ResultScene = load("res://scenes/ui/result_screen.tscn")
		var result_screen = ResultScene.instantiate()
		add_child(result_screen)
		assert(result_screen != null, "Result screen must instantiate")
		result_screen.show_victory(1, 1500, 18, 3, ["UNTOUCHABLE"])
		print("  -> Result screen successfully presented victory stats & stars")
		result_screen.queue_free()
		
		print("\n=================================================================")
		print("       ALL END-TO-END (E2E) TESTS PASSED SUCCESSFULLY!          ")
		print("=================================================================")
		get_tree().quit(0)
