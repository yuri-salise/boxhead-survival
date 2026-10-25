extends Node

signal wave_started(wave_num: int, total_waves: int, wave_total_enemies: int)
signal enemy_spawn_requested(enemy_type: int)
signal wave_enemies_updated(remaining_in_wave: int, total_in_wave: int)
signal wave_completed(wave_num: int, total_waves: int)
signal all_waves_completed()

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

var is_wave_active: bool = false
var is_intermission: bool = false
var all_completed: bool = false

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
	return waves_config.size()

func get_current_wave_number() -> int:
	return max(1, current_wave_index + 1)

func get_remaining_enemies_in_wave() -> int:
	return max(0, total_enemies_in_wave - enemies_killed_in_wave)

func start_waves() -> void:
	if waves_config.is_empty():
		waves_config = DEFAULT_WAVES.duplicate(true)
	current_wave_index = -1
	all_completed = false
	start_next_wave()

func stop_waves() -> void:
	is_wave_active = false
	is_intermission = false
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
	if is_instance_valid(intermission_timer):
		intermission_timer.stop()

func start_next_wave() -> void:
	current_wave_index += 1
	if current_wave_index >= waves_config.size():
		is_wave_active = false
		all_completed = true
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		all_waves_completed.emit()
		return
	
	var cfg: Dictionary = waves_config[current_wave_index]
	total_enemies_in_wave = int(cfg.get("total_enemies", 6))
	max_concurrent_in_wave = int(cfg.get("max_concurrent", 6))
	var interval: float = float(cfg.get("spawn_interval", 1.5))
	
	enemies_spawned_in_wave = 0
	enemies_alive_in_wave = 0
	enemies_killed_in_wave = 0
	boss_spawned_in_wave = false
	is_wave_active = true
	is_intermission = false
	
	if is_instance_valid(spawn_timer):
		spawn_timer.wait_time = maxf(0.05, interval)
		spawn_timer.start()
	
	wave_started.emit(current_wave_index + 1, waves_config.size(), total_enemies_in_wave)
	wave_enemies_updated.emit(total_enemies_in_wave, total_enemies_in_wave)

func _on_spawn_tick() -> void:
	if not is_wave_active or all_completed:
		return
	
	# Multiplayer safety: only authority decides when and where enemies spawn
	if multiplayer and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
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
	var cfg: Dictionary = waves_config[current_wave_index]
	var boss_type: int = int(cfg.get("guaranteed_boss", -1))
	
	# Spawn guaranteed boss halfway through the wave (or on last enemy if small wave)
	if boss_type >= 0 and not boss_spawned_in_wave:
		if enemies_spawned_in_wave >= int(total_enemies_in_wave / 2) or enemies_spawned_in_wave == total_enemies_in_wave - 1:
			boss_spawned_in_wave = true
			return boss_type
	
	var roll := randf()
	if current_wave_index == 0:
		# Wave 1: Walkers, Runners, occasional Boomer/Spitter
		if roll < 0.52:
			return 0 # WALKER
		elif roll < 0.80:
			return 1 # RUNNER
		elif roll < 0.92:
			return 2 # BOOMER
		else:
			return 4 # SPITTER
	elif current_wave_index == 1:
		# Wave 2: Heavier mix of Runners, Boomers, Spitters, and Witches
		if roll < 0.36:
			return 0 # WALKER
		elif roll < 0.65:
			return 1 # RUNNER
		elif roll < 0.82:
			return 2 # BOOMER
		elif roll < 0.94:
			return 4 # SPITTER
		else:
			return 5 # WITCH
	else:
		# Wave 3+: Intense horde with all special infected
		if roll < 0.30:
			return 0 # WALKER
		elif roll < 0.58:
			return 1 # RUNNER
		elif roll < 0.76:
			return 2 # BOOMER
		elif roll < 0.90:
			return 4 # SPITTER
		elif roll < 0.96:
			return 5 # WITCH
		else:
			return 3 # TANK

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
		wave_completed.emit(finished_wave_num, waves_config.size())
		
		if current_wave_index + 1 >= waves_config.size():
			all_completed = true
			all_waves_completed.emit()
		else:
			var next_cfg: Dictionary = waves_config[current_wave_index + 1]
			var wait_sec: float = float(next_cfg.get("intermission", 2.2))
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
