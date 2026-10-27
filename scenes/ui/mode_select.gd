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
	if gs and status_label and "survival_best_wave" in gs and gs.survival_best_wave > 0:
		status_label.text = "[ SURVIVAL RECORD: WAVE " + str(gs.survival_best_wave) + "  ·  SCORE " + str(gs.survival_best_score) + " ]"

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
