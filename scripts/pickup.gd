extends Area2D

signal picked_up(pickup_type: String, picker: Node2D)

const PICKUP_TYPES: Dictionary = {
	"MEDKIT": {
		"label": "+ MEDKIT (35 HP)",
		"color": Color(0.22, 0.85, 0.35, 1.0)
	},
	"ARMOR": {
		"label": "+ KEVLAR ARMOR (50 AP)",
		"color": Color(0.28, 0.65, 0.95, 1.0)
	},
	"AMMO": {
		"label": "+ AMMO CRATE & GRENADE",
		"color": Color(0.92, 0.75, 0.25, 1.0)
	},
	"ADRENALINE": {
		"label": "+ ADRENALINE SHOT",
		"color": Color(1.0, 0.50, 0.15, 1.0)
	},
	"WEAPON_SMG": {
		"label": "[2] MP5 SMG",
		"color": Color(0.98, 0.78, 0.25, 1.0)
	},
	"WEAPON_SHOTGUN": {
		"label": "[3] 12G SHOTGUN",
		"color": Color(1.0, 0.55, 0.18, 1.0)
	},
	"WEAPON_ASSAULT_RIFLE": {
		"label": "[4] M4A1 RIFLE",
		"color": Color(0.95, 0.88, 0.35, 1.0)
	},
	"WEAPON_MAGNUM": {
		"label": "[5] .44 MAGNUM",
		"color": Color(1.0, 0.32, 0.28, 1.0)
	}
}

@export var pickup_type: String = "MEDKIT"
@export var lifetime: float = 25.0

var elapsed: float = 0.0
var is_collected: bool = false

@onready var item_label: Label = get_node_or_null("ItemLabel")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 8 # Layer 4: Players
	body_entered.connect(_on_body_entered)
	_refresh_label()

func setup(p_type: String, p_pos: Vector2) -> void:
	pickup_type = p_type if PICKUP_TYPES.has(p_type) else "MEDKIT"
	global_position = p_pos
	_refresh_label()
	queue_redraw()

func _refresh_label() -> void:
	if item_label and PICKUP_TYPES.has(pickup_type):
		var info: Dictionary = PICKUP_TYPES[pickup_type]
		item_label.text = str(info["label"])
		item_label.add_theme_color_override("font_color", info["color"])

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if is_instance_valid(body) and body.is_in_group("players") and body.has_method("apply_pickup"):
		if body.get("is_dead") == true:
			return
		is_collected = true
		body.apply_pickup(pickup_type)
		picked_up.emit(pickup_type, body)
		queue_free()

func _draw() -> void:
	var info: Dictionary = PICKUP_TYPES.get(pickup_type, PICKUP_TYPES["MEDKIT"])
	var col: Color = info["color"]
	var bob := sin(elapsed * 4.5) * 3.0
	var pulse := 0.85 + 0.15 * sin(elapsed * 6.0)
	var center := Vector2(0, bob)
	
	# Ground drop shadow + beacon glow ring
	draw_circle(Vector2(5.0, 8.0), 12.5, Color(0.0, 0.0, 0.0, 0.48))
	draw_circle(Vector2.ZERO, 20.0 * pulse, Color(col.r, col.g, col.b, 0.18))
	draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.65), 1.8)
	
	match pickup_type:
		"MEDKIT":
			# White medical pouch with red cross
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), Color(0.92, 0.94, 0.92, 1.0), true)
			draw_rect(Rect2(center + Vector2(-11, -9), Vector2(22, 18)), Color(0.20, 0.55, 0.25, 1.0), false, 2.0)
			draw_rect(Rect2(center + Vector2(-2.5, -6), Vector2(5, 12)), Color(0.85, 0.15, 0.15, 1.0), true)
			draw_rect(Rect2(center + Vector2(-6, -2.5), Vector2(12, 5)), Color(0.85, 0.15, 0.15, 1.0), true)
		"ARMOR":
			# Tactical Kevlar vest plate
			var pts := PackedVector2Array([
				center + Vector2(-10, -10),
				center + Vector2(10, -10),
				center + Vector2(12, 2),
				center + Vector2(0, 12),
				center + Vector2(-12, 2)
			])
			draw_colored_polygon(pts, Color(0.18, 0.35, 0.52, 1.0))
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.45, 0.80, 1.0, 1.0), 2.0)
			draw_rect(Rect2(center + Vector2(-6, -4), Vector2(12, 6)), Color(0.32, 0.58, 0.82, 1.0), true)
		"AMMO":
			# Military olive ammo box + brass stripes
			draw_rect(Rect2(center + Vector2(-12, -8), Vector2(24, 16)), Color(0.28, 0.34, 0.22, 1.0), true)
			draw_rect(Rect2(center + Vector2(-12, -8), Vector2(24, 16)), Color(0.88, 0.72, 0.24, 1.0), false, 2.0)
			for i in range(-1, 2):
				draw_rect(Rect2(center + Vector2(i * 5 - 1.5, -4), Vector2(3, 8)), Color(0.95, 0.80, 0.28, 1.0), true)
		"ADRENALINE":
			# Glowing combat syringe
			draw_rect(Rect2(center + Vector2(-10, -3), Vector2(16, 6)), Color(0.95, 0.48, 0.12, 1.0), true)
			draw_rect(Rect2(center + Vector2(-10, -3), Vector2(16, 6)), Color(1.0, 0.85, 0.45, 1.0), false, 1.5)
			draw_line(center + Vector2(6, 0), center + Vector2(13, 0), Color(0.85, 0.90, 0.95, 1.0), 2.0)
			draw_line(center + Vector2(-14, 0), center + Vector2(-10, 0), Color(0.75, 0.78, 0.82, 1.0), 3.0)
		_:
			# Weapon Crate / Gun Silhouette
			draw_rect(Rect2(center + Vector2(-14, -7), Vector2(28, 14)), Color(0.14, 0.16, 0.18, 0.95), true)
			draw_rect(Rect2(center + Vector2(-14, -7), Vector2(28, 14)), col, false, 2.0)
			# Gun barrel & grip icon inside
			draw_rect(Rect2(center + Vector2(-9, -3), Vector2(18, 4)), Color(0.85, 0.88, 0.92, 1.0), true)
			draw_rect(Rect2(center + Vector2(-6, 1), Vector2(4, 5)), col, true)
			draw_rect(Rect2(center + Vector2(2, 1), Vector2(3, 4)), Color(0.65, 0.68, 0.72, 1.0), true)
