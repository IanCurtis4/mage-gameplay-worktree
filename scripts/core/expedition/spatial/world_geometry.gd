class_name WorldGeometry
extends RefCounted
## Logical world units: x/z horizontal, y height. No camera or projected pixels.
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const EPS := 0.00001
var geometry_revision := 0
var _stage: Dictionary = {}
var _temporary: Dictionary[String, AABB] = {}
var _solid_slabs: Array[AABB] = []
var _occupancy: Dictionary[String, Dictionary] = {}

func configure(manifest: ExpeditionManifest, stage_id: String) -> Dictionary:
	if manifest == null: return _failure(&"invalid_manifest")
	var data := manifest.to_data()
	for stage: Dictionary in data.get("stages", []):
		if stage["stage_id"] == stage_id:
			_stage = stage.duplicate(true)
			_solid_slabs.clear()
			# Preserve F0's distinction between authored solids and planar blockers.
			for instance: Dictionary in stage["part_instances"]:
				for definition: Dictionary in data["input"]["parts"]:
					if definition["part_id"] != instance["part_id"]: continue
					for original: AABB in definition["solid_volumes"]:
						var volume := Kernel.transform_volume(original,instance["rotation_quarters"],instance["translation"])
						if _supports_solid_floor(volume): _solid_slabs.append(volume)
			_temporary.clear()
			_occupancy.clear()
			# Monotonic even when replacing a world with another revision-1 manifest.
			geometry_revision += 1
			return _success({"manifest_hash": manifest.canonical_hash(), "stage_id": stage_id})
	return _failure(&"unknown_stage")

func _supports_solid_floor(volume: AABB) -> bool:
	var rectangle := PackedVector2Array([Vector2(volume.position.x,volume.position.z),Vector2(volume.end.x,volume.position.z),Vector2(volume.end.x,volume.end.z),Vector2(volume.position.x,volume.end.z)])
	for cell: Dictionary in _stage["surfaces"]:
		var polygon := PackedVector2Array()
		var horizontal := true
		for vertex: Vector3 in cell["vertices"]:
			if absf(vertex.y-volume.end.y) > EPS: horizontal = false; break
			polygon.append(Vector2(vertex.x,vertex.z))
		if horizontal and not Geometry2D.intersect_polygons(rectangle,polygon).is_empty(): return true
	return false
func _success(data: Dictionary = {}) -> Dictionary:
	return {"ok": true, "error_code": &"", "geometry_revision": geometry_revision, "data": data.duplicate(true)}

func _failure(code: StringName) -> Dictionary:
	return {"ok": false, "error_code": code, "geometry_revision": geometry_revision, "data": {}}

func _current(revision: int) -> bool:
	return not _stage.is_empty() and revision == geometry_revision

func _cell(id: String) -> Dictionary:
	for cell: Dictionary in _stage.get("surfaces", []):
		if cell["surface_id"] == id: return cell
	return {}

func _volumes() -> Array:
	var volumes: Array = _stage.get("volumes", []).duplicate()
	var ids: Array = _temporary.keys()
	ids.sort()
	for id: String in ids: volumes.append(_temporary[id])
	return volumes

func _profile_valid(profile: Dictionary) -> bool:
	if not profile.has_all(["radius", "height", "connector_kinds"]): return false
	if not _finite_number(profile["radius"]) or not _finite_number(profile["height"]): return false
	if not (profile["connector_kinds"] is Array or profile["connector_kinds"] is PackedStringArray) or profile["connector_kinds"].is_empty(): return false
	for kind: Variant in profile["connector_kinds"]:
		if not (kind is String or kind is StringName) or str(kind).is_empty(): return false
	return float(profile["radius"]) > 0.0 and float(profile["height"]) > 0.0

static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _point_valid(point: ExpeditionWorldPoint, radius: float = 0.0, height: float = 0.0) -> bool:
	if point == null or not point.position.is_finite() or point.stage_id != _stage.get("stage_id", ""): return false
	var cell := _cell(point.surface_id)
	return not cell.is_empty() and float(cell["headroom"]) + EPS >= height and _supported(cell, point.position, radius, height) and not sweep(point.position, point.position, {"radius":radius,"height":height}, geometry_revision)["data"]["hit"]

func _supported(cell: Dictionary, position: Vector3, radius: float, height: float) -> bool:
	if not Kernel.contains(cell, position): return false
	if Kernel.contains(cell, position, radius): return true
	# A disk may straddle a genuinely joined opening, never an unconnected edge.
	var vertices: Array = cell["vertices"]
	for index: int in range(vertices.size()):
		var a: Vector3 = vertices[index]
		var b: Vector3 = vertices[(index + 1) % vertices.size()]
		var edge := Vector2(b.x - a.x, b.z - a.z)
		var offset := Vector2(position.x - a.x, position.z - a.z)
		if absf(edge.cross(offset)) / edge.length() + EPS >= radius: continue
		var joined := false
		for endpoint: Dictionary in _stage["connectors"]:
			if endpoint["surface_id"] != cell["surface_id"] or float(endpoint["headroom"]) + EPS < height: continue
			var outward: Vector3 = endpoint["outward"]
			var delta := position - Vector3(endpoint["position"])
			var tangent := Vector2(-outward.z, outward.x)
			if absf(edge.normalized().dot(tangent)) < 1.0 - EPS or absf(Vector2(endpoint["position"].x - a.x, endpoint["position"].z - a.z).cross(edge)) > EPS: continue
			if absf(Vector2(delta.x, delta.z).dot(tangent)) + radius > float(endpoint["width"]) * 0.5 + EPS: continue
			for connection: Dictionary in _stage["connections"]:
				if endpoint["connector_id"] not in [connection["a_connector"], connection["b_connector"]]: continue
				var other_id: String = connection["b_connector"] if endpoint["connector_id"] == connection["a_connector"] else connection["a_connector"]
				for other: Dictionary in _stage["connectors"]:
					if other["connector_id"] == other_id and float(other["width"]) + EPS >= radius * 2.0 and float(other["headroom"]) + EPS >= height and float(_cell(other["surface_id"])["headroom"]) + EPS >= height: joined = true
		if not joined: return false
	return true
func support_at(surface_id: String, horizontal: Vector2, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not horizontal.is_finite(): return _failure(&"invalid_position")
	var cell := _cell(surface_id)
	if cell.is_empty(): return _failure(&"unknown_surface")
	var point := Kernel.support_y(cell, Vector3(horizontal.x,0,horizontal.y))
	if not Kernel.contains(cell,point): return _failure(&"invalid_support")
	return _success({"point":ExpeditionWorldPoint.create(_stage["stage_id"],surface_id,point).to_data()})
func position_query(point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	if not _point_valid(point, profile["radius"], profile["height"]): return _failure(&"invalid_support")
	var occupants: Array[String] = []
	for id: String in _occupancy:
		var item: Dictionary = _occupancy[id]
		var other: Vector3 = item["point"]["position"]
		if point.position.y < other.y + float(item["height"]) and point.position.y + float(profile["height"]) > other.y and Vector2(point.position.x, point.position.z).distance_to(Vector2(other.x, other.z)) < float(profile["radius"]) + float(item["radius"]): occupants.append(id)
	occupants.sort()
	return _success({"point": point.to_data(), "occupants": occupants})

func set_occupant(id: String, point: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	var check := position_query(point, profile, revision)
	if not check["ok"]: return check
	if id.is_empty(): return _failure(&"invalid_identity")
	_occupancy[id] = {"point": point.to_data(), "radius": profile["radius"], "height": profile["height"], "profile": profile.duplicate(true)}
	return _success()

func remove_occupant(id: String) -> void:
	_occupancy.erase(id)

func path(from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _profile_valid(profile): return _failure(&"invalid_profile")
	var radius: float = profile["radius"]
	var height: float = profile["height"]
	if not _point_valid(from, radius, height) or not _point_valid(to, radius, height): return _failure(&"invalid_support")
	var nodes: Dictionary = {"@from": from.to_data(), "@to": to.to_data()}
	var edges: Dictionary = {"@from": [], "@to": []}
	var endpoints: Dictionary = {}
	for endpoint: Dictionary in _stage["connectors"]:
		if not endpoint["kind"] in profile["connector_kinds"] or float(endpoint["width"]) + EPS < radius * 2.0 or float(endpoint["headroom"]) + EPS < height: continue
		var cell := _cell(endpoint["surface_id"])
		var inset := Kernel.support_y(cell, Vector3(endpoint["position"]) - Vector3(endpoint["outward"]) * radius)
		var point := ExpeditionWorldPoint.create(from.stage_id, endpoint["surface_id"], inset)
		if not _point_valid(point, radius, height): continue
		var id: String = endpoint["connector_id"]
		nodes[id] = point.to_data()
		edges[id] = []
		endpoints[id] = endpoint
	# Visibility graph corners give detours around AABBs within convex supports.
	for cell: Dictionary in _stage["surfaces"]:
		for volume_index: int in range(_volumes().size()):
			var box: AABB = _volumes()[volume_index]
			for x: float in [box.position.x - radius - EPS * 4.0, box.end.x + radius + EPS * 4.0]:
				for z: float in [box.position.z - radius - EPS * 4.0, box.end.z + radius + EPS * 4.0]:
					var position := Kernel.support_y(cell, Vector3(x, 0, z))
					var point := ExpeditionWorldPoint.create(from.stage_id, cell["surface_id"], position)
					if not _point_valid(point, radius, height): continue
					var id := "@corner/%s/%d/%s/%s" % [cell["surface_id"], volume_index, x, z]
					nodes[id] = point.to_data()
					edges[id] = []
	var ids: Array = nodes.keys()
	ids.sort()
	for a: String in ids:
		for b: String in ids:
			if a == b or nodes[a]["surface_id"] != nodes[b]["surface_id"]: continue
			if Kernel.clear_segment(nodes[a]["position"], nodes[b]["position"], _volumes(), radius, height):
				edges[a].append({"to": b, "via": [], "connection_id": "", "cost": Vector3(nodes[a]["position"]).distance_to(nodes[b]["position"])})
	for connection: Dictionary in _stage["connections"]:
		var a: String = connection["a_connector"]
		var b: String = connection["b_connector"]
		if not endpoints.has(a) or not endpoints.has(b): continue
		var seam: Vector3 = endpoints[a]["position"]
		if not Kernel.clear_segment(nodes[a]["position"], seam, _volumes(), radius, height) or not Kernel.clear_segment(seam, nodes[b]["position"], _volumes(), radius, height): continue
		var via := [ExpeditionWorldPoint.create(from.stage_id, endpoints[a]["surface_id"], seam).to_data(), ExpeditionWorldPoint.create(from.stage_id, endpoints[b]["surface_id"], seam).to_data()]
		var cost := Vector3(nodes[a]["position"]).distance_to(seam) + seam.distance_to(nodes[b]["position"])
		if connection["forward"]: edges[a].append({"to": b, "via": via, "connection_id": connection["connection_id"], "cost": cost})
		via = via.duplicate(true)
		via.reverse()
		if connection["backward"]: edges[b].append({"to": a, "via": via, "connection_id": connection["connection_id"], "cost": cost})
	var distances := {"@from": 0.0}
	var previous: Dictionary = {}
	var frontier: Array[String] = ["@from"]
	var visited: Dictionary = {}
	while not frontier.is_empty():
		frontier.sort_custom(func(a: String, b: String) -> bool: return float(distances[a]) < float(distances[b]) if distances[a] != distances[b] else a < b)
		var current: String = frontier.pop_front()
		if visited.has(current): continue
		visited[current] = true
		if current == "@to": break
		for edge: Dictionary in edges[current]:
			var candidate: float = float(distances[current]) + float(edge["cost"])
			if candidate + EPS >= float(distances.get(edge["to"], INF)): continue
			distances[edge["to"]] = candidate
			previous[edge["to"]] = {"from": current, "edge": edge}
			frontier.append(edge["to"])
	if not visited.has("@to"): return _failure(&"unreachable")
	var steps: Array[Dictionary] = []
	var cursor := "@to"
	while cursor != "@from":
		steps.push_front(previous[cursor])
		cursor = previous[cursor]["from"]
	var points: Array = [from.to_data()]
	var connections: Array[String] = []
	for step: Dictionary in steps:
		var edge: Dictionary = step["edge"]
		points.append_array(edge["via"])
		points.append(nodes[edge["to"]])
		if not edge["connection_id"].is_empty(): connections.append(edge["connection_id"])
	return _success({"points": points, "connection_ids": connections, "cost": distances["@to"]})

func sweep(from: Vector3, to: Vector3, collider: Dictionary, revision: int, mask: StringName = &"all") -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not from.is_finite() or not to.is_finite() or not collider.has_all(["radius", "height"]) or not _finite_number(collider["radius"]) or not _finite_number(collider["height"]) or float(collider["radius"]) < 0.0 or float(collider["height"]) < 0.0: return _failure(&"invalid_collider")
	if mask not in [&"all",&"supporting_slabs"]: return _failure(&"invalid_mask")
	var fraction := 1.0
	var normal := Vector3.ZERO
	var hit_id := ""
	var volumes: Array = _volumes() if mask == &"all" else _solid_slabs
	for index: int in range(volumes.size()):
		var volume: AABB = volumes[index]
		var radius: float = collider["radius"]
		var height: float = collider["height"]
		var expanded := AABB(volume.position - Vector3(radius, height, radius) + Vector3(EPS, 0, EPS), volume.size + Vector3(2 * radius, height, 2 * radius) - Vector3(2 * EPS, EPS, 2 * EPS))
		var hit := _segment_box(from, to, expanded)
		if hit.is_empty() or float(hit["fraction"]) > fraction: continue
		fraction = hit["fraction"]
		normal = hit["normal"]
		if mask == &"supporting_slabs":
			hit_id = "%s/slab/%d" % [_stage["stage_id"],index]
		elif index < _stage["volumes"].size():
			hit_id = "%s/volume/%d" % [_stage["stage_id"],index]
		else:
			var ids: Array = _temporary.keys()
			ids.sort()
			hit_id = "temporary/"+str(ids[index-_stage["volumes"].size()])
	return _success({"hit": not hit_id.is_empty(), "fraction": fraction, "position": from.lerp(to, fraction), "normal": normal, "volume_id": hit_id})

static func _segment_box(from: Vector3, to: Vector3, box: AABB) -> Dictionary:
	var low := 0.0
	var high := 1.0
	var normal := Vector3.ZERO
	var delta := to - from
	for axis: int in range(3):
		if absf(delta[axis]) < EPS:
			if from[axis] < box.position[axis] or from[axis] > box.end[axis]: return {}
			continue
		var a: float = (box.position[axis] - from[axis]) / delta[axis]
		var b: float = (box.end[axis] - from[axis]) / delta[axis]
		var entry: float = minf(a, b)
		if entry >= low:
			low = entry
			normal = Vector3.ZERO
			normal[axis] = -signf(delta[axis])
		high = minf(high, maxf(a, b))
		if low > high: return {}
	return {"fraction": low, "normal": normal}

func query_attack(shape: Dictionary, source: ExpeditionWorldPoint, target: ExpeditionWorldPoint, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not shape.has_all(["geometry_rule_id", "range"]) or not _finite_number(shape["range"]) or float(shape["range"]) < 0.0: return _failure(&"invalid_shape")
	if not _point_valid(source) or not _point_valid(target): return _failure(&"invalid_support")
	if not (shape["geometry_rule_id"] is String or shape["geometry_rule_id"] is StringName): return _failure(&"invalid_shape")
	var rule: StringName = shape["geometry_rule_id"]
	if rule not in [&"direct_volume", &"ground_connected", &"teleport_legal"]: return _failure(&"unknown_geometry_rule")
	var source_position := source.position
	var target_position := target.position
	if shape.has("source_offset") or shape.has("target_offset"):
		if rule != &"direct_volume": return _failure(&"invalid_shape")
		if not shape.get("source_offset",Vector3.ZERO) is Vector3 or not shape.get("target_offset",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var source_offset: Vector3 = shape.get("source_offset",Vector3.ZERO)
		var target_offset: Vector3 = shape.get("target_offset",Vector3.ZERO)
		if not source_offset.is_finite() or not target_offset.is_finite(): return _failure(&"invalid_shape")
		source_position += source_offset
		target_position += target_offset
	var distance := source_position.distance_to(target_position)
	var range_ok := distance <= float(shape["range"]) + EPS
	var los_ok := true
	var surfaces: Array[String] = [source.surface_id]
	if rule == &"ground_connected":
		if not shape.has("traversal"): return _failure(&"invalid_profile")
		var route := path(source, target, shape["traversal"], revision)
		los_ok = route["ok"]
		if los_ok:
			distance = route["data"]["cost"]
			range_ok = distance <= float(shape["range"]) + EPS
			for point: Dictionary in route["data"]["points"]:
				if not surfaces.has(point["surface_id"]): surfaces.append(point["surface_id"])
	elif rule == &"teleport_legal":
		if not shape.has("traversal") or not _profile_valid(shape["traversal"]): return _failure(&"invalid_profile")
		if not _point_valid(target, shape["traversal"]["radius"], shape["traversal"]["height"]): return _failure(&"invalid_destination")
		# The swept body may leave a supporting top, but may not enter its solid slab.
		# Authored planar blockers and temporary walls retain E06's bypass exception.
		var check := sweep(source.position,target.position,shape["traversal"],revision,&"supporting_slabs")
		los_ok = not check["data"]["hit"]
	else:
		var check := sweep(source_position, target_position, {"radius": 0.0, "height": 0.0}, revision)
		los_ok = not check["data"]["hit"]
	var shape_ok := true
	if not (shape.get("kind",&"sphere") is String or shape.get("kind",&"sphere") is StringName): return _failure(&"invalid_shape")
	var kind: StringName = shape.get("kind", &"sphere" )
	if kind not in [&"sphere", &"cone", &"line"]: return _failure(&"invalid_shape")
	if kind in [&"cone", &"line"]:
		if not shape.get("direction",Vector3.ZERO) is Vector3: return _failure(&"invalid_shape")
		var direction: Vector3 = shape.get("direction", Vector3.ZERO)
		if not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_shape")
		var offset := target_position - source_position
		var along := offset.dot(direction.normalized())
		if kind == &"cone":
			var angle := float(shape.get("half_angle", -1.0))
			if not is_finite(angle) or angle < 0.0 or angle > PI: return _failure(&"invalid_shape")
			shape_ok = offset.is_zero_approx() or direction.angle_to(offset) <= angle + EPS
		else:
			var width := float(shape.get("half_width", -1.0))
			if not is_finite(width) or width < 0.0: return _failure(&"invalid_shape")
			shape_ok = along >= 0.0 and (offset - direction.normalized() * along).length() <= width + EPS
	if not surfaces.has(target.surface_id): surfaces.append(target.surface_id)
	var hit := range_ok and los_ok and shape_ok
	return _success({"range_ok": range_ok, "los_ok": los_ok, "shape_ok": shape_ok, "hit": hit, "distance": distance, "affected_surfaces": surfaces if hit else []})

func insert_obstacle(id: String, volume: AABB, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if id.is_empty() or _temporary.has(id): return _failure(&"invalid_identity")
	if not volume.position.is_finite() or not volume.size.is_finite() or volume.size.x <= 0.0 or volume.size.y <= 0.0 or volume.size.z <= 0.0: return _failure(&"invalid_volume")
	for occupant: Dictionary in _occupancy.values():
		if not Kernel.clear_segment(occupant["point"]["position"], occupant["point"]["position"], [volume], occupant["radius"], occupant["height"]): return _failure(&"occupied")
	# Preserve every currently reachable authored socket for each registered occupant.
	# Compute before insertion, then reject atomically if the candidate disconnects one.
	var protected: Array[Dictionary] = []
	for occupant: Dictionary in _occupancy.values():
		var origin := ExpeditionWorldPoint.create(occupant["point"]["stage_id"], occupant["point"]["surface_id"], occupant["point"]["position"])
		for socket: Dictionary in _stage["sockets"]:
			var destination := ExpeditionWorldPoint.create(_stage["stage_id"], socket["surface_id"], socket["position"])
			if path(origin, destination, occupant["profile"], revision)["ok"]:
				protected.append({"from": origin, "to": destination, "profile": occupant["profile"]})
	_temporary[id] = volume
	for route: Dictionary in protected:
		if not path(route["from"], route["to"], route["profile"], revision)["ok"]:
			_temporary.erase(id)
			return _failure(&"would_disconnect")
	geometry_revision += 1
	return _success()

func remove_obstacle(id: String, revision: int) -> Dictionary:
	if not _current(revision): return _failure(&"stale_geometry")
	if not _temporary.erase(id): return _failure(&"unknown_obstacle")
	geometry_revision += 1
	return _success()

func resolve_surface(origin: Vector3, direction: Vector3, visible_surfaces: Array[String], revision: int) -> Dictionary:
	# Pure ray query only; projection, rendering and mouse wiring await visual D05.
	if not _current(revision): return _failure(&"stale_geometry")
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return _failure(&"invalid_ray")
	var nearest := INF
	var hit: Dictionary = {}
	var ambiguous := false
	for cell: Dictionary in _stage["surfaces"]:
		if not cell["surface_id"] in visible_surfaces: continue
		var normal := Kernel.plane_normal(cell["vertices"])
		var denominator := normal.dot(direction)
		if absf(denominator) < EPS: continue
		var t: float = normal.dot(Vector3(cell["vertices"][0]) - origin) / denominator
		if t < 0.0 or t > nearest + EPS: continue
		var point := origin + direction * t
		if not Kernel.contains(cell, point): continue
		if absf(t - nearest) <= EPS:
			ambiguous = true
			continue
		ambiguous = false
		nearest = t
		hit = {"point": ExpeditionWorldPoint.create(_stage["stage_id"], cell["surface_id"], point).to_data(), "normal": normal if normal.y > 0 else -normal}
	if hit.is_empty(): return _failure(&"hidden_or_missing_surface")
	if ambiguous: return _failure(&"ambiguous_surface")
	var obstruction := sweep(origin, hit["point"]["position"], {"radius": 0.0, "height": 0.0}, revision)
	if obstruction["data"]["hit"] and float(obstruction["data"]["fraction"]) < 1.0 - EPS: return _failure(&"occluded_surface")
	return _success(hit)
