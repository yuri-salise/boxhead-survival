extends SceneTree

func _init():
	var runner = NetworkManagerTestRunner.new()
	root.add_child.call_deferred(runner)

class NetworkManagerTestRunner extends Node:
	var net_mgr: Node = null
	var state := 0
	var state_timer := 0.0
	var timeout_fired := false
	
	func _ready():
		print("Starting Task 13: NetworkManager Autoload & Peer Session Lifecycle Tests...")
		var NetMgrScript = load("res://autoload/network_manager.gd")
		assert(NetMgrScript != null, "Failed to load res://autoload/network_manager.gd")
		net_mgr = NetMgrScript.new()
		add_child(net_mgr)
		
		# 1. Test IP Address discovery
		var ips: Array[String] = net_mgr.get_local_ip_addresses()
		assert(ips.size() > 0, "NetworkManager should find at least one IP address")
		print("IP Discovery: PASS -> Found IPs: ", ips)
		
		# 2. Test hosting session
		var host_err: Error = net_mgr.host_game(7781)
		assert(host_err == OK, "Hosting on 7781 should return OK (got " + str(host_err) + ")")
		assert(net_mgr.is_host == true, "NetworkManager.is_host must be true after hosting")
		assert(1 in net_mgr.connected_peers, "Host peer 1 must be in connected_peers")
		print("Host Creation: PASS")
		
		# 3. Test leave game and offline peer restoration
		net_mgr.leave_game()
		assert(net_mgr.is_host == false, "NetworkManager.is_host must be false after leaving")
		assert(net_mgr.connected_peers.is_empty(), "connected_peers must be empty after leaving")
		assert(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Multiplayer peer must be OfflineMultiplayerPeer after leaving")
		print("Leave & Offline Restoration: PASS")
		
		# 4. Test client timeout recovery on unreachable address
		print("Testing unreachable host connection timeout...")
		net_mgr.connection_failed.connect(func(reason: String):
			timeout_fired = true
			print("Received expected connection_failed signal: ", reason)
		)
		
		# Set very short timeout for test (0.25s)
		net_mgr.CONNECT_TIMEOUT_SEC = 0.25
		var join_err: Error = net_mgr.join_game("127.0.0.1", 19999) # Port 19999 should not have a server
		assert(join_err == OK, "join_game should initiate socket connection with OK")
		assert(net_mgr.is_connecting == true, "net_mgr.is_connecting must be true while attempting join")
		state = 1
	
	func _process(delta: float):
		if state == 1:
			state_timer += delta
			if state_timer >= 0.45:
				assert(timeout_fired == true, "NetworkManager must emit connection_failed after timeout")
				assert(net_mgr.is_connecting == false, "net_mgr.is_connecting must be false after timeout")
				assert(multiplayer.multiplayer_peer is OfflineMultiplayerPeer, "Must restore OfflineMultiplayerPeer after timeout")
				print("Timeout Recovery & Clean Failure: PASS")
				
				net_mgr.queue_free()
				print("ALL NETWORK MANAGER TESTS PASSED!")
				get_tree().quit(0)
