extends Control

@onready var play_dialog: PanelContainer = $Modals/PlayDialog
@onready var settings_dialog: PanelContainer = $Modals/SettingsDialog
@onready var credits_dialog: PanelContainer = $Modals/CreditsDialog

@onready var play_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/PlayButton
@onready var settings_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/SettingsButton
@onready var credits_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/CreditsButton
@onready var quit_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/QuitButton

# Dialog controls
@onready var start_level_button: Button = $Modals/PlayDialog/PlayMargin/PlayVBox/StartLevelButton
@onready var play_back_button: Button = $Modals/PlayDialog/PlayMargin/PlayVBox/PlayBackButton

@onready var sfx_toggle_button: Button = $Modals/SettingsDialog/SettingsMargin/SettingsVBox/SFXToggle
@onready var music_toggle_button: Button = $Modals/SettingsDialog/SettingsMargin/SettingsVBox/MusicToggle
@onready var screen_mode_button: Button = $Modals/SettingsDialog/SettingsMargin/SettingsVBox/ScreenModeToggle
@onready var settings_back_button: Button = $Modals/SettingsDialog/SettingsMargin/SettingsVBox/SettingsBackButton

@onready var credits_back_button: Button = $Modals/CreditsDialog/CreditsMargin/CreditsVBox/CreditsBackButton

var sfx_enabled: bool = true
var music_enabled: bool = true
var is_fullscreen: bool = false

func _ready() -> void:
	_hide_all_dialogs()
	
	# Wire main menu buttons
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Wire dialog buttons
	start_level_button.pressed.connect(_on_start_level_pressed)
	play_back_button.pressed.connect(_hide_all_dialogs)
	
	sfx_toggle_button.pressed.connect(_on_sfx_toggle_pressed)
	music_toggle_button.pressed.connect(_on_music_toggle_pressed)
	screen_mode_button.pressed.connect(_on_screen_mode_toggle_pressed)
	settings_back_button.pressed.connect(_hide_all_dialogs)
	
	credits_back_button.pressed.connect(_hide_all_dialogs)
	
	# Hide quit button on mobile platforms where OS handles app lifecycle
	if OS.has_feature("mobile") or OS.has_feature("web"):
		quit_button.visible = false
	
	_update_settings_ui()

func _hide_all_dialogs() -> void:
	play_dialog.visible = false
	settings_dialog.visible = false
	credits_dialog.visible = false

func _on_play_button_pressed() -> void:
	_hide_all_dialogs()
	play_dialog.visible = true

func _on_settings_button_pressed() -> void:
	_hide_all_dialogs()
	settings_dialog.visible = true

func _on_credits_button_pressed() -> void:
	_hide_all_dialogs()
	credits_dialog.visible = true

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_start_level_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_sfx_toggle_pressed() -> void:
	sfx_enabled = not sfx_enabled
	_update_settings_ui()

func _on_music_toggle_pressed() -> void:
	music_enabled = not music_enabled
	_update_settings_ui()

func _on_screen_mode_toggle_pressed() -> void:
	is_fullscreen = not is_fullscreen
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_settings_ui()

func _update_settings_ui() -> void:
	sfx_toggle_button.text = "Sound FX: " + ("ON" if sfx_enabled else "OFF")
	music_toggle_button.text = "Music: " + ("ON" if music_enabled else "OFF")
	screen_mode_button.text = "Display: " + ("Fullscreen" if is_fullscreen else "Windowed")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if play_dialog.visible or settings_dialog.visible or credits_dialog.visible:
			_hide_all_dialogs()
