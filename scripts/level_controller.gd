extends Node

signal level_won(level_id: int, score: int, kills: int, stars: int)
signal level_lost(level_id: int, score: int, kills: int, reason: String)

@export var level_id: int = 1
@export var two_star_score: int = 220
@export var three_star_score: int = 420

var is_resolved: bool = false
var current_score: int = 0
var current_kills: int = 0
var bitten_count: int = 0
var night_mode_active: bool = false
var last_unlocked_achievements: Array[String] = []

func reset_state(p_level_id: int = 1) -> void:
	level_id = p_level_id
	is_resolved = false
	current_score = 0
	current_kills = 0
	bitten_count = 0
	last_unlocked_achievements.clear()

func record_kill(points: int) -> void:
	if is_resolved:
		return
	current_kills += 1
	current_score += max(0, points)

func record_player_bitten() -> void:
	if is_resolved:
		return
	bitten_count += 1

func calculate_stars(score: int, health_ratio: float = 1.0) -> int:
	if score >= three_star_score and health_ratio >= 0.45:
		return 3
	elif score >= two_star_score or health_ratio >= 0.65:
		return 2
	return 1

func on_all_waves_completed(health_ratio: float = 1.0) -> void:
	if is_resolved:
		return
	
	# Multiplayer safety: only authority resolves final match state
	if multiplayer and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	is_resolved = true
	var stars := calculate_stars(current_score, health_ratio)
	var without_bit := (bitten_count == 0)
	
	# Save campaign progression & evaluate sector achievements in offline mode
	var gs := get_node_or_null("/root/GameState")
	if gs and gs.has_method("complete_level"):
		if str(gs.get("selected_mode")) != "online":
			last_unlocked_achievements = gs.complete_level(level_id, current_score, stars, without_bit, night_mode_active)
	
	level_won.emit(level_id, current_score, current_kills, stars)

func on_all_players_dead(reason: String = "OUTPOST OVERRUN") -> void:
	if is_resolved:
		return
	
	if multiplayer and multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	is_resolved = true
	level_lost.emit(level_id, current_score, current_kills, reason)
