extends SceneTree

func _init():
	var runner = GraphicsSettingsTestRunner.new()
	runner.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(runner)

class GraphicsSettingsTestRunner extends Node:
	func _ready():
		print("Testing Graphics Quality, Resolution Scale, Fullscreen & In-Game Pause Settings...")
		
		var GameStateScript = load("res://autoload/game_state.gd")
		var gs = GameStateScript.new()
		add_child(gs)
		
		# 1. Test GameState methods & cyclers
		gs.set_graphics_quality(0)
		assert(gs.graphics_quality == 0, "Graphics quality must be set to 0 (Low / Battery Saver)")
		var next_q: int = gs.cycle_graphics_quality()
		assert(next_q == 1 and gs.graphics_quality == 1, "Cycling graphics quality from 0 must yield 1 (Medium / Balanced)")
		next_q = gs.cycle_graphics_quality()
		assert(next_q == 2 and gs.graphics_quality == 2, "Cycling graphics quality from 1 must yield 2 (High / Ultra)")
		next_q = gs.cycle_graphics_quality()
		assert(next_q == 0 and gs.graphics_quality == 0, "Cycling graphics quality from 2 must wrap to 0")
		
		gs.set_resolution_scale(1.0)
		assert(is_equal_approx(gs.resolution_scale, 1.0), "Resolution scale set to 1.0")
		var next_scale: float = gs.cycle_resolution_scale()
		assert(is_equal_approx(next_scale, 1.25), "Cycling resolution from 1.0 must yield 1.25")
		next_scale = gs.cycle_resolution_scale()
		assert(is_equal_approx(next_scale, 0.75), "Cycling resolution from 1.25 must yield 0.75")
		next_scale = gs.cycle_resolution_scale()
		assert(is_equal_approx(next_scale, 1.0), "Cycling resolution from 0.75 must wrap to 1.0")
		
		gs.set_fullscreen(false)
		assert(gs.fullscreen == false, "Fullscreen set to false")
		var is_fs: bool = gs.toggle_fullscreen()
		assert(is_fs == true and gs.fullscreen == true, "Toggling fullscreen must yield true")
		is_fs = gs.toggle_fullscreen()
		assert(is_fs == false and gs.fullscreen == false, "Toggling fullscreen again must yield false")
		
		# 2. Test persistence across file save and reload
		gs.set_graphics_quality(2)
		gs.set_resolution_scale(0.75)
		gs.set_fullscreen(true)
		gs.save_progress()
		
		var gs_reloaded = GameStateScript.new()
		add_child(gs_reloaded)
		assert(gs_reloaded.graphics_quality == 2, "Reloaded GameState must preserve graphics_quality == 2")
		assert(is_equal_approx(gs_reloaded.resolution_scale, 0.75), "Reloaded GameState must preserve resolution_scale == 0.75")
		assert(gs_reloaded.fullscreen == true, "Reloaded GameState must preserve fullscreen == true")
		print("GameState settings & persistence: PASS")
		
		# Restore defaults
		gs_reloaded.set_graphics_quality(1)
		gs_reloaded.set_resolution_scale(1.0)
		gs_reloaded.set_fullscreen(false)
		gs_reloaded.save_progress()
		
		# 3. Test Main Menu Settings Dialog Controls
		var main_menu_scene = load("res://scenes/ui/main_menu.tscn")
		var menu = main_menu_scene.instantiate()
		get_tree().root.add_child(menu)
		
		assert(menu.graphics_toggle_button != null, "Main menu must have GraphicsToggle button")
		assert(menu.resolution_toggle_button != null, "Main menu must have ResolutionToggle button")
		assert(menu.screen_mode_button != null, "Main menu must have ScreenModeToggle button")
		
		menu._on_settings_button_pressed()
		assert(menu.settings_dialog.visible == true, "Settings dialog must open")
		
		menu._on_graphics_toggle_pressed()
		assert("ULTRA" in menu.graphics_toggle_button.text or "HIGH" in menu.graphics_toggle_button.text or "BATTERY" in menu.graphics_toggle_button.text or "BALANCED" in menu.graphics_toggle_button.text, "Graphics button text must reflect quality")
		
		menu._on_resolution_toggle_pressed()
		assert("%" in menu.resolution_toggle_button.text, "Resolution button text must reflect percentage")
		
		menu._hide_all_dialogs()
		assert(menu.settings_dialog.visible == false, "Settings dialog must close")
		menu.queue_free()
		print("Main Menu Settings Dialog UI: PASS")
		
		# 4. Test In-Game Pause Menu Settings Controls
		var pause_menu_scene = load("res://scenes/ui/pause_menu.tscn")
		var pause_menu = pause_menu_scene.instantiate()
		get_tree().root.add_child(pause_menu)
		
		assert(pause_menu.graphics_button != null, "Pause menu must have GraphicsButton")
		assert(pause_menu.resolution_button != null, "Pause menu must have ResolutionButton")
		
		pause_menu.open_pause_menu()
		assert(pause_menu.visible == true, "Pause menu must be visible when opened")
		
		pause_menu._on_graphics_pressed()
		assert("GRAPHICS:" in pause_menu.graphics_button.text, "Graphics button in pause menu must update text")
		
		pause_menu._on_resolution_pressed()
		assert("RESOLUTION:" in pause_menu.resolution_button.text, "Resolution button in pause menu must update text")
		
		pause_menu.close_pause_menu()
		assert(pause_menu.visible == false, "Pause menu must close")
		pause_menu.queue_free()
		print("In-Game Pause Menu Graphics & Resolution Settings: PASS")
		
		gs.queue_free()
		gs_reloaded.queue_free()
		
		print("ALL GRAPHICS & RESOLUTION SETTINGS TESTS PASSED!")
		get_tree().quit()
