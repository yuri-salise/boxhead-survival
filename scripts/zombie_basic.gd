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
	WITCH,
	SCREAMER,
	STALKER,
	LEAPER,
	BRUTE,
	PARASITE,
	BUTCHER,
	PHANTOM
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
		"skin": Color(0.80, 0.78, 0.76, 1.0),
		"eye_color": Color(0.95, 0.05, 0.05, 1.0)
	},
	ZombieType.SCREAMER: {
		"name": "SCREAMER",
		"hp": 80.0,
		"speed": 158.0,
		"damage": 16.0,
		"cooldown": 0.70,
		"scale": 1.02,
		"score": 40,
		"skin": Color(0.70, 0.74, 0.78, 1.0),
		"sfx": "sfx_screamer",
		"eye_color": Color(0.20, 0.95, 1.0, 1.0)
	},
	ZombieType.STALKER: {
		"name": "STALKER",
		"hp": 72.0,
		"speed": 225.0,
		"damage": 22.0,
		"cooldown": 0.55,
		"scale": 0.96,
		"score": 45,
		"skin": Color(0.20, 0.16, 0.26, 1.0),
		"sfx": "sfx_stalker",
		"eye_color": Color(0.88, 0.15, 1.0, 1.0)
	},
	ZombieType.LEAPER: {
		"name": "LEAPER",
		"hp": 64.0,
		"speed": 215.0,
		"damage": 20.0,
		"cooldown": 0.55,
		"scale": 0.95,
		"score": 38,
		"skin": Color(0.68, 0.18, 0.18, 1.0),
		"sfx": "sfx_leaper",
		"eye_color": Color(1.0, 0.58, 0.10, 1.0)
	},
	ZombieType.BRUTE: {
		"name": "BRUTE",
		"hp": 220.0,
		"speed": 112.0,
		"damage": 28.0,
		"cooldown": 0.95,
		"scale": 1.45,
		"score": 55,
		"skin": Color(0.28, 0.32, 0.36, 1.0),
		"sfx": "sfx_brute",
		"eye_color": Color(1.0, 0.45, 0.10, 1.0)
	},
	ZombieType.PARASITE: {
		"name": "PARASITE",
		"hp": 90.0,
		"speed": 136.0,
		"damage": 18.0,
		"cooldown": 0.75,
		"scale": 1.12,
		"score": 42,
		"skin": Color(0.54, 0.44, 0.26, 1.0),
		"sfx": "sfx_parasite",
		"eye_color": Color(0.95, 0.85, 0.15, 1.0)
	},
	ZombieType.BUTCHER: {
		"name": "BUTCHER",
		"hp": 165.0,
		"speed": 148.0,
		"damage": 30.0,
		"cooldown": 0.72,
		"scale": 1.28,
		"score": 52,
		"skin": Color(0.56, 0.34, 0.32, 1.0),
		"sfx": "sfx_butcher",
		"eye_color": Color(1.0, 0.08, 0.08, 1.0)
	},
	ZombieType.PHANTOM: {
		"name": "PHANTOM",
		"hp": 115.0,
		"speed": 175.0,
		"damage": 24.0,
		"cooldown": 0.65,
		"scale": 1.10,
		"score": 50,
		"skin": Color(0.26, 0.48, 0.46, 1.0),
		"sfx": "sfx_phantom",
		"eye_color": Color(0.20, 1.0, 0.65, 1.0)
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
var ability_cooldown: float = 1.5
var vocal_timer: float = 2.0
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
	ability_cooldown = randf_range(0.8, 1.8)
	vocal_timer = randf_range(1.2, 3.0)
	modulate.a = 0.35 if zombie_type == ZombieType.STALKER else 1.0
	
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
		
		# Scary Variant Special Abilities & Audio Cues
		ability_cooldown = maxf(0.0, ability_cooldown - delta)
		vocal_timer -= delta
		if vocal_timer <= 0.0 and dist < 420.0:
			vocal_timer = randf_range(4.2, 7.5)
			var cfg_sfx: String = str(ZOMBIE_CONFIGS.get(zombie_type, {}).get("sfx", ""))
			if cfg_sfx != "":
				var audio_mgr := get_node_or_null("/root/AudioManager")
				if audio_mgr:
					audio_mgr.play_sfx(cfg_sfx)
		
		# 6. SCREAMER: Sonic shriek at < 300px, enraging itself and nearby infected
		if zombie_type == ZombieType.SCREAMER and not is_enraged and dist < 300.0:
			is_enraged = true
			speed *= 1.32
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr:
				audio_mgr.play_sfx("sfx_screamer")
		
		# 7. STALKER: Semi-invisible in darkness; uncloaks at < 195px or when caught in player's flashlight cone (Player Edge!)
		if zombie_type == ZombieType.STALKER:
			var caught_in_beam := false
			var p_vis: Node2D = target_player.get_node_or_null("Visuals") if target_player else null
			if p_vis and dist < 340.0:
				var aim_dir := Vector2.RIGHT.rotated(p_vis.rotation)
				var to_zombie := (global_position - target_player.global_position).normalized()
				if aim_dir.dot(to_zombie) > 0.78:
					caught_in_beam = true
			if caught_in_beam:
				modulate.a = move_toward(modulate.a, 1.0, delta * 5.0)
				is_enraged = false
			elif dist < 195.0:
				if not is_enraged:
					is_enraged = true
					var audio_mgr := get_node_or_null("/root/AudioManager")
					if audio_mgr:
						audio_mgr.play_sfx("sfx_stalker")
				modulate.a = move_toward(modulate.a, 1.0, delta * 4.5)
			else:
				modulate.a = move_toward(modulate.a, 0.30, delta * 2.5)
		
		# 8. LEAPER: High-velocity feral pounce when in mid-range (130..255px)
		if zombie_type == ZombieType.LEAPER and ability_cooldown <= 0.0 and dist > 125.0 and dist < 255.0 and not is_crawling:
			ability_cooldown = 3.4
			is_enraged = true
			knockback_velocity = dir * 340.0
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr:
				audio_mgr.play_sfx("sfx_leaper")
		
		# 10. PARASITE: Short-range bio-spit & chittering swarm
		if zombie_type == ZombieType.PARASITE:
			spit_cooldown -= delta
			if dist < 230.0 and spit_cooldown <= 0.0:
				_fire_acid_spit(dir)
				spit_cooldown = 3.8
		
		# 11. BUTCHER: Heavy cleaver frenzy rush inside 210px
		if zombie_type == ZombieType.BUTCHER and not is_enraged and dist < 210.0:
			is_enraged = true
			speed *= 1.24
			var audio_mgr := get_node_or_null("/root/AudioManager")
			if audio_mgr:
				audio_mgr.play_sfx("sfx_butcher")
		
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
			if zombie_type == ZombieType.PHANTOM:
				terrain_speed_mult = 1.0 # Phantom floats over mud and craters
			move_spd *= terrain_speed_mult
			if zombie_type == ZombieType.STALKER and modulate.a > 0.85 and not is_enraged:
				move_spd *= 0.72 # Flashlight beam burns & slows the Stalker (Player Edge!)
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
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	var s_type := 6 if zombie_type == ZombieType.BOOMER else -1
	
	if is_network_puppet:
		hurt_flash_timer = 0.10
		if audio_mgr:
			audio_mgr.play_sfx("sfx_zombie_hit")
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
	if audio_mgr:
		audio_mgr.play_sfx("sfx_zombie_hit")
	
	if zombie_type == ZombieType.WITCH and not is_enraged:
		_trigger_witch_enrage()
	
	# 9. BRUTE: Heavy riot armor absorbs 30% of incoming damage while armor plate (>50% HP) is intact
	var final_dmg := amount
	if zombie_type == ZombieType.BRUTE and current_health > max_health * 0.5:
		final_dmg = amount * 0.70
	
	current_health = max(0.0, current_health - final_dmg)
	var new_ratio := current_health / maxf(1.0, max_health)
	if zombie_type == ZombieType.BRUTE and not is_enraged and new_ratio <= 0.50 and current_health > 0.0:
		is_enraged = true
		speed *= 1.30
		if audio_mgr:
			audio_mgr.play_sfx("sfx_brute")
	
	# 12. PHANTOM: Phase-blinks laterally when struck if cooldown is ready
	if zombie_type == ZombieType.PHANTOM and current_health > 0.0 and ability_cooldown <= 0.0:
		ability_cooldown = 2.6
		var side_sign := 1.0 if randf() < 0.5 else -1.0
		var perp := last_hit_dir. orthogonal() * side_sign if last_hit_dir != Vector2.ZERO else Vector2(0, side_sign)
		global_position += perp * 44.0
		if audio_mgr:
			audio_mgr.play_sfx("sfx_phantom")
	
	# Add visible flesh wound on torso
	if torso_wounds.size() < 6:
		torso_wounds.append(Vector2(randf_range(-7.0, 5.0), randf_range(-8.0, 8.0)))
	
	# Dismemberment trigger: crossing 75%, 45%, 20% health or taking heavy caliber hit (>= 18 dmg)
	if current_health > 0.0:
		var crossed_threshold := (prev_ratio > 0.75 and new_ratio <= 0.75) or (prev_ratio > 0.45 and new_ratio <= 0.45) or (prev_ratio > 0.22 and new_ratio <= 0.22)
		if crossed_threshold or (amount >= 18.0 and limbs_severed_count == 0):
			sever_next_limb(last_hit_dir)
	
	# Emit active blood splash on hit
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
		var cfg_sfx: String = str(ZOMBIE_CONFIGS.get(zombie_type, {}).get("sfx", ""))
		if zombie_type == ZombieType.BOOMER:
			audio_mgr.play_sfx("sfx_boomer")
		elif cfg_sfx != "":
			audio_mgr.play_sfx(cfg_sfx)
		else:
			audio_mgr.play_sfx("sfx_zombie_death")
	
	_grant_player_edge_bonus()
	
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

func _grant_player_edge_bonus() -> void:
	var p: Node2D = target_player if (is_instance_valid(target_player) and target_player.get("is_dead") != true) else _find_nearest_living_player()
	if not is_instance_valid(p):
		return
	var scene := get_tree().current_scene if get_tree() else null
	
	match zombie_type:
		ZombieType.SCREAMER:
			# Sonic Backlash Pulse: stuns/knocks back and damages nearby zombies within 150px
			if get_parent():
				for z in get_parent().get_children():
					if z != self and is_instance_valid(z) and z.get("is_dead") != true and z.has_method("take_damage"):
						var dist := global_position.distance_to(z.global_position)
						if dist <= 155.0:
							var push_dir: Vector2 = (z.global_position - global_position).normalized()
							if z.has_method("apply_hit_impulse"):
								z.apply_hit_impulse(push_dir * 420.0)
							z.take_damage(24.0)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "⚡ SONIC SHOCKWAVE EDGE!", Color(0.95, 0.45, 1.0))
		
		ZombieType.STALKER:
			# Shadow Reflex Edge: Instant Dash reset + +10 HP
			if "dash_cooldown_left" in p:
				p.dash_cooldown_left = 0.0
			if p.has_method("heal"):
				p.heal(10.0)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "⚡ SHADOW EDGE: DASH READY +10 HP", Color(0.45, 0.90, 1.0))
		
		ZombieType.LEAPER:
			# Feral Adrenaline Edge: 3.5s Adrenaline Rush speed & fire-rate boost
			if "adrenaline_time_left" in p:
				p.adrenaline_time_left = maxf(float(p.adrenaline_time_left), 3.5)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "⚡ FERAL ADRENALINE RUSH!", Color(1.0, 0.65, 0.20))
		
		ZombieType.BRUTE:
			# Scavenged Riot Plate Edge: +20 Kevlar Armor
			if p.has_method("add_armor"):
				p.add_armor(20.0)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "🛡️ RIOT PLATE SCAVENGED +20 ARMOR", Color(0.35, 0.80, 1.0))
		
		ZombieType.PARASITE:
			# Bio-Marrow Edge: +15 HP
			if p.has_method("heal"):
				p.heal(15.0)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "🧬 BIO-EXTRACT +15 HP", Color(0.55, 1.0, 0.35))
		
		ZombieType.BUTCHER:
			# Cleaver Bandolier Edge: Refill unlocked weapons ammo
			var wc = p.get_node_or_null("WeaponController")
			if wc and wc.has_method("refill_all_unlocked_ammo"):
				wc.refill_all_unlocked_ammo()
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "⚔️ BUTCHER STASH: AMMO REFILLED!", Color(1.0, 0.85, 0.25))
		
		ZombieType.PHANTOM:
			# Soul Flare Edge: +15 HP, +15 Armor, & searing light burst to nearby undead
			if p.has_method("heal"):
				p.heal(15.0)
			if p.has_method("add_armor"):
				p.add_armor(15.0)
			if get_parent():
				for z in get_parent().get_children():
					if z != self and is_instance_valid(z) and z.get("is_dead") != true and z.has_method("take_damage"):
						if global_position.distance_to(z.global_position) <= 160.0:
							z.take_damage(28.0)
			if scene and scene.has_method("spawn_floating_text"):
				scene.spawn_floating_text(global_position, "👻 SOUL FLARE: +15 HP / +15 ARMOR", Color(0.40, 1.0, 0.95))

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
		
		ZombieType.SCREAMER:
			# 6. SCREAMER: Pale straightjacket asylum horror with unhinged shrieking jaw & sonic rings
			if is_enraged:
				var sonic_r := 18.0 + fmod(anim_time * 36.0, 22.0)
				draw_arc(Vector2(6, 0), sonic_r, -1.1, 1.1, 16, Color(0.95, 0.30, 0.95, 0.55), 2.0)
			var jacket_c := Color(0.64, 0.60, 0.68, 1.0) if hurt_flash_timer <= 0.0 else Color(1.0, 0.45, 0.85, 1.0)
			_draw_arm_or_stump(Vector2(3, -10), Vector2(19, -8 + sway), Color(0.72, 0.64, 0.76, 1.0), 4.2, Color(0.88, 0.15, 0.45, 1.0), 3.2, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 10), Vector2(19, 8 - sway), Color(0.72, 0.64, 0.76, 1.0), 4.2, Color(0.88, 0.15, 0.45, 1.0), 3.2, has_right_arm)
			draw_rect(Rect2(Vector2(-10, -11), Vector2(17, 22)), jacket_c, true)
			draw_line(Vector2(-8, -9), Vector2(5, 9), Color(0.28, 0.22, 0.30, 0.95), 2.2)
			draw_line(Vector2(-8, 9), Vector2(5, -9), Color(0.28, 0.22, 0.30, 0.95), 2.2)
			if has_head:
				draw_circle(Vector2(3, 0), 8.0, Color(0.76, 0.68, 0.80, 1.0))
				draw_circle(Vector2(9, 0), 4.2 if is_enraged else 2.6, Color(0.18, 0.02, 0.08, 0.98)) # Gaping screaming mouth
				draw_circle(Vector2(7, -3.2), 1.9, Color(1.0, 0.22, 0.88, 1.0))
				draw_circle(Vector2(7, 3.2), 1.9, Color(1.0, 0.22, 0.88, 1.0))
		
		ZombieType.STALKER:
			# 7. STALKER: Obsidian shadow-draped nightcrawler with razor mantis talons & cyan eyes
			var shadow_c := Color(0.12, 0.14, 0.20, 1.0) if hurt_flash_timer <= 0.0 else Color(0.45, 0.85, 1.0, 1.0)
			_draw_arm_or_stump(Vector2(4, -10), Vector2(23, -5 + sway), Color(0.18, 0.22, 0.28, 1.0), 4.0, Color(0.25, 0.95, 1.0, 0.95), 3.8, has_left_arm)
			_draw_arm_or_stump(Vector2(4, 10), Vector2(23, 5 - sway), Color(0.18, 0.22, 0.28, 1.0), 4.0, Color(0.25, 0.95, 1.0, 0.95), 3.8, has_right_arm)
			var stalk_pts := PackedVector2Array([Vector2(-12, -10), Vector2(9, -7), Vector2(9, 7), Vector2(-12, 10)])
			draw_colored_polygon(stalk_pts, shadow_c)
			if has_head:
				draw_circle(Vector2(4, 0), 7.4, Color(0.16, 0.18, 0.24, 1.0))
				draw_circle(Vector2(8.5, -2.8), 2.1, Color(0.20, 0.98, 1.0, 1.0))
				draw_circle(Vector2(8.5, 2.8), 2.1, Color(0.20, 0.98, 1.0, 1.0))
		
		ZombieType.LEAPER:
			# 8. LEAPER: Hunched dorsal-spined feral predator with elongated leaping limbs
			var leap_c := Color(0.46, 0.22, 0.14, 1.0) if hurt_flash_timer <= 0.0 else Color(1.0, 0.55, 0.25, 1.0)
			_draw_arm_or_stump(Vector2(4, -11), Vector2(24, -7 + sway), Color(0.58, 0.34, 0.24, 1.0), 4.6, Color(0.95, 0.25, 0.10, 1.0), 3.8, has_left_arm)
			_draw_arm_or_stump(Vector2(4, 11), Vector2(24, 7 - sway), Color(0.58, 0.34, 0.24, 1.0), 4.6, Color(0.95, 0.25, 0.10, 1.0), 3.8, has_right_arm)
			draw_circle(Vector2(-2, 0), 11.5, leap_c)
			# Dorsal bone spines
			for sp_x in [-9.0, -4.0, 1.0]:
				draw_circle(Vector2(sp_x, 0), 2.4, Color(0.92, 0.86, 0.74, 0.95))
			if has_head:
				draw_circle(Vector2(6, 0), 7.2, Color(0.58, 0.34, 0.24, 1.0))
				draw_circle(Vector2(10, -2.6), 2.0, Color(1.0, 0.52, 0.08, 1.0))
				draw_circle(Vector2(10, 2.6), 2.0, Color(1.0, 0.52, 0.08, 1.0))
		
		ZombieType.BRUTE:
			# 9. BRUTE: Heavy SWAT riot-armored juggernaut with steel shoulder pauldrons & cracked visor
			var armor_c := Color(0.22, 0.26, 0.32, 1.0) if hurt_flash_timer <= 0.0 else Color(0.75, 0.85, 1.0, 1.0)
			_draw_arm_or_stump(Vector2(3, -14), Vector2(20, -10 + sway * 0.4), armor_c, 8.0, Color(0.55, 0.15, 0.15, 1.0), 5.2, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 14), Vector2(20, 10 - sway * 0.4), armor_c, 8.0, Color(0.55, 0.15, 0.15, 1.0), 5.2, has_right_arm)
			draw_rect(Rect2(Vector2(-13, -15), Vector2(22, 30)), armor_c, true)
			# Tactical riot chest plate & shoulder pauldrons
			draw_rect(Rect2(Vector2(-8, -12), Vector2(14, 24)), Color(0.14, 0.17, 0.22, 1.0), true)
			draw_circle(Vector2(1, -14), 5.5, Color(0.32, 0.38, 0.45, 1.0))
			draw_circle(Vector2(1, 14), 5.5, Color(0.32, 0.38, 0.45, 1.0))
			if has_head:
				draw_circle(Vector2(5, 0), 8.2, Color(0.18, 0.22, 0.28, 1.0))
				draw_line(Vector2(9, -4), Vector2(9, 4), Color(1.0, 0.18, 0.12, 0.98), 2.6)
		
		ZombieType.PARASITE:
			# 10. PARASITE: Twitching bio-host with glowing green egg sacs & writhing tendrils
			var host_c := Color(0.38, 0.46, 0.22, 1.0) if hurt_flash_timer <= 0.0 else Color(0.75, 1.0, 0.35, 1.0)
			_draw_arm_or_stump(Vector2(2, -9), Vector2(17, -5 + sway), host_c, 3.8, Color(0.65, 1.0, 0.20, 1.0), 2.8, has_left_arm)
			_draw_arm_or_stump(Vector2(2, 9), Vector2(17, 5 - sway), host_c, 3.8, Color(0.65, 1.0, 0.20, 1.0), 2.8, has_right_arm)
			draw_rect(Rect2(Vector2(-9, -10), Vector2(16, 20)), host_c, true)
			# Pulsing bioluminescent parasite cysts on back
			var pulse := 0.8 + 0.25 * sin(anim_time * 9.0)
			draw_circle(Vector2(-5, -6), 4.5 * pulse, Color(0.58, 1.0, 0.16, 0.92))
			draw_circle(Vector2(-4, 6), 4.0 * pulse, Color(0.58, 1.0, 0.16, 0.92))
			draw_circle(Vector2(-8, 0), 3.6 * pulse, Color(0.82, 1.0, 0.22, 0.92))
			if has_head:
				draw_circle(Vector2(4, 0), 7.0, Color(0.46, 0.56, 0.28, 1.0))
				draw_circle(Vector2(8, -2.5), 1.8, Color(0.65, 1.0, 0.15, 1.0))
				draw_circle(Vector2(8, 2.5), 1.8, Color(0.65, 1.0, 0.15, 1.0))
		
		ZombieType.BUTCHER:
			# 11. BUTCHER: Blood-soaked slaughterhouse apron hulk wielding a heavy steel meat cleaver
			var apron_c := Color(0.52, 0.12, 0.12, 1.0) if hurt_flash_timer <= 0.0 else Color(1.0, 0.35, 0.35, 1.0)
			_draw_arm_or_stump(Vector2(3, -12), Vector2(19, -8 + sway * 0.5), Color(0.62, 0.44, 0.40, 1.0), 6.0, Color(0.75, 0.10, 0.10, 1.0), 4.0, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 12), Vector2(20, 8 - sway * 0.5), Color(0.62, 0.44, 0.40, 1.0), 6.0, Color(0.75, 0.10, 0.10, 1.0), 4.0, has_right_arm)
			# Heavy bloody meat cleaver in right hand
			if has_right_arm:
				var cleaver_base := Vector2(18, 8 - sway * 0.5)
				draw_rect(Rect2(cleaver_base, Vector2(12, 5.5)), Color(0.82, 0.85, 0.88, 1.0), true)
				draw_line(cleaver_base + Vector2(12, 0), cleaver_base + Vector2(12, 5.5), Color(0.88, 0.06, 0.06, 0.98), 2.2)
			draw_rect(Rect2(Vector2(-11, -13), Vector2(19, 26)), Color(0.38, 0.28, 0.26, 1.0), true)
			draw_rect(Rect2(Vector2(-6, -11), Vector2(14, 22)), apron_c, true)
			if has_head:
				draw_circle(Vector2(4, 0), 8.0, Color(0.58, 0.42, 0.38, 1.0))
				draw_circle(Vector2(9, -2.6), 1.9, Color(1.0, 0.22, 0.10, 1.0))
				draw_circle(Vector2(9, 2.6), 1.9, Color(1.0, 0.22, 0.10, 1.0))
		
		ZombieType.PHANTOM:
			# 12. PHANTOM: Spectral wraith with tattered ethereal shroud & blazing cyan eye sockets
			var wraith_c := Color(0.18, 0.36, 0.42, 0.88) if hurt_flash_timer <= 0.0 else Color(0.55, 1.0, 1.0, 1.0)
			draw_circle(Vector2(0, 0), 16.0, Color(0.20, 0.85, 0.95, 0.16 + 0.08 * sin(anim_time * 7.0)))
			_draw_arm_or_stump(Vector2(3, -10), Vector2(21, -6 + sway), wraith_c, 4.2, Color(0.35, 1.0, 0.95, 0.95), 3.4, has_left_arm)
			_draw_arm_or_stump(Vector2(3, 10), Vector2(21, 6 - sway), wraith_c, 4.2, Color(0.35, 1.0, 0.95, 0.95), 3.4, has_right_arm)
			var shroud_pts := PackedVector2Array([
				Vector2(-15, -12), Vector2(8, -10), Vector2(10, 0), Vector2(8, 10), Vector2(-15, 12), Vector2(-10, 0)
			])
			draw_colored_polygon(shroud_pts, wraith_c)
			if has_head:
				draw_circle(Vector2(3, 0), 7.8, Color(0.10, 0.18, 0.22, 0.95))
				draw_circle(Vector2(8, -2.8), 2.1, Color(0.35, 1.0, 0.95, 1.0))
				draw_circle(Vector2(8, 2.8), 2.1, Color(0.35, 1.0, 0.95, 1.0))
	
	# Draw visible bullet wounds & exposed white ribs on damaged zombie torso
	for w in torso_wounds:
		draw_circle(w, 3.2, Color(0.58, 0.04, 0.04, 0.95))
		draw_line(w + Vector2(-2, -1), w + Vector2(2, 1), Color(0.90, 0.86, 0.78, 0.90), 1.4)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Draw Overhead Health Bar when damaged or for Elite/Boss variants
	if not is_dead and (current_health < max_health or zombie_type in [ZombieType.TANK, ZombieType.WITCH, ZombieType.BRUTE, ZombieType.BUTCHER, ZombieType.PHANTOM]):
		var bar_w := 32.0 * sc
		var bar_h := 4.5
		var bar_pos := Vector2(-bar_w * 0.5, -24.0 * sc)
		var ratio := clampf(current_health / maxf(1.0, max_health), 0.0, 1.0)
		draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.08, 0.08, 0.10, 0.85), true)
		var fill_c := Color(0.85, 0.20, 0.20, 0.95) if zombie_type != ZombieType.BOOMER else Color(0.55, 0.85, 0.20, 0.95)
		draw_rect(Rect2(bar_pos, Vector2(bar_w * ratio, bar_h)), fill_c, true)
