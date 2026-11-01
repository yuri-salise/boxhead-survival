extends SceneTree

func _init():
	var runner = ZombieTestRunner.new()
	root.add_child.call_deferred(runner)

class ZombieTestRunner extends Node2D:
	func _ready():
		print("Testing Zombie Basic Actor...")
		var zombie_scene = load("res://scenes/actors/zombie_basic.tscn")
		assert(zombie_scene != null, "Failed to load zombie_basic.tscn")
		
		var zombie = zombie_scene.instantiate()
		add_child(zombie)
		zombie.position = Vector2(300, 300)
		
		# Verify initial properties
		assert(zombie.max_health == 50.0, "Max health should be 50")
		assert(zombie.current_health == 50.0, "Current health should be 50")
		assert(zombie.attack_damage == 15.0, "Attack damage should be 15")
		assert(zombie.is_dead == false, "Zombie should start alive")
		print("Zombie initial properties: PASS")
		
		# Test target pursuit direction calculation
		var dummy_player = DummyPlayer.new()
		add_child(dummy_player)
		dummy_player.position = Vector2(400, 300) # Directly to the right
		
		zombie.set_target(dummy_player)
		var pursuit_dir = zombie.get_pursuit_direction()
		assert(pursuit_dir.is_equal_approx(Vector2.RIGHT), "Pursuit direction should point to target player")
		print("Pursuit direction calculation: PASS")
		
		# Test attack delivery on contact
		assert(zombie.can_attack == true, "Zombie should initially be ready to attack")
		zombie.try_attack_target(dummy_player)
		assert(dummy_player.damage_received == 15.0, "Player should take zombie attack damage")
		assert(zombie.can_attack == false, "Zombie should be on attack cooldown after striking")
		
		# Cooldown elapsed
		zombie.update_attack_cooldown(zombie.attack_cooldown + 0.05)
		assert(zombie.can_attack == true, "Zombie should be ready to attack after cooldown")
		print("Attack damage delivery and cooldown: PASS")
		
		# Test damage taking and death signal
		var death_signaled = [false]
		zombie.zombie_died.connect(func(z):
			death_signaled[0] = true
			assert(z == zombie, "Zombie reference in signal mismatch")
		)
		
		zombie.take_damage(25.0)
		assert(zombie.current_health == 25.0, "Health should be 25 after taking 25 damage")
		assert(zombie.is_dead == false, "Zombie should still be alive")
		
		zombie.take_damage(30.0)
		assert(zombie.current_health == 0.0, "Health should clamp to 0")
		assert(zombie.is_dead == true, "Zombie should be marked dead")
		assert(death_signaled[0] == true, "zombie_died signal not emitted")
		print("Zombie damage & death signal: PASS")
		
		dummy_player.queue_free()
		zombie.queue_free()
		
		# Test all 7 New Scary Zombie Variants + Audio Assets + Player Edge Bonuses
		var expected_scary_variants := [
			{"type": 6, "name": "SCREAMER", "sfx": "res://assets/audio/sfx_screamer.wav"},
			{"type": 7, "name": "STALKER", "sfx": "res://assets/audio/sfx_stalker.wav"},
			{"type": 8, "name": "LEAPER", "sfx": "res://assets/audio/sfx_leaper.wav"},
			{"type": 9, "name": "BRUTE", "sfx": "res://assets/audio/sfx_brute.wav"},
			{"type": 10, "name": "PARASITE", "sfx": "res://assets/audio/sfx_parasite.wav"},
			{"type": 11, "name": "BUTCHER", "sfx": "res://assets/audio/sfx_butcher.wav"},
			{"type": 12, "name": "PHANTOM", "sfx": "res://assets/audio/sfx_phantom.wav"}
		]
		for v in expected_scary_variants:
			assert(FileAccess.file_exists(v["sfx"]), "Missing scary zombie audio file: " + str(v["sfx"]))
			var sz = zombie_scene.instantiate()
			add_child(sz)
			sz.configure_type(int(v["type"]))
			assert(sz.get_type_name() == v["name"], "Scary zombie type name mismatch for " + str(v["name"]))
			assert(sz.max_health > 0.0, "Scary zombie max_health must be positive")
			sz.queue_free()
		print("7 Scary Zombie Variants & Audio Files: PASS")
		
		print("ALL ZOMBIE TESTS PASSED!")
		get_tree().quit(0)

class DummyPlayer extends Node2D:
	var damage_received: float = 0.0
	var is_dead: bool = false
	func take_damage(amount: float) -> void:
		damage_received += amount
