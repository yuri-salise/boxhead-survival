extends Node

signal progress_saved()
signal achievement_unlocked(achievement_id: String, title: String, description: String)
signal settings_changed(setting_name: String, value: Variant)

const SAVE_PATH: String = "user://save.cfg"
const SAVE_VERSION: int = 1
const TOTAL_LEVELS: int = 5

const ACHIEVEMENT_DEFS: Dictionary = {
	"UNTOUCHABLE": {
		"title": "UNTOUCHABLE",
		"desc": "Clear a quarantine sector without getting bit or taking damage."
	},
	"NIGHT_STALKER": {
		"title": "NIGHT STALKER",
		"desc": "Clear a quarantine sector in pitch-black Night Mode (Flashlight Only)."
	},
	"LIMB_RIPPER": {
		"title": "ANATOMY LESSON",
		"desc": "Sever 15 zombie limbs across your survival career."
	},
	"BOSS_SLAYER": {
		"title": "APEX PREDATOR",
		"desc": "Eliminate both a startling Witch and a hulking Tanker."
	},
	"ARSENAL_MASTER": {
		"title": "LOCKED & LOADED",
		"desc": "Unlock all 5 weapons in a single deployment."
	},
	"QUARANTINE_SAVIOR": {
		"title": "DEAD BLOCK SAVIOR",
		"desc": "Clear all 5 Quarantine Sectors of the campaign."
	}
}

var unlocked_level: int = 1
var current_level: int = 1
var selected_mode: String = "offline"
var night_mode_enabled: bool = false

var best_score_by_level: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0
}
var best_stars_by_level: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0
}

var unlocked_achievements: Dictionary = {}
var total_limbs_severed: int = 0
var killed_witch: bool = false
var killed_tank: bool = false

var sfx_enabled: bool = true
var music_enabled: bool = true
var graphics_quality: int = 1 # 0 = LOW (Battery Saver), 1 = MEDIUM (Balanced), 2 = HIGH (Ultra)
var resolution_scale: float = 1.0 # 0.75, 1.0, 1.25
var fullscreen: bool = false
var last_saved_checkpoint: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()

func is_level_unlocked(level_id: int) -> bool:
	return level_id >= 1 and level_id <= unlocked_level

func has_achievement(achievement_id: String) -> bool:
	return unlocked_achievements.get(achievement_id, false) == true

func get_unlocked_achievements_count() -> int:
	var c := 0
	for k in ACHIEVEMENT_DEFS.keys():
		if has_achievement(k):
			c += 1
	return c

func unlock_achievement(achievement_id: String) -> bool:
	if not ACHIEVEMENT_DEFS.has(achievement_id):
		return false
	if has_achievement(achievement_id):
		return false
	
	unlocked_achievements[achievement_id] = true
	save_progress()
	var info: Dictionary = ACHIEVEMENT_DEFS[achievement_id]
	achievement_unlocked.emit(achievement_id, str(info["title"]), str(info["desc"]))
	return true

func record_limb_severed() -> bool:
	total_limbs_severed += 1
	if total_limbs_severed >= 15 and not has_achievement("LIMB_RIPPER"):
		return unlock_achievement("LIMB_RIPPER")
	return false

func record_special_kill(type_name: String) -> bool:
	if type_name == "WITCH":
		killed_witch = true
	elif type_name == "TANKER":
		killed_tank = true
	if killed_witch and killed_tank and not has_achievement("BOSS_SLAYER"):
		return unlock_achievement("BOSS_SLAYER")
	return false

func complete_level(level_id: int, score: int, stars: int = 1, without_getting_bit: bool = false, in_night_mode: bool = false) -> Array[String]:
	var newly_unlocked: Array[String] = []
	
	if score > best_score_by_level.get(level_id, 0):
		best_score_by_level[level_id] = score
	if stars > best_stars_by_level.get(level_id, 0):
		best_stars_by_level[level_id] = clampi(stars, 1, 3)
	
	if level_id >= unlocked_level and level_id < TOTAL_LEVELS:
		unlocked_level = level_id + 1
	
	if without_getting_bit and not has_achievement("UNTOUCHABLE"):
		unlocked_achievements["UNTOUCHABLE"] = true
		newly_unlocked.append("UNTOUCHABLE")
	
	if (in_night_mode or night_mode_enabled) and not has_achievement("NIGHT_STALKER"):
		unlocked_achievements["NIGHT_STALKER"] = true
		newly_unlocked.append("NIGHT_STALKER")
	
	if level_id >= TOTAL_LEVELS and not has_achievement("QUARANTINE_SAVIOR"):
		unlocked_achievements["QUARANTINE_SAVIOR"] = true
		newly_unlocked.append("QUARANTINE_SAVIOR")
	
	save_progress()
	
	for ach_id in newly_unlocked:
		var info: Dictionary = ACHIEVEMENT_DEFS[ach_id]
		achievement_unlocked.emit(ach_id, str(info["title"]), str(info["desc"]))
	
	return newly_unlocked

func save_checkpoint(level_id: int, kills: int, score: int, health: float, armor: float, weapons: Array) -> bool:
	last_saved_checkpoint = {
		"level_id": level_id,
		"kills": kills,
		"score": score,
		"health": health,
		"armor": armor,
		"weapons": weapons,
		"timestamp": Time.get_datetime_string_from_system()
	}
	if score > best_score_by_level.get(level_id, 0):
		best_score_by_level[level_id] = score
	return save_progress()

func save_progress() -> bool:
	var config := ConfigFile.new()
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("progression", "unlocked_level", unlocked_level)
	config.set_value("progression", "current_level", current_level)
	config.set_value("progression", "total_limbs_severed", total_limbs_severed)
	config.set_value("progression", "killed_witch", killed_witch)
	config.set_value("progression", "killed_tank", killed_tank)
	
	for lvl in range(1, TOTAL_LEVELS + 1):
		config.set_value("scores", "level_" + str(lvl), best_score_by_level.get(lvl, 0))
		config.set_value("stars", "level_" + str(lvl), best_stars_by_level.get(lvl, 0))
	
	for ach_id in ACHIEVEMENT_DEFS.keys():
		config.set_value("achievements", ach_id, has_achievement(ach_id))
	
	config.set_value("settings", "sfx_enabled", sfx_enabled)
	config.set_value("settings", "music_enabled", music_enabled)
	config.set_value("settings", "night_mode_enabled", night_mode_enabled)
	config.set_value("settings", "graphics_quality", graphics_quality)
	config.set_value("settings", "resolution_scale", resolution_scale)
	config.set_value("settings", "fullscreen", fullscreen)
	
	if not last_saved_checkpoint.is_empty():
		for key in last_saved_checkpoint.keys():
			config.set_value("checkpoint", key, last_saved_checkpoint[key])
	
	var err := config.save(SAVE_PATH)
	if err == OK:
		progress_saved.emit()
		return true
	return false

func load_progress() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)
	if err != OK:
		return
	
	unlocked_level = clampi(int(config.get_value("progression", "unlocked_level", 1)), 1, TOTAL_LEVELS)
	current_level = clampi(int(config.get_value("progression", "current_level", 1)), 1, TOTAL_LEVELS)
	total_limbs_severed = int(config.get_value("progression", "total_limbs_severed", 0))
	killed_witch = bool(config.get_value("progression", "killed_witch", false))
	killed_tank = bool(config.get_value("progression", "killed_tank", false))
	
	for lvl in range(1, TOTAL_LEVELS + 1):
		best_score_by_level[lvl] = max(0, int(config.get_value("scores", "level_" + str(lvl), 0)))
		best_stars_by_level[lvl] = clampi(int(config.get_value("stars", "level_" + str(lvl), 0)), 0, 3)
	
	unlocked_achievements.clear()
	if config.has_section("achievements"):
		for ach_id in ACHIEVEMENT_DEFS.keys():
			unlocked_achievements[ach_id] = bool(config.get_value("achievements", ach_id, false))
	
	sfx_enabled = bool(config.get_value("settings", "sfx_enabled", true))
	music_enabled = bool(config.get_value("settings", "music_enabled", true))
	night_mode_enabled = bool(config.get_value("settings", "night_mode_enabled", false))
	graphics_quality = clampi(int(config.get_value("settings", "graphics_quality", 1)), 0, 2)
	resolution_scale = clampf(float(config.get_value("settings", "resolution_scale", 1.0)), 0.5, 1.5)
	fullscreen = bool(config.get_value("settings", "fullscreen", false))
	apply_display_settings()
	
	if config.has_section("checkpoint"):
		last_saved_checkpoint = {
			"level_id": int(config.get_value("checkpoint", "level_id", 1)),
			"kills": int(config.get_value("checkpoint", "kills", 0)),
			"score": int(config.get_value("checkpoint", "score", 0)),
			"health": float(config.get_value("checkpoint", "health", 100.0)),
			"armor": float(config.get_value("checkpoint", "armor", 0.0)),
			"weapons": config.get_value("checkpoint", "weapons", ["PISTOL"]),
			"timestamp": str(config.get_value("checkpoint", "timestamp", ""))
		}

func reset_progress() -> void:
	unlocked_level = 1
	current_level = 1
	total_limbs_severed = 0
	killed_witch = false
	killed_tank = false
	unlocked_achievements.clear()
	for lvl in range(1, TOTAL_LEVELS + 1):
		best_score_by_level[lvl] = 0
		best_stars_by_level[lvl] = 0
	last_saved_checkpoint.clear()
	save_progress()

func set_graphics_quality(quality: int) -> void:
	graphics_quality = clampi(quality, 0, 2)
	save_progress()
	settings_changed.emit("graphics_quality", graphics_quality)

func cycle_graphics_quality() -> int:
	graphics_quality = (graphics_quality + 1) % 3
	save_progress()
	settings_changed.emit("graphics_quality", graphics_quality)
	return graphics_quality

func set_resolution_scale(scale: float) -> void:
	resolution_scale = clampf(scale, 0.5, 1.5)
	apply_display_settings()
	save_progress()
	settings_changed.emit("resolution_scale", resolution_scale)

func cycle_resolution_scale() -> float:
	if is_equal_approx(resolution_scale, 0.75):
		resolution_scale = 1.0
	elif is_equal_approx(resolution_scale, 1.0):
		resolution_scale = 1.25
	else:
		resolution_scale = 0.75
	apply_display_settings()
	save_progress()
	settings_changed.emit("resolution_scale", resolution_scale)
	return resolution_scale

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	apply_display_settings()
	save_progress()
	settings_changed.emit("fullscreen", fullscreen)

func toggle_fullscreen() -> bool:
	fullscreen = not fullscreen
	apply_display_settings()
	save_progress()
	settings_changed.emit("fullscreen", fullscreen)
	return fullscreen

func apply_display_settings() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var target_size := Vector2i(int(1280.0 * resolution_scale), int(720.0 * resolution_scale))
		if not OS.has_feature("mobile"):
			DisplayServer.window_set_size(target_size)
	
	var root_viewport := get_tree().root if get_tree() else null
	if root_viewport:
		root_viewport.content_scale_factor = 1.0
