extends Control

# Modal layer and backdrop
@onready var modal_layer: Control = $ModalLayer
@onready var modal_backdrop: ColorRect = $ModalLayer/ModalOverlayBackdrop
@onready var play_dialog: PanelContainer = $ModalLayer/ModalsCenter/PlayDialog
@onready var settings_dialog: PanelContainer = $ModalLayer/ModalsCenter/SettingsDialog
@onready var credits_dialog: PanelContainer = $ModalLayer/ModalsCenter/CreditsDialog

# Main menu buttons
@onready var play_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/PlayButton
@onready var settings_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/SettingsButton
@onready var credits_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/CreditsButton
@onready var quit_button: Button = $MarginContainer/MainLayout/MenuColumn/ButtonsContainer/QuitButton

# Dialog controls
@onready var start_level_button: Button = $ModalLayer/ModalsCenter/PlayDialog/PlayMargin/PlayVBox/StartLevelButton
@onready var play_back_button: Button = $ModalLayer/ModalsCenter/PlayDialog/PlayMargin/PlayVBox/PlayBackButton

@onready var graphics_toggle_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/GraphicsToggle
@onready var resolution_toggle_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/ResolutionToggle
@onready var sfx_toggle_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/SFXToggle
@onready var music_toggle_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/MusicToggle
@onready var screen_mode_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/ScreenModeToggle
@onready var settings_back_button: Button = $ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox/SettingsBackButton

@onready var credits_back_button: Button = $ModalLayer/ModalsCenter/CreditsDialog/CreditsMargin/CreditsVBox/CreditsBackButton

var sfx_enabled: bool = true
var music_enabled: bool = true
var is_fullscreen: bool = false

func _ready() -> void:
	_hide_all_dialogs()
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		sfx_enabled = bool(audio_mgr.sfx_enabled)
		music_enabled = bool(audio_mgr.music_enabled)
		if audio_mgr.has_method("play_music"):
			audio_mgr.play_music("ambient_menu")
	
	# Wire main menu buttons
	play_button.pressed.connect(_on_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Wire dialog actions
	start_level_button.pressed.connect(_on_start_level_pressed)
	play_back_button.pressed.connect(_hide_all_dialogs)
	
	if graphics_toggle_button:
		graphics_toggle_button.pressed.connect(_on_graphics_toggle_pressed)
	if resolution_toggle_button:
		resolution_toggle_button.pressed.connect(_on_resolution_toggle_pressed)
	sfx_toggle_button.pressed.connect(_on_sfx_toggle_pressed)
	music_toggle_button.pressed.connect(_on_music_toggle_pressed)
	screen_mode_button.pressed.connect(_on_screen_mode_toggle_pressed)
	settings_back_button.pressed.connect(_hide_all_dialogs)
	
	credits_back_button.pressed.connect(_hide_all_dialogs)
	
	# Clicking the dark overlay backdrop dismisses the modal
	modal_backdrop.gui_input.connect(_on_backdrop_gui_input)
	
	# Hide quit button on mobile platforms where OS handles app lifecycle
	if OS.has_feature("mobile") or OS.has_feature("web"):
		quit_button.visible = false
	
	_setup_bonus_settings_controls()
	_update_settings_ui()
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("bind_button_tweens"):
		gs.bind_button_tweens(self)

func _setup_bonus_settings_controls() -> void:
	var settings_vbox := get_node_or_null("ModalLayer/ModalsCenter/SettingsDialog/SettingsMargin/SettingsVBox")
	var gs := get_node_or_null("/root/GameState")
	if not settings_vbox or not gs:
		return
	var callsign_input := LineEdit.new()
	callsign_input.name = "CallsignInput"
	callsign_input.placeholder_text = "Enter Survivor Callsign..."
	callsign_input.text = str(gs.get("player_callsign"))
	callsign_input.max_length = 16
	callsign_input.text_changed.connect(func(new_txt: String):
		gs.player_callsign = new_txt.strip_edges() if not new_txt.strip_edges().is_empty() else "SURVIVOR"
		gs.save_progress()
	)
	settings_vbox.add_child(callsign_input)
	settings_vbox.move_child(callsign_input, 1)
	
	var vib_btn := Button.new()
	vib_btn.name = "VibrationToggle"
	vib_btn.text = "VIBRATION / HAPTICS: " + ("ENABLED" if bool(gs.get("vibration_enabled")) else "OFF")
	vib_btn.pressed.connect(func():
		gs.vibration_enabled = not bool(gs.get("vibration_enabled"))
		gs.save_progress()
		vib_btn.text = "VIBRATION / HAPTICS: " + ("ENABLED" if bool(gs.get("vibration_enabled")) else "OFF")
		if gs.vibration_enabled and gs.has_method("trigger_haptic"):
			gs.trigger_haptic(35)
	)
	settings_vbox.add_child(vib_btn)
	settings_vbox.move_child(vib_btn, settings_vbox.get_child_count() - 2)
	
	var cb_btn := Button.new()
	cb_btn.name = "ColorblindToggle"
	cb_btn.text = "COLOR-BLIND MARKERS: " + ("ENABLED" if bool(gs.get("colorblind_mode")) else "OFF")
	cb_btn.pressed.connect(func():
		gs.colorblind_mode = not bool(gs.get("colorblind_mode"))
		gs.save_progress()
		cb_btn.text = "COLOR-BLIND MARKERS: " + ("ENABLED" if bool(gs.get("colorblind_mode")) else "OFF")
	)
	settings_vbox.add_child(cb_btn)
	settings_vbox.move_child(cb_btn, settings_vbox.get_child_count() - 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if modal_layer and modal_layer.visible:
			_hide_all_dialogs()
		else:
			get_tree().quit()

func _show_dialog(target: PanelContainer) -> void:
	modal_layer.visible = true
	play_dialog.visible = (target == play_dialog)
	settings_dialog.visible = (target == settings_dialog)
	credits_dialog.visible = (target == credits_dialog)

func _hide_all_dialogs() -> void:
	modal_layer.visible = false
	play_dialog.visible = false
	settings_dialog.visible = false
	credits_dialog.visible = false

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mode_select.tscn")

func _on_settings_button_pressed() -> void:
	_show_dialog(settings_dialog)

func _on_credits_button_pressed() -> void:
	_show_dialog(credits_dialog)

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_all_dialogs()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_start_level_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_sfx_toggle_pressed() -> void:
	sfx_enabled = not sfx_enabled
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.set_sfx_enabled(sfx_enabled)
		if sfx_enabled:
			audio_mgr.play_sfx("sfx_pistol")
	_update_settings_ui()

func _on_music_toggle_pressed() -> void:
	music_enabled = not music_enabled
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.set_music_enabled(music_enabled)
	_update_settings_ui()

func _on_graphics_toggle_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("cycle_graphics_quality"):
		gs.cycle_graphics_quality()
	_update_settings_ui()

func _on_resolution_toggle_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("cycle_resolution_scale"):
		gs.cycle_resolution_scale()
	_update_settings_ui()

func _on_screen_mode_toggle_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("toggle_fullscreen"):
		is_fullscreen = gs.toggle_fullscreen()
	else:
		is_fullscreen = not is_fullscreen
		if is_fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_update_settings_ui()

func _update_settings_ui() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var q_names: Array[String] = ["BATTERY SAVER (LOW)", "BALANCED (MED)", "ULTRA (HIGH)"]
		var q_idx: int = clampi(int(gs.graphics_quality), 0, 2)
		if graphics_toggle_button:
			graphics_toggle_button.text = "GRAPHICS: " + q_names[q_idx]
		
		var scale_pct := int(roundf(float(gs.resolution_scale) * 100.0))
		if resolution_toggle_button:
			resolution_toggle_button.text = "RESOLUTION: " + str(scale_pct) + "%"
		
		is_fullscreen = bool(gs.fullscreen)
	
	sfx_toggle_button.text = "SOUND FX: " + ("ENABLED" if sfx_enabled else "MUTED")
	music_toggle_button.text = "MUSIC: " + ("ENABLED" if music_enabled else "MUTED")
	screen_mode_button.text = "DISPLAY: " + ("FULLSCREEN" if is_fullscreen else "WINDOWED")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if modal_layer.visible:
			_hide_all_dialogs()
			get_viewport().set_input_as_handled()
