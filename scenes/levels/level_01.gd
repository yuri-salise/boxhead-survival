extends Node2D

const BloodDecalScript = preload("res://scripts/blood_decal.gd")
const ZombieScript = preload("res://scripts/zombie_basic.gd")

@export var level_id: int = 1
@export var force_night_mode: bool = false
@export var day_night_cycle_duration: float = 64.0
@export var zombie_scene: PackedScene = preload("res://scenes/actors/zombie_basic.tscn")
@export var pickup_scene: PackedScene = preload("res://scenes/actors/pickup.tscn")
@export var max_alive_zombies: int = 18
@export var max_blood_decals: int = 240
@export var custom_waves: Array[Dictionary] = []

@onready var arena_env: Node2D = $ArenaEnvironment
@onready var blood_container: Node2D = $BloodDecalContainer
@onready var pickup_container: Node2D = $PickupContainer
@onready var player: CharacterBody2D = $Player
@onready var zombie_container: Node2D = $ZombieContainer
@onready var fx_container: Node2D = $FXContainer
@onready var wave_director: Node = get_node_or_null("WaveDirector")
@onready var level_controller: Node = get_node_or_null("LevelController")
@onready var spawn_timer: Timer = get_node_or_null("SpawnTimer")

# HUD references
@onready var horror_vignette: Control = $UI/HorrorVignette
@onready var touch_controls: Control = $UI/TouchControls
@onready var health_bar: ProgressBar = $UI/MarginContainer/TopBar/VitalsColumn/HealthBar
@onready var health_label: Label = $UI/MarginContainer/TopBar/VitalsColumn/HealthLabel
@onready var armor_bar: ProgressBar = $UI/MarginContainer/TopBar/VitalsColumn/ArmorBar
@onready var armor_label: Label = $UI/MarginContainer/TopBar/VitalsColumn/ArmorLabel
@onready var dash_label: Label = $UI/MarginContainer/TopBar/VitalsColumn/DashStatusLabel

@onready var kills_label: Label = $UI/MarginContainer/TopBar/CenterColumn/KillsLabel
@onready var weapon_label: Label = $UI/MarginContainer/TopBar/CenterColumn/WeaponLabel
@onready var pause_button: Button = $UI/MarginContainer/TopBar/PauseButton

@onready var pause_menu: Control = $UI/PauseMenu
@onready var result_screen: Control = get_node_or_null("UI/ResultScreen")
@onready var death_panel: PanelContainer = $UI/DeathPanel
@onready var death_kills_label: Label = $UI/DeathPanel/DeathMargin/DeathVBox/DeathKillsLabel
@onready var restart_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/RestartButton
@onready var menu_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/MenuButton

var kills_count: int = 0
var score_count: int = 0
var total_spawned: int = 0
var current_wave_num: int = 1
var total_waves_count: int = 3
var wave_remaining_count: int = 6
var day_night_time: float = 0.0
var current_night_factor: float = 0.0
var current_time_phase_name: String = "DAYLIGHT"
var player2: CharacterBody2D = null
var title_font: Font = preload("res://assets/fonts/BebasNeue-Regular.ttf")

# Mobile performance caching for flashlight occluders & lights
var cached_occluders: Array = []
var last_occluder_query_pos: Vector2 = Vector2(-9999.0, -9999.0)
var ambient_query_timer: float = 0.0
var cached_ambient_lights: Array = []
var witch_query_timer: float = 0.0
var cached_witch_eyes: Array = []

func _ready() -> void:
	get_tree().paused = false
	if death_panel:
		death_panel.visible = false
	
	if is_instance_valid(arena_env):
		if "sector_type" in arena_env:
			arena_env.sector_type = level_id
		var gs = get_node_or_null("/root/GameState")
		if gs and "graphics_quality" in gs and "graphics_quality" in arena_env:
			arena_env.graphics_quality = gs.graphics_quality
	
	# Pre-splatter a few weathered blood stains in the quarantine yard for atmosphere
	for i in range(8):
		var rand_pos := Vector2(randf_range(120, 1160), randf_range(120, 600))
		spawn_blood_decal(rand_pos, Vector2.RIGHT.rotated(randf() * TAU), -1, 0.9, false)
	
	# Spawn starter supply caches around the arena so player can immediately grab weapons/gear
	spawn_pickup_at("WEAPON_SHOTGUN", Vector2(460, 260))
	spawn_pickup_at("WEAPON_SMG", Vector2(820, 260))
	spawn_pickup_at("WEAPON_ASSAULT_RIFLE", Vector2(460, 470))
	spawn_pickup_at("ARMOR", Vector2(820, 470))
	spawn_pickup_at("MEDKIT", Vector2(640, 210))
	
	# Spawn interactive world elements at the outpost
	var gen_scene: PackedScene = load("res://scenes/actors/generator.tscn")
	if gen_scene:
		var generator := gen_scene.instantiate()
		generator.position = Vector2(740, 240)
		generator.generator_started.connect(_on_generator_started)
		add_child(generator)
	
	var sentry_scene: PackedScene = load("res://scenes/actors/sentry_turret.tscn")
	if sentry_scene:
		var sentry := sentry_scene.instantiate()
		sentry.position = Vector2(640, 440)
		add_child(sentry)
	
	var crate_scene: PackedScene = load("res://scenes/actors/supply_crate.tscn")
	if crate_scene:
		var crate := crate_scene.instantiate()
		crate.position = Vector2(530, 260)
		add_child(crate)
	
	if player:
		player.add_to_group("players")
		player.touch_controls = touch_controls
		player.health_changed.connect(_on_player_health_changed)
		player.armor_changed.connect(_on_player_armor_changed)
		player.dash_changed.connect(_on_player_dash_changed)
		player.grenades_changed.connect(_on_player_grenades_changed)
		player.pickup_collected.connect(_on_player_pickup_collected)
		player.grenade_detonated.connect(_on_grenade_detonated)
		player.player_damaged_at.connect(_on_player_damaged_at)
		if player.has_signal("player_bitten"):
			player.player_bitten.connect(_on_player_bitten)
		player.player_died.connect(_on_player_died)
		
		if player.weapon_controller:
			player.weapon_controller.weapon_changed.connect(_on_weapon_updated)
			player.weapon_controller.ammo_changed.connect(_on_ammo_updated)
		
		if touch_controls:
			touch_controls.dash_pressed.connect(func():
				if is_instance_valid(player):
					var aim_dir := Vector2.from_angle(player.visuals.rotation if player.visuals else 0.0)
					player.try_dash(player.velocity, player.global_position + aim_dir * 120.0)
			)
			touch_controls.grenade_pressed.connect(func():
				if is_instance_valid(player):
					var aim_dir := Vector2.from_angle(player.visuals.rotation if player.visuals else 0.0)
					player.try_throw_grenade(player.global_position + aim_dir * 190.0)
			)
			touch_controls.switch_weapon_pressed.connect(func():
				if is_instance_valid(player) and player.weapon_controller:
					player.weapon_controller.cycle_weapon(1)
			)
			if touch_controls.has_signal("interact_pressed"):
				touch_controls.interact_pressed.connect(func():
					if is_instance_valid(player):
						player.try_interact()
				)
		
		_on_player_health_changed(player.current_health, player.max_health)
		_on_player_armor_changed(player.current_armor, player.max_armor)
		_refresh_weapon_hud()
	
	# Initialize 2-player co-op if connected via NetworkManager
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var is_coop: bool = (net_mgr != null and (net_mgr.is_host or net_mgr.connected_peers.size() > 1))
	if is_coop and player:
		player.is_coop_mode = true
		player.peer_id = 1
		player.player_index = 1
		
		var client_id := 2
		for p in net_mgr.connected_peers:
			if p != 1:
				client_id = p
				break
		
		var player_scene: PackedScene = load("res://scenes/actors/player.tscn")
		player2 = player_scene.instantiate()
		player2.name = "Player2"
		player2.position = player.position + Vector2(70, 0)
		player2.is_coop_mode = true
		player2.peer_id = client_id
		player2.player_index = 2
		add_child(player2)
		player2.add_to_group("players")
		
		player2.player_died.connect(_on_player2_died)
		if player2.has_signal("player_bitten"):
			player2.player_bitten.connect(_on_player_bitten)
		player2.pickup_collected.connect(func(msg, col): _on_player_pickup_collected(msg, col))
		player2.grenade_detonated.connect(_on_grenade_detonated)
		
		if not net_mgr.peer_disconnected.is_connected(_on_coop_peer_disconnected):
			net_mgr.peer_disconnected.connect(_on_coop_peer_disconnected)
		if not net_mgr.server_disconnected.is_connected(_on_coop_server_disconnected):
			net_mgr.server_disconnected.connect(_on_coop_server_disconnected)
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	
	if pause_menu:
		pause_menu.save_requested.connect(_on_save_progress_requested)
		pause_menu.retry_requested.connect(_on_restart_pressed)
		pause_menu.main_menu_requested.connect(_on_return_pressed)
	
	if result_screen:
		result_screen.visible = false
		result_screen.next_level_requested.connect(_on_next_level_requested)
		result_screen.retry_requested.connect(_on_restart_pressed)
		result_screen.main_menu_requested.connect(_on_return_pressed)
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_return_pressed)
	
	if level_controller:
		level_controller.reset_state(level_id)
		level_controller.two_star_score = 220 * level_id
		level_controller.three_star_score = 420 * level_id
		level_controller.level_won.connect(_on_level_won)
		level_controller.level_lost.connect(_on_level_lost)
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_signal("achievement_unlocked") and not gs.achievement_unlocked.is_connected(_on_achievement_unlocked):
		gs.achievement_unlocked.connect(_on_achievement_unlocked)
	
	# Initialize dynamic per-sector starting time of day (gradually progresses through Day -> Dusk -> Night -> Dawn)
	var start_phase: float = _get_initial_phase_for_level(level_id)
	if force_night_mode:
		start_phase = 0.45
	day_night_time = start_phase * maxf(10.0, day_night_cycle_duration)
	advance_day_night_cycle(0.0, true)
	
	if wave_director:
		var is_survival: bool = (gs != null and gs.selected_mode == "survival")
		if is_survival:
			wave_director.is_endless_survival = true
		else:
			var waves_to_use: Array[Dictionary] = custom_waves if not custom_waves.is_empty() else _get_preset_waves_for_level(level_id)
			if not waves_to_use.is_empty():
				wave_director.setup_waves(waves_to_use)
		wave_director.wave_started.connect(_on_wave_started)
		wave_director.enemy_spawn_requested.connect(_on_wave_enemy_spawn_requested)
		wave_director.wave_enemies_updated.connect(_on_wave_enemies_updated)
		wave_director.wave_completed.connect(_on_wave_completed)
		wave_director.all_waves_completed.connect(_on_all_waves_completed)
		if wave_director.has_signal("herd_swarm_triggered"):
			wave_director.herd_swarm_triggered.connect(_on_herd_swarm_triggered)
		wave_director.start_waves()
	elif spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()
	
	_update_kills_display()

func _get_preset_waves_for_level(lvl_id: int) -> Array[Dictionary]:
	match lvl_id:
		2:
			return [
				{"total_enemies": 8, "spawn_interval": 1.45, "max_concurrent": 7, "intermission": 2.2, "guaranteed_boss": -1},
				{"total_enemies": 10, "spawn_interval": 1.25, "max_concurrent": 9, "intermission": 2.4, "guaranteed_boss": 5},
				{"total_enemies": 12, "spawn_interval": 1.10, "max_concurrent": 11, "intermission": 2.4, "guaranteed_boss": 5},
				{"total_enemies": 14, "spawn_interval": 0.95, "max_concurrent": 13, "intermission": 2.5, "guaranteed_boss": 3}
			]
		3:
			return [
				{"total_enemies": 10, "spawn_interval": 1.30, "max_concurrent": 8, "intermission": 2.2, "guaranteed_boss": -1},
				{"total_enemies": 12, "spawn_interval": 1.15, "max_concurrent": 11, "intermission": 2.4, "guaranteed_boss": 3},
				{"total_enemies": 15, "spawn_interval": 1.00, "max_concurrent": 13, "intermission": 2.4, "guaranteed_boss": 5},
				{"total_enemies": 18, "spawn_interval": 0.88, "max_concurrent": 15, "intermission": 2.5, "guaranteed_boss": 3}
			]
		4:
			return [
				{"total_enemies": 10, "spawn_interval": 1.20, "max_concurrent": 10, "intermission": 2.0, "guaranteed_boss": -1},
				{"total_enemies": 12, "spawn_interval": 1.05, "max_concurrent": 12, "intermission": 2.2, "guaranteed_boss": 5},
				{"total_enemies": 14, "spawn_interval": 0.95, "max_concurrent": 14, "intermission": 2.2, "guaranteed_boss": 3},
				{"total_enemies": 16, "spawn_interval": 0.85, "max_concurrent": 16, "intermission": 2.4, "guaranteed_boss": 5},
				{"total_enemies": 20, "spawn_interval": 0.78, "max_concurrent": 18, "intermission": 2.5, "guaranteed_boss": 3}
			]
		5:
			return [
				{"total_enemies": 12, "spawn_interval": 1.10, "max_concurrent": 12, "intermission": 2.0, "guaranteed_boss": 5},
				{"total_enemies": 15, "spawn_interval": 0.98, "max_concurrent": 14, "intermission": 2.2, "guaranteed_boss": 3},
				{"total_enemies": 18, "spawn_interval": 0.88, "max_concurrent": 16, "intermission": 2.2, "guaranteed_boss": 5},
				{"total_enemies": 20, "spawn_interval": 0.78, "max_concurrent": 18, "intermission": 2.4, "guaranteed_boss": 3},
				{"total_enemies": 24, "spawn_interval": 0.70, "max_concurrent": 20, "intermission": 2.5, "guaranteed_boss": 3}
			]
		_:
			return []

func _get_initial_phase_for_level(lvl_id: int) -> float:
	# Each sector begins at a progressive time of day and continuously cycles through Day -> Dusk -> Night -> Dawn
	match lvl_id:
		1:
			return 0.08 # Afternoon Daylight -> gradually transitions into Sunset & Nightfall
		2:
			return 0.16 # Late Afternoon -> Golden Hour -> Dusk
		3:
			return 0.24 # Sunset / Dusk -> Nightfall approaching fast
		4:
			return 0.34 # Deep Twilight -> Nightfall
		5:
			return 0.45 # Midnight Blackout -> Pre-Dawn
		_:
			return 0.08

func advance_day_night_cycle(delta: float, silent: bool = false) -> void:
	var duration := maxf(10.0, day_night_cycle_duration)
	day_night_time = fposmod(day_night_time + maxf(0.0, delta), duration)
	var phase := day_night_time / duration # 0.0 = Noon, 0.25 = Sunset/Dusk, 0.50 = Midnight, 0.75 = Dawn
	
	# Smooth cosine wave (0.0 in daylight -> 0.5 at dusk -> 1.0 at midnight -> 0.5 at dawn -> 0.0 in daylight)
	current_night_factor = clampf(0.5 - 0.5 * cos(phase * TAU), 0.0, 1.0)
	var is_dusk_warming := (phase < 0.5)
	
	if is_instance_valid(horror_vignette):
		if horror_vignette.has_method("set_night_factor"):
			horror_vignette.set_night_factor(current_night_factor, is_dusk_warming)
		elif horror_vignette.has_method("set_night_mode"):
			horror_vignette.set_night_mode(current_night_factor >= 0.45)
	
	if is_instance_valid(arena_env) and arena_env.has_method("set_night_factor"):
		arena_env.set_night_factor(current_night_factor)
	
	# Mark level_controller.night_mode_active once the player fights in significant darkness
	if level_controller and current_night_factor >= 0.60:
		level_controller.night_mode_active = true
	
	var next_phase_name := get_time_of_day_label()
	if next_phase_name != current_time_phase_name:
		var prev_phase := current_time_phase_name
		current_time_phase_name = next_phase_name
		_update_kills_display()
		if not silent and is_instance_valid(player) and prev_phase != "":
			if next_phase_name == "DUSK":
				spawn_floating_text(player.global_position + Vector2(0, -64), "SUNSET — DUSK APPROACHING...", Color(0.96, 0.62, 0.24))
			elif next_phase_name == "NIGHTFALL":
				spawn_floating_text(player.global_position + Vector2(0, -64), "NIGHTFALL — FLASHLIGHT CONE ACTIVE", Color(0.95, 0.85, 0.35))
			elif next_phase_name == "DAWN":
				spawn_floating_text(player.global_position + Vector2(0, -64), "FIRST LIGHT — DAWN BREAKING...", Color(0.55, 0.82, 0.98))
			elif next_phase_name == "DAYLIGHT":
				spawn_floating_text(player.global_position + Vector2(0, -64), "DAYLIGHT RESTORED", Color(0.95, 0.95, 0.78))

func get_time_of_day_label() -> String:
	var duration := maxf(10.0, day_night_cycle_duration)
	var phase := fposmod(day_night_time / duration, 1.0)
	if current_night_factor < 0.24:
		return "DAYLIGHT"
	elif current_night_factor >= 0.65:
		return "NIGHTFALL"
	elif phase < 0.5:
		return "DUSK"
	else:
		return "DAWN"

func set_night_mode_enabled(enabled: bool) -> void:
	var duration := maxf(10.0, day_night_cycle_duration)
	day_night_time = (0.5 * duration) if enabled else 0.0
	advance_day_night_cycle(0.0, true)
	if level_controller:
		level_controller.night_mode_active = enabled

func _on_achievement_unlocked(_ach_id: String, title: String, _desc: String) -> void:
	if is_instance_valid(player):
		spawn_floating_text(player.global_position + Vector2(0, -78), "★ ACHIEVEMENT: " + title + " ★", Color(1.0, 0.85, 0.22))

func _process(delta: float) -> void:
	advance_day_night_cycle(delta)
	if is_instance_valid(player):
		if is_instance_valid(arena_env):
			if arena_env.has_method("set_focus_position"):
				arena_env.set_focus_position(player.global_position)
		
		if is_instance_valid(horror_vignette) and horror_vignette.has_method("update_flashlight_transform"):
			var screen_pos: Vector2 = player.get_global_transform_with_canvas().origin
			var aim_rot: float = float(player.visuals.rotation) if player.visuals else 0.0
			var occluders: Array = []
			if current_night_factor > 0.02 and is_instance_valid(arena_env) and arena_env.has_method("get_nearby_obstacles"):
				if player.global_position.distance_squared_to(last_occluder_query_pos) >= 256.0 or cached_occluders.is_empty():
					last_occluder_query_pos = player.global_position
					cached_occluders = arena_env.get_nearby_obstacles(player.global_position, 550.0)
				occluders = cached_occluders
			horror_vignette.update_flashlight_transform(screen_pos, aim_rot, occluders, player.global_position)
			
			ambient_query_timer += delta
			if ambient_query_timer >= 0.20 or cached_ambient_lights.is_empty():
				ambient_query_timer = 0.0
				var ambients: Array = []
				if is_instance_valid(arena_env) and arena_env.has_method("get_ambient_lights"):
					ambients.append_array(arena_env.get_ambient_lights(player.global_position, 850.0))
				var gens := get_tree().get_nodes_in_group("generators")
				for g in gens:
					if is_instance_valid(g) and g.has_method("get_light_data"):
						var ldata: Dictionary = g.get_light_data()
						if not ldata.is_empty():
							ambients.append(ldata)
				cached_ambient_lights = ambients
				if horror_vignette.has_method("update_ambient_lights"):
					horror_vignette.update_ambient_lights(cached_ambient_lights, player.global_position)
			
			witch_query_timer += delta
			if witch_query_timer >= 0.12 or cached_witch_eyes.is_empty():
				witch_query_timer = 0.0
				var witches: Array = []
				if is_instance_valid(zombie_container):
					for z in zombie_container.get_children():
						if is_instance_valid(z) and not z.get("is_dead") and z.get("zombie_type") == 5: # ZombieType.WITCH == 5
							witches.append({
								"pos": z.global_position,
								"rot": z.rotation,
								"is_enraged": bool(z.get("is_enraged"))
							})
				cached_witch_eyes = witches
				if horror_vignette.has_method("update_witch_eyes"):
					horror_vignette.update_witch_eyes(cached_witch_eyes, player.global_position)
			
			# Keep zombies pursuing the player across the infinite world by relocating stragglers > 1450px behind
			if is_instance_valid(zombie_container):
				for z in zombie_container.get_children():
					if is_instance_valid(z) and not z.get("is_dead"):
						if z.global_position.distance_to(player.global_position) > 1450.0:
							var ahead_ang := randf() * TAU
							z.global_position = player.global_position + Vector2.from_angle(ahead_ang) * randf_range(680.0, 790.0)

func spawn_blood_decal(world_pos: Vector2, hit_dir: Vector2, splatter_type: int = -1, scale_mult: float = 1.0, active_splash: bool = true) -> Node2D:
	if not blood_container:
		return null
	
	var gs := get_node_or_null("/root/GameState")
	var is_survival: bool = (gs != null and gs.selected_mode == "survival")
	var decal_limit := 48 if is_survival else 75
	
	if blood_container.get_child_count() >= decal_limit:
		var oldest := blood_container.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	
	var decal := Node2D.new()
	decal.set_script(BloodDecalScript)
	blood_container.add_child(decal)
	decal.setup(world_pos, hit_dir, splatter_type, scale_mult, active_splash)
	if is_survival and decal.has_method("set_lifetime"):
		decal.set_lifetime(7.5)
	return decal

func spawn_severed_limb(world_pos: Vector2, hit_dir: Vector2, limb_kind: int, skin_color: Color, scale_mult: float = 1.0) -> Node2D:
	if not blood_container:
		return null
	
	var gs := get_node_or_null("/root/GameState")
	var is_survival: bool = (gs != null and gs.selected_mode == "survival")
	var decal_limit := 48 if is_survival else 75
	
	if blood_container.get_child_count() >= decal_limit:
		var oldest := blood_container.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	
	var limb_decal := Node2D.new()
	limb_decal.set_script(BloodDecalScript)
	blood_container.add_child(limb_decal)
	limb_decal.setup_severed_limb(world_pos, hit_dir, limb_kind, skin_color, scale_mult)
	if is_survival and limb_decal.has_method("set_lifetime"):
		limb_decal.set_lifetime(9.0)
	
	if gs and gs.has_method("record_limb_severed"):
		gs.record_limb_severed()
	return limb_decal

func spawn_pickup_at(p_type: String, world_pos: Vector2) -> Node2D:
	if not pickup_scene or not pickup_container:
		return null
	var item: Node2D = pickup_scene.instantiate()
	pickup_container.add_child(item)
	item.setup(p_type, world_pos)
	return item

func spawn_floating_text(world_pos: Vector2, message: String, color: Color = Color.WHITE) -> void:
	if not fx_container:
		return
	var lbl := Label.new()
	lbl.text = message
	lbl.global_position = world_pos + Vector2(-70, -28)
	lbl.custom_minimum_size = Vector2(140, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		lbl.add_theme_font_override("font", title_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	fx_container.add_child(lbl)
	
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 36.0, 0.85)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.85)
	tween.chain().tween_callback(lbl.queue_free)

func _on_player_health_changed(cur: float, max_h: float) -> void:
	if health_bar:
		health_bar.max_value = max_h
		health_bar.value = cur
	if health_label:
		health_label.text = "HP: " + str(int(ceil(cur))) + " / " + str(int(max_h))
	if horror_vignette and horror_vignette.has_method("set_health_ratio"):
		horror_vignette.set_health_ratio(cur / maxf(1.0, max_h))

func _on_player_armor_changed(cur: float, max_a: float) -> void:
	if armor_bar:
		armor_bar.max_value = max_a
		armor_bar.value = cur
	if armor_label:
		armor_label.text = "ARMOR: " + str(int(ceil(cur))) + " / " + str(int(max_a))

func _on_player_dash_changed(cd_left: float, cd_max: float) -> void:
	if touch_controls and touch_controls.has_method("set_dash_cooldown"):
		touch_controls.set_dash_cooldown(cd_left, cd_max)
	if dash_label:
		if cd_left <= 0.02:
			dash_label.text = "DASH: READY"
			dash_label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.50))
		else:
			dash_label.text = "DASH: " + String.num(cd_left, 1) + "S"
			dash_label.add_theme_color_override("font_color", Color(0.85, 0.55, 0.25))

func _on_player_grenades_changed(_count: int) -> void:
	_refresh_weapon_hud()

func _on_weapon_updated(_wid: String, _wname: String, _ammo: int, _max_ammo: int) -> void:
	_refresh_weapon_hud()

func _on_ammo_updated(_wid: String, _ammo: int, _max_ammo: int) -> void:
	_refresh_weapon_hud()

func _refresh_weapon_hud() -> void:
	if not player or not player.weapon_controller:
		return
	var w_text: String = player.weapon_controller.get_current_weapon_display()
	var g_count: int = int(player.grenade_count)
	if weapon_label:
		weapon_label.text = w_text + "  ·  FRAGS: " + str(g_count)
	if touch_controls:
		if touch_controls.has_method("set_weapon_display"):
			touch_controls.set_weapon_display(w_text)
		if touch_controls.has_method("set_grenade_count"):
			touch_controls.set_grenade_count(g_count)

func _on_player_pickup_collected(msg: String, col: Color) -> void:
	if is_instance_valid(player):
		spawn_floating_text(player.global_position, msg, col)
		if player.weapon_controller and player.weapon_controller.unlocked_weapons.size() >= 5:
			var gs := get_node_or_null("/root/GameState")
			if gs and gs.has_method("unlock_achievement"):
				gs.unlock_achievement("ARSENAL_MASTER")
	_refresh_weapon_hud()

func _on_player_damaged_at(world_pos: Vector2, hit_dir: Vector2) -> void:
	spawn_blood_decal(world_pos, hit_dir, 0, 0.95, true)

func _on_player_bitten(hit_dir: Vector2, damage: float) -> void:
	if level_controller and level_controller.has_method("record_player_bitten"):
		level_controller.record_player_bitten()
	if horror_vignette and horror_vignette.has_method("trigger_bite_pov_splatter"):
		horror_vignette.trigger_bite_pov_splatter(hit_dir, damage)

func _on_grenade_detonated(world_pos: Vector2, radius: float, damage: float) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_explosion")
	spawn_blood_decal(world_pos, Vector2.RIGHT, 7, 1.35, true) # Scorch crater + debris
	spawn_floating_text(world_pos, "FRAG BLAST!", Color(1.0, 0.62, 0.20))
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(12.0)
	_apply_aoe_explosion(world_pos, radius, damage, false)

func _on_boomer_exploded(world_pos: Vector2, radius: float, damage: float) -> void:
	spawn_floating_text(world_pos, "BOOMER BILE BLAST!", Color(0.58, 0.92, 0.20))
	if is_instance_valid(player) and player.has_method("add_camera_shake"):
		player.add_camera_shake(11.0)
	_apply_aoe_explosion(world_pos, radius, damage, true)

func _apply_aoe_explosion(world_pos: Vector2, radius: float, damage: float, can_hurt_player: bool) -> void:
	if zombie_container:
		for z in zombie_container.get_children():
			if is_instance_valid(z) and not z.get("is_dead"):
				var d := world_pos.distance_to(z.global_position)
				if d <= radius and z.has_method("take_damage"):
					var falloff := clampf(1.0 - (d / radius) * 0.5, 0.4, 1.0)
					if z.has_method("apply_hit_impulse"):
						z.apply_hit_impulse((z.global_position - world_pos).normalized() * 340.0)
					z.take_damage(damage * falloff)
	
	if can_hurt_player and is_instance_valid(player) and not player.is_dead:
		var dp := world_pos.distance_to(player.global_position)
		if dp <= radius:
			player.take_damage(damage * 0.75)

func _on_player_died() -> void:
	if _check_all_players_dead():
		_handle_all_players_dead()
	else:
		if is_instance_valid(player):
			spawn_floating_text(player.global_position, "! SURVIVOR 1 INCAPACITATED !", Color(1.0, 0.25, 0.20))

func _on_player2_died() -> void:
	if _check_all_players_dead():
		_handle_all_players_dead()
	else:
		if is_instance_valid(player2):
			spawn_floating_text(player2.global_position, "! SURVIVOR 2 INCAPACITATED !", Color(1.0, 0.25, 0.20))

func _check_all_players_dead() -> bool:
	var p1_dead: bool = (not is_instance_valid(player) or player.is_dead)
	var p2_dead: bool = (not is_instance_valid(player2) or player2.is_dead)
	return p1_dead and p2_dead

func _handle_all_players_dead() -> void:
	if spawn_timer:
		spawn_timer.stop()
	if wave_director and wave_director.has_method("stop_waves"):
		wave_director.stop_waves()
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.selected_mode == "survival":
		var rec: Dictionary = gs.record_survival_run(current_wave_num, score_count)
		if result_screen and result_screen.has_method("show_survival_defeat"):
			result_screen.show_survival_defeat(current_wave_num, score_count, kills_count, rec.get("new_wave_record", false) or rec.get("new_score_record", false))
			if death_panel:
				death_panel.visible = false
			return
	
	if level_controller and level_controller.has_method("on_all_players_dead"):
		level_controller.on_all_players_dead("OUTPOST OVERRUN")
	else:
		_on_level_lost(level_id, score_count, kills_count, "OUTPOST OVERRUN")

func _on_generator_started(pos: Vector2) -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("unlock_achievement"):
		gs.unlock_achievement("GENERATOR_POWER")
	if is_instance_valid(player):
		spawn_floating_text(pos + Vector2(0, -48), "⚡ EMERGENCY GENERATOR RUNNING — FLOODLIGHT ACTIVE! ⚡", Color(1.0, 0.90, 0.30))
		player.add_camera_shake(6.0)
	
	# Loud engine roars attract an immediate zombie swarm!
	if wave_director and wave_director.has_method("trigger_herd_swarm"):
		wave_director.trigger_herd_swarm(8, randf() * TAU)

func _on_herd_swarm_triggered(count: int, direction_angle: float) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_groan", 0.70, 4.0)
	
	spawn_floating_text(player.global_position + Vector2(0, -68), "⚠ WARNING: ZOMBIE HERD RUSH DETECTED! ⚠", Color(1.0, 0.20, 0.15))
	if player.has_method("add_camera_shake"):
		player.add_camera_shake(7.5)
	
	# Deploy cluster of zombies charging the player together
	var center_spawn := player.global_position + Vector2.from_angle(direction_angle) * 560.0
	for i in range(count):
		var jitter := Vector2(randf_range(-60.0, 60.0), randf_range(-60.0, 60.0))
		var z_pos := center_spawn + jitter
		var z_type := ZombieScript.ZombieType.RUNNER if (i % 2 == 0) else ZombieScript.ZombieType.WALKER
		if i == 0 and count >= 12:
			z_type = ZombieScript.ZombieType.BOOMER
		var z := spawn_test_zombie_at(z_pos, z_type)
		if is_instance_valid(z):
			z.set_meta("is_wave_enemy", true)
			if "speed" in z:
				z.speed *= 1.15

func _on_wave_started(wave_num: int, total_waves: int, wave_total_enemies: int) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_wave_start")
	current_wave_num = wave_num
	total_waves_count = total_waves
	wave_remaining_count = wave_total_enemies
	_update_kills_display()
	if is_instance_valid(player):
		var banner := "=== WAVE " + str(wave_num) + " INCOMING ===" if total_waves <= 0 else "=== WAVE " + str(wave_num) + " / " + str(total_waves) + " INCOMING ==="
		spawn_floating_text(player.global_position + Vector2(0, -56), banner, Color(0.98, 0.78, 0.25))

func _on_wave_enemies_updated(remaining_in_wave: int, _total_in_wave: int) -> void:
	wave_remaining_count = remaining_in_wave
	_update_kills_display()

func _on_wave_enemy_spawn_requested(enemy_type: int) -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	var spawn_ang := randf() * TAU
	var spawn_dist := randf_range(640.0, 780.0)
	var pos := player.global_position + Vector2.from_angle(spawn_ang) * spawn_dist
	var z := spawn_test_zombie_at(pos, enemy_type)
	if is_instance_valid(z):
		z.set_meta("is_wave_enemy", true)
		if enemy_type == ZombieScript.ZombieType.TANK:
			spawn_floating_text(player.global_position + Vector2(0, -48), "! TANKER BREACHED PERIMETER !", Color(1.0, 0.25, 0.20))
		elif enemy_type == ZombieScript.ZombieType.WITCH:
			spawn_floating_text(player.global_position + Vector2(0, -48), "! WITCH WEEPING NEARBY !", Color(0.95, 0.40, 0.40))

func _on_wave_completed(wave_num: int, total_waves: int) -> void:
	var is_endless: bool = (total_waves <= 0)
	if (is_endless or wave_num < total_waves) and is_instance_valid(player):
		spawn_floating_text(player.global_position + Vector2(0, -56), "=== WAVE " + str(wave_num) + " CLEARED — SUPPLY DROP! ===", Color(0.35, 0.95, 0.50))
		var supply_pool: Array[String] = ["MEDKIT", "ARMOR", "AMMO", "ADRENALINE"]
		var drop_offset := Vector2.from_angle(randf() * TAU) * 85.0
		spawn_pickup_at(supply_pool[randi() % supply_pool.size()], player.global_position + drop_offset)

func _on_all_waves_completed() -> void:
	var hp_ratio := 1.0
	if is_instance_valid(player):
		hp_ratio = float(player.current_health) / maxf(1.0, float(player.max_health))
	if level_controller and level_controller.has_method("on_all_waves_completed"):
		level_controller.on_all_waves_completed(hp_ratio)

func _on_level_won(lvl: int, score: int, kills: int, stars: int) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_victory")
	
	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc_sync_match_result.rpc(true, lvl, score, kills, stars, "")
	
	var achs: Array = []
	if level_controller and level_controller.get("last_unlocked_achievements") != null:
		achs = level_controller.last_unlocked_achievements.duplicate()
	if achs.is_empty():
		if level_controller and level_controller.bitten_count == 0:
			achs.append("UNTOUCHABLE (NO BITES)")
		if horror_vignette and horror_vignette.get("night_mode_enabled") == true:
			achs.append("NIGHT STALKER (BLACKOUT)")
	if result_screen and result_screen.has_method("show_victory"):
		result_screen.show_victory(lvl, score, kills, stars, achs)

func _on_level_lost(lvl: int, score: int, kills: int, reason: String) -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sfx("sfx_defeat")
	
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.selected_mode == "survival":
		var rec: Dictionary = gs.record_survival_run(current_wave_num, score_count)
		if result_screen and result_screen.has_method("show_survival_defeat"):
			result_screen.show_survival_defeat(current_wave_num, score, kills, rec.get("new_wave_record", false) or rec.get("new_score_record", false))
			if death_panel:
				death_panel.modulate.a = 0.0
			return
	
	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		rpc_sync_match_result.rpc(false, lvl, score, kills, 0, reason)
	
	if death_panel:
		death_panel.visible = true
		if death_kills_label:
			death_kills_label.text = reason + " — ELIMINATED " + str(kills) + " INFECTED (SCORE: " + str(score) + ")"
	if result_screen and result_screen.has_method("show_defeat"):
		result_screen.show_defeat(lvl, score, kills, reason)
		# Hide legacy DeathPanel visuals when ResultScreen is present so they don't overlap visually,
		# while keeping death_panel.visible = true if ResultScreen is absent
		if death_panel:
			death_panel.modulate.a = 0.0

@rpc("authority", "call_remote", "reliable")
func rpc_sync_match_result(is_victory: bool, lvl: int, score: int, kills: int, stars: int, reason: String) -> void:
	if is_victory:
		_on_level_won(lvl, score, kills, stars)
	else:
		_on_level_lost(lvl, score, kills, reason)

func _on_coop_peer_disconnected(id: int) -> void:
	if is_instance_valid(player2) and player2.peer_id == id:
		if is_instance_valid(player):
			spawn_floating_text(player.global_position, "CO-OP SURVIVOR DISCONNECTED", Color(1.0, 0.65, 0.25))
		player2.queue_free()
		player2 = null

func _on_coop_server_disconnected() -> void:
	get_tree().paused = false
	if ResourceLoader.exists("res://scenes/ui/lobby.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/lobby.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _on_next_level_requested(next_lvl: int) -> void:
	get_tree().paused = false
	var next_path := "res://scenes/levels/level_0" + str(next_lvl) + ".tscn"
	if ResourceLoader.exists(next_path):
		get_tree().change_scene_to_file(next_path)
	elif ResourceLoader.exists("res://scenes/ui/level_select.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func spawn_test_zombie_at(spawn_pos: Vector2, forced_type: int = -1) -> Node2D:
	if not zombie_scene or not zombie_container:
		return null
	
	var zombie: Node2D = zombie_scene.instantiate()
	zombie.position = spawn_pos
	zombie_container.add_child(zombie)
	
	if forced_type >= 0 and zombie.has_method("configure_type"):
		zombie.configure_type(forced_type)
	
	zombie.zombie_died.connect(_on_zombie_killed)
	if zombie.has_signal("blood_splashed"):
		zombie.blood_splashed.connect(func(pos, dir, stype, sc): spawn_blood_decal(pos, dir, stype, sc, true))
	if zombie.has_signal("limb_severed"):
		zombie.limb_severed.connect(func(pos, dir, lkind, scol, sc): spawn_severed_limb(pos, dir, lkind, scol, sc))
	if zombie.has_signal("boomer_exploded"):
		zombie.boomer_exploded.connect(_on_boomer_exploded)
	if zombie.has_signal("witch_startled"):
		zombie.witch_startled.connect(func(w):
			if is_instance_valid(w):
				spawn_floating_text(w.global_position, "! WITCH STARTLED !", Color(1.0, 0.15, 0.15))
		)
	if zombie.has_signal("drop_requested"):
		zombie.drop_requested.connect(_on_zombie_drop_requested)
	
	if is_instance_valid(player):
		zombie.set_target(player)
	return zombie

func _pick_zombie_type_for_spawn() -> int:
	total_spawned += 1
	# Guarantee periodic special infected variety (Runner, Boomer, Spitter, Witch, Tanker)
	if total_spawned % 12 == 0:
		return ZombieScript.ZombieType.TANK
	if total_spawned % 9 == 0:
		return ZombieScript.ZombieType.WITCH
	
	var roll := randf()
	if roll < 0.42:
		return ZombieScript.ZombieType.WALKER
	elif roll < 0.66:
		return ZombieScript.ZombieType.RUNNER
	elif roll < 0.82:
		return ZombieScript.ZombieType.BOOMER
	elif roll < 0.94:
		return ZombieScript.ZombieType.SPITTER
	else:
		return ZombieScript.ZombieType.WITCH

func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(player) or player.is_dead:
		return
	
	if zombie_container.get_child_count() >= max_alive_zombies:
		return
	
	# Spawn zombies on a 360-degree perimeter ring around the player's current position in the infinite world
	var spawn_ang := randf() * TAU
	var spawn_dist := randf_range(640.0, 780.0)
	var pos := player.global_position + Vector2.from_angle(spawn_ang) * spawn_dist
	var z_type := _pick_zombie_type_for_spawn()
	var z := spawn_test_zombie_at(pos, z_type)
	if is_instance_valid(z):
		if z_type == ZombieScript.ZombieType.TANK:
			spawn_floating_text(player.global_position + Vector2(0, -48), "! TANKER BREACHED PERIMETER !", Color(1.0, 0.25, 0.20))
		elif z_type == ZombieScript.ZombieType.WITCH:
			spawn_floating_text(player.global_position + Vector2(0, -48), "! WITCH WEEPING NEARBY !", Color(0.95, 0.40, 0.40))

func _on_zombie_drop_requested(world_pos: Vector2, z_type_name: String) -> void:
	# Special infected have high/guaranteed supply drop chances; normal walkers have 35% chance
	var drop_chance := 0.35
	if z_type_name in ["TANKER", "WITCH"]:
		drop_chance = 1.0
	elif z_type_name in ["BOOMER", "SPITTER"]:
		drop_chance = 0.72
	elif z_type_name == "RUNNER":
		drop_chance = 0.45
	
	if randf() > drop_chance:
		return
	
	var drop_pool: Array[String] = [
		"MEDKIT", "ARMOR", "AMMO", "ADRENALINE",
		"WEAPON_SMG", "WEAPON_SHOTGUN", "WEAPON_ASSAULT_RIFLE", "WEAPON_MAGNUM"
	]
	var chosen := drop_pool[randi() % drop_pool.size()]
	spawn_pickup_at(chosen, world_pos)

func _on_zombie_killed(zombie: Node2D) -> void:
	kills_count += 1
	var pts: int = int(zombie.get("score_value")) if is_instance_valid(zombie) and zombie.get("score_value") != null else 10
	score_count += pts
	if is_instance_valid(zombie) and zombie.has_method("get_type_name"):
		var z_name: String = zombie.get_type_name()
		var gs := get_node_or_null("/root/GameState")
		if gs and gs.has_method("record_special_kill"):
			gs.record_special_kill(z_name)
	if level_controller and level_controller.has_method("record_kill"):
		level_controller.record_kill(pts)
	if wave_director and is_instance_valid(zombie) and zombie.has_meta("is_wave_enemy"):
		wave_director.notify_enemy_killed()
	_update_kills_display()

func _update_kills_display() -> void:
	if kills_label:
		var wave_str := "WAVE " + str(current_wave_num) if total_waves_count <= 0 else "WAVE " + str(current_wave_num) + "/" + str(total_waves_count)
		var gs := get_node_or_null("/root/GameState")
		var mode_prefix := "SURVIVAL: " if (gs != null and gs.selected_mode == "survival") else ""
		kills_label.text = mode_prefix + wave_str + "   ·   " + current_time_phase_name + "   ·   HOSTILES: " + str(wave_remaining_count) + "   ·   KILLS: " + str(kills_count) + "   ·   SCORE: " + str(score_count)

func _on_pause_button_pressed() -> void:
	if pause_menu and pause_menu.has_method("open_pause_menu"):
		pause_menu.open_pause_menu()

func _on_save_progress_requested() -> void:
	var hp: float = float(player.current_health) if is_instance_valid(player) else 100.0
	var ap: float = float(player.current_armor) if is_instance_valid(player) else 0.0
	var weps: Array = player.weapon_controller.unlocked_weapons if (is_instance_valid(player) and player.weapon_controller) else ["PISTOL"]
	
	var saved_ok := false
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("save_checkpoint"):
		saved_ok = gs.save_checkpoint(level_id, kills_count, score_count, hp, ap, weps)
	else:
		var temp_gs: Node = load("res://autoload/game_state.gd").new()
		saved_ok = temp_gs.save_checkpoint(level_id, kills_count, score_count, hp, ap, weps)
		temp_gs.free()
	
	if pause_menu and pause_menu.has_method("show_save_confirmation"):
		pause_menu.show_save_confirmation(saved_ok)

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_menu and not death_panel.visible:
			if pause_menu.visible:
				pause_menu.close_pause_menu()
			else:
				pause_menu.open_pause_menu()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and death_panel.visible:
			_on_restart_pressed()
