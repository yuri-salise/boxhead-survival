extends Control

signal next_level_requested(next_level_id: int)
signal retry_requested()
signal main_menu_requested()

@onready var outcome_title: Label = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/OutcomeTitle
@onready var stars_label: Label = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/StarsLabel
@onready var stats_label: Label = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/StatsLabel
@onready var unlock_banner: Label = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/UnlockBanner
@onready var next_level_button: Button = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/NextLevelButton
@onready var retry_button: Button = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/RetryButton
@onready var main_menu_button: Button = $CenterContainer/ResultPanel/ResultMargin/ResultVBox/MainMenuButton

var current_level_id: int = 1
var is_victory: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if next_level_button:
		next_level_button.pressed.connect(_on_next_level_pressed)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func show_victory(level_id: int, score: int, kills: int, stars: int, unlocked_achs: Array = []) -> void:
	current_level_id = level_id
	is_victory = true
	visible = true
	
	if outcome_title:
		outcome_title.text = "SECTOR CLEARED // SURVIVED"
		outcome_title.add_theme_color_override("font_color", Color(0.35, 0.92, 0.48, 1.0))
	
	if stars_label:
		var clamped_stars := clampi(stars, 1, 3)
		var star_str := ""
		for i in range(1, 4):
			star_str += "★ " if i <= clamped_stars else "☆ "
		stars_label.text = star_str.strip_edges() + "   RATING (" + str(clamped_stars) + "/3)"
		stars_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.25, 1.0))
		stars_label.visible = true
	
	if stats_label:
		stats_label.text = "ZONE 0" + str(level_id) + "   ·   INFECTED KILLED: " + str(kills) + "   ·   SCORE: " + str(score)
	
	if unlock_banner:
		var base_msg := "[ PROGRESS SAVED — SECTOR 0" + str(level_id + 1) + " UNLOCKED ]" if level_id < 5 else "[ CAMPAIGN COMPLETE — ALL QUARANTINE SECTORS CLEARED! ]"
		if not unlocked_achs.is_empty():
			var ach_str := ", ".join(PackedStringArray(unlocked_achs))
			base_msg += "\n★ ACHIEVEMENT UNLOCKED: " + ach_str + " ★"
		unlock_banner.text = base_msg
		unlock_banner.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28, 1.0) if not unlocked_achs.is_empty() else Color(0.45, 0.88, 0.55, 1.0))
	
	if next_level_button:
		next_level_button.visible = (level_id < 5)

func show_defeat(level_id: int, score: int, kills: int, reason: String = "OUTPOST OVERRUN") -> void:
	current_level_id = level_id
	is_victory = false
	visible = true
	
	if outcome_title:
		outcome_title.text = reason
		outcome_title.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22, 1.0))
	
	if stars_label:
		stars_label.text = "☆ ☆ ☆   SECTOR LOST"
		stars_label.add_theme_color_override("font_color", Color(0.65, 0.28, 0.28, 1.0))
		stars_label.visible = true
	
	if stats_label:
		stats_label.text = "ZONE 0" + str(level_id) + "   ·   INFECTED KILLED: " + str(kills) + "   ·   SCORE: " + str(score)
	
	if unlock_banner:
		unlock_banner.text = "[ THE HORDE OVERRAN YOUR POSITION — REGROUP AND RETRY ]"
		unlock_banner.add_theme_color_override("font_color", Color(0.85, 0.45, 0.35, 1.0))
	
	if next_level_button:
		next_level_button.visible = false

func _on_next_level_pressed() -> void:
	visible = false
	get_tree().paused = false
	next_level_requested.emit(current_level_id + 1)

func _on_retry_pressed() -> void:
	visible = false
	get_tree().paused = false
	retry_requested.emit()

func _on_main_menu_pressed() -> void:
	visible = false
	get_tree().paused = false
	main_menu_requested.emit()
