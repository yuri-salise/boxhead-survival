extends RefCounted

## Shared soft-light textures for world lights.
##
## Lights used to be drawn as flat-alpha discs and four-point polygons, which
## read as hard cartoon shapes. These textures fall off smoothly (inverse-square
## style, windowed to zero at the edge) so a lamp pool or a beam has no visible
## outline. Both are generated once and cached; nothing is allocated per frame.

const GLOW_SIZE: int = 96
const BEAM_W: int = 128
const BEAM_H: int = 96

static var _glow_tex: ImageTexture = null
static var _beam_tex: ImageTexture = null

## Radial light pool: bright core, long soft tail, exactly zero at the rim.
static func glow_texture() -> ImageTexture:
	if _glow_tex == null:
		var img := Image.create(GLOW_SIZE, GLOW_SIZE, false, Image.FORMAT_RGBA8)
		var half := float(GLOW_SIZE - 1) * 0.5
		for y in range(GLOW_SIZE):
			for x in range(GLOW_SIZE):
				var d := Vector2(float(x) - half, float(y) - half).length() / half
				var a := 0.0
				if d < 1.0:
					var window := (1.0 - d * d)
					a = (1.0 / (1.0 + 9.0 * d * d)) * window * window
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
		_glow_tex = ImageTexture.create_from_image(img)
	return _glow_tex

## Directional beam: origin at the left-centre, widening along +X.
## Gaussian hotspot on the axis, soft spill toward the edges, fading with distance.
static func beam_texture() -> ImageTexture:
	if _beam_tex == null:
		var img := Image.create(BEAM_W, BEAM_H, false, Image.FORMAT_RGBA8)
		for y in range(BEAM_H):
			var v := absf((float(y) / float(BEAM_H - 1)) - 0.5) * 2.0
			for x in range(BEAM_W):
				var u := float(x) / float(BEAM_W - 1)
				var a := 0.0
				if u > 0.0 and v < u:
					var ang := v / u
					var hotspot := exp(-pow(ang / 0.42, 2.0))
					var spill := 1.0 - smoothstep(0.0, 1.0, ang)
					var dist_fall := (1.0 - u * u)
					var start := smoothstep(0.0, 0.10, u)
					a = (hotspot * 0.65 + spill * 0.35) * dist_fall * dist_fall * start
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a, 0.0, 1.0)))
		_beam_tex = ImageTexture.create_from_image(img)
	return _beam_tex

## Draws a soft radial light pool. `color.a` is the peak brightness at the centre.
static func draw_glow(ci: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.5 or color.a <= 0.003:
		return
	var r := Vector2(radius, radius)
	ci.draw_texture_rect(glow_texture(), Rect2(center - r, r * 2.0), false, color)

## Draws a soft beam along the canvas item's current +X axis, starting at
## `start_x`. Callers rotate with draw_set_transform() to aim it.
static func draw_beam(ci: CanvasItem, start_x: float, length: float, half_width: float, color: Color) -> void:
	if length <= 1.0 or color.a <= 0.003:
		return
	ci.draw_texture_rect(beam_texture(), Rect2(Vector2(start_x, -half_width), Vector2(length, half_width * 2.0)), false, color)
