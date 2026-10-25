extends SceneTree

func _init():
	var runner = ProjectileTestRunner.new()
	root.add_child.call_deferred(runner)

class ProjectileTestRunner extends Node2D:
	func _ready():
		print("Testing Projectile System...")
		var proj_scene = load("res://scenes/actors/projectile.tscn")
		assert(proj_scene != null, "Failed to load projectile.tscn")
		
		var shooter = Node2D.new()
		add_child(shooter)
		shooter.position = Vector2(100, 100)
		
		var proj = proj_scene.instantiate()
		add_child(proj)
		proj.init(Vector2(100, 100), Vector2.RIGHT, 500.0, 25.0, shooter)
		
		# Verify initialization
		assert(proj.position == Vector2(100, 100), "Initial position mismatch")
		assert(proj.direction == Vector2.RIGHT, "Direction mismatch")
		assert(proj.speed == 500.0, "Speed mismatch")
		assert(proj.damage == 25.0, "Damage mismatch")
		assert(proj.shooter == shooter, "Shooter reference mismatch")
		print("Projectile initialization: PASS")
		
		# Test target hit
		var dummy_target = DummyTarget.new()
		add_child(dummy_target)
		dummy_target.position = Vector2(150, 100)
		
		var hit_detected = [false]
		proj.hit_target.connect(func(target, dmg):
			hit_detected[0] = true
			assert(target == dummy_target, "Target mismatch in signal")
			assert(dmg == 25.0, "Damage mismatch in signal")
		)
		
		proj._on_body_entered(dummy_target)
		assert(dummy_target.damage_received == 25.0, "Target did not take expected damage")
		assert(hit_detected[0] == true, "hit_target signal not emitted")
		print("Target damage delivery & signal: PASS")
		
		# Test shooter collision ignored
		dummy_target.damage_received = 0.0
		proj._on_body_entered(shooter)
		assert(dummy_target.damage_received == 0.0, "Shooter should not take damage from own projectile")
		print("Shooter safety: PASS")
		
		print("ALL PROJECTILE TESTS PASSED!")
		get_tree().quit(0)

class DummyTarget extends CharacterBody2D:
	var damage_received: float = 0.0
	func take_damage(amount: float) -> void:
		damage_received += amount
