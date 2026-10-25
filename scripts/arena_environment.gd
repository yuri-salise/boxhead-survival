extends Node2D

const CHUNK_SIZE: float = 640.0
const SHADOW_VEC: Vector2 = Vector2(14.0, 18.0)

var focus_position: Vector2 = Vector2(640.0, 360.0)
var beacon_time: float = 0.0
var chunk_cache: Dictionary = {}

func set_focus_position(pos: Vector2) -> void:
	focus_position = pos
	queue_redraw()

func get_chunk_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CHUNK_SIZE)), int(floor(world_pos.y / CHUNK_SIZE)))

func _process(delta: float) -> void:
	beacon_time += delta
	queue_redraw()

func _get_chunk_data(cx: int, cy: int) -> Dictionary:
	var key := str(cx) + "_" + str(cy)
	if chunk_cache.has(key):
		return chunk_cache[key]
	
	# Evict oldest chunks if cache grows large during long infinite exploration
	if chunk_cache.size() > 64:
		chunk_cache.clear()
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(cx, cy)) ^ 0x5F3759DF
	
	var origin := Vector2(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
	var cracks: Array[Array] = []
	for i in range(6):
		var start_p := origin + Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40))
		var pts: Array[Vector2] = [start_p]
		var cur := start_p
		var ang := rng.randf() * TAU
		for step in range(rng.randi_range(3, 5)):
			ang += rng.randf_range(-0.65, 0.65)
			cur += Vector2.from_angle(ang) * rng.randf_range(16.0, 36.0)
			pts.append(cur)
		cracks.append(pts)
	
	var stains: Array[Dictionary] = []
	for i in range(9):
		stains.append({
			"pos": origin + Vector2(rng.randf_range(24, CHUNK_SIZE - 24), rng.randf_range(24, CHUNK_SIZE - 24)),
			"radius": rng.randf_range(5.0, 20.0),
			"dark": rng.randf() < 0.65
		})
	
	# Visual props with realistic directional cast shadows (barrels, concrete roadblocks, beacons)
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(2, 4)
	for i in range(prop_count):
		var px := rng.randf_range(80.0, CHUNK_SIZE - 80.0)
		var py := rng.randf_range(80.0, CHUNK_SIZE - 80.0)
		var p_pos := origin + Vector2(px, py)
		# Keep starter spawn center clear
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = rusted barrel, 1 = concrete roadblock, 2 = emergency beacon post
			"rot": rng.randf_range(-0.45, 0.45)
		})
	
	var data := {
		"origin": origin,
		"cx": cx,
		"cy": cy,
		"cracks": cracks,
		"stains": stains,
		"props": props,
		"has_ew_road": (absi(cy) % 2 == 0),
		"has_ns_road": (absi(cx) % 2 == 1)
	}
	chunk_cache[key] = data
	return data

func _draw() -> void:
	var center_chunk := get_chunk_coords(focus_position)
	var flicker := 0.60 + 0.40 * sin(beacon_time * 4.5)
	
	# Render a 5x5 grid of 640x640 chunks around the player's current position for seamless infinite movement
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var chunk := _get_chunk_data(center_chunk.x + dx, center_chunk.y + dy)
			_draw_chunk(chunk, flicker)

func _draw_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# 1. Base weathered concrete / asphalt sector floor
	var base_shade := 0.09 if ((cx + cy) % 2 == 0) else 0.085
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade + 0.01, base_shade + 0.02, 1.0), true)
	
	# 2. Concrete expansion slab grid lines
	var grid_col := Color(0.05, 0.06, 0.07, 0.72)
	for step in range(0, int(CHUNK_SIZE), 160):
		draw_line(origin + Vector2(step, 0), origin + Vector2(step, CHUNK_SIZE), grid_col, 2.0)
		draw_line(origin + Vector2(0, step), origin + Vector2(CHUNK_SIZE, step), grid_col, 2.0)
	
	# 3. Infinite Quarantine Road Network (East-West & North-South Asphalt Highways)
	if chunk["has_ew_road"]:
		var road_y := origin.y + CHUNK_SIZE * 0.5 - 70.0
		draw_rect(Rect2(Vector2(origin.x, road_y), Vector2(CHUNK_SIZE, 140.0)), Color(0.065, 0.07, 0.08, 1.0), true)
		draw_line(Vector2(origin.x, road_y), Vector2(origin.x + CHUNK_SIZE, road_y), Color(0.22, 0.23, 0.25, 0.55), 3.0)
		draw_line(Vector2(origin.x, road_y + 140.0), Vector2(origin.x + CHUNK_SIZE, road_y + 140.0), Color(0.22, 0.23, 0.25, 0.55), 3.0)
		for lx in range(20, int(CHUNK_SIZE), 90):
			draw_rect(Rect2(Vector2(origin.x + lx, origin.y + CHUNK_SIZE * 0.5 - 3.0), Vector2(46.0, 6.0)), Color(0.45, 0.36, 0.16, 0.24), true)
	
	if chunk["has_ns_road"]:
		var road_x := origin.x + CHUNK_SIZE * 0.5 - 70.0
		draw_rect(Rect2(Vector2(road_x, origin.y), Vector2(140.0, CHUNK_SIZE)), Color(0.065, 0.07, 0.08, 1.0), true)
		for ly in range(20, int(CHUNK_SIZE), 90):
			draw_rect(Rect2(Vector2(origin.x + CHUNK_SIZE * 0.5 - 3.0, origin.y + ly), Vector2(6.0, 46.0)), Color(0.45, 0.36, 0.16, 0.24), true)
	
	# Evacuation Helipad markings at starting origin sector
	if cx == 1 and cy == 0:
		var helipad := Vector2(640, 360)
		draw_arc(helipad, 110.0, 0.0, TAU, 48, Color(0.42, 0.34, 0.16, 0.24), 4.0)
		draw_arc(helipad, 78.0, 0.0, TAU, 36, Color(0.52, 0.16, 0.16, 0.20), 2.5)
	
	# 4. Oil spills, bloodied grime & rubble stains
	var stains: Array = chunk["stains"]
	for d in stains:
		var col := Color(0.04, 0.04, 0.05, 0.58) if d["dark"] else Color(0.14, 0.13, 0.12, 0.42)
		draw_circle(d["pos"], d["radius"], col)
	
	# 5. Jagged pavement cracks
	var cracks: Array = chunk["cracks"]
	for c in cracks:
		for i in range(c.size() - 1):
			draw_line(c[i], c[i + 1], Color(0.03, 0.03, 0.04, 0.85), 1.8)
	
	# 6. Props with Realistic Directional Cast Shadows
	var props: Array = chunk["props"]
	for p in props:
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		if kind == 0:
			# Rusted Biohazard Drum + elongated cast shadow
			draw_circle(pos + SHADOW_VEC * 0.85, 14.0, Color(0.0, 0.0, 0.0, 0.38))
			draw_circle(pos + SHADOW_VEC * 0.45, 13.5, Color(0.0, 0.0, 0.0, 0.50))
			draw_circle(pos, 13.0, Color(0.36, 0.18, 0.12, 1.0))
			draw_arc(pos, 13.0, 0.0, TAU, 20, Color(0.18, 0.10, 0.08, 1.0), 2.2)
			draw_circle(pos + Vector2(-3, -3), 4.0, Color(0.68, 0.52, 0.14, 0.80))
		elif kind == 1:
			# Weathered Concrete Roadblock Barrier + directional polygon shadow
			var b_rect := Rect2(pos - Vector2(26, 8), Vector2(52, 16))
			var s_rect := Rect2(pos - Vector2(26, 8) + SHADOW_VEC * 0.75, Vector2(54, 18))
			draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.48), true)
			draw_rect(b_rect, Color(0.24, 0.25, 0.27, 1.0), true)
			draw_rect(b_rect, Color(0.12, 0.13, 0.15, 1.0), false, 2.0)
			draw_line(pos - Vector2(20, 0), pos + Vector2(20, 0), Color(0.65, 0.20, 0.16, 0.75), 3.0)
		else:
			# Flickering Quarantine Lamp Post + long pole shadow + eerie crimson/amber light pool
			draw_line(pos, pos + SHADOW_VEC * 1.9, Color(0.0, 0.0, 0.0, 0.52), 5.0)
			draw_circle(pos, 52.0, Color(0.78, 0.18, 0.12, 0.08 * flicker))
			draw_circle(pos, 20.0, Color(0.92, 0.25, 0.15, 0.16 * flicker))
			draw_circle(pos, 6.0, Color(0.18, 0.20, 0.22, 1.0))
			draw_circle(pos, 3.8, Color(1.0, 0.38, 0.20, 0.90 * flicker))
