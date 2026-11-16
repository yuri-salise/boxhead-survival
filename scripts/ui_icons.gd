extends RefCounted

## UI icon helper.
##
## Emoji and symbol glyphs (stars, bolts, clipboards) are not in the game's
## fonts, so on Android they fall back to the system emoji font or render as
## empty boxes. Buttons use the original SVGs in assets/art/icons instead, and
## star ratings are rasterised once here so they look identical on every device.

const ICON_DIR: String = "res://assets/art/icons/"
const STAR_PX: int = 40
const STAR_GAP: int = 6
const STAR_FULL_COLOR: Color = Color(0.98, 0.80, 0.22, 1.0)
const STAR_EMPTY_COLOR: Color = Color(0.42, 0.40, 0.36, 1.0)

static var _icon_cache: Dictionary = {}
static var _strip_cache: Dictionary = {}
static var _star_mask: PackedFloat32Array = PackedFloat32Array()

## Returns the named icon texture (e.g. "pause", "lock"), or null if it is missing.
static func get_icon(icon_name: String) -> Texture2D:
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]
	var path := ICON_DIR + icon_name + ".svg"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_icon_cache[icon_name] = tex
	return tex

## Puts an icon on a button, scaled to `px` wide. Passing "" clears it.
static func apply(button: Button, icon_name: String, px: int = 24) -> void:
	if button == null:
		return
	button.icon = get_icon(icon_name) if icon_name != "" else null
	button.add_theme_constant_override("icon_max_width", px)
	button.add_theme_constant_override("h_separation", 8)

## A row of `total` stars with the first `filled` in gold and the rest dimmed.
static func star_strip(filled: int, total: int = 3) -> ImageTexture:
	total = maxi(1, total)
	filled = clampi(filled, 0, total)
	var key := filled * 100 + total
	if _strip_cache.has(key):
		return _strip_cache[key]
	_ensure_star_mask()
	var width := total * STAR_PX + (total - 1) * STAR_GAP
	var img := Image.create(width, STAR_PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for s in range(total):
		var col := STAR_FULL_COLOR if s < filled else STAR_EMPTY_COLOR
		var ox := s * (STAR_PX + STAR_GAP)
		for y in range(STAR_PX):
			for x in range(STAR_PX):
				var a := _star_mask[y * STAR_PX + x]
				if a > 0.0:
					img.set_pixel(ox + x, y, Color(col.r, col.g, col.b, a))
	var tex := ImageTexture.create_from_image(img)
	_strip_cache[key] = tex
	return tex

# Anti-aliased coverage mask of one five-point star (3x3 supersampling).
static func _ensure_star_mask() -> void:
	if _star_mask.size() == STAR_PX * STAR_PX:
		return
	var center := Vector2(STAR_PX, STAR_PX) * 0.5
	var outer := float(STAR_PX) * 0.48
	var inner := outer * 0.42
	var pts := PackedVector2Array()
	for i in range(10):
		var r := outer if i % 2 == 0 else inner
		var ang := -PI * 0.5 + float(i) * PI / 5.0
		pts.append(center + Vector2(cos(ang), sin(ang)) * r + Vector2(0.0, 1.0))
	_star_mask.resize(STAR_PX * STAR_PX)
	for y in range(STAR_PX):
		for x in range(STAR_PX):
			var hits := 0
			for sy in range(3):
				for sx in range(3):
					var p := Vector2(float(x) + (float(sx) + 0.5) / 3.0, float(y) + (float(sy) + 0.5) / 3.0)
					if Geometry2D.is_point_in_polygon(p, pts):
						hits += 1
			_star_mask[y * STAR_PX + x] = float(hits) / 9.0
