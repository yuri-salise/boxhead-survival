extends Area2D

@export var pool_radius: float = 48.0
@export var duration: float = 5.5
@export var tick_damage: float = 6.0
@export var tick_interval: float = 0.45

var elapsed: float = 0.0
var tick_timer: float = 0.0
var bubbles: Array[Dictionary] = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 # Layer 4: Players
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = pool_radius
	col.shape = shape
	add_child(col)
	
	for i in range(10):
		var ang := randf() * TAU
		var dist := randf_range(4.0, pool_radius * 0.78)
		bubbles.append({
			"pos": Vector2.from_angle(ang) * dist,
			"phase": randf() * TAU,
			"max_r": randf_range(3.0, 7.0)
		})

func _process(delta: float) -> void:
	elapsed += delta
	tick_timer += delta
	
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		for body in get_overlapping_bodies():
			if is_instance_valid(body) and body.is_in_group("players") and body.has_method("take_damage"):
				body.take_damage(tick_damage)
	
	queue_redraw()
	if elapsed >= duration:
		queue_free()

func _draw() -> void:
	var fade := clampf(1.0 - maxf(0.0, (elapsed - (duration - 1.2)) / 1.2), 0.0, 1.0)
	var pulse := 0.94 + 0.06 * sin(elapsed * 6.0)
	
	# Outer toxic glow
	draw_circle(Vector2.ZERO, pool_radius * 1.12 * pulse, Color(0.25, 0.75, 0.12, 0.25 * fade))
	# Main corrosive puddle
	draw_circle(Vector2.ZERO, pool_radius * pulse, Color(0.32, 0.68, 0.14, 0.65 * fade))
	# Inner neon acid core
	draw_circle(Vector2.ZERO, pool_radius * 0.65 * pulse, Color(0.58, 0.92, 0.18, 0.72 * fade))
	
	# Bubbling acid blisters
	for b in bubbles:
		var r: float = b["max_r"] * (0.5 + 0.5 * sin(elapsed * 5.0 + b["phase"]))
		draw_circle(b["pos"], r, Color(0.82, 1.0, 0.45, 0.80 * fade))
