extends Node

signal shot_fired(projectile: Node2D)
signal weapon_changed(weapon_id: String, weapon_name: String, ammo: int, max_ammo: int)
signal ammo_changed(weapon_id: String, ammo: int, max_ammo: int)

@export var projectile_scene: PackedScene = preload("res://scenes/actors/projectile.tscn")
@export var fire_rate: float = 0.20
@export var damage: float = 25.0
@export var projectile_speed: float = 850.0

const WEAPON_SPECS: Dictionary = {
	"PISTOL": {
		"name": "9MM SERVICE PISTOL",
		"fire_rate": 0.20,
		"damage": 26.0,
		"speed": 850.0,
		"pellets": 1,
		"spread": 0.03,
		"pierce": 1,
		"recoil_shake": 0.65,
		"max_shake": 1.1,
		"max_ammo": -1, # Infinite reserve
		"pickup_ammo": -1,
		"color": Color(0.98, 0.85, 0.35, 1.0)
	},
	"SMG": {
		"name": "MP5 SUBMACHINE GUN",
		"fire_rate": 0.085,
		"damage": 19.0,
		"speed": 880.0,
		"pellets": 1,
		"spread": 0.11,
		"pierce": 1,
		"recoil_shake": 0.40,
		"max_shake": 0.9,
		"max_ammo": 150,
		"pickup_ammo": 75,
		"color": Color(0.98, 0.76, 0.25, 1.0)
	},
	"SHOTGUN": {
		"name": "12G COMBAT SHOTGUN",
		"fire_rate": 0.56,
		"damage": 21.0,
		"speed": 760.0,
		"pellets": 6,
		"spread": 0.28,
		"pierce": 1,
		"recoil_shake": 3.0,
		"max_shake": 3.8,
		"max_ammo": 36,
		"pickup_ammo": 16,
		"color": Color(1.0, 0.62, 0.22, 1.0)
	},
	"ASSAULT_RIFLE": {
		"name": "M4A1 ASSAULT RIFLE",
		"fire_rate": 0.12,
		"damage": 35.0,
		"speed": 960.0,
		"pellets": 1,
		"spread": 0.05,
		"pierce": 1,
		"recoil_shake": 0.55,
		"max_shake": 1.2,
		"max_ammo": 100,
		"pickup_ammo": 50,
		"color": Color(1.0, 0.90, 0.45, 1.0)
	},
	"MAGNUM": {
		"name": ".44 PIERCING MAGNUM",
		"fire_rate": 0.46,
		"damage": 95.0,
		"speed": 1150.0,
		"pellets": 1,
		"spread": 0.01,
		"pierce": 3,
		"recoil_shake": 2.0,
		"max_shake": 2.6,
		"max_ammo": 24,
		"pickup_ammo": 12,
		"color": Color(1.0, 0.40, 0.30, 1.0)
	}
}

const WEAPON_ORDER: Array[String] = ["PISTOL", "SMG", "SHOTGUN", "ASSAULT_RIFLE", "MAGNUM"]

var current_weapon_id: String = "PISTOL"
var unlocked_weapons: Array[String] = ["PISTOL"]
var ammo_counts: Dictionary = {
	"PISTOL": -1,
	"SMG": 0,
	"SHOTGUN": 0,
	"ASSAULT_RIFLE": 0,
	"MAGNUM": 0
}
var ammo_by_weapon: Dictionary:
	get:
		return ammo_counts

var cooldown_remaining: float = 0.0
var fire_rate_multiplier: float = 1.0

func _ready() -> void:
	equip_weapon("PISTOL")

func _process(delta: float) -> void:
	update_cooldown(delta)

func update_cooldown(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = max(0.0, cooldown_remaining - delta)

func can_shoot() -> bool:
	if cooldown_remaining > 0.0:
		return false
	var ammo: int = ammo_counts.get(current_weapon_id, -1)
	return ammo == -1 or ammo > 0

func get_current_weapon_spec() -> Dictionary:
	return WEAPON_SPECS.get(current_weapon_id, WEAPON_SPECS["PISTOL"])

func equip_weapon(weapon_id: String) -> bool:
	if not WEAPON_SPECS.has(weapon_id) or not unlocked_weapons.has(weapon_id):
		return false
	if current_weapon_id != weapon_id:
		cooldown_remaining = 0.0
	current_weapon_id = weapon_id
	var spec: Dictionary = WEAPON_SPECS[weapon_id]
	fire_rate = float(spec["fire_rate"])
	damage = float(spec["damage"])
	projectile_speed = float(spec["speed"])
	weapon_changed.emit(current_weapon_id, str(spec["name"]), int(ammo_counts[current_weapon_id]), int(spec["max_ammo"]))
	return true

func cycle_weapon(step: int = 1) -> void:
	if unlocked_weapons.size() <= 1:
		return
	var idx := unlocked_weapons.find(current_weapon_id)
	if idx == -1:
		idx = 0
	idx = posmod(idx + step, unlocked_weapons.size())
	equip_weapon(unlocked_weapons[idx])

func unlock_or_add_weapon(weapon_id: String) -> void:
	if not WEAPON_SPECS.has(weapon_id):
		return
	var spec: Dictionary = WEAPON_SPECS[weapon_id]
	if not unlocked_weapons.has(weapon_id):
		unlocked_weapons.append(weapon_id)
		# Keep weapon order consistent
		unlocked_weapons.sort_custom(func(a, b): return WEAPON_ORDER.find(a) < WEAPON_ORDER.find(b))
	
	if int(spec["max_ammo"]) > 0:
		var cur_ammo: int = int(ammo_counts.get(weapon_id, 0))
		ammo_counts[weapon_id] = mini(int(spec["max_ammo"]), cur_ammo + int(spec["pickup_ammo"]))
	
	equip_weapon(weapon_id)

func refill_all_unlocked_ammo() -> void:
	for wid in unlocked_weapons:
		if wid == "PISTOL":
			continue
		var spec: Dictionary = WEAPON_SPECS[wid]
		ammo_counts[wid] = mini(int(spec["max_ammo"]), int(ammo_counts.get(wid, 0)) + int(spec["pickup_ammo"]))
	var cur_spec: Dictionary = WEAPON_SPECS[current_weapon_id]
	ammo_changed.emit(current_weapon_id, int(ammo_counts[current_weapon_id]), int(cur_spec["max_ammo"]))

func get_current_weapon_display() -> String:
	var spec: Dictionary = WEAPON_SPECS.get(current_weapon_id, WEAPON_SPECS["PISTOL"])
	var w_name: String = str(spec["name"])
	var ammo: int = int(ammo_counts.get(current_weapon_id, -1))
	if ammo < 0:
		return w_name + " [ INF ]"
	return w_name + " [ " + str(ammo) + " / " + str(spec["max_ammo"]) + " ]"

func try_fire(spawn_pos: Vector2, shoot_dir: Vector2, shooter: Node2D) -> Node2D:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if not can_shoot():
		if audio_mgr and cooldown_remaining <= 0.0:
			audio_mgr.play_sfx("sfx_dry_fire")
		# Auto-fallback to pistol if out of ammo on special weapon
		if cooldown_remaining <= 0.0 and current_weapon_id != "PISTOL":
			equip_weapon("PISTOL")
		else:
			return null
	
	if not projectile_scene:
		return null
	
	var spec: Dictionary = WEAPON_SPECS.get(current_weapon_id, WEAPON_SPECS["PISTOL"])
	cooldown_remaining = fire_rate * fire_rate_multiplier
	
	# Play authentic sound effect for weapon
	if audio_mgr:
		match current_weapon_id:
			"PISTOL": audio_mgr.play_sfx("sfx_pistol")
			"SHOTGUN": audio_mgr.play_sfx("sfx_shotgun")
			"SMG": audio_mgr.play_sfx("sfx_smg")
			"ASSAULT_RIFLE": audio_mgr.play_sfx("sfx_rifle")
			"MAGNUM": audio_mgr.play_sfx("sfx_magnum")
			_: audio_mgr.play_sfx("sfx_pistol")
	
	# Consume ammo if finite
	if int(spec["max_ammo"]) > 0:
		ammo_counts[current_weapon_id] = max(0, int(ammo_counts[current_weapon_id]) - 1)
		ammo_changed.emit(current_weapon_id, int(ammo_counts[current_weapon_id]), int(spec["max_ammo"]))
	
	var pellets: int = int(spec.get("pellets", 1))
	var spread: float = float(spec.get("spread", 0.0))
	var pierce: int = int(spec.get("pierce", 1))
	var t_color: Color = spec.get("color", Color(0.98, 0.85, 0.35, 1.0))
	
	var first_proj: Node2D = null
	var base_dir := shoot_dir.normalized() if shoot_dir != Vector2.ZERO else Vector2.RIGHT
	
	for i in range(pellets):
		var proj: Node2D = projectile_scene.instantiate()
		if shooter.get_parent():
			shooter.get_parent().add_child(proj)
		else:
			shooter.add_child(proj)
		
		var angle_offset := 0.0
		if pellets > 1:
			var t := (float(i) / float(pellets - 1)) - 0.5
			angle_offset = t * spread + randf_range(-0.03, 0.03)
		elif spread > 0.0:
			angle_offset = randf_range(-spread * 0.5, spread * 0.5)
		
		var pellet_dir := base_dir.rotated(angle_offset)
		var pellet_spd := projectile_speed * (randf_range(0.92, 1.08) if pellets > 1 else 1.0)
		proj.init(spawn_pos, pellet_dir, pellet_spd, damage, shooter, pierce, t_color, false)
		
		if i == 0:
			first_proj = proj
		shot_fired.emit(proj)
	
	# Auto-switch back to pistol if last round was just fired
	if int(spec["max_ammo"]) > 0 and int(ammo_counts[current_weapon_id]) <= 0:
		equip_weapon("PISTOL")
	
	return first_proj
