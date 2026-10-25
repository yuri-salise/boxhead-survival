extends Control

signal dash_pressed()
signal grenade_pressed()
signal switch_weapon_pressed()

@export var joystick_radius: float = 68.0
@export var knob_radius: float = 28.0
@export var deadzone: float = 0.14

# Centers in 1280x720 landscape viewport with safe-area margins for phone notches/bezels
var left_center: Vector2 = Vector2(148.0, 565.0)
var right_center: Vector2 = Vector2(1115.0, 565.0)

var move_touch_idx: int = -1
var aim_touch_idx: int = -1

var move_vector: Vector2 = Vector2.ZERO
var aim_vector: Vector2 = Vector2.ZERO
var is_firing: bool = false

# Button states for visual feedback
var dash_cooldown_ratio: float = 0.0
var grenade_count: int = 2
var current_weapon_label: String = "9MM PISTOL [INF]"

@onready var dash_btn: Button = $DashButton
@onready var grenade_btn: Button = $GrenadeButton
@onready var weapon_btn: Button = $WeaponSwitchButton

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	if dash_btn:
		dash_btn.pressed.connect(func(): dash_pressed.emit())
	if grenade_btn:
		grenade_btn.pressed.connect(func(): grenade_pressed.emit())
	if weapon_btn:
		weapon_btn.pressed.connect(func(): switch_weapon_pressed.emit())
	
	_update_button_labels()

func set_dash_cooldown(cd_left: float, cd_max: float) -> void:
	dash_cooldown_ratio = clampf(cd_left / maxf(0.01, cd_max), 0.0, 1.0)
	if dash_btn:
		if cd_left <= 0.02:
			dash_btn.text = "DASH"
			dash_btn.disabled = false
		else:
			dash_btn.text = String.num(cd_left, 1) + "s"
			dash_btn.disabled = true
	queue_redraw()

func set_grenade_count(count: int) -> void:
	grenade_count = count
	_update_button_labels()

func set_weapon_display(w_text: String) -> void:
	current_weapon_label = w_text
	_update_button_labels()

func _update_button_labels() -> void:
	if grenade_btn:
		grenade_btn.text = "FRAG (" + str(grenade_count) + ")"
		grenade_btn.disabled = (grenade_count <= 0)
	if weapon_btn:
		weapon_btn.text = "GUN: " + current_weapon_label

func is_using_touch_input() -> bool:
	return move_touch_idx != -1 or aim_touch_idx != -1

func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		reset_sticks()
		return
	
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			# Ignore touches that land directly on action buttons
			if _is_point_on_action_buttons(touch.position):
				return
			
			if touch.position.distance_to(left_center) <= joystick_radius * 1.55 and move_touch_idx == -1:
				move_touch_idx = touch.index
				_update_move_stick(touch.position)
			elif touch.position.distance_to(right_center) <= joystick_radius * 1.55 and aim_touch_idx == -1:
				aim_touch_idx = touch.index
				_update_aim_stick(touch.position)
		else:
			if touch.index == move_touch_idx:
				move_touch_idx = -1
				move_vector = Vector2.ZERO
				queue_redraw()
			elif touch.index == aim_touch_idx:
				aim_touch_idx = -1
				is_firing = false
				queue_redraw()
	
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == move_touch_idx:
			_update_move_stick(drag.position)
		elif drag.index == aim_touch_idx:
			_update_aim_stick(drag.position)

func _is_point_on_action_buttons(pt: Vector2) -> bool:
	for btn in [dash_btn, grenade_btn, weapon_btn]:
		if is_instance_valid(btn) and btn.get_global_rect().has_point(pt):
			return true
	return false

func _update_move_stick(touch_pos: Vector2) -> void:
	var delta_vec := touch_pos - left_center
	var dist := delta_vec.length()
	var norm_dist := clampf(dist / joystick_radius, 0.0, 1.0)
	if norm_dist < deadzone:
		move_vector = Vector2.ZERO
	else:
		move_vector = delta_vec.normalized() * norm_dist
	queue_redraw()

func _update_aim_stick(touch_pos: Vector2) -> void:
	var delta_vec := touch_pos - right_center
	var dist := delta_vec.length()
	var norm_dist := clampf(dist / joystick_radius, 0.0, 1.0)
	if norm_dist >= deadzone:
		aim_vector = delta_vec.normalized()
		is_firing = true
	else:
		is_firing = false
	queue_redraw()

func reset_sticks() -> void:
	move_touch_idx = -1
	aim_touch_idx = -1
	move_vector = Vector2.ZERO
	is_firing = false
	queue_redraw()

func simulate_stick_input(new_move: Vector2, new_aim: Vector2, firing: bool) -> void:
	move_touch_idx = 0 if new_move != Vector2.ZERO else -1
	aim_touch_idx = 1 if (new_aim != Vector2.ZERO or firing) else -1
	move_vector = new_move.limit_length(1.0)
	aim_vector = new_aim.normalized() if new_aim != Vector2.ZERO else Vector2.RIGHT
	is_firing = firing
	queue_redraw()

func _draw() -> void:
	# 1. Left Virtual Joystick (Movement)
	draw_circle(left_center, joystick_radius, Color(0.08, 0.09, 0.11, 0.52))
	draw_arc(left_center, joystick_radius, 0.0, TAU, 36, Color(0.55, 0.60, 0.65, 0.55), 2.5)
	draw_arc(left_center, joystick_radius * 0.35, 0.0, TAU, 20, Color(0.45, 0.50, 0.55, 0.25), 1.5)
	
	# Crosshair direction ticks on left stick
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2.from_angle(a)
		draw_line(left_center + d * (joystick_radius * 0.72), left_center + d * (joystick_radius * 0.92), Color(0.65, 0.70, 0.75, 0.40), 2.0)
	
	var left_knob_pos := left_center + move_vector * joystick_radius
	var left_active := (move_touch_idx != -1)
	draw_circle(left_knob_pos, knob_radius, Color(0.28, 0.34, 0.26, 0.88) if left_active else Color(0.20, 0.23, 0.26, 0.72))
	draw_arc(left_knob_pos, knob_radius, 0.0, TAU, 24, Color(0.75, 0.82, 0.75, 0.85), 2.2)
	
	# 2. Right Virtual Joystick (Aim & Auto-Fire)
	draw_circle(right_center, joystick_radius, Color(0.11, 0.07, 0.08, 0.52))
	var right_ring_col := Color(0.92, 0.25, 0.22, 0.80) if is_firing else Color(0.70, 0.24, 0.24, 0.58)
	draw_arc(right_center, joystick_radius, 0.0, TAU, 36, right_ring_col, 2.8)
	draw_arc(right_center, joystick_radius * 0.35, 0.0, TAU, 20, Color(0.75, 0.25, 0.25, 0.28), 1.5)
	
	for a in [0.0, PI * 0.5, PI, PI * 1.5]:
		var d := Vector2.from_angle(a)
		draw_line(right_center + d * (joystick_radius * 0.72), right_center + d * (joystick_radius * 0.92), Color(0.85, 0.35, 0.35, 0.45), 2.0)
	
	var right_offset := aim_vector * (joystick_radius * 0.85) if is_firing else Vector2.ZERO
	var right_knob_pos := right_center + right_offset
	draw_circle(right_knob_pos, knob_radius, Color(0.78, 0.18, 0.18, 0.90) if is_firing else Color(0.38, 0.16, 0.16, 0.75))
	draw_arc(right_knob_pos, knob_radius, 0.0, TAU, 24, Color(1.0, 0.55, 0.50, 0.90), 2.2)
