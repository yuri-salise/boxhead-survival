extends StaticBody2D

const LightFX := preload("res://scripts/light_fx.gd")

signal gasoline_dispensed(player_node: Node2D)
signal player_proximity_changed(in_range: bool)

@export var light_radius: float = 175.0
@export var light_color: Color = Color(1.0, 0.72, 0.25, 0.88)

const MAX_INTERACTION_DISTANCE: float = 135.0

var is_player_nearby: bool = false
var nearby_players: Array[Node2D] = []
var anim_time: float = 0.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("interactables")
	add_to_group("fuel_trucks")
	
	if interaction_area:
		interaction_area.collision_mask = 255
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = true
		prompt_label.text = "FUEL TRUCK [GET GASOLINE]"

func _process(delta: float) -> void:
	anim_time += delta
	queue_redraw()

func get_nearby_player(max_dist: float = MAX_INTERACTION_DISTANCE) -> Node2D:
	var tree := get_tree()
	if not tree:
		return null
	var players := tree.get_nodes_in_group("players")
	var closest: Node2D = null
	var min_d: float = max_dist
	for p in players:
		if is_instance_valid(p) and not p.get("is_dead") and not p.get("is_downed"):
			var d := global_position.distance_to(p.global_position)
			if d <= min_d:
				min_d = d
				closest = p as Node2D
	return closest

func can_interact(p_actor: Node2D = null) -> bool:
	var actor := p_actor
	if is_instance_valid(actor):
		if global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
			return false
	else:
		actor = get_nearby_player()
		if get_tree() and not get_tree().get_nodes_in_group("players").is_empty():
			if not is_instance_valid(actor) or global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
				return false
	return is_instance_valid(actor) and actor.get("has_gasoline") != true

func interact(p_actor: Node2D = null) -> bool:
	return dispense_gasoline(p_actor)

func get_interaction_prompt() -> String:
	return "GRAB GASOLINE CAN"

func dispense_gasoline(target_player: Node2D = null) -> bool:
	var recipient: Node2D = target_player
	if is_instance_valid(recipient):
		if global_position.distance_to(recipient.global_position) > MAX_INTERACTION_DISTANCE:
			return false
	else:
		recipient = get_nearby_player()
		if get_tree() and not get_tree().get_nodes_in_group("players").is_empty():
			if not is_instance_valid(recipient) or global_position.distance_to(recipient.global_position) > MAX_INTERACTION_DISTANCE:
				return false
	if not is_instance_valid(recipient):
		return false
	if recipient.get("has_gasoline") == true:
		var tree := get_tree()
		if tree and tree.current_scene and tree.current_scene.has_method("spawn_floating_text"):
			tree.current_scene.spawn_floating_text(global_position + Vector2(0, -54), "ALREADY CARRYING GASOLINE — DELIVER TO GENERATOR!", Color(1.0, 0.85, 0.25))
		return false
	
	recipient.set("has_gasoline", true)
	if recipient.has_method("sync_gasoline_state"):
		recipient.sync_gasoline_state(true)
	recipient.queue_redraw()
	
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_pickup", 1.05, 1.0)
	
	var tree := get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("spawn_floating_text"):
		tree.current_scene.spawn_floating_text(global_position + Vector2(0, -56), "GASOLINE CAN ACQUIRED — REFUEL THE GENERATOR!", Color(1.0, 0.82, 0.22))
	
	if prompt_label:
		prompt_label.text = "DELIVER GAS TO GENERATOR"
	
	gasoline_dispensed.emit(recipient)
	queue_redraw()
	return true

func _can_local_player_interact() -> bool:
	var scene := get_tree().current_scene if get_tree() else null
	if scene and scene.has_method("get_local_player"):
		var lp: Node = scene.get_local_player()
		if is_instance_valid(lp):
			if lp.get("is_dead") == true or lp.get("is_downed") == true:
				return false
			if global_position.distance_to(lp.global_position) > MAX_INTERACTION_DISTANCE:
				return false
	return true

func _input(event: InputEvent) -> void:
	if not _can_local_player_interact():
		return
	var nearby_p := get_nearby_player()
	if not is_instance_valid(nearby_p):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if global_position.distance_to(mpos) <= 95.0:
			dispense_gasoline(nearby_p)
	elif event is InputEventScreenTouch and event.pressed:
		var canvas_pos := get_global_transform_with_canvas().origin
		if canvas_pos.distance_to(event.position) <= 100.0:
			dispense_gasoline(nearby_p)

func _unhandled_input(event: InputEvent) -> void:
	if not _can_local_player_interact():
		return
	var nearby_p := get_nearby_player()
	if not is_instance_valid(nearby_p):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			dispense_gasoline(nearby_p)

func get_light_data() -> Dictionary:
	return {
		"world_pos": global_position,
		"radius": light_radius,
		"color": light_color
	}

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		if not nearby_players.has(body):
			nearby_players.append(body)
		is_player_nearby = true
		player_proximity_changed.emit(true)
		if body.get("has_gasoline") != true:
			dispense_gasoline(body)
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "DELIVER GAS TO GENERATOR" if body.get("has_gasoline") == true else "TAP / [E] TO GRAB GASOLINE"
		if "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			if body.get("has_gasoline") != true:
				body.touch_controls.set_interact_prompt(true, "GRAB GASOLINE CAN", self)
		queue_redraw()

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		nearby_players.erase(body)
		is_player_nearby = not nearby_players.is_empty()
		if not is_player_nearby:
			player_proximity_changed.emit(false)
			if prompt_label:
				prompt_label.text = "FUEL TRUCK [GET GASOLINE]"
		if "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(false, "", null)
		queue_redraw()

func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(anim_time * 5.5)
	
	# 0. Interaction / Supply Zone Ring
	draw_arc(Vector2.ZERO, 68.0, 0.0, TAU, 36, Color(1.0, 0.65, 0.15, (0.42 if is_player_nearby else 0.22) * pulse), 2.2)
	
	# 1. Heavy Tanker Cast Shadow
	draw_rect(Rect2(Vector2(-48, -22) + Vector2(10, 14), Vector2(96, 44)), Color(0.0, 0.0, 0.0, 0.48), true)
	
	# 2. Six Heavy Duty Truck Tires
	for wx in [-34.0, -4.0, 28.0]:
		draw_rect(Rect2(Vector2(wx - 7.0, -25.0), Vector2(14.0, 6.0)), Color(0.08, 0.08, 0.09, 1.0), true)
		draw_rect(Rect2(Vector2(wx - 7.0, 19.0), Vector2(14.0, 6.0)), Color(0.08, 0.08, 0.09, 1.0), true)
	
	# 3. Truck Frame & Armored Cab (Right side cab, Left side fuel cistern)
	draw_rect(Rect2(Vector2(-46, -20), Vector2(92, 40)), Color(0.18, 0.20, 0.18, 1.0), true)
	
	# Cab (Front right)
	var cab_rect := Rect2(Vector2(18, -19), Vector2(28, 38))
	draw_rect(cab_rect, Color(0.28, 0.32, 0.24, 1.0), true)
	draw_rect(cab_rect, Color(0.12, 0.14, 0.11, 1.0), false, 2.0)
	# Windshield
	draw_rect(Rect2(Vector2(34, -15), Vector2(7, 30)), Color(0.42, 0.56, 0.65, 0.85), true)
	# Headlights
	LightFX.draw_glow(self, Vector2(48, -13), 16.0, Color(1.0, 0.93, 0.70, 0.55))
	LightFX.draw_glow(self, Vector2(48, 13), 16.0, Color(1.0, 0.93, 0.70, 0.55))
	draw_circle(Vector2(46, -13), 3.0, Color(1.0, 0.92, 0.65, 0.95))
	draw_circle(Vector2(46, 13), 3.0, Color(1.0, 0.92, 0.65, 0.95))
	
	# 4. Cylindrical Gasoline Tanker Cistern (Red & Hazard Yellow)
	var tank_rect := Rect2(Vector2(-44, -18), Vector2(60, 36))
	draw_rect(tank_rect, Color(0.68, 0.16, 0.14, 1.0), true)
	draw_rect(Rect2(Vector2(-44, -9), Vector2(60, 18)), Color(0.82, 0.22, 0.18, 1.0), true)
	draw_rect(tank_rect, Color(0.25, 0.08, 0.08, 1.0), false, 2.0)
	
	# Hazard stripes along tank center
	for sx in range(-38, 10, 12):
		draw_line(Vector2(sx, -6), Vector2(sx + 6, 6), Color(0.95, 0.78, 0.15, 0.90), 3.0)
	
	# Top filler hatches
	draw_circle(Vector2(-26, 0), 5.0, Color(0.28, 0.30, 0.32, 1.0))
	draw_circle(Vector2(-6, 0), 5.0, Color(0.28, 0.30, 0.32, 1.0))
	
	# Amber roof beacon light + warm ground glow
	LightFX.draw_glow(self, Vector2(26, 0), 95.0, Color(1.0, 0.68, 0.20, 0.42 * pulse))
	draw_circle(Vector2(26, 0), 4.2, Color(1.0, 0.75, 0.15, 0.98))
