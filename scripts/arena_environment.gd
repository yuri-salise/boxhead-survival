extends Node2D

enum SectorBiome {
	QUARANTINE = 1,
	FOREST = 2,
	SWAMP = 3,
	VILLAGE = 4,
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
	
	var move_dist_sq := focus_position.distance_squared_to(last_redraw_pos)
	var threshold := 144.0 if graphics_quality == 0 else (49.0 if graphics_quality == 1 else 16.0)
	if move_dist_sq >= threshold:
		last_redraw_pos = focus_position
		queue_redraw()

func set_night_factor(factor: float) -> void:
	var old := night_factor
	night_factor = clampf(factor, 0.0, 1.0)
	if absf(night_factor - old) > 0.03:
		queue_redraw()

func set_graphics_quality(quality: int) -> void:
	self.graphics_quality = quality

func set_sector_type(type: int) -> void:
	self.sector_type = type

func get_chunk_coords(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CHUNK_SIZE)), int(floor(world_pos.y / CHUNK_SIZE)))

func get_speed_multiplier_at(world_pos: Vector2) -> float:
	if sector_type != SectorBiome.SWAMP:
		return 1.0
	
	# Sector 3 Swamp slows movement down!
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
						SectorBiome.FOREST:
							r = 18.0 if (kind == 0 or kind == 1) else (14.0 if kind == 2 else 16.0)
						SectorBiome.URBAN:
							r = 26.0 if kind == 0 else (8.0 if kind == 1 else 22.0)
						SectorBiome.VILLAGE:
							r = 14.0 if kind == 0 else (18.0 if kind == 1 else 14.0)
						SectorBiome.SWAMP:
							r = float(p.get("size", 22.0)) * 0.7 if kind == 0 else 14.0
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
						"radius": b_sz.length() * 0.35,
						"kind": 99
					})
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
			SectorBiome.FOREST:
				if kind == 0 or kind == 1:
					var c := CircleShape2D.new()
					c.radius = 14.0 if kind == 0 else 15.0
					col_shape.shape = c
					shape_created = true
				elif kind == 2:
					var r := RectangleShape2D.new()
					r.size = Vector2(42.0, 10.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 3:
					var c := CircleShape2D.new()
					c.radius = 16.0
					col_shape.shape = c
					shape_created = true
			SectorBiome.SWAMP:
				if kind == 0:
					var sz: float = float(p.get("size", 22.0))
					var c := CircleShape2D.new()
					c.radius = sz * 0.65
					col_shape.shape = c
					shape_created = true
				elif kind == 2:
					var c := CircleShape2D.new()
					c.radius = 14.0
					col_shape.shape = c
					shape_created = true
			SectorBiome.VILLAGE:
				if kind == 0:
					var r := RectangleShape2D.new()
					r.size = Vector2(48.0, 8.0)
					col_shape.shape = r
					shape_created = true
				elif kind == 1:
					var r := RectangleShape2D.new()
					r.size = Vector2(32.0, 24.0)
					col_shape.shape = r
					shape_created = true
				elif kind == 2:
					var c := CircleShape2D.new()
					c.radius = 12.0
					col_shape.shape = c
					shape_created = true
			SectorBiome.URBAN:
				if kind == 0:
					var r := RectangleShape2D.new()
					r.size = Vector2(56.0, 32.0)
					col_shape.shape = r
					body.rotation = rot
					shape_created = true
				elif kind == 1:
					var c := CircleShape2D.new()
					c.radius = 6.0
					col_shape.shape = c
					shape_created = true
				elif kind == 2:
					var r := RectangleShape2D.new()
					r.size = Vector2(48.0, 28.0)
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
		
		# North wall
		var n_col := CollisionShape2D.new()
		var n_shape := RectangleShape2D.new()
		n_shape.size = Vector2(b_sz.x, 10.0)
		n_col.shape = n_shape
		n_col.position = Vector2(0.0, -b_sz.y * 0.5 + 5.0)
		wall_body.add_child(n_col)
		
		# West wall
		var w_col := CollisionShape2D.new()
		var w_shape := RectangleShape2D.new()
		w_shape.size = Vector2(10.0, b_sz.y)
		w_col.shape = w_shape
		w_col.position = Vector2(-b_sz.x * 0.5 + 5.0, 0.0)
		wall_body.add_child(w_col)
		
		# East wall
		var e_col := CollisionShape2D.new()
		var e_shape := RectangleShape2D.new()
		e_shape.size = Vector2(10.0, b_sz.y)
		e_col.shape = e_shape
		e_col.position = Vector2(b_sz.x * 0.5 - 5.0, 0.0)
		wall_body.add_child(e_col)
		
		# South wall Left (doorway opening in center)
		var s_left_col := CollisionShape2D.new()
		var s_left_shape := RectangleShape2D.new()
		var seg_w := maxf(16.0, (b_sz.x - 44.0) * 0.5)
		s_left_shape.size = Vector2(seg_w, 10.0)
		s_left_col.shape = s_left_shape
		s_left_col.position = Vector2(-b_sz.x * 0.5 + seg_w * 0.5, b_sz.y * 0.5 - 5.0)
		wall_body.add_child(s_left_col)
		
		# South wall Right
		var s_right_col := CollisionShape2D.new()
		var s_right_shape := RectangleShape2D.new()
		s_right_shape.size = Vector2(seg_w, 10.0)
		s_right_col.shape = s_right_shape
		s_right_col.position = Vector2(b_sz.x * 0.5 - seg_w * 0.5, b_sz.y * 0.5 - 5.0)
		wall_body.add_child(s_right_col)
		
		# Stone fireplace chimney
		var chim_col := CollisionShape2D.new()
		var chim_shape := RectangleShape2D.new()
		chim_shape.size = Vector2(24.0, 24.0)
		chim_col.shape = chim_shape
		chim_col.position = -b_sz * 0.5 + Vector2(20.0, 20.0)
		wall_body.add_child(chim_col)
		
		collider_container.add_child(wall_body)
		bodies.append(wall_body)
	
	return bodies

func _process(delta: float) -> void:
	beacon_time += delta
	redraw_timer += delta
	
	# Performance optimization: throttle redraw interval based on graphics quality
	var interval := 0.35 if graphics_quality == 0 else (0.16 if graphics_quality == 1 else 0.06)
	if redraw_timer >= interval:
		redraw_timer = 0.0
		queue_redraw()

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
		SectorBiome.FOREST:
			_generate_forest_chunk(data, origin, cx, cy, rng)
		SectorBiome.SWAMP:
			_generate_swamp_chunk(data, origin, cx, cy, rng)
		SectorBiome.VILLAGE:
			_generate_village_chunk(data, origin, cx, cy, rng)
		SectorBiome.URBAN:
			_generate_urban_chunk(data, origin, cx, cy, rng)
		_:
			_generate_quarantine_chunk(data, origin, cx, cy, rng)
	
	chunk_cache[key] = data
	return data

# ==============================================================================
# PROCEDURAL CHUNK GENERATORS PER SECTOR BIOME
# ==============================================================================

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

func _generate_forest_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var foliage_patches: Array[Dictionary] = []
	var count := 5 if graphics_quality == 0 else 10
	for i in range(count):
		foliage_patches.append({
			"pos": origin + Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30)),
			"radius": rng.randf_range(14.0, 38.0),
			"moss": rng.randf() < 0.55
		})
	
	# Forest trail winding through chunks
	var has_trail: bool = (absi(cx + cy) % 2 == 0)
	var trail_points: Array[Vector2] = []
	if has_trail:
		var p1 := origin + Vector2(0.0, CHUNK_SIZE * rng.randf_range(0.3, 0.7))
		var p2 := origin + Vector2(CHUNK_SIZE * 0.5, CHUNK_SIZE * rng.randf_range(0.2, 0.8))
		var p3 := origin + Vector2(CHUNK_SIZE, CHUNK_SIZE * rng.randf_range(0.3, 0.7))
		trail_points = [p1, p2, p3]
	
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(2, 3) if graphics_quality == 0 else rng.randi_range(4, 7)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(60.0, CHUNK_SIZE - 60.0), rng.randf_range(60.0, CHUNK_SIZE - 60.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 4, # 0 = Pine Tree, 1 = Oak Tree, 2 = Fallen Timber Log, 3 = Mossy Boulder
			"radius": rng.randf_range(28.0, 46.0),
			"rot": rng.randf_range(-PI, PI)
		})
	
	data["foliage"] = foliage_patches
	data["has_trail"] = has_trail
	data["trail_points"] = trail_points
	data["props"] = props

func _generate_swamp_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var water_pools: Array[Dictionary] = []
	var pool_count := 2 if graphics_quality == 0 else rng.randi_range(2, 4)
	for i in range(pool_count):
		water_pools.append({
			"pos": origin + Vector2(rng.randf_range(90, CHUNK_SIZE - 90), rng.randf_range(90, CHUNK_SIZE - 90)),
			"radius": rng.randf_range(42.0, 95.0),
			"depth": rng.randf_range(0.6, 1.0)
		})
	
	var mud_patches: Array[Dictionary] = []
	var mud_count := 3 if graphics_quality == 0 else 6
	for i in range(mud_count):
		mud_patches.append({
			"pos": origin + Vector2(rng.randf_range(40, CHUNK_SIZE - 40), rng.randf_range(40, CHUNK_SIZE - 40)),
			"radius": rng.randf_range(20.0, 50.0)
		})
	
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(2, 3) if graphics_quality == 0 else rng.randi_range(3, 6)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(60.0, CHUNK_SIZE - 60.0), rng.randf_range(60.0, CHUNK_SIZE - 60.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = Cypress Swamp Stump, 1 = Cattail / Reed Cluster, 2 = Bubbling Toxic Vent
			"size": rng.randf_range(18.0, 32.0),
			"rot": rng.randf_range(-PI, PI)
		})
	
	data["water_pools"] = water_pools
	data["mud_patches"] = mud_patches
	data["props"] = props

func _generate_village_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var paths: Array[Dictionary] = []
	var has_path: bool = (absi(cx * 3 + cy) % 2 == 0)
	if has_path:
		paths.append({
			"from": origin + Vector2(0, CHUNK_SIZE * 0.5),
			"to": origin + Vector2(CHUNK_SIZE, CHUNK_SIZE * 0.5),
			"width": 72.0
		})
	
	var buildings: Array[Dictionary] = []
	# Place an abandoned wooden cabin footprint if not too close to center
	if rng.randf() < 0.55:
		var b_pos := origin + Vector2(rng.randf_range(130, CHUNK_SIZE - 130), rng.randf_range(130, CHUNK_SIZE - 130))
		if b_pos.distance_to(Vector2(640, 360)) > 170.0:
			buildings.append({
				"pos": b_pos,
				"size": Vector2(rng.randf_range(120, 160), rng.randf_range(90, 130)),
				"rot": rng.randf_range(-0.25, 0.25)
			})
	
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(2, 3) if graphics_quality == 0 else rng.randi_range(3, 5)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(70.0, CHUNK_SIZE - 70.0), rng.randf_range(70.0, CHUNK_SIZE - 70.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = Picket Fence, 1 = Hay Bale, 2 = Weathered Fruit Tree
			"rot": rng.randf_range(-PI, PI)
		})
	
	data["paths"] = paths
	data["buildings"] = buildings
	data["props"] = props

func _generate_urban_chunk(data: Dictionary, origin: Vector2, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var has_ew_street: bool = (absi(cy) % 2 == 0)
	var has_ns_street: bool = (absi(cx) % 2 == 1)
	
	var rubble: Array[Dictionary] = []
	var count := 3 if graphics_quality == 0 else 6
	for i in range(count):
		rubble.append({
			"pos": origin + Vector2(rng.randf_range(30, CHUNK_SIZE - 30), rng.randf_range(30, CHUNK_SIZE - 30)),
			"size": Vector2(rng.randf_range(14, 28), rng.randf_range(12, 24)),
			"rot": rng.randf_range(-PI, PI)
		})
	
	var props: Array[Dictionary] = []
	var prop_count := rng.randi_range(2, 3) if graphics_quality == 0 else rng.randi_range(3, 5)
	for i in range(prop_count):
		var p_pos := origin + Vector2(rng.randf_range(80.0, CHUNK_SIZE - 80.0), rng.randf_range(80.0, CHUNK_SIZE - 80.0))
		if p_pos.distance_to(Vector2(640, 360)) < 150.0:
			continue
		props.append({
			"pos": p_pos,
			"kind": rng.randi() % 3, # 0 = Car Wreck, 1 = Urban Streetlight, 2 = Heavy Dumpster
			"rot": rng.randf_range(-0.5, 0.5)
		})
	
	data["has_ew_street"] = has_ew_street
	data["has_ns_street"] = has_ns_street
	data["rubble"] = rubble
	data["props"] = props

# ==============================================================================
# DRAWING ROUTINES
# ==============================================================================

func _draw() -> void:
	var center_chunk := get_chunk_coords(focus_position)
	var flicker := 0.60 + 0.40 * sin(beacon_time * 4.5)
	
	# Mobile efficiency: Low quality renders 3x3 chunks; Medium and High render 5x5 chunks
	var radius := 1 if graphics_quality == 0 else 2
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var chunk := _get_chunk_data(center_chunk.x + dx, center_chunk.y + dy)
			_draw_chunk(chunk, flicker)

func _draw_chunk(chunk: Dictionary, flicker: float) -> void:
	var sector: int = int(chunk.get("sector", 1))
	match sector:
		SectorBiome.FOREST:
			_draw_forest_chunk(chunk, flicker)
		SectorBiome.SWAMP:
			_draw_swamp_chunk(chunk, flicker)
		SectorBiome.VILLAGE:
			_draw_village_chunk(chunk, flicker)
		SectorBiome.URBAN:
			_draw_urban_chunk(chunk, flicker)
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
		for lx in range(20, int(CHUNK_SIZE), 90):
			draw_rect(Rect2(Vector2(origin.x + lx, origin.y + CHUNK_SIZE * 0.5 - 3.0), Vector2(46.0, 6.0)), Color(0.45, 0.36, 0.16, 0.24), true)
	
	if chunk.get("has_ns_road", false):
		var road_x := origin.x + CHUNK_SIZE * 0.5 - 70.0
		draw_rect(Rect2(Vector2(road_x, origin.y), Vector2(140.0, CHUNK_SIZE)), Color(0.065, 0.07, 0.08, 1.0), true)
		for ly in range(20, int(CHUNK_SIZE), 90):
			draw_rect(Rect2(Vector2(origin.x + CHUNK_SIZE * 0.5 - 3.0, origin.y + ly), Vector2(6.0, 46.0)), Color(0.45, 0.36, 0.16, 0.24), true)
	
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

# --- 2. DENSE FOREST ---
func _draw_forest_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Rich earthy dark moss/dirt floor
	var base_green := 0.13 if ((cx + cy) % 2 == 0) else 0.11
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.09, base_green, 0.07, 1.0), true)
	
	# Organic dirt trails
	if chunk.get("has_trail", false):
		var pts: Array = chunk.get("trail_points", [])
		if pts.size() >= 3:
			draw_polyline(pts, Color(0.18, 0.14, 0.09, 0.90), 38.0)
			draw_polyline(pts, Color(0.14, 0.11, 0.07, 0.70), 46.0)
	
	# Forest foliage & moss patches
	for fol in chunk.get("foliage", []):
		var col := Color(0.06, 0.18, 0.08, 0.40) if fol["moss"] else Color(0.22, 0.16, 0.07, 0.35)
		draw_circle(fol["pos"], fol["radius"], col)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Pine trees, broadleaf oak, logs, boulders
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var r: float = float(p.get("radius", 32.0))
		
		if kind == 0:
			# Pine Tree: Layered evergreen canopy with circular shadow
			draw_circle(pos + dyn_shadow * 0.8, r * 1.1, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(pos, 8.0, Color(0.22, 0.14, 0.08, 1.0)) # trunk
			draw_circle(pos, r, Color(0.08, 0.22, 0.10, 1.0)) # outer canopy
			draw_circle(pos + Vector2(-3, -3), r * 0.68, Color(0.12, 0.30, 0.13, 1.0)) # inner needles
			draw_circle(pos + Vector2(-6, -6), r * 0.32, Color(0.18, 0.38, 0.18, 1.0)) # peak
		elif kind == 1:
			# Oak Tree: Wide rounded canopy
			draw_circle(pos + dyn_shadow * 0.75, r * 1.15, Color(0.0, 0.0, 0.0, 0.40))
			draw_circle(pos, 9.0, Color(0.25, 0.16, 0.09, 1.0))
			draw_circle(pos, r * 0.95, Color(0.14, 0.24, 0.08, 1.0))
			draw_circle(pos + Vector2(r * 0.2, -r * 0.2), r * 0.55, Color(0.18, 0.30, 0.10, 0.9))
		elif kind == 2:
			# Fallen Timber Log
			var log_len := 42.0
			var log_dir := Vector2.from_angle(p["rot"])
			var p1 := pos - log_dir * (log_len * 0.5)
			var p2 := pos + log_dir * (log_len * 0.5)
			draw_line(p1 + dyn_shadow * 0.5, p2 + dyn_shadow * 0.5, Color(0.0, 0.0, 0.0, 0.48), 12.0)
			draw_line(p1, p2, Color(0.28, 0.19, 0.10, 1.0), 10.0)
			draw_line(p1, p2, Color(0.16, 0.26, 0.12, 0.60), 3.0) # moss stripe
		else:
			# Mossy Boulder
			draw_circle(pos + dyn_shadow * 0.5, 18.0, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(pos, 16.0, Color(0.26, 0.27, 0.28, 1.0))
			draw_circle(pos + Vector2(-3, -3), 11.0, Color(0.18, 0.28, 0.16, 0.85))

# --- 3. MURKY TOXIC SWAMP ---
func _draw_swamp_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Murky peat bog / stagnant water floor
	var base_green := 0.09 if ((cx + cy) % 2 == 0) else 0.08
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(0.06, base_green, 0.06, 1.0), true)
	
	# Mud beds
	for m in chunk.get("mud_patches", []):
		draw_circle(m["pos"], m["radius"], Color(0.11, 0.09, 0.06, 0.70))
	
	# Deep murky toxic water pools with ripples
	var pulse := sin(beacon_time * 2.8) * 3.0
	for pool in chunk.get("water_pools", []):
		var p_pos: Vector2 = pool["pos"]
		var r: float = float(pool["radius"])
		draw_circle(p_pos, r, Color(0.03, 0.07, 0.04, 0.95))
		draw_circle(p_pos, r * 0.7, Color(0.02, 0.05, 0.03, 0.98))
		draw_arc(p_pos, maxf(8.0, r * 0.5 + pulse), 0.0, TAU, 28, Color(0.15, 0.32, 0.12, 0.30), 2.0)
		draw_arc(p_pos, r, 0.0, TAU, 32, Color(0.12, 0.18, 0.08, 0.65), 3.0)
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		var sz: float = float(p.get("size", 22.0))
		
		if kind == 0:
			# Rotted Cypress Stump
			draw_circle(pos + dyn_shadow * 0.6, sz * 0.8, Color(0.0, 0.0, 0.0, 0.45))
			draw_circle(pos, sz * 0.7, Color(0.20, 0.15, 0.10, 1.0))
			draw_circle(pos, sz * 0.4, Color(0.08, 0.06, 0.04, 1.0)) # hollow core
			draw_arc(pos, sz * 0.7, 0.0, TAU, 16, Color(0.12, 0.22, 0.10, 0.8), 2.5) # moss rim
		elif kind == 1:
			# Clustered Cattails & Wetland Reeds
			draw_circle(pos + dyn_shadow * 0.4, 12.0, Color(0.0, 0.0, 0.0, 0.35))
			for ang in [-0.4, 0.0, 0.4]:
				var tip := pos + Vector2(ang * 18.0, -22.0)
				draw_line(pos, tip, Color(0.16, 0.28, 0.12, 1.0), 2.5)
				draw_line(tip - Vector2(0, 8), tip, Color(0.36, 0.22, 0.10, 1.0), 4.0) # fuzzy seed head
		else:
			# Bubbling Toxic Vent
			var vent_pulse := 0.5 + 0.5 * sin(beacon_time * 5.0 + pos.x)
			draw_circle(pos, 16.0, Color(0.04, 0.08, 0.04, 0.85))
			draw_circle(pos, 28.0 + vent_pulse * 12.0, Color(0.18, 0.75, 0.25, 0.09 * flicker))
			draw_circle(pos, 8.0, Color(0.25, 0.85, 0.30, 0.45 * vent_pulse))

# --- 4. ABANDONED RURAL VILLAGE ---
func _draw_village_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Dry packed dirt & scrub ground
	var base_dirt := 0.15 if ((cx + cy) % 2 == 0) else 0.13
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_dirt + 0.02, base_dirt, base_dirt - 0.03, 1.0), true)
	
	# Wagon cart dirt paths
	for path in chunk.get("paths", []):
		var p_from: Vector2 = path["from"]
		var p_to: Vector2 = path["to"]
		draw_line(p_from, p_to, Color(0.22, 0.18, 0.12, 0.85), float(path["width"]))
		draw_line(p_from + Vector2(0, -18), p_to + Vector2(0, -18), Color(0.16, 0.12, 0.08, 0.5), 4.0) # rut
		draw_line(p_from + Vector2(0, 18), p_to + Vector2(0, 18), Color(0.16, 0.12, 0.08, 0.5), 4.0) # rut
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	# Abandoned wooden cabins
	for b in chunk.get("buildings", []):
		var b_pos: Vector2 = b["pos"]
		var b_sz: Vector2 = b["size"]
		var rect := Rect2(b_pos - b_sz * 0.5, b_sz)
		var s_rect := Rect2(b_pos - b_sz * 0.5 + dyn_shadow * 0.8, b_sz)
		
		draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.45), true) # building shadow
		draw_rect(rect, Color(0.24, 0.18, 0.12, 1.0), true) # wood floor
		
		# Floor planks
		for py in range(int(rect.position.y), int(rect.position.y + rect.size.y), 24):
			draw_line(Vector2(rect.position.x, py), Vector2(rect.position.x + rect.size.x, py), Color(0.16, 0.11, 0.07, 0.6), 2.0)
		
		draw_rect(rect, Color(0.36, 0.26, 0.16, 1.0), false, 4.0) # wall outline
		# Stone chimney hearth
		draw_rect(Rect2(rect.position + Vector2(8, 8), Vector2(24, 24)), Color(0.30, 0.30, 0.32, 1.0), true)
	
	# Village props: fence, hay bale, weathered tree
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		
		if kind == 0:
			# Picket wooden fence
			var f_len := 48.0
			var p1 := pos - Vector2(f_len * 0.5, 0)
			var p2 := pos + Vector2(f_len * 0.5, 0)
			draw_line(p1 + dyn_shadow * 0.6, p2 + dyn_shadow * 0.6, Color(0.0, 0.0, 0.0, 0.40), 6.0)
			draw_line(p1, p2, Color(0.42, 0.32, 0.20, 1.0), 5.0)
			for fx in range(int(p1.x), int(p2.x) + 1, 14):
				draw_circle(Vector2(fx, pos.y), 3.5, Color(0.52, 0.40, 0.26, 1.0))
		elif kind == 1:
			# Hay bale
			var h_rect := Rect2(pos - Vector2(16, 12), Vector2(32, 24))
			var s_rect := Rect2(pos - Vector2(16, 12) + dyn_shadow * 0.6, Vector2(32, 24))
			draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(h_rect, Color(0.55, 0.44, 0.16, 1.0), true)
			draw_rect(h_rect, Color(0.36, 0.28, 0.10, 1.0), false, 2.0)
		else:
			# Weathered village tree
			draw_circle(pos + dyn_shadow * 0.7, 24.0, Color(0.0, 0.0, 0.0, 0.40))
			draw_circle(pos, 7.0, Color(0.24, 0.16, 0.10, 1.0))
			draw_circle(pos, 22.0, Color(0.18, 0.25, 0.12, 0.90))

# --- 5. RUINED URBAN CITY ---
func _draw_urban_chunk(chunk: Dictionary, flicker: float) -> void:
	var origin: Vector2 = chunk["origin"]
	var cx: int = chunk["cx"]
	var cy: int = chunk["cy"]
	
	# Dark cracked asphalt
	var base_shade := 0.065 if ((cx + cy) % 2 == 0) else 0.060
	draw_rect(Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE)), Color(base_shade, base_shade, base_shade + 0.01, 1.0), true)
	
	# Sidewalk perimeter
	var sidewalk_col := Color(0.15, 0.15, 0.16, 1.0)
	var curb_col := Color(0.24, 0.24, 0.26, 1.0)
	
	if chunk.get("has_ew_street", false):
		var street_y := origin.y + CHUNK_SIZE * 0.5 - 90.0
		# Concrete sidewalks on both sides
		draw_rect(Rect2(Vector2(origin.x, street_y - 32.0), Vector2(CHUNK_SIZE, 32.0)), sidewalk_col, true)
		draw_line(Vector2(origin.x, street_y), Vector2(origin.x + CHUNK_SIZE, street_y), curb_col, 3.0)
		
		draw_rect(Rect2(Vector2(origin.x, street_y + 180.0), Vector2(CHUNK_SIZE, 32.0)), sidewalk_col, true)
		draw_line(Vector2(origin.x, street_y + 180.0), Vector2(origin.x + CHUNK_SIZE, street_y + 180.0), curb_col, 3.0)
		
		# Street pavement
		draw_rect(Rect2(Vector2(origin.x, street_y), Vector2(CHUNK_SIZE, 180.0)), Color(0.045, 0.045, 0.05, 1.0), true)
		
		# White crosswalk zebra stripes at intersections
		if chunk.get("has_ns_street", false):
			for stripe_x in range(int(origin.x + 30), int(origin.x + 150), 20):
				draw_rect(Rect2(Vector2(stripe_x, street_y + 10), Vector2(10, 160)), Color(0.75, 0.75, 0.75, 0.35), true)
		else:
			# Dashed yellow lane divider
			for lx in range(20, int(CHUNK_SIZE), 80):
				draw_rect(Rect2(Vector2(origin.x + lx, street_y + 88.0), Vector2(40.0, 5.0)), Color(0.68, 0.55, 0.16, 0.40), true)
	
	if chunk.get("has_ns_street", false):
		var street_x := origin.x + CHUNK_SIZE * 0.5 - 90.0
		draw_rect(Rect2(Vector2(street_x, origin.y), Vector2(180.0, CHUNK_SIZE)), Color(0.045, 0.045, 0.05, 1.0), true)
		for ly in range(20, int(CHUNK_SIZE), 80):
			draw_rect(Rect2(Vector2(street_x + 88.0, origin.y + ly), Vector2(5.0, 40.0)), Color(0.68, 0.55, 0.16, 0.40), true)
	
	# Concrete rubble piles
	for r in chunk.get("rubble", []):
		draw_rect(Rect2(r["pos"], r["size"]), Color(0.20, 0.20, 0.22, 0.85), true)
		draw_line(r["pos"], r["pos"] + r["size"], Color(0.35, 0.12, 0.10, 0.7), 2.0) # rusted rebar
	
	var shadow_stretch := 1.0 + 0.55 * sin(night_factor * PI)
	var dyn_shadow := SHADOW_VEC * shadow_stretch
	
	for p in chunk.get("props", []):
		var pos: Vector2 = p["pos"]
		var kind: int = p["kind"]
		
		if kind == 0:
			# Abandoned Rusted Car Wreck
			var car_rect := Rect2(pos - Vector2(28, 16), Vector2(56, 32))
			var s_rect := Rect2(pos - Vector2(28, 16) + dyn_shadow * 0.8, Vector2(58, 34))
			draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.48), true)
			draw_rect(car_rect, Color(0.38, 0.22, 0.16, 1.0), true) # rusted chassis
			draw_rect(Rect2(pos - Vector2(16, 10), Vector2(28, 20)), Color(0.18, 0.18, 0.20, 1.0), true) # roof
			draw_line(pos - Vector2(14, 10), pos - Vector2(14, 10), Color(0.6, 0.7, 0.8, 0.7), 4.0) # cracked windshield
		elif kind == 1:
			# High-mast Urban Streetlight
			draw_line(pos, pos + dyn_shadow * 2.2, Color(0.0, 0.0, 0.0, 0.55), 5.0)
			draw_circle(pos, 60.0 + night_factor * 30.0, Color(0.70, 0.75, 0.85, 0.07 * flicker))
			draw_circle(pos, 22.0, Color(0.85, 0.90, 1.0, 0.14 * flicker))
			draw_circle(pos, 6.0, Color(0.24, 0.26, 0.28, 1.0))
			draw_circle(pos, 3.5, Color(0.85, 0.92, 1.0, 0.95))
		else:
			# Industrial Dumpster
			var d_rect := Rect2(pos - Vector2(24, 14), Vector2(48, 28))
			var s_rect := Rect2(pos - Vector2(24, 14) + dyn_shadow * 0.7, Vector2(48, 28))
			draw_rect(s_rect, Color(0.0, 0.0, 0.0, 0.45), true)
			draw_rect(d_rect, Color(0.15, 0.26, 0.18, 1.0), true) # green dumpster
			draw_rect(d_rect, Color(0.08, 0.14, 0.09, 1.0), false, 2.5)
