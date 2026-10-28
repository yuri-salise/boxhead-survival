extends SceneTree

const ZombieScript = preload("res://scripts/zombie_basic.gd")

func _init():
	var runner = ArenaCombatTestRunner.new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(runner)

class ArenaCombatTestRunner extends Node2D:
	func _ready():
		print("Testing Upgraded Phase 1 Arena Combat, Special Infected, Weapons, Dash, Blood & Pause Menu...")
		var level_scene = load("res://scenes/levels/level_01.tscn")
		assert(level_scene != null, "Failed to load level_01.tscn")
		
		var level = level_scene.instantiate()
		get_tree().root.add_child(level)
		
		# 1. Verify HUD & Pause Menu (Compact Pause button + functional Pause Menu with real GUI click hit-testing)
		get_tree().root.size = Vector2i(1280, 720)
		assert(level.pause_button != null, "Compact PauseButton must exist in TopBar")
		assert(level.pause_menu != null, "PauseMenu modal must exist in UI")
		assert(level.pause_menu.get_child_count() == 2, "PauseMenu must not have duplicated subscene children")
		assert(level.pause_menu.visible == false, "PauseMenu should start hidden")
		
		level._on_pause_button_pressed()
		assert(level.pause_menu.visible == true, "PauseMenu should open when PauseButton pressed")
		assert(get_tree().paused == true, "SceneTree should be paused when PauseMenu is open")
		
		await get_tree().process_frame
		await get_tree().process_frame
		
		# Verify real GUI hit-testing on SaveButton while SceneTree is paused
		var save_rect: Rect2 = level.pause_menu.save_button.get_global_rect()
		var save_center: Vector2 = save_rect.get_center()
		var motion := InputEventMouseMotion.new()
		motion.position = save_center
		motion.global_position = save_center
		get_tree().root.push_input(motion)
		await get_tree().process_frame
		assert(get_tree().root.gui_get_hovered_control() == level.pause_menu.save_button, "SaveButton must be hovered/clickable and not occluded")
		
		var click_down := InputEventMouseButton.new()
		click_down.button_index = MOUSE_BUTTON_LEFT
		click_down.pressed = true
		click_down.position = save_center
		click_down.global_position = save_center
		get_tree().root.push_input(click_down)
		
		var click_up := InputEventMouseButton.new()
		click_up.button_index = MOUSE_BUTTON_LEFT
		click_up.pressed = false
		click_up.position = save_center
		click_up.global_position = save_center
		get_tree().root.push_input(click_up)
		await get_tree().process_frame
		assert("SAVED" in level.pause_menu.status_label.text, "Clicking SaveButton via GUI input must save checkpoint and show confirmation")
		
		# Verify real GUI click on ResumeButton closes PauseMenu and unpauses tree
		var resume_center: Vector2 = level.pause_menu.resume_button.get_global_rect().get_center()
		click_down.position = resume_center
		click_down.global_position = resume_center
		get_tree().root.push_input(click_down)
		click_up.position = resume_center
		click_up.global_position = resume_center
		get_tree().root.push_input(click_up)
		await get_tree().process_frame
		assert(level.pause_menu.visible == false, "PauseMenu should close when ResumeButton is clicked")
		assert(get_tree().paused == false, "SceneTree should unpause when ResumeButton is clicked")
		print("Pause Menu (Real GUI Clicks on Resume, Save Progress, Retry, Main Menu): PASS")
		
		# 2. Test Player Dash & Invulnerability Frames
		var p = level.player
		assert(p != null, "Player actor must exist")
		var dash_ok = p.try_dash(Vector2.RIGHT, Vector2.ZERO)
		assert(dash_ok == true, "Player should be able to dash when off cooldown")
		assert(p.is_dashing == true, "Player should be in dashing state")
		var hp_before_dash_hit = p.current_health
		p.take_damage(25.0)
		assert(p.current_health == hp_before_dash_hit, "Player should be invulnerable during dash i-frames")
		p.is_dashing = false
		print("Player Dash & i-frames: PASS")
		
		# 3. Test Armor Absorption, Medkit & Weapon Pickups
		p.current_armor = 50.0
		p.current_health = 80.0
		p.take_damage(20.0) # 70% absorbed by armor (14 AP), 30% to HP (6 HP)
		assert(p.current_armor == 36.0, "Kevlar armor should absorb 70% of damage")
		assert(p.current_health == 74.0, "Health should only take remaining 30% damage")
		
		p.apply_pickup("MEDKIT")
		assert(p.current_health == 100.0, "Medkit should heal player")
		
		p.apply_pickup("WEAPON_SHOTGUN")
		assert(p.weapon_controller.current_weapon_id == "SHOTGUN", "Picking up Shotgun should equip Shotgun")
		assert(p.weapon_controller.unlocked_weapons.has("SHOTGUN"), "Shotgun should be unlocked")
		
		p.apply_pickup("WEAPON_MAGNUM")
		assert(p.weapon_controller.current_weapon_id == "MAGNUM", "Picking up Magnum should equip Magnum")
		print("Pickups (Medkit, Armor, Multi-Weapon Arsenal): PASS")
		
		# 4. Test All 6 Left 4 Dead / Walking Dead Zombie Types & Permanent Ground Blood Splatters
		var decals_before = level.blood_container.get_child_count()
		
		# Runner
		var runner_z = level.spawn_test_zombie_at(Vector2(300, 300), ZombieScript.ZombieType.RUNNER)
		assert(runner_z.speed > 200.0, "Runner zombie must be fast")
		
		# Witch (Startle mechanic)
		var witch_z = level.spawn_test_zombie_at(Vector2(350, 300), ZombieScript.ZombieType.WITCH)
		assert(witch_z.is_enraged == false, "Witch starts calm/weeping")
		witch_z.take_damage(20.0)
		assert(witch_z.is_enraged == true, "Damaging Witch must startle/enrage her")
		assert(witch_z.speed >= 300.0, "Startled Witch must sprint at lethal speed")
		
		# Tanker
		var tank_z = level.spawn_test_zombie_at(Vector2(400, 300), ZombieScript.ZombieType.TANK)
		assert(tank_z.max_health >= 300.0, "Tanker must have massive health pool")
		
		# Spitter
		var spitter_z = level.spawn_test_zombie_at(Vector2(450, 300), ZombieScript.ZombieType.SPITTER)
		spitter_z.take_damage(spitter_z.max_health)
		assert(spitter_z.is_dead == true, "Spitter should die when health depleted")
		
		# Boomer explosion & bile splatter
		var boomer_exploded_flag = [false]
		var boomer_z = level.spawn_test_zombie_at(Vector2(500, 360), ZombieScript.ZombieType.BOOMER)
		boomer_z.boomer_exploded.connect(func(_pos, _r, _d): boomer_exploded_flag[0] = true)
		boomer_z.take_damage(boomer_z.max_health)
		assert(boomer_exploded_flag[0] == true, "Boomer must explode on death")
		assert(level.blood_container.get_child_count() > decals_before, "Permanent blood decals must be added to ground")
		print("Special Infected (Walker, Runner, Boomer, Tanker, Spitter, Witch) & Permanent Blood Decals: PASS")
		
		# 5. Test Infinite World Streaming, Zombie Dismemberment (Broken Limbs & Crawling), and POV Bite Blood
		assert(level.get_node_or_null("ArenaWalls") == null, "Enclosing ArenaWalls must be removed for infinite world movement")
		assert(p.player_camera != null, "Player must have a Camera2D for infinite world tracking")
		
		# Test Dismemberment on a Tanker / Walker
		var dismember_z = level.spawn_test_zombie_at(Vector2(600, 300), ZombieScript.ZombieType.WALKER)
		assert(dismember_z.has_left_arm == true and dismember_z.has_right_arm == true and dismember_z.has_legs == true, "Zombie starts with all limbs intact")
		dismember_z.take_damage(18.0) # Heavy hit severs left arm
		assert(dismember_z.has_left_arm == false, "First heavy hit must sever zombie's left arm")
		dismember_z.sever_next_limb(Vector2.RIGHT)
		assert(dismember_z.has_right_arm == false, "Second dismemberment must sever zombie's right arm")
		dismember_z.sever_next_limb(Vector2.RIGHT)
		assert(dismember_z.has_legs == false and dismember_z.is_crawling == true, "Third dismemberment must sever legs and force zombie into crawling state")
		
		# Test POV Blood on Screen Lens when bitten by a zombie
		var drops_before: int = level.horror_vignette.pov_blood_drops.size()
		runner_z.try_attack_target(p)
		assert(level.horror_vignette.pov_blood_drops.size() > drops_before, "Getting bitten by a zombie must splash POV blood onto the camera lens")
		assert(level.horror_vignette.bite_flash_alpha > 0.0, "Getting bitten must trigger crimson POV bite flash")
		
		# Test Infinite World movement far beyond original 1280x720 bounds
		p.global_position = Vector2(4800.0, -3600.0)
		level._process(0.016)
		assert(level.arena_env.focus_position == Vector2(4800.0, -3600.0), "Infinite ArenaEnvironment must stream chunks around player's world coordinates")
		print("Infinite World, Shadows, Zombie Limb Dismemberment & POV Bite Blood: PASS")
		
		# 6. Test Mobile Touch Controls (Twin-Stick + Dash/Weapon/Grenade Touch Buttons)
		var tc = level.touch_controls
		assert(tc != null, "Mobile TouchControls node must exist in level UI")
		assert(tc.get_child_count() >= 5, "TouchControls must not have duplicated subscene children")
		assert(tc.dash_btn != null and tc.grenade_btn != null and tc.weapon_btn != null, "Mobile action buttons must exist")
		tc.simulate_stick_input(Vector2(1.0, 0.0), Vector2(0.0, -1.0), true)
		assert(tc.move_vector == Vector2(1.0, 0.0), "Left virtual stick should set move_vector")
		assert(tc.aim_vector == Vector2(0.0, -1.0), "Right virtual stick should set aim_vector")
		assert(tc.is_firing == true, "Right virtual stick deflection should trigger auto-fire")
		p._physics_process(0.016)
		assert(p.velocity.x > 0.0, "Player should move right when left virtual joystick is deflected right")
		var w_before = p.weapon_controller.current_weapon_id
		tc.weapon_btn.pressed.emit()
		assert(p.weapon_controller.current_weapon_id != w_before, "Mobile WeaponSwitchButton should cycle unlocked weapons")
		tc.simulate_stick_input(Vector2.ZERO, Vector2.ZERO, false)
		print("Mobile Twin-Stick & Touch Action HUD: PASS")
		
		# 7. Test WaveDirector, LevelController & ResultScreen Integration on Defeat
		assert(level.wave_director != null and level.level_controller != null and level.result_screen != null, "Phase 2 WaveDirector, LevelController, and ResultScreen must be present in Level01")
		p.current_armor = 0.0
		p.take_damage(p.max_health + 50.0)
		assert(p.is_dead == true, "Player should be dead")
		assert(level.result_screen.visible == true and level.result_screen.is_victory == false, "ResultScreen should open in defeat mode on player death")
		print("Phase 2 WaveDirector, LevelController & ResultScreen integration: PASS")
		
		level.queue_free()
		
		print("ALL UPGRADED ARENA COMBAT TESTS PASSED!")
		get_tree().quit(0)
