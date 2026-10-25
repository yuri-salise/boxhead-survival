extends Node

signal progress_saved()

const SAVE_PATH: String = "user://save.cfg"
const SAVE_VERSION: int = 1
const TOTAL_LEVELS: int = 5

var unlocked_level: int = 1
var current_level: int = 1
var selected_mode: String = "offline"

var best_score_by_level: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0
}
var best_stars_by_level: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0
}

var sfx_enabled: bool = true
var music_enabled: bool = true
var last_saved_checkpoint: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_progress()

func is_level_unlocked(level_id: int) -> bool:
	return level_id >= 1 and level_id <= unlocked_level

func complete_level(level_id: int, score: int, stars: int = 1) -> void:
	if score > best_score_by_level.get(level_id, 0):
		best_score_by_level[level_id] = score
	if stars > best_stars_by_level.get(level_id, 0):
		best_stars_by_level[level_id] = clampi(stars, 1, 3)
	
	if level_id >= unlocked_level and level_id < TOTAL_LEVELS:
		unlocked_level = level_id + 1
	
	save_progress()

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
	
	for lvl in range(1, TOTAL_LEVELS + 1):
		config.set_value("scores", "level_" + str(lvl), best_score_by_level.get(lvl, 0))
		config.set_value("stars", "level_" + str(lvl), best_stars_by_level.get(lvl, 0))
	
	config.set_value("settings", "sfx_enabled", sfx_enabled)
	config.set_value("settings", "music_enabled", music_enabled)
	
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
	
	for lvl in range(1, TOTAL_LEVELS + 1):
		best_score_by_level[lvl] = max(0, int(config.get_value("scores", "level_" + str(lvl), 0)))
		best_stars_by_level[lvl] = clampi(int(config.get_value("stars", "level_" + str(lvl), 0)), 0, 3)
	
	sfx_enabled = bool(config.get_value("settings", "sfx_enabled", true))
	music_enabled = bool(config.get_value("settings", "music_enabled", true))
	
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
	for lvl in range(1, TOTAL_LEVELS + 1):
		best_score_by_level[lvl] = 0
		best_stars_by_level[lvl] = 0
	last_saved_checkpoint.clear()
	save_progress()
