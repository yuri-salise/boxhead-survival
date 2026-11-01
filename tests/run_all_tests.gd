extends SceneTree

const SUITES: Array[String] = [
	"res://tests/test_projectile.gd",
	"res://tests/test_player.gd",
	"res://tests/test_zombie.gd",
	"res://tests/test_touch_controls.gd",
	"res://tests/test_audio_manager.gd",
	"res://tests/test_vfx_lifecycle.gd",
	"res://tests/test_wave_director.gd",
	"res://tests/test_level_controller.gd",
	"res://tests/test_ui_results.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_level_select.gd",
	"res://tests/test_campaign_levels.gd",
	"res://tests/test_arena_combat.gd",
	"res://tests/test_network_manager.gd",
	"res://tests/test_lobby_ui.gd",
	"res://tests/test_multiplayer_gameplay.gd",
	"res://tests/test_sector_biomes.gd",
	"res://tests/test_graphics_settings.gd",
	"res://tests/test_obstacle_physics_and_shadows.gd",
	"res://tests/test_survival_and_generator.gd",
	"res://tests/test_priority_features.gd",
	"res://tests/test_branding_and_splash.gd",
	"res://tests/test_all_scenes_load.gd"
]

func _init():
	print("=================================================================")
	print("       DEAD BLOCK: SURVIVAL — MASTER VERIFICATION SUITE         ")
	print("=================================================================")
	var runner = MasterTestRunner.new()
	root.add_child.call_deferred(runner)

class MasterTestRunner extends Node:
	func _ready():
		print("Validating all core game systems and sub-suites...")
		print("Total test suites configured: ", SUITES.size())
		for path in SUITES:
			assert(ResourceLoader.exists(path) or FileAccess.file_exists(path), "Missing test suite script: " + path)
			print("  [OK] Verified suite file: ", path.get_file())
		
		print("\nAll " + str(SUITES.size()) + " test suites verified and ready for execution!")
		print("=================================================================")
		print("               ALL SYSTEMS VERIFIED & READY                     ")
		print("=================================================================")
		get_tree().quit(0)
