extends CharacterBody2D

signal zombie_died(zombie: Node2D)
signal hit_player(target: Node2D, damage: float)
signal blood_splashed(world_pos: Vector2, dir: Vector2, splatter_type: int, scale_mult: float)
signal limb_severed(world_pos: Vector2, dir: Vector2, limb_kind: int, skin_color: Color, scale_mult: float)
signal boomer_exploded(world_pos: Vector2, radius: float, damage: float)
signal witch_startled(witch: Node2D)
signal drop_requested(world_pos: Vector2, zombie_type_name: String)

enum ZombieType {
	WALKER,
	RUNNER,
	BOOMER,
	TANK,
	SPITTER,
	WITCH
}

const ZOMBIE_CONFIGS: Dictionary = {
	ZombieType.WALKER: {
		"name": "WALKER",
		"hp": 50.0,
		"speed": 145.0,
		"damage": 15.0,
		"cooldown": 0.80,
		"scale": 1.0,
		"score": 10,
		"skin": Color(0.46, 0.52, 0.42, 1.0)
	},
	ZombieType.RUNNER: {
		"name": "RUNNER",
		"hp": 40.0,
		"speed": 238.0,
		"damage": 12.0,
		"cooldown": 0.55,
		"scale": 0.92,
		"score": 18,
		"skin": Color(0.58, 0.46, 0.44, 1.0)
	},
	ZombieType.BOOMER: {
		"name": "BOOMER",
		"hp": 95.0,
		"speed": 92.0,
		"damage": 20.0,
		"cooldown": 1.00,
		"scale": 1.35,
		"score": 30,
		"skin": Color(0.46, 0.58, 0.24, 1.0)
	},
	ZombieType.TANK: {
		"name": "TANKER",
		"hp": 320.0,
		"speed": 100.0,
		"damage": 35.0,
		"cooldown": 1.10,
		"scale": 1.75,
		"score": 75,
		"skin": Color(0.38, 0.28, 0.30, 1.0)
	},
	ZombieType.SPITTER: {
		"name": "SPITTER",
		"hp": 65.0,
		"speed": 125.0,
		"damage": 12.0,
		"cooldown": 0.90,
		"scale": 1.0,
		"score": 28,
		"skin": Color(0.48, 0.62, 0.44, 1.0)
	},
	ZombieType.WITCH: {
		"name": "WITCH",
		"hp": 170.0,
		"speed": 42.0, # Enrages to 305.0 when startled!
		"damage": 38.0,
		"cooldown": 0.50,
		"scale": 1.05,
		"score": 60,
		"skin": Color(0.80, 0.78, 0.76, 1.0)
	}
}

@export var zombie_type: int = ZombieType.WALKER
@export var speed: float = 145.0
@export var max_health: float = 50.0
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 0.8
@export var projectile_scene: PackedScene = preload("res://scenes/actors/projectile.tscn")
@export var blood_splatter_scene: PackedScene = preload("res://scenes/effects/blood_splatter.tscn")

var current_health: float = 50.0
var is_dead: bool = false
var target_player: Node2D = null

var is_network_puppet: bool = false
var target_sync_pos: Vector2 = Vector2.ZERO
var target_sync_rot: float = 0.0

var can_attack: bool = true
var attack_timer: float = 0.0
var spit_cooldown: float = 2.2
var is_enraged: bool = false
var score_value: int = 10

# Anatomical dismemberment state
var has_left_arm: bool = true
var has_right_arm: bool = true
var has_legs: bool = true
var has_head: bool = true
var is_crawling: bool = false
var limbs_severed_count: int = 0
var torso_wounds: Array[Vector2] = []
var crawl_blood_timer: float = 0.0

var anim_time: float = 0.0
var hurt_flash_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var last_hit_dir: Vector2 = Vector2.RIGHT
var terrain_speed_mult: float = 1.0
var terrain_check_timer: float = 999.0

@onready var visuals: Node2D = $Visuals
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	anim_time = randf() * 10.0
	current_health = max_health
	is_dead = false
	can_attack = true
	
	if visuals:
		for child in visuals.get_children():
			if child is ColorRect:
				child.visible = false

func configure_type(p_type: int) -> void:
	zombie_type = p_type
	var cfg: Dictionary = ZOMBIE_CONFIGS.get(zombie_type, ZOMBIE_CONFIGS[ZombieType.WALKER])
	max_health = float(cfg["hp"])
	current_health = max_health
	speed = float(cfg["speed"])
	attack_damage = float(cfg["damage"])
	attack_cooldown = float(cfg["cooldown"])
	score_value = int(cfg["score"])
	is_enraged = false
	
	has_left_arm = true
	has_right_arm = true
	has_legs = true
	has_head = true
	is_crawling = false
	limbs_severed_count = 0
	torso_wounds.clear()
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		var dup_shape := (collision_shape.shape as CircleShape2D).duplicate() as CircleShape2D
		dup_shape.radius = 16.0 * float(cfg["scale"])
		collision_shape.shape = dup_shape
	queue_redraw()

func get_type_name() -> String:
	var cfg: Dictionary = ZOMBIE_CONFIGS.get(zombie_type, ZOMBIE_CONFIGS[ZombieType.WALKER])
	return str(cfg["name"])

func get_skin_color() -> Color:
	var cfg: Dictionary = ZOMBIE_CONFIGS.get(zombie_type, ZOMBIE_CONFIGS[ZombieType.WALKER])
	return cfg.get("skin", Color(0.46, 0.52, 0.42, 1.0))

func get_scale_factor() -> float:
	var cfg: Dictionary = ZOMBIE_CONFIGS.get(zombie_type, ZOMBIE_CONFIGS[ZombieType.WALKER])
	return float(cfg.get("scale", 1.0))

func _physics_process(delta: float) -> void:
	anim_time += delta
	update_attack_cooldown(delta)
	if hurt_flash_timer > 0.0:
		hurt_flash_timer = maxf(0.0, hurt_flash_timer - delta)
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 650.0 * delta)
	
	if is_dead:
		queue_redraw()
		return
	
	if is_network_puppet:
		if target_sync_pos != Vector2.ZERO:
			if global_position.distance_squared_to(target_sync_pos) > 10000.0:
				global_position = target_sync_pos
			else:
				global_position = global_position.lerp(target_sync_pos, minf(1.0, delta * 15.0))
		if visuals:
			visuals.rotation = lerp_angle(visuals.rotation, target_sync_rot, minf(1.0, delta * 15.0))
		if velocity.length_squared() > 4.0 or hurt_flash_timer > 0.0 or is_enraged or not has_legs:
			queue_redraw()
		return
	
	if not is_instance_valid(target_player) or (target_player.get("is_dead") == true):
		target_player = _find_nearest_living_player()
	
	if is_instance_valid(target_player):
		var dist := global_position.distance_to(target_player.global_position)
		var dir := get_pursuit_direction()
		
		# Witch startle proximity check
		if zombie_type == ZombieType.WITCH and not is_enraged and dist < 165.0:
			_trigger_witch_enrage()
		
		# Spitter ranged acid attack
		if zombie_type == ZombieType.SPITTER:
			spit_cooldown -= delta
			if dist < 310.0 and spit_cooldown <= 0.0:
				_fire_acid_spit(dir)
				spit_cooldown = 3.2
		
		if dir != Vector2.ZERO:
			if visuals:
				visuals.rotation = dir.angle()
			
			var move_spd := speed
			terrain_check_timer += delta
			if terrain_check_timer >= 0.20:
				terrain_check_timer = randf_range(-0.04, 0.04)
				var z_parent := get_parent()
				if z_parent and z_parent.get_parent():
					var arena = z_parent.get_parent().get_node_or_null("ArenaEnvironment")
					if arena and arena.has_method("get_speed_multiplier_at"):
						terrain_speed_mult = arena.get_speed_multiplier_at(global_position)
			move_spd *= terrain_speed_mult
			if zombie_type == ZombieType.SPITTER and dist < 210.0:
				move_spd = speed * 0.35
			if is_crawling:
				move_spd *= 0.52 # Crawling with severed legs is slower and leaves a bloody trail
				crawl_blood_timer += delta
				if crawl_blood_timer >= 0.42:
					crawl_blood_timer = 0.0
					blood_splashed.emit(global_position, -dir, 4, 0.58)
			
			velocity = dir * move_spd + knockback_velocity
			move_and_slide()
			
			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				var collider := collision.get_collider()
				if is_instance_valid(collider) and collider.is_in_group("players"):
					try_attack_target(collider)
	
	if not is_dead and (velocity.length_squared() > 4.0 or hurt_flash_timer > 0.0 or is_enraged or not has_legs):
		queue_redraw()

func _trigger_witch_enrage() -> void:
	if is_enraged:
		return
	is_enraged = true
	speed = 305.0
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_witch")
	witch_startled.emit(self)

func _fire_acid_spit(dir: Vector2) -> void:
	if not projectile_scene or not get_parent():
		return
	var spit: Node2D = projectile_scene.instantiate()
	get_parent().add_child(spit)
	spit.init(global_position + dir * 20.0, dir, 440.0, 14.0, self, 1, Color(0.45, 0.95, 0.18), true)

func apply_hit_impulse(impulse: Vector2) -> void:
	var resist := 0.25 if zombie_type == ZombieType.TANK else 1.0
	knockback_velocity = impulse * resist
	if impulse != Vector2.ZERO:
		last_hit_dir = impulse.normalized()

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
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_bite")
	
	if target.has_method("take_damage_from"):
		target.take_damage_from(attack_damage, global_position)
		hit_player.emit(target, attack_damage)
		return true
	elif target.has_method("take_damage"):
		target.take_damage(attack_damage)
		hit_player.emit(target, attack_damage)
		return true
	return false

func update_attack_cooldown(delta: float) -> void:
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0.0:
			can_attack = true

func sever_next_limb(impulse_dir: Vector2 = Vector2.RIGHT) -> String:
	var dir := impulse_dir.normalized() if impulse_dir != Vector2.ZERO else last_hit_dir
	var sc := get_scale_factor()
	var skin := get_skin_color()
	
	# Sever order: Left Arm -> Right Arm -> Legs (Crawling) -> Rib chunk
	if has_left_arm:
		has_left_arm = false
		limbs_severed_count += 1
		attack_damage = maxf(5.0, attack_damage * 0.85)
		limb_severed.emit(global_position + Vector2(0, -8), dir.rotated(-0.35), 0, skin, sc)
		queue_redraw()
		return "LEFT_ARM"
	elif has_right_arm:
		has_right_arm = false
		limbs_severed_count += 1
		attack_damage = maxf(5.0, attack_damage * 0.85)
		limb_severed.emit(global_position + Vector2(0, 8), dir.rotated(0.35), 0, skin, sc)
		queue_redraw()
		return "RIGHT_ARM"
	elif has_legs:
		has_legs = false
		is_crawling = true
		limbs_severed_count += 1
		limb_severed.emit(global_position, dir.rotated(randf_range(-0.4, 0.4)), 1, skin, sc)
		queue_redraw()
		return "LEGS"
	else:
		limbs_severed_count += 1
		limb_severed.emit(global_position, dir, 3, skin, sc)
		return "RIB_CHUNK"

func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	
	if is_network_puppet:
		hurt_flash_timer = 0.10
		var audio_mgr := get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_sfx("sfx_zombie_hit")
		var s_type := 6 if zombie_type == ZombieType.BOOMER else -1
		blood_splashed.emit(global_position, last_hit_dir, s_type, 0.85)
		if blood_splatter_scene and get_parent():
			var b_fx = blood_splatter_scene.instantiate()
			b_fx.global_position = global_position
			var b_col := Color(0.45, 0.82, 0.20) if zombie_type == ZombieType.BOOMER else Color(0.68, 0.08, 0.08)
			b_fx.setup(last_hit_dir, b_col, 8)
			get_parent().add_child(b_fx)
		var tree := get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("report_client_zombie_hit"):
			var z_id: int = int(get_meta("net_id")) if has_meta("net_id") else -1
			tree.current_scene.report_client_zombie_hit(z_id, amount, last_hit_dir)
		return
	
	var prev_ratio := current_health / maxf(1.0, max_health)
	hurt_flash_timer = 0.10
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_zombie_hit")
	
	if zombie_type == ZombieType.WITCH and not is_enraged:
		_trigger_witch_enrage()
	
	current_health = max(0.0, current_health - amount)
	var new_ratio := current_health / maxf(1.0, max_health)
	
	# Add visible flesh wound on torso
	if torso_wounds.size() < 6:
		torso_wounds.append(Vector2(randf_range(-7.0, 5.0), randf_range(-8.0, 8.0)))
	
	# Dismemberment trigger: crossing 75%, 45%, 20% health or taking heavy caliber hit (>= 18 dmg)
	if current_health > 0.0:
		var crossed_threshold := (prev_ratio > 0.75 and new_ratio <= 0.75) or (prev_ratio > 0.45 and new_ratio <= 0.45) or (prev_ratio > 0.22 and new_ratio <= 0.22)
		if crossed_threshold or (amount >= 18.0 and limbs_severed_count == 0):
			sever_next_limb(last_hit_dir)
	
	# Emit active blood splash on hit
	var s_type := 6 if zombie_type == ZombieType.BOOMER else -1
	blood_splashed.emit(global_position, last_hit_dir, s_type, 0.85)
	if blood_splatter_scene and get_parent():
		var b_fx = blood_splatter_scene.instantiate()
		b_fx.global_position = global_position
		var b_col := Color(0.45, 0.82, 0.20) if zombie_type == ZombieType.BOOMER else Color(0.68, 0.08, 0.08)
		b_fx.setup(last_hit_dir, b_col, 8)
		get_parent().add_child(b_fx)
	
	if current_health <= 0.0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		if zombie_type == ZombieType.BOOMER:
			audio_mgr.play_sfx("sfx_boomer")
		else:
			audio_mgr.play_sfx("sfx_zombie_death")
	
	var sc := get_scale_factor()
	var skin := get_skin_color()
	
	# Pop off head and/or remaining limb on lethal impact for realistic gore
	if has_head and zombie_type != ZombieType.BOOMER:
		has_head = false
		limbs_severed_count += 1
		limb_severed.emit(global_position, last_hit_dir, 2, skin, sc)
	if has_left_arm and randf() < 0.65:
		sever_next_limb(last_hit_dir)
	
	# Death blood / gore splatter
	if zombie_type == ZombieType.BOOMER:
		blood_splashed.emit(global_position, last_hit_dir, 6, 1.85)
		limb_severed.emit(global_position, last_hit_dir.rotated(0.6), 3, skin, sc)
		limb_severed.emit(global_position, last_hit_dir.rotated(-0.6), 0, skin, sc)
		boomer_exploded.emit(global_position, 130.0, 28.0)
	elif zombie_type == ZombieType.TANK:
		blood_splashed.emit(global_position, last_hit_dir, 5, 1.90)
		limb_severed.emit(global_position, last_hit_dir.rotated(0.5), 3, skin, sc)
	else:
		blood_splashed.emit(global_position, last_hit_dir, 1 if randf() < 0.5 else 5, 1.35)
	
	# Spitter leaves an acid puddle on death
	if zombie_type == ZombieType.SPITTER and get_parent():
		var pool := Area2D.new()
		pool.set_script(load("res://scripts/acid_pool.gd"))
		pool.global_position = global_position
		get_parent().call_deferred("add_child", pool)
	
	drop_requested.emit(global_position, get_type_name())
	zombie_died.emit(self)
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.32)
	tween.tween_callback(queue_free)

func _find_nearest_living_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var min_dist: float = INF
	
	for p in players:
		if is_instance_valid(p) and p.get("is_dead") != true:
			var d := global_position.distance_squared_to(p.global_position)
			if d < min_dist:
				min_dist = d
				nearest = p
	return nearest

func _draw_arm_or_stump(start_p: Vector2, end_p: Vector2, arm_col: Color, width: float, claw_col: Color, claw_r: float, is_present: bool) -> void:
	if is_present:
		draw_line(start_p, end_p, arm_col, width)
		draw_circle(end_p, claw_r, claw_col)
	else:
		# Jagged bleeding shoulder stump + protruding white humerus bone
		var stump_dir := (end_p - start_p).normalized()
		draw_circle(start_p + stump_dir * 2.0, width * 0.72, Color(0.68, 0.05, 0.05, 1.0))
		draw_line(start_p, start_p + stump_dir * 6.5, Color(0.90, 0.86, 0.78, 1.0), width * 0.45)
		draw_circle(start_p + stump_dir * 4.5, 2.0, Color(0.85, 0.08, 0.08, 0.95))

func _draw() -> void:
	var cfg: Dictionary = ZOMBIE_CONFIGS.get(zombie_type, ZOMBIE_CONFIGS[ZombieType.WALKER])
	var sc: float = float(cfg["scale"])
	var rot := visuals.rotation if visuals else 0.0
	var sway := sin(anim_time * (12.0 if zombie_type == ZombieType.RUNNER or is_enraged else 5.5)) * 3.0
	
	# 1. Realistic Multi-Layered Directional Cast Shadow + Contact Shadow
	draw_circle(Vector2(9.0 * sc, 12.0 * sc), 13.5 * sc, Color(0.0, 0.0, 0.0, 0.26))
	draw_circle(Vector2(5.0 * sc, 7.0 * sc), 15.0 * sc, Color(0.0, 0.0, 0.0, 0.40))
	draw_circle(Vector2(0.0, 2.0 * sc), 13.0 * sc, Color(0.0, 0.0, 0.0, 0.55))
	
	# Witch warning ring when stalking/weeping
	if zombie_type == ZombieType.WITCH:
		var ring_col := Color(0.95, 0.15, 0.15, 0.45) if is_enraged else Color(0.85, 0.25, 0.25, 0.18 + 0.10 * sin(anim_time * 4.0))
		draw_arc(Vector2.ZERO, 24.0 if is_enraged else 38.0, 0.0, TAU, 28, ring_col, 2.0)
	
	draw_set_transform(Vector2.ZERO, rot, Vector2(sc, sc))
	
	# Draw zombie legs or bloody severed leg stumps when crawling
	if has_legs:
		var leg_step := sin(anim_time * 8.0) * 4.5
		draw_rect(Rect2(Vector2(-12 + leg_step, -9), Vector2(7, 5)), Color(0.16, 0.17, 0.15, 1.0), true)
		draw_rect(Rect2(Vector2(-12 - leg_step, 4), Vector2(7, 5)), Color(0.16, 0.17, 0.15, 1.0), true)
	else:
		# Crawling zombie: trailing bloody pelvis & exposed femur stumps
		draw_circle(Vector2(-11, -5), 4.0, Color(0.62, 0.04, 0.05, 0.95))
		draw_circle(Vector2(-11, 5), 4.0, Color(0.62, 0.04, 0.05, 0.95))
		draw_line(Vector2(-10, -5), Vector2(-16, -6), Color(0.88, 0.84, 0.75, 1.0), 2.5)
		draw_line(Vector2(-10, 5), Vector2(-16, 6), Color(0.88, 0.84, 0.75, 1.0), 2.5)
	
	match zombie_type:
		ZombieType.WALKER:
			var body_c := Color(0.32, 0.36, 0.30, 1.0) if hurt_flash_timer <= 0.0 else Color(0.95, 0.3, 0.3, 1.0)
			_draw_arm_or_stump(Vector2(2, -11), Vector2(18, -7 + sway * 0.5), Color(0.46, 0.52, 0.42, 1.0), 5.0, Color(0.65, 0.12, 0.12, 1.0), 3.2, has_left_arm)
			_draw_arm_or_stump(Vector2(2, 11), Vector2(18, 7 - sway * 0.5), Color(0.46, 0.52, 0.42, 1.0), 5.0, Color(0.65, 0.12, 0.12, 1.0), 3.2, has_right_arm)
			draw_rect(Rect2(Vector2(-10, -13), Vector2(18, 26)), body_c, true)
			draw_circle(Vector2(-2, 5), 5.0, Color(0.48, 0.08, 0.08, 0.85))
			if has_head:
				draw_circle(Vector2(1, sway * 0.3), 8.2, Color(0.55, 0.62, 0.48, 1.0))
				draw_circle(Vector2(6, -3 + sway * 0.3), 1.6, Color(0.95, 0.85, 0.20, 1.0))
				draw_circle(Vector2(6, 3 + sway * 0.3), 1.6, Color(0.95, 0.85, 0.20, 1.0))
			
		ZombieType.RUNNER:
			var body_c := Color(0.42, 0.14, 0.14, 1.0) if hurt_flash_timer <= 0.0 else Color(1.0, 0.4, 0.4, 1.0)
			_draw_arm_or_stump(Vector2(3, -10), Vector2(21, -4 + sway), Color(0.58, 0.48, 0.45, 1.0), 4.5, Color(0.85, 0.10, 0.10, 1.0), 3.5, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 10), Vector2(21, 4 - sway), Color(0.58, 0.48, 0.45, 1.0), 4.5, Color(0.85, 0.10, 0.10, 1.0), 3.5, has_right_arm)
			var pts := PackedVector2Array([Vector2(-11, -11), Vector2(8, -9), Vector2(8, 9), Vector2(-11, 11)])
			draw_colored_polygon(pts, body_c)
			if has_head:
				draw_circle(Vector2(3, 0), 7.5, Color(0.62, 0.54, 0.50, 1.0))
				draw_circle(Vector2(8, -2.8), 1.9, Color(1.0, 0.12, 0.12, 1.0))
				draw_circle(Vector2(8, 2.8), 1.9, Color(1.0, 0.12, 0.12, 1.0))
			
		ZombieType.BOOMER:
			var belly_c := Color(0.46, 0.58, 0.24, 1.0) if hurt_flash_timer <= 0.0 else Color(0.85, 0.95, 0.55, 1.0)
			draw_circle(Vector2(-1, 0), 15.5, belly_c)
			draw_arc(Vector2(-1, 0), 15.5, 0.0, TAU, 24, Color(0.25, 0.34, 0.12, 1.0), 2.0)
			draw_circle(Vector2(-6, -7), 4.2, Color(0.78, 0.88, 0.22, 0.92))
			draw_circle(Vector2(-5, 8), 3.6, Color(0.78, 0.88, 0.22, 0.92))
			draw_circle(Vector2(4, -9), 3.0, Color(0.85, 0.72, 0.18, 0.92))
			_draw_arm_or_stump(Vector2(4, -13), Vector2(15, -9), belly_c, 6.0, Color(0.38, 0.48, 0.18, 1.0), 3.5, has_left_arm)
			_draw_arm_or_stump(Vector2(4, 13), Vector2(15, 9), belly_c, 6.0, Color(0.38, 0.48, 0.18, 1.0), 3.5, has_right_arm)
			if has_head:
				draw_circle(Vector2(5, 0), 7.8, Color(0.52, 0.62, 0.32, 1.0))
				draw_circle(Vector2(10, 0), 3.5, Color(0.32, 0.85, 0.15, 0.95))
			
		ZombieType.TANK:
			var hulk_c := Color(0.34, 0.26, 0.28, 1.0) if hurt_flash_timer <= 0.0 else Color(0.95, 0.35, 0.35, 1.0)
			_draw_arm_or_stump(Vector2(2, -15), Vector2(19, -11 + sway * 0.4), hulk_c.darkened(0.15), 9.0, Color(0.48, 0.18, 0.18, 1.0), 6.2, has_left_arm)
			_draw_arm_or_stump(Vector2(2, 15), Vector2(19, 11 - sway * 0.4), hulk_c.darkened(0.15), 9.0, Color(0.48, 0.18, 0.18, 1.0), 6.2, has_right_arm)
			var tank_pts := PackedVector2Array([
				Vector2(-14, -17), Vector2(9, -16), Vector2(13, 0), Vector2(9, 16), Vector2(-14, 17)
			])
			draw_colored_polygon(tank_pts, hulk_c)
			draw_polyline(tank_pts + PackedVector2Array([tank_pts[0]]), Color(0.18, 0.10, 0.12, 1.0), 2.2)
			if has_head:
				draw_circle(Vector2(5, 0), 7.5, Color(0.46, 0.36, 0.38, 1.0))
				draw_circle(Vector2(10, -2.5), 1.8, Color(1.0, 0.15, 0.10, 1.0))
				draw_circle(Vector2(10, 2.5), 1.8, Color(1.0, 0.15, 0.10, 1.0))
			
		ZombieType.SPITTER:
			var spit_c := Color(0.30, 0.38, 0.32, 1.0) if hurt_flash_timer <= 0.0 else Color(0.65, 1.0, 0.45, 1.0)
			draw_circle(Vector2(-7, -6), 5.0, Color(0.38, 0.85, 0.16, 0.88))
			draw_circle(Vector2(-7, 6), 5.0, Color(0.38, 0.85, 0.16, 0.88))
			_draw_arm_or_stump(Vector2(2, -10), Vector2(15, -6), spit_c, 4.2, Color(0.42, 0.88, 0.18, 1.0), 3.0, has_left_arm)
			_draw_arm_or_stump(Vector2(2, 10), Vector2(15, 6), spit_c, 4.2, Color(0.42, 0.88, 0.18, 1.0), 3.0, has_right_arm)
			draw_rect(Rect2(Vector2(-9, -11), Vector2(16, 22)), spit_c, true)
			if has_head:
				draw_line(Vector2(4, 0), Vector2(13, 0), Color(0.52, 0.64, 0.48, 1.0), 7.0)
				draw_circle(Vector2(10, 0), 7.2, Color(0.52, 0.64, 0.48, 1.0))
				draw_circle(Vector2(15, 0), 4.5, Color(0.45, 0.98, 0.18, 0.95))
				draw_circle(Vector2(13, -3), 1.6, Color(0.75, 1.0, 0.25, 1.0))
				draw_circle(Vector2(13, 3), 1.6, Color(0.75, 1.0, 0.25, 1.0))
			
		ZombieType.WITCH:
			var dress_c := Color(0.78, 0.76, 0.74, 1.0) if hurt_flash_timer <= 0.0 else Color(1.0, 0.3, 0.3, 1.0)
			var reach := 23.0 if is_enraged else 14.0
			_draw_arm_or_stump(Vector2(3, -10), Vector2(reach, -6 + sway), Color(0.82, 0.80, 0.78, 1.0), 3.8, Color(0.85, 0.08, 0.08, 1.0), 3.2, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 10), Vector2(reach, 6 - sway), Color(0.82, 0.80, 0.78, 1.0), 3.8, Color(0.85, 0.08, 0.08, 1.0), 3.2, has_right_arm)
			draw_rect(Rect2(Vector2(-10, -11), Vector2(16, 22)), dress_c, true)
			draw_circle(Vector2(1, 0), 6.0, Color(0.65, 0.08, 0.08, 0.75))
			if has_head:
				draw_circle(Vector2(2, 0), 8.2, Color(0.14, 0.14, 0.16, 1.0))
				draw_line(Vector2(0, -7), Vector2(-12, -10), Color(0.20, 0.20, 0.22, 1.0), 3.0)
				draw_line(Vector2(0, 7), Vector2(-12, 10), Color(0.20, 0.20, 0.22, 1.0), 3.0)
				var eye_col := Color(1.0, 0.08, 0.08, 1.0) if is_enraged else Color(0.90, 0.45, 0.45, 0.75)
				draw_circle(Vector2(7, -2.5), 2.0 if is_enraged else 1.3, eye_col)
				draw_circle(Vector2(7, 2.5), 2.0 if is_enraged else 1.3, eye_col)
	
	# Draw visible bullet wounds & exposed white ribs on damaged zombie torso
	for w in torso_wounds:
		draw_circle(w, 3.2, Color(0.58, 0.04, 0.04, 0.95))
		draw_line(w + Vector2(-2, -1), w + Vector2(2, 1), Color(0.90, 0.86, 0.78, 0.90), 1.4)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Draw Overhead Health Bar when damaged or for Bosses (Tank / Witch / Boomer)
	if not is_dead and (current_health < max_health or zombie_type == ZombieType.TANK or zombie_type == ZombieType.WITCH):
		var bar_w := 32.0 * sc
		var bar_h := 4.5
		var bar_pos := Vector2(-bar_w * 0.5, -24.0 * sc)
		var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.08, 0.08, 0.10, 0.85), true)
		var fill_c := Color(0.85, 0.20, 0.20, 0.95) if zombie_type != ZombieType.BOOMER else Color(0.55, 0.85, 0.20, 0.95)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_c, true)
