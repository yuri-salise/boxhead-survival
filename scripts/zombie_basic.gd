extends CharacterBody2D

signal zombie_died(zombie: Node2D)
signal hit_player(target: Node2D, damage: float)

@export var speed: float = 145.0
@export var max_health: float = 50.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.8

var current_health: float = 50.0
var is_dead: bool = false
var target_player: Node2D = null

var can_attack: bool = true
var attack_timer: float = 0.0

@onready var visuals: Node2D = $Visuals
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	current_health = max_health
	is_dead = false
	can_attack = true

func _physics_process(delta: float) -> void:
	update_attack_cooldown(delta)
	
	if is_dead:
		return
	
	# Auto-acquire target player if none assigned
	if not is_instance_valid(target_player) or (target_player.get("is_dead") == true):
		target_player = _find_nearest_living_player()
	
	if is_instance_valid(target_player):
		var dir = get_pursuit_direction()
		if dir != Vector2.ZERO:
			visuals.rotation = dir.angle()
			velocity = dir * speed
			move_and_slide()
			
			# Check contact attacks
			for i in range(get_slide_collision_count()):
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if is_instance_valid(collider) and collider.is_in_group("players"):
					try_attack_target(collider)

func set_target(player: Node2D) -> void:
	target_player = player

func get_pursuit_direction() -> Vector2:
	if is_instance_valid(target_player):
		return (target_player.global_position - global_position).normalized()
	return Vector2.ZERO

func try_attack_target(target: Node2D) -> bool:
	if not can_attack or is_dead:
		return false
	
	can_attack = false
	attack_timer = attack_cooldown
	
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
		hit_player.emit(target, attack_damage)
		return true
	return false

func update_attack_cooldown(delta: float) -> void:
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0.0:
			can_attack = true

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	
	current_health = max(0.0, current_health - amount)
	
	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	zombie_died.emit(self)
	
	# Visual death fade/queue_free
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _find_nearest_living_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var min_dist: float = INF
	
	for p in players:
		if is_instance_valid(p) and p.get("is_dead") != true:
			var d = global_position.distance_squared_to(p.global_position)
			if d < min_dist:
				min_dist = d
				nearest = p
	return nearest
