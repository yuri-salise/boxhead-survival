extends Node2D

@export var zombie_scene: PackedScene = preload("res://scenes/actors/zombie_basic.tscn")
@export var max_alive_zombies: int = 15

@onready var player: CharacterBody2D = $Player
@onready var zombie_container: Node2D = $ZombieContainer
@onready var spawn_timer: Timer = $SpawnTimer

# UI references
@onready var health_bar: ProgressBar = $UI/MarginContainer/TopBar/HealthContainer/HealthBar
@onready var health_label: Label = $UI/MarginContainer/TopBar/HealthContainer/HealthLabel
@onready var kills_label: Label = $UI/MarginContainer/TopBar/KillsLabel
@onready var top_return_button: Button = $UI/MarginContainer/TopBar/ReturnButton

@onready var death_panel: PanelContainer = $UI/DeathPanel
@onready var death_kills_label: Label = $UI/DeathPanel/DeathMargin/DeathVBox/DeathKillsLabel
@onready var restart_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/RestartButton
@onready var menu_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/MenuButton

var kills_count: int = 0

func _ready() -> void:
	if death_panel:
		death_panel.visible = false
	
	if player:
		player.add_to_group("players")
		player.health_changed.connect(_on_player_health_changed)
		player.player_died.connect(_on_player_died)
		_on_player_health_changed(player.current_health, player.max_health)
	
	if top_return_button:
		top_return_button.pressed.connect(_on_return_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_return_pressed)
	
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()
	
	_update_kills_display()

func _on_player_health_changed(cur: float, max_h: float) -> void:
	if health_bar:
		health_bar.max_value = max_h
		health_bar.value = cur
	if health_label:
		health_label.text = "HEALTH: " + str(int(cur)) + " / " + str(int(max_h))

func _on_player_died() -> void:
	if spawn_timer:
		spawn_timer.stop()
	if death_panel:
		death_panel.visible = true
		if death_kills_label:
			death_kills_label.text = "OUTPOST OVERRUN — SURVIVED AND ELIMINATED " + str(kills_count) + " WALKERS"

func spawn_test_zombie_at(spawn_pos: Vector2) -> Node2D:
	if not zombie_scene or not zombie_container:
		return null
		
	var zombie = zombie_scene.instantiate()
	zombie.position = spawn_pos
	zombie_container.add_child(zombie)
	zombie.zombie_died.connect(_on_zombie_killed)
	if is_instance_valid(player):
		zombie.set_target(player)
	return zombie

func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	
	if zombie_container.get_child_count() >= max_alive_zombies:
		return
	
	# Spawn randomly around arena perimeter
	var spawn_points = [
		Vector2(randf_range(80, 1200), 70),   # Top
		Vector2(randf_range(80, 1200), 650),  # Bottom
		Vector2(70, randf_range(80, 640)),    # Left
		Vector2(1210, randf_range(80, 640))   # Right
	]
	var pos = spawn_points[randi() % spawn_points.size()]
	spawn_test_zombie_at(pos)

func _on_zombie_killed(_zombie: Node2D) -> void:
	kills_count += 1
	_update_kills_display()

func _update_kills_display() -> void:
	if kills_label:
		kills_label.text = "WALKERS KILLED: " + str(kills_count)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_return_pressed()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		_on_restart_pressed()
