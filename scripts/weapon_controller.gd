extends Node

signal shot_fired(projectile: Node2D)

@export var projectile_scene: PackedScene = preload("res://scenes/actors/projectile.tscn")
@export var fire_rate: float = 0.2
@export var damage: float = 25.0
@export var projectile_speed: float = 850.0

var cooldown_remaining: float = 0.0

func _process(delta: float) -> void:
	update_cooldown(delta)

func update_cooldown(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_shoot() -> bool:
	return cooldown_remaining <= 0.0

func try_fire(spawn_pos: Vector2, shoot_dir: Vector2, shooter: Node2D) -> Node2D:
	if not can_shoot():
		return null
	
	if not projectile_scene:
		return null
	
	cooldown_remaining = fire_rate
	
	var proj = projectile_scene.instantiate()
	if shooter.get_parent():
		shooter.get_parent().add_child(proj)
	else:
		shooter.add_child(proj)
		
	proj.init(spawn_pos, shoot_dir, projectile_speed, damage, shooter)
	shot_fired.emit(proj)
	return proj
