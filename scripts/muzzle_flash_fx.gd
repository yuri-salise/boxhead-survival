extends Node2D

@export var lifetime: float = 0.075
@export var flash_scale: float = 1.0
@export var flash_color: Color = Color(1.0, 0.90, 0.40, 1.0)

var elapsed: float = 0.0

func _ready() -> void:
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var alpha := 1.0 - (elapsed / maxf(0.01, lifetime))
	var sc := flash_scale * (1.0 + elapsed * 3.0)
	
	# Jagged flame starburst
	var spurs := PackedVector2Array([
		Vector2(0, 0),
		Vector2(18 * sc, -7 * sc),
		Vector2(12 * sc, -1 * sc),
		Vector2(26 * sc, 0),
		Vector2(12 * sc, 1 * sc),
		Vector2(18 * sc, 7 * sc)
	])
	draw_colored_polygon(spurs, Color(flash_color.r, flash_color.g, flash_color.b, alpha * 0.90))
	
	# Bright incandescent core
	draw_circle(Vector2(4 * sc, 0), 4.5 * sc, Color(1.0, 1.0, 0.92, alpha * 0.98))
	draw_circle(Vector2(9 * sc, 0), 3.0 * sc, Color(1.0, 0.75, 0.25, alpha * 0.85))
