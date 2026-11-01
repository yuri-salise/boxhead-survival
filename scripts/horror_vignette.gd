extends Control

var low_health_ratio: float = 1.0
var pulse_time: float = 0.0
var bite_flash_alpha: float = 0.0
var last_bite_dir: Vector2 = Vector2.RIGHT

# Continuous Gradual Day/Dusk/Night Cycle (0.0 = Daylight, 0.5 = Dusk/Dawn, 1.0 = Pitch-Black Night)
var night_factor: float = 0.0
var night_mode_enabled: bool = false
var is_dusk_phase: bool = true
var flashlight_screen_pos: Vector2 = Vector2(640.0, 360.0)
var flashlight_angle: float = 0.0
var flashlight_occluders: Array = []
var flashlight_player_world_pos: Vector2 = Vector2.ZERO

# Ambient Lights (Streetlights, beacon lamps, emergency generators, turrets, fuel trucks)
var ambient_lights: Array = []
# Ally / Bot / Turret directional flashlight cones
var ally_flashlights: Array = []
# Witch & scary special zombie glowing eyes in darkness
var active_witches: Array = []

# POV blood splatters & dripping streaks on the screen lens when bitten
var pov_blood_drops: Array[Dictionary] = []

var darkness_rect: ColorRect = null
var darkness_mat: ShaderMaterial = null

const DARKNESS_SHADER_CODE: String = """
shader_type canvas_item;

uniform float u_night_factor : hint_range(0.0, 1.0) = 0.0;
uniform vec2 u_canvas_size = vec2(1280.0, 720.0);
uniform vec2 u_player_screen_pos = vec2(640.0, 360.0);
uniform float u_flashlight_angle = 0.0;
uniform float u_cone_half = 0.44;
uniform float u_beam_len = 430.0;
uniform float u_inner_radius = 60.0;

const int MAX_ALLIES = 6;
uniform int u_ally_count = 0;
uniform vec2 u_ally_screen_pos[MAX_ALLIES];
uniform float u_ally_flashlight_angle[MAX_ALLIES];

const int MAX_LIGHTS = 16;
uniform int u_light_count = 0;
uniform vec2 u_light_pos[MAX_LIGHTS];
uniform float u_light_radius[MAX_LIGHTS];
uniform vec4 u_light_color[MAX_LIGHTS];

const int MAX_SHADOWS = 8;
uniform int u_shadow_count = 0;
uniform vec2 u_shadow_obs_pos[MAX_SHADOWS];
uniform float u_shadow_obs_radius[MAX_SHADOWS];

void fragment() {
	if (u_night_factor <= 0.005) {
		COLOR = vec4(0.0);
	} else {
		vec2 p = UV * u_canvas_size;
		vec2 to_pixel = p - u_player_screen_pos;
		float dist_sq = dot(to_pixel, to_pixel);
		
		float player_light = 0.0;
		if (dist_sq < u_beam_len * u_beam_len) {
			float dist = sqrt(dist_sq);
			if (dist < u_inner_radius) {
				player_light = smoothstep(u_inner_radius, u_inner_radius * 0.45, dist);
			}
			float angle = atan(to_pixel.y, to_pixel.x);
			float diff = abs(mod(angle - u_flashlight_angle + 3.14159265, 6.2831853) - 3.14159265);
			if (diff < u_cone_half) {
				float cone_fade = smoothstep(u_cone_half, u_cone_half - 0.09, diff);
				float beam_fade = smoothstep(u_beam_len, u_beam_len * 0.78, dist);
				float flash = cone_fade * beam_fade;
				for (int i = 0; i < u_shadow_count; i++) {
					vec2 to_obs = u_shadow_obs_pos[i] - u_player_screen_pos;
					float obs_dist_sq = dot(to_obs, to_obs);
					if (dist_sq > obs_dist_sq && obs_dist_sq > 64.0) {
						float obs_dist = sqrt(obs_dist_sq);
						float obs_angle = atan(to_obs.y, to_obs.x);
						float obs_diff = abs(mod(angle - obs_angle + 3.14159265, 6.2831853) - 3.14159265);
						float shadow_w = atan(u_shadow_obs_radius[i], obs_dist);
						if (obs_diff < shadow_w) {
							float shadow_edge = smoothstep(shadow_w, shadow_w * 0.82, obs_diff);
							flash *= (1.0 - shadow_edge);
						}
					}
				}
				player_light = max(player_light, flash);
			}
		}
		
		float max_ally_beam = u_beam_len * 0.96;
		float max_ally_beam_sq = max_ally_beam * max_ally_beam;
		float ally_inner = u_inner_radius * 1.25;
		for (int a = 0; a < u_ally_count; a++) {
			vec2 to_ally = p - u_ally_screen_pos[a];
			float ally_dist_sq = dot(to_ally, to_ally);
			if (ally_dist_sq < max_ally_beam_sq) {
				float ally_dist = sqrt(ally_dist_sq);
				if (ally_dist < ally_inner) {
					float a_inner = smoothstep(ally_inner, u_inner_radius * 0.42, ally_dist);
					player_light = max(player_light, a_inner);
				}
				float ally_ang = atan(to_ally.y, to_ally.x);
				float ally_diff = abs(mod(ally_ang - u_ally_flashlight_angle[a] + 3.14159265, 6.2831853) - 3.14159265);
				if (ally_diff < u_cone_half * 1.05) {
					float a_cone = smoothstep(u_cone_half * 1.05, u_cone_half * 0.65, ally_diff);
					float a_beam = smoothstep(max_ally_beam, u_beam_len * 0.58, ally_dist);
					player_light = max(player_light, a_cone * a_beam);
				}
			}
		}
		
		float ambient_light = 0.0;
		vec3 ambient_tint = vec3(0.0);
		for (int i = 0; i < u_light_count; i++) {
			vec2 dvec = p - u_light_pos[i];
			float r = u_light_radius[i];
			float d_sq = dot(dvec, dvec);
			if (d_sq < r * r) {
				float d = sqrt(d_sq);
				float l = smoothstep(r, r * 0.25, d) * u_light_color[i].a;
				ambient_light = max(ambient_light, l);
				ambient_tint += u_light_color[i].rgb * (l * 0.35);
			}
		}
		
		float total_light = clamp(player_light + ambient_light, 0.0, 1.0);
		float dark_alpha = (1.0 - total_light) * 0.96 * u_night_factor;
		vec3 dark_col = vec3(0.01, 0.01, 0.02) + ambient_tint;
		COLOR = vec4(dark_col, dark_alpha);
	}
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_darkness_shader()

func _setup_darkness_shader() -> void:
	if darkness_rect == null:
		darkness_rect = ColorRect.new()
		darkness_rect.name = "DarknessShaderRect"
		darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		darkness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		
		darkness_mat = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = DARKNESS_SHADER_CODE
		darkness_mat.shader = shader
		darkness_rect.material = darkness_mat
		darkness_rect.visible = false
		add_child(darkness_rect)
		move_child(darkness_rect, 0)

func set_night_factor(factor: float, dusk_warming: bool = true) -> void:
	night_factor = clampf(factor, 0.0, 1.0)
	night_mode_enabled = (night_factor >= 0.45)
	is_dusk_phase = dusk_warming
	
	if darkness_mat:
		darkness_mat.set_shader_parameter("u_night_factor", night_factor)
	if darkness_rect:
		darkness_rect.visible = (night_factor > 0.005)
	
	queue_redraw()

func set_night_mode(enabled: bool) -> void:
	set_night_factor(1.0 if enabled else 0.0, true)

var last_drawn_flashlight_pos: Vector2 = Vector2(-9999.0, -9999.0)
var last_drawn_flashlight_angle: float = -9999.0

# Pre-allocated shader uniform buffers to eliminate per-frame Array GC allocations
var _shadow_pos_buf: Array[Vector2] = []
var _shadow_rad_buf: Array[float] = []
var _light_pos_buf: Array[Vector2] = []
var _light_rad_buf: Array[float] = []
var _light_col_buf: Array[Vector4] = []
var _ally_pos_buf: Array[Vector2] = []
var _ally_ang_buf: Array[float] = []

func _ensure_shader_buffers() -> void:
	if _shadow_pos_buf.size() != 8:
		_shadow_pos_buf.resize(8)
		_shadow_rad_buf.resize(8)
	if _light_pos_buf.size() != 16:
		_light_pos_buf.resize(16)
		_light_rad_buf.resize(16)
		_light_col_buf.resize(16)
	if _ally_pos_buf.size() != 6:
		_ally_pos_buf.resize(6)
		_ally_ang_buf.resize(6)

func update_flashlight_transform(screen_pos: Vector2, angle_rad: float, occluders: Array = [], player_world_pos: Vector2 = Vector2.ZERO) -> void:
	flashlight_screen_pos = screen_pos
	flashlight_angle = angle_rad
	flashlight_occluders = occluders
	flashlight_player_world_pos = player_world_pos
	
	if darkness_mat and night_factor > 0.005:
		_ensure_shader_buffers()
		var c_size: Vector2 = size if size != Vector2.ZERO else get_viewport_rect().size
		darkness_mat.set_shader_parameter("u_canvas_size", c_size)
		darkness_mat.set_shader_parameter("u_player_screen_pos", screen_pos)
		darkness_mat.set_shader_parameter("u_flashlight_angle", angle_rad)
		darkness_mat.set_shader_parameter("u_inner_radius", lerpf(90.0, 52.0, night_factor))
		
		# Pass occluder shadows to shader (capped to 8 closest for high mobile FPS)
		var s_count := mini(occluders.size(), 8)
		for i in range(8):
			if i < s_count:
				var obs: Dictionary = occluders[i]
				var world_pos: Vector2 = obs["world_pos"]
				_shadow_pos_buf[i] = screen_pos + (world_pos - player_world_pos)
				_shadow_rad_buf[i] = float(obs.get("radius", 16.0))
			else:
				_shadow_pos_buf[i] = Vector2(-9999, -9999)
				_shadow_rad_buf[i] = 0.0
		
		darkness_mat.set_shader_parameter("u_shadow_count", s_count)
		darkness_mat.set_shader_parameter("u_shadow_obs_pos", _shadow_pos_buf)
		darkness_mat.set_shader_parameter("u_shadow_obs_radius", _shadow_rad_buf)
		
		# Re-project world ambient lights and ally flashlight cones every frame so stationary world lights never drift when player moves
		_sync_ambient_lights_to_shader(player_world_pos)
		_sync_ally_lights_to_shader(player_world_pos)
	
	if active_witches.size() > 0:
		for i in range(active_witches.size()):
			var w: Dictionary = active_witches[i]
			if w.has("world_pos"):
				w["screen_pos"] = flashlight_screen_pos + (Vector2(w["world_pos"]) - player_world_pos)
		if night_factor > 0.02:
			var pos_dist := flashlight_screen_pos.distance_squared_to(last_drawn_flashlight_pos)
			if pos_dist >= 4.0:
				last_drawn_flashlight_pos = flashlight_screen_pos
				queue_redraw()

func _sync_ambient_lights_to_shader(player_world_pos: Vector2) -> void:
	if not darkness_mat:
		return
	_ensure_shader_buffers()
	var l_count := mini(ambient_lights.size(), 16)
	for i in range(16):
		if i < l_count:
			var l: Dictionary = ambient_lights[i]
			var wpos: Vector2 = l["world_pos"]
			_light_pos_buf[i] = flashlight_screen_pos + (wpos - player_world_pos)
			_light_rad_buf[i] = float(l.get("radius", 140.0))
			var col: Color = l.get("color", Color(1.0, 1.0, 1.0, 1.0))
			_light_col_buf[i] = Vector4(col.r, col.g, col.b, col.a)
		else:
			_light_pos_buf[i] = Vector2(-9999, -9999)
			_light_rad_buf[i] = 0.0
			_light_col_buf[i] = Vector4(0, 0, 0, 0)
	
	darkness_mat.set_shader_parameter("u_light_count", l_count)
	darkness_mat.set_shader_parameter("u_light_pos", _light_pos_buf)
	darkness_mat.set_shader_parameter("u_light_radius", _light_rad_buf)
	darkness_mat.set_shader_parameter("u_light_color", _light_col_buf)

func _sync_ally_lights_to_shader(player_world_pos: Vector2) -> void:
	if not darkness_mat:
		return
	_ensure_shader_buffers()
	var a_count := mini(ally_flashlights.size(), 6)
	for i in range(6):
		if i < a_count:
			var a: Dictionary = ally_flashlights[i]
			var wpos: Vector2 = a["world_pos"]
			_ally_pos_buf[i] = flashlight_screen_pos + (wpos - player_world_pos)
			_ally_ang_buf[i] = float(a.get("angle", 0.0))
		else:
			_ally_pos_buf[i] = Vector2(-9999, -9999)
			_ally_ang_buf[i] = 0.0
	darkness_mat.set_shader_parameter("u_ally_count", a_count)
	darkness_mat.set_shader_parameter("u_ally_screen_pos", _ally_pos_buf)
	darkness_mat.set_shader_parameter("u_ally_flashlight_angle", _ally_ang_buf)

func update_ambient_lights(lights: Array, player_world_pos: Vector2 = Vector2.ZERO) -> void:
	ambient_lights = lights
	flashlight_player_world_pos = player_world_pos
	if darkness_mat and night_factor > 0.005:
		_sync_ambient_lights_to_shader(player_world_pos)

func update_ally_flashlights(allies: Array, player_world_pos: Vector2 = Vector2.ZERO) -> void:
	ally_flashlights = allies
	flashlight_player_world_pos = player_world_pos
	if darkness_mat and night_factor > 0.005:
		_sync_ally_lights_to_shader(player_world_pos)

func update_witch_eyes(witches: Array, player_world_pos: Vector2 = Vector2.ZERO) -> void:
	active_witches.clear()
	for w in witches:
		var wpos: Vector2 = w["pos"]
		var spos: Vector2 = flashlight_screen_pos + (wpos - player_world_pos)
		active_witches.append({
			"world_pos": wpos,
			"screen_pos": spos,
			"rot": float(w.get("rot", 0.0)),
			"is_enraged": w.get("is_enraged", false) == true,
			"eye_color": w.get("eye_color", Color(0.95, 0.05, 0.05, 1.0))
		})
	if active_witches.size() > 0 and night_factor > 0.02:
		queue_redraw()

func _process(delta: float) -> void:
	pulse_time += delta
	var needs_redraw: bool = false
	
	if bite_flash_alpha > 0.0:
		bite_flash_alpha = maxf(0.0, bite_flash_alpha - delta * 2.2)
		needs_redraw = true
	
	if low_health_ratio < 0.35:
		needs_redraw = true
	
	if pov_blood_drops.size() > 0:
		needs_redraw = true
		for i in range(pov_blood_drops.size() - 1, -1, -1):
			var drop: Dictionary = pov_blood_drops[i]
			drop["age"] = float(drop["age"]) + delta
			if float(drop["age"]) >= float(drop["lifetime"]):
				pov_blood_drops.remove_at(i)
			else:
				var cur_drip: float = float(drop["drip_len"])
				var max_drip: float = float(drop["max_drip"])
				if cur_drip < max_drip:
					drop["drip_len"] = minf(max_drip, cur_drip + float(drop["drip_speed"]) * delta)
	
	if needs_redraw:
		queue_redraw()

func set_health_ratio(ratio: float) -> void:
	low_health_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func trigger_bite_pov_splatter(hit_dir: Vector2 = Vector2.ZERO, damage: float = 15.0) -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	bite_flash_alpha = clampf(bite_flash_alpha + 0.55, 0.0, 0.85)
	if hit_dir != Vector2.ZERO:
		last_bite_dir = hit_dir.normalized()
	else:
		last_bite_dir = Vector2.RIGHT.rotated(randf() * TAU)
	
	var count := clampi(int(6 + damage * 0.35), 7, 16)
	var center := vp * 0.5
	
	for i in range(count):
		var edge_bias := -last_bite_dir
		var pos: Vector2
		if i < int(count * 0.65) and edge_bias != Vector2.ZERO:
			var spread_ang := edge_bias.angle() + randf_range(-0.95, 0.95)
			var rx := vp.x * randf_range(0.28, 0.47)
			var ry := vp.y * randf_range(0.26, 0.46)
			pos = center + Vector2(cos(spread_ang) * rx, sin(spread_ang) * ry)
		else:
			pos = Vector2(randf_range(80.0, vp.x - 80.0), randf_range(65.0, vp.y - 95.0))
		
		var sub_dots: Array[Vector3] = []
		for s in range(randi_range(3, 6)):
			var sa := randf() * TAU
			var sd := randf_range(12.0, 36.0)
			sub_dots.append(Vector3(cos(sa) * sd, sin(sa) * sd, randf_range(2.5, 7.5)))
		
		pov_blood_drops.append({
			"pos": pos,
			"radius": randf_range(14.0, 34.0),
			"drip_len": 0.0,
			"max_drip": randf_range(42.0, 135.0),
			"drip_speed": randf_range(24.0, 52.0),
			"age": 0.0,
			"lifetime": randf_range(3.2, 4.8),
			"dark": (i % 2 == 0),
			"is_claw": (i == 0),
			"sub_dots": sub_dots
		})
	
	while pov_blood_drops.size() > 36:
		pov_blood_drops.remove_at(0)
	
	queue_redraw()

func _draw() -> void:
	var vp := get_viewport_rect().size
	if vp == Vector2.ZERO:
		vp = Vector2(1280, 720)
	
	# 1. Atmospheric Sunset/Dusk or Dawn glaze during twilight transition
	if night_factor > 0.01:
		var twilight_bell := sin(clampf(night_factor, 0.0, 1.0) * PI)
		if twilight_bell > 0.02:
			var tint_col := Color(0.26, 0.09, 0.03, twilight_bell * 0.22) if is_dusk_phase else Color(0.06, 0.12, 0.24, twilight_bell * 0.20)
			draw_rect(Rect2(Vector2.ZERO, vp), tint_col, true)
	
	# 2. Witch Glowing Crimson Eyes piercing pitch darkness
	if night_factor > 0.05 and active_witches.size() > 0:
		for w in active_witches:
			var spos: Vector2 = w["screen_pos"]
			if spos.x < -80 or spos.x > vp.x + 80 or spos.y < -80 or spos.y > vp.y + 80:
				continue
			var w_rot: float = float(w.get("rot", 0.0))
			var is_enr: bool = w.get("is_enraged", false) == true
			
			var fwd := Vector2(7.0, 0.0).rotated(w_rot)
			var perp := Vector2(-fwd.y, fwd.x).normalized()
			var eye_l := spos + fwd + perp * 2.8
			var eye_r := spos + fwd - perp * 2.8
			
			var p_glow := 0.65 + 0.35 * sin(pulse_time * 8.0)
			var base_eye: Color = w.get("eye_color", Color(0.95, 0.05, 0.05, 1.0))
			var glow_col := Color(base_eye.r, base_eye.g, base_eye.b, (0.38 if not is_enr else 0.68) * p_glow)
			var pupil_col := Color(minf(1.0, base_eye.r + 0.15), minf(1.0, base_eye.g + 0.15), minf(1.0, base_eye.b + 0.15), 0.98) if not is_enr else Color(1.0, 0.85, 0.2, 1.0)
			
			# Outer crimson glare aura
			draw_circle(spos + fwd, 10.0 if not is_enr else 14.0, glow_col)
			# Left eye glint
			draw_circle(eye_l, 2.2 if is_enr else 1.8, pupil_col)
			# Right eye glint
			draw_circle(eye_r, 2.2 if is_enr else 1.8, pupil_col)
	
	# 3. Dark atmospheric horror border framing & corner shadows
	var border_col := Color(0.01, 0.01, 0.02, 0.58)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 34)), border_col, true)
	draw_rect(Rect2(0, vp.y - 34, vp.x, 34), border_col, true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(38, vp.y)), border_col, true)
	draw_rect(Rect2(vp.x - 38, 0, 38, vp.y), border_col, true)
	
	# 4. Immediate crimson bite shockwave border flash
	if bite_flash_alpha > 0.01:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.72, 0.03, 0.04, bite_flash_alpha * 0.42), false, 54.0)
		draw_rect(Rect2(Vector2(18, 18), vp - Vector2(36, 36)), Color(0.52, 0.02, 0.02, bite_flash_alpha * 0.25), false, 28.0)
	
	# 5. POV Blood Splatters, Claw Gashes & Dripping Streaks on Camera Lens
	for drop in pov_blood_drops:
		var age: float = float(drop["age"])
		var life: float = float(drop["lifetime"])
		var fade := clampf(1.0 - maxf(0.0, (age - life * 0.55) / (life * 0.45)), 0.0, 1.0)
		var p: Vector2 = drop["pos"]
		var r: float = float(drop["radius"])
		var drip: float = float(drop["drip_len"])
		var base_col := Color(0.46, 0.02, 0.03, 0.80 * fade) if drop["dark"] else Color(0.68, 0.05, 0.06, 0.76 * fade)
		var core_col := Color(0.28, 0.01, 0.02, 0.88 * fade)
		
		draw_circle(p, r, base_col)
		draw_circle(p + Vector2(-r * 0.2, -r * 0.15), r * 0.65, core_col)
		
		var subs: Array = drop["sub_dots"]
		for sv in subs:
			var v3: Vector3 = sv
			draw_circle(p + Vector2(v3.x, v3.y), v3.z, base_col)
		
		if drip > 2.0:
			var drip_end := p + Vector2(0.0, r * 0.5 + drip)
			draw_line(p + Vector2(0.0, r * 0.3), drip_end, base_col, maxf(3.0, r * 0.26), true)
			draw_circle(drip_end, maxf(3.5, r * 0.22), core_col)
		
		if drop["is_claw"]:
			for c_idx in range(-1, 2):
				var offset := Vector2(c_idx * 16.0, c_idx * 6.0)
				draw_line(p + offset + Vector2(-34, -28), p + offset + Vector2(34, 28), Color(0.78, 0.04, 0.04, 0.85 * fade), 4.5, true)
	
	# 6. Low-health blood heartbeat vignette when HP < 40%
	if low_health_ratio < 0.40:
		var intensity := (0.40 - low_health_ratio) / 0.40
		var beat := 0.55 + 0.45 * sin(pulse_time * 7.5)
		var red_alpha := intensity * beat * 0.38
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.58, 0.03, 0.04, red_alpha), false, 40.0)
