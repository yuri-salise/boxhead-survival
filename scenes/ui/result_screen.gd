extends Control

signal next_level_requested(next_level_id: int)
signal retry_requested()
signal main_menu_requested()

@onready var result_panel: PanelContainer = find_child("ResultPanel", true, false) as PanelContainer
@onready var result_scroll: ScrollContainer = find_child("ResultScroll", true, false) as ScrollContainer
@onready var outcome_title: Label = find_child("OutcomeTitle", true, false) as Label
@onready var stars_label: Label = find_child("StarsLabel", true, false) as Label
@onready var stats_label: Label = find_child("StatsLabel", true, false) as Label
@onready var unlock_banner: Label = find_child("UnlockBanner", true, false) as Label
@onready var next_level_button: Button = find_child("NextLevelButton", true, false) as Button
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button
@onready var main_menu_button: Button = find_child("MainMenuButton", true, false) as Button

var current_level_id: int = 1
var is_victory: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if get_viewport():
		get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	
	if next_level_button:
		next_level_button.pressed.connect(_on_next_level_pressed)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("bind_button_tweens"):
		gs.bind_button_tweens(self)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_responsive_layout()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if result_panel:
		result_panel.custom_minimum_size.x = clampf(vp_size.x - 36.0, 320.0, 540.0)
		result_panel.custom_minimum_size.y = clampf(vp_size.y - 32.0, 240.0, 440.0)
	if result_scroll:
		result_scroll.custom_minimum_size.y = clampf(vp_size.y - 64.0, 200.0, 400.0)

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
	_spawn_unlock_particle_burst()

func _spawn_unlock_particle_burst() -> void:
	var burst := CPUParticles2D.new()
	burst.name = "UnlockParticleBurst"
	burst.position = size * 0.5 if size != Vector2.ZERO else Vector2(640, 320)
	burst.emitting = true
	burst.one_shot = true
	burst.explosiveness = 0.92
	burst.amount = 36
	burst.lifetime = 1.2
	burst.spread = 180.0
	burst.gravity = Vector2(0, 140)
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 280.0
	burst.scale_amount_min = 3.0
	burst.scale_amount_max = 6.0
	burst.color = Color(0.98, 0.85, 0.28, 0.95)
	add_child(burst)
	burst.finished.connect(burst.queue_free)

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

func show_survival_defeat(wave: int, score: int, kills: int, is_new_best: bool = false) -> void:
	is_victory = false
	visible = true
	
	if outcome_title:
		outcome_title.text = "SURVIVAL TERMINATED // OVERRUN"
		outcome_title.add_theme_color_override("font_color", Color(0.92, 0.22, 0.22, 1.0))
	
	if stars_label:
		stars_label.text = "WAVES SURVIVED: " + str(wave)
		stars_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.25, 1.0) if is_new_best else Color(0.85, 0.55, 0.25, 1.0))
		stars_label.visible = true
	
	if stats_label:
		stats_label.text = "INFECTED KILLED: " + str(kills) + "   ·   TOTAL SCORE: " + str(score)
	
	if unlock_banner:
		if is_new_best:
			unlock_banner.text = "★ NEW PERSONAL RECORD SET! ★"
			unlock_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
		else:
			unlock_banner.text = "[ POSITION OVERRUN BY ENDLESS HORDE — REARM & RETRY ]"
			unlock_banner.add_theme_color_override("font_color", Color(0.85, 0.45, 0.35, 1.0))
	
	if next_level_button:
		next_level_button.visible = false
	if retry_button:
		retry_button.text = "RETRY SURVIVAL"

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
