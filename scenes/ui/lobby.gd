extends Control

@onready var local_ip_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/LocalIpLabel
@onready var host_banner_panel: PanelContainer = get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostBannerPanel")
@onready var host_ip_display: Label = get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostBannerPanel/HostBannerMargin/HostBannerVBox/HostIpBox/HostIpDisplay")
@onready var host_alt_ips_label: Label = get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostBannerPanel/HostBannerMargin/HostBannerVBox/HostAltIpsLabel")
@onready var copy_ip_button: Button = get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostBannerPanel/HostBannerMargin/HostBannerVBox/HostIpBox/CopyIpButton")

@onready var host_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostRow/HostButton
@onready var ip_input: LineEdit = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/IpInput
@onready var port_input: LineEdit = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/PortInput
@onready var join_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/JoinButton
@onready var status_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/StatusLabel
@onready var players_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/PlayersLabel
@onready var mode_button: Button = get_node_or_null("CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ModeRow/ModeButton")
@onready var sector_option: OptionButton = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/SectorRow/SectorOption
@onready var start_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ActionRow/StartButton
@onready var back_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ActionRow/BackButton

func _ready() -> void:
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
	if mode_button:
		mode_button.pressed.connect(_on_mode_button_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if copy_ip_button:
		copy_ip_button.pressed.connect(func():
			var net_mgr := _get_network_manager()
			var host_ip: String = net_mgr.get_primary_host_ip() if net_mgr and net_mgr.has_method("get_primary_host_ip") else "127.0.0.1"
			DisplayServer.clipboard_set(host_ip)
			copy_ip_button.text = "✓ COPIED"
			get_tree().create_timer(2.0).timeout.connect(func():
				if is_instance_valid(copy_ip_button):
					copy_ip_button.text = "📋 COPY"
			)
		)
	
	if sector_option:
		sector_option.clear()
		sector_option.add_item("SECTOR 01: QUARANTINE (3 WAVES)", 1)
		sector_option.add_item("SECTOR 02: THE STREET (4 WAVES)", 2)
		sector_option.add_item("SECTOR 03: NO EXIT (5 WAVES)", 3)
		sector_option.add_item("SECTOR 04: THE DEPOT (5 WAVES)", 4)
		sector_option.add_item("SECTOR 05: LAST LIGHT — BLACKOUT FINALE (5 WAVES)", 5)
		sector_option.select(0)
	
	var net_mgr := _get_network_manager()
	if net_mgr:
		if not net_mgr.status_changed.is_connected(_on_status_changed):
			net_mgr.status_changed.connect(_on_status_changed)
		if not net_mgr.connection_failed.is_connected(_on_connection_failed):
			net_mgr.connection_failed.connect(_on_connection_failed)
		if not net_mgr.connection_succeeded.is_connected(_on_connection_succeeded):
			net_mgr.connection_succeeded.connect(_on_connection_succeeded)
		if not net_mgr.peer_connected.is_connected(_on_peer_updated):
			net_mgr.peer_connected.connect(_on_peer_updated)
		if not net_mgr.peer_disconnected.is_connected(_on_peer_updated):
			net_mgr.peer_disconnected.connect(_on_peer_updated)
		if not net_mgr.server_disconnected.is_connected(_on_server_disconnected):
			net_mgr.server_disconnected.connect(_on_server_disconnected)
		if net_mgr.has_signal("game_mode_changed") and not net_mgr.game_mode_changed.is_connected(_on_game_mode_changed):
			net_mgr.game_mode_changed.connect(_on_game_mode_changed)
	
	_refresh_ui_state()

func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _refresh_ui_state() -> void:
	var net_mgr := _get_network_manager()
	var in_session: bool = (net_mgr != null and (net_mgr.is_host or net_mgr.connected_peers.size() > 0))
	var am_host: bool = (net_mgr != null and net_mgr.is_host)
	
	if host_button:
		host_button.disabled = in_session
		if am_host:
			host_button.text = "★ HOSTING ACTIVE (YOU ARE HOST) ★"
		else:
			host_button.text = "HOST CO-OP MATCH (BECOME HOST)"
	
	if join_button:
		join_button.disabled = in_session
	if ip_input:
		ip_input.editable = not in_session
	if port_input:
		port_input.editable = not in_session
	
	if host_banner_panel:
		host_banner_panel.visible = am_host
		if am_host and net_mgr:
			var primary_ip: String = net_mgr.get_primary_host_ip() if net_mgr.has_method("get_primary_host_ip") else "127.0.0.1"
			var port := 7777
			if port_input and port_input.text.is_valid_int():
				port = port_input.text.to_int()
			if host_ip_display:
				host_ip_display.text = "👉  " + primary_ip + "  (PORT: " + str(port) + ")  👈"
			if host_alt_ips_label:
				var all_ips: Array[String] = net_mgr.get_local_ip_addresses()
				if all_ips.size() > 1:
					var alts: Array[String] = []
					for i in range(1, all_ips.size()):
						alts.append(all_ips[i])
					host_alt_ips_label.text = "Alternative network adapters: " + " · ".join(PackedStringArray(alts))
					host_alt_ips_label.visible = true
				else:
					host_alt_ips_label.visible = false
	
	if local_ip_label and net_mgr:
		var primary_ip: String = net_mgr.get_primary_host_ip() if net_mgr.has_method("get_primary_host_ip") else "127.0.0.1"
		var all_ips: Array[String] = net_mgr.get_local_ip_addresses()
		if all_ips.size() > 1:
			var alts: Array[String] = []
			for i in range(1, all_ips.size()):
				alts.append(all_ips[i])
			local_ip_label.text = "THIS DEVICE'S IP:  " + primary_ip + " [WI-FI RECOMMENDED]  ·  (ALT: " + ", ".join(PackedStringArray(alts)) + ")"
		else:
			local_ip_label.text = "THIS DEVICE'S IP:  " + primary_ip + " [WI-FI / HOTSPOT]"
		
		# Hint subnet in Join placeholder
		if ip_input and primary_ip.contains(".") and not in_session:
			var parts := primary_ip.split(".")
			if parts.size() == 4:
				ip_input.placeholder_text = "Enter Host IP (e.g. " + parts[0] + "." + parts[1] + "." + parts[2] + ".xxx)"
	
	if net_mgr:
		_update_players_display(net_mgr.connected_peers)
	else:
		_update_players_display([])
	
	if mode_button:
		var mode_name: String = net_mgr.current_game_mode if (net_mgr and "current_game_mode" in net_mgr) else "campaign"
		if mode_name == "survival":
			mode_button.text = "🔥 ENDLESS SURVIVAL SWARMS (RECORD DEFENSE) 🔥"
			mode_button.add_theme_color_override("font_color", Color(1.0, 0.55, 0.20))
		else:
			mode_button.text = "CAMPAIGN MISSION (CLEAR SECTOR WAVES)"
			mode_button.add_theme_color_override("font_color", Color(0.95, 0.90, 0.85))
		
		# Only host or unjoined player can toggle the match mode
		mode_button.disabled = (not am_host and in_session)

func _on_mode_button_pressed() -> void:
	var net_mgr := _get_network_manager()
	if not net_mgr:
		return
	if net_mgr.connected_peers.size() > 0 and not net_mgr.is_host:
		return
	
	var new_mode := "survival" if net_mgr.current_game_mode == "campaign" else "campaign"
	net_mgr.current_game_mode = new_mode
	if net_mgr.is_host and is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		net_mgr.rpc_set_game_mode.rpc(new_mode)
	_refresh_ui_state()

func _on_game_mode_changed(_mode_name: String) -> void:
	_refresh_ui_state()

func _on_host_pressed() -> void:
	var port := 7777
	if port_input and port_input.text.is_valid_int():
		port = port_input.text.to_int()
	
	var net_mgr := _get_network_manager()
	if net_mgr:
		var err: Error = net_mgr.host_game(port)
		if err == OK:
			_refresh_ui_state()
			var host_ip: String = net_mgr.get_primary_host_ip() if net_mgr.has_method("get_primary_host_ip") else "127.0.0.1"
			if status_label:
				status_label.text = "[ HOST ACTIVE — TELL JOINERS TO INPUT IP: " + host_ip + " ]"
				status_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.50))

func _on_join_pressed() -> void:
	var address := "127.0.0.1"
	if ip_input and not ip_input.text.strip_edges().is_empty():
		address = ip_input.text.strip_edges()
	
	var port := 7777
	if port_input and port_input.text.is_valid_int():
		port = port_input.text.to_int()
	
	var net_mgr := _get_network_manager()
	if net_mgr:
		# Check if player accidentally typed their own device IP
		var my_ips: Array[String] = net_mgr.get_local_ip_addresses()
		if my_ips.has(address) and address != "127.0.0.1":
			if status_label:
				status_label.text = "[ ⚠️ THAT'S THIS DEVICE'S IP! ENTER THE OTHER DEVICE'S (HOST'S) IP ]"
				status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.20))
			return
		
		if host_button: host_button.disabled = true
		if join_button: join_button.disabled = true
		var err: Error = net_mgr.join_game(address, port)
		if err == OK and status_label:
			status_label.text = "[ CONNECTING TO HOST " + address + ":" + str(port) + "... ]"
			status_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))

func _on_start_pressed() -> void:
	var net_mgr := _get_network_manager()
	if not net_mgr or not net_mgr.is_host:
		return
	
	var lvl_id := 1
	if sector_option:
		var idx := sector_option.selected
		lvl_id = sector_option.get_item_id(idx)
	
	if net_mgr.has_method("rpc_start_coop_mission"):
		net_mgr.rpc_start_coop_mission.rpc(lvl_id, net_mgr.current_game_mode)

func _on_back_pressed() -> void:
	var net_mgr := _get_network_manager()
	if net_mgr:
		net_mgr.leave_game()
	
	if ResourceLoader.exists("res://scenes/ui/mode_select.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_status_changed(msg: String) -> void:
	if status_label:
		status_label.text = "[ " + msg.to_upper() + " ]"
		status_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.90))

func _on_connection_succeeded() -> void:
	_refresh_ui_state()
	if status_label:
		status_label.text = "[ CONNECTED TO HOST — WAITING FOR MISSION LAUNCH ]"
		status_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.50))

func _on_connection_failed(reason: String) -> void:
	_refresh_ui_state()
	if status_label:
		if "timed out" in reason.to_lower():
			status_label.text = "[ CONNECTION TIMED OUT — VERIFY HOST IP (NOT YOUR OWN IP) & SAME WI-FI ]"
		else:
			status_label.text = "[ ERROR: " + reason.to_upper() + " ]"
		status_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.20))

func _on_server_disconnected() -> void:
	_refresh_ui_state()
	if status_label:
		status_label.text = "[ HOST DISCONNECTED — RETURNING TO LOBBY IDLE ]"
		status_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.25))

func _on_peer_updated(_id: int) -> void:
	var net_mgr := _get_network_manager()
	if net_mgr:
		_update_players_display(net_mgr.connected_peers)

func _update_players_display(peers: Array) -> void:
	var count := peers.size()
	if players_label:
		players_label.text = "SURVIVORS READY: " + str(count) + " / 4"
		if count >= 4:
			players_label.text += "  ·  [ FULL SQUAD — READY TO DEPLOY ]"
			players_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.50))
		elif count >= 2:
			players_label.text += "  ·  [ SQUAD FORMED (" + str(count) + "/4) — DEPLOYMENT READY ]"
			players_label.add_theme_color_override("font_color", Color(0.40, 0.88, 0.55))
		elif count == 1:
			players_label.text += "  ·  [ WAITING FOR SQUAD MATES (1-3 MORE) ]"
			players_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.25))
		else:
			players_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.75))
	
	var net_mgr := _get_network_manager()
	var am_host: bool = bool(net_mgr.is_host) if net_mgr else false
	
	if start_button:
		if am_host:
			start_button.disabled = (count < 2)
			start_button.text = "LAUNCH SQUAD MISSION (" + str(count) + "/4)" if count >= 2 else "WAITING FOR SQUAD TO JOIN..."
		else:
			start_button.disabled = true
			start_button.text = "WAITING FOR HOST TO LAUNCH..."
