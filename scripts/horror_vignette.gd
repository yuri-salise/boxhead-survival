extends Control

var low_health_ratio: float = 1.0
var pulse_time: float = 0.0
var bite_flash_alpha: float = 0.0
var last_bite_dir: Vector2 = Vector2.RIGHT

# Continuous Gradual Day/Dusk/Night Cycle (0.0 = Daylight, 0.5 = Dusk/Dawn, 1.0 = Pitch-Black Night)
var night_factor: float = 0.0
var night_mode_enabled: bool = false
var is_dusk_phase: bool = true
var flashlight_screen_pos: Vector2 = Vector2(640.0, 360.0)
var flashlight_angle: float = 0.0
var flashlight_occluders: Array = []
var flashlight_player_world_pos: Vector2 = Vector2.ZERO

# POV blood splatters & dripping streaks on the screen lens when bitten
var pov_blood_drops: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func set_night_factor(factor: float, dusk_warming: bool = true) -> void:
	night_factor = clampf(factor, 0.0, 1.0)
	night_mode_enabled = (night_factor >= 0.45)
	is_dusk_phase = dusk_warming
	queue_redraw()

func set_night_mode(enabled: bool) -> void:
	set_night_factor(1.0 if enabled else 0.0, true)

func update_flashlight_transform(screen_pos: Vector2, angle_rad: float, occluders: Array = [], player_world_pos: Vector2 = Vector2.ZERO) -> void:
	flashlight_screen_pos = screen_pos
	flashlight_angle = angle_rad
	flashlight_occluders = occluders
	flashlight_player_world_pos = player_world_pos
	if night_factor > 0.01:
		queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	if bite_flash_alpha > 0.0:
		bite_flash_alpha = maxf(0.0, bite_flash_alpha - delta * 2.2)
	
	for i in range(pov_blood_drops.size() - 1, -1, -1):
		var drop: Dictionary = pov_blood_drops[i]
		drop["age"] = float(drop["age"]) + delta
		if float(drop["age"]) >= float(drop["lifetime"]):
			pov_blood_drops.remove_at(i)
		else:
			var cur_drip: float = float(drop["drip_len"])
			var max_drip: float = float(drop["max_drip"])
			if cur_drip < max_drip:
				drop["drip_len"] = minf(max_drip, cur_drip + float(drop["drip_speed"]) * delta)
	
	queue_redraw()

func set_health_ratio(ratio: float) -> void:
	low_health_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func trigger_bite_pov_splatter(hit_dir: Vector2 = Vector2.ZERO, damage: float = 15.0) -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	bite_flash_alpha = clampf(bite_flash_alpha + 0.55, 0.0, 0.85)
	if hit_dir != Vector2.ZERO:
		last_bite_dir = hit_dir.normalized()
	else:
		last_bite_dir = Vector2.RIGHT.rotated(randf() * TAU)
	
	var count := clampi(int(6 + damage * 0.35), 7, 16)
	var center := vp * 0.5
	
	for i in range(count):
		var edge_bias := -last_bite_dir
		var pos: Vector2
		if i < int(count * 0.65) and edge_bias != Vector2.ZERO:
			var spread_ang := edge_bias.angle() + randf_range(-0.95, 0.95)
			var rx := vp.x * randf_range(0.28, 0.47)
			var ry := vp.y * randf_range(0.26, 0.46)
			pos = center + Vector2(cos(spread_ang) * rx, sin(spread_ang) * ry)
		else:
			pos = Vector2(randf_range(80.0, vp.x - 80.0), randf_range(65.0, vp.y - 95.0))
		
		var sub_dots: Array[Vector3] = []
		for s in range(randi_range(3, 6)):
			var sa := randf() * TAU
			var sd := randf_range(12.0, 36.0)
			sub_dots.append(Vector3(cos(sa) * sd, sin(sa) * sd, randf_range(2.5, 7.5)))
		
		pov_blood_drops.append({
			"pos": pos,
			"radius": randf_range(14.0, 34.0),
			"drip_len": 0.0,
			"max_drip": randf_range(42.0, 135.0),
			"drip_speed": randf_range(24.0, 52.0),
			"age": 0.0,
			"lifetime": randf_range(3.2, 4.8),
			"dark": (i % 2 == 0),
			"is_claw": (i == 0),
			"sub_dots": sub_dots
		})
	
	while pov_blood_drops.size() > 36:
		pov_blood_drops.remove_at(0)
	
	queue_redraw()

func _draw_gradual_night_darkness(vp: Vector2) -> void:
	# 1. Atmospheric Sunset/Dusk (warm amber-crimson) or Dawn (cold slate-blue) glaze during twilight transition
	var twilight_bell := sin(clampf(night_factor, 0.0, 1.0) * PI)
	if twilight_bell > 0.02:
		var tint_col := Color(0.26, 0.09, 0.03, twilight_bell * 0.22) if is_dusk_phase else Color(0.06, 0.12, 0.24, twilight_bell * 0.20)
		draw_rect(Rect2(Vector2.ZERO, vp), tint_col, true)
	
	# 2. Gradual darkness mask outside the player's directional flashlight cone
	var origin := flashlight_screen_pos
	var cone_half := 0.44 # ~50-degree tactical flashlight cone
	var inner_r := lerpf(90.0, 52.0, night_factor) # Ambient awareness ring shrinks smoothly as night deepens
	var beam_len := 430.0
	var outer_r := 1600.0
	var dark_alpha := 0.96 * night_factor
	var dark_col := Color(0.01, 0.01, 0.02, dark_alpha)
	var penumbra_col := Color(0.01, 0.01, 0.02, 0.56 * night_factor)
	
	# 310-degree darkness shrouding everything outside the flashlight beam cone
	var start_a := flashlight_angle + cone_half
	var end_a := flashlight_angle + TAU - cone_half
	var dark_steps := 36
	for i in range(dark_steps):
		var a0 := lerpf(start_a, end_a, float(i) / float(dark_steps))
		var a1 := lerpf(start_a, end_a, float(i + 1) / float(dark_steps))
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		var quad := PackedVector2Array([
			origin + d0 * inner_r,
			origin + d0 * outer_r,
			origin + d1 * outer_r,
			origin + d1 * inner_r
		])
		draw_colored_polygon(quad, dark_col)
	
	# Darkness beyond the tip of the flashlight beam (distance > beam_len)
	var cone_start := flashlight_angle - cone_half
	var cone_end := flashlight_angle + cone_half
	var cone_steps := 10
	for i in range(cone_steps):
		var a0 := lerpf(cone_start, cone_end, float(i) / float(cone_steps))
		var a1 := lerpf(cone_start, cone_end, float(i + 1) / float(cone_steps))
		var d0 := Vector2.from_angle(a0)
		var d1 := Vector2.from_angle(a1)
		var cap_quad := PackedVector2Array([
			origin + d0 * beam_len,
			origin + d0 * outer_r,
			origin + d1 * outer_r,
			origin + d1 * beam_len
		])
		draw_colored_polygon(cap_quad, dark_col)
		
		var tip_fade_quad := PackedVector2Array([
			origin + d0 * (beam_len * 0.78),
			origin + d0 * beam_len,
			origin + d1 * beam_len,
			origin + d1 * (beam_len * 0.78)
		])
		draw_colored_polygon(tip_fade_quad, penumbra_col)
	
	# Soft penumbra feather wedges along left and right beam edges
	var feather := 0.11
	var left_outer := Vector2.from_angle(cone_start)
	var left_inner := Vector2.from_angle(cone_start + feather)
	draw_colored_polygon(PackedVector2Array([
		origin + left_outer * inner_r,
		origin + left_outer * beam_len,
		origin + left_inner * beam_len,
		origin + left_inner * inner_r
	]), penumbra_col)
	
	var right_inner := Vector2.from_angle(cone_end - feather)
	var right_outer := Vector2.from_angle(cone_end)
	draw_colored_polygon(PackedVector2Array([
		origin + right_inner * inner_r,
		origin + right_inner * beam_len,
		origin + right_outer * beam_len,
		origin + right_outer * inner_r
	]), penumbra_col)
	
	# Warm halogen flashlight beam glow inside cone (brightens as night deepens)
	var mid_dir := Vector2.from_angle(flashlight_angle)
	draw_colored_polygon(PackedVector2Array([
		origin + mid_dir * 16.0,
		origin + left_inner * (beam_len * 0.85),
		origin + mid_dir * (beam_len * 0.92),
		origin + right_inner * (beam_len * 0.85)
	]), Color(1.0, 0.95, 0.78, 0.085 * night_factor))
	
	# 3. Dynamic Obstacle Shadows: Solid obstacles inside the flashlight beam block light and cast realistic shadows
	if night_factor > 0.05 and flashlight_occluders.size() > 0:
		for obs in flashlight_occluders:
			var world_pos: Vector2 = obs["world_pos"]
			var radius: float = float(obs.get("radius", 16.0))
			var obs_screen_pos: Vector2 = flashlight_screen_pos + (world_pos - flashlight_player_world_pos)
			
			var to_obs: Vector2 = obs_screen_pos - origin
			var dist := to_obs.length()
			if dist < radius or dist > (beam_len + 60.0):
				continue
			
			var ang := to_obs.angle()
			var diff := absf(wrapf(ang - flashlight_angle, -PI, PI))
			var angular_radius := clampf(atan2(radius, dist), 0.05, 0.60)
			
			if diff < (cone_half + angular_radius):
				var a_left := ang - angular_radius
				var a_right := ang + angular_radius
				var dir_left := Vector2.from_angle(a_left)
				var dir_right := Vector2.from_angle(a_right)
				
				var perp := Vector2(-to_obs.y, to_obs.x).normalized()
				var p_near_left := obs_screen_pos - perp * (radius * 0.85)
				var p_near_right := obs_screen_pos + perp * (radius * 0.85)
				
				var shadow_reach := outer_r
				var p_far_left := obs_screen_pos + dir_left * shadow_reach
				var p_far_right := obs_screen_pos + dir_right * shadow_reach
				
				# Main dark shadow polygon (blocks light completely behind the obstacle)
				var shadow_poly := PackedVector2Array([p_near_left, p_far_left, p_far_right, p_near_right])
				draw_colored_polygon(shadow_poly, dark_col)
				
				# Soft penumbra edges for cinematic realism
				var pen_feather := 0.05
				var dir_pen_left := Vector2.from_angle(a_left - pen_feather)
				var dir_pen_right := Vector2.from_angle(a_right + pen_feather)
				
				draw_colored_polygon(PackedVector2Array([
					p_near_left,
					obs_screen_pos + dir_pen_left * shadow_reach,
					p_far_left
				]), penumbra_col)
				
				draw_colored_polygon(PackedVector2Array([
					p_near_right,
					p_far_right,
					obs_screen_pos + dir_pen_right * shadow_reach
				]), penumbra_col)

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	# 0. Gradual Time-Based Day/Dusk/Night Cycle & Flashlight Cone
	if night_factor > 0.01:
		_draw_gradual_night_darkness(vp)
	
	# 1. Dark atmospheric horror border framing & corner shadows
	var border_col := Color(0.01, 0.01, 0.02, 0.58)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 34)), border_col, true)
	draw_rect(Rect2(0, vp.y - 34, vp.x, 34), border_col, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(38, vp.y)), border_col, true)
	draw_rect(Rect2(vp.x - 38, 0, 38, vp.y), border_col, true)
	
	# 2. Immediate crimson bite shockwave border flash
	if bite_flash_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.72, 0.03, 0.04, bite_flash_alpha * 0.42), false, 54.0)
		draw_rect(Rect2(Vector2(18, 18), vp - Vector2(36, 36)), Color(0.52, 0.02, 0.02, bite_flash_alpha * 0.25), false, 28.0)
	
	# 3. POV Blood Splatters, Claw Gashes & Dripping Streaks on Camera Lens
	for drop in pov_blood_drops:
		var age: float = float(drop["age"])
		var life: float = float(drop["lifetime"])
		var fade := clampf(1.0 - maxf(0.0, (age - life * 0.55) / (life * 0.45)), 0.0, 1.0)
		var p: Vector2 = drop["pos"]
		var r: float = float(drop["radius"])
		var drip: float = float(drop["drip_len"])
		var base_col := Color(0.46, 0.02, 0.03, 0.80 * fade) if drop["dark"] else Color(0.68, 0.05, 0.06, 0.76 * fade)
		var core_col := Color(0.28, 0.01, 0.02, 0.88 * fade)
		
		draw_circle(p, r, base_col)
		draw_circle(p + Vector2(-r * 0.2, -r * 0.15), r * 0.65, core_col)
		
		var subs: Array = drop["sub_dots"]
		for sv in subs:
			var v3: Vector3 = sv
			draw_circle(p + Vector2(v3.x, v3.y), v3.z, base_col)
		
		if drip > 2.0:
			var drip_end := p + Vector2(0.0, r * 0.5 + drip)
			draw_line(p + Vector2(0.0, r * 0.3), drip_end, base_col, maxf(3.0, r * 0.26), true)
			draw_circle(drip_end, maxf(3.5, r * 0.22), core_col)
		
		if drop["is_claw"]:
			for c_idx in range(-1, 2):
				var offset := Vector2(c_idx * 16.0, c_idx * 6.0)
				draw_line(p + offset + Vector2(-34, -28), p + offset + Vector2(34, 28), Color(0.78, 0.04, 0.04, 0.85 * fade), 4.5, true)
	
	# 4. Low-health blood heartbeat vignette when HP < 40%
	if low_health_ratio < 0.40:
		var intensity := (0.40 - low_health_ratio) / 0.40
		var beat := 0.55 + 0.45 * sin(pulse_time * 7.5)
		var red_alpha := intensity * beat * 0.38
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.58, 0.03, 0.04, red_alpha), false, 40.0)
