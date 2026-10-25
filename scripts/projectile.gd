extends Area2D

signal hit_target(target: Node2D, damage: float)

@export var speed: float = 750.0
@export var damage: float = 25.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var shooter: Node2D = null

@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if lifetime_timer:
		lifetime_timer.wait_time = lifetime
		lifetime_timer.timeout.connect(_on_lifetime_timeout)
		lifetime_timer.start()

func init(start_pos: Vector2, shoot_dir: Vector2, bullet_speed: float, bullet_damage: float, shooter_ref: Node2D) -> void:
	global_position = start_pos
	direction = shoot_dir.normalized()
	speed = bullet_speed
	damage = bullet_damage
	shooter = shooter_ref
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Ignore shooter
	if body == shooter:
		return
	
	# Damage target if destructible/damageable
	if body.has_method("take_damage"):
		body.take_damage(damage)
		hit_target.emit(body, damage)
		queue_free()
		return
	
	# Wall / obstacle collision
	if body is StaticBody2D or body is TileMap:
		queue_free()

func _on_lifetime_timeout() -> void:
	queue_free()
