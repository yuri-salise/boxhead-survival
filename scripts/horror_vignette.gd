extends Control

var low_health_ratio: float = 1.0
var pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	pulse_time += delta
	queue_redraw()

func set_health_ratio(ratio: float) -> void:
	low_health_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	# Dark horror border framing
	var border_col := Color(0.01, 0.01, 0.02, 0.55)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 38)), border_col, true)
	draw_rect(Rect2(Vector2(0, vp.y - 38), Vector2(vp.x, 38)), border_col, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(42, vp.y)), border_col, true)
	draw_rect(Rect2(Vector2(vp.x - 42, 0), Vector2(42, vp.y)), border_col, true)
	
	# Low-health blood heartbeat vignette when HP < 40%
	if low_health_ratio < 0.40:
		var intensity := (0.40 - low_health_ratio) / 0.40
		var beat := 0.55 + 0.45 * sin(pulse_time * 7.5)
		var red_alpha := intensity * beat * 0.35
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.55, 0.04, 0.04, red_alpha), false, 36.0)
