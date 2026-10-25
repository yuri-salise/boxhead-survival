extends Control

@onready var solo_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/SoloCampaignButton
@onready var coop_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/CoopLobbyButton
@onready var night_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/NightModeButton
@onready var back_button: Button = $CenterContainer/ModePanel/ModeMargin/ModeVBox/BackButton
@onready var status_label: Label = $CenterContainer/ModePanel/ModeMargin/ModeVBox/StatusLabel

func _ready() -> void:
	if solo_button:
		solo_button.pressed.connect(_on_solo_pressed)
	if coop_button:
		coop_button.pressed.connect(_on_coop_pressed)
	if night_button:
		night_button.pressed.connect(_on_night_toggled)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	_refresh_night_button()

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _refresh_night_button() -> void:
	if not night_button:
		return
	var gs := _get_game_state()
	var is_night := bool(gs.get("night_mode_enabled")) if gs else false
	night_button.text = "NIGHT MODE (FLASHLIGHT ONLY): " + ("ON [PITCH BLACK]" if is_night else "OFF [STANDARD]")

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

func _on_night_toggled() -> void:
	var gs := _get_game_state()
	if gs:
		gs.night_mode_enabled = not bool(gs.get("night_mode_enabled"))
		if gs.has_method("save_progress"):
			gs.save_progress()
	_refresh_night_button()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
