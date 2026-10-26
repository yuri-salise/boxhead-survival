extends Node

signal connection_succeeded()
signal connection_failed(reason: String)
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal server_disconnected()
signal status_changed(message: String)
signal game_started(level_id: int)

const DEFAULT_PORT: int = 7777
const MAX_CLIENTS: int = 1 # 2-player co-op: Host (1) + Guest (1)

var CONNECT_TIMEOUT_SEC: float = 8.0

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var is_connecting: bool = false
var connection_timer: float = 0.0
var connected_peers: Array[int] = []
var selected_level_id: int = 1

func _ready() -> void:
	# Keep NetworkManager processing across scene changes and pauses
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	if is_connecting:
		connection_timer -= delta
		if connection_timer <= 0.0:
			_handle_connection_timeout()

func get_local_ip_addresses() -> Array[String]:
	var results: Array[String] = []
	var all_ips: PackedStringArray = IP.get_local_addresses()
	for ip in all_ips:
		# Filter for valid IPv4 addresses excluding link-local or loopback
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
			results.append(ip)
	
	if results.is_empty():
		results.append("127.0.0.1")
	return results

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
	
	var status_msg := "Host active on port " + str(port) + ". Waiting for co-op peer..."
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
func rpc_start_coop_mission(level_id: int) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	# In local call, sender_id can be 0 (called locally by host) or 1
	if sender_id != 0 and sender_id != 1:
		push_warning("Unauthorized client attempted to call rpc_start_coop_mission")
		return
	
	selected_level_id = level_id
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.selected_mode = "online"
		gs.current_level = level_id
	
	game_started.emit(level_id)
	
	var scene_path := "res://scenes/levels/level_0" + str(level_id) + ".tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")
