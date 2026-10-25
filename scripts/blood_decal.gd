extends Node2D

enum SplatterType {
	ARTERIAL_SPRAY,
	COAGULATED_POOL,
	STARBURST,
	FINE_MIST,
	SMEAR_STREAK,
	HEAVY_GORE,
	BOOMER_BILE,
	SCORCH_CRATER
}

var splatter_type: int = SplatterType.ARTERIAL_SPRAY
var spray_direction: Vector2 = Vector2.RIGHT
var base_scale: float = 1.0
var seed_val: int = 0

# Precomputed shapes so redrawing is fast and deterministic
var blobs: Array[Dictionary] = []
var streaks: Array[Dictionary] = []
var flying_droplets: Array[Dictionary] = []
var splash_time: float = 0.0
var is_animating_splash: bool = true

func setup(p_pos: Vector2, p_dir: Vector2, p_type: int = -1, p_scale: float = 1.0, with_active_splash: bool = true) -> void:
	global_position = p_pos
	spray_direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU)
	base_scale = p_scale * randf_range(0.85, 1.25)
	seed_val = randi()
	
	if p_type < 0:
		# Pick a weighted random blood splatter variation
		var roll := randf()
		if roll < 0.25:
			splatter_type = SplatterType.ARTERIAL_SPRAY
		elif roll < 0.45:
			splatter_type = SplatterType.COAGULATED_POOL
		elif roll < 0.62:
			splatter_type = SplatterType.STARBURST
		elif roll < 0.78:
			splatter_type = SplatterType.FINE_MIST
		elif roll < 0.90:
			splatter_type = SplatterType.SMEAR_STREAK
		else:
			splatter_type = SplatterType.HEAVY_GORE
	else:
		splatter_type = p_type
	
	_generate_splatter_geometry(with_active_splash)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_animating_splash:
		set_process(false)
		return
	
	splash_time += delta
	var active_count := 0
	for drop in flying_droplets:
		if splash_time < drop["duration"]:
			active_count += 1
			drop["pos"] += drop["vel"] * delta
			drop["vel"] = drop["vel"].move_toward(Vector2.ZERO, 420.0 * delta)
	
	queue_redraw()
	if active_count == 0 or splash_time >= 0.45:
		is_animating_splash = false
		flying_droplets.clear()
		queue_redraw()
		set_process(false)

func _pick_blood_color(rng: RandomNumberGenerator, is_dark: bool = false) -> Color:
	var palettes: Array[Color] = [
		Color(0.48, 0.04, 0.05, 0.90), # Deep arterial red
		Color(0.35, 0.02, 0.03, 0.92), # Dark venous crimson
		Color(0.62, 0.07, 0.07, 0.85), # Fresh bright blood
		Color(0.26, 0.03, 0.04, 0.94), # Coagulated clot
		Color(0.42, 0.08, 0.05, 0.88)  # Rust-dried blood
	]
	var c: Color = palettes[rng.randi() % palettes.size()]
	if is_dark:
		c = c.darkened(0.32)
	return c

func _generate_splatter_geometry(with_active_splash: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	
	blobs.clear()
	streaks.clear()
	flying_droplets.clear()
	
	var base_angle := spray_direction.angle()
	
	match splatter_type:
		SplatterType.ARTERIAL_SPRAY:
			# Directional fan of droplets and streaks along bullet vector
			blobs.append({
				"pos": Vector2.ZERO,
				"radius": 8.0 * base_scale,
				"color": _pick_blood_color(rng, true)
			})
			for i in range(18):
				var ang := base_angle + rng.randf_range(-0.55, 0.55)
				var dist := rng.randf_range(6.0, 58.0) * base_scale
				var p := Vector2.from_angle(ang) * dist
				var r := rng.randf_range(2.0, 6.5) * base_scale * (1.0 - dist / (75.0 * base_scale))
				blobs.append({
					"pos": p,
					"radius": maxf(1.5, r),
					"color": _pick_blood_color(rng, i % 3 == 0)
				})
			for i in range(6):
				var ang := base_angle + rng.randf_range(-0.4, 0.4)
				var start_d := rng.randf_range(2.0, 15.0) * base_scale
				var len_d := rng.randf_range(12.0, 32.0) * base_scale
				streaks.append({
					"from": Vector2.from_angle(ang) * start_d,
					"to": Vector2.from_angle(ang) * (start_d + len_d),
					"width": rng.randf_range(1.5, 3.8) * base_scale,
					"color": _pick_blood_color(rng, false)
				})
				
		SplatterType.COAGULATED_POOL:
			# Thick overlapping dark crimson puddles
			for i in range(9):
				var offset := Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)) * base_scale
				blobs.append({
					"pos": offset,
					"radius": rng.randf_range(8.0, 18.0) * base_scale,
					"color": _pick_blood_color(rng, i < 5)
				})
			for i in range(12):
				var ang := rng.randf() * TAU
				var dist := rng.randf_range(16.0, 36.0) * base_scale
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(1.8, 4.5) * base_scale,
					"color": _pick_blood_color(rng, false)
				})
				
		SplatterType.STARBURST:
			# High-impact jagged radial burst
			blobs.append({
				"pos": Vector2.ZERO,
				"radius": 11.0 * base_scale,
				"color": _pick_blood_color(rng, true)
			})
			for i in range(12):
				var ang := (TAU / 12.0) * i + rng.randf_range(-0.2, 0.2)
				var len_d := rng.randf_range(16.0, 44.0) * base_scale
				streaks.append({
					"from": Vector2.ZERO,
					"to": Vector2.from_angle(ang) * len_d,
					"width": rng.randf_range(2.0, 4.5) * base_scale,
					"color": _pick_blood_color(rng, i % 2 == 0)
				})
				blobs.append({
					"pos": Vector2.from_angle(ang) * (len_d + rng.randf_range(3.0, 9.0) * base_scale),
					"radius": rng.randf_range(2.0, 4.0) * base_scale,
					"color": _pick_blood_color(rng, false)
				})
				
		SplatterType.FINE_MIST:
			# High-velocity mist of 32 small droplets
			for i in range(32):
				var ang := base_angle + rng.randf_range(-1.1, 1.1)
				var dist := rng.randf_range(4.0, 52.0) * base_scale
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(1.2, 3.8) * base_scale,
					"color": _pick_blood_color(rng, i % 4 == 0)
				})
				
		SplatterType.SMEAR_STREAK:
			# Dragged bloody streaks across concrete
			var perp := spray_direction.orthogonal()
			for i in range(5):
				var lateral := perp * rng.randf_range(-10.0, 10.0) * base_scale
				var start_p := lateral - spray_direction * rng.randf_range(5.0, 15.0) * base_scale
				var end_p := lateral + spray_direction * rng.randf_range(25.0, 54.0) * base_scale
				streaks.append({
					"from": start_p,
					"to": end_p,
					"width": rng.randf_range(3.0, 6.5) * base_scale,
					"color": _pick_blood_color(rng, i % 2 == 0)
				})
			for i in range(10):
				blobs.append({
					"pos": spray_direction * rng.randf_range(0.0, 48.0) * base_scale + perp * rng.randf_range(-14.0, 14.0) * base_scale,
					"radius": rng.randf_range(2.5, 6.0) * base_scale,
					"color": _pick_blood_color(rng, true)
				})
				
		SplatterType.HEAVY_GORE:
			# Visceral heavy kill pool with gore chunks and bone fragments
			for i in range(8):
				blobs.append({
					"pos": Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18)) * base_scale,
					"radius": rng.randf_range(10.0, 22.0) * base_scale,
					"color": _pick_blood_color(rng, true)
				})
			for i in range(16):
				var ang := rng.randf() * TAU
				var dist := rng.randf_range(12.0, 55.0) * base_scale
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(3.0, 7.5) * base_scale,
					"color": Color(0.55, 0.08, 0.08, 0.95) if i % 4 != 0 else Color(0.78, 0.72, 0.64, 0.90) # Bone/viscera specks
				})
				
		SplatterType.BOOMER_BILE:
			# Putrid toxic bile green + dark crimson explosion stain
			for i in range(14):
				var ang := rng.randf() * TAU
				var dist := rng.randf_range(0.0, 50.0) * base_scale
				var is_bile := (i % 2 == 0)
				var col := Color(0.38, 0.58, 0.14, 0.88) if is_bile else _pick_blood_color(rng, true)
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(8.0, 24.0) * base_scale,
					"color": col
				})
			for i in range(20):
				var ang := rng.randf() * TAU
				var dist := rng.randf_range(25.0, 78.0) * base_scale
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(2.5, 6.5) * base_scale,
					"color": Color(0.52, 0.74, 0.18, 0.85)
				})
				
		SplatterType.SCORCH_CRATER:
			# Grenade blast charred crater
			blobs.append({
				"pos": Vector2.ZERO,
				"radius": 34.0 * base_scale,
				"color": Color(0.05, 0.05, 0.06, 0.88)
			})
			blobs.append({
				"pos": Vector2.ZERO,
				"radius": 20.0 * base_scale,
				"color": Color(0.02, 0.02, 0.02, 0.94)
			})
			for i in range(16):
				var ang := (TAU / 16.0) * i + rng.randf_range(-0.15, 0.15)
				streaks.append({
					"from": Vector2.from_angle(ang) * 14.0 * base_scale,
					"to": Vector2.from_angle(ang) * rng.randf_range(38.0, 68.0) * base_scale,
					"width": rng.randf_range(2.5, 5.0) * base_scale,
					"color": Color(0.08, 0.07, 0.07, 0.80)
				})

	# Active flying blood droplets for immediate visceral impact animation
	if with_active_splash:
		is_animating_splash = true
		var count := 14 if splatter_type != SplatterType.HEAVY_GORE and splatter_type != SplatterType.BOOMER_BILE else 26
		for i in range(count):
			var spread := 0.85 if splatter_type == SplatterType.ARTERIAL_SPRAY else PI
			var ang := base_angle + rng.randf_range(-spread, spread)
			var spd := rng.randf_range(90.0, 260.0) * base_scale
			var col := Color(0.55, 0.78, 0.20, 0.95) if (splatter_type == SplatterType.BOOMER_BILE and i % 2 == 0) else Color(0.78, 0.08, 0.08, 0.95)
			flying_droplets.append({
				"pos": Vector2.ZERO,
				"vel": Vector2.from_angle(ang) * spd,
				"radius": rng.randf_range(2.2, 5.2) * base_scale,
				"duration": rng.randf_range(0.18, 0.42),
				"color": col
			})
	else:
		is_animating_splash = false

func _draw() -> void:
	for s in streaks:
		draw_line(s["from"], s["to"], s["color"], s["width"], true)
	for b in blobs:
		draw_circle(b["pos"], b["radius"], b["color"])
	if is_animating_splash:
		for d in flying_droplets:
			if splash_time < d["duration"]:
				var t: float = 1.0 - (splash_time / d["duration"])
				draw_circle(d["pos"], d["radius"] * (0.5 + 0.5 * t), d["color"])
