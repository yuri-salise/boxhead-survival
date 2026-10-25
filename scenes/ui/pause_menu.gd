extends Control

signal resume_requested()
signal save_requested()
signal retry_requested()
signal main_menu_requested()

@onready var backdrop: ColorRect = $PauseBackdrop
@onready var status_label: Label = $CenterContainer/PausePanel/PauseMargin/PauseVBox/SaveStatusLabel
@onready var resume_button: Button = $CenterContainer/PausePanel/PauseMargin/PauseVBox/ResumeButton
@onready var save_button: Button = $CenterContainer/PausePanel/PauseMargin/PauseVBox/SaveButton
@onready var retry_button: Button = $CenterContainer/PausePanel/PauseMargin/PauseVBox/RetryButton
@onready var main_menu_button: Button = $CenterContainer/PausePanel/PauseMargin/PauseVBox/MainMenuButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if save_button:
		save_button.pressed.connect(_on_save_pressed)
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_pressed)

func open_pause_menu() -> void:
	visible = true
	if status_label:
		status_label.text = "[ TACTICAL FIELD TERMINAL // GAME PAUSED ]"
		status_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.20))
	get_tree().paused = true

func close_pause_menu() -> void:
	visible = false
	get_tree().paused = false

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
