extends Node

signal wave_started(wave_num: int, total_waves: int, wave_total_enemies: int)
signal enemy_spawn_requested(enemy_type: int)
signal wave_enemies_updated(remaining_in_wave: int, total_in_wave: int)
signal wave_completed(wave_num: int, total_waves: int)
signal all_waves_completed()
signal herd_swarm_triggered(count: int, direction_angle: float)

const DEFAULT_WAVES: Array[Dictionary] = [
	{
		"total_enemies": 6,
		"spawn_interval": 1.65,
		"max_concurrent": 5,
		"intermission": 2.2,
		"guaranteed_boss": -1 # Normal Walkers, Runners, Spitters
	},
	{
		"total_enemies": 10,
		"spawn_interval": 1.35,
		"max_concurrent": 8,
		"intermission": 2.5,
		"guaranteed_boss": 5 # Guaranteed Witch in Wave 2
	},
	{
		"total_enemies": 14,
		"spawn_interval": 1.15,
		"max_concurrent": 11,
		"intermission": 2.5,
		"guaranteed_boss": 3 # Guaranteed Tanker Boss in Final Wave 3
	}
]

var waves_config: Array[Dictionary] = []
var current_wave_index: int = -1
var enemies_spawned_in_wave: int = 0
var enemies_alive_in_wave: int = 0
var enemies_killed_in_wave: int = 0
var total_enemies_in_wave: int = 0
var max_concurrent_in_wave: int = 6
var boss_spawned_in_wave: bool = false
var herd_spawned_in_wave: bool = false

var is_wave_active: bool = false
var is_intermission: bool = false
var all_completed: bool = false
var is_endless_survival: bool = false
var total_survival_waves_completed: int = 0

var spawn_timer: Timer = null
var intermission_timer: Timer = null

func _ready() -> void:
	if waves_config.is_empty():
		waves_config = DEFAULT_WAVES.duplicate(true)
	
	spawn_timer = Timer.new()
	spawn_timer.name = "WaveSpawnTimer"
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(spawn_timer)
	
	intermission_timer = Timer.new()
	intermission_timer.name = "WaveIntermissionTimer"
	intermission_timer.one_shot = true
	intermission_timer.timeout.connect(_on_intermission_finished)
	add_child(intermission_timer)

func setup_waves(custom_waves: Array[Dictionary]) -> void:
	waves_config = custom_waves.duplicate(true)
	current_wave_index = -1
	is_wave_active = false
	is_intermission = false
	all_completed = false

func get_total_waves() -> int:
	if is_endless_survival:
		return -1 # Endless indicator
	return waves_config.size()

func get_current_wave_number() -> int:
	return max(1, current_wave_index + 1)

func get_remaining_enemies_in_wave() -> int:
	return max(0, total_enemies_in_wave - enemies_killed_in_wave)

func start_waves() -> void:
	if waves_config.is_empty() and not is_endless_survival:
		waves_config = DEFAULT_WAVES.duplicate(true)
	current_wave_index = -1
	all_completed = false
	total_survival_waves_completed = 0
	start_next_wave()

func stop_waves() -> void:
	is_wave_active = false
	is_intermission = false
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
	if is_instance_valid(intermission_timer):
		intermission_timer.stop()

func _generate_endless_wave_config(wave_idx: int) -> Dictionary:
	var wave_num := wave_idx + 1
	var count := 8 + wave_num * 4
	var max_conc := mini(24, 7 + wave_num * 2)
	var interval := maxf(0.50, 1.45 - wave_num * 0.05)
	var boss_type := -1
	if wave_num % 6 == 0:
		boss_type = 13 # Necro + 7 Witches Coven Boss every 6 waves
	elif wave_num % 5 == 0:
		boss_type = 3 # Tanker Boss every 5 waves
	elif wave_num % 4 == 0:
		boss_type = 9 if (wave_num % 8 == 0) else 11 # Brute or Butcher
	elif wave_num % 3 == 0:
		boss_type = 12 if (wave_num % 6 == 0) else 5 # Phantom or Witch
	elif wave_num % 2 == 0:
		boss_type = 6 if (wave_num % 4 == 2) else 2 # Screamer or Boomer
	return {
		"total_enemies": count,
		"spawn_interval": interval,
		"max_concurrent": max_conc,
		"intermission": 3.0,
		"guaranteed_boss": boss_type
	}

func start_next_wave() -> void:
	current_wave_index += 1
	if not is_endless_survival and current_wave_index >= waves_config.size():
		is_wave_active = false
		all_completed = true
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		all_waves_completed.emit()
		return
	
	var cfg: Dictionary
	if is_endless_survival:
		cfg = _generate_endless_wave_config(current_wave_index)
	else:
		cfg = waves_config[current_wave_index]
	
	total_enemies_in_wave = int(cfg.get("total_enemies", 6))
	max_concurrent_in_wave = int(cfg.get("max_concurrent", 6))
	var interval: float = float(cfg.get("spawn_interval", 1.5))
	
	enemies_spawned_in_wave = 0
	enemies_alive_in_wave = 0
	enemies_killed_in_wave = 0
	boss_spawned_in_wave = false
	herd_spawned_in_wave = false
	is_wave_active = true
	is_intermission = false
	
	if is_instance_valid(spawn_timer):
		spawn_timer.wait_time = maxf(0.05, interval)
		spawn_timer.start()
	
	var total_display := -1 if is_endless_survival else waves_config.size()
	wave_started.emit(current_wave_index + 1, total_display, total_enemies_in_wave)
	wave_enemies_updated.emit(total_enemies_in_wave, total_enemies_in_wave)

func trigger_herd_swarm(count: int = 10, direction_angle: float = -999.0) -> void:
	var ang := direction_angle
	if ang < -900.0:
		ang = randf() * TAU
	herd_swarm_triggered.emit(count, ang)

func _on_spawn_tick() -> void:
	if not is_wave_active or all_completed:
		return
	
	# Multiplayer safety: only authority decides when and where enemies spawn
	if multiplayer and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	# In endless mode, trigger a herd swarm when halfway through wave from wave 2+
	if is_endless_survival and not herd_spawned_in_wave and (current_wave_index + 1) >= 2:
		if enemies_spawned_in_wave >= int(total_enemies_in_wave * 0.45):
			herd_spawned_in_wave = true
			var herd_size := clampi(6 + (current_wave_index + 1) * 2, 8, 16)
			trigger_herd_swarm(herd_size, randf() * TAU)
	
	if enemies_spawned_in_wave >= total_enemies_in_wave:
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		return
	
	if enemies_alive_in_wave >= max_concurrent_in_wave:
		return
	
	var enemy_type := _pick_enemy_type_for_current_wave()
	enemies_spawned_in_wave += 1
	enemies_alive_in_wave += 1
	enemy_spawn_requested.emit(enemy_type)

func _pick_enemy_type_for_current_wave() -> int:
	var cfg: Dictionary
	if is_endless_survival:
		cfg = _generate_endless_wave_config(current_wave_index)
	else:
		cfg = waves_config[current_wave_index]
	
	var boss_type: int = int(cfg.get("guaranteed_boss", -1))
	
	# Spawn guaranteed boss halfway through the wave (or on last enemy if small wave)
	if boss_type >= 0 and not boss_spawned_in_wave:
		if enemies_spawned_in_wave >= int(float(total_enemies_in_wave) / 2.0) or enemies_spawned_in_wave == total_enemies_in_wave - 1:
			boss_spawned_in_wave = true
			return boss_type
	
	var roll := randf()
	if current_wave_index == 0:
		# Wave 1: Walkers, Runners, plus early Scary Variants (Screamer, Stalker, Leaper, Parasite)
		if roll < 0.42:
			return 0 # WALKER
		elif roll < 0.66:
			return 1 # RUNNER
		elif roll < 0.74:
			return 2 # BOOMER
		elif roll < 0.81:
			return 4 # SPITTER
		elif roll < 0.86:
			return 6 # SCREAMER
		elif roll < 0.91:
			return 7 # STALKER
		elif roll < 0.96:
			return 8 # LEAPER
		else:
			return 10 # PARASITE
	elif current_wave_index == 1:
		# Wave 2: Heavier mix including Screamer, Stalker, Leaper, Parasite, Butcher, Phantom
		if roll < 0.28:
			return 0 # WALKER
		elif roll < 0.48:
			return 1 # RUNNER
		elif roll < 0.56:
			return 2 # BOOMER
		elif roll < 0.64:
			return 4 # SPITTER
		elif roll < 0.70:
			return 5 # WITCH
		elif roll < 0.76:
			return 6 # SCREAMER
		elif roll < 0.82:
			return 7 # STALKER
		elif roll < 0.88:
			return 8 # LEAPER
		elif roll < 0.93:
			return 10 # PARASITE
		elif roll < 0.97:
			return 11 # BUTCHER
		else:
			return 12 # PHANTOM
	else:
		# Wave 3+: Intense horde with all 13 special & scary infected variants
		if roll < 0.22:
			return 0 # WALKER
		elif roll < 0.38:
			return 1 # RUNNER
		elif roll < 0.46:
			return 2 # BOOMER
		elif roll < 0.54:
			return 4 # SPITTER
		elif roll < 0.60:
			return 5 # WITCH
		elif roll < 0.66:
			return 6 # SCREAMER
		elif roll < 0.73:
			return 7 # STALKER
		elif roll < 0.80:
			return 8 # LEAPER
		elif roll < 0.86:
			return 9 # BRUTE
		elif roll < 0.91:
			return 10 # PARASITE
		elif roll < 0.96:
			return 11 # BUTCHER
		elif roll < 0.98:
			return 12 # PHANTOM
		elif roll < 0.992:
			return 3 # TANK
		else:
			return 13 # NECRO

func notify_enemy_killed() -> void:
	if not is_wave_active and not is_intermission:
		return
	
	enemies_alive_in_wave = max(0, enemies_alive_in_wave - 1)
	enemies_killed_in_wave += 1
	wave_enemies_updated.emit(get_remaining_enemies_in_wave(), total_enemies_in_wave)
	
	if enemies_killed_in_wave >= total_enemies_in_wave and is_wave_active:
		is_wave_active = false
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		
		var finished_wave_num := current_wave_index + 1
		total_survival_waves_completed = finished_wave_num
		var total_display := -1 if is_endless_survival else waves_config.size()
		wave_completed.emit(finished_wave_num, total_display)
		
		if not is_endless_survival and current_wave_index + 1 >= waves_config.size():
			all_completed = true
			all_waves_completed.emit()
		else:
			var wait_sec: float = 3.0
			if not is_endless_survival:
				var next_cfg: Dictionary = waves_config[current_wave_index + 1]
				wait_sec = float(next_cfg.get("intermission", 2.2))
			
			if wait_sec <= 0.01:
				start_next_wave()
			else:
				is_intermission = true
				if is_instance_valid(intermission_timer):
					intermission_timer.wait_time = wait_sec
					intermission_timer.start()

func _on_intermission_finished() -> void:
	if is_intermission and not all_completed:
		start_next_wave()
