extends SceneTree

func _init():
	var runner = LobbyUITestRunner.new()
	root.add_child.call_deferred(runner)

class LobbyUITestRunner extends Node:
	func _ready():
		print("Starting Task 14: Lobby UI & Network Status Tests...")
		var lobby_scene = load("res://scenes/ui/lobby.tscn")
		assert(lobby_scene != null, "Failed to load res://scenes/ui/lobby.tscn")
		
		var lobby_ui = lobby_scene.instantiate()
		add_child(lobby_ui)
		
		# 1. Verify key UI nodes exist
		assert(lobby_ui.host_button != null, "Host button must exist")
		assert(lobby_ui.join_button != null, "Join button must exist")
		assert(lobby_ui.start_button != null, "Start button must exist")
		assert(lobby_ui.back_button != null, "Back button must exist")
		assert(lobby_ui.ip_input != null, "IP LineEdit must exist")
		assert(lobby_ui.port_input != null, "Port LineEdit must exist")
		assert(lobby_ui.status_label != null, "Status label must exist")
		assert(lobby_ui.players_label != null, "Players label must exist")
		print("Lobby Node Structure: PASS")
		
		# 2. Verify initial UI state
		assert(lobby_ui.start_button.disabled == true, "Start button must be disabled initially before peers connect")
		assert(lobby_ui.local_ip_label.text.length() > 0, "Local IP info should display detected IP addresses")
		print("Initial State & IP Display: PASS")
		
		# 3. Simulate peer connection update
		var net_mgr = get_node_or_null("/root/NetworkManager")
		if net_mgr:
			lobby_ui._on_status_changed("Testing status display")
			assert("TESTING STATUS DISPLAY" in lobby_ui.status_label.text, "Status label must update")
			
			net_mgr.is_host = true
			lobby_ui._update_players_display([1, 2])
			assert("2 / 4" in lobby_ui.players_label.text or "2 / 2" in lobby_ui.players_label.text, "Players label must show player count")
			assert(lobby_ui.start_button.disabled == false, "Start button should be enabled when 2 players connected on host")
			net_mgr.is_host = false
		
		
		lobby_ui.queue_free()
		print("ALL LOBBY UI TESTS PASSED!")
		get_tree().quit(0)
