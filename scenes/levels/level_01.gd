extends Node2D

const BloodDecalScript = preload("res://scripts/blood_decal.gd")
const ZombieScript = preload("res://scripts/zombie_basic.gd")

@export var zombie_scene: PackedScene = preload("res://scenes/actors/zombie_basic.tscn")
@export var pickup_scene: PackedScene = preload("res://scenes/actors/pickup.tscn")
@export var max_alive_zombies: int = 18
@export var max_blood_decals: int = 240

@onready var arena_env: Node2D = $ArenaEnvironment
@onready var blood_container: Node2D = $BloodDecalContainer
@onready var pickup_container: Node2D = $PickupContainer
@onready var player: CharacterBody2D = $Player
@onready var zombie_container: Node2D = $ZombieContainer
@onready var fx_container: Node2D = $FXContainer
@onready var spawn_timer: Timer = $SpawnTimer

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
@onready var death_panel: PanelContainer = $UI/DeathPanel
@onready var death_kills_label: Label = $UI/DeathPanel/DeathMargin/DeathVBox/DeathKillsLabel
@onready var restart_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/RestartButton
@onready var menu_button: Button = $UI/DeathPanel/DeathMargin/DeathVBox/MenuButton

var kills_count: int = 0
var score_count: int = 0
var total_spawned: int = 0
var title_font: Font = preload("res://assets/fonts/BebasNeue-Regular.ttf")

func _ready() -> void:
	get_tree().paused = false
	if death_panel:
		death_panel.visible = false
	
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
		
		_on_player_health_changed(player.current_health, player.max_health)
		_on_player_armor_changed(player.current_armor, player.max_armor)
		_refresh_weapon_hud()
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	
	if pause_menu:
		pause_menu.save_requested.connect(_on_save_progress_requested)
		pause_menu.retry_requested.connect(_on_restart_pressed)
		pause_menu.main_menu_requested.connect(_on_return_pressed)
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_return_pressed)
	
	if spawn_timer:
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
		spawn_timer.start()
	
	_update_kills_display()

func spawn_blood_decal(world_pos: Vector2, hit_dir: Vector2, splatter_type: int = -1, scale_mult: float = 1.0, active_splash: bool = true) -> Node2D:
	if not blood_container:
		return null
	
	if blood_container.get_child_count() >= max_blood_decals:
		var oldest := blood_container.get_child(0)
		if is_instance_valid(oldest):
			oldest.queue_free()
	
	var decal := Node2D.new()
	decal.set_script(BloodDecalScript)
	blood_container.add_child(decal)
	decal.setup(world_pos, hit_dir, splatter_type, scale_mult, active_splash)
	return decal

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
	_refresh_weapon_hud()

func _on_player_damaged_at(world_pos: Vector2, hit_dir: Vector2) -> void:
	spawn_blood_decal(world_pos, hit_dir, 0, 0.95, true)

func _on_grenade_detonated(world_pos: Vector2, radius: float, damage: float) -> void:
	spawn_blood_decal(world_pos, Vector2.RIGHT, 7, 1.35, true) # Scorch crater + debris
	spawn_floating_text(world_pos, "FRAG BLAST!", Color(1.0, 0.62, 0.20))
	_apply_aoe_explosion(world_pos, radius, damage, false)

func _on_boomer_exploded(world_pos: Vector2, radius: float, damage: float) -> void:
	spawn_floating_text(world_pos, "BOOMER BILE BLAST!", Color(0.58, 0.92, 0.20))
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
	if spawn_timer:
		spawn_timer.stop()
	if death_panel:
		death_panel.visible = true
		if death_kills_label:
			death_kills_label.text = "OUTPOST OVERRUN — ELIMINATED " + str(kills_count) + " INFECTED (SCORE: " + str(score_count) + ")"

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
	
	var spawn_points: Array[Vector2] = [
		Vector2(randf_range(90, 1190), 75),
		Vector2(randf_range(90, 1190), 645),
		Vector2(75, randf_range(90, 630)),
		Vector2(1205, randf_range(90, 630))
	]
	var pos := spawn_points[randi() % spawn_points.size()]
	var z_type := _pick_zombie_type_for_spawn()
	var z := spawn_test_zombie_at(pos, z_type)
	if is_instance_valid(z):
		if z_type == ZombieScript.ZombieType.TANK:
			spawn_floating_text(pos, "! TANKER BREACHED PERIMETER !", Color(1.0, 0.25, 0.20))
		elif z_type == ZombieScript.ZombieType.WITCH:
			spawn_floating_text(pos, "! WITCH WEEPING NEARBY !", Color(0.95, 0.40, 0.40))

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
	_update_kills_display()

func _update_kills_display() -> void:
	if kills_label:
		kills_label.text = "INFECTED KILLED: " + str(kills_count) + "   ·   SCORE: " + str(score_count)

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
		saved_ok = gs.save_checkpoint(1, kills_count, score_count, hp, ap, weps)
	else:
		var temp_gs: Node = load("res://autoload/game_state.gd").new()
		saved_ok = temp_gs.save_checkpoint(1, kills_count, score_count, hp, ap, weps)
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
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R and death_panel.visible:
		_on_restart_pressed()
