extends SceneTree

func _init():
	var runner = PlayerTestRunner.new()
	root.add_child.call_deferred(runner)

class PlayerTestRunner extends Node2D:
	func _ready():
		print("Testing Player Survivor & Weapon Controller...")
		var player_scene = load("res://scenes/actors/player.tscn")
		assert(player_scene != null, "Failed to load player.tscn")
		
		var player = player_scene.instantiate()
		add_child(player)
		player.position = Vector2(200, 200)
		
		# Verify initial properties
		assert(player.max_health == 100.0, "Max health should be 100")
		assert(player.current_health == 100.0, "Current health should start at 100")
		assert(player.is_dead == false, "Player should be alive")
		print("Player initial properties: PASS")
		
		# Test damage & health signal
		var health_reported = [-1.0, -1.0]
		player.health_changed.connect(func(cur, m):
			health_reported[0] = cur
			health_reported[1] = m
		)
		
		player.take_damage(30.0)
		assert(player.current_health == 70.0, "Current health should be 70 after 30 damage")
		assert(health_reported[0] == 70.0 and health_reported[1] == 100.0, "health_changed signal values mismatch")
		print("Health decrement & signal: PASS")
		
		# Test player death
		var death_signaled = [false]
		player.player_died.connect(func():
			death_signaled[0] = true
		)
		
		player.take_damage(80.0)
		assert(player.current_health == 0.0, "Health should clamp to 0")
		assert(player.is_dead == true, "Player should be marked dead")
		assert(death_signaled[0] == true, "player_died signal not emitted")
		print("Player death & signal: PASS")
		
		# Test WeaponController cooldown
		var weapon = player.weapon_controller
		assert(weapon != null, "weapon_controller should exist on player")
		assert(weapon.can_shoot() == true, "Weapon should initially be ready to fire")
		
		var muzzle_pos = player.get_muzzle_position()
		var proj = weapon.try_fire(muzzle_pos, Vector2.RIGHT, player)
		assert(proj != null, "Weapon fire should produce projectile")
		assert(weapon.can_shoot() == false, "Weapon should be on cooldown immediately after firing")
		
		# Update cooldown
		weapon.update_cooldown(weapon.fire_rate + 0.01)
		assert(weapon.can_shoot() == true, "Weapon should be ready after cooldown elapsed")
		print("WeaponController firing and cooldown: PASS")
		
		proj.queue_free()
		player.queue_free()
		
		print("ALL PLAYER TESTS PASSED!")
		get_tree().quit(0)
