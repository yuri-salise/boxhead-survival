extends SceneTree

func _init():
	var runner = TouchControlsTestRunner.new()
	root.add_child.call_deferred(runner)

class TouchControlsTestRunner extends Node:
	func _ready():
		print("Starting Task 11: TouchControls Dual Virtual Sticks & Action Buttons Tests...")
		var touch_scene = load("res://scenes/ui/touch_controls.tscn")
		assert(touch_scene != null, "Failed to load res://scenes/ui/touch_controls.tscn")
		
		var controls = touch_scene.instantiate()
		add_child(controls)
		if not controls.is_node_ready():
			await controls.ready
		
		assert(controls.dash_btn != null, "Dash button must exist")
		assert(controls.grenade_btn != null, "Grenade button must exist")
		assert(controls.weapon_btn != null, "Weapon switch button must exist")
		print("TouchControls Node Structure: PASS")
		
		# 1. Test movement stick input
		var ev_move_down = InputEventScreenTouch.new()
		ev_move_down.index = 0
		ev_move_down.pressed = true
		ev_move_down.position = controls.left_center + Vector2(40.0, 0.0) # Drag right
		controls._input(ev_move_down)
		assert(controls.move_vector.x > 0.0, "Move vector x should be positive when dragging right")
		assert(controls.is_using_touch_input() == true, "Should report touch input active")
		
		# Release move stick
		var ev_move_up = InputEventScreenTouch.new()
		ev_move_up.index = 0
		ev_move_up.pressed = false
		ev_move_up.position = controls.left_center + Vector2(40.0, 0.0)
		controls._input(ev_move_up)
		assert(controls.move_vector == Vector2.ZERO, "Move vector must reset to ZERO on release")
		print("Virtual Move Stick: PASS")
		
		# 2. Test aim stick input
		var ev_aim_down = InputEventScreenTouch.new()
		ev_aim_down.index = 1
		ev_aim_down.pressed = true
		ev_aim_down.position = controls.right_center + Vector2(0.0, -45.0) # Aim up
		controls._input(ev_aim_down)
		assert(controls.aim_vector.y < 0.0, "Aim vector y should be negative when aiming up")
		assert(controls.is_firing == true, "Aim stick touch must activate is_firing")
		
		# Release aim stick
		var ev_aim_up = InputEventScreenTouch.new()
		ev_aim_up.index = 1
		ev_aim_up.pressed = false
		controls._input(ev_aim_up)
		assert(controls.is_firing == false, "Aim stick release must clear is_firing")
		print("Virtual Aim & Shoot Stick: PASS")
		
		# 3. Test Action Buttons
		var dash_fired := [false]
		controls.dash_pressed.connect(func(): dash_fired[0] = true)
		controls.dash_btn.pressed.emit()
		assert(dash_fired[0] == true, "Dash button signal must propagate to controls.dash_pressed")
		
		var frag_fired := [false]
		controls.grenade_pressed.connect(func(): frag_fired[0] = true)
		controls.grenade_btn.pressed.emit()
		assert(frag_fired[0] == true, "Frag button signal must propagate to controls.grenade_pressed")
		
		var switch_fired := [false]
		controls.switch_weapon_pressed.connect(func(): switch_fired[0] = true)
		controls.weapon_btn.pressed.emit()
		assert(switch_fired[0] == true, "Switch weapon button signal must propagate to controls.switch_weapon_pressed")
		print("Touch Action Buttons (DASH, FRAG, GUN): PASS")
		
		# 4. Cooldown update display
		controls.set_dash_cooldown(1.2, 1.4)
		assert(controls.dash_btn.disabled == true, "Dash button must be disabled during cooldown")
		controls.set_dash_cooldown(0.0, 1.4)
		assert(controls.dash_btn.disabled == false, "Dash button must be re-enabled when ready")
		print("Button Cooldown State: PASS")
		
		controls.queue_free()
		print("ALL TOUCH CONTROLS TESTS PASSED!")
		get_tree().quit(0)
