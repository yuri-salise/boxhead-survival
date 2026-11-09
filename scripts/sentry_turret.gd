extends StaticBody2D

signal turret_activated()
signal player_proximity_changed(in_range: bool)

@export var max_active_duration: float = 25.0
@export var range_radius: float = 480.0
@export var fire_interval: float = 0.16
@export var bullet_damage: float = 18.0
@export var projectile_scene: PackedScene = preload("res://scenes/actors/projectile.tscn")

var is_active: bool = false
var active_time_left: float = 0.0
var fire_timer: float = 0.0
var aim_angle: float = 0.0
var current_target: Node2D = null

var is_player_nearby: bool = false
var anim_time: float = 0.0
var muzzle_flash_timer: float = 0.0
var target_scan_timer: float = 999.0
var redraw_accum: float = 0.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("interactables")
	add_to_group("turrets")
	
	if interaction_area:
		interaction_area.collision_mask = 255
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "TAP TO ACTIVATE TURRET"

func can_interact() -> bool:
	return not is_active

func interact() -> bool:
	return activate_turret()

func get_interaction_prompt() -> String:
	return "START TURRET"

func _input(event: InputEvent) -> void:
	if is_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if global_position.distance_to(mpos) <= 80.0 or (is_player_nearby and global_position.distance_to(mpos) <= 125.0):
			activate_turret()
	elif event is InputEventScreenTouch and event.pressed:
		var canvas_pos := get_global_transform_with_canvas().origin
		if canvas_pos.distance_to(event.position) <= 85.0 or (is_player_nearby and canvas_pos.distance_to(event.position) <= 140.0):
			activate_turret()

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			activate_turret()

@rpc("any_peer", "call_local", "reliable")
func rpc_sync_activate_turret() -> void:
	_execute_activate_turret()

@rpc("authority", "call_local", "reliable")
func rpc_sync_deactivate_turret() -> void:
	_execute_deactivate_turret()

func activate_turret() -> bool:
	if is_active:
		return false
	if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
		rpc_sync_activate_turret.rpc()
		return true
	return _execute_activate_turret()

func _execute_activate_turret() -> bool:
	if is_active:
		return false
	
	is_active = true
	active_time_left = max_active_duration
	fire_timer = 0.0
	
	if prompt_label:
		prompt_label.text = "TURRET ACTIVE: " + str(int(active_time_left)) + "s"
		prompt_label.visible = true
	
	# Clear touch prompt
	var tree := get_tree()
	if tree:
		for p in tree.get_nodes_in_group("players"):
			if "touch_controls" in p and p.touch_controls and p.touch_controls.has_method("set_interact_prompt"):
				p.touch_controls.set_interact_prompt(false, "", null)
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_wave_start", 1.2, 0.0)
	
	turret_activated.emit()
	queue_redraw()
	return true

func _execute_deactivate_turret() -> void:
	is_active = false
	active_time_left = 0.0
	if prompt_label:
		prompt_label.visible = is_player_nearby
		prompt_label.text = "TAP TO ACTIVATE TURRET"
	queue_redraw()

func _process(delta: float) -> void:
	anim_time += delta
	redraw_accum += delta
	var needs_redraw: bool = false
	
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer = maxf(0.0, muzzle_flash_timer - delta)
		needs_redraw = true
	
	if is_active:
		if redraw_accum >= 0.045:
			redraw_accum = 0.0
			needs_redraw = true
		active_time_left = maxf(0.0, active_time_left - delta)
		if prompt_label:
			var sec_left := int(ceil(active_time_left))
			prompt_label.text = "TURRET: " + str(sec_left) + "s"
			prompt_label.visible = true
		
		if active_time_left <= 0.0:
			if is_inside_tree() and multiplayer and multiplayer.has_multiplayer_peer():
				if multiplayer.is_server():
					rpc_sync_deactivate_turret.rpc()
				return
			_execute_deactivate_turret()
			return
		
		# Acquire closest living zombie (throttled to 10 Hz for mobile CPU performance)
		target_scan_timer += delta
		if target_scan_timer >= 0.10 or not is_instance_valid(current_target) or current_target.get("is_dead") == true:
			target_scan_timer = 0.0
			_acquire_target()
		if is_instance_valid(current_target):
			var target_ang := (current_target.global_position - global_position).angle()
			aim_angle = rotate_toward(aim_angle, target_ang, 8.5 * delta)
			
			fire_timer += delta
			if fire_timer >= fire_interval:
				fire_timer = 0.0
				_fire_shot()
		else:
			# Idle sweep scan
			aim_angle += 0.85 * delta
	elif is_player_nearby and redraw_accum >= 0.06:
		redraw_accum = 0.0
		needs_redraw = true
	
	if needs_redraw:
		queue_redraw()

func _acquire_target() -> void:
	current_target = null
	var min_dist := range_radius
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var zombie_container = tree.current_scene.get_node_or_null("ZombieContainer")
	if not zombie_container:
		return
	
	for z in zombie_container.get_children():
		if is_instance_valid(z) and z.has_method("take_damage") and z.get("is_dead") != true:
			var d := global_position.distance_to(z.global_position)
			if d < min_dist:
				min_dist = d
				current_target = z

func _fire_shot() -> void:
	muzzle_flash_timer = 0.09
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_rifle", 1.35, -2.0)
	
	var dir := Vector2.from_angle(aim_angle)
	var spawn_pos := global_position + dir * 28.0
	
	if projectile_scene and get_parent():
		var proj = projectile_scene.instantiate()
		get_parent().add_child(proj)
		proj.init(spawn_pos, dir, 820.0, bullet_damage, self, 0, Color(0.98, 0.85, 0.25), false)

func get_sync_state() -> Dictionary:
	return {
		"is_active": is_active,
		"active_time_left": active_time_left,
		"aim_angle": aim_angle
	}

func apply_sync_state(data: Dictionary) -> void:
	var was_active := is_active
	is_active = data.get("is_active", false)
	active_time_left = float(data.get("active_time_left", 0.0))
	aim_angle = float(data.get("aim_angle", aim_angle))
	if prompt_label:
		if is_active:
			prompt_label.text = "TURRET: " + str(int(ceil(active_time_left))) + "s"
			prompt_label.visible = true
		else:
			prompt_label.visible = is_player_nearby
			prompt_label.text = "TAP TO ACTIVATE TURRET"
	if was_active != is_active:
		queue_redraw()

func get_light_data() -> Dictionary:
	if muzzle_flash_timer > 0.0:
		var flash_ratio: float = muzzle_flash_timer / 0.09
		var flash_pos: Vector2 = global_position + Vector2.from_angle(aim_angle) * 32.0
		return {
			"world_pos": flash_pos,
			"radius": 320.0 * (0.75 + 0.25 * flash_ratio),
			"color": Color(1.0, 0.92, 0.45, 1.0)
		}
	return {}

func get_spotlight_data() -> Dictionary:
	if is_active:
		return {
			"world_pos": global_position,
			"radius": 310.0,
			"color": Color(0.92, 0.96, 1.0, 0.96),
			"angle": aim_angle
		}
	return {}

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_player_nearby = true
		player_proximity_changed.emit(true)
		if not is_active and prompt_label:
			prompt_label.visible = true
			prompt_label.text = "TAP TO ACTIVATE TURRET"
		if not is_active and "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(true, "START TURRET", self)
		queue_redraw()

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_player_nearby = false
		player_proximity_changed.emit(false)
		if not is_active and prompt_label:
			prompt_label.visible = false
		if "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(false, "", null)
		queue_redraw()

func _draw() -> void:
	# 0. Interaction radius ring when nearby
	if is_player_nearby and not is_active:
		var pulse := 0.6 + 0.4 * sin(anim_time * 6.0)
		draw_arc(Vector2.ZERO, 62.0, 0.0, TAU, 32, Color(0.40, 0.75, 1.0, 0.35 * pulse), 2.0)
	
	# 1. Base shadow
	draw_circle(Vector2(6, 8), 18.0, Color(0.0, 0.0, 0.0, 0.45))
	
	# 2. Tripod mount legs
	for leg_ang in [0.8, 2.4, 4.0]:
		var leg_tip := Vector2.from_angle(leg_ang) * 20.0
		draw_line(Vector2.ZERO, leg_tip, Color(0.18, 0.20, 0.22, 1.0), 5.0)
		draw_circle(leg_tip, 3.5, Color(0.12, 0.14, 0.16, 1.0))
	
	# Base plate
	draw_circle(Vector2.ZERO, 15.0, Color(0.24, 0.26, 0.28, 1.0))
	draw_circle(Vector2.ZERO, 10.0, Color(0.16, 0.18, 0.20, 1.0))
	
	# 3. Rotating Turret Housing
	var aim_dir := Vector2.from_angle(aim_angle)
	var perp := Vector2(-aim_dir.y, aim_dir.x)
	
	# Twin Gun Barrels
	var barrel_len := 24.0
	draw_line(perp * 4.0, perp * 4.0 + aim_dir * barrel_len, Color(0.14, 0.15, 0.16, 1.0), 3.5)
	draw_line(-perp * 4.0, -perp * 4.0 + aim_dir * barrel_len, Color(0.14, 0.15, 0.16, 1.0), 3.5)
	
	# Armored turret body
	draw_circle(Vector2.ZERO, 11.5, Color(0.32, 0.35, 0.38, 1.0))
	draw_circle(Vector2.ZERO, 7.5, Color(0.20, 0.22, 0.24, 1.0))
	
	# Targeting Laser Sight, Tactical Spotlight Cone & Status LED
	if is_active:
		# Steady 360-degree perimeter tactical floodlight glow on ground
		draw_circle(Vector2.ZERO, 95.0, Color(0.88, 0.94, 1.0, 0.12))
		draw_circle(Vector2.ZERO, 44.0, Color(0.95, 0.98, 1.0, 0.18))
		
		# Directional tactical spotlight beam along aim_dir
		var cone_outer := PackedVector2Array([
			aim_dir * 12.0,
			aim_dir * 310.0 + perp * 105.0,
			aim_dir * 340.0,
			aim_dir * 310.0 - perp * 105.0
		])
		draw_colored_polygon(cone_outer, Color(0.92, 0.96, 1.0, 0.11))
		var cone_inner := PackedVector2Array([
			aim_dir * 12.0,
			aim_dir * 225.0 + perp * 52.0,
			aim_dir * 255.0,
			aim_dir * 225.0 - perp * 52.0
		])
		draw_colored_polygon(cone_inner, Color(0.98, 0.98, 1.0, 0.15))
		
		# Green targeting laser beam
		var laser_end := aim_dir * range_radius
		draw_line(Vector2.ZERO, laser_end, Color(0.15, 0.95, 0.25, 0.36), 1.8)
		draw_circle(Vector2.ZERO, 3.8, Color(0.2, 0.95, 0.3, 1.0)) # Green active LED
		
		# Muzzle flash on shot — dynamic lighting on turret chassis & surrounding ground
		if muzzle_flash_timer > 0.0:
			var flash_ratio: float = muzzle_flash_timer / 0.09
			# Radial ambient ground & turret body illumination
			draw_circle(Vector2.ZERO, 58.0, Color(1.0, 0.85, 0.30, 0.34 * flash_ratio))
			draw_circle(aim_dir * 18.0, 42.0, Color(1.0, 0.90, 0.40, 0.45 * flash_ratio))
			
			# Twin muzzle flash flares
			var tip1 := perp * 4.0 + aim_dir * (barrel_len + 4.0)
			var tip2 := -perp * 4.0 + aim_dir * (barrel_len + 4.0)
			
			# Outer bloom circles
			draw_circle(tip1, 20.0, Color(1.0, 0.80, 0.20, 0.52 * flash_ratio))
			draw_circle(tip2, 20.0, Color(1.0, 0.80, 0.20, 0.52 * flash_ratio))
			
			# White-hot inner core
			draw_circle(tip1, 8.5, Color(1.0, 0.98, 0.88, 0.98 * flash_ratio))
			draw_circle(tip2, 8.5, Color(1.0, 0.98, 0.88, 0.98 * flash_ratio))
			
			# Burst spike rays
			for spike_ang in [-0.28, 0.0, 0.28]:
				var sdir := Vector2.from_angle(aim_angle + spike_ang)
				draw_line(tip1, tip1 + sdir * 18.0, Color(1.0, 0.95, 0.60, 0.85 * flash_ratio), 2.5)
				draw_line(tip2, tip2 + sdir * 18.0, Color(1.0, 0.95, 0.60, 0.85 * flash_ratio), 2.5)
	else:
		# Standby yellow LED
		var led_pulse := 0.5 + 0.5 * sin(anim_time * 5.0)
		draw_circle(Vector2.ZERO, 3.0, Color(0.95, 0.80, 0.20, led_pulse))
