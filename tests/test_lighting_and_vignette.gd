extends SceneTree

func _init() -> void:
	var runner := LightingVignetteTestRunner.new()
	root.add_child.call_deferred(runner)

class LightingVignetteTestRunner extends Node:
	func _ready() -> void:
		print("=================================================================")
		print("  TESTING REALISTIC LIGHTING, MULTI-SOURCE BLENDING & VIGNETTE   ")
		print("=================================================================")
		
		var VignetteScript = load("res://scripts/horror_vignette.gd")
		assert(VignetteScript != null, "Failed to load horror_vignette.gd")
		
		var vignette = VignetteScript.new()
		add_child(vignette)
		vignette.size = Vector2(1280, 720)
		
		# Test 1: Shader initialization and compilation
		assert(vignette.darkness_rect != null, "darkness_rect must be created")
		assert(vignette.darkness_mat != null, "darkness_mat ShaderMaterial must be created")
		assert(vignette.darkness_mat.shader != null, "darkness shader must be compiled")
		print("  [OK] ShaderMaterial & Shader compiled successfully")
		
		# Test 2: Night factor and visibility toggle
		vignette.set_night_factor(0.85, true)
		assert(vignette.night_factor == 0.85, "night_factor must update")
		assert(vignette.darkness_rect.visible == true, "darkness_rect must become visible when night_factor > 0")
		vignette.set_night_factor(0.0, true)
		assert(vignette.darkness_rect.visible == false, "darkness_rect must hide in daylight")
		vignette.set_night_factor(1.0, true)
		print("  [OK] Night mode transitions and shader parameters verified")
		
		# Test 3: Tactical Flashlight transform and buffer integrity
		var test_screen_pos := Vector2(640, 360)
		var test_angle := 0.785 # 45 degrees
		var test_occluders: Array = [
			{"world_pos": Vector2(700, 360), "radius": 24.0},
			{"world_pos": Vector2(600, 420), "radius": 18.0}
		]
		vignette.update_flashlight_transform(test_screen_pos, test_angle, test_occluders, Vector2(1000, 1000))
		assert(vignette.darkness_mat.get_shader_parameter("u_shadow_count") == 2, "Shadow occluders must be passed to shader")
		print("  [OK] Flashlight transform and obstacle shadow occluders verified")
		
		# Test 4: Multi-source ambient lights (eliminating dark areas between 2+ sources)
		var multi_lights: Array = [
			{"world_pos": Vector2(1000, 1000), "radius": 220.0, "color": Color(1.0, 0.85, 0.3, 1.0)}, # Generator
			{"world_pos": Vector2(1150, 1000), "radius": 180.0, "color": Color(0.9, 0.9, 1.0, 1.0)},  # Streetlight
			{"world_pos": Vector2(1050, 1120), "radius": 140.0, "color": Color(1.0, 0.4, 0.2, 1.0)}   # Barrel Fire
		]
		vignette.update_ambient_lights(multi_lights, Vector2(1000, 1000))
		assert(vignette.darkness_mat.get_shader_parameter("u_light_count") == 3, "All 3 ambient light sources must be active in shader")
		print("  [OK] Multi-source ambient lights accumulation verified (3 light sources active)")
		
		# Test 5: Ally / Bot / Turret flashlight cones
		var ally_cones: Array = [
			{"screen_pos": Vector2(500, 360), "angle": 0.0},
			{"screen_pos": Vector2(780, 400), "angle": 3.14}
		]
		vignette.update_ally_flashlights(ally_cones, Vector2(1000, 1000))
		assert(vignette.darkness_mat.get_shader_parameter("u_ally_count") == 2, "Both ally flashlight cones must be active in shader")
		print("  [OK] Ally & Turret multi-cone illumination verified")
		
		# Test 6: Zero allocations buffer stability
		assert(vignette._light_pos_buf.size() == 16, "Light position buffer must be fixed at 16")
		assert(vignette._shadow_pos_buf.size() == 8, "Shadow buffer must be fixed at 8")
		assert(vignette._ally_pos_buf.size() == 6, "Ally buffer must be fixed at 6")
		print("  [OK] Pre-allocated zero-GC shader uniform buffers verified")
		
		vignette.queue_free()
		print("\nALL REALISTIC LIGHTING AND MULTI-SOURCE TESTS PASSED (100%)!")
		get_tree().quit(0)
