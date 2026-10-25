extends Area2D

signal hit_target(target: Node2D, damage: float)

@export var speed: float = 750.0
@export var damage: float = 25.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null
var pierce_remaining: int = 1
var knockback_force: float = 80.0
var is_acid_spit: bool = false
var tracer_color: Color = Color(0.98, 0.84, 0.32, 1.0)
var hit_bodies: Array[Node2D] = []

@onready var lifetime_timer: Timer = $LifetimeTimer
@onready var bullet_visual: Control = get_node_or_null("BulletVisual")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if bullet_visual:
		bullet_visual.visible = false # We use custom _draw() for richer tracer visuals
	if lifetime_timer:
		lifetime_timer.wait_time = lifetime
		lifetime_timer.timeout.connect(_on_lifetime_timeout)
		lifetime_timer.start()

func init(start_pos: Vector2, shoot_dir: Vector2, bullet_speed: float, bullet_damage: float, shooter_ref: Node2D, p_pierce: int = 1, p_color: Color = Color(0.98, 0.84, 0.32, 1.0), p_acid: bool = false) -> void:
	global_position = start_pos
	direction = shoot_dir.normalized() if shoot_dir != Vector2.ZERO else Vector2.RIGHT
	speed = bullet_speed
	damage = bullet_damage
	shooter = shooter_ref
	pierce_remaining = max(1, p_pierce)
	tracer_color = p_color
	is_acid_spit = p_acid
	rotation = direction.angle()
	
	if is_acid_spit:
		collision_mask = 9 # Layer 1 Walls + Layer 4 Players
	else:
		collision_mask = 3 # Layer 1 Walls + Layer 2 Enemies
	queue_redraw()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _draw() -> void:
	if is_acid_spit:
		# Glowing toxic green spit glob with trail
		draw_line(Vector2(-16, 0), Vector2.ZERO, Color(0.35, 0.85, 0.15, 0.55), 5.0)
		draw_circle(Vector2.ZERO, 6.5, Color(0.35, 0.88, 0.14, 0.90))
		draw_circle(Vector2(1.5, 0), 3.8, Color(0.78, 1.0, 0.45, 0.95))
	else:
		# High-velocity bullet tracer streak + bright core
		var trail_len := 22.0 if pierce_remaining > 1 else 14.0
		var width := 3.5 if pierce_remaining > 1 else 2.4
		draw_line(Vector2(-trail_len, 0), Vector2(4, 0), Color(tracer_color.r, tracer_color.g, tracer_color.b, 0.45), width + 2.0)
		draw_line(Vector2(-trail_len * 0.6, 0), Vector2(5, 0), tracer_color, width)
		draw_circle(Vector2(4, 0), width * 0.65, Color(1.0, 0.98, 0.90, 1.0))

func _on_body_entered(body: Node2D) -> void:
	if body == shooter or hit_bodies.has(body):
		return
	
	if is_acid_spit and body.is_in_group("enemies"):
		return
	if not is_acid_spit and body.is_in_group("players"):
		return
	
	if body.has_method("take_damage"):
		hit_bodies.append(body)
		if body.has_method("apply_hit_impulse"):
			body.apply_hit_impulse(direction * knockback_force)
		body.take_damage(damage)
		hit_target.emit(body, damage)
		
		if is_acid_spit:
			_spawn_acid_hazard()
			queue_free()
			return
		
		pierce_remaining -= 1
		if pierce_remaining <= 0:
			queue_free()
		return
	
	if body is StaticBody2D or body is TileMap:
		if is_acid_spit:
			_spawn_acid_hazard()
		queue_free()

func _on_lifetime_timeout() -> void:
	if is_acid_spit:
		_spawn_acid_hazard()
	queue_free()

func _spawn_acid_hazard() -> void:
	var parent_node := get_parent()
	if not parent_node:
		return
	var pool := Area2D.new()
	pool.set_script(load("res://scripts/acid_pool.gd"))
	pool.global_position = global_position
	parent_node.call_deferred("add_child", pool)
