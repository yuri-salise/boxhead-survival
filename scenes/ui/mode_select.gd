extends Control

@onready var solo_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/SoloCampaignButton
@onready var coop_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/CoopLobbyButton
@onready var back_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/BackButton
@onready var status_label: Label = $CenterContainer/ModePanel/ModeMargin/ModeVBox/StatusLabel

func _ready() -> void:
	if solo_button:
		solo_button.pressed.connect(_on_solo_pressed)
	if coop_button:
		coop_button.pressed.connect(_on_coop_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _on_solo_pressed() -> void:
	var gs := _get_game_state()
	if gs:
		gs.selected_mode = "offline"
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")

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
