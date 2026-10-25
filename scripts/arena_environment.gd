extends Node2D

var cracks: Array[Array] = []
var debris_spots: Array[Dictionary] = []
var beacon_time: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 847291
	
	# Generate realistic pavement cracks across the quarantine zone
	for i in range(28):
		var start_p := Vector2(rng.randf_range(70, 1210), rng.randf_range(70, 650))
		var pts: Array[Vector2] = [start_p]
		var cur := start_p
		var ang := rng.randf() * TAU
		for step in range(rng.randi_range(3, 6)):
			ang += rng.randf_range(-0.65, 0.65)
			cur += Vector2.from_angle(ang) * rng.randf_range(14.0, 34.0)
			pts.append(cur)
		cracks.append(pts)
	
	# Generate scattered rubble, oil stains, and rusted quarantine props
	for i in range(42):
		debris_spots.append({
			"pos": Vector2(rng.randf_range(65, 1215), rng.randf_range(65, 655)),
			"radius": rng.randf_range(4.0, 18.0),
			"dark": rng.randf() < 0.65
		})

func _process(delta: float) -> void:
	beacon_time += delta
	queue_redraw()

func _draw() -> void:
	# 1. Outer pitch-black abyss outside quarantine walls
	draw_rect(Rect2(Vector2(-100, -100), Vector2(1480, 920)), Color(0.03, 0.03, 0.04, 1.0), true)
	
	# 2. Main decayed asphalt compound floor
	draw_rect(Rect2(Vector2(40, 40), Vector2(1200, 640)), Color(0.09, 0.10, 0.11, 1.0), true)
	
	# 3. Concrete slab grid joints
	var grid_col := Color(0.06, 0.07, 0.08, 0.75)
	for x in range(120, 1240, 160):
		draw_line(Vector2(x, 40), Vector2(x, 680), grid_col, 2.0)
	for y in range(120, 680, 160):
		draw_line(Vector2(40, y), Vector2(1240, y), grid_col, 2.0)
	
	# 4. Faded road lanes & quarantine center helipad / evacuation circle
	draw_arc(Vector2(640, 360), 115.0, 0.0, TAU, 48, Color(0.38, 0.32, 0.16, 0.22), 4.0)
	draw_arc(Vector2(640, 360), 82.0, 0.0, TAU, 36, Color(0.45, 0.16, 0.16, 0.18), 2.5)
	for x in range(100, 1180, 90):
		draw_rect(Rect2(Vector2(x, 357), Vector2(45, 6)), Color(0.42, 0.35, 0.18, 0.18), true)
	
	# 5. Oil stains & rubble spots
	for d in debris_spots:
		var col := Color(0.05, 0.05, 0.06, 0.55) if d["dark"] else Color(0.15, 0.14, 0.13, 0.45)
		draw_circle(d["pos"], d["radius"], col)
	
	# 6. Pavement cracks
	for c in cracks:
		for i in range(c.size() - 1):
			draw_line(c[i], c[i + 1], Color(0.04, 0.04, 0.05, 0.85), 1.8)
	
	# 7. Quarantine Perimeter Concrete Barricade Walls & Hazard Stripes
	draw_rect(Rect2(Vector2(40, 40), Vector2(1200, 640)), Color(0.24, 0.25, 0.27, 1.0), false, 8.0)
	draw_rect(Rect2(Vector2(44, 44), Vector2(1192, 632)), Color(0.55, 0.16, 0.16, 0.85), false, 2.5)
	
	# 8. Flickering Emergency Quarantine Corner Beacons
	var flicker := 0.55 + 0.45 * sin(beacon_time * 4.5)
	var corners: Array[Vector2] = [
		Vector2(64, 64), Vector2(1216, 64), Vector2(64, 656), Vector2(1216, 656)
	]
	for cp in corners:
		draw_circle(cp, 46.0, Color(0.75, 0.15, 0.12, 0.09 * flicker))
		draw_circle(cp, 18.0, Color(0.88, 0.22, 0.15, 0.18 * flicker))
		draw_circle(cp, 5.0, Color(1.0, 0.35, 0.20, 0.85 * flicker))
