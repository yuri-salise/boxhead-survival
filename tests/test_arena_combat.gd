extends SceneTree

func _init():
	var runner = ArenaCombatTestRunner.new()
	root.add_child.call_deferred(runner)

class ArenaCombatTestRunner extends Node2D:
	func _ready():
		print("Testing Arena Combat Integration in Level 01...")
		var level_scene = load("res://scenes/levels/level_01.tscn")
		assert(level_scene != null, "Failed to load level_01.tscn")
		
		var level = level_scene.instantiate()
		add_child(level)
		
		# Verify key components exist
		assert(level.player != null, "Player actor must exist in level_01")
		assert(level.player.is_in_group("players"), "Player must be in 'players' group")
		assert(level.health_bar != null, "Health bar HUD must exist")
		assert(level.kills_label != null, "Kills counter HUD must exist")
		assert(level.death_panel != null, "Death panel must exist")
		assert(level.death_panel.visible == false, "Death panel should initially be hidden")
		print("Arena structural components: PASS")
		
		# Test kill counter increment
		var init_kills = level.kills_count
		level.spawn_test_zombie_at(Vector2(500, 360))
		assert(level.zombie_container.get_child_count() > 0, "Zombie should be spawned in container")
		var zombie = level.zombie_container.get_child(0)
		
		# Simulate zombie kill
		zombie.take_damage(zombie.max_health)
		assert(level.kills_count == init_kills + 1, "Kill counter should increment by 1 on zombie death")
		print("Kill counter logic: PASS")
		
		# Test player death triggers death panel
		level.player.take_damage(level.player.max_health)
		assert(level.player.is_dead == true, "Player should be dead")
		assert(level.death_panel.visible == true, "Death panel should be visible after player death")
		print("Player death panel trigger: PASS")
		
		level.queue_free()
		
		print("ALL ARENA COMBAT TESTS PASSED!")
		get_tree().quit(0)
