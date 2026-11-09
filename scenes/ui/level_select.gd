extends Control

const LEVEL_NAMES: Dictionary = {
	1: "SECTOR 01: OUTPOST QUARANTINE (3 WAVES · DAY -> DUSK)",
	2: "SECTOR 02: THE DEAD HIGHWAY (4 WAVES · AFTERNOON -> NIGHT)",
	3: "SECTOR 03: INDUSTRIAL SLAUGHTERHOUSE (4 WAVES · SUNSET -> NIGHT)",
	4: "SECTOR 04: CONTAINMENT DEPOT (5 WAVES · DUSK -> MIDNIGHT)",
	5: "SECTOR 05: LAST LIGHT — BLACKOUT FINALE (5 WAVES · MIDNIGHT -> DAWN)"
}

@onready var level_panel: PanelContainer = find_child("LevelPanel", true, false) as PanelContainer
@onready var level_scroll: ScrollContainer = find_child("LevelScroll", true, false) as ScrollContainer
@onready var back_button: Button = find_child("BackButton", true, false) as Button
@onready var achievements_label: Label = find_child("AchievementsLabel", true, false) as Label

var level_buttons: Array[Button] = []
var custom_game_state: Node = null

func _ready() -> void:
	level_buttons.clear()
	for i in range(1, 6):
		var btn = find_child("Level" + str(i) + "Button", true, false) as Button
		if btn:
			level_buttons.append(btn)
			var lvl_id := i
			btn.pressed.connect(func(): _on_level_selected(lvl_id))
	
	if get_viewport():
		get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	var gs := _get_game_state()
	if gs and gs.has_method("bind_button_tweens"):
		gs.bind_button_tweens(self)
	
	refresh_ui()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_responsive_layout()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if level_panel:
		level_panel.custom_minimum_size.x = clampf(vp_size.x - 36.0, 320.0, 840.0)
		level_panel.custom_minimum_size.y = clampf(vp_size.y - 32.0, 260.0, 560.0)
	if level_scroll:
		level_scroll.custom_minimum_size.y = clampf(vp_size.y - 64.0, 220.0, 500.0)

func _get_game_state() -> Node:
	if is_instance_valid(custom_game_state):
		return custom_game_state
	return get_node_or_null("/root/GameState")

func refresh_ui() -> void:
	var gs := _get_game_state()
	var unlocked_max := int(gs.get("unlocked_level")) if gs else 1
	
	for i in range(level_buttons.size()):
		var lvl_id := i + 1
		var btn := level_buttons[i]
		if not btn:
			continue
		
		var base_title: String = LEVEL_NAMES.get(lvl_id, "SECTOR 0" + str(lvl_id))
		var is_unlocked := (lvl_id <= unlocked_max)
		btn.disabled = not is_unlocked
		
		if is_unlocked:
			var best_sc := 0
			var best_st := 0
			if gs:
				best_sc = int(gs.best_score_by_level.get(lvl_id, 0))
				best_st = int(gs.best_stars_by_level.get(lvl_id, 0))
			var stars_txt := ""
			for s in range(1, 4):
				stars_txt += "★" if s <= best_st else "☆"
			btn.text = base_title + "   —   " + stars_txt + "   [ BEST: " + str(best_sc) + " ]"
		else:
			btn.text = "[ LOCKED ]   " + base_title
	
	if achievements_label:
		if gs and gs.get("ACHIEVEMENT_DEFS") != null:
			var defs: Dictionary = gs.ACHIEVEMENT_DEFS
			var badges: Array[String] = []
			for ach_id in defs.keys():
				var title_str: String = str(defs[ach_id]["title"])
				var has_it: bool = gs.has_achievement(ach_id)
				badges.append(("★ " if has_it else "☆ ") + title_str)
			var total_st: int = gs.get_total_stars() if gs.has_method("get_total_stars") else 0
			var perk_str := " [★ VETERAN PERK ACTIVE]" if total_st >= 6 else (" [★ " + str(total_st) + "/6 FOR VETERAN PERK]")
			achievements_label.text = "STARS: " + str(total_st) + "/15" + perk_str + "  |  MEDALS:  " + "   ·   ".join(PackedStringArray(badges))
		else:
			achievements_label.text = "MEDALS:  ☆ UNTOUCHABLE   ·   ☆ NIGHT STALKER   ·   ☆ ANATOMY LESSON   ·   ☆ APEX PREDATOR"

func _on_level_selected(level_id: int) -> void:
	var gs := _get_game_state()
	var unlocked_max := int(gs.get("unlocked_level")) if gs else 1
	if level_id > unlocked_max:
		return
	if gs:
		gs.current_level = level_id
		gs.save_progress()
	
	var scene_path := "res://scenes/levels/level_0" + str(level_id) + ".tscn"
	if ResourceLoader.exists(scene_path):
		get_tree().change_scene_to_file(scene_path)
	else:
		get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_back_pressed() -> void:
	if ResourceLoader.exists("res://scenes/ui/mode_select.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
