extends Control

@onready var local_ip_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/LocalIpLabel
@onready var host_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/HostRow/HostButton
@onready var ip_input: LineEdit = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/IpInput
@onready var port_input: LineEdit = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/PortInput
@onready var join_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/JoinRow/JoinButton
@onready var status_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/StatusLabel
@onready var players_label: Label = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/PlayersLabel
@onready var sector_option: OptionButton = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/SectorRow/SectorOption
@onready var start_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ActionRow/StartButton
@onready var back_button: Button = $CenterContainer/LobbyPanel/LobbyMargin/LobbyVBox/ActionRow/BackButton

func _ready() -> void:
	if host_button:
		host_button.pressed.connect(_on_host_pressed)
	if join_button:
		join_button.pressed.connect(_on_join_pressed)
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	if sector_option:
		sector_option.clear()
		sector_option.add_item("SECTOR 01: OUTPOST QUARANTINE (3 WAVES)", 1)
		sector_option.add_item("SECTOR 02: THE DEAD HIGHWAY (4 WAVES)", 2)
		sector_option.add_item("SECTOR 03: INDUSTRIAL SLAUGHTERHOUSE (4 WAVES)", 3)
		sector_option.add_item("SECTOR 04: CONTAINMENT DEPOT (5 WAVES)", 4)
		sector_option.add_item("SECTOR 05: LAST LIGHT — BLACKOUT FINALE (5 WAVES)", 5)
		sector_option.select(0)
	
	var net_mgr := _get_network_manager()
	if net_mgr:
		var ips: Array[String] = net_mgr.get_local_ip_addresses()
		if local_ip_label:
			local_ip_label.text = "YOUR LOCAL IP(S):  " + "  ·  ".join(PackedStringArray(ips))
		
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
	
	_refresh_ui_state()

func _get_network_manager() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _refresh_ui_state() -> void:
	var net_mgr := _get_network_manager()
	var in_session: bool = (net_mgr != null and (net_mgr.is_host or net_mgr.connected_peers.size() > 0))
	
	if host_button:
		host_button.disabled = in_session
	if join_button:
		join_button.disabled = in_session
	if ip_input:
		ip_input.editable = not in_session
	if port_input:
		port_input.editable = not in_session
	
	if net_mgr:
		_update_players_display(net_mgr.connected_peers)
	else:
		_update_players_display([])

func _on_host_pressed() -> void:
	var port := 7777
	if port_input and port_input.text.is_valid_int():
		port = port_input.text.to_int()
	
	var net_mgr := _get_network_manager()
	if net_mgr:
		var err: Error = net_mgr.host_game(port)
		if err == OK:
			_refresh_ui_state()
			if status_label:
				status_label.text = "[ HOSTING SESSION ON PORT " + str(port) + " — WAITING FOR SURVIVOR 2 ]"
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
		if host_button: host_button.disabled = true
		if join_button: join_button.disabled = true
		var err: Error = net_mgr.join_game(address, port)
		if err == OK and status_label:
			status_label.text = "[ CONNECTING TO " + address + ":" + str(port) + "... ]"
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
		net_mgr.rpc_start_coop_mission.rpc(lvl_id)

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
		players_label.text = "SURVIVORS READY: " + str(count) + " / 2"
		if count >= 2:
			players_label.text += "  ·  [ SQUAD FULL - DEPLOYMENT AUTHORIZED ]"
			players_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.50))
		elif count == 1:
			players_label.text += "  ·  [ WAITING FOR SECOND SURVIVOR ]"
			players_label.add_theme_color_override("font_color", Color(0.85, 0.70, 0.25))
		else:
			players_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.75))
	
	var net_mgr := _get_network_manager()
	var am_host: bool = bool(net_mgr.is_host) if net_mgr else false
	
	if start_button:
		if am_host:
			start_button.disabled = (count < 2)
			start_button.text = "LAUNCH CO-OP MISSION" if count >= 2 else "WAITING FOR 2ND SURVIVOR..."
		else:
			start_button.disabled = true
			start_button.text = "WAITING FOR HOST TO LAUNCH..."
