extends Node2D

enum SectorBiome {
	QUARANTINE = 1,
	THE_STREET = 2,
	FOREST = 2,
	NO_EXIT = 3,
	SWAMP = 3,
	THE_DEPOT = 4,
	VILLAGE = 4,
	LAST_LIGHT = 5,
	URBAN = 5
}

const CHUNK_SIZE: float = 640.0
const SHADOW_VEC: Vector2 = Vector2(14.0, 18.0)

@export var sector_type: int = SectorBiome.QUARANTINE:
	set(val):
		if sector_type != val:
			sector_type = val
			chunk_cache.clear()
			clear_colliders()
			queue_redraw()

@export var graphics_quality: int = 1: # 0 = Low (Mobile Saver), 1 = Medium (Balanced), 2 = High (Full Visuals)
	set(val):
		graphics_quality = clampi(val, 0, 2)
		chunk_cache.clear()
		clear_colliders()
		queue_redraw()

var focus_position: Vector2 = Vector2(640.0, 360.0)
var beacon_time: float = 0.0
var night_factor: float = 0.0
var chunk_cache: Dictionary = {}

var last_redraw_pos: Vector2 = Vector2(-9999.0, -9999.0)
var redraw_timer: float = 0.0

var collider_container: Node2D = null
var active_colliders: Dictionary = {} # Key: "{cx}_{cy}", Value: Array[StaticBody2D]
var current_collider_center: Vector2i = Vector2i(-9999, -9999)

func _ready() -> void:
	if not collider_container:
		collider_container = Node2D.new()
		collider_container.name = "ObstacleColliders"
		add_child(collider_container)
	current_collider_center = get_chunk_coords(focus_position)
	_update_active_colliders()
	
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_signal("settings_changed"):
		if not gs.settings_changed.is_connected(_on_global_settings_changed):
			gs.settings_changed.connect(_on_global_settings_changed)
		if "graphics_quality" in gs:
			graphics_quality = int(gs.graphics_quality)

func _on_global_settings_changed(setting_name: String, value: Variant) -> void:
	if setting_name == "graphics_quality":
		set_graphics_quality(int(value))

func clear_colliders() -> void:
	for k in active_colliders.keys():
		var list: Array = active_colliders[k]
		for b in list:
			if is_instance_valid(b):
				b.queue_free()
	active_colliders.clear()
	current_collider_center = Vector2i(-9999, -9999)
	if is_inside_tree():
		_update_active_colliders()

func set_focus_position(pos: Vector2) -> void:
	focus_position = pos
	var center_chunk := get_chunk_coords(focus_position)
	if center_chunk != current_collider_center:
		current_collider_center = center_chunk
		if is_inside_tree():
			_update_active_colliders()
		queue_redraw()

func set_night_factor(factor: float) -> void:
	var old := night_factor
	night_factor = clampf(factor, 0.0, 1.0)
	if absf(night_factor - old) > 0.08:
		queue_redraw()

func set_graphics_quality(quality: int) -> void:
	self.graphics_quality = quality

func set_sector_type(type: int) -> void:
	self.sector_type = type

func get_chunk_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CHUNK_SIZE)), int(floor(world_pos.y / CHUNK_SIZE)))

func get_speed_multiplier_at(world_pos: Vector2) -> float:
	if sector_type != SectorBiome.NO_EXIT:
		return 1.0
	
	# Sector 3 No Exit: Muddy alley sludge & sewage runoff slows movement down
	var cx := int(floor(world_pos.x / CHUNK_SIZE))
	var cy := int(floor(world_pos.y / CHUNK_SIZE))
	var chunk := _get_chunk_data(cx, cy)
	
	# Deep mire water pools slow down heavily (0.65x)
	var pools: Array = chunk.get("water_pools", [])
	for p in pools:
		var p_pos: Vector2 = p["pos"]
		var r: float = float(p["radius"])
		if world_pos.distance_to(p_pos) <= r:
			return 0.65
	
	# Mud patches and marshland slow down moderately (0.76x)
	return 0.76

func get_nearby_obstacles(center_pos: Vector2, max_dist: float = 550.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center_chunk := get_chunk_coords(center_pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var chunk := _get_chunk_data(center_chunk.x + dx, center_chunk.y + dy)
			var s: int = int(chunk.get("sector", 1))
			for p in chunk.get("props", []):
				var pos: Vector2 = p["pos"]
				var d := pos.distance_to(center_pos)
				if d <= max_dist:
					var r: float = 16.0
					var kind: int = p.get("kind", 0)
					match s:
						SectorBiome.THE_STREET:
							r = 34.0 if kind == 0 else (36.0 if kind == 1 else (50.0 if kind == 2 else 16.0))
						SectorBiome.NO_EXIT:
							r = 26.0 if kind == 0 else (16.0 if kind == 1 else 18.0)
						SectorBiome.THE_DEPOT:
							r = 20.0 if kind == 0 else (14.0 if kind == 1 else 8.0)
						SectorBiome.LAST_LIGHT:
							r = 30.0 if kind == 0 else (24.0 if kind == 1 else (8.0 if kind == 2 else 22.0))
						_: # Quarantine
							r = 14.0 if kind == 0 else (24.0 if kind == 1 else 8.0)
					result.append({
						"world_pos": pos,
						"radius": r,
						"kind": kind
					})
			for b in chunk.get("buildings", []):
				var b_pos: Vector2 = b["pos"]
				var b_sz: Vector2 = b["size"]
				if b_pos.distance_to(center_pos) <= max_dist + b_sz.length() * 0.5:
					result.append({
						"world_pos": b_pos,
						"radius": b_sz.length() * 0.40,
						"kind": 99
					})
	return result

func get_ambient_lights(center_pos: Vector2, max_dist: float = 750.0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var center_chunk := get_chunk_coords(center_pos)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var chunk := _get_chunk_data(center_chunk.x + dx, center_chunk.y + dy)
			var s: int = int(chunk.get("sector", 1))
			for p in chunk.get("props", []):
				var pos: Vector2 = p["pos"]
				var d := pos.distance_to(center_pos)
				if d <= max_dist:
					var kind: int = p.get("kind", 0)
					if s == SectorBiome.QUARANTINE and kind == 2:
						result.append({
							"world_pos": pos,
							"radius": 135.0,
							"color": Color(1.0, 0.42, 0.18, 0.85)
						})
					elif s == SectorBiome.THE_STREET and kind == 4:
						result.append({
							"world_pos": pos,
							"radius": 180.0,
							"color": Color(1.0, 0.82, 0.48, 0.90)
						})
					elif s == SectorBiome.NO_EXIT and kind == 3:
						result.append({
							"world_pos": pos,
							"radius": 85.0,
							"color": Color(0.25, 0.85, 0.30, 0.65)
						})
					elif s == SectorBiome.THE_DEPOT and kind == 2:
						result.append({
							"world_pos": pos,
							"radius": 210.0,
							"color": Color(0.95, 0.90, 0.65, 0.95)
						})
					elif s == SectorBiome.LAST_LIGHT and (kind == 0 or kind == 2):
						result.append({
							"world_pos": pos,
							"radius": 240.0 if kind == 0 else 170.0,
							"color": Color(0.75, 0.90, 1.0, 0.95)
						})
	return result
	return result

func _update_active_colliders() -> void:
	if not is_inside_tree() or not is_instance_valid(collider_container):
		return
	
	var radius := 1 if graphics_quality == 0 else 2
	var needed_keys: Dictionary = {}
	
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cx := current_collider_center.x + dx
			var cy := current_collider_center.y + dy
			var key := str(cx) + "_" + str(cy)
			needed_keys[key] = Vector2i(cx, cy)
	
	# Evict colliders from chunks that are no longer in radius
	var old_keys := active_colliders.keys()
	for k in old_keys:
		if not needed_keys.has(k):
			var bodies: Array = active_colliders[k]
			for b in bodies:
				if is_instance_valid(b):
					b.queue_free()
			active_colliders.erase(k)
	
	# Create colliders for newly entered chunks
	for k in needed_keys.keys():
		if not active_colliders.has(k):
			var coords: Vector2i = needed_keys[k]
			var bodies := _spawn_chunk_colliders(coords.x, coords.y)
			active_colliders[k] = bodies

func _spawn_chunk_colliders(cx: int, cy: int) -> Array[StaticBody2D]:
	var bodies: Array[StaticBody2D] = []
	if not is_inside_tree() or not is_instance_valid(collider_container):
		return bodies
	
	var chunk := _get_chunk_data(cx, cy)
	var sector: int = int(chunk.get("sector", 1))
	
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var rot: float = float(p.get("rot", 0.0))
		
		var body := StaticBody2D.new()
		body.position = pos
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("obstacles")
		
		var col_shape := CollisionShape2D.new()
		var shape_created := false
		
		match sector:
			SectorBiome.THE_STREET:
				if kind == 0: # Sedan car wreck
					var r := RectangleShape2D.new()
					r.size = Vector2(34.0, 66.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 1: # Police cruiser / ambulance
					var r := RectangleShape2D.new()
					r.size = Vector2(36.0, 72.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 2: # Heavy SWAT Van / Bus / Truck
					var r := RectangleShape2D.new()
					r.size = Vector2(42.0, 108.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 3: # Jersey concrete barrier
					var r := RectangleShape2D.new()
					r.size = Vector2(16.0, 50.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 4: # Streetlight pole
					var c := CircleShape2D.new()
					c.radius = 6.0
					col_shape.shape = c
					shape_created = true
			SectorBiome.NO_EXIT:
				if kind == 0: # Heavy industrial dumpster
					var r := RectangleShape2D.new()
					r.size = Vector2(50.0, 30.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 1: # Chainlink security fence
					var r := RectangleShape2D.new()
					r.size = Vector2(60.0, 8.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 2: # Pallets / trash pile
					var r := RectangleShape2D.new()
					r.size = Vector2(34.0, 34.0)
					col_shape.shape = r
					shape_created = true
			SectorBiome.THE_DEPOT:
				if kind == 0: # Supply crate stack
					var r := RectangleShape2D.new()
					r.size = Vector2(32.0, 32.0)
					col_shape.shape = r
					shape_created = true
				elif kind == 1: # Oil drum cluster
					var c := CircleShape2D.new()
					c.radius = 14.0
					col_shape.shape = c
					shape_created = true
				elif kind == 2: # Floodlight mast
					var c := CircleShape2D.new()
					c.radius = 8.0
					col_shape.shape = c
					shape_created = true
			SectorBiome.LAST_LIGHT:
				if kind == 0: # Diesel Generator Station
					var r := RectangleShape2D.new()
					r.size = Vector2(54.0, 38.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 1: # Sandbag fortification
					var r := RectangleShape2D.new()
					r.size = Vector2(68.0, 16.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 2: # Floodlight pole
					var c := CircleShape2D.new()
					c.radius = 7.0
					col_shape.shape = c
					shape_created = true
				elif kind == 3: # Stone monument / planter
					var r := RectangleShape2D.new()
					r.size = Vector2(42.0, 42.0)
					col_shape.shape = r
					shape_created = true
			_: # Quarantine
				if kind == 0:
					var c := CircleShape2D.new()
					c.radius = 13.0
					col_shape.shape = c
					shape_created = true
				elif kind == 1:
					var r := RectangleShape2D.new()
					r.size = Vector2(52.0, 16.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 2:
					var c := CircleShape2D.new()
					c.radius = 6.0
					col_shape.shape = c
					shape_created = true
		
		if shape_created:
			body.add_child(col_shape)
			collider_container.add_child(body)
			bodies.append(body)
		else:
			body.queue_free()
	
	for b in chunk.get("buildings", []):
		var b_pos: Vector2 = b["pos"]
		var b_sz: Vector2 = b["size"]
		var b_rot: float = float(b.get("rot", 0.0))
		
		var wall_body := StaticBody2D.new()
		wall_body.position = b_pos
		wall_body.rotation = b_rot
		wall_body.collision_layer = 1
		wall_body.collision_mask = 0
		wall_body.add_to_group("obstacles")
		
		var col := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = b_sz
		col.shape = rect_shape
		wall_body.add_child(col)
		
		collider_container.add_child(wall_body)
		bodies.append(wall_body)
	
	return bodies

func _process(delta: float) -> void:
	beacon_time += delta

func _get_chunk_data(cx: int, cy: int) -> Dictionary:
	var key := str(sector_type) + "_" + str(cx) + "_" + str(cy)
	if chunk_cache.has(key):
		return chunk_cache[key]
	
	if chunk_cache.size() > 72:
		chunk_cache.clear()
	
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cx, cy, sector_type)) ^ 0x5F3759DF
	
	var origin := Vector2(cx * CHUNK_SIZE, cy * CHUNK_SIZE)
	var data: Dictionary = {
		"origin": origin,
		"cx": cx,
		"cy": cy,
		"sector": sector_type
	}
	
	match sector_type:
		SectorBiome.THE_STREET:
			_generate_street_chunk(data, origin, cx, cy, rng)
		SectorBiome.NO_EXIT:
			_generate_alley_chunk(data, origin, cx, cy, rng)
		SectorBiome.THE_DEPOT:
			_generate_depot_chunk(data, origin, cx, cy, rng)
		SectorBiome.LAST_LIGHT:
			_generate_plaza_chunk(data, origin, cx, cy, rng)
		_:
			_generate_quarantine_chunk(data, origin, cx, cy, rng)
	
	chunk_cache[key] = data
	return data

# ==============================================================================
# PROCEDURAL CHUNK GENERATORS PER SECTOR BIOME
# ==============================================================================

# --- Level 1: Outpost Quarantine ---
func _generate_quarantine_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var cracks: Array[Array] = []
	var crack_count := 3 if graphics_quality == 0 else 6
	for i in range(crack_count):
		var start_p := origin + Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40))
		var pts: Array[Vector2] = [start_p]
		var cur := start_p
		var ang := rng.randf() * TAU
		for step in range(rng.randi_range(3, 5)):
			ang += rng.randf_range(-0.65, 0.65)
			cur += Vector2.from_angle(ang) * rng.randf_range(16.0, 36.0)
			pts.append(cur)
		cracks.append(pts)
	
	var stains: Array[Dictionary] = []
	var stain_count := 4 if graphics_quality == 0 else 8
	for i in range(stain_count):
		stains.append({
			"pos": origin + Vector2(rng.randf_range(24, CHUNK_SIZE - 24), rng.randf_range(24, CHUNK_SIZE - 24)),
			"radius": rng.randf_range(6.0, 20.0),
			"dark": rng.randf() < 0.65
		})
	
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(1, 2) if graphics_quality == 0 else rng.randi_range(2, 4)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(80.0, CHUNK_SIZE - 80.0), rng.randf_range(80.0, CHUNK_SIZE - 80.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = barrel, 1 = roadblock, 2 = beacon
			"rot": rng.randf_range(-0.45, 0.45)
		})
	
	data["cracks"] = cracks
	data["stains"] = stains
	data["props"] = props
	data["has_ew_road"] = (absi(cy) % 2 == 0)
	data["has_ns_road"] = (absi(cx) % 2 == 1)

# --- Level 2: The Street (Abandoned vehicle barricades creating vertical sightlines) ---
func _generate_street_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var foliage_patches: Array[Dictionary] = []
	var fol_count := 2 if graphics_quality == 0 else 5
	for i in range(fol_count):
		foliage_patches.append({
			"pos": origin + Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30)),
			"radius": rng.randf_range(10.0, 22.0),
			"moss": false
		})
	
	# Abandoned Vehicle Barricades: Staggered along north-south vertical columns
	# to create distinct, open vertical sightlines and shooting corridors
	var props: Array[Dictionary] = []
	var col_xs := [origin.x + 160.0, origin.x + 320.0, origin.x + 480.0]
	var count := 2 if graphics_quality == 0 else rng.randi_range(3, 5)
	
	for i in range(count):
		var base_x: float = col_xs[rng.randi() % col_xs.size()] + rng.randf_range(-25.0, 25.0)
		var base_y: float = origin.y + rng.randf_range(70.0, CHUNK_SIZE - 70.0)
		var p_pos := Vector2(base_x, base_y)
		if p_pos.distance_to(Vector2(640, 360)) < 140.0:
			continue
		
		# 0 = Sedan car wreck, 1 = Police cruiser/ambulance, 2 = SWAT van/Truck, 3 = Jersey concrete barrier, 4 = Streetlight
		var k := rng.randi() % 5
		# Keep rotation vertical to channel players/zombies into vertical lanes
		var rot: float = rng.randf_range(-0.12, 0.12) if (rng.randf() < 0.85) else (PI * 0.5 + rng.randf_range(-0.1, 0.1))
		props.append({
			"pos": p_pos,
			"kind": k,
			"rot": rot,
			"color_variant": rng.randi() % 4
		})
	
	data["foliage"] = foliage_patches
	data["props"] = props
	data["has_ns_road"] = true
	data["has_ew_road"] = (absi(cy) % 3 == 0)

# --- Level 3: No Exit (Tight alley choke points forcing close-quarters defense) ---
func _generate_alley_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var water_pools: Array[Dictionary] = []
	var pool_count := 2 if graphics_quality == 0 else rng.randi_range(2, 4)
	for i in range(pool_count):
		water_pools.append({
			"pos": origin + Vector2(rng.randf_range(80, CHUNK_SIZE - 80), rng.randf_range(80, CHUNK_SIZE - 80)),
			"radius": rng.randf_range(26.0, 48.0)
		})
	
	var mud_patches: Array[Dictionary] = []
	var mud_count := 3 if graphics_quality == 0 else 5
	for i in range(mud_count):
		mud_patches.append({
			"pos": origin + Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40)),
			"radius": rng.randf_range(20.0, 45.0)
		})
	
	# Tight Alley Brick Chokepoint Walls
	var buildings: Array[Dictionary] = []
	if (abs(cx - 1) + abs(cy)) > 0:
		var wall_type := rng.randi() % 3
		if wall_type == 0:
			# Horizontal choke wall leaving an 80px bottleneck
			buildings.append({
				"pos": origin + Vector2(160.0, CHUNK_SIZE * 0.5),
				"size": Vector2(240.0, 24.0),
				"rot": 0.0
			})
			buildings.append({
				"pos": origin + Vector2(520.0, CHUNK_SIZE * 0.5),
				"size": Vector2(160.0, 24.0),
				"rot": 0.0
			})
		elif wall_type == 1:
			# Vertical choke wall
			buildings.append({
				"pos": origin + Vector2(CHUNK_SIZE * 0.5, 180.0),
				"size": Vector2(24.0, 260.0),
				"rot": 0.0
			})
			buildings.append({
				"pos": origin + Vector2(CHUNK_SIZE * 0.5, 520.0),
				"size": Vector2(24.0, 160.0),
				"rot": 0.0
			})
		else:
			# Corner alley choke
			buildings.append({
				"pos": origin + Vector2(200.0, 200.0),
				"size": Vector2(180.0, 24.0),
				"rot": 0.0
			})
			buildings.append({
				"pos": origin + Vector2(200.0, 320.0),
				"size": Vector2(24.0, 220.0),
				"rot": 0.0
			})
	
	# Alley Props: Industrial Dumpsters, Chainlink Gates, Pallet Barricades, Steam Vents
	var props: Array[Dictionary] = []
	var prop_count := 2 if graphics_quality == 0 else rng.randi_range(3, 5)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(70.0, CHUNK_SIZE - 70.0), rng.randf_range(70.0, CHUNK_SIZE - 70.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 4, # 0 = Dumpster, 1 = Chainlink Gate, 2 = Pallet Stack, 3 = Steaming Grate
			"rot": rng.randf_range(-0.35, 0.35)
		})
	
	data["water_pools"] = water_pools
	data["mud_patches"] = mud_patches
	data["buildings"] = buildings
	data["props"] = props

# --- Level 4: The Depot (Warehouse storage container maze with blind corners) ---
func _generate_depot_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	# Interlocking 20ft/40ft shipping container maze with 90° blind corners
	var buildings: Array[Dictionary] = []
	var container_colors := [
		Color(0.65, 0.18, 0.16), # Freight Red
		Color(0.18, 0.36, 0.58), # Marine Blue
		Color(0.28, 0.38, 0.22), # Cargo Olive
		Color(0.68, 0.38, 0.16)  # Rust Orange
	]
	
	var is_spawn_chunk := (cx == 1 and cy == 0)
	var slots: Array[Vector2] = [
		Vector2(160, 160), Vector2(480, 160),
		Vector2(160, 480), Vector2(480, 480)
	]
	
	for slot in slots:
		var p_pos: Vector2 = origin + slot
		if is_spawn_chunk and p_pos.distance_to(Vector2(640, 360)) < 160.0:
			continue
		
		var is_vert := (rng.randf() < 0.5)
		var c_sz := Vector2(48.0, 120.0) if is_vert else Vector2(120.0, 48.0)
		buildings.append({
			"pos": p_pos,
			"size": c_sz,
			"rot": 0.0,
			"color": container_colors[rng.randi() % container_colors.size()]
		})
	
	var props: Array[Dictionary] = []
	var prop_count := 2 if graphics_quality == 0 else rng.randi_range(3, 5)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(80.0, CHUNK_SIZE - 80.0), rng.randf_range(80.0, CHUNK_SIZE - 80.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = Crate stack, 1 = Oil drum cluster, 2 = Floodlight mast
			"rot": rng.randf_range(-PI, PI)
		})
	
	data["buildings"] = buildings
	data["props"] = props

# --- Level 5: Last Light (Open plaza with perimeter generator defense points) ---
func _generate_plaza_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var rubble: Array[Dictionary] = []
	var count := 3 if graphics_quality == 0 else 6
	for i in range(count):
		rubble.append({
			"pos": origin + Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30)),
			"size": Vector2(rng.randf_range(14, 28), rng.randf_range(12, 24)),
			"rot": rng.randf_range(-PI, PI)
		})
	
	var props: Array[Dictionary] = []
	
	# 4 Perimeter Emergency Generator Defense Points around the central plaza
	if cx == 1 and cy == 0:
		# North generator defense station
		props.append({"pos": Vector2(640.0, 110.0), "kind": 0, "rot": 0.0}) # Generator
		props.append({"pos": Vector2(580.0, 130.0), "kind": 1, "rot": -0.35}) # Left sandbags
		props.append({"pos": Vector2(700.0, 130.0), "kind": 1, "rot": 0.35}) # Right sandbags
		props.append({"pos": Vector2(640.0, 80.0), "kind": 2, "rot": 0.0}) # Floodlight
		
		# South generator defense station
		props.append({"pos": Vector2(640.0, 610.0), "kind": 0, "rot": 0.0})
		props.append({"pos": Vector2(580.0, 590.0), "kind": 1, "rot": 0.35})
		props.append({"pos": Vector2(700.0, 590.0), "kind": 1, "rot": -0.35})
		props.append({"pos": Vector2(640.0, 640.0), "kind": 2, "rot": 0.0})
	elif cx == 0 and cy == 0:
		# West generator defense station
		props.append({"pos": Vector2(220.0, 360.0), "kind": 0, "rot": PI * 0.5})
		props.append({"pos": Vector2(240.0, 300.0), "kind": 1, "rot": 1.2})
		props.append({"pos": Vector2(240.0, 420.0), "kind": 1, "rot": 1.9})
		props.append({"pos": Vector2(180.0, 360.0), "kind": 2, "rot": 0.0})
	elif cx == 2 and cy == 0:
		# East generator defense station
		props.append({"pos": Vector2(1060.0, 360.0), "kind": 0, "rot": PI * 0.5})
		props.append({"pos": Vector2(1040.0, 300.0), "kind": 1, "rot": -1.2})
		props.append({"pos": Vector2(1040.0, 420.0), "kind": 1, "rot": -1.9})
		props.append({"pos": Vector2(1100.0, 360.0), "kind": 2, "rot": 0.0})
	else:
		# Outer perimeter props: Sandbag fortifications and stone monument blocks
		var outer_count := 2 if graphics_quality == 0 else rng.randi_range(2, 4)
		for i in range(outer_count):
			var p_pos := origin + Vector2(rng.randf_range(80.0, CHUNK_SIZE - 80.0), rng.randf_range(80.0, CHUNK_SIZE - 80.0))
			props.append({
				"pos": p_pos,
				"kind": 1 if (rng.randf() < 0.6) else 3,
				"rot": rng.randf_range(-PI, PI)
			})
	
	data["rubble"] = rubble
	data["props"] = props

# ==============================================================================
# DRAWING ROUTINES
# ==============================================================================

func _draw() -> void:
	var center_chunk := get_chunk_coords(focus_position)
	var flicker := 0.60 + 0.40 * sin(beacon_time * 4.5)
	
	var radius := 1 if graphics_quality == 0 else 2
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var chunk := _get_chunk_data(center_chunk.x + dx, center_chunk.y + dy)
			_draw_chunk(chunk, flicker)

func _draw_chunk(chunk: Dictionary, flicker: float) -> void:
	var sector: int = int(chunk.get("sector", 1))
	match sector:
		SectorBiome.THE_STREET:
			_draw_street_chunk(chunk, flicker)
		SectorBiome.NO_EXIT:
			_draw_alley_chunk(chunk, flicker)
		SectorBiome.THE_DEPOT:
			_draw_depot_chunk(chunk, flicker)
		SectorBiome.LAST_LIGHT:
			_draw_plaza_chunk(chunk, flicker)
		_:
			_draw_quarantine_chunk(chunk, flicker)

# --- 1. QUARANTINE OUTPOST ---
func _draw_quarantine_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	var base_shade := 0.09 if ((cx + cy) % 2 == 0) else 0.085
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade + 0.01, base_shade + 0.02, 1.0), true)
	
	var grid_col := Color(0.05, 0.06, 0.07, 0.72)
	for step in range(0, int(CHUNK_SIZE), 160):
		draw_line(origin + Vector2(step, 0), origin + Vector2(step, CHUNK_SIZE), grid_col, 2.0)
		draw_line(origin + Vector2(0, step), origin + Vector2(CHUNK_SIZE, step), grid_col, 2.0)
	
	if chunk.get("has_ew_road", false):
		var road_y := origin.y + CHUNK_SIZE * 0.5 - 70.0
		draw_rect(Rect2(Vector2(origin.x, road_y), Vector2(CHUNK_SIZE, 140.0)), Color(0.065, 0.07, 0.08, 1.0), true)
		draw_line(Vector2(origin.x, road_y), Vector2(origin.x + CHUNK_SIZE, road_y), Color(0.22, 0.23, 0.25, 0.55), 3.0)
		draw_line(Vector2(origin.x, road_y + 140.0), Vector2(origin.x + CHUNK_SIZE, road_y + 140.0), Color(0.22, 0.23, 0.25, 0.55), 3.0)
	
	if chunk.get("has_ns_road", false):
		var road_x := origin.x + CHUNK_SIZE * 0.5 - 70.0
		draw_rect(Rect2(Vector2(road_x, origin.y), Vector2(140.0, CHUNK_SIZE)), Color(0.065, 0.07, 0.08, 1.0), true)
	
	if cx == 1 and cy == 0:
		var helipad := Vector2(640, 360)
		draw_arc(helipad, 110.0, 0.0, TAU, 48, Color(0.42, 0.34, 0.16, 0.24), 4.0)
		draw_arc(helipad, 78.0, 0.0, TAU, 36, Color(0.52, 0.16, 0.16, 0.20), 2.5)
	
	for d in chunk.get("stains", []):
		var col := Color(0.04, 0.04, 0.05, 0.58) if d["dark"] else Color(0.14, 0.13, 0.12, 0.42)
		draw_circle(d["pos"], d["radius"], col)
	
	for c in chunk.get("cracks", []):
		for i in range(c.size() - 1):
			draw_line(c[i], c[i + 1], Color(0.03, 0.03, 0.04, 0.85), 1.8)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	var lamp_boost := 1.0 + night_factor * 1.35
	
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		if kind == 0:
			draw_circle(pos + dyn_shadow * 0.65, 14.0, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(pos, 13.0, Color(0.36, 0.18, 0.12, 1.0))
			draw_arc(pos, 13.0, 0.0, TAU, 20, Color(0.18, 0.10, 0.08, 1.0), 2.2)
			draw_circle(pos + Vector2(-3, -3), 4.0, Color(0.68, 0.52, 0.14, 0.80))
		elif kind == 1:
			var b_rect := Rect2(pos - Vector2(26, 8), Vector2(52, 16))
			var s_rect := Rect2(pos - Vector2(26, 8) + dyn_shadow * 0.75, Vector2(54, 18))
			draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.48), true)
			draw_rect(b_rect, Color(0.24, 0.25, 0.27, 1.0), true)
			draw_rect(b_rect, Color(0.12, 0.13, 0.15, 1.0), false, 2.0)
			draw_line(pos - Vector2(20, 0), pos + Vector2(20, 0), Color(0.65, 0.20, 0.16, 0.75), 3.0)
		else:
			draw_line(pos, pos + dyn_shadow * 1.9, Color(0.0, 0.0, 0.0, 0.52), 5.0)
			draw_circle(pos, 52.0 + night_factor * 24.0, Color(0.78, 0.18, 0.12, 0.08 * flicker * lamp_boost))
			draw_circle(pos, 20.0 + night_factor * 10.0, Color(0.92, 0.25, 0.15, 0.16 * flicker * lamp_boost))
			draw_circle(pos, 6.0, Color(0.18, 0.20, 0.22, 1.0))
			draw_circle(pos, 3.8, Color(1.0, 0.38, 0.20, clampf(0.90 * flicker * lamp_boost, 0.0, 1.0)))

# --- 2. THE STREET ---
func _draw_street_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Dark cracked highway asphalt
	var base_shade := 0.065 if ((cx + cy) % 2 == 0) else 0.060
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade, base_shade + 0.008, 1.0), true)
	
	# North-South Highway Lanes
	var road_col := Color(0.045, 0.045, 0.05, 1.0)
	var curb_col := Color(0.22, 0.22, 0.24, 0.8)
	draw_line(origin + Vector2(60, 0), origin + Vector2(60, CHUNK_SIZE), curb_col, 3.0)
	draw_line(origin + Vector2(CHUNK_SIZE - 60, 0), origin + Vector2(CHUNK_SIZE - 60, CHUNK_SIZE), curb_col, 3.0)
	
	# Dashed yellow lane divider down the center
	for ly in range(20, int(CHUNK_SIZE), 80):
		draw_rect(Rect2(Vector2(origin.x + CHUNK_SIZE * 0.5 - 2.0, origin.y + ly), Vector2(4.0, 40.0)), Color(0.70, 0.58, 0.18, 0.40), true)
	
	# Weeds in pavement
	for fol in chunk.get("foliage", []):
		draw_circle(fol["pos"], fol["radius"], Color(0.14, 0.15, 0.10, 0.35))
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Top-down Abandoned Vehicles and Barricades
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var rot: float = float(p.get("rot", 0.0))
		var cv: int = int(p.get("color_variant", 0))
		
		if kind == 0:
			# Sedan car wreck (size ~ 34 x 68)
			var colors := [Color(0.38, 0.22, 0.16), Color(0.22, 0.24, 0.26), Color(0.48, 0.18, 0.16), Color(0.30, 0.32, 0.35)]
			var car_col: Color = colors[cv % colors.size()]
			var car_sz := Vector2(34.0, 68.0)
			
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-car_sz * 0.5 + dyn_shadow * 0.7, car_sz), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(-car_sz * 0.5, car_sz), car_col, true) # Chassis
			draw_rect(Rect2(-13.0, -18.0, 26.0, 36.0), Color(0.14, 0.14, 0.16), true) # Roof
			draw_line(Vector2(-12.0, -18.0), Vector2(12.0, -18.0), Color(0.6, 0.75, 0.85, 0.7), 3.0) # Windshield
			draw_line(Vector2(-12.0, 18.0), Vector2(12.0, 18.0), Color(0.5, 0.65, 0.75, 0.5), 2.5) # Rear glass
			# Wheels on sides
			for wy in [-22.0, 22.0]:
				draw_rect(Rect2(-car_sz.x * 0.5 - 3.0, wy - 6.0, 4.0, 12.0), Color(0.08, 0.08, 0.08), true)
				draw_rect(Rect2(car_sz.x * 0.5 - 1.0, wy - 6.0, 4.0, 12.0), Color(0.08, 0.08, 0.08), true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 1:
			# Police cruiser / Ambulance (size ~ 36 x 72)
			var car_sz := Vector2(36.0, 72.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-car_sz * 0.5 + dyn_shadow * 0.7, car_sz), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(-car_sz * 0.5, car_sz), Color(0.85, 0.88, 0.90), true) # White body
			draw_rect(Rect2(-car_sz.x * 0.5, -12.0, car_sz.x, 24.0), Color(0.12, 0.22, 0.45), true) # Navy door stripe
			draw_rect(Rect2(-12.0, -4.0, 24.0, 8.0), Color(0.18, 0.20, 0.22), true) # Lightbar base
			draw_circle(Vector2(-6.0, 0.0), 3.0, Color(0.9, 0.2, 0.2, 0.85)) # Red emergency beacon
			draw_circle(Vector2(6.0, 0.0), 3.0, Color(0.2, 0.4, 0.9, 0.85)) # Blue emergency beacon
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 2:
			# Heavy SWAT Van / City Bus (size ~ 44 x 110)
			var van_sz := Vector2(44.0, 110.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-van_sz * 0.5 + dyn_shadow * 0.75, van_sz), Color(0.0, 0.0, 0.0, 0.50), true)
			draw_rect(Rect2(-van_sz * 0.5, van_sz), Color(0.20, 0.24, 0.22), true) # Dark olive armor
			draw_rect(Rect2(-16.0, -45.0, 32.0, 90.0), Color(0.15, 0.18, 0.16), true) # Corrugated roof
			draw_line(Vector2(-18.0, -46.0), Vector2(18.0, -46.0), Color(0.4, 0.5, 0.6, 0.6), 4.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 3:
			# Concrete Jersey Barrier (size ~ 16 x 50)
			var b_sz := Vector2(16.0, 50.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-b_sz * 0.5 + dyn_shadow * 0.6, b_sz), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(-b_sz * 0.5, b_sz), Color(0.35, 0.36, 0.38), true)
			draw_line(Vector2(-b_sz.x * 0.5, 0.0), Vector2(b_sz.x * 0.5, 0.0), Color(0.75, 0.65, 0.15, 0.7), 2.5) # Yellow stripe
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			# High-mast Streetlight
			draw_line(pos, pos + dyn_shadow * 2.2, Color(0.0, 0.0, 0.0, 0.55), 5.0)
			draw_circle(pos, 60.0 + night_factor * 30.0, Color(1.0, 0.82, 0.48, 0.08 * flicker))
			draw_circle(pos, 20.0, Color(1.0, 0.90, 0.60, 0.16 * flicker))
			draw_circle(pos, 6.0, Color(0.25, 0.26, 0.28))
			draw_circle(pos, 3.5, Color(1.0, 0.85, 0.50, 0.95))

# --- 3. NO EXIT ---
func _draw_alley_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Wet, dark alley ground
	var base_shade := 0.055 if ((cx + cy) % 2 == 0) else 0.050
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade + 0.005, base_shade + 0.005, 1.0), true)
	
	# Sludge & mud patches
	for m in chunk.get("mud_patches", []):
		draw_circle(m["pos"], m["radius"], Color(0.08, 0.07, 0.05, 0.70))
	
	# Toxic rainwater puddles
	for pool in chunk.get("water_pools", []):
		var p_pos: Vector2 = pool["pos"]
		var r: float = float(pool["radius"])
		draw_circle(p_pos, r, Color(0.03, 0.05, 0.03, 0.92))
		draw_arc(p_pos, r, 0.0, TAU, 24, Color(0.15, 0.45, 0.20, 0.40), 2.0)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Brick Chokepoint Walls
	for b in chunk.get("buildings", []):
		var b_pos: Vector2 = b["pos"]
		var b_sz: Vector2 = b["size"]
		var rect := Rect2(b_pos - b_sz * 0.5, b_sz)
		var s_rect := Rect2(b_pos - b_sz * 0.5 + dyn_shadow * 0.8, b_sz)
		draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.50), true)
		draw_rect(rect, Color(0.32, 0.16, 0.12), true) # Brick base
		# Mortar line
		draw_line(Vector2(rect.position.x, b_pos.y), Vector2(rect.position.x + rect.size.x, b_pos.y), Color(0.18, 0.10, 0.08, 0.6), 2.0)
		draw_rect(rect, Color(0.45, 0.42, 0.38), false, 2.5) # Concrete top capstone
	
	# Alley Props: Dumpsters, Security Gates, Pallets, Steam Vents
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var rot: float = float(p.get("rot", 0.0))
		
		if kind == 0:
			# Heavy Dumpster (size ~ 50 x 30)
			var d_sz := Vector2(50.0, 30.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-d_sz * 0.5 + dyn_shadow * 0.65, d_sz), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(-d_sz * 0.5, d_sz), Color(0.15, 0.24, 0.16), true) # Green metal
			draw_rect(Rect2(-d_sz.x * 0.5, -d_sz.y * 0.5, d_sz.x * 0.5 - 1.0, d_sz.y), Color(0.11, 0.18, 0.12), true) # Left lid
			draw_rect(Rect2(1.0, -d_sz.y * 0.5, d_sz.x * 0.5 - 1.0, d_sz.y), Color(0.11, 0.18, 0.12), true) # Right lid
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 1:
			# Security Chainlink Gate (size ~ 60 x 8)
			var g_sz := Vector2(60.0, 8.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_line(Vector2(-g_sz.x * 0.5, 0.0), Vector2(g_sz.x * 0.5, 0.0), Color(0.45, 0.46, 0.48), 3.0)
			draw_circle(Vector2(-g_sz.x * 0.5, 0.0), 4.0, Color(0.3, 0.3, 0.32))
			draw_circle(Vector2(g_sz.x * 0.5, 0.0), 4.0, Color(0.3, 0.3, 0.32))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 2:
			# Stacked Cargo Pallets (size ~ 34 x 34)
			var pal_sz := Vector2(34.0, 34.0)
			draw_rect(Rect2(pos - pal_sz * 0.5 + dyn_shadow * 0.5, pal_sz), Color(0.0, 0.0, 0.0, 0.40), true)
			draw_rect(Rect2(pos - pal_sz * 0.5, pal_sz), Color(0.38, 0.28, 0.16), true)
			for py in [-10.0, 0.0, 10.0]:
				draw_line(pos + Vector2(-pal_sz.x * 0.5, py), pos + Vector2(pal_sz.x * 0.5, py), Color(0.22, 0.16, 0.09), 2.0)
		else:
			# Steaming Drainage Grate
			draw_circle(pos, 14.0, Color(0.15, 0.16, 0.17))
			draw_circle(pos, 24.0 + sin(beacon_time * 4.0) * 8.0, Color(0.25, 0.85, 0.30, 0.12 * flicker))
			draw_arc(pos, 13.0, 0.0, TAU, 16, Color(0.28, 0.30, 0.32), 2.0)

# --- 4. THE DEPOT ---
func _draw_depot_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Industrial concrete yard pavement
	var base_shade := 0.075 if ((cx + cy) % 2 == 0) else 0.070
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade, base_shade + 0.005, 1.0), true)
	
	# Yellow safety boundary stripes around aisles
	var stripe_col := Color(0.72, 0.62, 0.18, 0.30)
	for lx in range(0, int(CHUNK_SIZE), 320):
		draw_line(origin + Vector2(lx, 0), origin + Vector2(lx, CHUNK_SIZE), stripe_col, 2.0)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Freight Shipping Containers (Interlocking Maze with 90° blind corners)
	for b in chunk.get("buildings", []):
		var b_pos: Vector2 = b["pos"]
		var b_sz: Vector2 = b["size"]
		var col: Color = b.get("color", Color(0.65, 0.20, 0.16))
		var rect := Rect2(b_pos - b_sz * 0.5, b_sz)
		var s_rect := Rect2(b_pos - b_sz * 0.5 + dyn_shadow * 0.8, b_sz)
		
		draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.52), true) # Container shadow
		draw_rect(rect, col, true) # Container paint
		
		# Corrugated ridge stripes
		var is_vert: bool = (b_sz.y > b_sz.x)
		if is_vert:
			for ry in range(int(rect.position.y + 10), int(rect.position.y + rect.size.y - 10), 16):
				draw_line(Vector2(rect.position.x + 4, ry), Vector2(rect.position.x + rect.size.x - 4, ry), col.darkened(0.28), 3.0)
		else:
			for rx in range(int(rect.position.x + 10), int(rect.position.x + rect.size.x - 10), 16):
				draw_line(Vector2(rx, rect.position.y + 4), Vector2(rx, rect.position.y + rect.size.y - 4), col.darkened(0.28), 3.0)
		
		draw_rect(rect, col.darkened(0.40), false, 2.5) # Border rim
		# Heavy corner casting pockets
		for cx_p in [rect.position.x + 5, rect.position.x + rect.size.x - 5]:
			for cy_p in [rect.position.y + 5, rect.position.y + rect.size.y - 5]:
				draw_rect(Rect2(Vector2(cx_p - 3, cy_p - 3), Vector2(6, 6)), Color(0.12, 0.12, 0.14), true)
	
	# Depot Props: Supply Crates, Steel Drums, Sodium Floodlight Masts
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		
		if kind == 0:
			# Wooden Supply Crate stack (size ~ 32 x 32)
			var cr_sz := Vector2(32.0, 32.0)
			draw_rect(Rect2(pos - cr_sz * 0.5 + dyn_shadow * 0.5, cr_sz), Color(0.0, 0.0, 0.0, 0.40), true)
			draw_rect(Rect2(pos - cr_sz * 0.5, cr_sz), Color(0.45, 0.35, 0.20), true)
			draw_rect(Rect2(pos - cr_sz * 0.5, cr_sz), Color(0.28, 0.20, 0.10), false, 2.0)
			draw_line(pos - cr_sz * 0.5, pos + cr_sz * 0.5, Color(0.28, 0.20, 0.10), 2.0) # Cross brace
		elif kind == 1:
			# Chemical Steel Oil Drum cluster
			draw_circle(pos + dyn_shadow * 0.5, 15.0, Color(0.0, 0.0, 0.0, 0.40))
			draw_circle(pos, 14.0, Color(0.72, 0.60, 0.15)) # Yellow hazard drum
			draw_circle(pos, 10.0, Color(0.14, 0.14, 0.16))
			draw_circle(pos, 4.0, Color(0.72, 0.60, 0.15))
		else:
			# High-mast Sodium Floodlight
			draw_line(pos, pos + dyn_shadow * 2.4, Color(0.0, 0.0, 0.0, 0.55), 5.0)
			draw_circle(pos, 85.0 + night_factor * 35.0, Color(0.95, 0.90, 0.65, 0.09 * flicker))
			draw_circle(pos, 28.0, Color(1.0, 0.95, 0.75, 0.18 * flicker))
			draw_circle(pos, 8.0, Color(0.22, 0.24, 0.26))
			draw_circle(pos, 4.5, Color(1.0, 0.95, 0.70, 0.95))

# --- 5. LAST LIGHT ---
func _draw_plaza_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Grand open civic plaza flagstone paving
	var base_shade := 0.075 if ((cx + cy) % 2 == 0) else 0.070
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade, base_shade + 0.006, 1.0), true)
	
	# Flagstone tile grid
	var tile_col := Color(0.045, 0.045, 0.05, 0.65)
	for step in range(0, int(CHUNK_SIZE), 80):
		draw_line(origin + Vector2(step, 0), origin + Vector2(step, CHUNK_SIZE), tile_col, 1.5)
		draw_line(origin + Vector2(0, step), origin + Vector2(CHUNK_SIZE, step), tile_col, 1.5)
	
	# Central Plaza Emblem
	if cx == 1 and cy == 0:
		var center := Vector2(640, 360)
		draw_arc(center, 140.0, 0.0, TAU, 48, Color(0.35, 0.38, 0.42, 0.25), 3.0)
		draw_arc(center, 90.0, 0.0, TAU, 36, Color(0.60, 0.22, 0.20, 0.20), 2.0)
	
	for r in chunk.get("rubble", []):
		draw_rect(Rect2(r["pos"], r["size"]), Color(0.22, 0.22, 0.24, 0.85), true)
		draw_line(r["pos"], r["pos"] + r["size"], Color(0.40, 0.15, 0.12, 0.7), 2.0)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Perimeter Generator Defense Points & Fortifications
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var rot: float = float(p.get("rot", 0.0))
		
		if kind == 0:
			# Emergency Diesel Generator Station (size ~ 54 x 38)
			var gen_sz := Vector2(54.0, 38.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-gen_sz * 0.5 + dyn_shadow * 0.7, gen_sz), Color(0.0, 0.0, 0.0, 0.48), true)
			draw_rect(Rect2(-gen_sz * 0.5, gen_sz), Color(0.25, 0.28, 0.32), true) # Metal chassis
			draw_rect(Rect2(-gen_sz.x * 0.5 + 4, -gen_sz.y * 0.5 + 4, 18.0, gen_sz.y - 8), Color(0.14, 0.16, 0.18), true) # Radiator
			draw_circle(Vector2(12.0, 0.0), 5.0, Color(0.35, 0.85, 1.0, 0.90 * flicker)) # Pulsing generator beacon
			draw_circle(Vector2(12.0, 0.0), 16.0, Color(0.35, 0.85, 1.0, 0.22 * flicker))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 1:
			# Sandbag fortification wing (size ~ 68 x 16)
			var sb_sz := Vector2(68.0, 16.0)
			draw_set_transform(pos, rot, Vector2.ONE)
			draw_rect(Rect2(-sb_sz * 0.5 + dyn_shadow * 0.6, sb_sz), Color(0.0, 0.0, 0.0, 0.42), true)
			draw_rect(Rect2(-sb_sz * 0.5, sb_sz), Color(0.48, 0.42, 0.30), true) # Sandbag burlap
			for bx in range(int(-sb_sz.x * 0.5 + 8), int(sb_sz.x * 0.5), 14):
				draw_line(Vector2(bx, -sb_sz.y * 0.5), Vector2(bx, sb_sz.y * 0.5), Color(0.30, 0.25, 0.16), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif kind == 2:
			# High-intensity Floodlight
			draw_line(pos, pos + dyn_shadow * 2.2, Color(0.0, 0.0, 0.0, 0.55), 5.0)
			draw_circle(pos, 90.0 + night_factor * 40.0, Color(0.75, 0.90, 1.0, 0.12 * flicker))
			draw_circle(pos, 30.0, Color(0.85, 0.95, 1.0, 0.24 * flicker))
			draw_circle(pos, 7.0, Color(0.24, 0.26, 0.28))
			draw_circle(pos, 4.0, Color(0.85, 0.95, 1.0, 0.95))
		else:
			# Stone Plaza Monument / Planter (size ~ 42 x 42)
			var m_sz := Vector2(42.0, 42.0)
			draw_rect(Rect2(pos - m_sz * 0.5 + dyn_shadow * 0.6, m_sz), Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(Rect2(pos - m_sz * 0.5, m_sz), Color(0.24, 0.25, 0.27), true)
			draw_rect(Rect2(pos - m_sz * 0.5, m_sz), Color(0.14, 0.15, 0.16), false, 2.5)
