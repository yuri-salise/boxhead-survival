extends Node

signal sfx_setting_changed(enabled: bool)
signal music_setting_changed(enabled: bool)

const POOL_SIZE: int = 16

var sfx_streams: Dictionary = {}
var sfx_players: Array[AudioStreamPlayer] = []
var next_player_idx: int = 0

var sfx_enabled: bool = true
var music_enabled: bool = true
var sfx_volume: float = 1.0
var music_volume: float = 0.8

var music_player: AudioStreamPlayer = null
var music_streams: Dictionary = {}
var current_music_track: String = ""

const MUSIC_FILES: Dictionary = {
	"ambient_menu": "res://assets/audio/ambient_menu.wav",
	"ambient_combat": "res://assets/audio/ambient_combat.wav"
}

const SFX_FILES: Dictionary = {
	"sfx_pistol": "res://assets/audio/sfx_pistol.wav",
	"sfx_shotgun": "res://assets/audio/sfx_shotgun.wav",
	"sfx_smg": "res://assets/audio/sfx_smg.wav",
	"sfx_rifle": "res://assets/audio/sfx_rifle.wav",
	"sfx_magnum": "res://assets/audio/sfx_magnum.wav",
	"sfx_dry_fire": "res://assets/audio/sfx_dry_fire.wav",
	"sfx_groan": "res://assets/audio/sfx_groan.wav",
	"sfx_zombie_hit": "res://assets/audio/sfx_zombie_hit.wav",
	"sfx_zombie_death": "res://assets/audio/sfx_zombie_death.wav",
	"sfx_bite": "res://assets/audio/sfx_bite.wav",
	"sfx_boomer": "res://assets/audio/sfx_boomer.wav",
	"sfx_witch": "res://assets/audio/sfx_witch.wav",
	"sfx_player_hurt": "res://assets/audio/sfx_player_hurt.wav",
	"sfx_dash": "res://assets/audio/sfx_dash.wav",
	"sfx_explosion": "res://assets/audio/sfx_explosion.wav",
	"sfx_pickup": "res://assets/audio/sfx_pickup.wav",
	"sfx_wave_start": "res://assets/audio/sfx_wave_start.wav",
	"sfx_victory": "res://assets/audio/sfx_victory.wav",
	"sfx_defeat": "res://assets/audio/sfx_defeat.wav"
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 1. Preload audio streams with direct fallback parser
	for key in SFX_FILES.keys():
		var path: String = SFX_FILES[key]
		var stream: AudioStream = _load_wav_stream(path)
		if stream:
			sfx_streams[key] = stream
	
	for key in MUSIC_FILES.keys():
		var path: String = MUSIC_FILES[key]
		var stream: AudioStream = _load_wav_stream(path)
		if stream:
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			music_streams[key] = stream
	
	# 2. Build AudioStreamPlayer polyphonic pool
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		p.bus = "Master"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_players.append(p)
	
	# 3. Create dedicated music stream player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	
	load_audio_settings()

func has_sfx(sfx_name: String) -> bool:
	return sfx_streams.has(sfx_name)

func play_sfx(sfx_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	if not sfx_enabled:
		return null
	
	if not sfx_streams.has(sfx_name):
		return null
	
	var stream: AudioStream = sfx_streams[sfx_name]
	var player: AudioStreamPlayer = null
	
	# Find an idle player in the pool
	for p in sfx_players:
		if not p.playing:
			player = p
			break
	
	# If all players busy, round-robin steal oldest
	if player == null:
		player = sfx_players[next_player_idx]
		next_player_idx = (next_player_idx + 1) % POOL_SIZE
	
	player.stream = stream
	# Add slight subtle pitch variation (+/- 3%) for organic acoustic feel
	player.pitch_scale = clampf(pitch_scale * randf_range(0.97, 1.03), 0.5, 2.0)
	var vol_db := linear_to_db(clampf(sfx_volume, 0.01, 1.0)) + volume_offset_db
	player.volume_db = vol_db
	player.play()
	return player

func play_sfx_at_pos(sfx_name: String, listener_pos: Vector2, emitter_pos: Vector2, max_dist: float = 900.0) -> AudioStreamPlayer:
	if not sfx_enabled:
		return null
	var dist := listener_pos.distance_to(emitter_pos)
	if dist > max_dist:
		return null
	var falloff := clampf(1.0 - (dist / max_dist), 0.0, 1.0)
	var vol_db := linear_to_db(clampf(falloff, 0.01, 1.0))
	return play_sfx(sfx_name, 1.0, vol_db)

func play_music(track_name: String) -> void:
	if not music_streams.has(track_name):
		return
	if current_music_track == track_name and is_instance_valid(music_player) and music_player.playing:
		return
	
	current_music_track = track_name
	if not is_instance_valid(music_player):
		return
	
	var stream: AudioStream = music_streams[track_name]
	music_player.stream = stream
	music_player.volume_db = linear_to_db(clampf(music_volume, 0.01, 1.0))
	if music_enabled:
		music_player.play()

func stop_music() -> void:
	current_music_track = ""
	if is_instance_valid(music_player) and music_player.playing:
		music_player.stop()

func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	if not sfx_enabled:
		for p in sfx_players:
			if p.playing:
				p.stop()
	save_audio_settings()
	sfx_setting_changed.emit(sfx_enabled)

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if is_instance_valid(music_player):
		if not music_enabled and music_player.playing:
			music_player.stop()
		elif music_enabled and not music_player.playing and not current_music_track.is_empty():
			if music_streams.has(current_music_track):
				music_player.stream = music_streams[current_music_track]
				music_player.volume_db = linear_to_db(clampf(music_volume, 0.01, 1.0))
				music_player.play()
	save_audio_settings()
	music_setting_changed.emit(music_enabled)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	save_audio_settings()

func set_music_volume(vol: float) -> void:
	music_volume = clampf(vol, 0.0, 1.0)
	if is_instance_valid(music_player):
		music_player.volume_db = linear_to_db(clampf(music_volume, 0.01, 1.0))
	save_audio_settings()

func save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://audio.cfg")
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save("user://audio.cfg")
	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.sfx_enabled = sfx_enabled
		gs.music_enabled = music_enabled
		gs.save_progress()

func load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load("user://audio.cfg")
	if err == OK:
		sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", true))
		music_enabled = bool(cfg.get_value("audio", "music_enabled", true))
		sfx_volume = float(cfg.get_value("audio", "sfx_volume", 1.0))
		music_volume = float(cfg.get_value("audio", "music_volume", 0.8))
	else:
		var gs := get_node_or_null("/root/GameState")
		if gs:
			sfx_enabled = bool(gs.sfx_enabled)
			music_enabled = bool(gs.music_enabled)

func _load_wav_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStream:
			return res
	
	if not FileAccess.file_exists(path):
		return null
	
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	
	var buffer := file.get_buffer(file.get_length())
	file.close()
	
	if buffer.size() < 44:
		return null
	
	var s_rate := buffer.decode_u32(24)
	var bits_per_sample := buffer.decode_u16(34)
	var data_size := buffer.decode_u32(40)
	if data_size == 0 or 44 + data_size > buffer.size():
		data_size = buffer.size() - 44
	var pcm_data := buffer.slice(44, 44 + data_size)
	
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits_per_sample == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = s_rate
	stream.stereo = false
	stream.data = pcm_data
	if path.contains("ambient_"):
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(float(data_size) / (2.0 if bits_per_sample == 16 else 1.0))
	return stream

