extends SceneTree

func _init():
	var runner = ResultScreenTestRunner.new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(runner)

class ResultScreenTestRunner extends Node:
	func _ready():
		print("Testing ResultScreen Victory & Defeat Modals...")
		get_tree().root.size = Vector2i(1280, 720)
		
		var res_scene = load("res://scenes/ui/result_screen.tscn")
		assert(res_scene != null, "Failed to load res://scenes/ui/result_screen.tscn")
		
		var res = res_scene.instantiate()
		get_tree().root.add_child(res)
		await get_tree().process_frame
		
		assert(res.visible == false, "ResultScreen should start hidden")
		
		# 1. Test Victory state on Level 1
		res.show_victory(1, 540, 30, 3)
		assert(res.visible == true, "ResultScreen should be visible on show_victory")
		assert("SECTOR CLEARED" in res.outcome_title.text, "Victory title should say SECTOR CLEARED")
		assert("3/3" in res.stars_label.text, "Victory stars should show 3/3")
		assert("30" in res.stats_label.text and "540" in res.stats_label.text, "Stats label should show kills and score")
		assert(res.next_level_button.visible == true, "NextLevelButton must be visible on Level 1 victory")
		
		var next_lvl_clicked := [-1]
		res.next_level_requested.connect(func(nxt): next_lvl_clicked[0] = nxt)
		res.next_level_button.pressed.emit()
		assert(next_lvl_clicked[0] == 2, "Clicking NextLevelButton on Level 1 should request Level 2")
		print("ResultScreen Victory & Next Level routing: PASS")
		
		# 2. Test Victory state on Final Level 5 hides NextLevelButton
		res.show_victory(5, 900, 75, 3)
		assert(res.next_level_button.visible == false, "NextLevelButton must be hidden on final Level 5")
		
		# 3. Test Defeat state
		res.show_defeat(1, 120, 8, "OUTPOST OVERRUN")
		assert(res.visible == true, "ResultScreen should be visible on show_defeat")
		assert(res.outcome_title.text == "OUTPOST OVERRUN", "Defeat title should match reason")
		assert(res.next_level_button.visible == false, "NextLevelButton must be hidden on defeat")
		
		var retry_clicked := [false]
		res.retry_requested.connect(func(): retry_clicked[0] = true)
		res.retry_button.pressed.emit()
		assert(retry_clicked[0] == true, "RetryButton should emit retry_requested")
		print("ResultScreen Defeat & Retry routing: PASS")
		
		res.queue_free()
		print("ALL RESULT SCREEN TESTS PASSED!")
		get_tree().quit(0)
