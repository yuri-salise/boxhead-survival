extends Node2D

const LightFX := preload("res://scripts/light_fx.gd")

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
	
	# Soft light spill onto the ground around the muzzle
	LightFX.draw_glow(self, Vector2(8 * sc, 0), 46.0 * sc, Color(flash_color.r, flash_color.g, flash_color.b, alpha * 0.55))
	
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
	LightFX.draw_glow(self, Vector2(5 * sc, 0), 11.0 * sc, Color(1.0, 1.0, 0.92, alpha))
