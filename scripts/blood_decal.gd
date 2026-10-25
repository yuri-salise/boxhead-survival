extends Node2D

enum SplatterType {
	ARTERIAL_SPRAY,
	COAGULATED_POOL,
	STARBURST,
	FINE_MIST,
	SMEAR_STREAK,
	HEAVY_GORE,
	BOOMER_BILE,
	SCORCH_CRATER,
	SEVERED_LIMB
}

enum LimbKind {
	ARM,
	LEG,
	HEAD,
	RIB_CHUNK
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

# Severed limb physics & permanent corpse part state
var has_limb_part: bool = false
var limb_kind: int = LimbKind.ARM
var limb_color: Color = Color(0.46, 0.52, 0.42, 1.0)
var limb_pos: Vector2 = Vector2.ZERO
var limb_vel: Vector2 = Vector2.ZERO
var limb_rot: float = 0.0
var limb_ang_vel: float = 0.0
var limb_z: float = 0.0
var limb_z_vel: float = 0.0
var limb_settled: bool = true

func setup(p_pos: Vector2, p_dir: Vector2, p_type: int = -1, p_scale: float = 1.0, with_active_splash: bool = true) -> void:
	global_position = p_pos
	spray_direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU)
	base_scale = p_scale * randf_range(0.85, 1.25)
	seed_val = randi()
	has_limb_part = false
	
	if p_type < 0:
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
	set_process(is_animating_splash or not limb_settled)
	queue_redraw()

func setup_severed_limb(p_pos: Vector2, p_dir: Vector2, p_limb_kind: int, p_skin_color: Color, p_scale: float = 1.0) -> void:
	global_position = p_pos
	spray_direction = p_dir.normalized() if p_dir != Vector2.ZERO else Vector2.RIGHT.rotated(randf() * TAU)
	base_scale = p_scale
	seed_val = randi()
	splatter_type = SplatterType.SEVERED_LIMB
	
	has_limb_part = true
	limb_kind = p_limb_kind
	limb_color = p_skin_color
	limb_pos = Vector2.ZERO
	var launch_angle := spray_direction.angle() + randf_range(-0.55, 0.55)
	limb_vel = Vector2.from_angle(launch_angle) * randf_range(115.0, 235.0) * p_scale
	limb_rot = randf() * TAU
	limb_ang_vel = randf_range(-14.0, 14.0)
	limb_z = 8.0 * p_scale
	limb_z_vel = randf_range(110.0, 175.0)
	limb_settled = false
	
	_generate_splatter_geometry(true)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	var needs_update := false
	
	if is_animating_splash:
		splash_time += delta
		var active_count := 0
		for drop in flying_droplets:
			if splash_time < drop["duration"]:
				active_count += 1
				drop["pos"] += drop["vel"] * delta
				drop["vel"] = drop["vel"].move_toward(Vector2.ZERO, 420.0 * delta)
		if active_count == 0 or splash_time >= 0.45:
			is_animating_splash = false
			flying_droplets.clear()
		else:
			needs_update = true
	
	if has_limb_part and not limb_settled:
		needs_update = true
		limb_pos += limb_vel * delta
		limb_rot += limb_ang_vel * delta
		limb_z_vel -= 480.0 * delta
		limb_z += limb_z_vel * delta
		
		# Bounce on the asphalt floor and leave blood drops on impact
		if limb_z <= 0.0:
			limb_z = 0.0
			if absf(limb_z_vel) > 38.0:
				limb_z_vel = -limb_z_vel * 0.42
				limb_vel *= 0.62
				limb_ang_vel *= 0.60
				blobs.append({
					"pos": limb_pos + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
					"radius": randf_range(4.5, 8.5) * base_scale,
					"color": Color(0.45, 0.03, 0.04, 0.90)
				})
			else:
				limb_z_vel = 0.0
				limb_vel = limb_vel.move_toward(Vector2.ZERO, 380.0 * delta)
				limb_ang_vel = move_toward(limb_ang_vel, 0.0, 28.0 * delta)
				if limb_vel.length() < 4.0:
					limb_settled = true
					# Final coagulated blood puddle under the settled severed limb
					blobs.append({
						"pos": limb_pos,
						"radius": 10.5 * base_scale,
						"color": Color(0.34, 0.02, 0.03, 0.88)
					})
	
	queue_redraw()
	if not needs_update and not is_animating_splash and limb_settled:
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
		SplatterType.ARTERIAL_SPRAY, SplatterType.SEVERED_LIMB:
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
			for i in range(32):
				var ang := base_angle + rng.randf_range(-1.1, 1.1)
				var dist := rng.randf_range(4.0, 52.0) * base_scale
				blobs.append({
					"pos": Vector2.from_angle(ang) * dist,
					"radius": rng.randf_range(1.2, 3.8) * base_scale,
					"color": _pick_blood_color(rng, i % 4 == 0)
				})
				
		SplatterType.SMEAR_STREAK:
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
					"color": Color(0.55, 0.08, 0.08, 0.95) if i % 4 != 0 else Color(0.78, 0.72, 0.64, 0.90)
				})
				
		SplatterType.BOOMER_BILE:
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

	if with_active_splash:
		is_animating_splash = true
		var count := 16 if splatter_type != SplatterType.HEAVY_GORE and splatter_type != SplatterType.BOOMER_BILE else 26
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
	
	if has_limb_part:
		_draw_severed_limb()

func _draw_severed_limb() -> void:
	# Ground shadow offset by airborne height limb_z
	var shadow_pos := limb_pos + Vector2(4.0 + limb_z * 0.35, 5.0 + limb_z * 0.45)
	draw_circle(shadow_pos, 7.5 * base_scale, Color(0.0, 0.0, 0.0, 0.52))
	
	var visual_pos := limb_pos + Vector2(0.0, -limb_z)
	draw_set_transform(visual_pos, limb_rot, Vector2(base_scale, base_scale))
	
	match limb_kind:
		LimbKind.ARM:
			# Exposed white humerus bone at severed joint + bloody stump
			draw_line(Vector2(-10, 0), Vector2(-4, 0), Color(0.88, 0.85, 0.76, 1.0), 3.0)
			draw_circle(Vector2(-4, 0), 4.2, Color(0.68, 0.06, 0.06, 1.0))
			# Forearm flesh & torn sleeve
			draw_line(Vector2(-4, 0), Vector2(9, 1), limb_color, 5.5)
			# Bloody clawed zombie hand
			draw_circle(Vector2(10, 1), 3.5, Color(0.65, 0.10, 0.10, 1.0))
			draw_line(Vector2(10, -1), Vector2(14, -3), Color(0.75, 0.12, 0.12, 1.0), 1.6)
			draw_line(Vector2(10, 1), Vector2(15, 1), Color(0.75, 0.12, 0.12, 1.0), 1.6)
			draw_line(Vector2(10, 3), Vector2(14, 4), Color(0.75, 0.12, 0.12, 1.0), 1.6)
		LimbKind.LEG:
			# Exposed femur bone + torn thigh muscle
			draw_line(Vector2(-11, 0), Vector2(-5, 0), Color(0.90, 0.86, 0.78, 1.0), 3.6)
			draw_circle(Vector2(-5, 0), 5.0, Color(0.65, 0.05, 0.05, 1.0))
			# Torn trouser leg
			draw_line(Vector2(-5, 0), Vector2(8, 0), Color(0.22, 0.24, 0.20, 1.0), 6.8)
			# Heavy muddy boot
			draw_rect(Rect2(Vector2(7, -3), Vector2(7, 8)), Color(0.14, 0.12, 0.10, 1.0), true)
		LimbKind.HEAD:
			# Severed neck stump & spine bone
			draw_circle(Vector2(-6, 0), 5.0, Color(0.62, 0.04, 0.05, 1.0))
			draw_circle(Vector2(-7, 0), 2.2, Color(0.88, 0.85, 0.78, 1.0))
			# Rotting zombie skull/head
			draw_circle(Vector2(0, 0), 7.8, limb_color)
			draw_circle(Vector2(4, -2.5), 1.6, Color(0.12, 0.04, 0.04, 1.0))
			draw_circle(Vector2(4, 2.5), 1.6, Color(0.75, 0.65, 0.15, 0.85))
			draw_line(Vector2(5, -3), Vector2(5, 3), Color(0.45, 0.05, 0.05, 1.0), 2.0)
		LimbKind.RIB_CHUNK:
			# Mangled flesh chunk with white rib bones
			draw_circle(Vector2(0, 0), 6.5, Color(0.56, 0.05, 0.06, 0.96))
			draw_line(Vector2(-5, -3), Vector2(4, -2), Color(0.88, 0.84, 0.75, 1.0), 2.2)
			draw_line(Vector2(-4, 1), Vector2(5, 2), Color(0.88, 0.84, 0.75, 1.0), 2.2)
			draw_line(Vector2(-3, 4), Vector2(3, 5), Color(0.88, 0.84, 0.75, 1.0), 2.0)
	
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
