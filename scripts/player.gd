extends CharacterBody2D

signal health_changed(current_health: float, max_health: float)
signal armor_changed(current_armor: float, max_armor: float)
signal dash_changed(cooldown_left: float, cooldown_max: float)
signal grenades_changed(count: int)
signal pickup_collected(message: String, color: Color)
signal grenade_detonated(world_pos: Vector2, radius: float, damage: float)
signal player_damaged_at(world_pos: Vector2, hit_dir: Vector2)
signal player_bitten(hit_dir: Vector2, damage: float)
signal player_died()
signal player_downed(player_node: CharacterBody2D)
signal player_revived(player_node: CharacterBody2D)

@export var speed: float = 280.0
@export var max_health: float = 100.0
@export var max_armor: float = 100.0
@export var dash_speed: float = 760.0
@export var dash_duration: float = 0.18
@export var dash_cooldown: float = 1.40
@export var peer_id: int = 1
@export var player_index: int = 1
@export var is_coop_mode: bool = false

var current_health: float = 100.0
var current_armor: float = 0.0
var is_dead: bool = false

# Multiplayer Squad Revive & Bleedout
var is_downed: bool = false
var bleedout_time_left: float = 0.0
const MAX_BLEEDOUT_TIME: float = 35.0

# Dash state
var is_dashing: bool = false
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var ghost_trail_points: Array[Dictionary] = []

# Buffs & inventory
var adrenaline_time_left: float = 0.0
var grenade_count: int = 2
var max_grenades: int = 5

# Animation & visual feedback
var walk_cycle: float = 0.0
var muzzle_flash_timer: float = 0.0
var hurt_flash_timer: float = 0.0
var camera_shake_strength: float = 0.0
var player_camera: Camera2D = null

# External input overrides (e.g. mobile virtual sticks or multiplayer sync)
var input_override_enabled: bool = false
var override_move_vec: Vector2 = Vector2.ZERO
var override_aim_pos: Vector2 = Vector2.ZERO
var override_is_shooting: bool = false
var touch_controls: Control = null
var network_sync_enabled: bool = false
var terrain_speed_mult: float = 1.0
var terrain_check_timer: float = 999.0

@onready var visuals: Node2D = $Visuals
@onready var muzzle_marker: Marker2D = $Visuals/MuzzlePoint
@onready var weapon_controller: Node = $WeaponController

func is_local_player() -> bool:
	if not is_coop_mode:
		return true
	if multiplayer and multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id() == peer_id
	return peer_id == 1

func _ready() -> void:
	current_health = max_health
	is_dead = false
	
	if is_coop_mode:
		var tree := get_tree()
		if tree:
			var timer := tree.create_timer(0.6)
			if timer:
				timer.timeout.connect(func(): network_sync_enabled = true)
	else:
		network_sync_enabled = true
	
	# Attach smooth Camera2D for infinite world movement
	player_camera = get_node_or_null("PlayerCamera") as Camera2D
	if not player_camera:
		player_camera = Camera2D.new()
		player_camera.name = "PlayerCamera"
		player_camera.position_smoothing_enabled = true
		player_camera.position_smoothing_speed = 8.5
		add_child(player_camera)
	
	if is_local_player():
		player_camera.make_current()
	else:
		player_camera.enabled = false
	
	# Hide legacy blocky ColorRects inside Visuals so our detailed custom _draw() renders cleanly
	if visuals:
		for child in visuals.get_children():
			if child is ColorRect:
				child.visible = false
	
	if weapon_controller and weapon_controller.has_signal("shot_fired"):
		weapon_controller.shot_fired.connect(_on_weapon_shot_fired)

var muzzle_flash_scene: PackedScene = preload("res://scenes/effects/muzzle_flash.tscn")

func add_camera_shake(intensity: float) -> void:
	camera_shake_strength = minf(18.0, camera_shake_strength + intensity)

func _on_weapon_shot_fired(_proj: Node2D) -> void:
	muzzle_flash_timer = 0.06
	add_camera_shake(2.2)
	if muzzle_flash_scene and get_parent():
		var flash := muzzle_flash_scene.instantiate() as Node2D
		flash.global_position = get_muzzle_position()
		flash.rotation = visuals.rotation if visuals else 0.0
		get_parent().add_child(flash)
	queue_redraw()

func _physics_process(delta: float) -> void:
	# Update timers
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
	if hurt_flash_timer > 0.0:
		hurt_flash_timer = maxf(0.0, hurt_flash_timer - delta)
	if camera_shake_strength > 0.0:
		camera_shake_strength = maxf(0.0, camera_shake_strength - delta * 28.0)
		if is_instance_valid(player_camera):
			player_camera.offset = Vector2(
				randf_range(-camera_shake_strength, camera_shake_strength),
				randf_range(-camera_shake_strength, camera_shake_strength)
			)
	elif is_instance_valid(player_camera) and player_camera.offset != Vector2.ZERO:
		player_camera.offset = Vector2.ZERO
	
	if adrenaline_time_left > 0.0:
		adrenaline_time_left = maxf(0.0, adrenaline_time_left - delta)
		if weapon_controller:
			weapon_controller.fire_rate_multiplier = 0.62 if adrenaline_time_left > 0.0 else 1.0
	
	if dash_cooldown_left > 0.0:
		dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)
		dash_changed.emit(dash_cooldown_left, dash_cooldown)
	
	# Fade dash ghost trail
	for i in range(ghost_trail_points.size() - 1, -1, -1):
		ghost_trail_points[i]["alpha"] -= delta * 4.5
		if ghost_trail_points[i]["alpha"] <= 0.0:
			ghost_trail_points.remove_at(i)
	
	if is_dead:
		queue_redraw()
		return
	
	if is_downed:
		bleedout_time_left = maxf(0.0, bleedout_time_left - delta)
		if bleedout_time_left <= 0.0:
			die()
			return
		queue_redraw()
	
	var move_vec: Vector2
	var aim_pos: Vector2
	var shooting: bool
	
	if is_coop_mode and not is_local_player():
		move_vec = override_move_vec
		aim_pos = override_aim_pos
		shooting = override_is_shooting and not is_downed
	elif not is_coop_mode and input_override_enabled:
		move_vec = override_move_vec
		aim_pos = override_aim_pos
		shooting = override_is_shooting and not is_downed
	else:
		move_vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if move_vec == Vector2.ZERO:
			var dx := (1 if Input.is_key_pressed(KEY_D) else 0) - (1 if Input.is_key_pressed(KEY_A) else 0)
			var dy := (1 if Input.is_key_pressed(KEY_S) else 0) - (1 if Input.is_key_pressed(KEY_W) else 0)
			move_vec = Vector2(dx, dy)
		
		# Blend in mobile virtual movement joystick if active
		if is_instance_valid(touch_controls) and touch_controls.get("move_vector") != Vector2.ZERO:
			move_vec = touch_controls.get("move_vector")
		
		# Check if mobile right twin-stick is actively aiming/shooting
		if is_instance_valid(touch_controls) and touch_controls.get("is_firing") == true and not is_downed:
			var stick_aim: Vector2 = touch_controls.get("aim_vector")
			aim_pos = global_position + stick_aim * 150.0
			shooting = true
		else:
			aim_pos = get_global_mouse_position()
			var pointer_on_touch_ui := false
			if is_instance_valid(touch_controls) and touch_controls.has_method("is_using_touch_input"):
				pointer_on_touch_ui = touch_controls.is_using_touch_input() or touch_controls._is_point_on_action_buttons(get_viewport().get_mouse_position())
			shooting = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not pointer_on_touch_ui and not is_downed
		
		# Dash trigger on Space or Shift
		if (Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SHIFT)) and not is_downed:
			try_dash(move_vec, aim_pos)
		
		if is_coop_mode and is_local_player() and network_sync_enabled and is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.get_unique_id() != 1:
			sync_input_to_host.rpc_id(1, move_vec, aim_pos, shooting)
	
	# Handle active dash, downed crawl, or standard movement
	if is_downed:
		is_dashing = false
		velocity = move_vec.normalized() * 58.0 # Slow wounded crawl
	elif is_dashing:
		dash_time_left -= delta
		velocity = dash_direction * dash_speed
		ghost_trail_points.append({
			"global_pos": global_position,
			"rot": visuals.rotation if visuals else 0.0,
			"alpha": 0.55
		})
		if dash_time_left <= 0.0:
			is_dashing = false
	else:
		var spd_mult := 1.32 if adrenaline_time_left > 0.0 else 1.0
		terrain_check_timer += delta
		if terrain_check_timer >= 0.20:
			terrain_check_timer = 0.0
			var p_parent := get_parent()
			if p_parent:
				var arena = p_parent.get_node_or_null("ArenaEnvironment")
				if arena and arena.has_method("get_speed_multiplier_at"):
					terrain_speed_mult = arena.get_speed_multiplier_at(global_position)
		velocity = move_vec.normalized() * (speed * spd_mult * terrain_speed_mult)
	
	move_and_slide()
	
	if velocity.length() > 15.0:
		walk_cycle += delta * (14.0 if not is_dashing else 24.0)
	
	# Handle aiming and firing
	if aim_pos != Vector2.ZERO and aim_pos != global_position:
		var aim_dir := (aim_pos - global_position).normalized()
		if visuals:
			visuals.rotation = aim_dir.angle()
		
		if shooting and weapon_controller:
			var muzzle_global := get_muzzle_position()
			weapon_controller.try_fire(muzzle_global, aim_dir, self)
	
	if is_coop_mode and network_sync_enabled and is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_state_to_peers.rpc(global_position, visuals.rotation if visuals else 0.0, velocity, current_health, current_armor, weapon_controller.current_weapon_id if weapon_controller else "PISTOL")
	
	queue_redraw()

@rpc("any_peer", "call_remote", "unreliable")
func sync_input_to_host(p_move: Vector2, p_aim: Vector2, p_shooting: bool) -> void:
	if not is_inside_tree() or multiplayer == null:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var sender_id: int = multiplayer.get_remote_sender_id()
		if sender_id != 0 and sender_id != peer_id:
			return
	input_override_enabled = true
	override_move_vec = p_move
	override_aim_pos = p_aim
	override_is_shooting = p_shooting

@rpc("authority", "call_remote", "unreliable")
func sync_state_to_peers(p_pos: Vector2, p_rot: float, p_vel: Vector2, p_hp: float, p_ap: float, p_wep: String) -> void:
	if not is_inside_tree() or multiplayer == null:
		return
	if is_local_player():
		current_health = p_hp
		current_armor = p_ap
		if global_position.distance_squared_to(p_pos) > 10000.0:
			global_position = p_pos
		return
	global_position = p_pos
	if visuals:
		visuals.rotation = p_rot
	velocity = p_vel
	current_health = p_hp
	current_armor = p_ap
	if weapon_controller and weapon_controller.current_weapon_id != p_wep:
		if weapon_controller.has_method("unlock_or_add_weapon"):
			weapon_controller.unlock_or_add_weapon(p_wep)
		else:
			weapon_controller.equip_weapon(p_wep)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead or input_override_enabled or not is_local_player():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				if weapon_controller: weapon_controller.equip_weapon("PISTOL")
			KEY_2:
				if weapon_controller: weapon_controller.equip_weapon("SMG")
			KEY_3:
				if weapon_controller: weapon_controller.equip_weapon("SHOTGUN")
			KEY_4:
				if weapon_controller: weapon_controller.equip_weapon("ASSAULT_RIFLE")
			KEY_5:
				if weapon_controller: weapon_controller.equip_weapon("MAGNUM")
			KEY_Q:
				if weapon_controller: weapon_controller.cycle_weapon(-1)
			KEY_E:
				if not try_interact():
					if weapon_controller: weapon_controller.cycle_weapon(1)
			KEY_F:
				try_interact()
			KEY_G:
				try_throw_grenade(get_global_mouse_position())
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and weapon_controller:
			weapon_controller.cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and weapon_controller:
			weapon_controller.cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			try_dash(velocity, get_global_mouse_position())

func try_dash(move_vec: Vector2 = Vector2.ZERO, aim_pos: Vector2 = Vector2.ZERO) -> bool:
	if is_dead or is_dashing or dash_cooldown_left > 0.0:
		return false
	
	is_dashing = true
	dash_time_left = dash_duration
	dash_cooldown_left = dash_cooldown
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_dash")
	
	if move_vec.length() > 0.1:
		dash_direction = move_vec.normalized()
	elif aim_pos != Vector2.ZERO and aim_pos != global_position:
		dash_direction = (aim_pos - global_position).normalized()
	else:
		dash_direction = Vector2.from_angle(visuals.rotation if visuals else 0.0)
	
	dash_changed.emit(dash_cooldown_left, dash_cooldown)
	return true

func try_throw_grenade(target_pos: Vector2) -> bool:
	if is_dead or grenade_count <= 0:
		return false
	grenade_count -= 1
	grenades_changed.emit(grenade_count)
	
	var throw_dir := (target_pos - global_position)
	var dist := minf(throw_dir.length(), 280.0)
	var impact_pos := global_position + (throw_dir.normalized() * dist if dist > 1.0 else Vector2.RIGHT * 120.0)
	grenade_detonated.emit(impact_pos, 135.0, 165.0)
	return true

func try_interact() -> bool:
	if is_dead or is_downed:
		return false
	var tree := get_tree()
	if not tree:
		return false
	
	# Priority 1: Revive nearby downed squadmates!
	var players := tree.get_nodes_in_group("players")
	for p in players:
		if is_instance_valid(p) and p != self and p.get("is_downed") == true:
			if global_position.distance_to(p.global_position) <= 100.0:
				p.revive(40.0)
				return true
	
	var interactables := tree.get_nodes_in_group("interactables")
	var closest: Node = null
	var min_d := 130.0
	for item in interactables:
		if is_instance_valid(item) and item.has_method("can_interact") and item.can_interact():
			var d := global_position.distance_to(item.global_position)
			if d < min_d:
				min_d = d
				closest = item
	if closest and closest.has_method("interact"):
		return closest.interact()
	return false

func apply_pickup(pickup_type: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_pickup")
	
	match pickup_type:
		"MEDKIT":
			heal(35.0)
			pickup_collected.emit("+35 HP MEDKIT", Color(0.25, 0.92, 0.40))
		"ARMOR":
			add_armor(50.0)
			pickup_collected.emit("+50 KEVLAR ARMOR", Color(0.32, 0.72, 1.0))
		"AMMO":
			if weapon_controller:
				weapon_controller.refill_all_unlocked_ammo()
			grenade_count = mini(max_grenades, grenade_count + 1)
			grenades_changed.emit(grenade_count)
			pickup_collected.emit("+AMMO & +1 FRAG GRENADE", Color(0.95, 0.80, 0.28))
		"ADRENALINE":
			adrenaline_time_left = 8.0
			if weapon_controller:
				weapon_controller.fire_rate_multiplier = 0.62
			dash_cooldown_left = 0.0
			dash_changed.emit(0.0, dash_cooldown)
			pickup_collected.emit("ADRENALINE RUSH! (8S)", Color(1.0, 0.52, 0.18))
		"WEAPON_SMG":
			if weapon_controller:
				weapon_controller.unlock_or_add_weapon("SMG")
			pickup_collected.emit("ACQUIRED MP5 SMG!", Color(0.98, 0.78, 0.25))
		"WEAPON_SHOTGUN":
			if weapon_controller:
				weapon_controller.unlock_or_add_weapon("SHOTGUN")
			pickup_collected.emit("ACQUIRED 12G SHOTGUN!", Color(1.0, 0.55, 0.18))
		"WEAPON_ASSAULT_RIFLE":
			if weapon_controller:
				weapon_controller.unlock_or_add_weapon("ASSAULT_RIFLE")
			pickup_collected.emit("ACQUIRED M4A1 RIFLE!", Color(0.95, 0.88, 0.35))
		"WEAPON_MAGNUM":
			if weapon_controller:
				weapon_controller.unlock_or_add_weapon("MAGNUM")
			pickup_collected.emit("ACQUIRED .44 MAGNUM!", Color(1.0, 0.35, 0.30))

func get_muzzle_position() -> Vector2:
	if muzzle_marker:
		return muzzle_marker.global_position
	return global_position

func take_damage(amount: float) -> void:
	take_damage_from(amount, Vector2.ZERO)

func take_damage_from(amount: float, attacker_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dead or amount <= 0.0 or is_dashing:
		return
	
	hurt_flash_timer = 0.14
	add_camera_shake(9.5)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_player_hurt")
	var remaining_dmg := amount
	
	# Kevlar armor absorbs 70% of damage while active
	if current_armor > 0.0 and amount < max_health:
		var absorbed := minf(current_armor, amount * 0.70)
		current_armor = maxf(0.0, current_armor - absorbed)
		remaining_dmg = amount - absorbed
		armor_changed.emit(current_armor, max_armor)
	
	current_health = maxf(0.0, current_health - remaining_dmg)
	health_changed.emit(current_health, max_health)
	var hit_dir := (global_position - attacker_pos).normalized() if (attacker_pos != Vector2.ZERO and attacker_pos != global_position) else Vector2.RIGHT.rotated(randf() * TAU)
	player_damaged_at.emit(global_position, hit_dir)
	player_bitten.emit(hit_dir, amount)
	
	if current_health <= 0.0:
		if is_coop_mode and not is_downed:
			down()
		else:
			die()

func can_interact() -> bool:
	return is_downed and not is_dead

func interact() -> bool:
	if is_downed and not is_dead:
		revive(40.0)
		return true
	return false

func down() -> void:
	if is_dead or is_downed:
		return
	is_downed = true
	bleedout_time_left = MAX_BLEEDOUT_TIME
	current_health = 0.0
	velocity = Vector2.ZERO
	is_dashing = false
	health_changed.emit(current_health, max_health)
	player_downed.emit(self)
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_player_hurt", 0.85, 3.0)
	
	if is_local_player():
		var tree := get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("spawn_floating_text"):
			tree.current_scene.spawn_floating_text(global_position + Vector2(0, -60), "! DOWNED — CALLING FOR SQUAD REVIVE !", Color(1.0, 0.25, 0.20))
	
	if multiplayer and multiplayer.has_multiplayer_peer() and is_local_player():
		rpc_sync_downed.rpc(true)
	
	queue_redraw()

func revive(restore_hp: float = 40.0) -> void:
	if not is_downed:
		return
	is_downed = false
	bleedout_time_left = 0.0
	current_health = clampf(restore_hp, 20.0, max_health)
	health_changed.emit(current_health, max_health)
	player_revived.emit(self)
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_pickup", 1.2, 0.0)
	
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("spawn_floating_text"):
		tree.current_scene.spawn_floating_text(global_position + Vector2(0, -60), "★ SQUADMATE REVIVED! ★", Color(0.35, 1.0, 0.50))
	
	if multiplayer and multiplayer.has_multiplayer_peer() and is_local_player():
		rpc_sync_downed.rpc(false)
	
	queue_redraw()

@rpc("any_peer", "call_local", "reliable")
func rpc_sync_downed(downed: bool) -> void:
	if not is_inside_tree() or multiplayer == null:
		return
	if downed:
		if not is_downed:
			is_downed = true
			bleedout_time_left = MAX_BLEEDOUT_TIME
			current_health = 0.0
			health_changed.emit(current_health, max_health)
			player_downed.emit(self)
	else:
		if is_downed:
			is_downed = false
			bleedout_time_left = 0.0
			current_health = 40.0
			health_changed.emit(current_health, max_health)
			player_revived.emit(self)
	queue_redraw()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func add_armor(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_armor = minf(max_armor, current_armor + amount)
	armor_changed.emit(current_armor, max_armor)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	is_downed = false
	velocity = Vector2.ZERO
	player_died.emit()

func set_input_override(move_vec: Vector2, aim_pos: Vector2, is_shooting: bool) -> void:
	input_override_enabled = true
	override_move_vec = move_vec
	override_aim_pos = aim_pos
	override_is_shooting = is_shooting

func _draw() -> void:
	var rot := visuals.rotation if visuals else 0.0
	
	# Draw dash afterimage ghost trail in world-relative offset
	for g in ghost_trail_points:
		var rel_pos: Vector2 = g["global_pos"] - global_position
		draw_circle(rel_pos, 14.0, Color(0.35, 0.75, 0.95, g["alpha"] * 0.45))
	
	# Realistic Multi-Layered Directional Cast Shadow + Contact Shadow
	var aim_vec := Vector2.from_angle(rot)
	draw_circle(Vector2(9.0, 12.0), 14.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2(5.0, 7.0), 15.5, Color(0.0, 0.0, 0.0, 0.42))
	draw_circle(Vector2(0.0, 2.0), 13.5, Color(0.0, 0.0, 0.0, 0.56))
	draw_line(Vector2(5.0, 7.0), Vector2(5.0, 7.0) + aim_vec * 26.0, Color(0.0, 0.0, 0.0, 0.34), 6.0)
	
	# Adrenaline aura ring if active
	if adrenaline_time_left > 0.0:
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.15, 0.65), 2.2)
	
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	
	# 1. Tactical Flashlight Cone extending into the darkness
	if not is_dead:
		var cone_outer := PackedVector2Array([
			Vector2(14, 0),
			Vector2(290, -95),
			Vector2(320, 0),
			Vector2(290, 95)
		])
		draw_colored_polygon(cone_outer, Color(0.96, 0.92, 0.76, 0.065))
		var cone_inner := PackedVector2Array([
			Vector2(14, 0),
			Vector2(210, -48),
			Vector2(235, 0),
			Vector2(210, 48)
		])
		draw_colored_polygon(cone_inner, Color(0.98, 0.95, 0.82, 0.085))
	
	# 2. Animated Stepping Boots
	var leg_stride := sin(walk_cycle) * 6.0 if velocity.length() > 15.0 else 0.0
	draw_rect(Rect2(Vector2(-5 + leg_stride, -12), Vector2(10, 6)), Color(0.14, 0.13, 0.12, 1.0), true)
	draw_rect(Rect2(Vector2(-5 - leg_stride, 6), Vector2(10, 6)), Color(0.14, 0.13, 0.12, 1.0), true)
	
	# 3. Survivor Shoulders & Weathered Field Jacket (Distinct 4-Player Squad Outfits)
	var base_jacket := Color(0.28, 0.34, 0.24, 1.0) # P1: Olive Green / Slate
	if player_index == 2:
		base_jacket = Color(0.22, 0.32, 0.50, 1.0) # P2: Navy Blue
	elif player_index == 3:
		base_jacket = Color(0.48, 0.20, 0.20, 1.0) # P3: Crimson Ops
	elif player_index >= 4:
		base_jacket = Color(0.48, 0.40, 0.16, 1.0) # P4: Desert Tan / Gold
	
	var jacket_col := base_jacket if hurt_flash_timer <= 0.0 else Color(0.92, 0.25, 0.25, 1.0)
	if is_downed:
		jacket_col = jacket_col.darkened(0.35)
	
	var shoulder_pts := PackedVector2Array([
		Vector2(-10, -15),
		Vector2(7, -14),
		Vector2(10, -8),
		Vector2(10, 8),
		Vector2(7, 14),
		Vector2(-10, 15),
		Vector2(-13, 9),
		Vector2(-13, -9)
	])
	draw_colored_polygon(shoulder_pts, jacket_col)
	draw_polyline(shoulder_pts + PackedVector2Array([shoulder_pts[0]]), Color(0.12, 0.15, 0.10, 1.0), 1.8)
	
	# Backpack / Survivor Pack on back
	draw_rect(Rect2(Vector2(-15, -9), Vector2(6, 18)), Color(0.22, 0.19, 0.15, 1.0), true)
	
	# Kevlar Armor Plate overlay when player has armor
	if current_armor > 0.0:
		draw_rect(Rect2(Vector2(-7, -10), Vector2(13, 20)), Color(0.20, 0.36, 0.50, 0.92), true)
		draw_rect(Rect2(Vector2(-7, -10), Vector2(13, 20)), Color(0.45, 0.75, 0.95, 0.85), false, 1.4)
	
	# 4. Survivor Arms & Gloved Hands Holding Weapon
	draw_line(Vector2(2, -11), Vector2(14, -3), jacket_col.darkened(0.12), 5.5)
	draw_line(Vector2(2, 11), Vector2(16, 4), jacket_col.darkened(0.12), 5.5)
	draw_circle(Vector2(14, -2), 3.2, Color(0.78, 0.64, 0.52, 1.0))
	draw_circle(Vector2(17, 4), 3.2, Color(0.78, 0.64, 0.52, 1.0))
	
	# 5. Distinct Equipped Weapon Model (hidden while crawling downed)
	if not is_downed:
		var wid: String = weapon_controller.current_weapon_id if weapon_controller else "PISTOL"
		match wid:
			"PISTOL":
				draw_rect(Rect2(Vector2(12, 0), Vector2(13, 4.5)), Color(0.16, 0.18, 0.20, 1.0), true)
				draw_rect(Rect2(Vector2(14, 1), Vector2(9, 2)), Color(0.42, 0.45, 0.48, 1.0), true)
			"SMG":
				draw_rect(Rect2(Vector2(10, 0), Vector2(18, 5)), Color(0.14, 0.15, 0.18, 1.0), true)
				draw_rect(Rect2(Vector2(17, -4), Vector2(3, 5)), Color(0.25, 0.26, 0.28, 1.0), true)
			"SHOTGUN":
				draw_rect(Rect2(Vector2(7, 0.5), Vector2(24, 5)), Color(0.18, 0.18, 0.20, 1.0), true)
				draw_rect(Rect2(Vector2(14, 0), Vector2(10, 6)), Color(0.48, 0.30, 0.16, 1.0), true) # Wood pump
			"ASSAULT_RIFLE":
				draw_rect(Rect2(Vector2(6, 0), Vector2(26, 5.5)), Color(0.13, 0.15, 0.17, 1.0), true)
				draw_rect(Rect2(Vector2(12, 1), Vector2(11, 3.5)), Color(0.28, 0.32, 0.26, 1.0), true)
				draw_rect(Rect2(Vector2(26, 1.8), Vector2(6, 2)), Color(0.35, 0.38, 0.40, 1.0), true)
			"MAGNUM":
				draw_rect(Rect2(Vector2(11, 0), Vector2(19, 5)), Color(0.75, 0.78, 0.82, 1.0), true)
				draw_rect(Rect2(Vector2(12, 1), Vector2(6, 3)), Color(0.35, 0.20, 0.12, 1.0), true)
		
		# Muzzle Flash Burst
		if muzzle_flash_timer > 0.0:
			var flash_pts := PackedVector2Array([
				Vector2(28, 3),
				Vector2(42, -5),
				Vector2(37, 1),
				Vector2(48, 3),
				Vector2(37, 5),
				Vector2(42, 11)
			])
			draw_colored_polygon(flash_pts, Color(1.0, 0.88, 0.35, 0.92))
			draw_circle(Vector2(31, 3), 5.0, Color(1.0, 0.98, 0.85, 0.95))
	
	# 6. Survivor Head, Bandana & Cap
	var bandana_cols := [Color(0.75, 0.16, 0.16, 1.0), Color(0.20, 0.55, 0.88, 1.0), Color(0.85, 0.25, 0.25, 1.0), Color(0.92, 0.75, 0.22, 1.0)]
	var bandana_col: Color = bandana_cols[clampi(player_index - 1, 0, 3)]
	# Trailing bandana knot
	draw_line(Vector2(-8, -2), Vector2(-15, -6 - sin(walk_cycle) * 2.0), bandana_col.darkened(0.12), 3.0)
	draw_line(Vector2(-8, 2), Vector2(-15, 5 + cos(walk_cycle) * 2.0), bandana_col.darkened(0.12), 2.5)
	# Head skin & hair
	draw_circle(Vector2(0, 0), 8.5, Color(0.84, 0.70, 0.58, 1.0))
	draw_arc(Vector2(-1, 0), 8.2, PI * 0.55, PI * 1.45, 14, Color(0.18, 0.14, 0.11, 1.0), 3.5)
	# Survivor Bandana across forehead
	draw_arc(Vector2(0, 0), 8.4, -PI * 0.65, PI * 0.65, 14, bandana_col, 3.2)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# 7. Downed Bleedout & Revive Beacon
	if is_downed:
		var pulse := 0.6 + 0.4 * sin(walk_cycle * 8.0)
		var beacon_col := Color(1.0, 0.20, 0.20, 0.95 * pulse)
		
		# Ground revive ring
		draw_circle(Vector2.ZERO, 30.0, Color(0.85, 0.15, 0.15, 0.25 * pulse))
		var time_ratio := clampf(bleedout_time_left / MAX_BLEEDOUT_TIME, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 34.0, -PI * 0.5, -PI * 0.5 + TAU * time_ratio, 32, beacon_col, 3.2)
		
		# Pulsing medical cross badge above head
		var cross_pos := Vector2(0, -42)
		draw_circle(cross_pos, 15.0, Color(0.10, 0.11, 0.13, 0.90))
		draw_arc(cross_pos, 15.0, 0.0, TAU, 24, Color(1.0, 0.30, 0.30, 0.90), 2.0)
		draw_line(cross_pos + Vector2(-8, 0), cross_pos + Vector2(8, 0), Color(1.0, 0.95, 0.95), 4.2)
		draw_line(cross_pos + Vector2(0, -8), cross_pos + Vector2(0, 8), Color(1.0, 0.95, 0.95), 4.2)
		
		var b_sec := str(int(ceil(bleedout_time_left))) + "s"
		draw_string(ThemeDB.fallback_font, cross_pos + Vector2(-20, -18), b_sec, HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Color(1.0, 0.85, 0.25))
	elif is_coop_mode:
		# Overhead squad tag in co-op mode
		var squad_names: Array[String] = ["ALPHA (HOST)", "BRAVO", "CHARLIE", "DELTA"]
		var s_idx := clampi(player_index - 1, 0, 3)
		var tag_txt: String = "SURVIVOR " + str(player_index) + " [" + squad_names[s_idx] + "]"
		var squad_colors: Array[Color] = [Color(0.95, 0.55, 0.40), Color(0.40, 0.75, 0.95), Color(0.95, 0.40, 0.40), Color(0.95, 0.85, 0.35)]
		var tag_col: Color = squad_colors[s_idx]
		draw_string(ThemeDB.fallback_font, Vector2(-70, -26), tag_txt, HORIZONTAL_ALIGNMENT_CENTER, 140, 11, tag_col)
