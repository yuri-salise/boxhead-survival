extends StaticBody2D

signal crate_opened(world_pos: Vector2)
signal player_proximity_changed(in_range: bool)

const MAX_INTERACTION_DISTANCE: float = 135.0

@export var is_opened: bool = false
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
	
	if interaction_area:
		interaction_area.collision_mask = 255
		interaction_area.body_entered.connect(_on_interaction_body_entered)
		interaction_area.body_exited.connect(_on_interaction_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "TAP TO OPEN CRATE"

func _process(delta: float) -> void:
	anim_time += delta
	if is_player_nearby and not is_opened:
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
	if is_opened:
		return false
	var actor := p_actor
	if is_instance_valid(actor):
		if global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
			return false
	else:
		actor = get_nearby_player()
		if get_tree() and not get_tree().get_nodes_in_group("players").is_empty():
			if not is_instance_valid(actor) or global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
				return false
	return true

func interact(p_actor: Node2D = null) -> bool:
	return open_crate(p_actor)

func get_interaction_prompt() -> String:
	return "OPEN CRATE"

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
	if is_opened or not _can_local_player_interact():
		return
	var nearby_p := get_nearby_player()
	if not is_instance_valid(nearby_p):
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mpos := get_global_mouse_position()
		if global_position.distance_to(mpos) <= 75.0:
			open_crate(nearby_p)
	elif event is InputEventScreenTouch and event.pressed:
		var canvas_pos := get_global_transform_with_canvas().origin
		if canvas_pos.distance_to(event.position) <= 85.0:
			open_crate(nearby_p)

func _unhandled_input(event: InputEvent) -> void:
	if is_opened or not _can_local_player_interact():
		return
	var nearby_p := get_nearby_player()
	if not is_instance_valid(nearby_p):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			open_crate(nearby_p)

func open_crate(p_actor: Node2D = null) -> bool:
	if is_opened:
		return false
	var actor := p_actor
	if is_instance_valid(actor):
		if global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
			return false
	else:
		actor = get_nearby_player()
		if get_tree() and not get_tree().get_nodes_in_group("players").is_empty():
			if not is_instance_valid(actor) or global_position.distance_to(actor.global_position) > MAX_INTERACTION_DISTANCE:
				return false
	
	is_opened = true
	if prompt_label:
		prompt_label.visible = false
	
	# Clear touch button prompt
	var tree := get_tree()
	if tree:
		for p in tree.get_nodes_in_group("players"):
			if "touch_controls" in p and p.touch_controls and p.touch_controls.has_method("set_interact_prompt"):
				p.touch_controls.set_interact_prompt(false, "", null)
	
	# Play sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_sfx"):
		audio_mgr.play_sfx("sfx_pickup", 0.9, 2.0)
	
	# Spawn cached weapons & supplies
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("spawn_pickup_at"):
		var loot := ["WEAPON_SHOTGUN", "WEAPON_ASSAULT_RIFLE", "AMMO", "ARMOR", "MEDKIT"]
		loot.shuffle()
		for i in range(mini(3, loot.size())):
			var ang := randf() * TAU
			var dist := randf_range(38.0, 68.0)
			main_scene.spawn_pickup_at(loot[i], global_position + Vector2.from_angle(ang) * dist)
	
	crate_opened.emit(global_position)
	queue_redraw()
	return true

func _on_interaction_body_entered(body: Node2D) -> void:
	if body.is_in_group("players"):
		if not nearby_players.has(body):
			nearby_players.append(body)
		is_player_nearby = true
		player_proximity_changed.emit(true)
		if not is_opened and prompt_label:
			prompt_label.visible = true
		if not is_opened and "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(true, "OPEN CRATE", self)
		queue_redraw()

func _on_interaction_body_exited(body: Node2D) -> void:
	if body.is_in_group("players"):
		nearby_players.erase(body)
		is_player_nearby = not nearby_players.is_empty()
		if not is_player_nearby:
			player_proximity_changed.emit(false)
			if prompt_label:
				prompt_label.visible = false
		if "touch_controls" in body and body.touch_controls and body.touch_controls.has_method("set_interact_prompt"):
			body.touch_controls.set_interact_prompt(false, "", null)
		queue_redraw()

func _draw() -> void:
	# 0. Interaction radius ring when player is nearby
	if is_player_nearby and not is_opened:
		var pulse := 0.6 + 0.4 * sin(anim_time * 6.0)
		draw_arc(Vector2.ZERO, 58.0, 0.0, TAU, 28, Color(0.35, 0.90, 0.50, 0.35 * pulse), 2.0)
	
	# 1. Shadow
	var s_rect := Rect2(Vector2(-20, -12) + Vector2(8, 10), Vector2(40, 24))
	draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.40), true)
	
	# 2. Steel crate container
	var c_rect := Rect2(Vector2(-20, -12), Vector2(40, 24))
	var crate_col := Color(0.18, 0.24, 0.16, 1.0) if not is_opened else Color(0.14, 0.18, 0.13, 0.90)
	draw_rect(c_rect, crate_col, true)
	draw_rect(c_rect, Color(0.08, 0.12, 0.07, 1.0), false, 2.0)
	
	# Metal reinforced corners
	for corner in [Vector2(-19, -11), Vector2(13, -11), Vector2(-19, 6), Vector2(13, 6)]:
		draw_rect(Rect2(corner, Vector2(6, 5)), Color(0.32, 0.36, 0.30, 1.0), true)
	
	# Hinges & Latches
	if not is_opened:
		# Closed crate with yellow padlock / clasp
		draw_line(Vector2(-18, 0), Vector2(18, 0), Color(0.10, 0.14, 0.09, 1.0), 2.5)
		draw_rect(Rect2(Vector2(-4, -3), Vector2(8, 6)), Color(0.85, 0.70, 0.18, 1.0), true)
	else:
		# Open lid popped up
		draw_line(Vector2(-20, -12), Vector2(-22, -24), Color(0.24, 0.28, 0.22, 1.0), 3.0)
		draw_line(Vector2(20, -12), Vector2(18, -24), Color(0.24, 0.28, 0.22, 1.0), 3.0)
		draw_rect(Rect2(Vector2(-22, -26), Vector2(40, 6)), Color(0.28, 0.34, 0.26, 1.0), true)
		# Empty interior shadow
		draw_rect(Rect2(Vector2(-16, -8), Vector2(32, 16)), Color(0.05, 0.06, 0.05, 0.90), true)
