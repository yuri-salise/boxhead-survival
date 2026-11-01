extends SceneTree

func _init():
	print("Generating procedural apocalyptic audio assets for Dead Block: Survival...")
	var sample_rate := 22050
	
	# 1. SFX Pistol (Sharp snap + low punch)
	_save_wav("res://assets/audio/sfx_pistol.wav", _gen_gunshot(0.18, 480.0, 110.0, 0.85, sample_rate), sample_rate)
	
	# 2. SFX Shotgun (Heavy boom + wide noise blast)
	_save_wav("res://assets/audio/sfx_shotgun.wav", _gen_shotgun(0.38, 220.0, sample_rate), sample_rate)
	
	# 3. SFX SMG (Rapid high-pitch crack)
	_save_wav("res://assets/audio/sfx_smg.wav", _gen_gunshot(0.12, 620.0, 180.0, 0.70, sample_rate), sample_rate)
	
	# 4. SFX Assault Rifle (Military 5.56mm punch)
	_save_wav("res://assets/audio/sfx_rifle.wav", _gen_gunshot(0.22, 540.0, 130.0, 0.90, sample_rate), sample_rate)
	
	# 5. SFX Magnum (Heavy cannon blast)
	_save_wav("res://assets/audio/sfx_magnum.wav", _gen_gunshot(0.42, 340.0, 75.0, 1.0, sample_rate), sample_rate)
	
	# 6. SFX Dry Fire (Metallic mechanical click)
	_save_wav("res://assets/audio/sfx_dry_fire.wav", _gen_click(0.06, 1800.0, sample_rate), sample_rate)
	
	# 7. SFX Zombie Groan (Throaty growl)
	_save_wav("res://assets/audio/sfx_groan.wav", _gen_groan(0.65, 115.0, sample_rate), sample_rate)
	
	# 8. SFX Zombie Hit (Wet meaty impact)
	_save_wav("res://assets/audio/sfx_zombie_hit.wav", _gen_impact(0.15, 160.0, sample_rate), sample_rate)
	
	# 9. SFX Zombie Death (Squishy bone snap)
	_save_wav("res://assets/audio/sfx_zombie_death.wav", _gen_squish(0.32, 130.0, sample_rate), sample_rate)
	
	# 10. SFX Bite (Sharp teeth snap)
	_save_wav("res://assets/audio/sfx_bite.wav", _gen_bite(0.20, sample_rate), sample_rate)
	
	# 11. SFX Boomer Blast (Bile explosion)
	_save_wav("res://assets/audio/sfx_boomer.wav", _gen_explosion(0.60, 90.0, sample_rate), sample_rate)
	
	# 12. SFX Witch Scream (Piercing shriek)
	_save_wav("res://assets/audio/sfx_witch.wav", _gen_witch(0.85, sample_rate), sample_rate)
	
	# 13. SFX Player Hurt (Pained grunt)
	_save_wav("res://assets/audio/sfx_player_hurt.wav", _gen_grunt(0.24, 180.0, sample_rate), sample_rate)
	
	# 14. SFX Dash (Aerodynamic whoosh)
	_save_wav("res://assets/audio/sfx_dash.wav", _gen_whoosh(0.22, sample_rate), sample_rate)
	
	# 15. SFX Explosion (Frag grenade detonation)
	_save_wav("res://assets/audio/sfx_explosion.wav", _gen_explosion(0.75, 70.0, sample_rate), sample_rate)
	
	# 16. SFX Pickup (Chime grab)
	_save_wav("res://assets/audio/sfx_pickup.wav", _gen_chime(0.25, sample_rate), sample_rate)
	
	# 17. SFX Wave Start (Quarantine alert horn)
	_save_wav("res://assets/audio/sfx_wave_start.wav", _gen_horn(0.80, 220.0, sample_rate), sample_rate)
	
	# 18. SFX Victory (Major chord brass swell)
	_save_wav("res://assets/audio/sfx_victory.wav", _gen_chord([261.6, 329.6, 392.0, 523.2], 1.2, sample_rate), sample_rate)
	
	# 19. SFX Defeat (Somber minor descent)
	_save_wav("res://assets/audio/sfx_defeat.wav", _gen_chord([196.0, 233.1, 293.7, 392.0], 1.5, sample_rate), sample_rate)
	
	# 20. Ambient Menu (Desolate horror atmospheric drone, 6s seamless loop)
	_save_wav("res://assets/audio/ambient_menu.wav", _gen_ambient_menu(6.0, sample_rate), sample_rate)
	
	# 21. Ambient Combat (Rhythmic tension heartbeat + gritty industrial drone, 6s seamless loop at 120 BPM)
	_save_wav("res://assets/audio/ambient_combat.wav", _gen_ambient_combat(6.0, sample_rate), sample_rate)
	
	print("All Audio Assets generated and saved successfully!")
	quit(0)

func _gen_gunshot(dur: float, start_f: float, end_f: float, intensity: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := exp(-progress * 14.0)
		var freq := lerpf(start_f, end_f, progress)
		var tone := sin(t * freq * TAU)
		var noise := randf_range(-1.0, 1.0)
		var sample := clampf((tone * 0.45 + noise * 0.55) * env * intensity, -1.0, 1.0)
		var s16 := int(clampf(sample * 32000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_shotgun(dur: float, bass_f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := exp(-progress * 9.5)
		var sub := sin(t * bass_f * TAU * exp(-progress * 4.0))
		var noise := randf_range(-1.0, 1.0)
		var pump_t := clampf((t - 0.22) * 20.0, 0.0, 1.0)
		var pump_mech := sin((t - 0.22) * 1200.0) * exp(-pump_t * 6.0) if t > 0.22 else 0.0
		var sample := clampf((sub * 0.50 + noise * 0.50 + pump_mech * 0.35) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 32000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_click(dur: float, freq: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 90.0)
		var sample := sin(t * freq * TAU) * env
		var s16 := int(clampf(sample * 28000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_groan(dur: float, base_f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := sin(progress * PI)
		var mod_f := base_f + sin(t * 18.0) * 25.0
		var vocal := sin(t * mod_f * TAU) + 0.4 * sin(t * mod_f * 2.1 * TAU)
		var rasp := randf_range(-0.35, 0.35)
		var sample := clampf((vocal * 0.65 + rasp) * env * 0.82, -1.0, 1.0)
		var s16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_impact(dur: float, f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 26.0)
		var thud := sin(t * f * TAU)
		var wet := randf_range(-0.6, 0.6)
		var sample := clampf((thud * 0.55 + wet * 0.45) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_squish(dur: float, f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 14.0)
		var snap := randf_range(-0.85, 0.85) if t < 0.04 else randf_range(-0.3, 0.3)
		var sub := sin(t * f * TAU)
		var sample := clampf((sub * 0.4 + snap * 0.6) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 31000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_bite(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 22.0)
		var snap := (randf_range(-1.0, 1.0) if t < 0.05 else randf_range(-0.4, 0.4))
		var tear := sin(t * 880.0 * TAU) * 0.3
		var sample := clampf((snap * 0.7 + tear) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 31000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_witch(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := sin(progress * PI)
		var f := 1450.0 + sin(t * 32.0) * 350.0
		var shriek := sin(t * f * TAU) + 0.5 * sin(t * f * 1.5 * TAU)
		var sample := clampf((shriek * 0.7 + randf_range(-0.3, 0.3)) * env * 0.85, -1.0, 1.0)
		var s16 := int(clampf(sample * 29000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_grunt(dur: float, f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 18.0)
		var tone := sin(t * (f - t * 80.0) * TAU)
		var sample := clampf((tone * 0.65 + randf_range(-0.3, 0.3)) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_whoosh(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := sin(progress * PI)
		var noise := randf_range(-1.0, 1.0)
		var sample := noise * env * 0.75
		var s16 := int(clampf(sample * 28000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_explosion(dur: float, base_f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 6.5)
		var sub := sin(t * (base_f - t * 25.0) * TAU)
		var noise := randf_range(-1.0, 1.0)
		var sample := clampf((sub * 0.60 + noise * 0.40) * env, -1.0, 1.0)
		var s16 := int(clampf(sample * 32000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_chime(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var env := exp(-t * 12.0)
		var tone := sin(t * 880.0 * TAU) + 0.6 * sin(t * 1320.0 * TAU) + 0.3 * sin(t * 1760.0 * TAU)
		var sample := clampf(tone * env * 0.5, -1.0, 1.0)
		var s16 := int(clampf(sample * 28000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_horn(dur: float, f: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := sin(progress * PI)
		var tone := sin(t * f * TAU) + 0.4 * sin(t * f * 2.0 * TAU) + 0.2 * sin(t * f * 3.0 * TAU)
		var sample := clampf(tone * env * 0.8, -1.0, 1.0)
		var s16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_chord(freqs: Array, dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		var progress := t / dur
		var env := sin(progress * PI) * exp(-progress * 1.5)
		var sum := 0.0
		for f in freqs:
			sum += sin(t * float(f) * TAU)
		var sample := clampf((sum / float(freqs.size())) * env * 0.85, -1.0, 1.0)
		var s16 := int(clampf(sample * 30000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_ambient_menu(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		# Low resonant drone (55Hz and 82.5Hz - dark and hollow)
		var bass := sin(t * 55.0 * TAU) * 0.45 + sin(t * 82.5 * TAU) * 0.25
		# Slow breathing tremolo modulation (0.33 Hz = 2 cycles in 6s)
		var mod := 0.70 + 0.30 * sin(t * (TAU / 3.0))
		# High eerie metallic resonance (520Hz + slight dissonance)
		var metal := sin(t * 520.0 * TAU) * 0.08 + sin(t * 524.0 * TAU) * 0.06
		# Distant dark rumble noise filtered
		var rumble := sin(t * 32.0 * TAU) * 0.20
		# Gentle tape hiss/crackle
		var hiss := randf_range(-0.025, 0.025)
		
		var edge_fade := 1.0
		var fade_samples := int(0.08 * s_rate)
		if i < fade_samples:
			edge_fade = float(i) / float(fade_samples)
		elif i > total_samples - fade_samples:
			edge_fade = float(total_samples - i) / float(fade_samples)
		
		var sample := clampf((bass * mod + metal * mod + rumble + hiss) * edge_fade * 0.75, -1.0, 1.0)
		var s16 := int(clampf(sample * 28000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _gen_ambient_combat(dur: float, s_rate: int) -> PackedByteArray:
	var total_samples := int(dur * s_rate)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	var beat_period := 0.5
	for i in range(total_samples):
		var t := float(i) / float(s_rate)
		# 1. Driving Heartbeat / Sub-bass kick (0.5s intervals)
		var beat_t := fmod(t, beat_period)
		var kick_env := exp(-beat_t * 14.0)
		var kick := sin(beat_t * (70.0 - beat_t * 30.0) * TAU) * kick_env * 0.55
		
		# 2. Industrial Bassline Drone (65.4 Hz C2 with harmonic distortion)
		var bass_raw := sin(t * 65.41 * TAU) + 0.35 * sin(t * 130.82 * TAU)
		var bass_drive := clampf(bass_raw * 1.5, -1.0, 1.0) * 0.32
		
		# 3. High Suspense Strings (Minor dissonance: 220Hz + 261.6Hz + 311.1Hz)
		var string_pulse := 0.6 + 0.4 * sin(t * (TAU / 1.5))
		var strings := (sin(t * 220.0 * TAU) * 0.06 + sin(t * 261.63 * TAU) * 0.06 + sin(t * 311.13 * TAU) * 0.05) * string_pulse
		
		# 4. Background tension noise pulse
		var noise := randf_range(-0.04, 0.04) * kick_env
		
		var edge_fade := 1.0
		var fade_samples := int(0.05 * s_rate)
		if i < fade_samples:
			edge_fade = float(i) / float(fade_samples)
		elif i > total_samples - fade_samples:
			edge_fade = float(total_samples - i) / float(fade_samples)
		
		var sample := clampf((kick + bass_drive + strings + noise) * edge_fade * 0.85, -1.0, 1.0)
		var s16 := int(clampf(sample * 29000.0, -32768.0, 32767.0))
		bytes.encode_s16(i * 2, s16)
	return bytes

func _save_wav(path: String, pcm_data: PackedByteArray, s_rate: int) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		printerr("Cannot open file for writing: ", path)
		return
	
	var data_size := pcm_data.size()
	var chunk_size := 36 + data_size
	
	# RIFF header
	file.store_string("RIFF")
	file.store_32(chunk_size)
	file.store_string("WAVE")
	
	# fmt chunk
	file.store_string("fmt ")
	file.store_32(16) # Subchunk1Size for PCM
	file.store_16(1)  # AudioFormat (1 = PCM)
	file.store_16(1)  # NumChannels (1 = Mono)
	file.store_32(s_rate) # SampleRate
	file.store_32(s_rate * 2) # ByteRate (SampleRate * NumChannels * BitsPerSample / 8)
	file.store_16(2)  # BlockAlign (NumChannels * BitsPerSample / 8)
	file.store_16(16) # BitsPerSample
	
	# data chunk
	file.store_string("data")
	file.store_32(data_size)
	file.store_buffer(pcm_data)
	file.close()
	print("Saved WAV: ", path, " (", data_size, " bytes)")
