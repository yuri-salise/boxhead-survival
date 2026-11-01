extends Control

## TitleScreen / SplashScreen for Dead Block: Survival
## Presents studio and game branding, handles skip on touch/key input,
## and transitions cleanly to the Main Menu.

@export var auto_advance_delay: float = 4.0
@export var next_scene_path: String = "res://scenes/ui/main_menu.tscn"

@onready var logo_texture: TextureRect = $CenterContainer/MainVBox/LogoContainer/LogoTexture
@onready var studio_badge: TextureRect = $CenterContainer/MainVBox/StudioBadge
@onready var prompt_label: Label = $CenterContainer/MainVBox/PromptContainer/PromptLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

var is_transitioning: bool = false
var prompt_tween: Tween = null
var auto_timer: SceneTreeTimer = null

func _ready() -> void:
	# Ensure fade overlay starts covering screen for smooth intro
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate.a = 1.0
		var intro_tween = create_tween()
		intro_tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.45)
	
	# Start pulsing prompt animation
	_start_prompt_animation()
	
	# Play intro atmospheric audio cue if available
	_play_intro_audio()
	
	# Auto-advance after delay
	auto_timer = get_tree().create_timer(auto_advance_delay)
	auto_timer.timeout.connect(_on_auto_advance_timeout)

func _play_intro_audio() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		if audio_mgr.has_method("play_music"):
			audio_mgr.play_music("ambient_menu")
		if audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("sfx_wave_start")

func _start_prompt_animation() -> void:
	if not prompt_label:
		return
	
	prompt_tween = create_tween().set_loops()
	prompt_tween.tween_property(prompt_label, "modulate:a", 0.25, 0.7).set_trans(Tween.TRANS_SINE)
	prompt_tween.tween_property(prompt_label, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

func _on_auto_advance_timeout() -> void:
	advance_to_main_menu()

func _gui_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	
	if event is InputEventMouseButton and event.pressed:
		advance_to_main_menu()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		advance_to_main_menu()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	
	# Advance on any key, joypad button, or mouse click
	if event is InputEventKey and event.pressed and not event.echo:
		advance_to_main_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		advance_to_main_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		advance_to_main_menu()
		get_viewport().set_input_as_handled()

func advance_to_main_menu() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	
	if prompt_tween and prompt_tween.is_valid():
		prompt_tween.kill()
	
	if is_inside_tree():
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr and audio_mgr.has_method("play_sfx"):
			audio_mgr.play_sfx("sfx_pistol")
	
	if fade_overlay and is_inside_tree():
		fade_overlay.visible = true
		var out_tween = create_tween()
		out_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.35)
		out_tween.finished.connect(_change_scene)
	else:
		_change_scene()

func _change_scene() -> void:
	if is_inside_tree() and get_tree():
		get_tree().change_scene_to_file(next_scene_path)
