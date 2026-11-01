extends StaticBody2D

signal generator_started(world_pos: Vector2)
signal generator_depleted(world_pos: Vector2)
signal generator_refueled(world_pos: Vector2)
signal player_proximity_changed(in_range: bool)

@export var light_radius: float = 380.0
@export var light_color: Color = Color(1.0, 0.94, 0.72, 1.0)
@export var fuel_duration: float = 35.0
@export var restart_delay: float = 3.0

var is_running: bool = false
var has_fuel: bool = true
var fuel_time_left: float = 35.0
var is_starting: bool = false
var startup_time_left: float = 0.0
var is_player_nearby: bool = false
var anim_time: float = 0.0
var exhaust_puffs: Array[Dictionary] = []

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	fuel_time_left = fuel_duration
	add_to_group("obstacles")
	add_to_group("generators")
	add_to_group("interactables")
	
	if interaction_area:
		interaction_area.collision_mask = 255
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "TAP TO START GENERATOR"

func _process(delta: float) -> void:
	anim_time += delta
	var needs_redraw: bool = false
	
	if is_starting:
		needs_redraw = true
		startup_time_left = maxf(0.0, startup_time_left - delta)
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "TURNING ON: " + ("%.1f" % startup_time_left) + "s"
		if fmod(anim_time, 0.14) < delta:
			exhaust_puffs.append({
				"pos": Vector2(-18, -18),
				"vel": Vector2(randf_range(-12, -24), randf_range(-26, -42)),
				"radius": randf_range(4.0, 7.0),
				"age": 0.0,
				"life": randf_range(0.5, 0.9)
			})
		if startup_time_left <= 0.0:
			is_starting = false
			has_fuel = true
			fuel_time_left = fuel_duration
			start_generator()
	elif is_running:
		needs_redraw = true
		fuel_time_left = maxf(0.0, fuel_time_left - delta)
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "GENERATOR: " + str(int(ceil(fuel_time_left))) + "s [FUEL]"
		
		if fuel_time_left <= 0.0:
			is_running = false
			has_fuel = false
			if prompt_label:
				prompt_label.visible = true
				prompt_label.text = "OUT OF FUEL — GET GAS FROM TRUCK"
			generator_depleted.emit(global_position)
			queue_redraw()
			return
		
		# Generate smoke puffs from exhaust pipe
		if fmod(anim_time, 0.18) < delta:
			exhaust_puffs.append({
				"pos": Vector2(-18, -18),
				"vel": Vector2(randf_range(-8, -18), randf_range(-22, -38)),
				"radius": randf_range(3.5, 6.0),
				"age": 0.0,
				"life": randf_range(0.6, 1.1)
			})
	elif is_player_nearby or not has_fuel:
		needs_redraw = true # Pulsing LED prompt
	
	# Update active smoke puffs
	for i in range(exhaust_puffs.size() - 1, -1, -1):
		var puff: Dictionary = exhaust_puffs[i]
		puff["age"] = float(puff["age"]) + delta
		if float(puff["age"]) >= float(puff["life"]):
			exhaust_puffs.remove_at(i)
		else:
			var p: Vector2 = puff["pos"]
			var v: Vector2 = puff["vel"]
			puff["pos"] = p + v * delta
			puff["radius"] = float(puff["radius"]) + delta * 7.0
	
	if needs_redraw:
		queue_redraw()

func can_interact(p_actor: Node2D = null) -> bool:
	if is_running or is_starting:
		return false
	if not has_fuel and is_instance_valid(p_actor):
		return p_actor.get("has_gasoline") == true
	return true

func interact(p_actor: Node2D = null) -> bool:
	if is_running or is_starting:
		return false
	if not has_fuel:
		if is_instance_valid(p_actor) and p_actor.get("has_gasoline") == true:
			p_actor.has_gasoline = false
			p_actor.queue_redraw()
			return refuel_and_restart()
		return _try_refuel_from_player()
	return start_generator()

func get_interaction_prompt() -> String:
	if not has_fuel:
		return "ADD GASOLINE & TURN ON (3S)"
	return "START GENERATOR"

func _try_refuel_from_player() -> bool:
	var tree := get_tree()
	if tree:
		for p in tree.get_nodes_in_group("players"):
			if is_instance_valid(p) and p.get("has_gasoline") == true:
				p.has_gasoline = false
				p.queue_redraw()
				return refuel_and_restart()
		if tree.current_scene and tree.current_scene.has_method("spawn_floating_text"):
			tree.current_scene.spawn_floating_text(global_position + Vector2(0, -48), "⛽ OUT OF FUEL! COLLECT GASOLINE FROM FUEL TRUCK! ⛽", Color(1.0, 0.45, 0.20))
	return false

func refuel_and_restart() -> bool:
	if is_running or is_starting:
		return false
	is_starting = true
	startup_time_left = maxf(0.1, restart_delay)
	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "TURNING ON: " + ("%.1f" % startup_time_left) + "s"
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_pickup", 0.9, 1.0)
	generator_refueled.emit(global_position)
	queue_redraw()
	return true

func _input(event: InputEvent) -> void:
	if is_running or is_starting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if global_position.distance_to(mpos) <= 85.0 or (is_player_nearby and global_position.distance_to(mpos) <= 130.0):
			interact()
	elif event is InputEventScreenTouch and event.pressed:
		var tpos: Vector2 = event.position
		var canvas_pos := get_global_transform_with_canvas().origin
		if canvas_pos.distance_to(tpos) <= 90.0 or (is_player_nearby and canvas_pos.distance_to(tpos) <= 150.0):
			interact()

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby or is_running or is_starting:
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			interact()

func start_generator() -> bool:
	if is_running or is_starting:
		return false
	if not has_fuel:
		return _try_refuel_from_player()
	
	is_running = true
	is_starting = false
	if fuel_time_left <= 0.0:
		fuel_time_left = fuel_duration
	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "GENERATOR: " + str(int(ceil(fuel_time_left))) + "s [FUEL]"
	
	# Clear touch button prompt
	var tree := get_tree()
	if tree:
		for p in tree.get_nodes_in_group("players"):
			if "touch_controls" in p and p.touch_controls and p.touch_controls.has_method("set_interact_prompt"):
				p.touch_controls.set_interact_prompt(false, "", null)
	
	# Audio feedback
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		if audio_mgr.has_method("play_sfx"):
			if audio_mgr.has_sfx("sfx_wave_start"):
				audio_mgr.play_sfx("sfx_wave_start", 0.75, 2.0)
			elif audio_mgr.has_sfx("sfx_explosion"):
				audio_mgr.play_sfx("sfx_explosion", 1.4, -4.0)
	
	generator_started.emit(global_position)
	queue_redraw()
	return true

func get_light_data() -> Dictionary:
	if is_starting:
		var prog := clampf(1.0 - (startup_time_left / maxf(0.1, restart_delay)), 0.15, 1.0)
		var flick := 0.65 + 0.35 * sin(anim_time * 32.0)
		return {
			"world_pos": global_position,
			"radius": light_radius * 0.55 * prog * flick,
			"color": Color(1.0, 0.85, 0.45, 0.85 * prog)
		}
	if not is_running:
		return {}
	return {
		"world_pos": global_position,
		"radius": light_radius,
		"color": light_color
	}

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_player_nearby = true
		player_proximity_changed.emit(true)
		# Auto-refuel if generator is out of fuel and player walks up carrying gasoline!
		if not is_running and not is_starting and not has_fuel and body.get("has_gasoline") == true:
			body.has_gasoline = false
			body.queue_redraw()
			refuel_and_restart()
			return
		if not is_running and not is_starting and prompt_label:
			prompt_label.visible = true
			prompt_label.text = get_interaction_prompt()
		if not is_running and not is_starting and "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(true, get_interaction_prompt(), self)
		queue_redraw()

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		is_player_nearby = false
		player_proximity_changed.emit(false)
		if not is_running and not is_starting and has_fuel and prompt_label:
			prompt_label.visible = false
		if "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(false, "", null)
		queue_redraw()

func _draw() -> void:
	# 0. Interaction radius ring when player is nearby and generator is off
	if (is_player_nearby or not has_fuel) and not is_running and not is_starting:
		var pulse := 0.6 + 0.4 * sin(anim_time * 6.0)
		var ring_col := Color(1.0, 0.85, 0.25, 0.35 * pulse) if has_fuel else Color(1.0, 0.30, 0.18, 0.45 * pulse)
		draw_arc(Vector2.ZERO, 65.0, 0.0, TAU, 32, ring_col, 2.0)
	
	# 3-Second Startup Progress Ring when cranking after refueling
	if is_starting:
		var prog := clampf(1.0 - (startup_time_left / maxf(0.1, restart_delay)), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 52.0, -PI * 0.5, -PI * 0.5 + TAU * prog, 32, Color(0.25, 0.95, 0.45, 0.92), 4.0)
	
	# 1. Industrial cast shadow
	var s_rect := Rect2(Vector2(-24, -14) + Vector2(10, 14), Vector2(48, 30))
	draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.42), true)
	
	# 2. Main generator chassis (heavy-duty military olive metal)
	var body_rect := Rect2(Vector2(-24, -15), Vector2(48, 30))
	draw_rect(body_rect, Color(0.22, 0.26, 0.20, 1.0), true)
	draw_rect(body_rect, Color(0.12, 0.15, 0.11, 1.0), false, 2.0)
	
	# Hazard warning stripes on side
	for stripe_x in range(-20, 16, 10):
		draw_line(Vector2(stripe_x, 8), Vector2(stripe_x + 6, 14), Color(0.85, 0.65, 0.12, 0.8), 2.5)
	
	# Control panel & gauges
	draw_rect(Rect2(Vector2(-18, -12), Vector2(16, 14)), Color(0.10, 0.11, 0.12, 1.0), true)
	draw_circle(Vector2(-14, -5), 3.0, Color(0.9, 0.9, 0.9, 0.9)) # gauge
	draw_circle(Vector2(-6, -5), 2.0, Color(0.2, 0.8, 0.3, 0.9) if is_running else (Color(1.0, 0.75, 0.15, 0.9) if is_starting else Color(0.8, 0.2, 0.2, 0.9)))
	
	# Fuel cap
	draw_circle(Vector2(14, -8), 4.5, Color(0.85, 0.20, 0.15, 1.0) if not has_fuel else Color(0.35, 0.38, 0.40, 1.0))
	
	# Exhaust pipe
	draw_line(Vector2(-16, -15), Vector2(-18, -22), Color(0.30, 0.30, 0.32, 1.0), 4.0)
	
	# Floodlight mast & bulb fixture
	draw_line(Vector2(14, -15), Vector2(16, -30), Color(0.40, 0.42, 0.45, 1.0), 3.5)
	draw_circle(Vector2(16, -30), 5.5, Color(0.60, 0.62, 0.65, 1.0))
	
	# Light bulb, ground floodlight pool & fuel gauge bar
	if is_running:
		var pulse := 0.95 + 0.05 * sin(anim_time * 24.0)
		draw_circle(Vector2(16, -30), 125.0, Color(1.0, 0.92, 0.55, 0.13 * pulse))
		draw_circle(Vector2(16, -30), 54.0, Color(1.0, 0.88, 0.42, 0.22 * pulse))
		draw_circle(Vector2(16, -30), 22.0, Color(1.0, 0.90, 0.50, 0.38 * pulse))
		draw_circle(Vector2(16, -30), 5.0, Color(1.0, 0.98, 0.85, 1.0))
		
		# Overhead Fuel Timer Bar
		var f_ratio := clampf(fuel_time_left / maxf(1.0, fuel_duration), 0.0, 1.0)
		var bar_rect := Rect2(Vector2(-24, -44), Vector2(48, 5))
		draw_rect(bar_rect, Color(0.08, 0.09, 0.10, 0.88), true)
		var fill_col := Color(0.30, 0.92, 0.42, 0.95) if f_ratio > 0.3 else Color(1.0, 0.35, 0.15, 0.95)
		draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * f_ratio, bar_rect.size.y)), fill_col, true)
	elif is_starting:
		var flick := 0.5 + 0.5 * sin(anim_time * 30.0)
		draw_circle(Vector2(16, -30), 36.0, Color(1.0, 0.85, 0.35, 0.25 * flick))
		draw_circle(Vector2(16, -30), 4.2, Color(1.0, 0.92, 0.65, flick))
	else:
		# Standby slow red pulse
		var red_alpha := 0.45 + 0.45 * sin(anim_time * 4.0)
		draw_circle(Vector2(16, -30), 3.2, Color(0.95, 0.15, 0.15, red_alpha))
	
	# Smoke exhaust particles when active
	for puff in exhaust_puffs:
		var p: Vector2 = puff["pos"]
		var r: float = float(puff["radius"])
		var age: float = float(puff["age"])
		var life: float = float(puff["life"])
		var fade := clampf(1.0 - (age / life), 0.0, 1.0)
		draw_circle(p, r, Color(0.45, 0.45, 0.45, 0.32 * fade))
