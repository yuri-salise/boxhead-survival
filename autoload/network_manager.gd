extends Node

signal connection_succeeded()
signal connection_failed(reason: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected()
signal status_changed(message: String)
signal game_started(level_id: int)
signal game_mode_changed(mode_name: String)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 3 # 4-player Squad Co-op: Host (1) + up to 3 Guests (4 survivors total)

var CONNECT_TIMEOUT_SEC: float = 8.0

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_connecting: bool = false
var connection_timer: float = 0.0
var connected_peers: Array[int] = []
var selected_level_id: int = 1
var current_game_mode: String = "campaign"

func _ready() -> void:
	# Keep NetworkManager processing across scene changes and pauses
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_connecting:
		connection_timer -= delta
		if connection_timer <= 0.0:
			_handle_connection_timeout()

func get_smart_ip_list() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var interfaces := IP.get_local_interfaces()
	
	var virtual_keywords := ["wsl", "hyper-v", "vmnet", "vmware", "virtualbox", "vbox", "docker", "vethernet", "bluetooth", "loopback", "pseudo"]
	var wifi_lan_keywords := ["wi-fi", "wifi", "wlan", "wireless", "hotspot", "ap0", "eth", "ethernet", "en0", "wlan0"]
	
	for iface in interfaces:
		var name_str: String = str(iface.get("name", "")).to_lower()
		var friendly: String = str(iface.get("friendly", "")).to_lower()
		var full_id := name_str + " " + friendly
		
		var is_virtual: bool = false
		for vk in virtual_keywords:
			if vk in full_id:
				is_virtual = true
				break
		
		var is_wifi_lan: bool = false
		for wk in wifi_lan_keywords:
			if wk in full_id:
				is_wifi_lan = true
				break
		
		var addresses: Array = iface.get("addresses", [])
		for addr in addresses:
			var s_addr: String = str(addr)
			if not s_addr.contains(".") or s_addr.begins_with("127.") or s_addr.begins_with("169.254."):
				continue
			
			var score := 0
			if is_wifi_lan and not is_virtual:
				score += 100
			elif not is_virtual:
				score += 50
			else:
				score -= 50
			
			if s_addr.begins_with("192.168."):
				score += 20
			elif s_addr.begins_with("10."):
				score += 10
			
			results.append({
				"ip": s_addr,
				"name": iface.get("friendly", iface.get("name", "LAN")),
				"score": score,
				"is_virtual": is_virtual
			})
	
	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results

func get_local_ip_addresses() -> Array[String]:
	var smart := get_smart_ip_list()
	var results: Array[String] = []
	for item in smart:
		if not results.has(item["ip"]):
			results.append(item["ip"])
	
	# Fallback if interface scanning returned empty
	if results.is_empty():
		var all_ips: PackedStringArray = IP.get_local_addresses()
		for ip in all_ips:
			if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				if not results.has(ip):
					results.append(ip)
	
	if results.is_empty():
		results.append("127.0.0.1")
	return results

func get_primary_host_ip() -> String:
	var ips := get_local_ip_addresses()
	return ips[0] if not ips.is_empty() else "127.0.0.1"

func host_game(port: int = DEFAULT_PORT) -> Error:
	leave_game()
	
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(port, MAX_CLIENTS)
	if err != OK:
		peer = null
		var msg := "Failed to create host server on port " + str(port) + " (Error code: " + str(err) + ")"
		status_changed.emit(msg)
		connection_failed.emit(msg)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connecting = false
	connected_peers = [1] # Peer 1 is the host
	
	_connect_multiplayer_signals()
	
	var status_msg := "Host active on port " + str(port) + ". Waiting for squad peers..."
	status_changed.emit(status_msg)
	peer_connected.emit(1)
	return OK

func join_game(address: String = "127.0.0.1", port: int = DEFAULT_PORT) -> Error:
	leave_game()
	
	var target_ip := address.strip_edges()
	if target_ip.is_empty():
		target_ip = "127.0.0.1"
	
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(target_ip, port)
	if err != OK:
		peer = null
		var msg := "Failed to initiate client connection to " + target_ip + ":" + str(port) + " (Error code: " + str(err) + ")"
		status_changed.emit(msg)
		connection_failed.emit(msg)
		return err
	
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_connecting = true
	connection_timer = CONNECT_TIMEOUT_SEC
	connected_peers.clear()
	
	_connect_multiplayer_signals()
	
	status_changed.emit("Connecting to " + target_ip + ":" + str(port) + "...")
	return OK

func leave_game() -> void:
	is_connecting = false
	connection_timer = 0.0
	
	_disconnect_multiplayer_signals()
	
	if is_instance_valid(peer):
		peer.close()
		peer = null
	
	# Restore safe offline multiplayer peer as strictly required by AGENTS.md
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	
	is_host = false
	connected_peers.clear()
	status_changed.emit("Disconnected")

func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _disconnect_multiplayer_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
	if multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.disconnect(_on_connection_failed)
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	if not id in connected_peers:
		connected_peers.append(id)
	status_changed.emit("Survivor (Peer " + str(id) + ") connected.")
	peer_connected.emit(id)
	if is_host and id != 1:
		rpc_set_game_mode.rpc_id(id, current_game_mode)

func _on_peer_disconnected(id: int) -> void:
	if id in connected_peers:
		connected_peers.erase(id)
	status_changed.emit("Survivor (Peer " + str(id) + ") disconnected.")
	peer_disconnected.emit(id)

func _on_connected_to_server() -> void:
	is_connecting = false
	var my_id := multiplayer.get_unique_id()
	if not my_id in connected_peers:
		connected_peers.append(my_id)
	if not 1 in connected_peers:
		connected_peers.append(1) # Host is peer 1
	status_changed.emit("Connected to Host. Ready for deployment!")
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	leave_game()
	var msg := "Connection attempt failed. Unable to reach host."
	status_changed.emit(msg)
	connection_failed.emit(msg)

func _on_server_disconnected() -> void:
	leave_game()
	var msg := "Lost connection to Host server."
	status_changed.emit(msg)
	server_disconnected.emit()

func _handle_connection_timeout() -> void:
	var msg := "Connection timed out after " + String.num(CONNECT_TIMEOUT_SEC, 1) + " seconds. Check IP address and Wi-Fi / Hotspot connection."
	leave_game()
	connection_failed.emit(msg)

@rpc("authority", "call_local", "reliable")
func rpc_set_game_mode(mode_name: String) -> void:
	var sender_id: int = 0
	if is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer():
		sender_id = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return
	current_game_mode = mode_name
	game_mode_changed.emit(mode_name)

@rpc("authority", "call_local", "reliable")
func rpc_start_coop_mission(level_id: int, mode_name: String = "campaign") -> void:
	var sender_id: int = 0
	if is_inside_tree() and multiplayer != null and multiplayer.has_multiplayer_peer():
		sender_id = multiplayer.get_remote_sender_id()
	# In local call, sender_id can be 0 (called locally by host) or 1
	if sender_id != 0 and sender_id != 1:
		push_warning("Unauthorized client attempted to call rpc_start_coop_mission")
		return
	
	selected_level_id = level_id
	current_game_mode = mode_name
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.selected_mode = "survival" if mode_name == "survival" else "online"
		gs.current_level = level_id
	
	game_started.emit(level_id)
	
	var scene_path := "res://scenes/levels/level_0" + str(level_id) + ".tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")
