extends Control

@onready var mode_panel: PanelContainer = find_child("ModePanel", true, false) as PanelContainer
@onready var mode_scroll: ScrollContainer = find_child("ModeScroll", true, false) as ScrollContainer
@onready var solo_button: Button = find_child("SoloCampaignButton", true, false) as Button
@onready var survival_button: Button = find_child("SurvivalModeButton", true, false) as Button
@onready var coop_button: Button = find_child("CoopLobbyButton", true, false) as Button
@onready var back_button: Button = find_child("BackButton", true, false) as Button
@onready var status_label: Label = find_child("StatusLabel", true, false) as Label

func _ready() -> void:
	if get_viewport():
		get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	
	if solo_button:
		solo_button.pressed.connect(_on_solo_pressed)
	if survival_button:
		survival_button.pressed.connect(_on_survival_pressed)
	if coop_button:
		coop_button.pressed.connect(_on_coop_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	var gs := _get_game_state()
	if gs:
		if gs.has_method("bind_button_tweens"):
			gs.bind_button_tweens(self)
		var ai_btn := Button.new()
		ai_btn.name = "AiCompanionToggleButton"
		ai_btn.custom_minimum_size = Vector2(0, 40)
		var update_ai_text := func():
			var on: bool = (gs.get("ai_companion_enabled") == true)
			ai_btn.text = "OFFLINE AI SQUADMATE: " + ("ENABLED (BRAVO BOT)" if on else "SOLO ONLY (OFF)")
		update_ai_text.call()
		ai_btn.pressed.connect(func():
			gs.ai_companion_enabled = not (gs.get("ai_companion_enabled") == true)
			gs.save_progress()
			update_ai_text.call()
		)
		if solo_button and solo_button.get_parent():
			solo_button.get_parent().add_child(ai_btn)
			solo_button.get_parent().move_child(ai_btn, solo_button.get_index() + 1)
			if gs.has_method("bind_button_tweens"):
				gs.bind_button_tweens(ai_btn)
	if gs and status_label and "survival_best_wave" in gs and gs.survival_best_wave > 0:
		status_label.text = "[ SURVIVAL RECORD: WAVE " + str(gs.survival_best_wave) + "  ·  SCORE " + str(gs.survival_best_score) + " ]"

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_responsive_layout()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if mode_panel:
		mode_panel.custom_minimum_size.x = clampf(vp_size.x - 36.0, 320.0, 560.0)
		mode_panel.custom_minimum_size.y = clampf(vp_size.y - 32.0, 240.0, 460.0)
	if mode_scroll:
		mode_scroll.custom_minimum_size.y = clampf(vp_size.y - 64.0, 200.0, 420.0)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _on_solo_pressed() -> void:
	var gs := _get_game_state()
	if gs:
		gs.selected_mode = "offline"
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_survival_pressed() -> void:
	var gs := _get_game_state()
	if gs:
		gs.selected_mode = "survival"
		gs.current_level = 1
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_coop_pressed() -> void:
	var gs := _get_game_state()
	if gs:
		gs.selected_mode = "online"
	if ResourceLoader.exists("res://scenes/ui/lobby.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
