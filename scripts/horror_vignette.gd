extends Control

var low_health_ratio: float = 1.0
var pulse_time: float = 0.0
var bite_flash_alpha: float = 0.0
var last_bite_dir: Vector2 = Vector2.RIGHT

# POV blood splatters & dripping streaks on the screen lens when bitten
var pov_blood_drops: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

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
			# Viscous blood slowly drips down the screen glass
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
		# Bias splatters toward the screen edge where the bite came from, plus some across the lens
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
	
	# Cap active lens drops for mobile performance
	while pov_blood_drops.size() > 36:
		pov_blood_drops.remove_at(0)
	
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	# 1. Dark atmospheric horror border framing & corner shadows
	var border_col := Color(0.01, 0.01, 0.02, 0.58)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 34)), border_col, true)
	draw_rect(Rect2(Vector2(0, vp.y - 34), Vector2(vp.x, 34)), border_col, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(38, vp.y)), border_col, true)
	draw_rect(Rect2(Vector2(vp.x - 38, 0), Vector2(38, vp.y)), border_col, true)
	
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
		
		# Main lens blood blotch
		draw_circle(p, r, base_col)
		draw_circle(p + Vector2(-r * 0.2, -r * 0.15), r * 0.65, core_col)
		
		# Satellite micro-splatter droplets on lens
		var subs: Array = drop["sub_dots"]
		for sv in subs:
			var v3: Vector3 = sv
			draw_circle(p + Vector2(v3.x, v3.y), v3.z, base_col)
		
		# Gravity-driven dripping blood trail down the screen
		if drip > 2.0:
			var drip_end := p + Vector2(0.0, r * 0.5 + drip)
			draw_line(p + Vector2(0.0, r * 0.3), drip_end, base_col, maxf(3.0, r * 0.26), true)
			draw_circle(drip_end, maxf(3.5, r * 0.22), core_col)
		
		# Visceral 3-claw / teeth slash across lens on primary bite drop
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
