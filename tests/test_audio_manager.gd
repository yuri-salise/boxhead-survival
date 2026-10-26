extends SceneTree

func _init():
	var runner = AudioManagerTestRunner.new()
	root.add_child.call_deferred(runner)

class AudioManagerTestRunner extends Node:
	func _ready():
		print("Starting Task 12 & 16: AudioManager Autoload & Audio Playback Tests...")
		var AudioMgrScript = load("res://autoload/audio_manager.gd")
		assert(AudioMgrScript != null, "Failed to load res://autoload/audio_manager.gd")
		
		var audio_mgr = AudioMgrScript.new()
		add_child(audio_mgr)
		
		# 1. Verify audio streams loaded
		var test_sfx_keys := [
			"sfx_pistol", "sfx_shotgun", "sfx_smg", "sfx_rifle", "sfx_magnum", "sfx_dry_fire",
			"sfx_groan", "sfx_zombie_hit", "sfx_zombie_death", "sfx_bite", "sfx_boomer", "sfx_witch",
			"sfx_player_hurt", "sfx_dash", "sfx_explosion", "sfx_pickup", "sfx_wave_start", "sfx_victory", "sfx_defeat"
		]
		for key in test_sfx_keys:
			assert(audio_mgr.has_sfx(key) == true, "AudioManager must have sound stream for: " + key)
		print("Audio Stream Catalog Loading: PASS (19 sound streams loaded)")
		
		# 2. Test play_sfx playback from pool
		var player = audio_mgr.play_sfx("sfx_pistol", 1.0, 0.0)
		assert(player != null, "play_sfx should return an active AudioStreamPlayer from the pool")
		assert(player.stream != null, "Active player must have an assigned AudioStream")
		print("AudioStreamPlayer Pool Dispatch: PASS")
		
		# 3. Test volume and mute toggles
		assert(audio_mgr.sfx_enabled == true, "SFX starts enabled by default")
		audio_mgr.set_sfx_enabled(false)
		assert(audio_mgr.sfx_enabled == false, "set_sfx_enabled(false) must update state")
		var muted_player = audio_mgr.play_sfx("sfx_pistol")
		assert(muted_player == null, "play_sfx should return null when SFX is disabled")
		
		audio_mgr.set_sfx_enabled(true)
		assert(audio_mgr.sfx_enabled == true, "set_sfx_enabled(true) must restore playback")
		var restored_player = audio_mgr.play_sfx("sfx_pistol")
		assert(restored_player != null, "play_sfx should resume working when SFX is enabled")
		print("SFX Enable / Disable Mute: PASS")
		
		# 4. Test music mute toggle
		audio_mgr.set_music_enabled(false)
		assert(audio_mgr.music_enabled == false, "set_music_enabled(false) must update state")
		audio_mgr.set_music_enabled(true)
		assert(audio_mgr.music_enabled == true, "set_music_enabled(true) must restore state")
		print("Music Enable / Disable: PASS")
		
		audio_mgr.queue_free()
		print("ALL AUDIO MANAGER TESTS PASSED!")
		get_tree().quit(0)
