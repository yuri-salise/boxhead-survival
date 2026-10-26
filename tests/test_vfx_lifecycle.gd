extends SceneTree

func _init():
	var runner = VFXLifecycleTestRunner.new()
	root.add_child.call_deferred(runner)

class VFXLifecycleTestRunner extends Node:
	var flash_node: Node2D = null
	var blood_node: Node2D = null
	var state := 0
	var timer := 0.0
	
	func _ready():
		print("Starting Task 17: Visual FX & Lifecycle Auto-Free Tests...")
		var flash_scene = load("res://scenes/effects/muzzle_flash.tscn")
		assert(flash_scene != null, "MuzzleFlash scene must load")
		flash_node = flash_scene.instantiate()
		flash_node.lifetime = 0.06
		add_child(flash_node)
		
		var blood_scene = load("res://scenes/effects/blood_splatter.tscn")
		assert(blood_scene != null, "BloodSplatter scene must load")
		blood_node = blood_scene.instantiate()
		blood_node.lifetime = 0.08
		blood_node.setup(Vector2.RIGHT, Color(0.7, 0.1, 0.1), 10)
		add_child(blood_node)
		
		assert(is_instance_valid(flash_node), "Muzzle flash must be valid after adding")
		assert(is_instance_valid(blood_node), "Blood splatter must be valid after adding")
		print("VFX Instantiation & Setup: PASS")
		state = 1
	
	func _process(delta: float):
		if state == 1:
			timer += delta
			if timer >= 0.20:
				assert(not is_instance_valid(flash_node) or flash_node.is_queued_for_deletion(), "Muzzle flash must auto-free after lifetime")
				assert(not is_instance_valid(blood_node) or blood_node.is_queued_for_deletion(), "Blood splatter must auto-free after lifetime")
				print("VFX Auto-Free Lifecycle & Memory Cleanup: PASS")
				print("ALL VFX LIFECYCLE TESTS PASSED!")
				get_tree().quit(0)
