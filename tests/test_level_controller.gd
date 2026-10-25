extends SceneTree

func _init():
	var runner = LevelControllerTestRunner.new()
	root.add_child.call_deferred(runner)

class LevelControllerTestRunner extends Node:
	func _ready():
		print("Testing Authoritative LevelController Objective Resolution...")
		var LevelControllerScript = load("res://scripts/level_controller.gd")
		assert(LevelControllerScript != null, "Failed to load res://scripts/level_controller.gd")
		
		var lc = LevelControllerScript.new()
		add_child(lc)
		lc.reset_state(1)
		lc.two_star_score = 200
		lc.three_star_score = 400
		
		var won_events: Array[Dictionary] = []
		var lost_events: Array[Dictionary] = []
		
		lc.level_won.connect(func(lvl, sc, kl, st):
			won_events.append({"level": lvl, "score": sc, "kills": kl, "stars": st})
		)
		lc.level_lost.connect(func(lvl, sc, kl, rsn):
			lost_events.append({"level": lvl, "score": sc, "kills": kl, "reason": rsn})
		)
		
		# 1. Record kills and resolve victory
		lc.record_kill(150)
		lc.record_kill(300)
		assert(lc.current_kills == 2 and lc.current_score == 450, "LevelController should track kills and score")
		
		lc.on_all_waves_completed(0.85)
		assert(won_events.size() == 1, "level_won must emit exactly once")
		assert(won_events[0]["stars"] == 3, "450 score + 85% HP should award 3 stars")
		
		# Ensure duplicate calls or post-win player death cannot re-trigger resolution
		lc.on_all_waves_completed(0.85)
		lc.on_all_players_dead("LATE HIT")
		assert(won_events.size() == 1 and lost_events.size() == 0, "Resolved level must ignore subsequent win/loss triggers")
		print("Victory resolution, star calculation & single-resolution lock: PASS")
		
		# 2. Reset and test defeat resolution
		lc.reset_state(2)
		lc.record_kill(50)
		lc.on_all_players_dead("OUTPOST OVERRUN")
		assert(lost_events.size() == 1, "level_lost must emit on player death")
		assert(lost_events[0]["level"] == 2 and lost_events[0]["score"] == 50, "Defeat payload must include level and score")
		lc.on_all_waves_completed(1.0)
		assert(won_events.size() == 1, "Defeated level must not emit level_won afterwards")
		print("Defeat resolution & lock: PASS")
		
		lc.queue_free()
		print("ALL LEVEL CONTROLLER TESTS PASSED!")
		get_tree().quit(0)
