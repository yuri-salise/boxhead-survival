extends Node2D

@onready var return_button: Button = $UI/MarginContainer/TopBar/ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_button_pressed)

func _on_return_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_button_pressed()
