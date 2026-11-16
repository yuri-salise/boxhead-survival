extends Control

const UiIcons := preload("res://scripts/ui_icons.gd")

signal resume_requested()
signal save_requested()
signal retry_requested()
signal main_menu_requested()

@onready var backdrop: ColorRect = get_node_or_null("PauseBackdrop")
@onready var pause_panel: PanelContainer = find_child("PausePanel", true, false) as PanelContainer
@onready var pause_scroll: ScrollContainer = find_child("PauseScroll", true, false) as ScrollContainer
@onready var status_label: Label = find_child("SaveStatusLabel", true, false) as Label
@onready var resume_button: Button = find_child("ResumeButton", true, false) as Button
@onready var graphics_button: Button = find_child("GraphicsButton", true, false) as Button
@onready var resolution_button: Button = find_child("ResolutionButton", true, false) as Button
@onready var save_button: Button = find_child("SaveButton", true, false) as Button
@onready var retry_button: Button = find_child("RetryButton", true, false) as Button
@onready var main_menu_button: Button = find_child("MainMenuButton", true, false) as Button
@onready var sound_button: Button = find_child("SoundButton", true, false) as Button
@onready var music_button: Button = find_child("MusicButton", true, false) as Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if get_viewport():
		get_viewport().size_changed.connect(_update_responsive_layout)
	_update_responsive_layout()
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if graphics_button:
		graphics_button.pressed.connect(_on_graphics_pressed)
	if resolution_button:
		resolution_button.pressed.connect(_on_resolution_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)
	if sound_button:
		sound_button.pressed.connect(_on_sound_pressed)
	if music_button:
		music_button.pressed.connect(_on_music_pressed)
	
	var gs := get_node_or_null("/root/GameState")
	if gs:
		if gs.has_method("bind_button_tweens"):
			gs.bind_button_tweens(self)
		if gs.has_method("setup_touch_scroll") and pause_scroll:
			gs.setup_touch_scroll(pause_scroll)
	
	_refresh_settings_buttons()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_responsive_layout()

func _update_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var vp_size := get_viewport_rect().size
	if pause_panel:
		pause_panel.custom_minimum_size.x = clampf(vp_size.x - 48.0, 340.0, 680.0)
		pause_panel.custom_minimum_size.y = clampf(vp_size.y - 36.0, 240.0, 360.0)
	if pause_scroll:
		pause_scroll.custom_minimum_size.y = clampf(vp_size.y - 120.0, 150.0, 230.0)

func open_pause_menu() -> void:
	visible = true
	if status_label:
		status_label.text = "[ TACTICAL FIELD TERMINAL // GAME PAUSED ]"
		status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20))
	_refresh_settings_buttons()
	get_tree().paused = true

func close_pause_menu() -> void:
	visible = false
	get_tree().paused = false

func _refresh_settings_buttons() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs:
		var q_names: Array[String] = ["BATTERY SAVER (LOW)", "BALANCED (MED)", "ULTRA (HIGH)"]
		var q_idx: int = clampi(int(gs.graphics_quality), 0, 2)
		if graphics_button:
			graphics_button.text = "GRAPHICS: " + q_names[q_idx]
		
		var scale_pct := int(roundf(float(gs.resolution_scale) * 100.0))
		if resolution_button:
			resolution_button.text = "RESOLUTION: " + str(scale_pct) + "%"

	# Sound on/off lives in the pause menu too (lab Phase 6), not only in Settings.
	var audio_mgr := get_node_or_null("/root/AudioManager")
	var sfx_on: bool = audio_mgr == null or audio_mgr.sfx_enabled == true
	var music_on: bool = audio_mgr == null or audio_mgr.music_enabled == true
	if sound_button:
		sound_button.text = "SOUND FX: " + ("ON" if sfx_on else "MUTED")
		UiIcons.apply(sound_button, "sound_on" if sfx_on else "sound_off", 22)
	if music_button:
		music_button.text = "MUSIC: " + ("ON" if music_on else "MUTED")
		UiIcons.apply(music_button, "music" if music_on else "sound_off", 22)

func _on_sound_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("set_sfx_enabled"):
		audio_mgr.set_sfx_enabled(not (audio_mgr.sfx_enabled == true))
	_refresh_settings_buttons()

func _on_music_pressed() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("set_music_enabled"):
		audio_mgr.set_music_enabled(not (audio_mgr.music_enabled == true))
	_refresh_settings_buttons()

func _on_graphics_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("cycle_graphics_quality"):
		gs.cycle_graphics_quality()
	_refresh_settings_buttons()

func _on_resolution_pressed() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("cycle_resolution_scale"):
		gs.cycle_resolution_scale()
	_refresh_settings_buttons()

func show_save_confirmation(success: bool) -> void:
	if not status_label:
		return
	if success:
		status_label.text = "[ OUTPOST LOG UPDATED — PROGRESS SAVED! ]"
		status_label.add_theme_color_override("font_color", Color(0.28, 0.92, 0.42))
	else:
		status_label.text = "[ ERROR: FAILED TO WRITE SAVE FILE ]"
		status_label.add_theme_color_override("font_color", Color(0.95, 0.28, 0.28))

func _on_resume_pressed() -> void:
	close_pause_menu()
	resume_requested.emit()

func _on_save_pressed() -> void:
	save_requested.emit()

func _on_retry_pressed() -> void:
	close_pause_menu()
	retry_requested.emit()

func _on_main_menu_pressed() -> void:
	close_pause_menu()
	main_menu_requested.emit()
