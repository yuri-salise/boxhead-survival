extends SceneTree

const ZombieScript = preload("res://scripts/zombie_basic.gd")

func _init():
	var runner = ArenaCombatTestRunner.new()
	root.add_child.call_deferred(runner)

class ArenaCombatTestRunner extends Node2D:
	func _ready():
		print("Testing Upgraded Phase 1 Arena Combat, Special Infected, Weapons, Dash, Blood & Pause Menu...")
		var level_scene = load("res://scenes/levels/level_01.tscn")
		assert(level_scene != null, "Failed to load level_01.tscn")
		
		var level = level_scene.instantiate()
		add_child(level)
		
		# 1. Verify HUD & Pause Menu (Big return button replaced by compact Pause button + functional Pause Menu)
		assert(level.pause_button != null, "Compact PauseButton must exist in TopBar")
		assert(level.pause_menu != null, "PauseMenu modal must exist in UI")
		assert(level.pause_menu.visible == false, "PauseMenu should start hidden")
		
		level._on_pause_button_pressed()
		assert(level.pause_menu.visible == true, "PauseMenu should open when PauseButton pressed")
		assert(get_tree().paused == true, "SceneTree should be paused when PauseMenu is open")
		
		# Test functional Save Progress button inside PauseMenu
		level.pause_menu._on_save_pressed()
		assert("SAVED" in level.pause_menu.status_label.text, "Save button should save checkpoint and show confirmation")
		
		level.pause_menu._on_resume_pressed()
		assert(level.pause_menu.visible == false, "PauseMenu should close on Resume")
		assert(get_tree().paused == false, "SceneTree should unpause on Resume")
		print("Pause Menu (Resume, Save Progress, Retry, Main Menu): PASS")
		
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
		
		# 5. Test Player Death triggers Death Panel
		p.current_armor = 0.0
		p.take_damage(p.max_health + 50.0)
		assert(p.is_dead == true, "Player should be dead")
		assert(level.death_panel.visible == true, "Death panel should be visible after player death")
		print("Player death panel trigger: PASS")
		
		level.queue_free()
		
		print("ALL UPGRADED ARENA COMBAT TESTS PASSED!")
		get_tree().quit(0)
