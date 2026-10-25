extends CharacterBody2D

signal health_changed(current_health: float, max_health: float)
signal player_died()

@export var speed: float = 280.0
@export var max_health: float = 100.0

var current_health: float = 100.0
var is_dead: bool = false

# External input overrides (e.g. mobile virtual sticks or multiplayer sync)
var input_override_enabled: bool = false
var override_move_vec: Vector2 = Vector2.ZERO
var override_aim_pos: Vector2 = Vector2.ZERO
var override_is_shooting: bool = false

@onready var visuals: Node2D = $Visuals
@onready var muzzle_marker: Marker2D = $Visuals/MuzzlePoint
@onready var weapon_controller: Node = $WeaponController

func _ready() -> void:
	current_health = max_health
	is_dead = false

func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	
	var move_vec: Vector2
	var aim_pos: Vector2
	var shooting: bool
	
	if input_override_enabled:
		move_vec = override_move_vec
		aim_pos = override_aim_pos
		shooting = override_is_shooting
	else:
		# Desktop default input
		move_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		# Also support WASD directly
		if move_vec == Vector2.ZERO:
			var dx = (1 if Input.is_key_pressed(KEY_D) else 0) - (1 if Input.is_key_pressed(KEY_A) else 0)
			var dy = (1 if Input.is_key_pressed(KEY_S) else 0) - (1 if Input.is_key_pressed(KEY_W) else 0)
			move_vec = Vector2(dx, dy)
		
		aim_pos = get_global_mouse_position()
		shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Handle movement
	velocity = move_vec.normalized() * speed
	move_and_slide()
	
	# Handle aiming
	if aim_pos != Vector2.ZERO and aim_pos != global_position:
		var aim_dir = (aim_pos - global_position).normalized()
		visuals.rotation = aim_dir.angle()
		
		# Handle firing
		if shooting and weapon_controller:
			var muzzle_global = get_muzzle_position()
			weapon_controller.try_fire(muzzle_global, aim_dir, self)

func get_muzzle_position() -> Vector2:
	if muzzle_marker:
		return muzzle_marker.global_position
	return global_position

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		die()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	player_died.emit()

func set_input_override(move_vec: Vector2, aim_pos: Vector2, is_shooting: bool) -> void:
	input_override_enabled = true
	override_move_vec = move_vec
	override_aim_pos = aim_pos
	override_is_shooting = is_shooting
