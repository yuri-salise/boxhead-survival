extends Control

@onready var solo_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/SoloCampaignButton
@onready var survival_button: Button = get_node_or_null("CenterContainer/ModePanel/ModeMargin/ModeVBox/SurvivalModeButton")
@onready var coop_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/CoopLobbyButton
@onready var back_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/BackButton
@onready var status_label: Label = $CenterContainer/ModePanel/ModeMargin/ModeVBox/StatusLabel

func _ready() -> void:
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
			var on := bool(gs.get("ai_companion_enabled"))
			ai_btn.text = "OFFLINE AI SQUADMATE: " + ("ENABLED (BRAVO BOT)" if on else "SOLO ONLY (OFF)")
		update_ai_text.call()
		ai_btn.pressed.connect(func():
			gs.ai_companion_enabled = not bool(gs.get("ai_companion_enabled"))
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
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

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
