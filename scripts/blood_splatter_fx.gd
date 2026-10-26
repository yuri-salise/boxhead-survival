extends Node2D

@export var lifetime: float = 0.22
@export var blood_color: Color = Color(0.68, 0.08, 0.08, 1.0)

var elapsed: float = 0.0
var droplets: Array[Dictionary] = []

func _ready() -> void:
	if droplets.is_empty():
		setup(Vector2.RIGHT)

func setup(impact_dir: Vector2, p_color: Color = Color(0.68, 0.08, 0.08, 1.0), count: int = 8) -> void:
	blood_color = p_color
	droplets.clear()
	var base_ang := impact_dir.angle()
	for i in range(count):
		var ang := base_ang + randf_range(-0.75, 0.75)
		var spd := randf_range(160.0, 380.0)
		droplets.append({
			"pos": Vector2.ZERO,
			"vel": Vector2.from_angle(ang) * spd,
			"radius": randf_range(2.0, 4.5)
		})
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	
	for d in droplets:
		d["pos"] += d["vel"] * delta
		d["vel"] = d["vel"].move_toward(Vector2.ZERO, 380.0 * delta)
	
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - (elapsed / maxf(0.01, lifetime))
	var col := Color(blood_color.r, blood_color.g, blood_color.b, alpha * 0.95)
	for d in droplets:
		draw_circle(d["pos"], d["radius"] * alpha, col)
