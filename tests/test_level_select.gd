extends SceneTree

func _init():
	var runner = LevelSelectTestRunner.new()
	root.add_child.call_deferred(runner)

class LevelSelectTestRunner extends Node:
	func _ready():
		print("Testing ModeSelect & LevelSelect Progression, Locks, Night Mode & Achievements...")
		var mode_scene = load("res://scenes/ui/mode_select.tscn")
		assert(mode_scene != null, "Failed to load res://scenes/ui/mode_select.tscn")
		var mode_ui = mode_scene.instantiate()
		add_child(mode_ui)
		assert(mode_ui.solo_button != null and mode_ui.coop_button != null and mode_ui.night_button != null, "ModeSelect buttons must exist")
		mode_ui.queue_free()
		print("ModeSelect instantiation & controls: PASS")
		
		var GameStateScript = load("res://autoload/game_state.gd")
		var gs = GameStateScript.new()
		add_child(gs)
		gs.reset_progress()
		
		var lvl_scene = load("res://scenes/ui/level_select.tscn")
		assert(lvl_scene != null, "Failed to load res://scenes/ui/level_select.tscn")
		var lvl_ui = lvl_scene.instantiate()
		add_child(lvl_ui)
		lvl_ui.custom_game_state = gs
		lvl_ui.refresh_ui()
		
		# 1. Verify Level 1 unlocked and Levels 2-5 locked initially
		assert(lvl_ui.level_buttons[0].disabled == false, "Level 1 button must be enabled when unlocked_level == 1")
		assert(lvl_ui.level_buttons[1].disabled == true, "Level 2 button must be disabled when unlocked_level == 1")
		assert(lvl_ui.level_buttons[4].disabled == true, "Level 5 button must be disabled when unlocked_level == 1")
		
		# 2. Complete Level 1 without getting bit -> unlocks Level 2 & UNTOUCHABLE medal
		gs.complete_level(1, 480, 3, true, false)
		lvl_ui.refresh_ui()
		assert(lvl_ui.level_buttons[1].disabled == false, "Level 2 button must be enabled after completing Level 1")
		assert("★ UNTOUCHABLE" in lvl_ui.achievements_label.text, "Achievements label must show unlocked ★ UNTOUCHABLE medal")
		
		# 3. Toggle Night Mode button in LevelSelect
		assert(gs.night_mode_enabled == false, "Night mode starts false")
		lvl_ui._on_night_mode_toggled()
		assert(gs.night_mode_enabled == true, "Toggling NightModeButton must set night_mode_enabled=true")
		assert("ON" in lvl_ui.night_button.text, "NightModeButton text must show ON")
		print("LevelSelect locks, ★ UNTOUCHABLE medal display & Night Mode toggle: PASS")
		
		gs.reset_progress()
		gs.night_mode_enabled = false
		gs.save_progress()
		lvl_ui.queue_free()
		gs.queue_free()
		
		print("ALL MODE SELECT & LEVEL SELECT TESTS PASSED!")
		get_tree().quit(0)
